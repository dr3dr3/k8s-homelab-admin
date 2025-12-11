# Copilot Agent: Commit and Create PR

## Purpose

This agent helps prepare changes for review by:

1. Reviewing all uncommitted changes in the workspace
2. Creating a short-lived feature branch
3. Committing changes with a concise, descriptive message
4. Pushing to remote and creating a Pull Request ready for review

## Instructions

When the user asks to commit and create a PR, follow these steps:

### Step 1: Review Changes

First, examine all uncommitted changes:

```bash
# Check current branch and status
git status

# Show detailed diff of all changes
git diff

# Show staged changes if any
git diff --staged

# List all modified, added, and deleted files
git diff --name-status
```

Provide a summary of:

- Which files were modified, added, or deleted
- The nature of the changes (new features, bug fixes, refactoring, documentation, etc.)
- Any potential issues or concerns with the changes

### Step 2: Create Feature Branch

Generate an appropriate branch name based on the changes:

- Use format: `{type}/{short-description}`
- Types: `feat/`, `fix/`, `refactor/`, `docs/`, `chore/`, `test/`
- Keep description short (3-5 words, kebab-case)
- Examples:
  - `feat/add-eks-workspace`
  - `fix/terraform-backend-config`
  - `refactor/align-folder-naming`
  - `docs/update-readme`
  - `chore/update-dependencies`

```bash
# Create and switch to the new branch
git checkout -b {branch-name}
```

### Step 3: Stage and Commit Changes

Stage all changes and create a commit with a descriptive message:

```bash
# Stage all changes
git add -A

# Create commit with conventional commit format
git commit -m "{type}: {concise description}"
```

Commit message guidelines:

- Use conventional commit format: `type: description`
- Types: `feat`, `fix`, `refactor`, `docs`, `chore`, `test`, `style`, `perf`
- Keep the first line under 72 characters
- Use imperative mood ("add" not "added")
- Be specific but concise

Examples:

- `feat: add EKS workspace configuration for development`
- `fix: correct IAM role ARN in OIDC provider`
- `refactor: align folder names with TFC workspace naming`
- `docs: update bootstrapping guide with new steps`
- `chore: update terraform providers to latest versions`

### Step 4: Push and Create PR

Push the branch and create a Pull Request:

```bash
# Push the new branch to origin
git push -u origin {branch-name}

# Create PR using GitHub CLI
gh pr create --title "{PR title}" --body "{PR description}" --base main
```

PR title should match the commit message.

PR body should include:

- Summary of changes
- List of files modified
- Any notes for reviewers
- Related issues if applicable

Template for PR body:

```markdown
## Summary

{Brief description of what this PR does}

## Changes

{List of key changes}

- Modified: `path/to/file`
- Added: `path/to/new/file`
- Deleted: `path/to/removed/file`

## Notes for Reviewers

{Any context or specific areas to focus review on}
```

### Step 5: Clean Up Local Workspace

Return to the main branch and update it:

```bash
# Switch back to main branch
git checkout main

# Pull latest changes from remote
git pull origin main
```

This ensures your workspace is ready for the next task.

### Step 6: Confirm Success

After creating the PR, provide:

- Link to the PR
- Summary of what was committed
- Confirmation that local workspace is back on `main` and up-to-date
- Reminder that the branch will be auto-deleted after merge (per repository settings)

## Repository Context

This workspace is the `k8s-homelab-admin` repository owned by `dr3dr3` with:

- Default branch: `main`
- Branch protection: Requires PR with 1 approving review
- Auto-delete branches on merge: enabled
- Squash merge: enabled

## Example Interaction

User: "Commit my changes and create a PR"

Agent response flow:

1. Run `git status` and `git diff` to review changes
2. Summarize what changed
3. Suggest branch name and commit message
4. Ask for confirmation or adjustments
5. Execute: create branch, commit, push, create PR
6. Provide PR link and summary

## Error Handling

- If no changes exist: Inform user there's nothing to commit
- If already on a feature branch: Ask if they want to use the current branch or create a new one
- If push fails: Check for authentication issues or branch protection violations
- If PR creation fails: Provide manual instructions using GitHub web UI
