# Ruby Code Execution Security: Resource Limiting and DoS Prevention

Comprehensive research for safely executing LLM-generated code in an agent framework (Ruby 3.2+).

## Table of Contents

1. [Memory Limits](#1-memory-limits)
2. [CPU/Time Limits](#2-cputime-limits)
3. [Operation Count Limits](#3-operation-count-limits)
4. [Fork Bombs and Process Limits](#4-fork-bombs-and-process-limits)
5. [Resource Exhaustion Attacks](#5-resource-exhaustion-attacks)
6. [Docker/Container Approaches](#6-dockercontainer-approaches)
7. [Production Systems](#7-production-systems-doing-this-well)
8. [Recommendations](#8-recommendations)

---

## 1. Memory Limits

### Process.setrlimit - Ruby Built-in

Ruby provides `Process.setrlimit` for setting memory limits at the OS level:

```ruby
# Limit virtual memory (address space) to 100MB
Process.setrlimit(Process::RLIMIT_AS, 100 * 1024 * 1024)

# Limit resident set size (RSS) to 50MB (in pages, typically 4KB each)
Process.setrlimit(Process::RLIMIT_RSS, 50 * 1024)  # 50MB / 4KB pages

# Limit data segment size
Process.setrlimit(Process::RLIMIT_DATA, 50 * 1024 * 1024)

# Check current limits
soft_limit, hard_limit = Process.getrlimit(:AS)
puts "Memory limit: #{soft_limit / 1024 / 1024}MB"
```

**Available limit types:**
- `RLIMIT_AS` - Virtual memory address space (most comprehensive)
- `RLIMIT_RSS` - Resident set size (physical memory)
- `RLIMIT_DATA` - Data segment size
- `RLIMIT_STACK` - Stack size

### Ruby-level Memory Tracking

Ruby doesn't provide built-in memory tracking, but you can use GC stats:

```ruby
before = GC.stat(:total_allocated_objects)
# Execute code
after = GC.stat(:total_allocated_objects)
allocated = after - before

# Also useful:
GC.stat(:heap_allocated_pages)  # Memory pages allocated
GC.stat(:heap_live_slots)       # Live objects
```

For more precise tracking, use gems like `memory_profiler`:

```ruby
require 'memory_profiler'

report = MemoryProfiler.report do
  # Code to profile
end

if report.total_allocated_memsize > 100_000_000  # 100MB
  raise "Memory limit exceeded"
end
```

### Detecting Memory Bombs

Memory bombs are hard to prevent at the Ruby level. Examples:

```ruby
# Infinite array
a = []
loop { a << 'x' * 1000 }

# String explosion
s = 'x' * (2 ** 30)  # Attempt to allocate 1GB string

# Hash table bomb
h = {}
1_000_000.times { |i| h[i] = 'x' * 1000 }
```

**Prevention:**
1. Use `RLIMIT_AS` - OS will kill process when limit exceeded
2. Monitor allocation rates using GC stats
3. Run in container with cgroup memory limits (preferred)

### ulimit Integration

System-level limits via `/etc/security/limits.conf`:

```
# /etc/security/limits.conf
username soft as 102400    # 100MB virtual memory
username hard as 204800    # 200MB hard limit
username soft data 51200   # 50MB data segment
```

Or set via shell before launching Ruby:

```bash
ulimit -v 102400  # 100MB virtual memory
ulimit -d 51200   # 50MB data segment
ruby untrusted_code.rb
```

**Limitations:**
- `RLIMIT_RSS` is not enforced on modern Linux (advisory only)
- `RLIMIT_AS` can be too aggressive (includes shared libraries)
- Better to use cgroups in production

**Sources:**
- [R14 - Memory Quota Exceeded in Ruby (MRI)](https://devcenter.heroku.com/articles/ruby-memory-use)
- [Ruby Issue #12771: Allow setting max memory consumption](https://bugs.ruby-lang.org/issues/12771)
- [Process module documentation](https://docs.ruby-lang.org/en/2.1.0/Process.html)

---

## 2. CPU/Time Limits

### Why Ruby's Timeout Module is Dangerous

**DO NOT USE `Timeout` for untrusted code execution.**

Ruby's `Timeout` module uses `Thread.raise` to interrupt execution, which is fundamentally unsafe:

```ruby
require 'timeout'

# DANGEROUS - Don't use this!
Timeout::timeout(5) do
  # Untrusted code
end
```

**Problems with Timeout:**

1. **Cannot be relied upon:** The exception thrown to terminate the block cannot be rescued unless `klass` is given explicitly. The block can use `ensure` to prevent handling.

2. **Corrupts shared resources:** Can interrupt code at any point, leaving resources in inconsistent state (network connections, files, databases).

3. **Thread.raise is unsafe:** "Thread.raise is basically like a sneak attack on your code that could result in almost anything."

4. **Undefined behavior:** "Take run-of-the-mill Ruby code, throw it in a `Timeout::timeout()` block, and a timeout will lead to undefined behavior."

### Safe Alternatives

#### 1. Process-based Timeouts (Recommended for Untrusted Code)

Fork a subprocess and use SIGALRM:

```ruby
require 'timeout'

def safe_execute_with_timeout(code, timeout_seconds)
  reader, writer = IO.pipe

  pid = fork do
    reader.close

    # Set up SIGALRM for hard timeout
    Signal.trap('ALRM') { exit!(124) }  # exit! bypasses ensure blocks
    Process.alarm(timeout_seconds)

    begin
      result = eval(code)
      writer.write(Marshal.dump(result))
    rescue => e
      writer.write(Marshal.dump(e))
    ensure
      writer.close
    end
  end

  writer.close

  # Wait for child with timeout
  deadline = Time.now + timeout_seconds
  loop do
    pid_result, status = Process.waitpid2(pid, Process::WNOHANG)
    if pid_result
      result = Marshal.load(reader.read) rescue nil
      reader.close
      return result if status.success?
      raise "Process exited with status #{status.exitstatus}"
    end

    if Time.now > deadline
      Process.kill('KILL', pid)
      Process.waitpid(pid)
      reader.close
      raise "Timeout after #{timeout_seconds}s"
    end

    sleep 0.1
  end
rescue => e
  Process.kill('KILL', pid) rescue nil
  raise e
end
```

**Alternative: Use the `safe_timeout` gem**

```ruby
require 'safe_timeout'

SafeTimeout.timeout(5) do
  # Code runs in separate process
end
```

#### 2. Signal Handling (Single Process)

For less critical use cases, use SIGALRM directly:

```ruby
def execute_with_signal_timeout(code, timeout_seconds)
  timed_out = false

  old_handler = Signal.trap('ALRM') do
    timed_out = true
    raise Timeout::Error, "Execution timed out after #{timeout_seconds}s"
  end

  Process.alarm(timeout_seconds)

  begin
    eval(code)
  ensure
    Process.alarm(0)  # Cancel alarm
    Signal.trap('ALRM', old_handler)
  end

  raise Timeout::Error if timed_out
end
```

**Limitations:**
- Can still be caught with rescue
- Not as secure as process isolation

#### 3. Ruby 3.1+ Fiber Scheduler

Modern Ruby with Fiber scheduler provides better timeout handling:

```ruby
require 'async'
require 'async/scheduler'

Async do |task|
  task.with_timeout(5) do
    # Code execution
  end
rescue Async::TimeoutError
  puts "Timed out!"
end
```

**Note:** Requires scheduler support; not universally available.

### Thread-based vs Process-based Timeouts

| Aspect | Thread-based (Timeout) | Process-based |
|--------|----------------------|---------------|
| Safety | Unsafe - can corrupt state | Safe - isolated process |
| Reliability | Can be bypassed | Cannot be bypassed |
| Overhead | Low | Higher (fork cost) |
| Shared state | Dangerous | Isolated |
| **Recommendation** | Never use for untrusted code | Use for untrusted code |

### Detecting Infinite Loops Before Execution

**Static Analysis (Limited):**

```ruby
def potentially_infinite?(code)
  # Very basic detection
  code.include?('loop') ||
  code.include?('while true') ||
  code.match?(/while\s+\d+\s*==\s*\d+/) ||
  code.include?('until false')
end
```

**Runtime Detection:**
- Not practical without executing
- Use timeout + process isolation instead

**Sources:**
- [Timeout: Ruby's Most Dangerous API (Mike Perham)](https://www.mikeperham.com/2015/05/08/timeout-rubys-most-dangerous-api/)
- [Why Ruby's Timeout is dangerous (Julia Evans)](https://jvns.ca/blog/2015/11/27/why-rubys-timeout-is-dangerous-and-thread-dot-raise-is-terrifying/)
- [safe_timeout gem](https://github.com/david-mccullars/safe_timeout)
- [The Ultimate Guide to Ruby Timeouts](https://github.com/ankane/the-ultimate-guide-to-ruby-timeouts)

---

## 3. Operation Count Limits

### TracePoint for Operation Counting

`TracePoint` is the modern, performant API for tracing Ruby execution:

```ruby
def execute_with_operation_limit(code, max_operations: 10_000)
  operation_count = 0

  trace = TracePoint.new(:call, :c_call, :line) do |tp|
    operation_count += 1
    if operation_count > max_operations
      trace.disable
      raise "Operation limit exceeded: #{max_operations}"
    end
  end

  trace.enable
  begin
    eval(code)
  ensure
    trace.disable
  end
end

# Usage
execute_with_operation_limit("100.times { |i| puts i }", max_operations: 1000)
```

**Available TracePoint Events:**

```ruby
:line          # Line execution
:call          # Ruby method call
:return        # Ruby method return
:c_call        # C method call
:c_return      # C method return
:raise         # Exception raised
:b_call        # Block call
:b_return      # Block return
:thread_begin  # Thread started
:thread_end    # Thread ended
```

**Filtering for Performance:**

```ruby
# Only trace specific events
trace = TracePoint.new(:call, :c_call) { |tp| ... }

# Only trace specific classes/modules
trace = TracePoint.new do |tp|
  next unless tp.defined_class.to_s.start_with?('User')
  # Count operation
end
```

### set_trace_func (Legacy API)

**Note:** `set_trace_func` is deprecated. Use TracePoint instead.

```ruby
def execute_with_trace_func(code, max_operations: 10_000)
  operation_count = 0

  set_trace_func proc { |event, file, line, id, binding, classname|
    operation_count += 1
    if operation_count > max_operations
      set_trace_func nil
      raise "Operation limit exceeded"
    end
  }

  begin
    eval(code)
  ensure
    set_trace_func nil
  end
end
```

### Performance Overhead of Tracing

**Benchmark Results:**

According to HuggingFace smolagents issue #6895, TracePoint significantly outperforms set_trace_func:

- `set_trace_func`: ~1.14 seconds
- `TracePoint` (basic): ~0.20 seconds
- **~5.7x faster with TracePoint**

**Overhead by Event Type:**

```ruby
# Minimal overhead (line events only)
TracePoint.new(:line) { }  # ~2-5x slowdown

# Moderate overhead (call events)
TracePoint.new(:call, :c_call) { }  # ~10-20x slowdown

# High overhead (accessing binding)
TracePoint.new(:line) do |tp|
  tp.binding.local_variables  # Very expensive!
end  # ~50-100x slowdown
```

**Best Practices:**

1. **Filter events:** Only trace necessary events
2. **Avoid binding access:** Don't call `tp.binding` unless required
3. **Disable when not needed:** `trace.disable` stops overhead
4. **Combine with timeout:** Tracing + timeout provides defense in depth

```ruby
def safe_execute(code, max_ops: 10_000, timeout: 5)
  operation_count = 0

  trace = TracePoint.new(:line) do |tp|
    operation_count += 1
    if operation_count > max_ops
      trace.disable
      raise "Operation limit exceeded: #{max_ops}"
    end
  end

  pid = fork do
    Signal.trap('ALRM') { exit!(124) }
    Process.alarm(timeout)

    trace.enable
    begin
      eval(code)
    ensure
      trace.disable
    end
  end

  # Wait for child...
end
```

**Sources:**
- [TracePoint API Issue #6895](https://bugs.ruby-lang.org/issues/6895)
- [Changing Debugging in Ruby with TracePoint](https://blog.appsignal.com/2020/04/01/changing-the-approach-to-debugging-in-ruby-with-tracepoint.html)
- [TracePoint documentation](https://docs.ruby-lang.org/en/master/TracePoint.html)

---

## 4. Fork Bombs and Process Limits

### What is a Fork Bomb?

A fork bomb creates processes exponentially:

```ruby
# Classic fork bomb (DO NOT RUN)
loop { fork { load __FILE__ } }

# Or the famous Bash version: :(){ :|:& };:
```

### Preventing Fork/Spawn

#### 1. Process Limits with RLIMIT_NPROC

```ruby
# Limit to 10 processes per user
Process.setrlimit(Process::RLIMIT_NPROC, 10)

# Now fork bombs are contained
begin
  10.times { fork { sleep 100 } }
rescue Errno::EAGAIN
  puts "Process limit reached!"
end
```

**System-wide limits:**

```bash
# /etc/security/limits.conf
username soft nproc 30
username hard nproc 50
```

Or via ulimit:

```bash
ulimit -u 30  # Max 30 processes
ruby untrusted_code.rb
```

**Modern Linux:** Default `nproc` limit since 2011 to mitigate fork bombs:

```bash
ulimit -u  # Check current limit
# Typical default: 4096 or more
```

#### 2. Detecting Process.fork Calls

**Method 1: Redefine fork**

```ruby
# Disable fork entirely
module Process
  def self.fork(*args)
    raise SecurityError, "fork is not allowed"
  end
end

# Or use alias
class Object
  alias_method :original_fork, :fork
  def fork(*args)
    raise SecurityError, "fork is not allowed"
  end
end
```

**Method 2: Use Binding.eval with restricted context**

```ruby
class RestrictedBinding
  def initialize
    @binding = binding
  end

  def get_binding
    # Don't expose fork, system, exec, etc.
    @binding.eval("undef fork") rescue nil
    @binding.eval("undef system") rescue nil
    @binding.eval("undef exec") rescue nil
    @binding.eval("undef spawn") rescue nil
    @binding.eval("undef `") rescue nil
    @binding
  end
end

# Execute in restricted binding
RestrictedBinding.new.get_binding.eval(untrusted_code)
```

**Method 3: TracePoint Detection**

```ruby
def detect_dangerous_calls(code)
  dangerous = []

  trace = TracePoint.new(:call, :c_call) do |tp|
    method_name = tp.method_id
    if [:fork, :spawn, :system, :exec, :`, :eval].include?(method_name)
      dangerous << "Detected dangerous call: #{method_name}"
      trace.disable
      raise SecurityError, "Dangerous method call: #{method_name}"
    end
  end

  trace.enable
  begin
    eval(code)
  ensure
    trace.disable
  end
end
```

#### 3. Container/cgroup Limits (Recommended)

**Docker:**

```yaml
# docker-compose.yml
services:
  ruby-sandbox:
    image: ruby:3.2
    pids_limit: 10  # Max 10 processes
    ulimits:
      nproc: 10
```

**Kubernetes:**

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: ruby-sandbox
    resources:
      limits:
        pids: "10"  # Alpha feature - requires PodPidsLimit
```

**cgroups directly:**

```bash
# Create cgroup
cgcreate -g pids:/sandbox

# Set limit
echo 10 > /sys/fs/cgroup/pids/sandbox/pids.max

# Run in cgroup
cgexec -g pids:/sandbox ruby untrusted_code.rb
```

### Backtraces and Caller Inspection

TracePoint can inspect the call stack:

```ruby
trace = TracePoint.new(:call) do |tp|
  if tp.method_id == :fork
    caller_locations = tp.binding.caller_locations
    puts "Fork called from:"
    caller_locations.each { |loc| puts "  #{loc}" }
    raise SecurityError, "fork is not allowed"
  end
end
```

**Sources:**
- [Fork bomb - Wikipedia](https://en.wikipedia.org/wiki/Fork_bomb)
- [Fork Bomb Protection for Clusters](https://github.com/gardener/gardener/issues/663)
- [What is a fork bomb and how can it be prevented?](https://www.supportpro.com/blog/what-is-a-fork-bomb-and-how-can-it-be-prevented/)

---

## 5. Resource Exhaustion Attacks

### ReDoS - Regular Expression Denial of Service

**What is ReDoS?**

Regular expressions with nested quantifiers can cause catastrophic backtracking:

```ruby
# Vulnerable regex (catastrophic backtracking)
vulnerable = /^(a+)+$/
vulnerable.match('a' * 30 + 'X')  # Takes exponential time!

# Another example
bad_regex = /^(a|a)*$/
bad_regex.match('a' * 25 + 'X')  # 2^25 steps = 33 million!
```

**How it works:** Regex engine tries all possible ways to match, leading to exponential time complexity.

#### Ruby 3.2+ Protection: Regexp.timeout

Ruby 3.2 introduced `Regexp.timeout` to prevent ReDoS:

```ruby
# Set global timeout (Ruby 3.2+)
Regexp.timeout = 1.0  # 1 second timeout for all regex matches

# Now this will raise Regexp::TimeoutError instead of hanging
begin
  /^(a+)+$/.match('a' * 30 + 'X')
rescue Regexp::TimeoutError
  puts "Regex timed out!"
end
```

**Per-Regexp timeout:**

```ruby
# Different timeout for specific regex
re = Regexp.new('^(a+)+$', timeout: 0.5)
re.match('aaaaaaaaaaaX')  # Times out after 500ms
```

**Important:** There is **no default timeout** - you must set it explicitly:

```ruby
# In your application initialization
Regexp.timeout = 1.0  # Set appropriate limit for your use case
```

#### Prevention Techniques

1. **Always set Regexp.timeout** for untrusted input:

```ruby
# Before executing untrusted code
Regexp.timeout = 1.0

# Or wrap specific execution
def safe_regex_exec(pattern, string)
  re = Regexp.new(pattern, timeout: 1.0)
  re.match(string)
rescue Regexp::TimeoutError
  nil
end
```

2. **Avoid nested quantifiers:**

```ruby
# Bad - nested quantifiers
/^(a+)+$/
/^(a*)*$/
/^(a+)*$/

# Good - atomic groups or possessive quantifiers
/^(?>a+)+$/     # Atomic group
/^a++$/         # Possessive quantifier (Ruby 2.0+)
```

3. **Make alternatives mutually exclusive:**

```ruby
# Bad - overlapping alternatives
/^(a|a)*$/
/^(ab|abc)*$/

# Good - mutually exclusive
/^a*$/
/^(ab|ac)*$/
```

4. **Use static analysis tools:**

```ruby
# Check for vulnerable patterns
require 'regexp-examples'  # gem install regexp-examples

def vulnerable_regex?(pattern)
  # Very simplified check
  pattern.scan(/(\(.+\))[+*]/).any?
end
```

**Tools for detection:**
- [regexploit](https://github.com/doyensec/regexploit) - Find ReDoS vulnerabilities
- RuboCop with custom cops for regex analysis

### Symbol Table Pollution

**The Problem:** In Ruby < 2.2, symbols were never garbage collected, leading to memory exhaustion:

```ruby
# Attack: Create infinite unique symbols
loop do |i|
  "user_input_#{i}".to_sym  # Never freed!
end
```

**Ruby 2.2+ Solution:** Symbol GC

Ruby 2.2 introduced Symbol Garbage Collection:

```ruby
# Dynamically created symbols CAN be GC'd
1_000_000.times { |i| "sym_#{i}".to_sym }
GC.start  # Symbols can be collected

# But method-based symbols are IMMORTAL
1_000.times { |i| define_method("method_#{i}") { } }
# These symbols will NEVER be collected
```

**Types of symbols:**

1. **Mortal symbols** (can be GC'd):
   - Created with `to_sym` / `intern`
   - Created dynamically at runtime

2. **Immortal symbols** (never GC'd):
   - Defined in source code
   - Created by `define_method`
   - Internal Ruby symbols

#### Prevention

**Primary rule: Never convert user input to symbols**

```ruby
# BAD - DoS vulnerability
def lookup(user_input)
  MY_HASH[user_input.to_sym]  # Don't do this!
end

# GOOD - Keep as strings
def lookup(user_input)
  MY_HASH[user_input]  # Strings are fine
end
```

**Dangerous methods that create symbols:**

```ruby
# All of these create symbols internally:
send(user_input, args)                    # BAD
instance_variable_get("@#{user_input}")   # BAD
const_get(user_input)                     # BAD
class_variable_get("@@#{user_input}")     # BAD
define_method(user_input) { }             # BAD - creates IMMORTAL symbol!
```

**Safe alternatives:**

```ruby
# Instead of send:
ALLOWED_METHODS = %w[method1 method2 method3]
if ALLOWED_METHODS.include?(user_input)
  send(user_input.to_sym, args)  # Now safe
end

# Or use hash lookup:
METHODS = {
  'method1' => -> { method1 },
  'method2' => -> { method2 }
}
METHODS[user_input]&.call
```

**Memory monitoring:**

```ruby
before = Symbol.all_symbols.size
# Execute code
after = Symbol.all_symbols.size
if after - before > 1000
  raise "Too many symbols created: #{after - before}"
end
```

### File Descriptor Exhaustion

**The Attack:**

```ruby
# Open files until system limit reached
loop { File.open('/dev/null') }  # Quickly exhausts FDs
```

**System limits:**

```ruby
# Check current limit
soft, hard = Process.getrlimit(:NOFILE)
puts "FD limit: #{soft} (soft), #{hard} (hard)"

# Default on Linux: often 1024 (soft), 4096 (hard)
```

#### Prevention

**1. Set RLIMIT_NOFILE:**

```ruby
# Limit to 100 file descriptors
Process.setrlimit(Process::RLIMIT_NOFILE, 100)

# Now this will fail:
100.times { File.open('/dev/null') }  # OK
File.open('/dev/null')  # Raises Errno::EMFILE
```

**System configuration:**

```bash
# /etc/security/limits.conf
username soft nofile 256
username hard nofile 512

# Or via ulimit
ulimit -n 100
ruby untrusted_code.rb
```

**2. Track open file descriptors:**

```ruby
def execute_with_fd_limit(code, max_fds: 50)
  initial_fds = open_fds_count

  begin
    eval(code)
  ensure
    current_fds = open_fds_count
    if current_fds - initial_fds > max_fds
      raise "Too many file descriptors opened: #{current_fds - initial_fds}"
    end
  end
end

def open_fds_count
  Dir.glob("/proc/#{Process.pid}/fd/*").length
rescue
  # Fallback: count ObjectSpace
  ObjectSpace.each_object(IO).count { |io| !io.closed? }
end
```

**3. Auto-close resources:**

```ruby
# Use blocks for auto-closing
File.open('file.txt') do |f|
  # File closed automatically
end

# Instead of:
f = File.open('file.txt')  # Might leak if exception
```

**4. Container limits (recommended):**

```yaml
# docker-compose.yml
services:
  ruby-sandbox:
    ulimits:
      nofile:
        soft: 100
        hard: 200
```

**Important:** Setting RLIMIT_NOFILE too high (e.g., 1048576) can cause performance issues, as some programs iterate over all possible FDs.

**Sources:**
- [Regexp.timeout in Ruby 3.2](https://blog.saeloun.com/2022/08/09/ruby-introduces-regexp-timeout/)
- [ReDoS and Catastrophic Backtracking](https://snyk.io/blog/redos-and-catastrophic-backtracking/)
- [Symbol GC in Ruby 2.2](https://www.sitepoint.com/symbol-gc-ruby-2-2/)
- [Ruby security documentation](https://docs.ruby-lang.org/en/2.4.0/security_rdoc.html)
- [Process limits documentation](https://workingwithruby.com/wwup/rlimits/)

---

## 6. Docker/Container Approaches

### Should You Use Docker/Containers?

**TL;DR: Yes, for production LLM code execution, containers (or VMs) are strongly recommended.**

### Container Isolation Hierarchy (Weakest to Strongest)

1. **In-process sandboxing** (Ruby-level)
   - Weakest isolation
   - Shared kernel, shared memory space
   - Can be bypassed with native extensions

2. **Operating system containers** (Docker, LXC)
   - Namespace isolation
   - cgroup resource limits
   - Shared kernel with host
   - Good for most use cases

3. **Sandboxed containers** (gVisor, Kata Containers)
   - Additional userspace kernel layer
   - Stronger syscall filtering
   - Better isolation than standard containers

4. **MicroVMs** (Firecracker, Cloud Hypervisor)
   - Full hardware virtualization
   - Strongest isolation
   - Used by AWS Lambda
   - Higher overhead but maximum security

### Docker + cgroups for Resource Limits

**Complete Docker example:**

```dockerfile
# Dockerfile
FROM ruby:3.2-slim

# Security: non-root user
RUN useradd -m -u 1000 sandbox
USER sandbox
WORKDIR /home/sandbox

# Install minimal dependencies
COPY Gemfile* ./
RUN bundle install --without development test

COPY . .

CMD ["ruby", "execute.rb"]
```

```yaml
# docker-compose.yml
version: '3.8'
services:
  ruby-sandbox:
    build: .
    security_opt:
      - no-new-privileges:true
      - seccomp:./seccomp-profile.json
    read_only: true
    tmpfs:
      - /tmp:size=10M,mode=1777

    # cgroup limits
    mem_limit: 128m           # Memory limit
    memswap_limit: 128m       # No swap
    mem_reservation: 64m      # Soft limit
    cpus: 0.5                 # 50% of one CPU
    pids_limit: 10            # Max 10 processes

    # Ulimits
    ulimits:
      nofile:                 # File descriptors
        soft: 100
        hard: 200
      nproc: 10               # Process limit

    # Network isolation
    network_mode: none

    # Capability dropping
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE  # Only if needed
```

**cgroups Directly (without Docker):**

```bash
# Create cgroup
sudo cgcreate -g cpu,memory,pids:/sandbox

# Set limits
echo 128M > /sys/fs/cgroup/memory/sandbox/memory.limit_in_bytes
echo 50000 > /sys/fs/cgroup/cpu/sandbox/cpu.cfs_quota_us  # 50% CPU
echo 10 > /sys/fs/cgroup/pids/sandbox/pids.max

# Execute in cgroup
cgexec -g cpu,memory,pids:/sandbox ruby untrusted_code.rb
```

**Monitoring cgroup usage:**

```ruby
# Read cgroup stats from Ruby
def cgroup_memory_usage
  File.read('/sys/fs/cgroup/memory/memory.usage_in_bytes').to_i
rescue
  nil
end

def cgroup_cpu_usage
  File.read('/sys/fs/cgroup/cpu/cpuacct.usage').to_i
rescue
  nil
end
```

### gVisor - Stronger Container Isolation

**What is gVisor?**

- Google's container sandbox runtime
- Implements Linux syscall interface in userspace (written in Go)
- Intercepts all syscalls before reaching host kernel
- Used by Google Cloud Run, GKE Sandbox

**Installation:**

```bash
# Install runsc (gVisor runtime)
(
  set -e
  ARCH=$(uname -m)
  URL=https://storage.googleapis.com/gvisor/releases/release/latest/${ARCH}
  wget ${URL}/runsc ${URL}/runsc.sha512 \
    ${URL}/containerd-shim-runsc-v1 ${URL}/containerd-shim-runsc-v1.sha512
  sha512sum -c runsc.sha512 -c containerd-shim-runsc-v1.sha512
  rm -f *.sha512
  chmod a+rx runsc containerd-shim-runsc-v1
  sudo mv runsc containerd-shim-runsc-v1 /usr/local/bin
)

# Configure Docker to use gVisor
sudo tee /etc/docker/daemon.json <<EOF
{
  "runtimes": {
    "runsc": {
      "path": "/usr/local/bin/runsc"
    }
  }
}
EOF

sudo systemctl restart docker
```

**Usage:**

```bash
# Run container with gVisor
docker run --runtime=runsc ruby:3.2 ruby -e "puts 'Hello from gVisor'"
```

**Ruby compatibility:**
- Ruby works well with gVisor
- Performance overhead: ~10-30% for I/O operations
- Worth it for untrusted code execution

### Firecracker - MicroVM Isolation (Strongest)

**What is Firecracker?**

- Lightweight virtual machine manager (VMM)
- Developed by AWS for Lambda and Fargate
- Combines VM isolation with container speed
- 125ms boot time, <5MB memory overhead per VM

**Key features:**
- Hardware virtualization (KVM)
- Full kernel isolation
- Cannot be escaped (unlike containers)
- Rate limiter for network/disk I/O
- 150 microVMs/sec/host creation rate

**Architecture:**

```
[Your Code] → [Ruby in microVM] → [Guest Kernel] → [KVM] → [Host Kernel]
            ↑
            Full isolation boundary
```

**Usage example:**

```bash
# Install Firecracker
release_url="https://github.com/firecracker-microvm/firecracker/releases"
latest=$(basename $(curl -fsSLI -o /dev/null -w  %{url_effective} ${release_url}/latest))
arch=`uname -m`
curl -L ${release_url}/download/${latest}/firecracker-${latest}-${arch}.tgz \
| tar -xz

# Run microVM (simplified)
./firecracker --config-file vm-config.json
```

**Production systems using Firecracker:**
- AWS Lambda (all functions)
- AWS Fargate
- Fly.io
- Many AI agent platforms

**Tradeoffs:**

| Aspect | Docker | gVisor | Firecracker |
|--------|--------|--------|-------------|
| Isolation | Good | Better | Best |
| Performance | Native | -10-30% | -5-10% |
| Startup time | <1s | <1s | ~125ms |
| Memory overhead | ~5-10MB | ~10-15MB | ~5MB |
| Complexity | Low | Medium | High |
| Escape risk | Medium | Low | Very Low |

### Pros/Cons: Container vs In-Process Sandboxing

#### In-Process Sandboxing (Ruby-level)

**Pros:**
- No external dependencies
- Fast - no container overhead
- Easy to integrate into existing code
- Works on all platforms

**Cons:**
- Weakest isolation - shared kernel
- Native extensions can bypass sandboxing
- Difficult to get right (many edge cases)
- No process isolation
- Ruby's `$SAFE` was removed for a reason
- Can be bypassed with clever code

**Example:**

```ruby
# In-process sandbox (weak)
class RubySandbox
  def execute(code)
    binding.eval("
      undef fork
      undef system
      undef exec

      #{code}
    ")
  end
end
```

#### Container-Based Sandboxing

**Pros:**
- Strong isolation (namespace + cgroups)
- Resource limits enforced by kernel
- Process isolation - crash doesn't affect host
- Well-tested and battle-proven
- Easy to configure and monitor
- Used by major platforms (Lambda, Cloud Run)
- Can use security profiles (seccomp, AppArmor)

**Cons:**
- Requires Docker/container runtime
- Slight performance overhead
- More complex deployment
- Shared kernel (containers) - use gVisor/Firecracker for stronger isolation

**Example:**

```ruby
# Container-based sandbox (strong)
class DockerSandbox
  def execute(code)
    # Write code to temp file
    File.write('/tmp/code.rb', code)

    # Execute in isolated container
    result = `docker run --rm \
      --memory=128m \
      --cpus=0.5 \
      --pids-limit=10 \
      --network=none \
      --read-only \
      -v /tmp/code.rb:/code.rb:ro \
      ruby:3.2-slim \
      timeout 5s ruby /code.rb 2>&1`

    raise "Execution failed" unless $?.success?
    result
  end
end
```

### Recommendation for LLM-Generated Code

For production LLM agents:

1. **Minimum viable security:** Docker containers with resource limits
2. **Recommended:** Docker + gVisor for stronger isolation
3. **Maximum security:** Firecracker microVMs (if complexity justified)
4. **Never rely on:** In-process Ruby sandboxing alone

**Layered approach (defense in depth):**

```ruby
# Layer 1: Process isolation + timeout
# Layer 2: Container with resource limits
# Layer 3: gVisor/Firecracker for syscall filtering
# Layer 4: Network isolation
# Layer 5: Read-only filesystem
# Layer 6: Monitoring and kill-switch
```

**Sources:**
- [Docker and Container Isolation](https://www.aquasec.com/blog/container-isolation-techniques/)
- [gVisor Architecture](https://gvisor.dev/docs/architecture_guide/intro/)
- [Firecracker: Lightweight Virtualization](https://aws.amazon.com/blogs/aws/firecracker-lightweight-virtualization-for-serverless-computing/)
- [Making Containers More Isolated](https://unit42.paloaltonetworks.com/making-containers-more-isolated-an-overview-of-sandboxed-container-technologies/)

---

## 7. Production Systems Doing This Well

### 1. E2B (Code Interpreter Sandbox)

**Overview:** Open-source infrastructure for running AI-generated code in secure isolated sandboxes.

**Technology:**
- Cloud-based sandboxes
- Multiple language support (Python, JavaScript, Ruby, C++)
- Firecracker microVMs for isolation
- Python/JS SDKs for integration

**Ruby Support:**

```ruby
# Using E2B (via REST API, no official Ruby SDK yet)
require 'net/http'
require 'json'

class E2BSandbox
  API_KEY = ENV['E2B_API_KEY']

  def execute_ruby(code)
    uri = URI('https://api.e2b.dev/sandboxes')

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path)
    request['Authorization'] = "Bearer #{API_KEY}"
    request['Content-Type'] = 'application/json'
    request.body = {
      template: 'base',
      code: code,
      language: 'ruby'
    }.to_json

    response = http.request(request)
    JSON.parse(response.body)
  end
end
```

**Features:**
- Full Linux environment
- File system access
- Package installation
- Network access (configurable)
- Real-world tool usage

**Pricing:** Free tier + pay-as-you-go

**Sources:**
- [E2B GitHub](https://github.com/e2b-dev/E2B)
- [E2B Documentation](https://e2b.dev/docs)

### 2. AWS Lambda (Firecracker)

**Overview:** Serverless execution platform using Firecracker microVMs.

**Ruby Support:**

```ruby
# AWS Lambda with Ruby 3.2
def lambda_handler(event:, context:)
  # Secure by default:
  # - 128MB-10GB memory limit
  # - 15-minute timeout
  # - Isolated microVM
  # - No persistent disk
  # - No network (unless VPC configured)

  code = event['code']
  eval(code)  # Still need in-lambda validation!
end
```

**Security Model:**
- Each function = separate Firecracker microVM
- Hardware-level isolation
- Resource limits enforced
- Fast cold starts (~100ms)

**Limitations:**
- Not designed for arbitrary code execution
- Need custom layer for untrusted code validation
- Cost per invocation

### 3. Heroku (Container-based)

**Overview:** Platform-as-a-Service using containerization.

**Resource Limits:**
- Memory quotas (R14 errors)
- Process limits
- File descriptor limits
- Network timeouts

**Ruby Example:**

```ruby
# Procfile
web: bundle exec puma -C config/puma.rb

# config/puma.rb
workers ENV.fetch("WEB_CONCURRENCY") { 2 }
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

# Heroku enforces:
# - Memory limits (512MB-14GB depending on dyno)
# - 30s request timeout
# - Process limits
```

### 4. Judge0 (Code Execution Engine)

**Overview:** Open-source online code execution system.

**Technology:**
- Docker containers
- Isolate sandbox (additional isolation layer)
- 60+ language support including Ruby
- REST API

**Security:**
- One container per execution
- Time and memory limits
- CPU limits
- Syscall filtering with seccomp
- Read-only file system

**Ruby Example:**

```bash
curl -X POST https://api.judge0.com/submissions \
  -H "Content-Type: application/json" \
  -d '{
    "source_code": "puts \"Hello from Ruby\"",
    "language_id": 72,
    "cpu_time_limit": 5,
    "memory_limit": 128000
  }'
```

### 5. Replit (Educational/Collaborative Coding)

**Overview:** Online IDE with code execution.

**Technology:**
- gVisor for container isolation
- Kubernetes orchestration
- Multi-language support

**Features:**
- Real-time collaboration
- Package management
- File system access
- Database integration

**Security:**
- Namespace isolation
- Resource quotas
- Network policies
- User authentication

### 6. GitHub Codespaces (Development Containers)

**Overview:** Cloud-based development environments.

**Technology:**
- VS Code Server
- Docker containers
- Kubernetes backend

**Ruby Support:**

```json
// .devcontainer/devcontainer.json
{
  "name": "Ruby",
  "image": "mcr.microsoft.com/devcontainers/ruby:3.2",
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {}
  },
  "customizations": {
    "vscode": {
      "extensions": ["rebornix.ruby"]
    }
  },
  "postCreateCommand": "bundle install"
}
```

**Security:**
- Isolated per-user containers
- Resource limits
- Network policies
- Secret management

### 7. Modal (Serverless Container Platform)

**Overview:** Serverless platform for data/ML workloads.

**Technology:**
- Custom container runtime
- GPU support
- Fast cold starts

**Ruby Support (via custom containers):**

```python
# modal_app.py (Python SDK)
import modal

stub = modal.Stub("ruby-executor")

@stub.function(
    image=modal.Image.debian_slim().apt_install("ruby"),
    memory=128,
    timeout=60,
    cpu=0.5
)
def execute_ruby(code: str):
    import subprocess
    result = subprocess.run(
        ["ruby", "-e", code],
        capture_output=True,
        text=True,
        timeout=5
    )
    return result.stdout
```

### Common Patterns Across Production Systems

1. **Isolation Layer:**
   - Containers (minimum)
   - gVisor/Kata (better)
   - Firecracker/MicroVMs (best)

2. **Resource Limits:**
   - Memory: 128MB-1GB typical
   - CPU: 0.5-2 cores
   - Time: 5-60 seconds
   - Processes: 10-100
   - File descriptors: 100-1000

3. **Network:**
   - Default: no network access
   - Optional: allowlist-based access

4. **File System:**
   - Read-only root filesystem
   - Small writable tmpfs
   - No persistent state

5. **Monitoring:**
   - Resource usage tracking
   - Audit logs
   - Anomaly detection
   - Kill-switch for abuse

**Sources:**
- [E2B Blog](https://e2b.dev/blog)
- [Firecracker at AWS](https://aws.amazon.com/blogs/opensource/firecracker-open-source-secure-fast-microvm-serverless/)
- [Judge0 GitHub](https://github.com/judge0/judge0)

---

## 8. Recommendations

### For smolagents-ruby: Layered Security Approach

#### Phase 1: Immediate (In-Process Guards)

**Basic resource limiting without containers:**

```ruby
module Smolagents
  class SecureExecutor
    def initialize(
      max_memory_mb: 128,
      max_operations: 10_000,
      timeout_seconds: 5,
      max_processes: 1
    )
      @max_memory_mb = max_memory_mb
      @max_operations = max_operations
      @timeout_seconds = timeout_seconds
      @max_processes = max_processes
    end

    def execute(code)
      setup_resource_limits
      execute_with_guards(code)
    end

    private

    def setup_resource_limits
      # Memory limit
      Process.setrlimit(
        Process::RLIMIT_AS,
        @max_memory_mb * 1024 * 1024
      )

      # Process limit (prevent fork bombs)
      Process.setrlimit(Process::RLIMIT_NPROC, @max_processes)

      # File descriptor limit
      Process.setrlimit(Process::RLIMIT_NOFILE, 100)

      # Set regex timeout (Ruby 3.2+)
      Regexp.timeout = 1.0 if defined?(Regexp.timeout=)
    end

    def execute_with_guards(code)
      operation_count = 0
      result = nil

      # TracePoint for operation counting
      trace = TracePoint.new(:line) do |tp|
        operation_count += 1
        if operation_count > @max_operations
          trace.disable
          raise SecurityError, "Operation limit exceeded"
        end
      end

      # Fork subprocess for timeout + isolation
      reader, writer = IO.pipe

      pid = fork do
        reader.close

        # Hard timeout with SIGALRM
        Signal.trap('ALRM') { exit!(124) }
        Process.alarm(@timeout_seconds)

        begin
          trace.enable
          result = eval(code)
          trace.disable

          writer.write(Marshal.dump(result))
        rescue => e
          writer.write(Marshal.dump(e))
        ensure
          writer.close
        end
      end

      writer.close

      # Wait for child
      deadline = Time.now + @timeout_seconds
      loop do
        pid_result, status = Process.waitpid2(pid, Process::WNOHANG)

        if pid_result
          data = reader.read
          reader.close
          result = Marshal.load(data) if data && !data.empty?

          if result.is_a?(Exception)
            raise result
          elsif status.success?
            return result
          else
            raise SecurityError, "Process exited with status #{status.exitstatus}"
          end
        end

        if Time.now > deadline
          Process.kill('KILL', pid)
          Process.waitpid(pid)
          reader.close
          raise Timeout::Error, "Execution timed out after #{@timeout_seconds}s"
        end

        sleep 0.01
      end
    rescue => e
      Process.kill('KILL', pid) rescue nil
      raise e
    end
  end
end
```

**Usage:**

```ruby
executor = Smolagents::SecureExecutor.new(
  max_memory_mb: 128,
  max_operations: 10_000,
  timeout_seconds: 5
)

result = executor.execute("100.times { |i| puts i }")
```

#### Phase 2: Container Integration (Recommended)

**Docker-based executor:**

```ruby
module Smolagents
  class DockerExecutor
    DOCKER_IMAGE = 'ruby:3.2-slim'

    def initialize(
      memory_limit: '128m',
      cpu_limit: '0.5',
      timeout: 5,
      network: false
    )
      @memory_limit = memory_limit
      @cpu_limit = cpu_limit
      @timeout = timeout
      @network = network
    end

    def execute(code)
      # Write code to temp file
      tmpfile = Tempfile.new(['code', '.rb'])
      tmpfile.write(code)
      tmpfile.close

      # Build docker command
      docker_cmd = [
        'docker', 'run', '--rm',
        '--memory', @memory_limit,
        '--cpus', @cpu_limit,
        '--pids-limit', '10',
        '--read-only',
        '--tmpfs', '/tmp:size=10M',
        '--security-opt', 'no-new-privileges:true'
      ]

      # Network isolation
      docker_cmd += ['--network', 'none'] unless @network

      # Mount code file
      docker_cmd += [
        '-v', "#{tmpfile.path}:/code.rb:ro",
        DOCKER_IMAGE,
        'timeout', "#{@timeout}s", 'ruby', '/code.rb'
      ]

      # Execute
      output = nil
      status = nil
      Open3.popen3(*docker_cmd) do |stdin, stdout, stderr, wait_thr|
        stdin.close
        output = stdout.read
        errors = stderr.read
        status = wait_thr.value

        raise SecurityError, errors unless status.success?
      end

      output
    ensure
      tmpfile.unlink if tmpfile
    end
  end
end
```

#### Phase 3: Advanced (gVisor or Firecracker)

**For maximum security in production:**

```ruby
module Smolagents
  class GVisorExecutor < DockerExecutor
    def execute(code)
      # Same as DockerExecutor but add:
      docker_cmd = [
        'docker', 'run', '--rm',
        '--runtime', 'runsc',  # Use gVisor
        # ... rest of options
      ]

      super
    end
  end
end
```

### Configuration Recommendations

**Development:**
```ruby
# config/smolagents.rb
Smolagents.configure do |config|
  config.executor = Smolagents::SecureExecutor.new(
    max_memory_mb: 256,
    max_operations: 50_000,
    timeout_seconds: 30
  )
end
```

**Production:**
```ruby
Smolagents.configure do |config|
  if ENV['DOCKER_AVAILABLE']
    config.executor = Smolagents::DockerExecutor.new(
      memory_limit: '128m',
      cpu_limit: '0.5',
      timeout: 5
    )
  else
    config.executor = Smolagents::SecureExecutor.new(
      max_memory_mb: 128,
      max_operations: 10_000,
      timeout_seconds: 5
    )

    warn "WARNING: Running without container isolation"
  end
end
```

**High-security production:**
```ruby
Smolagents.configure do |config|
  config.executor = Smolagents::GVisorExecutor.new(
    memory_limit: '128m',
    cpu_limit: '0.5',
    timeout: 5,
    network: false
  )

  # Additional monitoring
  config.on_execution_start do |code|
    AuditLog.log_execution(code: code, user: current_user)
  end

  config.on_execution_error do |error|
    SecurityMonitor.alert(error: error)
  end
end
```

### Resource Limit Guidelines

**Conservative (untrusted internet users):**
- Memory: 64-128MB
- CPU: 0.25-0.5 cores
- Timeout: 3-5 seconds
- Operations: 5,000-10,000
- Processes: 1-5
- File descriptors: 50-100
- Network: None

**Moderate (authenticated users):**
- Memory: 128-256MB
- CPU: 0.5-1 core
- Timeout: 10-30 seconds
- Operations: 10,000-50,000
- Processes: 5-10
- File descriptors: 100-200
- Network: Limited (allowlist)

**Generous (trusted users/development):**
- Memory: 256-512MB
- CPU: 1-2 cores
- Timeout: 30-60 seconds
- Operations: 50,000-100,000
- Processes: 10-20
- File descriptors: 200-500
- Network: Full access

### Testing Security Measures

**Create test suite for security:**

```ruby
# spec/security_spec.rb
RSpec.describe Smolagents::SecureExecutor do
  let(:executor) { described_class.new(timeout_seconds: 2) }

  describe 'memory limits' do
    it 'prevents memory bombs' do
      code = 'a = []; loop { a << "x" * 1_000_000 }'
      expect { executor.execute(code) }.to raise_error(SecurityError)
    end
  end

  describe 'time limits' do
    it 'enforces timeout' do
      code = 'sleep 10'
      expect { executor.execute(code) }.to raise_error(Timeout::Error)
    end
  end

  describe 'fork bombs' do
    it 'prevents fork bombs' do
      code = 'loop { fork { sleep 100 } }'
      expect { executor.execute(code) }.to raise_error(SecurityError)
    end
  end

  describe 'ReDoS' do
    it 'prevents catastrophic backtracking' do
      code = '/^(a+)+$/.match("a" * 30 + "X")'
      expect { executor.execute(code) }.to raise_error(Regexp::TimeoutError)
    end
  end

  describe 'file descriptor exhaustion' do
    it 'limits open files' do
      code = '100.times { File.open("/dev/null") }'
      expect { executor.execute(code) }.to raise_error(Errno::EMFILE)
    end
  end
end
```

### Documentation for Users

**README additions:**

```markdown
## Security Considerations

smolagents-ruby executes AI-generated code. For safety:

### Development
- Code runs in forked process with resource limits
- 5-second timeout
- 128MB memory limit
- Basic operation counting

### Production
We strongly recommend Docker/container isolation:

```ruby
# Use Docker executor
Smolagents.configure do |config|
  config.executor = Smolagents::DockerExecutor.new
end
```

Or use external sandbox services:
- E2B (e2b.dev)
- AWS Lambda
- Modal

### Security Layers
1. Process isolation (fork)
2. Resource limits (rlimit)
3. Timeout (SIGALRM)
4. Container isolation (Docker)
5. Optional: gVisor/Firecracker for maximum security
```

### Decision Matrix

| Scenario | Recommended Approach |
|----------|---------------------|
| Development/testing | SecureExecutor (fork + rlimit) |
| Production (low-risk) | Docker with resource limits |
| Production (high-risk) | Docker + gVisor |
| Production (maximum security) | Firecracker or external service (E2B) |
| Serverless | AWS Lambda (built-in Firecracker) |
| On-premise | Docker + cgroups + monitoring |

---

## Summary Table

| Protection | Implementation | Effectiveness | Performance Impact |
|------------|---------------|---------------|-------------------|
| **Memory Limit** | `Process.setrlimit(:AS)` | High | None |
| **CPU Limit** | Fork + SIGALRM | Medium-High | Low (fork cost) |
| **Operation Count** | TracePoint | Medium | Medium (2-10x) |
| **Fork Bombs** | `RLIMIT_NPROC` | High | None |
| **ReDoS** | `Regexp.timeout` | High | None |
| **Symbol Pollution** | Input validation | High | None |
| **FD Exhaustion** | `RLIMIT_NOFILE` | High | None |
| **Container** | Docker | Very High | Low (~5-10%) |
| **gVisor** | Docker + runsc | Very High | Medium (~10-30%) |
| **Firecracker** | MicroVM | Highest | Low (~5-10%) |

---

## Final Recommendations

### For smolagents-ruby (Ruby agent framework):

1. **Immediate (v1.0):**
   - Implement `SecureExecutor` with fork + rlimit + timeout
   - Set `Regexp.timeout = 1.0` globally
   - Document security considerations

2. **Short-term (v1.1):**
   - Add optional `DockerExecutor`
   - Provide docker-compose.yml example
   - Add security test suite

3. **Long-term (v2.0):**
   - Support gVisor runtime option
   - Integration with E2B or similar services
   - Advanced monitoring and audit logging

4. **Always:**
   - Defense in depth - use multiple layers
   - Never trust Ruby-level sandboxing alone
   - Monitor resource usage
   - Have kill-switch for abuse
   - Log all executions for audit

### The Bottom Line

**For production LLM code execution in Ruby:**
- Minimum: Fork + rlimit + timeout (SecureExecutor)
- Recommended: Docker containers with resource limits
- Best: Docker + gVisor, or Firecracker, or external service

**Never rely on Ruby-level sandboxing alone for truly untrusted code.**

---

## References

Complete list of sources cited throughout this document:

**Memory Limits:**
- [R14 - Memory Quota Exceeded in Ruby (MRI)](https://devcenter.heroku.com/articles/ruby-memory-use)
- [Ruby Issue #12771: Allow setting max memory consumption](https://bugs.ruby-lang.org/issues/12771)
- [Process module documentation](https://docs.ruby-lang.org/en/2.1.0/Process.html)

**Timeouts:**
- [Timeout: Ruby's Most Dangerous API (Mike Perham)](https://www.mikeperham.com/2015/05/08/timeout-rubys-most-dangerous-api/)
- [Why Ruby's Timeout is dangerous (Julia Evans)](https://jvns.ca/blog/2015/11/27/why-rubys-timeout-is-dangerous-and-thread-dot-raise-is-terrifying/)
- [safe_timeout gem](https://github.com/david-mccullars/safe_timeout)
- [The Ultimate Guide to Ruby Timeouts](https://github.com/ankane/the-ultimate-guide-to-ruby-timeouts)

**Tracing:**
- [TracePoint API Issue #6895](https://bugs.ruby-lang.org/issues/6895)
- [Changing Debugging in Ruby with TracePoint](https://blog.appsignal.com/2020/04/01/changing-the-approach-to-debugging-in-ruby-with-tracepoint.html)
- [TracePoint documentation](https://docs.ruby-lang.org/en/master/TracePoint.html)

**Process Limits:**
- [Fork bomb - Wikipedia](https://en.wikipedia.org/wiki/Fork_bomb)
- [Fork Bomb Protection for Clusters](https://github.com/gardener/gardener/issues/663)
- [What is a fork bomb and how can it be prevented?](https://www.supportpro.com/blog/what-is-a-fork-bomb-and-how-can-it-be-prevented/)

**Resource Exhaustion:**
- [Regexp.timeout in Ruby 3.2](https://blog.saeloun.com/2022/08/09/ruby-introduces-regexp-timeout/)
- [ReDoS and Catastrophic Backtracking](https://snyk.io/blog/redos-and-catastrophic-backtracking/)
- [Symbol GC in Ruby 2.2](https://www.sitepoint.com/symbol-gc-ruby-2-2/)
- [Ruby security documentation](https://docs.ruby-lang.org/en/2.4.0/security_rdoc.html)
- [Process limits documentation](https://workingwithruby.com/wwup/rlimits/)

**Containers:**
- [Docker and Container Isolation](https://www.aquasec.com/blog/container-isolation-techniques/)
- [Docker Sandboxes for Coding Agent Safety](https://www.docker.com/blog/docker-sandboxes-a-new-approach-for-coding-agent-safety/)
- [Container Isolation Best Practices](https://snyk.io/blog/best-practices-for-container-isolation/)

**gVisor:**
- [gVisor Architecture](https://gvisor.dev/docs/architecture_guide/intro/)
- [gVisor GitHub](https://github.com/google/gvisor)
- [Making Containers More Isolated](https://unit42.paloaltonetworks.com/making-containers-more-isolated-an-overview-of-sandboxed-container-technologies/)

**Firecracker:**
- [Firecracker: Lightweight Virtualization](https://aws.amazon.com/blogs/aws/firecracker-lightweight-virtualization-for-serverless-computing/)
- [Announcing Firecracker Open Source](https://aws.amazon.com/blogs/opensource/firecracker-open-source-secure-fast-microvm-serverless/)
- [Firecracker GitHub](https://github.com/firecracker-microvm/firecracker)
- [How AWS's Firecracker Virtual Machines Work](https://www.amazon.science/blog/how-awss-firecracker-virtual-machines-work)

**Production Systems:**
- [E2B GitHub](https://github.com/e2b-dev/E2B)
- [E2B Documentation](https://e2b.dev/docs)
- [Safe Ruby Sandbox](https://github.com/ukutaht/safe_ruby)
- [Ruby Box Sandbox](https://github.com/alecdotninja/ruby_box)
- [Shikashi Sandbox](https://github.com/tario/shikashi)

**LLM Sandboxing:**
- [Code Sandboxes for LLM AI Agents](https://amirmalik.net/2025/03/07/code-sandboxes-for-llm-ai-agents/)
- [Awesome Sandbox (Restyler)](https://github.com/restyler/awesome-sandbox)
- [LLM Sandbox GitHub](https://github.com/vndee/llm-sandbox)

---

**Document Version:** 1.0
**Last Updated:** 2026-01-08
**Target Ruby Version:** 3.2+
**For:** smolagents-ruby (LLM agent framework)
