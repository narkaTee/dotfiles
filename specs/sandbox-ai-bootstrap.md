# Sandbox AI Bootstrap

## Overview

The AI bootstrap library configures AI agent environments inside sandboxes by copying credentials from the host, patching prompt files with environment-specific constraints, and installing the agent CLI tools. It supports Claude Code, Gemini CLI, and OpenCode agents, ensuring they receive accurate context about sandbox limitations (network restrictions, git access, system constraints) via the prompt-patcher library.

## Key Constraints & Design Decisions

- **Host credential reuse**: Copies API keys and settings from host's `~/.claude`, `~/.gemini`, or `~/.config/opencode` directories
- **Environment-aware prompts**: Uses prompt-patcher to inject blocks based on `$BACKEND` and `$PROXY` variables
- **Temporary staging**: Builds config in `/tmp`, uploads via SCP, then cleans up
- **SSH-based upload**: Uses either SSH alias or port-based connection (same logic as `sandbox` command)
- **Automatic installation**: Installs/updates agent npm packages after config upload
- **Minimal onboarding**: Creates `.claude.json` to skip initial setup dialogs
- **Security considerations**: Gemini OAuth credentials intentionally not copied (commented out) due to revocation concerns

## Usage

**Invoked automatically by sandbox command:**
```bash
# Bootstrap Claude Code agent on sandbox start
sandbox --agent claude

# Bootstrap with specific backend and proxy
sandbox --kvm --proxy --agent gemini
```

**Direct function usage** (when sourced):
```bash
source ~/.config/lib/bash/sandbox/ai-bootstrap

# Bootstrap an agent for a running sandbox
bootstrap_ai "sandbox-myproject" "claude"
```

## Supported Agents

| Agent | Config Source | Config Target | Prompt File | NPM Package |
|-------|--------------|---------------|-------------|-------------|
| `claude` | `~/.claude/settings.json` | `~/.claude/` | `CLAUDE.md` | `@anthropic-ai/claude-code` |
| `gemini` | `~/.gemini/.env` | `~/.gemini/` | `GEMINI.md` | `@google/gemini-cli` |
| `opencode` | `~/.config/opencode/opencode.jsonc` | `~/.config/opencode/` | `AGENT.md` | `opencode-ai` |

## Configuration Behavior

**Claude Code (`build_claude_config`):**
1. Creates `~/.claude/` directory
2. Copies `settings.json` from host (or uses `optpl` template if available)
3. Creates `.claude.json` with `hasCompletedOnboarding: true` to skip setup
4. Patches `CLAUDE.md` with blocks using [prompt-patcher](prompt-patcher.md)

**Gemini (`build_gemini_config`):**
1. Creates `~/.gemini/` directory
2. Copies `.env` file from host
3. Does NOT copy `oauth_creds.json` (security concern)
4. Patches `GEMINI.md` with blocks using [prompt-patcher](prompt-patcher.md)

**OpenCode (`build_opencode_config`):**
1. Creates `~/.config/opencode/` directory
2. Copies `opencode.jsonc` from host (or uses `optpl` template if available)
3. Patches `AGENT.md` with blocks using [prompt-patcher](prompt-patcher.md)

## Prompt Patching Logic

The `patch_prompt_file` function dynamically selects blocks based on sandbox configuration. Default blocks (`communication`, `conventions`) are automatically injected by the prompt-patcher library.

### Blocks

See [prompt-patcher.md](prompt-patcher.md) for details on available blocks.

Backend-specific blocks:

- container backend: `sandbox-container`
- kvm and hcloud backend: `sandbox-vm`

Proxy restrictions:

- `proxy-restrictions` (when `$PROXY=true`)


## Dependencies

**Required:**
- Bash shell
- SSH client (`ssh`, `scp`)
- [prompt-patcher library](prompt-patcher.md)
- [sandbox-common library](sandbox-common.md) (for `is_ssh_alias_setup`, `backend_get_ssh_port`)
- Running sandbox with SSH access

**Optional:**
- `optpl` command for config templates (falls back to copying existing files)

**Runtime (installed by bootstrap):**
- Node.js and npm (must be available in sandbox)
- Internet access to npmjs.org (or allowlisted mirror)

## Integration Points

**Called by sandbox script** (bash/bin/sandbox):
- Sources ai-bootstrap when `--agent` flag is provided
- Validates agent name with `ensure_know_agent`
- Calls `bootstrap_ai` after sandbox start, before entering shell

**Uses prompt-patcher library**:
- Sources at startup (ai-bootstrap)
- Calls `replace_all_prompt_blocks` to inject environment-specific documentation

**Uses sandbox-common library**:
- `is_ssh_alias_setup()` to check for SSH alias
- `backend_get_ssh_port()` to get SSH port for SCP upload

**Environment variables consumed:**
- `$BACKEND` - Determines which sandbox constraint blocks to inject
- `$PROXY` - Controls proxy-restrictions block injection

**Installation process:**
1. Sources host environment setup scripts (`~/.config/setup/tools.sh`, `~/.config/setup/env.sh`)
2. Runs `npm -g install <package>` to install/update agent
3. Assumes sandbox has Node.js/npm pre-installed

## Error Handling

**Agent validation:**
- Exits with error if agent not in `{claude, gemini, opencode}` list
- Displays "Unknown agent" message to stderr

**SSH connection failures:**
- Exits if neither SSH alias nor SSH port can be determined
- Clear error message: "Could neither find a SSH alias nor a SSH port for sandbox $name"

**Missing source configs:**
- No explicit error checking for missing host config directories
- Falls back to `optpl` for Claude/OpenCode if `settings.json`/`opencode.jsonc` missing
- May fail during npm install if credentials not properly configured
