# Prompt Patcher Library

## Overview

The prompt-patcher library manages AI agent prompt files (CLAUDE.md, GEMINI.md, AGENT.md) by injecting context-specific blocks into them. It dynamically inserts documentation about sandbox constraints, network restrictions, and git access limitations based on the environment configuration. This ensures AI agents receive accurate instructions about their execution environment without manual prompt file editing.

## Key Constraints & Design Decisions

- **Block-based injection**: Prompt content organized as reusable markdown blocks in `blocks/` directory
- **Idempotent operations**: Can safely re-run block replacement without duplication
- **Marker-based tracking**: Uses HTML comments (`<!-- SANDBOX-BLOCK: id -->`) to identify and replace blocks
- **Tool-agnostic**: Supports multiple AI tools (Claude, Gemini, OpenCode) with tool-specific prompt filenames
- **Runtime allowlist injection**: Special handling for `proxy-restrictions` block to inject domain allowlists at runtime
- **Automatic cleanup**: Removes obsolete blocks when configuration changes

## Usage

### Basic Block Operations

**Get a prompt block:**
```bash
source ~/.config/lib/bash/prompt-patcher/lib.bash

# Get a single block with markers
get_prompt_block "sandbox-bwrap"
# Output:
# <!-- SANDBOX-BLOCK: sandbox-bwrap -->
# [block content]
# <!-- END-SANDBOX-BLOCK: sandbox-bwrap -->

# Get proxy restrictions with allowlist injection
get_prompt_block "proxy-restrictions" "/path/to/allowlist"
```

**Insert or replace blocks in a file:**
```bash
# Replace/insert a single block
insert_or_replace_block "/path/to/CLAUDE.md" "sandbox-vm"

# Replace all blocks (removes unlisted blocks, default blocks injected automatically)
replace_all_prompt_blocks "/path/to/CLAUDE.md" "" "sandbox-bwrap" "git-readonly"
```

**Remove blocks:**
```bash
# Remove a specific block
remove_prompt_block "/path/to/CLAUDE.md" "sandbox-bwrap"

# Remove blocks not in desired list
remove_obsolete_blocks "/path/to/CLAUDE.md" "sandbox-vm" "proxy-restrictions"
```

## Available Blocks

Blocks are located in: `bash/lib/prompt-patcher/blocks`

### Default Blocks (Automatically Injected)

These blocks are always included when calling `replace_all_prompt_blocks`:

| Block ID | Purpose |
|----------|---------|
| `communication` | General AI agent communication guidelines |
| `conventions` | General AI agent code conventions |

### Environment-Specific Blocks

These blocks are conditionally added based on sandbox configuration:

| Block ID | Purpose | Special Handling |
|----------|---------|------------------|
| `sandbox-bwrap` | Bubblewrap sandbox constraints | None |
| `sandbox-container` | Container-specific constraints | None |
| `sandbox-vm` | VM (KVM/hcloud) environment notes | None |
| `git-readonly` | Read-only git repository access | None |
| `proxy-restrictions` | Network filtering with domain allowlist | Runtime allowlist injection |

## Testing

Tests are colocated with the library: `bash/lib/prompt-patcher/lib.bats`

## Dependencies

- Bash shell
- Standard Unix tools: `grep`, `sed`, `cat`, `mktemp`, `mv`

## Configuration

**Tool-specific filenames:**
The `get_prompt_filename` function maps AI tools to their prompt files:
- `claude` → `CLAUDE.md`
- `gemini` → `GEMINI.md`
- `opencode` → `AGENT.md`

**Block directory structure:**
```
bash/lib/prompt-patcher/
├── lib.bash              # Main library functions
└── blocks/               # Reusable prompt blocks
```
