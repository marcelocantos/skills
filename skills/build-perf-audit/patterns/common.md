# Cross-cutting build performance patterns

These apply regardless of build system. Check these first — they cover
the most common wins and rule-of-thumb sanity checks.

---

## No or broken cache

**Symptom**: Incremental builds are nearly as slow as clean builds.

**Detection**:
- Run a clean build, note time.
- Run it again immediately with no changes.
- If the second run is > 20% of the first, something isn't caching.

**Common causes**:
- Compiler cache (ccache, sccache) not installed or not wired into the
  build's compiler invocation.
- Build cache disabled (`--no-cache`, `CARGO_INCREMENTAL=0`, etc.)
- Cache directory on a volume that gets wiped (`/tmp` on some systems,
  Docker volumes without mounts).
- Timestamp-based caching defeated by `touch`, `find -exec`, or VCS
  operations that rewrite mtimes.
- Inputs include something that changes every build (current time,
  git describe output, build counter).

**Fix**: install / enable the cache, verify it's being hit with its
stats command (`ccache -s`, `sccache --show-stats`).

**Risk**: Medium — cache misconfig can cause stale artifact bugs.
Always verify correctness after enabling.

---

## Serial where parallel is safe

**Symptom**: CPU utilisation well below 100% × core count during build.

**Detection**: `time make ...` → compare `user` vs `real`. If
`user / real` is much less than core count, you're under-parallelised.

**Common causes**:
- `make` without `-j` and no `MAKEFLAGS` default.
- Test runner in single-threaded mode (`pytest` without `-n`, `cargo
  test -- --test-threads=1`).
- Docker build steps running serially when they're independent.
- `xargs` without `-P`, shell loops instead of `parallel`.

**Fix**: enable parallelism at the right granularity. For make, set
`MAKEFLAGS := -j` in the Makefile (don't pass `-j` on the command
line — see global CLAUDE.md rule).

**Risk**: Low for compilation, Medium for tests (races and shared
fixtures), High for Docker (layer interdependencies).

---

## Heavy tests in the hot path

**Symptom**: Every local build or every CI check runs the full test
suite, including slow integration/e2e/perf tests.

**Detection**: look for `make test`, `cargo test`, `go test ./...` in
the default target, in pre-commit hooks, or in the main CI job without
tiering.

**Fix**: split tests into tiers — fast unit tests on every build,
integration tests on PR, slow/e2e tests on merge or nightly. Use test
markers / tags / target separation.

**Risk**: Low — you're not removing tests, just relocating them. But
be careful to ensure the slow tests still run *somewhere* and that
"somewhere" is actually monitored.

---

## Debug info / LTO / sanitisers on by default

**Symptom**: Clean build takes minutes even for small codebases.

**Detection**: check default build flags for `-g3`, `-flto`, `-fsanitize=*`,
`--release`, `CMAKE_BUILD_TYPE=RelWithDebInfo`, `opt-level = 3` in dev
profile, etc.

**Fix**: use minimal optimisation and debug info for dev builds.
Reserve expensive flags for explicit release / debug builds.

**Risk**: Low — just make sure CI release builds still use the
expensive flags. Don't accidentally ship un-optimised release binaries.

---

## Overly broad file globs

**Symptom**: Changing one file rebuilds the world.

**Detection**: look for `**/*.h`, `$(wildcard **)`, `sources = glob(["**/*"])`,
or dependency declarations that pull in all headers from all modules.

**Fix**: tighten dependency granularity. Split monolithic headers.
Use forward declarations. For generated files, depend on a stamp file,
not the generator.

**Risk**: Medium — tightening can introduce missing-dependency bugs
where files don't rebuild when they should. Verify with an intentional
header change + incremental build.

---

## Redundant work

**Symptom**: The same command appears multiple times in build output.

**Detection**: grep the build log. Common offenders:
- Codegen step running in multiple targets that each copy the output.
- Linter running once as a pre-build hook and once as a check target.
- Type checker running inside the compiler and again standalone.
- `go mod download` running before `go build` which also downloads.
- CI job re-installing dependencies that the Docker image already has.

**Fix**: consolidate. One generator, one output, multiple consumers
depending on the single output.

**Risk**: Low.

---

## Missing incremental mode

**Symptom**: Local scripts or CI pipelines do `rm -rf build/`,
`cargo clean`, `make clean`, etc. on every invocation.

**Detection**: grep build scripts and CI config for `clean`, `rm -rf`,
`--clean`, `--fresh`, `mvn clean install`.

**Fix**: remove the clean step. If it exists because "clean is
safer", that's a cache invalidation bug — fix the root cause instead
of papering over it with clean builds. Keep clean available as an
explicit command, just don't run it by default.

**Risk**: Medium — if clean was masking a real invalidation bug,
removing it will surface the bug. That's the point, but fix the bug.

---

## Re-downloading dependencies

**Symptom**: Every build fetches deps from the network.

**Detection**: look for `go mod download`, `npm ci`, `pip install`,
`cargo fetch`, `bundle install`, etc. in the default flow, without any
caching layer.

**Fix**:
- Local: trust the tool's default cache location, don't wipe it.
- Docker: copy manifest files first, install deps, then copy source.
  This keeps the deps layer cached across source changes.
- CI: use cache actions (`actions/cache`, `actions/setup-go` with
  `cache: true`, etc.).

**Risk**: Low for local, Low-Medium for Docker (layer ordering), Low
for CI cache actions.

---

## Monolithic targets

**Symptom**: One big target rebuilds 100 files when one file changed.

**Detection**: look for single-target structures where the build system
can't tell which outputs depend on which inputs — e.g. one big
`all.o`, one giant `cc` invocation with all sources, a single Gradle
task wrapping everything.

**Fix**: split into per-source-file or per-module targets and let the
build system track dependencies properly.

**Risk**: Medium — refactoring the build structure can introduce
ordering bugs.

---

## Wrong granularity — tiny targets

The opposite problem: thousands of tiny steps with per-step overhead
exceeding the actual work.

**Symptom**: Build spends more time in build-system overhead than in
compilation.

**Detection**: `ninja -d stats`, `make --debug=j`, or similar. If
per-step overhead dominates, this is it.

**Fix**: batch. `cc -c a.c b.c c.c` is cheaper than three separate
invocations if you don't need separate cache entries. Precompiled
headers. Unity builds (with caveats).

**Risk**: Medium — unity builds hurt incremental compile times in
return for faster clean builds. Trade-off, not a free win.
