# Sandbox Hetzner Cloud Backend

## Overview

The Hetzner Cloud backend provides cloud-based development sandboxes using Hetzner Cloud VMs with ephemeral lifecycle and direct SSH access. Unlike local backends (container/KVM), this backend provisions VMs on Hetzner's infrastructure, enabling cloud-based development with the same sandbox UX. VMs are completely destroyed on stop, ensuring no costs when not in use.

## Key Constraints & Design Decisions

- **Requires hcloud CLI**: Must have `hcloud` command installed and authenticated
- **1Password CLI auto-detection**: Automatically uses `op plugin run -- hcloud` if configured
- **Ephemeral VMs**: VMs destroyed on stop - no persistent cloud state, no costs when stopped
- **Fixed server type**: Uses CX21 (2 vCPU, 4GB RAM) hardcoded for consistency
- **Hardcoded region**: All VMs created in nbg1 (Nuremberg) datacenter
- **Debian 13 base**: Uses Hetzner's stock debian-13 image with cloud-init provisioning
- **Direct SSH access**: Connects to VM's public IP on port 22 (no port forwarding)
- **Security hardening**: VMs provisioned with UFW firewall and sshguard
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
- Detection runs once per sandbox lifecycle
- No user configuration required - fully automatic
- Uses op plugin system designed for CLI tool credential injection
- Non-invasive detection: Simple file existence check, no commands executed

**VM resources (hardcoded):**
- Server type: CX21
- Memory: 4GB
- CPUs: 2 vCPUs
- Location: nbg1 (Nuremberg)
- Image: debian-13

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
- Packages: ufw, sshguard, rsync, git, curl, vim, build-essential
- UFW configured: deny incoming, allow outgoing, allow SSH
- sshguard enabled for SSH protection
- User `dev` created with sudo NOPASSWD

## Testing

**Requirements verification:**
1. Check `hcloud` command available
2. Verify authentication: `hcloud context active` succeeds
3. Verify rsync installed (for `--sync` flag)

**VM lifecycle:**
1. Start hcloud sandbox - should create VM and boot in 30-60 seconds
2. Verify VM exists in Hetzner console
3. Verify SSH connection works without password
4. Inside VM, verify `/home/dev/workspace` exists (empty)
5. Stop sandbox - VM should be destroyed
6. Verify VM no longer in Hetzner console
7. Verify local state cleaned up

**Workspace sync:**
1. Create test files in local directory
2. Start with `--sync` flag
3. SSH to VM, verify files present in `/home/dev/workspace`
4. Stop sandbox
5. Start without `--sync` - workspace should be empty

**Multiple sandboxes:**
1. Start sandbox in directory A
2. Start sandbox in directory B
3. Verify both VMs running with different names
4. `sandbox list` shows both with correct IPs
5. Stop from directory A - only that VM destroyed
6. Stop from directory B - remaining VM destroyed

**Error handling:**
1. Start sandbox, manually delete VM in Hetzner console
2. Run `sandbox` - should detect missing VM and allow restart
3. Start sandbox, disconnect internet
4. Run `sandbox stop` - should fail with error
5. Verify local state preserved
6. Restore internet, retry `sandbox stop` - should succeed

**SSH alias:**
1. Ensure `~/.ssh/config.d/` exists
2. Start hcloud sandbox
3. Verify alias file created
4. Test `ssh sandbox-<name>` works
5. Stop sandbox - alias file removed

**Authentication:**
1. Test with HCLOUD_TOKEN environment variable set
2. Test with hcloud CLI context configured
3. Test with no authentication - should fail with helpful message

**1Password CLI integration:**
1. With `op plugin` configured for hcloud:
   - Backend detects via file existence: `~/.config/op/plugins/used_items/hcloud.json`
   - All `hcloud` commands run via `op plugin run -- hcloud ...`
   - Verify VM creation works with op-managed credentials
2. Without `op` configured:
   - Falls back to normal hcloud authentication
   - Behavior identical to non-op flow
3. Detection mechanism:
   - Check if `~/.config/op/plugins/used_items/hcloud.json` exists
   - Does NOT require `op` command to be available
   - Does NOT trigger authentication prompts or user interaction
   - Pure file existence check - completely non-invasive
   - If file exists, use op plugin for all hcloud commands
   - If file doesn't exist, use hcloud directly
