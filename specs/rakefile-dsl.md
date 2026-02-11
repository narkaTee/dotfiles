# Rakefile DSL

## Overview

The Rakefile DSL is a Ruby-based build system for managing dotfile installations and configurations. It provides a declarative API for syncing files, managing directories, and cloning git repositories. The DSL simplifies configuration management by abstracting common operations into reusable Ruby functions.

## Key Constraints & Design Decisions

- **Ruby-based**: Requires Ruby runtime. All configuration logic is written in `Rakefile` using Ruby.
- **Declarative API**: Uses method chaining and blocks for readable configuration definitions
- **ShellCheck integration**: Built-in support for shell script validation via `rake check`
- **Platform detection**: Provides helpers (`is_macos`, `is_linux`, `has_command`) to enable cross-platform configurations
- **Git repository management**: Handles cloning, updating, and pruning git repos declaratively

## API Reference

- `Cfg.file(permissions, src:, dst:)` - Install a single file with permissions
- `Cfg.directory(path) { purge; source "dir/"; ignore "pattern" }` - Sync a directory, optionally purge unmanaged files
- `Cfg.git_directory(path, { name: url, ... })` - Manage multiple git repos in a directory (clone/update/prune)
- `Utils.git(url, path)` - Clone a single git repo or pull if it already exists
- `is_macos`, `is_linux`, `has_command(name)` - Platform detection helpers

## Usage

**DSL examples:**

Install a single configuration file:
```ruby
Cfg.file("0644", src: "bash/bashrc", dst: "#{HOME}/.bashrc")
```

Manage a directory with automatic sync and cleanup:
```ruby
Cfg.directory "#{HOME}/.config/nvim/" do
  purge          # Remove files not in source
  source "nvim/" # Sync from this directory
  ignore "*.swp" # Don't sync swap files
end
```

Clone and manage git repositories:
```ruby
Cfg.git_directory("#{HOME}/.vim/pack/plugins/start/", {
  sensible: "https://github.com/tpope/vim-sensible.git",
  fugitive: "https://github.com/tpope/vim-fugitive.git"
})
```

Platform-specific configuration:
```ruby
if is_macos
  Cfg.file("0644", src: "macos/config", dst: "#{HOME}/.config")
elsif is_linux && has_command("systemctl")
  Cfg.file("0644", src: "linux/service", dst: "#{HOME}/.config/systemd/user/")
end
```
