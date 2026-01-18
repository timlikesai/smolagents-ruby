# Release Checklist: smolagents

## Namespace Claim Instructions (Do Not Execute Automatically)

These steps are for the human maintainer to claim the `smolagents` namespace on RubyGems.org.

1.  **Build the Gem:**
    ```bash
    gem build smolagents.gemspec
    ```
    *   *Expected Output:* `Successfully built RubyGem...  Name: smolagents  Version: 0.1.0  File: smolagents-0.1.0.gem`

2.  **Login to RubyGems (if not already logged in):**
    ```bash
    gem signin
    ```

3.  **Push the Gem (Claims the namespace):**
    ```bash
    gem push smolagents-0.1.0.gem
    ```

## Pre-Flight Validation

- [x] **Ruby Version:** `gemspec` requires `>= 4.0.0`.
- [x] **License:** Set to `Apache-2.0`.
- [ ] **Ractor Safety:** Verify `ToolSandbox` and Tool immutability.
- [ ] **Auto-Discovery:** Ensure `Smolagents.doctor` is non-blocking.
- [ ] **CI/CD:** Github Actions workflows are present (`.github/workflows/`).
