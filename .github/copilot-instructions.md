# Copilot Instructions

## Git Commits

**DO NOT commit changes to the repository unless the user explicitly asks you to do so.**

Even if you make changes to files during development, editing code, or implementing features, you must verify with the user before running any `git add`, `git commit`, or `git push` commands.

### Allowed Actions Without Explicit Request
- Reading files
- Making code changes and edits
- Running tests and diagnostics
- Creating temporary files
- Displaying diffs and comparisons

### Restricted Actions (Require Explicit User Request)
- `git add` - Adding files to staging
- `git commit` - Creating commits
- `git push` - Pushing to remote repository
- Any other git operations that modify repository history

### How to Handle Git Operations
1. Make the necessary code changes
2. Show the user what was changed (display diffs, summarize changes)
3. Wait for explicit instruction like "commit this" or "push to GitHub"
4. Only then execute git commands

This prevents accidental commits and ensures the user maintains control over when changes are persisted to the repository.
