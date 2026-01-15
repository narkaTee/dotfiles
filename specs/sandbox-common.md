# Sandbox Common Library

## Overview

The common library provides shared utility functions used by all sandbox backends. These functions reduce code duplication and ensure consistent behavior across container, KVM, and Hetzner Cloud backends.

## Key Constraints & Design Decisions

- **Sourcing order:**: sandbox common is sourced at the top of the sandbox script. It's always available.
- **Backend-agnostic**: Functions work with any backend by accepting backend name as parameter
- **Consistent paths**: All backends use same directory structure under `~/.cache/sandbox/`
- **Secure defaults**: State directories created with mode 700
- **Optional parameters**: Functions use sensible defaults (e.g., localhost for SSH alias host)

## Functions

### State Directory Management

**`backend_state_dir`** - Returns the state directory path for a backend/sandbox combination.

```bash
# Usage
backend_state_dir "$backend" "$name"

# Examples
backend_state_dir "kvm" "sandbox-myproject"
# Returns: ~/.cache/sandbox/kvm-vms/sandbox-myproject

backend_state_dir "hcloud" "sandbox-myproject"
# Returns: ~/.cache/sandbox/hcloud-vms/sandbox-myproject
```

**`ensure_backend_state_dir`** - Creates state directory with secure permissions.

```bash
# Usage
ensure_backend_state_dir "$backend" "$name"

# Behavior
# - Creates directory if not exists
# - Sets mode 700 (owner only)
# - Parent directories created as needed
```

### SSH Wait Loop

**`wait_for_ssh`** - Blocks until SSH connection succeeds or timeout reached.

```bash
# Usage
wait_for_ssh "$host" "$port" "$user" "$max_wait"

# Parameters
# - host: SSH host (IP or hostname)
# - port: SSH port
# - user: SSH username
# - max_wait: Maximum wait time in seconds (default: 30)

# Returns
# - 0: SSH available
# - 1: Timeout reached

# Examples
wait_for_ssh "localhost" "2222" "dev" 30
wait_for_ssh "$server_ip" "22" "dev" 120
```

**SSH options used:**
- `ConnectTimeout=$interval` - Match attempt interval
- `StrictHostKeyChecking=no` - Accept unknown hosts
- `UserKnownHostsFile=/dev/null` - Don't save host keys
- `BatchMode=yes` - No interactive prompts

### SSH Alias Setup

**`setup_ssh_alias`** - Creates SSH config alias for simplified connections.

```bash
# Usage
setup_ssh_alias "$name" "$port" ["$host"]

# Parameters
# - name: Sandbox name (becomes SSH alias)
# - port: SSH port
# - host: Optional hostname/IP (default: 127.0.0.1)

# Examples
setup_ssh_alias "sandbox-myproject" "2222"
setup_ssh_alias "sandbox-myproject" "22" "203.0.113.50"
```

**Behavior:**
- Creates `~/.ssh/config.d/alias-{name}.conf` if directory exists
- Sets secure file permissions (mode 600)
- Includes `StrictHostKeyChecking=no` and `UserKnownHostsFile=/dev/null`
- No-op if `~/.ssh/config.d/` doesn't exist

**Generated config:**
```
Host sandbox-myproject
    HostName 127.0.0.1
    Port 2222
    User dev
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
```

### Supporting Functions

**`remove_ssh_alias`** - Removes SSH alias config file.

```bash
remove_ssh_alias "$name"
```

**`remove_all_ssh_aliases`** - Removes all sandbox SSH aliases.

```bash
remove_all_ssh_aliases
```

**`is_ssh_alias_setup`** - Checks if SSH alias exists.

```bash
if is_ssh_alias_setup "$name"; then
    ssh "$name"
fi
```

**`get_ssh_agent_keys`** - Extracts public keys from SSH agent (base64 encoded).

```bash
ssh_keys=$(get_ssh_agent_keys)
# Returns base64-encoded public keys or empty string
```
