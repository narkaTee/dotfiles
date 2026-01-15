# Sandbox Tool

## Overview

The sandbox command orchestrates isolated development environments with pluggable backend support. It provides a unified interface for starting, stopping, and accessing sandboxes regardless of the underlying isolation technology (containers or VMs). Sandbox includes IDE integration for VS Code and IntelliJ IDEA, making it easy to connect development tools to isolated environments.

## Key Constraints & Design Decisions

- **Backend abstraction**: All backends implement common interface (`backend_start`, `backend_stop`, `backend_enter`, `backend_is_running`, `backend_get_ssh_port`)
- **Automatic backend detection**: If no flag specified, detects which backend is already running for current directory
- **Directory-based naming**: Sandbox name derived from current directory basename (sanitized for container/VM naming)
- **Single backend per sandbox**: Prevents conflicts by ensuring only one backend runs per sandbox name
- **SSH-based access**: All backends provide SSH connectivity, enabling IDE remote development features
- **Optional SSH alias**: Creates `~/.ssh/config.d/` entries for simplified connection (enables JetBrains Gateway)
- **Proxy wrapping**: Proxy is not a backend itself, it wraps container/KVM backends to add network filtering
- **AI agent bootstrap**: Optional injection of AI agent credentials after sandbox start

## Usage

**Basic operations:**
```bash
# Start/enter sandbox (auto-detects backend or uses container default)
sandbox

# Explicitly choose backend
sandbox --kvm
sandbox --container

# Add network isolation via proxy
sandbox --proxy

# Bootstrap with AI agent credentials
sandbox --agent claude
```

**IDE integration:**
```bash
# Open in VS Code Remote SSH
sandbox code

# Open in IntelliJ IDEA via JetBrains Gateway
sandbox idea
```

**Management commands:**
```bash
# Show SSH connection details
sandbox info

# List all running sandboxes (both backends)
sandbox list

# Stop current directory's sandbox
sandbox stop

# Stop all sandboxes
sandbox stop -a
```

**Proxy commands** (delegated to proxy backend):
```bash
sandbox proxy allow <domain>
sandbox proxy block <domain>
sandbox proxy list
sandbox proxy log [-f]
sandbox proxy reset
```

## Dependencies

**Core requirements:**
- Bash shell
- SSH client and agent
- At least one backend installed (see backend specs)

**Optional:**
- `~/.ssh/config.d/` directory for SSH aliases
- VS Code for `sandbox code` command
- JetBrains Gateway for `sandbox idea` command

## Configuration

**Backend selection logic:**
1. If `--kvm` or `--container` flag specified: use that backend
2. Else if sandbox already running for current directory: detect and use its backend
3. Else: default to container backend

**Sandbox naming:**
Derived from current directory: `sandbox-$(basename "$PWD")` with non-alphanumeric chars replaced by underscores.

**SSH alias setup:**
If `~/.ssh/config.d/` exists:
- Creates `alias-<name>.conf` with host entry
- Sets `StrictHostKeyChecking=no` and `UserKnownHostsFile=/dev/null`
- Removed automatically on sandbox stop

## Integration Points

**Backend implementations:**
- Container backend: [sandbox-container.md](sandbox-container.md)
- KVM backend: [sandbox-kvm.md](sandbox-kvm.md)
- Proxy backend: [sandbox-proxy.md](sandbox-proxy.md)

**SSH agent forwarding:**
Extracts public keys from host SSH agent and injects into sandbox for passwordless authentication.

**IDE URL schemes:**
- VS Code: `vscode://vscode-remote/ssh-remote+<host>/home/dev/workspace`
- IntelliJ: `jetbrains://gateway/ssh/environment?h=<host>&launchIde=true&ideHint=IU&projectHint=/home/dev/workspace`

**Nested sandbox prevention:**
Sets `$SANDBOX_CONTAINER` environment variable inside sandboxes to prevent recursive sandboxing.

## Testing

**Backend selection:**
1. Start container sandbox in directory A
2. Run `sandbox` (no flags) - should enter existing container sandbox
3. Run `sandbox --kvm` - should error (conflict: container already running)
4. Stop sandbox, run `sandbox --kvm` - should start KVM sandbox
5. In directory B, run `sandbox` - should start new container sandbox (default)

**SSH configuration:**
1. Start sandbox with `~/.ssh/config.d/` present
2. Verify alias file created: `~/.ssh/config.d/alias-sandbox-<name>.conf`
3. Test connection: `ssh sandbox-<name>`
4. Stop sandbox - alias file should be removed
5. Start sandbox without `~/.ssh/config.d/` - should work without aliases (use direct port)

**IDE integration:**
1. Start sandbox, run `sandbox code`
2. Verify VS Code opens with Remote SSH connection
3. Verify workspace opened at `/home/dev/workspace`
4. Run `sandbox idea` - JetBrains Gateway should open
5. Test both with and without SSH aliases configured

**Sandbox lifecycle:**
1. Fresh directory with no sandbox - `sandbox` starts new one
2. Sandbox running - `sandbox` enters existing
3. `sandbox info` shows SSH port and backend type
4. `sandbox list` shows sandbox in list
5. `sandbox stop` terminates sandbox
6. `sandbox list` no longer shows sandbox

**Conflict detection:**
1. Start container sandbox in directory
2. Try `sandbox --kvm` - should fail with clear error
3. Stop container, start KVM
4. Try `sandbox --container` - should fail with clear error

**AI agent bootstrap:**
1. Set appropriate API key environment variable on host
2. Run `sandbox --agent claude`
3. Inside sandbox, verify API key available in environment
4. Test for each supported agent: `claude`, `gemini`, `opencode`

**Proxy integration:**
1. Start with `sandbox --proxy`
2. Verify proxy commands work: `sandbox proxy list`
3. Inside sandbox, verify network restricted to allowlist
4. Stop sandbox - proxy container should stop too
