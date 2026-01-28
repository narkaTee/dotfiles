# boxed - Lightweight Bubblewrap Sandboxing

## Overview

`boxed` provides profile-based sandboxing for running untrusted commands using bubblewrap (bwrap). It offers a CLI interface to create isolated environments with minimal system access, configurable through reusable profiles. Primary use case is running AI agents and third-party tools with strong filesystem and capability isolation to prevent accidental system damage.

## Key Constraints & Design Decisions

### Security Model

- **Unshare everything by default**: Starts with `--unshare-all --cap-drop ALL --clearenv --new-session`
- **Read-only system**: System directories (`/usr`, `/bin`, `/lib`, etc.) are always mounted read-only
- **Tmpfs home**: Home directory is replaced with a tmpfs unless `--home` flag is used
- **No network by default**: Network must be explicitly enabled with `--net` flag
- **Principle of least privilege**: Profiles only add necessary bindings, never weaken defaults

### Profile-Based Configuration

- **Profiles are bash scripts**: Located in `bash/boxed/profiles.d/`, sourced after core features are initialized
- **Composable features**: Profiles use feature functions from `lib/features.bash` to build bwrap arguments
- **No profile inheritance**: Each profile is self-contained (but can call common feature functions)

## Usage

### Basic Command

```bash
# Run npm in npm profile
boxed npm npm install

# Launch interactive shell in npm profile
boxed --shell npm bash

# Debug: show bwrap arguments without executing
boxed --debug npm npm test

# Enable network and home directory (even if the profile would not enable network)
boxed --net --home npm npm publish
```

### Creating a Profile

Create `bash/boxed/profiles.d/my-profile`:

```bash
# shellcheck shell=bash

feature_bind_pwd             # Bind current working directory
feature_network              # Enable network + DNS + SSL certs
bind_ro_if_exists ~/.myrc    # Bind config file if exists
bind_cache ~/.cache/mytool   # Create and bind cache directory
add_env 'MYTOOL_*'           # Pass environment variables matching pattern
```

## Feature Functions Reference

In [features.bash](../bash/boxed/lib/features.bash).

### Core Features (Always Applied)

- `feature_ro_system`: Read-only system directories
- `feature_proc`: Minimal /proc with restricted /proc/sys and /proc/1
- `feature_dev_basic`: Basic /dev devices
- `feature_tmpfs_tmp`: Tmpfs /tmp
- `feature_tmpfs_home`: Tmpfs home (overridden by `--home` flag)
- `feature_essential_env`: HOME, USER, PATH, TERM, LS_COLORS

### Common Profile Features

- `feature_bind_pwd`: Bind current working directory (read-write)
- `feature_bind_pwd_git_ro`: Bind .git directory as read-only
- `feature_bind_home`: Bind real home directory (use with caution)
- `feature_network`: Enable network, DNS, SSL certificates
- `feature_bind_npm_globals`: Bind npm global modules directory
- `feature_bind_all_path_dirs`: Bind all directories in $PATH

### Helper Functions

- `bind_ro_if_exists <path>`: Bind path read-only if it exists
- `bind_rw_if_exists <path>`: Bind path read-write if it exists
- `bind_cache <path>`: Create directory and bind read-write
- `bind_command_tree <cmd> <levels> [protected_dirs...]`: Bind command's parent directory tree with optional protected subdirectories
- `add_env <pattern>`: Pass environment variables matching glob pattern
- `overlay_mount <lower> <upper> <work> <mount>`: Create overlay filesystem (for copy-on-write configs)
- `feature_run_optpl_with_template <template>`: Prepend optpl command for credential injection

## Integration Points

### optpl Integration

Profiles can use `feature_run_optpl_with_template` to inject credentials from 1Password before entering the sandbox. See [boxed-ai-jail.md](boxed-ai-jail.md) for an example.

## Configuration

### Environment Variables

No global configuration. All settings are per-invocation via flags or per-profile via profile scripts.

### Dependencies

- **Required**: `bubblewrap` (bwrap command)
- **Optional**: `optpl` for credential injection
- **Optional**: `prompt-patcher` library for AI agent integration (ai-jail profile only)
