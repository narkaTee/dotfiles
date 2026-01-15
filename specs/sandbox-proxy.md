# Sandbox Proxy Backend

## Overview

The proxy backend provides network isolation via a restrictive HTTP/HTTPS proxy with domain allowlist. It wraps the container or KVM backends, intercepting all network traffic and allowing only approved domains. This is ideal for limiting AI agent network access, preventing data exfiltration, or enforcing compliance policies.

## Key Constraints & Design Decisions

- **Allowlist-only approach**: Network access denied by default, must explicitly allow domains
- **Runs as wrapper**: Proxy doesn't replace backends, it augments them with network restrictions
- **Per-sandbox allowlists**: Each sandbox has independent allowlist (no global configuration)
- **Domain-based filtering**: Filters by domain name (no IP-based bypass possible)
- **Tinyproxy implementation**: Uses tinyproxy for actual HTTP/HTTPS proxying
- **Persistent allowlists**: Allowlist survives sandbox restarts (stored in `~/.cache/sandbox/sandbox-proxy/<name>/`)
- **Default allowlist**: Includes common package registries and git hosts for development

## Usage

**Starting sandbox with proxy:**
```bash
# Container backend with proxy
sandbox --container --proxy

# KVM backend with proxy
sandbox --kvm --proxy
```

**Managing allowlist:**
```bash
# Allow a domain (wildcard subdomains)
sandbox proxy allow github.com

# Block/remove a domain
sandbox proxy block github.com

# View current allowlist
sandbox proxy list

# Monitor proxy logs (all requests)
sandbox proxy log

# Monitor blocked requests only (follow mode)
sandbox proxy log -f

# Reset to default allowlist
sandbox proxy reset
```

**Domain format:**
- Add domains without protocol: `example.com` (not `https://example.com`)
- Tinyproxy treats entries as wildcard: `github.com` matches `*.github.com`

## Dependencies

- Docker or Podman (for proxy container)
- Default allowlist file: `bash/lib/sandbox/proxy/allowlist.txt`
- Proxy Dockerfile: `bash/lib/sandbox/proxy/Dockerfile`

## Configuration

**Proxy container:**
- Image: `sandbox-proxy:latest` (auto-built on first use)
- Port: 8888 (inside container)
- Container name: `sandbox-proxy-<name>` (container backend) or `sandbox-proxy-kvm-<name>` (KVM)

**Data storage:**
- Base directory: `~/.cache/sandbox/sandbox-proxy/`
- Per-sandbox allowlist: `~/.cache/sandbox/sandbox-proxy/<name>/allowlist.txt`

## Integration Points

**Container backend integration:**
1. Creates isolated Docker network with `--internal` and `--disable-dns` flags
2. Starts proxy container in network with external access
3. Connects sandbox container to isolated network (no direct internet)
4. Sets `HTTP_PROXY` and `HTTPS_PROXY` environment variables to proxy IP

Network isolation prevents bypassing proxy by blocking all direct connections.

**KVM backend integration:**
1. Starts proxy container with host port forwarding (dynamic port)
2. Generates cloud-init configuration with proxy settings
3. Injects config into VM via QEMU SMBIOS (`-smbios type=11`)
4. Guest agent reads config on boot and sets environment variables

VM uses host networking but environment variables direct all traffic through proxy.

## Testing

**Proxy container:**
1. Start sandbox with `--proxy` - proxy container should auto-build and start
2. Verify proxy container running: `docker/podman ps | grep sandbox-proxy`
3. Check proxy accessible on port 8888 from sandbox
4. Stop sandbox - proxy container should stop too

**Allowlist management:**
1. Start fresh sandbox with proxy
2. Run `sandbox proxy list` - should show default allowlist
3. Add domain: `sandbox proxy allow example.com`
4. Verify added: `sandbox proxy list | grep example.com`
5. Block domain: `sandbox proxy block example.com`
6. Verify removed: `sandbox proxy list` (should not contain example.com)
7. Reset: `sandbox proxy reset` - should restore to default

**Network filtering:**
1. Start sandbox with proxy
2. Inside sandbox, try accessing allowed domain: `curl https://github.com` - should succeed
3. Try accessing blocked domain: `curl https://blocked-site.com` - should fail
4. Add blocked domain to allowlist: `sandbox proxy allow blocked-site.com`
5. Retry access - should now succeed
6. Check logs: `sandbox proxy log` - should show both allowed and blocked requests

**Proxy logs:**
1. Run `sandbox proxy log` - should show historical requests
2. Run `sandbox proxy log -f` in separate terminal
3. Make request from inside sandbox
4. Verify blocked requests appear immediately in log output
5. Exit with Ctrl+C

**Allowlist persistence:**
1. Start sandbox with proxy, add domain to allowlist
2. Stop and restart sandbox
3. Verify domain still in allowlist (persisted)
4. Modify allowlist file directly in `~/.cache/sandbox/sandbox-proxy/<name>/`
5. Changes should take effect immediately (proxy watches file)

**Default allowlist:**
1. Verify default allowlist includes common domains (npm, pypi, github, etc.)
2. Test fresh sandbox can install packages: `npm install`, `pip install`
3. Reset custom allowlist: `sandbox proxy reset`
4. Verify restored to defaults
