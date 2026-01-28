# Live Integration Test Findings

This document captures discoveries, failure modes, and lessons learned from testing against real local models.

## Failure Modes Catalog

### F01: No Endpoints Reachable

**Symptom:** DNS resolution fails or connection refused on all endpoints.

**Causes:**
- Tailscale not running/connected
- LM Studio not running locally
- Network configuration issues

**Handling:** Tests should skip gracefully with exit 0, providing clear instructions.

**Resolution:**
- Start LM Studio on localhost:1234, OR
- Connect Tailscale with access to configured endpoints

### F02: Endpoint Reachable but No Models Loaded

**Symptom:** `/v1/models` returns empty array or model not found.

**Causes:**
- LM Studio running but no model loaded
- Model name mismatch

**Handling:** Tests should skip gracefully.

### F03: Model Loaded but Generation Fails

**Symptom:** Model created successfully but `generate()` throws exception.

**Causes:** (to be documented as we encounter them)
- Request format incompatibility
- Model-specific parameter issues
- Memory/resource constraints

---

## Test Infrastructure

### Endpoint Discovery

Tests use a discovery phase that:
1. Checks localhost:1234 first (for local development)
2. Falls back to Tailscale endpoints
3. Reports status of each endpoint
4. Selects first available with loaded models

### Bootstrap

`experiments/live/lib/bootstrap.rb` loads the full smolagents library and infrastructure config.

`experiments/live/lib/infrastructure.rb` provides endpoint configuration with:
- Environment variable overrides
- Tailscale defaults for distributed testing
- Optional dotenv support

---

## Observations

### 2026-01-28: Initial Setup

- LM Studio 0.4.0 probing works against real endpoints
- Network connectivity is a prerequisite that must be validated before tests
- Tailscale endpoints require Tailscale to be connected on the test machine
