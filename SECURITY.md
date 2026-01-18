# Security Policy

## Reporting a Vulnerability

To report security vulnerabilities, please open a private issue or contact the maintainers directly.

## Secure Code Execution

`smolagents-ruby` provides multiple options for secure code execution:

### 1. Local Ruby Sandbox (Default)

The default `LocalRubyExecutor` includes comprehensive security measures:

- **AST-based validation** - Uses Ripper to analyze code before execution
- **37 blocked methods** - eval, system, exec, spawn, send, const_get, etc.
- **17+ blocked constants** - File, IO, Dir, Process, Thread, ENV, etc.
- **Pattern blocking** - Backticks, %x literals, dangerous requires
- **Operation limits** - TracePoint-based execution tracking
- **Timeout enforcement** - Configurable execution timeout (default: 30s)

**Memory Limit Warning**: LocalRubyExecutor does NOT enforce memory limits. Only operation count is bounded via TracePoint. Malicious or poorly-written code can exhaust host memory:

```ruby
# This will crash the host Ruby process
Array.new(10**9)
```

For untrusted workloads, use DockerExecutor instead (see below).

### 2. Docker Sandbox (Recommended for Untrusted Code)

For stronger isolation with hard resource limits, use the `DockerExecutor`:

```ruby
executor = Smolagents::Executors::Docker.new(
  memory_mb: 256,  # Hard memory limit via cgroups
  cpu_quota: 100_000
)
```

Docker execution includes:
- `--memory` / `--memory-swap` - Hard memory limits (prevents OOM on host)
- `--cpu-quota` - CPU time limits
- `--pids-limit=32` - Prevents fork bombs
- `--network=none` - No network access
- `--read-only` - Read-only filesystem
- `--cap-drop=ALL` - All Linux capabilities dropped
- `--security-opt=no-new-privileges` - Privilege escalation blocked
- `--tmpfs=/tmp` - Limited writable space (32MB)

### 3. Ractor Isolation

For parallel execution with memory isolation:

```ruby
executor = Smolagents::RactorExecutor.new
```

We recommend Docker sandbox for executing untrusted code in production environments.
