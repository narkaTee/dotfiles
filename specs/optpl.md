# 1Password Template Injector (optpl)

## Overview

The `optpl` tool provides secure secret injection by wrapping the 1Password CLI (`op inject`) to dynamically populate configuration files with credentials before running commands. Templates use `.optpl` file extensions and contain `op://` secret references that are resolved at runtime. The tool automatically cleans up generated files after command execution, ensuring credentials never persist in plaintext.

## Key Constraints & Design Decisions

- **Template file extension**: All templates must use `.optpl` extension; target is derived by stripping this extension
- **Automatic cleanup**: Generated target files are always removed via EXIT trap, even on errors
- **Overwrite protection**: Refuses to run if target file already exists (warns and skips injection)
- **Pipe detection**: Auto-detects piped output (`stdout` not a TTY) and outputs to stdout instead of file
- **Alias system**: Built-in aliases map short names (`claude`, `opencode`) to full template paths
- **Graceful degradation**: Continues command execution even when `op` CLI is missing or template doesn't exist (with warnings)
- **Non-interactive mode**: Uses `op inject` which requires `op` session to be authenticated beforehand

## Usage

**Basic template injection:**
```bash
# Using a direct template file path
optpl ~/.config/app/config.json.optpl my-command --arg

# Using built-in alias
optpl claude claude
optpl opencode opencode
```

**Pipe mode (output to stdout):**
```bash
# Auto-detects pipe and outputs to stdout instead of file
optpl ~/.config/app/config.json.optpl - | jq .

# Explicitly specify stdout with '-'
optpl claude - | less
```

**Show alias paths:**
```bash
# Display the full path of an alias (for debugging and integration into other tools)
optpl --show-alias claude
# Output: /home/user/.claude/settings.json.optpl
```

**Example template file** (`~/.claude/settings.json.optpl`):
```json
{
  "apiKey": "op://vault/Claude/api_key",
  "organization": "op://vault/Claude/org_id"
}
```

**Workflow:**
1. `optpl` reads the `.optpl` template file
2. Runs `op inject -i template.optpl -o target` to resolve `op://` references
3. Executes the specified command (which can access the target file)
4. Cleanup trap removes the target file automatically

## Dependencies

**Required:**
- Bash shell
- 1Password CLI (`op`) - optional but highly recommended; tool warns and skips injection if missing

**Authentication:**
- User must be authenticated with `op` CLI before running (e.g., via `op signin` or existing session)
- Tool does not handle authentication itself

## Configuration

**Built-in template aliases:**
- `claude` → `$HOME/.claude/settings.json.optpl`
- `opencode` → `$HOME/.config/opencode/opencode.jsonc.optpl`

**Alias expansion:**
The `template_alias()` function maps short names to full paths. Add new aliases by extending this function.

## Integration Points

**1Password template syntax:**
Uses standard `op inject` format with `op://vault/item/field` secret references. See 1Password documentation for template syntax.

**Error handling behavior:**
- Missing `op` CLI: Warning printed, command still runs (without injection)
- Missing template: Warning printed, command still runs (without injection)
- Target exists: Warning printed, command still runs (without injection)
- Template equals target: Error and exit (prevents `.optpl` extension missing)
- Pipe mode failures: Exit with error (no fallback)

**Exit trap guarantees:**
The cleanup trap is registered immediately before `op inject`, ensuring target files are removed even if the command fails or is interrupted (SIGINT, SIGTERM).
