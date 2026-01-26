# AGHENTS.md

## Testing

```bash
rake check  # Runs all checks (shellcheck + shell syntax)
rake shellcheck # Shellcheck
rake test_bash  # Bash syntax checks
rake test_zsh   # Zsh syntax checks
rake test_sh    # POSIX shell checks
rake test_bats  # bats test which are colocated with the source code
```

## ShellCheck

Configuration in `.shellcheckrc`.
