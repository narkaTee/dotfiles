# AI Agent Specifications

## Overview

Centralized metadata for supported AI coding agents (Claude Code, Gemini CLI, OpenCode). This spec defines configuration paths, credential file locations, and tool-specific details used by [ai-bootstrap](sandbox-ai-bootstrap.md) and [ai-jail](boxed-ai-jail.md).

## Supported Agents

| Agent | Config Dir/Files | cfg Name | Prompt File | NPM Package |
|-------|-----------|----------|-------------|-------------|
| `claude` | `~/.claude/`, `~/.claude.json` | `claude` | `CLAUDE.md` | `@anthropic-ai/claude-code` |
| `gemini` | `~/.gemini/` | `gemini` | `GEMINI.md` | `@google/gemini-cli` |
| `opencode` | `~/.config/opencode/` | `opencode` | `AGENT.md` | `opencode-ai` |

## Install commands

### Claude

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

### Gemini

```bash
npm -g install @google/gemini-cli
```

### opencode

```bash
npm -g install opencode-ai
```

## Credential Files (Require tmpfs Isolation)

Files containing secrets that must not persist to disk after the sandboxed environment exited.
The files might be created by [cfg](cfg.md) when Credentials Injection is used.

**Claude**
- `~/.claude/settings.json` - API key and authentication (exported by cfg)
- `~/.claude.json` - User preferences including onboarding state (may be exported by cfg, requires special handling - see below)

**Gemini**
- `~/.gemini/oauth_creds.json` - OAuth credentials (exported by cfg)

**opencode**
- `~/.config/opencode/opencode.jsonc` - API key and config (exported by cfg)

## Special Handling Requirements

### Claude `~/.claude.json` Patching

The `~/.claude.json` file requires special handling to skip onboarding dialogs. Both [ai-bootstrap](sandbox-ai-bootstrap.md) and [ai-jail](boxed-ai-jail.md) MUST implement this logic identically.

**Requirements:**
- File location: `~/.claude.json` or the corresponding staging directory
- Must contain `hasCompletedOnboarding: true` to skip initial setup
- Should contain `theme: "dark"` for consistent UX
- May be exported by cfg profile or may not exist
- Must preserve other fields if cfg exports the file

**Implementation pattern:**
```bash
claude_json="$target_dir/.claude.json"
if [ ! -f "$claude_json" ] || ! jq -e '.hasCompletedOnboarding == true' "$claude_json" >/dev/null 2>&1; then
    if [ -f "$claude_json" ]; then
        # File exists but missing required fields - merge them in
        jq '. + {hasCompletedOnboarding: true, theme: "dark"}' "$claude_json" > "${claude_json}.tmp" && mv "${claude_json}.tmp" "$claude_json"
    else
        # File doesn't exist - create from scratch
        cat > "$claude_json" <<'EOF'
{
  "theme": "dark",
  "hasCompletedOnboarding": true
}
EOF
    fi
fi
```

## Key Constraints

**Credential isolation:**
- Credential files contain secrets and must be isolated to tmpfs in sandboxed environments or when running on ephemeral contains/vms it is okay to keep them on the fs (it will be delete after usage anyway).
- State files can persist to overlay layers for continuity between sessions
- [cfg tool](cfg.md) uses the "cfg Name" column value for profile selection and export operations

**Config generation:**
- All agents support cfg-based credential injection via `cfg <profile> --export-file <credential file>`
- Abort the start of the sandbox when profile selection cancelled
- Environment variables exported via `cfg <profile> --export-env`

**Prompt patching:**
- All agents use [prompt-patcher](prompt-patcher.md) library to inject environment-specific blocks
- Prompt files stored in agent's config directory
