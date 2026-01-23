# Sandbox KVM Backend

## Overview

The KVM backend provides full VM sandboxes using QEMU/KVM with direct kernel boot, 9p filesystem sharing, and ephemeral disk overlays. Unlike the container backend, KVM provides complete system isolation with full root access inside the VM. This backend is ideal for tasks requiring kernel-level access, system services, or stronger isolation guarantees.

## Key Constraints & Design Decisions

- **Requires KVM support**: Host must have `/dev/kvm` access and `qemu-system-x86_64` installed
- **Direct kernel boot**: Boots kernel directly (no GRUB) for faster startup (~5-10 seconds)
- **Ephemeral disk**: VM uses qcow2 overlay - all disk changes lost on stop
- **9p filesystem**: Workspace mounted via virtfs, no rsync/copy needed
- **Root access**: Full sudo access inside VM (unlike container backend)
- **Image management**: Uses ORAS (OCI Registry as Storage) for base image with zstd compression
- **Console access**: Unix socket for emergency debugging when SSH fails
- **Base image**: Debian 13 from `ghcr.io/narkatee/sandbox-kvm-image:latest`

## Usage

**Starting a KVM sandbox:**
```bash
# From main sandbox command
sandbox --kvm

# Or with proxy isolation
sandbox --kvm --proxy
```

**Direct backend functions** (called by main sandbox script):
```bash
# Check if VM is running
is_kvm_running sandbox-myproject

# Get SSH port for VM
get_kvm_ssh_port sandbox-myproject

# Get IP address for VM (returns "localhost")
get_kvm_ip sandbox-myproject

# Start KVM sandbox
start_kvm_sandbox sandbox-myproject

# Stop VM and cleanup
stop_kvm_sandbox sandbox-myproject

# Enter running VM
backend_enter sandbox-myproject
```

**VM characteristics:**
- Full Debian 13 system with systemd
- Root access via sudo
- Workspace at `/home/dev/workspace` mounted via 9p
- SSH access on dynamically allocated port
- Console access via Unix socket at `~/.cache/sandbox/kvm-vms/<name>/console.sock`

**Console access for debugging:**
```bash
socat STDIO,raw,echo=0,escape=0x1d UNIX-CONNECT:~/.cache/sandbox/kvm-vms/<name>/console.sock
# Exit with Ctrl+]
```

## Dependencies

- QEMU/KVM: `qemu-system-x86_64` command
- KVM kernel module: `/dev/kvm` must be accessible
- ORAS CLI: For fetching VM images from registry
- libguestfs-tools: `virt-ls` for extracting kernel/initrd from image
- zstd: For decompressing base image

## Configuration

**Cache locations:**
- Base image cache: `~/.cache/sandbox/kvm-cache/`
- VM state: via `backend_state_dir "kvm"` from common library

**VM resources (hardcoded):**
- Memory: 2GB
- CPUs: 2 cores
- Disk: Base image size (overlay grows as needed)

## Integration Points

**Common library usage** (see [sandbox-common.md](sandbox-common.md)):

**Proxy mode integration:**
When `$PROXY=true`:
1. Starts proxy container with host port forwarding
2. Generates cloud-init config with proxy settings
3. Injects config via QEMU SMBIOS (`-smbios type=11`)
4. Guest reads SMBIOS credentials on boot and configures environment

See [sandbox-proxy.md](sandbox-proxy.md) for proxy details.

**SSH configuration:**
- Uses host SSH agent keys (injected via cloud-init)
- Creates SSH alias in `~/.ssh/config.d/` if available
- Port forwarding: host random port -> VM port 22 via QEMU user networking

**Workspace sharing:**
- QEMU 9p virtfs mounts host directory into VM
- Security model: `mapped-xattr` for permission handling
- Auto-mounted at `/home/dev/workspace` via systemd mount unit
