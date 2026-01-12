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

### 2. Docker Sandbox

For stronger isolation, use the `DockerExecutor`:

```ruby
executor = Smolagents::DockerExecutor.new(
  timeout: 30,
  memory_mb: 256,
  network: false  # Disables networking
)
```

Docker execution includes:
- `--network=none` - No network access
- `--read-only` - Read-only filesystem
- `--cap-drop=ALL` - All Linux capabilities dropped
- `--security-opt=no-new-privileges` - Privilege escalation blocked
- Memory and CPU limits enforced

### 3. Ractor Isolation

For parallel execution with memory isolation:

```ruby
executor = Smolagents::RactorExecutor.new
```

We recommend Docker sandbox for executing untrusted code in production environments.
