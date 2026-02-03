# Encrypted Configuration Manager (cfg)

## Overview

The `cfg` tool manages encrypted configuration templates that can be safely committed to the dotfiles repository. It uses SSH agent signing to derive encryption keys (via OpenSSL AES-256-CBC) and 1Password CLI for secret resolution. Templates contain only `op://` references - actual secrets never leave 1Password.

## Testing Requirements

**All CLI commands and public API changes require unit tests.**

**Unit tests (mandatory):**
- Test location: `lib/cfg/spec/`
- Run command: `rake test_cfg`
- Coverage requirements:
  - All CLI commands must have tests in `lib/cfg/spec/cli_spec.rb`
  - All public module methods must have corresponding spec files
  - New features require tests for both success and failure cases
  - Exit codes must be tested for commands that use them (e.g., `--has-profiles`)

**E2E tests:**
- See [cfg-e2e-testing.md](cfg-e2e-testing.md) for end-to-end test approach and where they are mandatory.

**Before committing:**
1. Run `rake test_cfg` - all tests must pass
2. Verify new CLI commands have test coverage

## Usage

### Running with configs

```bash
# Run command with config applied (auto-injects files + env, cleans up after)
cfg claude.work claude

# Codex with config file + env vars
cfg codex.work codex

# Export env variables to stdout (for eval)
cfg codex.work --export-env

# Export specific file output to stdout (by target path)
cfg codex.work --export-file ~/.codex/config.toml > /tmp/config.toml

# Export all file outputs to a base directory (preserves relative paths from ~)
cfg codex.work --export-file --base-dir /tmp/overlay/

# Interactive selection, return selected profile name (for automation)
cfg --select claude
```

**Execution modes:**
- `cfg <profile> <cmd>`: Injects files to targets, loads env vars, executes command via `op run`
- `cfg <profile> --export-env`: Outputs shell export statements to stdout (for eval)
- `cfg <profile> --export-file <target>`: Outputs resolved file content to stdout
- `cfg <profile> --export-file --base-dir <dir>`: Exports all file outputs to directory

**Profile selection:**
- `cfg claude.work` - direct selection, no prompt
- `cfg claude` - auto-selects if one `claude.*` exists; otherwise fzf picker
- `cfg --select claude` - same as above, outputs profile name to stdout
- `cfg --has-profiles claude` - check if any `claude.*` profiles exist (exits 0 if yes, 1 if none)

**Profile naming rules:**
- Must start with alphanumeric character
- May contain: alphanumeric, dots (`.`), hyphens (`-`), underscores (`_`)
- No spaces or special characters
- Examples: `claude.work`, `codex-v2`, `api_test`

### Management commands

```bash
# List available configs (shows name, description, key suffix)
cfg list
cfg ls

# Create new config
# If multiple Ed25519 keys loaded: fzf selection showing "suffix - comment"
# If one key: uses that key automatically
# Note: comment is shown during selection but NOT stored in index.yaml
cfg add claude.personal

# Import existing file as template (auto-generates hashed filename)
# If profile already has a template with same target path, replaces it
cfg import claude.work ~/.claude/config.json

# Show decrypted profile as raw YAML
cfg show claude.work

# Show decrypted template content (fzf selection if multiple files)
cfg show claude.work file
cfg show claude.work env

# Edit profile metadata (description, op_account)
cfg edit claude.work

# Edit file template (fzf selection if multiple, prompts for target path if none exist)
cfg edit claude.work file

# Edit env template (creates if none exists)
cfg edit claude.work env

# Delete entire profile (also removes its template files)
cfg delete claude.work

# Delete file template from profile (fzf selection if multiple)
cfg delete claude.work file

# Delete env template from profile
cfg delete claude.work env

# Rotate SSH key (both keys must be loaded in agent)
cfg rotate-key a1b2c3 d4e5f6
```

## File Formats

Stores files in ~/dotfiles/cfg/

```
cfg/{index.yaml, profiles-<suffix>.enc, configs/<suffix>/*.enc}
```

`<suffix>` = first 6 hex characters of SHA-256 hash of the SSH public key (filename-safe).

### Index file (index.yaml)

```yaml
# index.yaml (unencrypted, committed to git)
encryption:
  namespace: cfg-secrets-v1

index:
  a1b2c3:  # suffix = first 6 hex chars of SHA-256 hash of public key
    ssh_public_key: "ssh-ed25519 AAAAC3..."  # comment stripped for privacy
    profiles_file: profiles-a1b2c3.enc
```

