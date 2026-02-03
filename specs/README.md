# Component Specifications

This directory contains detailed specifications for each component in the dotfiles repository.

## Dotfile Components

| Component | Spec File | Code Location | Description |
|-----------|-----------|---------------|-------------|
| Rakefile DSL | [rakefile-dsl.md](rakefile-dsl.md) | `lib/`, `Rakefile` | Ruby-based build system with custom DSL for managing configuration files |

## Development Tools

| Tool | Spec File | Code Location | Description |
|------|-----------|---------------|-------------|
| cfg | [cfg.md](cfg.md) | `bin/cfg`, `lib/cfg/` | Encrypted configuration manager using SSH agent signing and 1Password for secure multi-config management |
| optpl | [optpl.md](optpl.md) | `bash/bin/optpl` | 1Password template injector for secure credential management |
| boxed | [boxed.md](boxed.md) | `bash/boxed/` | Lightweight bubblewrap-based sandboxing with profile-based configuration |
| ↳ npm Profile | [boxed-npm.md](boxed-npm.md) | `bash/boxed/profiles.d/npm` | npm package operations with network and cache persistence |
| ↳ ai-jail Profile | [boxed-ai-jail.md](boxed-ai-jail.md) | `bash/boxed/profiles.d/ai-jail` | AI agent sandbox with config isolation and prompt injection |
| **Sandbox** | **[sandbox.md](sandbox.md)** | `bash/bin/sandbox` | **Backend-independent sandbox orchestration and IDE integration** |
| ↳ Common Library | [sandbox-common.md](sandbox-common.md) | `bash/lib/sandbox/common` | Shared utilities for state dirs, SSH wait, SSH aliases. Automatically available to all backends. |
| ↳ Container Backend | [sandbox-container.md](sandbox-container.md) | `bash/lib/sandbox/container-backend` | Docker/Podman-based sandboxes with container isolation |
| ↳ KVM Backend | [sandbox-kvm.md](sandbox-kvm.md) | `bash/lib/sandbox/kvm-backend` | QEMU/KVM-based VM sandboxes with full root access |
| ↳ Hetzner Cloud Backend | [sandbox-hcloud.md](sandbox-hcloud.md) | `bash/lib/sandbox/hcloud-backend` | Hetzner Cloud VMs with ephemeral lifecycle and direct SSH access |
| ↳ Proxy Backend | [sandbox-proxy.md](sandbox-proxy.md) | `bash/lib/sandbox/proxy-backend`, `bash/lib/sandbox/proxy-cli` | Restrictive proxy with domain allowlist |
| ↳ AI Bootstrap | [sandbox-ai-bootstrap.md](sandbox-ai-bootstrap.md) | `bash/lib/sandbox/ai-bootstrap` | AI agent configuration and credential setup for sandboxes |
| **Prompt Patcher Lib** | [prompt-patcher.md](prompt-patcher.md) | `bash/lib/prompt-patcher` | Dynamic AI agent prompt injection for  global instructions and sandbox environment constraints |

## Purpose of These Specs

Feature specs are **interface documents for human engineers to guide AI agents** during implementation. They provide clear descriptions, architectural constraints, critical guardrails, and success criteria - NOT exhaustive implementation documentation.

## Documentation Guidelines

When working with features:

- **Writing a new feature spec?** → Read [how-to-write-specs.md](how-to-write-specs.md)
- **Planning feature implementation?** → Read [how-to-write-implementation-plans.md](how-to-write-implementation-plans.md)

## Quick Reference

| Document Type | Purpose | When to Create | Length |
|--------------|---------|----------------|--------|
| **Feature Spec** | Define WHAT and WHY | Before implementation starts | 1-2 pages |
| **Implementation Plan** | Define HOW and WHEN | At start of implementation | As needed |

## Contributing

When working with a spec (Creating, Updating, Reviewing) use these guidelines: [how-to-write-specs.md](how-to-write-specs.md).

When adding a new features or specs:
1. Create or update a spec using the guidelines
2. Add an entry to the Components table above
3. Create an implementation plan if needed (see [how-to-write-implementation-plans.md](how-to-write-implementation-plans.md))
4. Stop. Implementation is triggered in a new session
