# boxed-brew Profile

## Overview

Sandboxed Homebrew (linuxbrew) operations with command tracking and filesystem isolation. Prevents brew from modifying system files while automatically reporting which new commands are installed. Primary use case is safely installing packages without risk to the host system.

## Key Constraints & Design Decisions

### Security Model
- **Minimal filesystem access**: Only `/home/linuxbrew/.linuxbrew` is writable
- **No tracking state in sandbox**: Command tracking runs outside sandbox to prevent tampering
- **OS detection required**: Brew needs `/etc/os-release` and `/etc/lsb-release` for platform detection

### Tracking Strategy
- **Monitors both bin and sbin**: Tracks `/home/linuxbrew/.linuxbrew/bin` and `/home/linuxbrew/.linuxbrew/sbin`
- **Uses `feature_track_commands`**: Leverages shared tracking infrastructure (see [boxed.md](boxed.md#command-tracking))
- **Always enabled**: All brew operations are tracked, not just installs

## Usage

```bash
# Install a package and see which new commands it provides
boxed brew brew install ripgrep

# Upgrade packages
boxed brew brew upgrade

# Other brew operations
boxed brew brew search fzf
boxed brew brew info ripgrep
```

## Configuration

- **Hardcoded linuxbrew path**: Assumes `/home/linuxbrew/.linuxbrew`
- **Network required**: Package downloads need `feature_network`
- **Environment passthrough**: All `HOMEBREW_*` variables are forwarded
