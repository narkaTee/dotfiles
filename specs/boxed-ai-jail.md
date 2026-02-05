# boxed ai-jail Profile

## Overview

The `ai-jail` profile creates a development sandbox specifically designed for running AI coding agents (Claude, Gemini, etc.) with reduced risk of accidental system damage. Scopes agent configuration per-project and integrates with prompt-patcher to inject custom prompts into agent prompt files.

## Usage

```bash
# Run Claude in sandbox
boxed ai-jail claude

# Run with cfg credential injection
boxed ai-jail claude  # cfg profile selection runs automatically

# Interactive shell to inspect environment
boxed --shell ai-jail bash
boxed -s ai-jail bash
```

## Key Design Principles

- **Bwrap constraints**: All filesystem setup via bwrap args before container starts (no post-exec modifications)
- **Credential isolation and Protection**: Ephemeral credentials in tmpfs, and files known to contains credentials mounted to tmpfs proactively
- **Per-project Agent Configuration directory**: Separate tool directories for each project: `~/.boxed-{project}/{tool}`

## What This Profile Enables

### Filesystem Access

- **Current directory**: Bound read-write via `feature_bind_pwd`
- **Git repository**: `.git` bound read-only via `feature_bind_pwd_git_ro` (prevents accidental commits)
- **Vim configuration**: `~/.vim/` bound read-only if exists
- **All PATH directories**: Binds all executable directories from $PATH
- **npm globals**: Global npm packages bound read-only
- **Claude shared data**: `~/.local/share/claude/` bound read-only if exists

### Agent Configuration Isolation

Uses a simple rw mount to create per-project isolated agent configs:

#### Example

Given a project name 'dotfiles' and starting claude inside the sandbox.

1. If it does not exist on the host `~/.boxed-dotfiles/.claude` will be created.
2. Adds a bwrap mount `~/.boxed-dotfiles/.claude` to `~/.claude`
3. Credential Injecton & Protection happens and makes sure they stay isolated

**Isolation strategy:**
- Simple mount to extra directory
- Credentials are protected via Credential Injection & Protection chapter

For supported tools see [agents.md](agents.md).

### Credential Injection & Protection

See [agents.md](agents.md) for agent metadata and credential file locations.

Uses [cfg](cfg.md) for secure credential injection when profiles exist.

**Tool-specific initialization:**
- Claude: Ensures `~/.claude.json` has required fields to skip first-run setup (see [agents.md](agents.md) Special Handling for implementation)

**Flow:**
1. Check if cfg profiles exist via `cfg --has-profiles {cfg Name}`
2a. **If no profiles exist**: Skip credential injection, continue with protection mode
2b. **If profiles exist**: Run `cfg --select {cfg Name}` to select profile (abort if cancelled), returns selected profile name
3. Create temp directory: `mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/boxed-creds.XXXXXX"`
4. Export credential files via `cfg <selected-profile> --export-file <credentials-file>` to temp directory
5. Ensure credential file paths exist in tmpdir (create empty files if cfg didn't export them, see [agents.md](agents.md) for credential paths)
6. Export environment variables via `cfg <selected-profile> --export-env` and pass to bwrap `--setenv`
7. Bind credential paths into container via bwrap `--bind` (always bound, even if empty)
8. Cleanup: trap removes temp directory on exit

**Modes:**
- **With credentials**: tmpfs credentials when cfg profiles exist
- **protection only**: Just create empty credentials files and mount to sandbox

**Security properties:**
- Credentials in user-scoped tmpfs (`$XDG_RUNTIME_DIR`, RAM-backed), fallback to `/tmp`
- Temp directory created with mktemp (prevents race conditions)
- Credential file paths **always** bound to tmpfs (even if empty) to prevent leakage
- Credential files writable (agents can update tokens, settings) but ephemeral (cleanup on exit)
- No credential leakage to persistent storage

### Prompt Injection

Automatically patches agent prompt files with sandbox environment notices:

- **Blocks injected**: `sandbox-bwrap`, `git-readonly`
- **Auto-cleanup**: Removes obsolete prompt blocks on each run
- **Tool-specific**: Uses correct prompt filename per agent (see [agents.md](agents.md) for tool → prompt file mapping)

### Network & Environment

- **Network enabled**: Full network access via `feature_network`
- **EDITOR preserved**: Passes through `$EDITOR` environment variable

## Use Cases

- Running AI agents in "auto mode" or "yolo mode" with reduced supervision
- Testing new MCP servers or agent capabilities safely
- Allowing agents to explore and modify code without risk of committing changes
- Multi-project workflows where each project should have isolated agent state
- Multi-credential workflows where different profiles maintain separate agent state

## Threat Model

### Protected Against

- Accidental file deletion or modification outside project directory
- Unintended git commits, branch changes, or repository corruption
- Agent writing to shared config files that affect other projects
- System-wide package or tool modifications
- Credential leakage to disk (tmpfs-backed credential injection)
- Credential persistence between sessions (auto-cleanup on exit)
