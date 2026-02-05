# Sandbox AI Bootstrap

## Overview

The AI bootstrap library configures AI agent environments inside sandboxes by copying credentials from the host, patching prompt files with environment-specific constraints, and installing the agent CLI tools. It supports Claude Code, Gemini CLI, and OpenCode agents, ensuring they receive accurate context about sandbox limitations (network restrictions, git access, system constraints) via the prompt-patcher library.

## Key Constraints & Design Decisions

- **Host-side credential generation**: Uses [cfg](cfg.md) tool on the host to generate config files with resolved secrets before upload
- **No 1Password in sandbox**: Sandboxes never need 1Password CLI - all secret resolution happens on host via cfg
- **Fallback to direct copy**: If cfg profile doesn't exist, falls back to copying existing config files from host
- **Environment-aware prompts**: Uses prompt-patcher to inject blocks based on `$BACKEND` and `$PROXY` variables
- **Temporary staging**: Builds config in `$XDG_RUNTIME_DIR` (fallback to `/tmp`), uploads via SCP, then cleans up
- **SSH-based upload**: Uses either SSH alias or port-based connection (same logic as `sandbox` command)
- **Automatic installation**: Installs/updates agent CLI tools after config upload (see [agents.md](agents.md) for install commands)
- **Minimal onboarding**: Claude bootstrap ensures `~/.claude.json` has required fields to skip initial setup dialogs (see [agents.md](agents.md) for special handling requirements)
- **Security considerations**: Gemini OAuth credentials intentionally not copied (commented out) due to revocation concerns
- **Time-boxed retry mechanism**: Agent installation may fail if VM setup incomplete. Retries every 5 seconds for up to 30 seconds until successful.

## Usage

**Invoked automatically by sandbox command:**
```bash
# Bootstrap Claude Code agent on sandbox start
sandbox --agents claude

# Bootstrap Claude Code and Gemini agent on sandbox start
sandbox --agents claude,gemini

# Bootstrap with specific backend and proxy
sandbox --kvm --proxy --agents gemini
```

**Direct function usage** (when sourced):
```bash
source ~/.config/lib/bash/sandbox/ai-bootstrap

# Bootstrap an agent for a running sandbox
bootstrap_ai "sandbox-myproject" "claude"
```

## Configuration Process

For each supported agent, the bootstrap:
1. Check if cfg profiles exist via `cfg --has-profiles <agent>`
2a. **If profiles exist**: Run `cfg --select <agent>` to select profile (abort if cancelled)
2b. **If no profiles exist**: Skip cfg, fall back to copying existing config files from host `~/.claude/`, `~/.gemini/`, etc. (if they exist)
3. Creates staging directory on host: `mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/ai-bootstrap.XXXXXX"`
4. If profile selected: Generate credential files using `cfg <profile> --export-file --base-dir <staging-dir>` (exports all files with preserved paths)
5. Ensures agent-specific preference files have required fields (see [agents.md](agents.md) Special Handling for implementation):
   - Claude: Patches/creates `~/.claude.json` to ensure `hasCompletedOnboarding: true`
6. Patches agent's prompt file in staging directory with environment blocks using [prompt-patcher](prompt-patcher.md)
7. Uploads entire staging directory to sandbox home via SCP (`scp -r <staging>/.* <sandbox>:~/`)
8. If profile selected: Appends environment variables to sandbox's `~/.config/setup/env.local.sh` via SSH using `cfg <profile> --export-env`
9. Installs/updates agent CLI tool in sandbox (runs install command from [agents.md](agents.md) with retry logic)
10. Cleanup: trap removes staging directory on host exit

**Modes:**
- **With cfg credentials**: When cfg profiles exist, exports credentials and env vars via cfg
- **Fallback mode**: When no cfg profiles exist, copies existing config files from host (if available)

See [agents.md](agents.md) for agent-specific paths, credential files, and install commands.

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
- Dotfiles with `~/.config/setup/env.local.sh` hook in sandbox

**Optional:**
- [cfg](cfg.md) command for config templates (falls back to copying existing files, if they exist)
- 1Password CLI (`op`) - only needed on host if using cfg

**Runtime (installed by bootstrap):**
- Node.js and npm (must be available in sandbox)
- Internet access to npmjs.org (or allowlisted mirror)

## Integration Points

**Called by sandbox script** (bash/bin/sandbox):
- Sources ai-bootstrap when `--agents` flag is provided
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

**Installation process (runs in sandbox):**
1. Sources sandbox environment setup scripts (`~/.config/setup/tools.sh`, `~/.config/setup/env.sh`)
2. Runs install command from [agents.md](agents.md) for the specific agent
3. Retries every 5 seconds for up to 30 seconds if installation fails (VM may still be initializing)
4. Environment variables from step 8 of Configuration Process are automatically loaded when shell starts

## Error Handling

**Agent validation:**
- Exits with error if agent not in `{claude, gemini, opencode}` list
- Displays "Unknown agent" message to stderr

**SSH connection failures:**
- Exits if neither SSH alias nor SSH port can be determined
- Clear error message: "Could neither find a SSH alias nor a SSH port for sandbox $name"

**Missing source configs:**
- No explicit error checking for missing host config directories
- Falls back to `cfg` for Claude/Gemini/OpenCode if existing config files are missing
- If both cfg profile and existing config file are missing, config generation is skipped
- May fail during npm install if credentials not properly configured
