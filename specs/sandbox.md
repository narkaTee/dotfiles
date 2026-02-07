# Sandbox Tool

## Overview

The sandbox command orchestrates isolated development environments with pluggable backend support. It provides a unified interface for starting, stopping, and accessing sandboxes regardless of the underlying isolation technology (containers or VMs). Sandbox includes IDE integration for VS Code and IntelliJ IDEA, making it easy to connect development tools to isolated environments.

## Key Constraints & Design Decisions

- **Backend abstraction**: All backends implement common interface (`backend_start`, `backend_stop`, `backend_enter`, `backend_is_running`, `backend_get_ssh_port`, `backend_get_ip`)
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
sandbox --hcloud

# Select hcloud server type interactively
sandbox --hcloud --select

# Add network isolation via proxy
sandbox --proxy

# Bootstrap with AI agent credentials
sandbox --agents claude
```

**IDE integration:**
```bash
# Open in VS Code Remote SSH
sandbox code

# Open in IntelliJ IDEA via JetBrains Gateway
sandbox idea

# Open in new Alacritty terminal with tmux
sandbox tmux
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

**Sync commands** (cloud backends only):
```bash
# Upload current directory to sandbox
sandbox sync up

# Download from sandbox to current directory
sandbox sync down
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
- Alacritty terminal emulator for `sandbox tmux` command

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
- Common library: [sandbox-common.md](sandbox-common.md)
- Container backend: [sandbox-container.md](sandbox-container.md)
- KVM backend: [sandbox-kvm.md](sandbox-kvm.md)
- Hetzner Cloud backend: [sandbox-hcloud.md](sandbox-hcloud.md)
- Proxy backend: [sandbox-proxy.md](sandbox-proxy.md)

**AI agent bootstrapping:**
- AI Agent bootstrapping is done via [sandbox-ai-bootstrap.md](sandbox-ai-bootstrap.md)

**SSH agent forwarding:**
Extracts public keys from host SSH agent and injects into sandbox for passwordless authentication.

**Connection info abstraction:**
- `backend_get_ssh_port()`: Returns SSH port (dynamic for container/KVM, always 22 for hcloud)
- `backend_get_ip()`: Returns IP address (localhost for container/KVM, public IPv4 for hcloud)

**IDE URL schemes:**
- VS Code: `vscode://vscode-remote/ssh-remote+<host>/home/dev/workspace`
- IntelliJ: `jetbrains://gateway/ssh/environment?h=<host>&launchIde=true&ideHint=IU&projectHint=/home/dev/workspace`

**Terminal integration (`sandbox tmux`):**
- **Terminal emulator**: Hardcoded to Alacritty (fails with error if not installed)
- **Terminal title**: is set to the same values as the shell function `auto_update_term_tittle` in `sh/setup/helper_functions.sh` would do
- **Execution mode**: Background/detached (non-blocking, returns immediately)
- **tmux behavior**: Attach to existing session or create new (`tmux new-session -A`)
- **Session naming**: Default/auto-generated (no explicit session name)
- **Working directory**: Starts in `/home/dev/workspace`
- **SSH connection**: Uses SSH alias if available, otherwise IP+port connection (`backend_get_ip()` and `backend_get_ssh_port()`) with same options as `backend_enter`
- **Error handling**: Shows clear error message and exits if Alacritty not found

**Nested sandbox prevention:**
Sets `$SANDBOX_CONTAINER` environment variable inside sandboxes to prevent recursive sandboxing.

**Workspace synchronization (`sandbox sync`):**
- **Availability**: Cloud backends only (hcloud); errors on container/KVM backends with helpful message
- **Backend detection**: Checks backend name; container/KVM use bind mounts so sync is unnecessary
- **Commands**:
  - `sandbox sync up` - Upload current directory → `/home/dev/workspace` (mirror mode)
  - `sandbox sync down` - Download `/home/dev/workspace` → current directory (mirror mode)
- **Rsync behavior**: Uses `rsync -hzav --no-o --no-g --delete` for destructive mirror:
  - `-h` - Human-readable output
  - `-z` - Compress file data during transfer
  - `-a` - Archive mode (recursive, preserve permissions, timestamps, etc.)
  - `-v` - Verbose output
  - `--no-o` - Do not preserve ownership (prevents errors on systems with different users)
  - `--no-g` - Do not preserve group (prevents errors on systems with different groups)
  - `--delete` - Delete files in destination that don't exist in source (mirror mode)
- **SSH connection**: Uses SSH alias if available, otherwise IP-based connection (`backend_get_ip()`) with same options as `backend_enter`
- **Prerequisites**: Sandbox must be running; errors if not started
- **No backend changes**: Implemented in main sandbox script using existing SSH connectivity
- **Error handling**: Clear error if called on bind-mount backends (container/KVM/proxy)
