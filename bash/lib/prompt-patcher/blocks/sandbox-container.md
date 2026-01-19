# Container Environment

This sandbox runs inside a container with these limitations:
- **Nested containers don't work** - Docker/Podman commands will fail
- **Limited capabilities** - System-level operations may be restricted
- **Resource limits** - RAM, CPU cores, and number of processes are limited

## Available Package Managers

Use package managers in this priority order for best results:

### 1. **sdkman** (Java/JVM ecosystem) - Preferred for JRE-related software

**Critical: before using the sdk command you need to source `~/.config/setup/tools.sh`**

- Show help: `sdk help`
- List available tools: `sdk list`
- List versions for a tool: `sdk list <candidate>` (e.g., `sdk list java`)
- Install specific version: `sdk install java 25.0.1-tem`
- Use installed version: `sdk use java 25.0.1-tem`

**Use for:** Java, Maven, Gradle, Kotlin, Scala, Spring Boot CLI, and other JVM tools

### 2. **n** (Node.js version manager) - Preferred for Node.js
- Show help: `n --help`
- Install latest LTS: `n install lts`
- Install specific version: `n install 20.11.0`
- Auto-install from project: `n install auto` (reads .node-version, .nvmrc, package.json)

**Use for:** Installing or switching Node.js versions

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
