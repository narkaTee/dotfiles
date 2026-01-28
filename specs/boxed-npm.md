# boxed npm Profile

## Overview

The `npm` profile provides a sandboxed environment for running Node.js package manager commands with network access and npm cache persistence. Designed for safely running `npm install`, `npm test`, and other package operations while maintaining isolation from the rest of the system.

## Usage

```bash
# Install dependencies in isolated environment
boxed npm npm install

# Run package scripts
boxed npm npm run build
boxed npm npm test

# Interactive shell with npm environment
boxed --shell npm bash
```

## What This Profile Enables

### Filesystem Access

- **Current directory**: Bound read-write via `feature_bind_pwd`
- **npm cache**: `~/.npm` bound read-write via `bind_cache`
- **npm config**: `~/.npmrc` bound read-only if exists

### npm Installation Protection

- **npm command tree**: Binds npm's parent directory with protected subdirectories (`n`, `repo`) to prevent modification of the Node.js version manager setup
- Uses `bind_command_tree npm 1 n repo` to allow npm execution while protecting version manager files

### Network & Environment

- **Network enabled**: Full network access via `feature_network` (includes DNS and SSL certificates)
- **Environment variables**: Passes through all `NODE_*` and `NPM_*` variables

## Use Cases

- Running `npm install` on untrusted or unfamiliar packages
- Executing npm scripts that might have unintended side effects
- Testing packages in isolation before adding to main environment
- CI/CD pipelines requiring hermetic builds

## Constraints

- **No home directory access**: Uses tmpfs home, only npm-specific paths are bound
- **Read-only system binaries**: Cannot modify system Node.js or npm installations
- **Protected version managers**: The `n` and `repo` directories are mounted read-only to prevent accidental npm version changes
