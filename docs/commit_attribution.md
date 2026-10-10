# Commit attribution

Commits in this repository must be authored by a human GitHub account.

Do not add Cursor, Claude, or cursoragent as **Author** or **Co-authored-by**.

This file is the policy. The hook is what actually strips those trailers on commit.

Enable the hook from the repository root (local to this clone):

```bash
git config core.hooksPath .githooks
```

The hook [`.githooks/commit-msg`](../.githooks/commit-msg) removes any `Co-authored-by` / `Co-Authored-By` line that mentions Cursor, cursoragent, Claude, or anthropic.
