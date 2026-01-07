# Container Environment Constraints

This sandbox runs inside a container with these limitations:
- **Nested containers don't work** - Docker/Podman commands will fail
- **Limited capabilities** - System-level operations may be restricted
- **Resource limits** - RAM, CPU cores, and number of processes are limited

## How to Handle Failures

1. **For Docker/Podman failures**: These cannot be worked around - inform the user they need to run the command outside the sandbox
2. **For system-level operations**: Try alternative approaches using standard Unix tools
3. **For resource limits**: If you hit memory or CPU limits, inform the user:
   - Describe which operation exceeded limits
   - Suggest running the operation outside the sandbox or splitting it into smaller tasks
4. **Before escalating**: Attempt the task with available tools (bash, git, common interpreters)
5. **When a command fails**: Check if an alternative tool can accomplish the same goal
6. **If no alternative exists**: Inform the user with:
   - The specific command that failed
   - The exact error message
   - Why you cannot proceed
   - What the user can do (e.g., run outside sandbox, install the tool)

These limitations cannot be changed - only bypass them by running outside the sandbox.

Do NOT assume missing tools mean the task is impossible.
