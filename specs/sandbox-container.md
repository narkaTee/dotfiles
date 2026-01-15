# Sandbox Container Backend

## Overview

The container backend provides Docker/Podman-based development sandboxes with security hardening and workspace bind mounts. It offers fast startup times (~1 second) with container-level isolation. This backend is ideal for lightweight, repeatable development environments that don't require root access.

## Key Constraints & Design Decisions

- **Container engine priority**: Prefers Podman over Docker if both are available (better security defaults)
- **Security hardened**: Drops all capabilities by default, only adds essential ones (CHOWN, DAC_OVERRIDE, SETGID, SETUID, NET_BIND_SERVICE)
- **No root access**: Containers run as non-root user `dev` - no sudo/privilege escalation inside sandbox
- **Shared host network**: Containers use host network by default unless proxy mode is enabled
- **Automatic image updates**: Image is pulled/updated on every sandbox start
- **Workspace bind mount**: Current directory is mounted to `/home/dev/workspace` with shared access
- **Container image**: Uses `ghcr.io/narkatee/sandbox-container:latest`

## Usage

**Starting a container sandbox:**
```bash
# From main sandbox command
sandbox --container

# Or with proxy isolation
sandbox --container --proxy
```

**Direct backend functions** (called by main sandbox script):
```bash
# Check if sandbox is running
is_container_running sandbox-myproject

# Get SSH port for container
get_container_ssh_port sandbox-myproject

# Start sandbox container
start_container_sandbox sandbox-myproject

# Stop and remove container
stop_container_sandbox sandbox-myproject

# Enter running container
backend_enter sandbox-myproject
```

**Container characteristics:**
- Workspace at `/home/dev/workspace` synced with host directory
- SSH access on dynamically allocated port (forwarded from container port 2222)
- User `dev` with zsh shell
- Automatic cleanup on stop (containers use `--rm` flag)

## Dependencies

- Docker or Podman installed
- SSH agent running on host (for key forwarding)
- Container image: `ghcr.io/narkatee/sandbox-container:latest`

## Integration Points

**Proxy mode integration:**
When `$PROXY=true`:
1. Creates isolated Docker network (`sandbox-net-<name>`)
2. Starts proxy container in network
3. Connects sandbox container to isolated network (no direct host access)
4. Configures HTTP_PROXY/HTTPS_PROXY environment variables

See [sandbox-proxy.md](sandbox-proxy.md) for proxy details.

**SSH configuration:**
- Injects host SSH public keys from `ssh-agent` into container
- Creates SSH alias in `~/.ssh/config.d/` if available
- Port forwarding: host random port -> container port 2222

## Testing

**Container engine detection:**
1. Install only Docker - verify it's detected
2. Install only Podman - verify it's detected
3. Install both - verify Podman is preferred
4. Remove both - verify error message

**Sandbox lifecycle:**
1. Start container sandbox - should complete in ~1-2 seconds
2. Verify container is running: `docker/podman ps`
3. Verify workspace mounted: files in current directory appear in `/home/dev/workspace`
4. Enter sandbox - should drop into zsh shell
5. Stop sandbox - container should be removed completely

**Security verification:**
1. Inside container, run `whoami` - should be `dev` not `root`
2. Try `sudo` - should not be available or fail
3. Check capabilities: `capsh --print` - should only show permitted capabilities
4. Verify `no-new-privileges` security option is active

**Proxy mode:**
1. Start with `--proxy` flag
2. Verify isolated network created: `docker/podman network ls`
3. Inside sandbox, verify `$HTTP_PROXY` and `$HTTPS_PROXY` are set
4. Test network access restricted to proxy allowlist
5. Stop sandbox - verify network is cleaned up
