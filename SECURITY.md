# Security Policy

## Reporting a Vulnerability

To report security vulnerabilities, please open a private issue or contact the maintainers directly.

## Secure Code Execution

`smolagents-ruby` uses Ractor-based execution for secure code isolation:

### Ractor Executor (Default)

The `RactorExecutor` provides memory-isolated execution with state persistence:

```ruby
executor = Smolagents::RactorExecutor.new
```

Security features:
- **Ractor memory isolation** - Code runs in a separate Ractor with no shared mutable state
- **AST-based validation** - Uses Ripper to analyze code before execution
- **37 blocked methods** - eval, system, exec, spawn, send, const_get, etc.
- **17+ blocked constants** - File, IO, Dir, Process, Thread, ENV, etc.
- **Pattern blocking** - Backticks, %x literals, dangerous requires
- **Operation limits** - TracePoint-based execution tracking
- **State persistence** - Instance variables persist across code blocks within an agent session

### Docker Sandbox (Recommended for Untrusted Code)

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

We recommend Docker sandbox for executing untrusted code in production environments.
