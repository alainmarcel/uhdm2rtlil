# Git Hooks

This directory contains Git hooks for the uhdm2rtlil project.

## Pre-commit Hook

The pre-commit hook prevents:
1. Committing files larger than 10MB to the repository
2. Committing temporary test files from `test/run/**/*.v`

## Setup

To enable these hooks, run the following command from the repository root:

```bash
git config core.hooksPath .githooks
```

Or to set it up automatically when cloning the repository, add this to your project documentation.

## Bypass

If you absolutely need to commit a large file (not recommended), you can bypass the hook with:

```bash
git commit --no-verify
```

However, it's better to use Git LFS for large files or add them to `.gitignore`.