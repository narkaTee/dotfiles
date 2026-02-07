# Sandbox (Ruby Implementation)

## Overview

This document specifies the Ruby implementation of the `sandbox` command. It mirrors the behavior described in the primary sandbox spec and defines Ruby-specific architecture, interfaces, and UX behavior. The Ruby implementation is expected to be a drop-in alternative that preserves all user-facing semantics while enabling a stricter, testable code structure.

**Source of truth:** The core behavior is defined in [`sandbox.md`](sandbox.md). This document references it and only adds Ruby-specific constraints and UX details.

## Goals

- Match all CLI semantics, backend behavior, and UX described in `sandbox.md`.
- Provide a **strict backend interface** with explicit method contracts.
- Preserve backend auto-detection rules and directory-based naming.
- Keep the implementation modular and testable (orchestrator, backends, IDE helpers, command runner).
- Add a TTY spinner header UX for long-running phases while preserving subcommand output.

## Non-Goals

- Changing CLI flags or user-visible behavior defined in `sandbox.md`.
- Replacing or altering backend functionality.
- Introducing new backends beyond those listed in `sandbox.md`.

## Architectural Decisions (Ruby-Specific)

### Strict Backend Interface

All backends must conform to a strict interface (Ruby module or abstract base class) with required methods:

- `backend_start`
- `backend_stop`
- `backend_enter`
- `backend_is_running`
- `backend_get_ssh_port`
- `backend_get_ip`

The orchestrator must depend exclusively on this interface. Any backend missing methods must raise a clear error at load time.

**Reference:** Backend abstraction defined in `sandbox.md`.

### Backend Detection and Selection

Use **probing** to detect existing sandboxes:

1. If explicit backend flag is provided, use that backend.
2. Else, call `backend_is_running` for each backend to detect an existing sandbox for the current directory.
3. Else, default to container backend.

**Reference:** Backend selection logic in `sandbox.md`.

### Directory-Based Naming

Sandbox name must be derived from the current directory basename with non-alphanumeric characters replaced by underscores.

**Reference:** Sandbox naming in `sandbox.md`.

### SSH Abstraction

All SSH access is mediated by backend `backend_get_ip` and `backend_get_ssh_port`. Ruby should expose a `ConnectionInfo` (or equivalent) object and pass it to IDE helpers and sync operations.

**Reference:** SSH abstraction and connection info in `sandbox.md`.

### Proxy Wrapper

Proxy is a wrapper (decorator) around container/KVM backends, not a standalone backend. It must preserve backend interface and delegate appropriately.

**Reference:** Proxy wrapping in `sandbox.md`.

### IDE Integration

IDE commands (`code`, `idea`, `tmux`) remain thin wrappers around connection info and URI/command templates.

**Reference:** IDE integration details in `sandbox.md`.

### Fail-Fast Behavior

If required tools are missing (e.g., Alacritty for `sandbox tmux`), Ruby must exit with a clear error message consistent with the Bash implementation.

**Reference:** Terminal integration error handling in `sandbox.md`.

## TTY Spinner Header UX

Add a Ruby-specific UX layer for long-running operations (e.g., image update, container start). The UX should display a spinner and task label **above** the live output of subcommands.

### Requirements

- Only activate when stdout is a TTY. If not, fall back to plain text status lines.
- Spinner line must update in place and remain **above** subcommand output.
- Task label must be updateable between phases (e.g., "Updating image" → "Starting container").
- Subcommand output must remain visible and unmodified, including interactive progress bars.
- When a phase completes or fails, the spinner must stop cleanly and leave the cursor below output.
- Spinner animation should match the cfg spec: bouncing dots (⣾⣽⣻⢿⡿⣟⣯⣷) at 10 FPS.

### Recommended Rendering Model

- Use a PTY for subcommands when spinner is active to preserve progress bars.
- Start a spinner thread that periodically updates a header line with ANSI cursor control:
  - Save cursor position
  - Move up one line
  - Clear line
  - Render `<spinner> <task>`
  - Restore cursor position
- Use a shared, thread-safe task label that can be updated at runtime.

### Failure and Cleanup

- Ensure SIGINT/SIGTERM stops the spinner, restores cursor state, and forwards signals to the subprocess.
- If the terminal is resized, the spinner should continue to update cleanly (best effort).

### Plain Output Fallback (Non-TTY)

- Print a single status line per phase without spinners.
- Preserve subcommand output order without ANSI control codes.

## Implementation Boundaries

- **Command runner:** Minimal utility that can run commands in either PTY or standard IO mode and stream output without buffering issues.
- **Spinner:** Separate, reusable component used by orchestrator for long-running phases.
- **Logging:** Keep UX output and errors consistent with existing Bash behavior.

## Testing Notes

- Add tests for backend selection logic (explicit flag, existing running backend, default path).
- Add tests for naming rules (sanitization).
- Add integration tests for spinner behavior when stdout is/is not a TTY (best effort).

## References

- [Sandbox spec](sandbox.md)
- [Sandbox common library](sandbox-common.md)
- [Container backend](sandbox-container.md)
- [KVM backend](sandbox-kvm.md)
- [Proxy backend](sandbox-proxy.md)
- [AI bootstrap](sandbox-ai-bootstrap.md)
