# Commit attribution

Commits in this repository must be authored by a human GitHub account.

Do not add third-party automated assistants as **Author** or **Co-authored-by**.

Enable the hook from the repository root (local to this clone):

```bash
git config core.hooksPath .githooks
```

The hook [`.githooks/commit-msg`](../.githooks/commit-msg) removes `Co-authored-by` / `Co-Authored-By` trailers so they cannot land on `main`.