**Multi-key behavior:**
- No matching keys → error
- One matching key → load that collection
- Multiple matching keys → merge all collections (profile names must be unique)

### Profile and template files (encrypted)

```yaml
# profiles-a1b2c3.enc (encrypted) → configs/a1b2c3/*.enc
codex.work:
  description: Work Codex
  op_account: work  # optional, passed to op --account
  outputs:
    - template: b4c6d2e.enc
      type: file
      target: ~/.codex/config.toml
    - template: f7a3c5b.enc
      type: env  # dotenv format, resolved via op run
# Template content uses op:// refs: ANTHROPIC_API_KEY=op://work/claude-api/credential
```

**Template types:**
- `type: env`: Dotenv format, resolved via `op run`
- `type: file`: Any format, resolved via `op inject`, written to `target` path

## Encryption

**Key derivation:** Sign namespace `cfg-secrets-v1` via SSH agent → SHA-256 hash → AES-256-CBC key.

**Algorithm:** OpenSSL AES-256-CBC with raw 256-bit key, base64-encoded output.

**Constraints:**
- Only Ed25519 keys supported (deterministic signatures required)
- Private key never leaves the SSH agent

**Portability:** Same SSH key on any machine produces identical encryption key. Create configs on laptop → commit to git → pull on server → decrypt.

## Security Model

**What's visible vs encrypted:**
- Visible: SSH public keys (in index.yaml)
- Encrypted: Profile names, descriptions, template references, all config content

**Secrets never on disk:**
- Templates contain only `op://vault/item/field` references
- 1Password CLI resolves references at runtime
- Actual secret values remain in 1Password

**1Password integration:**
- `op inject` resolves references for file outputs
- `op run --no-masking` resolves env templates and executes command (masking disabled to preserve stdin/stdout for interactive programs)
- `op read` resolves individual references for `--export-env` output
- Optional `op_account` in profile passed as `--account` flag
- Requires authenticated `op` session
- `op signin` called before `op inject` when `op_account` is set to avoid race condition during account switching with locked 1Password

**File safety:**
- When running commands, fails if target files already exist (prevents overwrites)
- Injected files automatically removed after command exits (via trap)

**Key rotation:**
- `cfg rotate-key <old-suffix> <new-suffix>` re-encrypts profiles and templates
- Both keys must be loaded in agent during rotation

## Installation

Installed via `rake cfg` (or as part of `rake bash`).

**Source layout:**
```
bin/cfg           # Entry point script
lib/cfg.rb        # Module definition + require_relative for all submodules
lib/cfg/
  cli.rb          # CLI dispatcher
  crypto.rb       # SSH agent signing, AES encryption
  storage.rb      # Index/profile file I/O
  profiles.rb     # Profile CRUD operations
  selector.rb     # fzf picker abstraction
  runner.rb       # Command execution, op integration
  ui.rb           # User input prompts, editor integration
```

**Main module (`lib/cfg.rb`):**
```ruby
module Cfg
  class Error < StandardError; end
end

require_relative 'cfg/crypto'
require_relative 'cfg/storage'
require_relative 'cfg/profiles'
require_relative 'cfg/selector'
require_relative 'cfg/ui'
require_relative 'cfg/runner'
require_relative 'cfg/cli'
```

**Installed layout:**
```
~/bin/cfg                    # Entry point (0755)
~/.local/lib/cfg.rb          # Main require
~/.local/lib/cfg/            # Module files
```

**Entry point (`bin/cfg`):**
```ruby
#!/usr/bin/env ruby
$LOAD_PATH.unshift("#{Dir.home}/.local/lib")
require 'cfg'
Cfg::CLI.run(ARGV)
```

## Dependencies

- Ruby (stdlib only - `yaml`, `open3`, `optparse`, `fileutils`)
- `openssl` - AES-256-CBC encryption
- `op` (1Password CLI) - secret resolution
- `fzf` - interactive selection
- SSH agent with Ed25519 key loaded

## Integration Points

**Automation commands:**
- `cfg --select <prefix>` - profile selection, outputs name to stdout
- `cfg <profile> --export-env` - outputs shell export statements
- `cfg <profile> --export-file --base-dir <dir>` - exports files to directory

Used by [boxed ai-jail](boxed-ai-jail.md) and [sandbox ai-bootstrap](sandbox-ai-bootstrap.md) for credential injection.
