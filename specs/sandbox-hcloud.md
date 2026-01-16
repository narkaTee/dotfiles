# Sandbox Hetzner Cloud Backend

## Overview

The Hetzner Cloud backend provides cloud-based development sandboxes using Hetzner Cloud VMs with ephemeral lifecycle and direct SSH access. Unlike local backends (container/KVM), this backend provisions VMs on Hetzner's infrastructure, enabling cloud-based development with the same sandbox UX. VMs are completely destroyed on stop, ensuring no costs when not in use.

## Key Constraints & Design Decisions

- **Requires hcloud CLI**: Must have `hcloud` command installed and authenticated
- **1Password CLI auto-detection**: Automatically uses `op plugin run -- hcloud` if configured
- **Ephemeral VMs**: VMs destroyed on stop - no persistent cloud state, no costs when stopped
- **Hardcoded region**: All VMs created in nbg1 (Nuremberg) datacenter
- **Debian 13 base**: Uses Hetzner's stock debian-13 image with cloud-init provisioning
- **Direct SSH access**: Connects to VM's public IP on port 22 (no port forwarding)
- **Security hardening**: VMs provisioned with UFW firewall and sshguard
- **Dotfiles auto-provisioning**: Automatically clones and configures dotfiles repo during VM initialization
- **Hostname-prefixed naming**: VMs named `{hostname}-sandbox-{project}` to avoid conflicts
- **Optional workspace sync**: Rsync only when `--sync` flag specified
- **State persistence on errors**: Failed stop operations preserve local state for retry

## Usage

**Starting a Hetzner Cloud sandbox:**
```bash
# From main sandbox command
sandbox --hcloud

# With workspace rsync
sandbox --hcloud --sync
```

**Direct backend functions** (called by main sandbox script):
```bash
# Check if VM is running
is_hcloud_running sandbox-myproject

# Get SSH port (always 22)
get_hcloud_ssh_port sandbox-myproject

# Start Hetzner Cloud VM
start_hcloud_sandbox sandbox-myproject

# Destroy VM and cleanup
stop_hcloud_sandbox sandbox-myproject

# List all running hcloud sandboxes
list_hcloud_sandboxes

# Stop all hcloud sandboxes
stop_all_hcloud_sandboxes
```

**VM characteristics:**
- Full Debian 13 system with systemd
- Root access via sudo
- Workspace at `/home/dev/workspace` (empty unless `--sync` used)
- SSH access via public IP
- UFW firewall enabled (deny incoming except SSH, allow outgoing)
- sshguard active for SSH brute-force protection
- ssh access for root disabled

## Dependencies

- hcloud CLI: `hcloud` command for Hetzner Cloud API
- Authentication: HCLOUD_TOKEN environment variable or hcloud context configured
- 1Password CLI (optional): `op` command for secure credential injection
- rsync: For `--sync` flag functionality
- SSH client: For connecting to VMs

## Configuration

**1Password CLI integration:**
- Detection on first hcloud command: Check if `~/.config/op/plugins/used_items/hcloud.json` exists
- If detected, create `use_op` flag file in state directory
- All subsequent `hcloud` commands wrapped: `op plugin run -- hcloud ...`
- **Account auto-detection**: Reads `account_id` from `hcloud.json` array entries
- Account ID passed via `--account` flag: `op --account <id> plugin run -- hcloud ...`
- If multiple accounts in JSON, uses first entry's `account_id`
- Falls back to no account flag if parsing fails or file is malformed
- Detection runs once per sandbox lifecycle
- No user configuration required - fully automatic
- Uses op plugin system designed for CLI tool credential injection
- Non-invasive detection: Simple file existence check, no commands executed

**VM resources (hardcoded):**
- Server type: CX23 (can be overridden via HCLOUD_SERVER_TYPE, to allow larger workloads)
- Location: nbg1 (Nuremberg) (hardcoded)
- Image: debian-13 (hardcoded)

**VM naming:**
- Format: `{hostname}-sandbox-{project}`
- Hostname: From `hostname -s` command
- Project: From `basename "$PWD"` with non-alphanumeric → underscore
- Example: `myhost-sandbox-myproject`

## State Management

**Philosophy**: Filesystem state is authoritative for reads; API calls reserved for writes.

**State files** via `backend_state_dir "hcloud"`:
- `server.id` - Hetzner server ID (presence = VM may exist)
- `server.ip` - Public IPv4 for SSH connections
- `created.timestamp` - Unix timestamp of creation

**Read operations** (no API calls):
- Backend detection, status checks, port queries, listing sandboxes
- All check filesystem only, assume running if state directory exists

**Write operations** (API calls required):
- `start_hcloud_sandbox()` - Verify VM doesn't exist, create if needed
- `stop_hcloud_sandbox()` - Delete VM, cleanup state on success only

**Stale state handling**:
- VM deleted externally → stop fails, user runs `rm -rf ~/.cache/sandbox/hcloud-vms/<name>/`
- VM deleted then restarted → start detects conflict, warns user, creates new VM and updates state
- Failed stop preserves state for retry (avoids lost cost tracking)
- List may show stale entries - acceptable for non-critical operation

## Integration Points

**Common library usage** (see [sandbox-common.md](sandbox-common.md)):

**SSH configuration:**
- Uses host SSH agent keys (injected via cloud-init user-data)
- Creates SSH alias in `~/.ssh/config.d/` if available
- Direct connection to public IP on port 22

**Workspace sync:**
- Only when `--sync` flag specified
- One-way sync: local → VM
- Command: `rsync -av --delete` from current directory to `/home/dev/workspace`
- Runs after VM boot, before entering shell

**Cloud-init provisioning:**
- SSH keys injected from host SSH agent
- Packages: ufw, sshguard, rsync, git, rake, curl, wget, vim, htop, build-essential, zsh, jq, unzip, zip, fzf
- UFW configured: deny incoming, allow outgoing, allow SSH
- sshguard enabled for SSH protection
- User `dev` created with sudo NOPASSWD
- Dotfiles repo (https://github.com/narkaTee/dotfiles.git) cloned and configured (`rake`) automatically
- Development tools pre-warmed for faster first use via this bash script: https://raw.githubusercontent.com/narkaTee/bootstrap-ws/refs/heads/main/sandbox/pre-warm-tools.sh

## Testing

**Success criteria:**
1. **VM lifecycle**: Start creates VM with SSH access, stop destroys VM and cleans state, no Hetzner costs when stopped
2. **1Password plugin auto-detection**: Automatically detects and uses `op plugin run` when `hcloud.json` exists, extracts account ID correctly, falls back gracefully on errors
3. **Workspace sync**: `--sync` flag syncs local files to `/home/dev/workspace`, without flag workspace is empty
4. **Stale state handling**: VM deleted externally allows restart with warning, failed stop preserves state for retry
5. **Multiple sandboxes**: Different projects run simultaneously with unique names and IPs, independent lifecycle management
