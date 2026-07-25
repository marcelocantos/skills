# `data/line-excludes.yaml` — fleet line-stat excludes

Single file in the **progress-reports** repo (not in each project):

`~/work/github.com/marcelocantos/progress-reports/data/line-excludes.yaml`

Read by `gather.sh` when computing progress-report ☲. Commits are **not**
filtered — only insertion/deletion stats.

Override path: `PROGRESS_LINE_EXCLUDES=/path/to/file.yaml`.

## Schema

```yaml
# Optional extra globals (merged with hard-coded vendor/node_modules).
defaults: []

# Per-repo globs keyed by org/repo (same label gather.sh prints).
repos:
  squz/ge:
    - verdicts/**
    - sample/tiltbuggy/fixtures/**
  squz/yourworld2:
    - golden/**
    - docs/golden/**
  marcelocantos/rustuml:
    - test-diagrams/**
    - test-fixtures/**
```

### Rules

| Rule | Detail |
|------|--------|
| Location | `progress-reports/data/line-excludes.yaml` only |
| Keys | `defaults:` (optional list), `repos:` (map of `org/repo` → list) |
| Glob syntax | git pathspecs, repo-relative (e.g. `verdicts/**`) |
| Always excluded | `**/vendor/**`, `**/node_modules/**` (hard-coded in gather.sh) |
| Commits | Still count toward ℂ |
| Binaries | `.a` / LFS already ≈0 lines; no need to list for kloc |

### What to list

- Golden / fixture / oracle corpora
- Generated trees that must stay committed but should not score as authorship
- Amalgamations **not** under `vendor/` (prefer moving under `vendor/` long-term)

### Maintenance (every `/progress-report` run)

`worker.md` requires the agent to **consider updating this file** whenever it:

1. Sees a **new repo** in gather output, or
2. Sees **new bulk content** in an existing repo (first-time goldens, verdicts,
   fixtures, amalgamations, generated dumps, etc.).

Workflow: edit globs → re-run `gather.sh` for the week → use the new `landed:`
figures in the draft → stage `data/line-excludes.yaml` with the report commit.
Do **not** put `.progress-report.yaml` (or similar) inside project repos.

### gather.sh output

```
exclude-config: line-excludes.yaml[squz/ge] → verdicts/** sample/tiltbuggy/fixtures/**
landed-excluded: N file changes, +X/-Y (defaults + line-excludes.yaml — not in headline)
```

Use `landed:` for Metrics ☲; footnote `landed-excluded` only.
