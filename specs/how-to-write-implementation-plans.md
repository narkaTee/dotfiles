# How to Write Implementation Plans

Unlike specs which are stable, implementation plans evolve during implementation.

## When to Create an Implementation Plan

Create an implementation plan for:
- Features with multiple interconnected components
- Changes that affect existing code in multiple places
- Features where the implementation approach isn't immediately obvious
- Complex features that benefit from breaking into phases

Skip the implementation plan for:
- Simple, single-file changes
- Obvious implementations with <3 steps
- Bug fixes with known solutions

## What to Include in an Implementation Plan

1. **Implementation Steps** (ordered list)
   - Specific files to create or modify
   - Dependencies between steps
   - What to implement in each step
   - Testing approach for each step (see Testing Strategy below)

2. **Key Decision Points**
   - Where alternative approaches were considered
   - Why specific choices were made during planning

3. **Risks and Unknowns**
   - Areas where the approach might need adjustment
   - Dependencies on external factors

## Testing Strategy

Each implementation step should define how it will be tested. **This must be determined interactively with the user** - go through each step one by one and ask about the testing approach.

Common testing decisions to discuss:
- Real dependencies vs mocks (e.g., real crypto vs stubbed)
- Integration vs unit tests
- What to stub (external CLIs, user input, file system)
- Shared test fixtures and helpers

Document the agreed approach in each step's **Testing:** section.

## Writing Guidelines

- Break work into logical, testable steps
- Identify dependencies between steps
- Note potential issues before starting
- Update the plan as you learn during implementation
- Focus on approach, not a granular task checklist
- Reference spec sections by header name for traceability (e.g., "see spec: Encryption")

**Small code snippets are useful** for clarity:
- Constants and their values
- Data structure definitions (structs, classes)
- Error class hierarchies
- Function signatures

## Cross-Reference Against Spec

Before finalizing the plan, review it against the feature spec to catch inconsistencies:

**Checklist:**
- [ ] All commands/operations from spec are covered in implementation steps
- [ ] All CLI flags mentioned in spec are included
- [ ] File formats and paths match spec exactly
- [ ] All modules referenced in spec exist in the plan
- [ ] Error cases from spec have corresponding handling
- [ ] Constants and magic values match between spec and plan

This review often reveals ambiguities or missing details in both documents.

Store plans in `specs/` with suffix `-implementation-plan.md`.
