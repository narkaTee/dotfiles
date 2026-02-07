# Configuration Manager (cfg)

## Overview

The `cfg` tool manages configuration templates stored in a private git repository. It uses 1Password CLI for secret resolution. Templates contain only `op://` references - actual secrets never leave 1Password.

**Private repository:** `git@github.com:narkaTee/cfgs.git` (hardcoded in tool)

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

# Sync with remote repository (explicit git pull)
cfg sync
```

**Execution modes:**
- `cfg <profile> <cmd>`: Injects files to targets, loads env vars, executes command via `op run`
- `cfg <profile> --export-env`: Outputs shell export statements to stdout (for eval)
- `cfg <profile> --export-file <target>`: Outputs resolved file content to stdout
- `cfg <profile> --export-file --base-dir <dir>`: Exports all file outputs to directory

**Profile selection:**
- `cfg claude.work` - direct selection, no prompt
- `cfg claude` - always opens fzf picker for `claude.*` matches
- `cfg --select claude` - same as above, outputs profile name to stdout
- fzf picker includes `<none>` option for no-credentials bootstrap (outputs empty string)
- `cfg --has-profiles claude` - check if any `claude.*` profiles exist (exits 0 if yes, 1 if none)

**Profile naming rules:**
- Must start with alphanumeric character
- May contain: alphanumeric, dots (`.`), hyphens (`-`), underscores (`_`)
- No spaces or special characters
- Examples: `claude.work`, `codex-v2`, `api_test`

**Loading indicators:**
- Git operations (clone, pull, push) show animated spinner in interactive terminals
- Spinner automatically hidden in pipes/scripts (non-TTY)
- Animation: bouncing dots (⣾⣽⣻⢿⡿⣟⣯⣷) at 10 FPS

### Management commands

```bash
# List available configs (shows name, description)
cfg list
cfg ls

# Create new config (auto-commits & pushes)
cfg add claude.personal

# Import existing file as template (auto-generates hashed filename, auto-commits & pushes)
# If profile already has a template with same target path, replaces it
cfg import claude.work ~/.claude/config.json

# Show profile as raw YAML
cfg show claude.work

# Show template content (fzf selection if multiple files)
cfg show claude.work file
cfg show claude.work env

# Edit profile metadata (description, op_account) - auto-commits & pushes
cfg edit claude.work

# Edit file template (fzf selection if multiple, prompts for target path if none exist) - auto-commits & pushes
cfg edit claude.work file

# Edit env template (creates if none exists) - auto-commits & pushes
cfg edit claude.work env

# Delete entire profile (also removes its template files) - auto-commits & pushes
cfg delete claude.work

# Delete file template from profile (fzf selection if multiple) - auto-commits & pushes
cfg delete claude.work file

# Delete env template from profile - auto-commits & pushes
cfg delete claude.work env
```

## Repository Structure

Private repository cloned to `~/.local/share/cfg/` (local working copy).

```
~/.local/share/cfg/
  .git/
  profiles/
    claude.work.yaml
    codex.personal.yaml
  templates/
    b4c6d2e.json       # hashed filenames
    f7a3c5b.env
```

### Profile files (plaintext YAML)

```yaml
# profiles/claude.work.yaml
description: Work Claude config
op_account: work  # optional, passed to op --account
outputs:
  - template: b4c6d2e.json  # references templates/ by hashed filename
    type: file
    target: ~/.claude/config.json
  - template: f7a3c5b.env
    type: env  # dotenv format, resolved via op run
```

### Template files (plaintext with op:// references)

```bash
# templates/f7a3c5b.env
ANTHROPIC_API_KEY=op://work/claude-api/credential
OPENAI_API_KEY=op://work/openai/api-key
```

```json
# templates/b4c6d2e.json
{
  "api_key": "op://work/claude-api/credential",
  "model": "claude-sonnet-4.5"
}
```

**Template types:**
- `type: env`: Dotenv format, resolved via `op run`
  - No `target` field (env vars loaded into process environment)
  - Template filename uses `.env` extension (e.g., `abc123.env`)
- `type: file`: Any format, resolved via `op inject`, written to `target` path
  - Requires `target` field (absolute path where file will be written)
  - Template filename extension should match target file type (e.g., `abc123.json`, `xyz789.toml`)

## Git Synchronization

**Initial clone:**
- On first operation (or `cfg sync`), clone repo from `REPO_URL` to `REPO_PATH`
- After successful clone, run `git github` to configure author info
- If `git github` fails: warn but continue (repo still usable)

**Auto-pull (periodic):**
- Before any operation, check if local repo is >2 hours old
- If stale: `git pull --rebase`
- If pull fails or conflicts: warn and continue with local state
- If uncommitted local changes: skip pull and warn

**Auto-commit & push:**
- After successful edit operations (`add`, `edit`, `import`, `delete`)
- Commit message format: `cfg: <action> <profile>`
  - Example: `cfg: Edit profile claude.work`
  - Example: `cfg: Add profile codex.personal`
- Automatic `git push origin main` after commit
- If push fails: warn but don't block (changes remain committed locally)

**Manual sync:**
- `cfg sync` - explicit `git pull` anytime

## Security Model

**Private repository:**
- Profiles and templates stored in private git repo (not encrypted)
- Access controlled via GitHub SSH keys
- Templates contain only `op://vault/item/field` references (no actual secrets)

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

## Installation

Installed via `rake cfg`

**Source layout:**
```
bin/cfg           # Entry point script
lib/cfg.rb        # Module definition + require_relative for all submodules
lib/cfg/
  cli.rb          # CLI dispatcher
  git.rb          # Git operations (clone, pull, commit, push)
  storage.rb      # Profile/template file I/O
  profiles.rb     # Profile CRUD operations
  selector.rb     # fzf picker abstraction
  runner.rb       # Command execution, op integration
  ui.rb           # User input prompts, editor integration
```

**Main module (`lib/cfg.rb`):**
```ruby
module Cfg
  class Error < StandardError; end
  REPO_URL = "git@github.com:narkaTee/cfgs.git"
  REPO_PATH = File.join(Dir.home, ".local/share/cfg")
end

require_relative 'cfg/git'
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
- `git` - repository management
- `op` (1Password CLI) - secret resolution
- `fzf` - interactive selection
- SSH key with GitHub access to private repo

## Bootstrap

**First-time setup:**
```bash
rake cfg              # Installs tool
cfg sync              # Clones private repo from hardcoded URL
```

If repo doesn't exist locally, first operation will auto-clone.

## Integration Points

**Automation commands:**
- `cfg --select <prefix>` - profile selection, outputs name to stdout
- `cfg <profile> --export-env` - outputs shell export statements
- `cfg <profile> --export-file --base-dir <dir>` - exports files to directory

Used by [boxed ai-jail](boxed-ai-jail.md) and [sandbox ai-bootstrap](sandbox-ai-bootstrap.md) for credential injection.
