# Network Proxy Restrictions

All network traffic routes through a filtering proxy. The following domains are accessible:

<!-- ALLOWLIST_START -->
(Domains will be injected here at runtime)
<!-- ALLOWLIST_END -->

## How to Handle Network Failures

1. **Check the allowlist above** - Verify if the domain you need is already accessible
2. **Attempt alternatives** - Try different mirrors or package sources if available (e.g., different npm registries)
3. **Request allowlisting** - If a legitimate domain is blocked, inform the user:
   - Provide the exact domain that failed (e.g., "api.example.com")
   - Explain why it's needed for the task
   - Tell user they can add it with: `sandbox proxy allow <domain>`

## Do NOT
- Retry the same blocked domain multiple times - one attempt is sufficient
- Assume wildcard patterns work intuitively (*.npmjs.org doesn't guarantee obscure.npmjs.org works)
- Attempt proxy bypasses (VPNs, tunnels, SOCKS proxies) - they will fail in this environment

After informing the user, wait for confirmation that they've allowlisted the domain before retrying.
