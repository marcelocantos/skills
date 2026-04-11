# go patterns

## Profiling

```bash
# Build timing
time go build ./...

# Compiler profiling (shows per-package time)
go build -x ./... 2>&1 | grep -E "^(compile|link)" | head

# Show what's being rebuilt
go build -a -x -v ./... 2>&1 | head -100   # -a forces full, for baseline

# Test timing
go test -v -count=1 ./... 2>&1 | grep -E "^(=== RUN|--- PASS|--- FAIL|PASS|FAIL|ok|BenchmarkResult)"

# Trace individual package compile
go build -gcflags="-m -m" ./mypackage   # escape analysis + inlining
go build -gcflags="-trace=trace.out" ./mypackage
```

## Patterns

### `GOCACHE` on a volume that gets wiped
**Symptom**: Every build recompiles stdlib and deps.
**Detection**: `go env GOCACHE` points to `/tmp/...` or similar.
**Fix**: set `GOCACHE` to a persistent location (default on macOS
is `~/Library/Caches/go-build`, which is fine). In CI, cache it
explicitly.

### `GOMODCACHE` not cached in CI
**Symptom**: CI downloads all deps every run.
**Detection**: CI config doesn't cache `$GOMODCACHE` (or use
`actions/setup-go` with `cache: true`).
**Fix**: enable Go module caching in the CI action.

### `CGO_ENABLED=1` without needing it
**Symptom**: Builds require a C toolchain and are slower.
**Detection**: no cgo code in the project, but `CGO_ENABLED` not set
to 0.
**Fix**: `CGO_ENABLED=0 go build ./...`. Significantly faster and
produces static binaries.
**Risk**: Low if no cgo deps. Verify by checking for `import "C"` in
the codebase.

### Over-broad package structure
**Symptom**: Changing one file rebuilds many packages.
**Detection**: use `go list -f '{{.Deps}}' ./...` to see import graph
depth. Look for "util" or "common" packages imported everywhere.
**Fix**: split common packages by concern. Go's compilation unit is
the package — smaller, focused packages compile incrementally better.

### Reflection-heavy deps in hot imports
**Symptom**: Clean builds dominated by `encoding/json`, `reflect`, or
reflection-heavy third-party libs (some ORMs).
**Detection**: `go build -x` showing these packages as hot.
**Fix**:
- Use code-gen alternatives: `easyjson`, `ffjson`, `protoc-gen-go`
  with fast marshallers.
- Evaluate whether the reflection-based API is actually needed.

### `go generate` in the default flow
**Symptom**: Every build runs codegen.
**Detection**: Makefile or build script runs `go generate ./...`
before `go build`.
**Fix**: `go generate` should be a pre-commit step or explicit
command, not part of every build. Commit generated code.

### `go test ./...` running integration tests
**Symptom**: `go test` on the whole module runs slow integration
tests.
**Detection**: integration tests without build tags.
**Fix**: use build tags (`//go:build integration`) to separate
integration tests. Default `go test ./...` runs unit tests only;
CI runs `go test -tags=integration ./...` in a separate job.

### Missing `-count=1` in CI
**Symptom**: Flaky test results due to test result caching.
**Detection**: `go test ./...` without `-count=1` in CI.
**Fix**: use `-count=1` to disable test caching in CI. Locally,
test caching is a feature, not a bug.
**Note**: this is a correctness fix, not a perf fix, but often
conflated with "why is CI slow / passing inconsistently".

### Linker dominance
**Symptom**: Link phase is the biggest cost.
**Detection**: `go build -x` showing `link` step dominating.
**Fix**:
- Split large monolithic binaries into smaller tools.
- `-ldflags='-s -w'` for release binaries (strip symbols and DWARF).
- Avoid `-race` except in dedicated race-detection jobs.

### `golangci-lint` re-linting everything
**Symptom**: Lint takes as long as the build.
**Detection**: `golangci-lint run` without cache.
**Fix**: golangci-lint caches by default; ensure its cache dir
(`~/.cache/golangci-lint`) is persistent and cached in CI.
