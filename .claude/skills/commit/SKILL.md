---
name: commit
description: commit
---

# Commit

Generates a conventional commit message and commits changes.

## Workflow

1. **Check for changes**: Run `git status --short` and `git diff` (staged + unstaged). Abort if nothing to commit.
2. **Analyze changes**: Review the diff to understand what changed and why.
3. **Generate commit message**: Draft a message following the format below.
4. **Show for confirmation**: Display the full proposed commit message and ask the user to confirm.
5. **Commit**: Stage relevant files and run `git commit` with the approved message. Use a HEREDOC to pass the message.

## Commit Message Format

```
<type>(<scope>): <short description>

<detailed description>
```

### Types
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `style:` Code style changes (formatting, etc.)
- `refactor:` Code refactoring
- `perf:` Performance improvements
- `test:` Test additions or changes
- `chore:` Build process or auxiliary tool changes

### Rules
- Scope is optional — use when changes are focused on a specific area (e.g. `feat(tournaments):`)
- Short description: imperative mood, lowercase, no period, under 72 chars
- Detailed description: explain what changed and why in bullet points
- Do NOT add co-authors or other tags.
- **NO emojis** in commit messages
- **Avoid double quotes (`"`)** in the message. Single quotes (`'`) are fine. Double quotes are valid only if properly escaped or passed via HEREDOC; default to no double quotes and confirm with the user before adding any.
- Keep messages professional and concise

## Example

```
feat(tournaments): add auto-fold logic for participants

Added new auto-fold logic for tournaments to prevent infinite games:
- Added Oban timeout job with configurable timeout
- Added tests for new functionality
...
```
