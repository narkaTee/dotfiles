# AGHENTS.md

## Installing dotfiles for testing

When running test on the system you should install the dotfiles via rake.

Try to use specific tasks to only install what you want to test.
For example when testing a bash script run `rake bash`

Take a look at the [Rakefile](Rakefile) to understand what tasks are available and what they install.

## Testing

After making changes run the appropiate checks/tests.

```bash
rake check  # Runs all checks (shellcheck + shell syntax)
rake shellcheck # Shellcheck
rake test_bash  # Bash syntax checks
rake test_zsh   # Zsh syntax checks
rake test_sh    # POSIX shell checks
rake test_bats  # bats test which are colocated with the source code
rake test_cfg   # cfg cli tool tests
```

## ShellCheck

Configuration in `.shellcheckrc`.
