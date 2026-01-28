# boxed ai-jail Profile

## Overview

The `ai-jail` profile creates a development sandbox specifically designed for running AI coding agents (Claude, Gemini, etc.) with reduced risk of accidental system damage. Uses overlay filesystems to isolate agent configuration changes per-project and integrates with prompt-patcher to inject sandbox environment notices into agent prompts.

## Usage

```bash
# Run Claude in sandbox
boxed ai-jail claude

# Run with 1Password credential injection
boxed ai-jail claude  # optpl runs automatically if configured

# Interactive shell to inspect environment
boxed --shell ai-jail bash
boxed -s ai-jail bash
```

## What This Profile Enables

### Filesystem Access

- **Current directory**: Bound read-write via `feature_bind_pwd`
- **Git repository**: `.git` bound read-only via `feature_bind_pwd_git_ro` (prevents accidental commits)
- **Vim configuration**: `~/.vim/` bound read-only if exists
- **All PATH directories**: Binds all executable directories from $PATH
- **npm globals**: Global npm packages bound read-only
- **Claude shared data**: `~/.local/share/claude/` bound read-only if exists

### Agent Configuration Isolation

Uses **overlay filesystem** to create per-project isolated agent configs:

- **Lower layer**: Original `~/.claude/` (or `~/.gemini/`, etc.) mounted read-only
- **Upper layer**: `~/{tool}-jail-overlay-{project}/upper-rw/` for modifications
- **Result**: Agent sees a writable config directory, but changes don't affect the original

Supported tools: `claude`, `gemini`, `opencode`

### Prompt Injection

Automatically patches agent prompt files with sandbox environment notices:

- **Blocks injected**: `sandbox-bwrap`, `git-readonly`
- **Auto-cleanup**: Removes obsolete prompt blocks on each run
- **Tool-specific**: Uses correct prompt filename per agent (e.g., `CLAUDE.md`)

### Network & Environment

- **Network enabled**: Full network access via `feature_network`
- **EDITOR preserved**: Passes through `$EDITOR` environment variable

### Credential Injection

- **optpl integration**: Automatically runs `optpl {tool_name}` if template is configured
- Allows agents to access credentials from 1Password without exposing the entire vault

## Use Cases

- Running AI agents in "auto mode" or "yolo mode" with reduced supervision
- Testing new MCP servers or agent capabilities safely
- Allowing agents to explore and modify code without risk of committing changes
- Multi-project workflows where each project should have isolated agent state

## Threat Model

### Protected Against

- Accidental file deletion or modification outside project directory
- Unintended git commits, branch changes, or repository corruption
- Agent writing to shared config files that affect other projects
- System-wide package or tool modifications
- Credentials theft is limited as the home directory is not mounted completely
