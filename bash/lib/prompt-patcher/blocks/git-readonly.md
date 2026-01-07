# Git Repository Access

The `.git` directory is mounted **read-only** in this sandbox.

## Allowed Operations
- Read git history, diffs, logs, and status
- View branch information and inspect commits
- Examine file changes with `git show`, `git diff`

## Blocked Operations
The following will fail with a read-only error:
- `git commit` - cannot create commits
- `git checkout`, `git switch` - cannot change branches
- `git config` - cannot modify git configuration
- `git push`, `git pull` - cannot modify remote state

## How to Handle User Requests

If the user asks for a write operation (commit, branch, push, etc.):
1. **Acknowledge** what they want to accomplish
2. **Explain** that git modifications require running commands outside the sandbox
3. **Provide** the exact commands they need to run locally (e.g., `git commit -m "message"`)
4. **Do NOT** attempt the operation or pretend it might work

Example response: "To commit these changes, run this outside the sandbox: `git add . && git commit -m 'your message'`"
