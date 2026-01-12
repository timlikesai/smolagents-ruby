# Architectural & Security Review

**Date**: 2026-01-12
**Reviewer**: Principal Ruby Engineer Review
**Status**: ✅ Complete - All items addressed

## Summary

Comprehensive review of smolagents-ruby codebase for Ruby best practices, security, and Python vestiges.

All identified issues have been resolved:
- Security hardening (class allowlists, format validation, path canonicalization)
- Python vestiges removed (`forward` → `execute`, documentation updated)
- Tooling improvements (rubocop-performance, tightened limits)

## Security Fixes Required

### 1. Class Allowlist for Persistence Deserialization

**Files**: `lib/smolagents/persistence/agent_manifest.rb`, `model_manifest.rb`
**Risk**: `Object.const_get` could instantiate arbitrary classes from untrusted manifests.
**Fix**: Add allowlist of valid agent/model classes.

### 2. Format Allowlist for AgentImage/AgentAudio

**File**: `lib/smolagents/types/agent_types.rb`
**Risk**: User-controlled format in Tempfile creation.
**Fix**: Allowlist valid image/audio formats.

### 3. Path Canonicalization

**File**: `lib/smolagents/types/agent_types.rb`
**Risk**: Path traversal in File.binread/binwrite.
**Fix**: Canonicalize and validate paths.

## Python Vestiges to Clean Up

### Code Changes

| File | Change |
|------|--------|
| `lib/smolagents/tools/tool.rb` | Rename `forward` → `execute` |
| All 19 tool implementations | Update method name |
| `lib/smolagents/tools/tool_dsl.rb` | Update DSL |

### Documentation Updates

| File | Issue |
|------|-------|
| `SECURITY.md` | References Python/Pyodide/E2B |
| `.github/ISSUE_TEMPLATE/bug_report.md` | Python code block, Python version |
| `CLAUDE.md` | `forward()` references |
| `README.md` | `forward()` in examples |

## Tooling Recommendations

- [x] Add `rubocop-performance` - done
- [x] Tighten complexity limits - done (method 50, class 300, ABC 50)
- [x] Code smell detection - addressed via manual refactoring (reek declined - RuboCop sufficient)

## Progress Tracking

- [x] Security: Class allowlist
- [x] Security: Format allowlist
- [x] Security: Path canonicalization
- [x] Cleanup: Rename forward → execute
- [x] Cleanup: Update SECURITY.md
- [x] Cleanup: Fix bug report template
- [x] Cleanup: Update CLAUDE.md/README.md
- [x] Tooling: RuboCop improvements (added rubocop-performance)
