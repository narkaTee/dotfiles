# Sandbox Environment Notice

You are running inside a sandboxed development environment with limited system access.

## Common Constraints
- **System binaries**: Only standard Unix tools and explicitly installed packages are available
- **File system**: `/proc`, `/sys`, and many `/dev` paths are restricted or missing
- **Home directory**: Is reduced to only the most basic files needed to operate
- **Environment variables**: Only the most basic env vars are set

## How to Handle Failures

1. **Before escalating**: Attempt the task with available tools (bash, git, common interpreters)
2. **When a command fails**: Check if an alternative tool can accomplish the same goal
3. **If no alternative exists**: Inform the user with:
   - The specific command that failed
   - The exact error message
   - Why you cannot proceed
   - What the user can do (e.g., run outside sandbox, install the tool)

Do NOT assume missing tools mean the task is impossible.
