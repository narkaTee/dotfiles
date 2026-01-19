# KVM Sandbox Environment

You are running inside a KVM-based virtual machine with full system access and multiple package managers available.

## Environment Capabilities
- **Full VM environment**: Complete system access with root privileges
- **sudo access**: Non-interactive sudo available - always use `sudo -n` flag
- **Package installation**: Multiple package managers are pre-configured and ready to use

## Available Package Managers

Use package managers in this priority order for best results:

### 1. **sdkman** (Java/JVM ecosystem) - Preferred for JRE-related software
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

### 3. **apt** (Debian package manager) - For system packages and libraries
- **Important**: Always run `sudo -n apt-get update` first - the package cache is likely empty or stale
- Update package lists: `sudo -n apt-get update`
- Install package: `sudo -n apt-get install -y <package>`
- Search for packages: `apt-cache search <keyword>`

**Use for:** System tools, libraries, compilers, or software not in specialized managers

### 4. **brew** (Homebrew/Linuxbrew) - For development tools and utilities
- Install package: `brew install <package>`
- Search packages: `brew search <keyword>`
- Update brew: `brew update`
- List installed: `brew list`
- Show package info: `brew info <package>`

**Use for:** Development tools, CLI utilities, modern versions of Unix tools, or newer software versions than apt provides

**Common brew packages:**
- Development tools: `gh` (GitHub CLI), `terraform`, `opentofu`
- Kubernetes tools: `helm`, `helmfile`, `kubectl`, `minikube`, ``

## Best Practices

1. **Check before installing**: Use `which <command>` or `<command> --version` to verify if already installed
2. **Choose the right manager**: Follow the priority order based on what you're installing
3. **Use non-interactive flags**: Always use `sudo -n` and `-y` for automated installations
4. **Update before install**: For apt, always run `apt-get update` first - the package cache starts empty

## Common Installation Patterns

**Java development environment:**
```bash
sdk install java 25.0.1-tem
sdk install maven
sdk install gradle
```

**Node.js from project requirements:**
```bash
n install auto
npm install
```

**System utilities and build tools:**
```bash
sudo -n apt-get update && sudo -n apt-get install -y build-essential git curl wget ripgrep jq
```

**Development CLI tools:**
```bash
brew install fd-find gh
```

**Python development:**
```bash
sudo -n apt-get update && sudo -n apt-get install -y python3-pip python3-venv
# or for newer Python
brew install python@3.12
```
