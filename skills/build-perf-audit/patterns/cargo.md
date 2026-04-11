# cargo / Rust patterns

## Profiling

```bash
# Built-in build timing — the main tool
cargo build --timings
# Opens target/cargo-timings/cargo-timing.html in a browser-ready form

# Per-crate build timing via env var
CARGO_LOG=cargo::core::compiler::timings=info cargo build

# Test timing
cargo test -- --show-output --nocapture -Z unstable-options --report-time

# Check what's being recompiled
CARGO_LOG=cargo::core::compiler::fingerprint=info cargo build 2>&1 | less
```

## Patterns

### `codegen-units = 1` in dev profile
**Symptom**: Slow incremental builds.
**Detection**: `Cargo.toml` has `[profile.dev] codegen-units = 1`.
This is a release optimisation; in dev it kills parallelism.
**Fix**: remove it from `[profile.dev]` (default is 256).

### LTO in dev
**Symptom**: Slow link times.
**Detection**: `[profile.dev] lto = ...` set to anything other than
`false` or `"off"`.
**Fix**: LTO should be off in dev. Keep it for release.

### `opt-level = 3` in dev
**Symptom**: Slow compile.
**Detection**: `[profile.dev] opt-level = 3`.
**Fix**: dev should be `opt-level = 0` (default) or `1` if you need
some optimisation for perf testing. Use `[profile.dev.package.*]`
overrides for specific crates that need to be fast (e.g. crypto libs
in test workloads).

### Monolithic crate
**Symptom**: Changing one file recompiles huge amounts of code.
**Detection**: one giant crate with all modules. `cargo build --timings`
shows the whole crate as one long bar.
**Fix**: split into workspace crates. Cargo's compilation unit is the
crate — splitting is the main lever for incremental compile speed.

### Proc macro heavy dependencies
**Symptom**: Clean build is dominated by `syn`, `serde_derive`, etc.
**Detection**: `cargo build --timings` shows proc-macro-heavy crates
dominating.
**Fix**:
- Use `cargo-nextest` for tests (faster test runner).
- Consider `rkyv` or manual impls instead of derived `Serialize`/
  `Deserialize` for hot paths.
- Ensure proc macros are compiled once, not rebuilt.

### sccache not configured (for shared / multi-machine caches)
**Symptom**: First-time builds of common deps slow across a team or
self-hosted runner pool where `rust-cache` can't reach.
**Detection**: `which sccache; cat ~/.cargo/config.toml | grep rustc-wrapper`.
**Fix**: install sccache, set `[build] rustc-wrapper = "sccache"` in
`~/.cargo/config.toml` or the project's `.cargo/config.toml`. Point
it at a shared backend (S3, Redis, GCS) via `SCCACHE_*` env vars.
**Risk**: Low — sccache is well-tested with cargo.

**When to prefer sccache over `Swatinem/rust-cache`**:
- Cross-machine caches (team dev boxes, self-hosted runner pools).
- Local dev where you regularly blow away `target/` or switch between
  many branches that each trigger dep rebuilds.

For single-repo GitHub Actions CI, prefer `Swatinem/rust-cache@v2`
(see "No build cache in CI") — simpler, no external backend needed.

### No build cache in CI (or `cargo clean` in scripts)
**Symptom**: CI always does clean builds. Every run recompiles the
entire dependency graph (tokio, serde, regex, proc-macro stack, etc.)
from scratch, even when nothing in those deps changed. This is often
the single largest CI wall-time win on a cargo project.

**Detection**:
- grep CI config for `cargo clean`, missing cache steps, or the
  absence of any `Cache*` / `cache:` / `rust-cache` action before the
  first cargo invocation.
- Compare two back-to-back CI runs; if both are the same duration,
  there's no cache.

**Fix**: on GitHub Actions, add `Swatinem/rust-cache@v2` as a step
after `rustup toolchain install` but before the first cargo
invocation. It's the de-facto standard Rust cache action — keys on
`Cargo.lock` content + toolchain version, caches `~/.cargo/registry`,
`~/.cargo/git`, `~/.cargo/bin`, and `target/`, and auto-invalidates on
dep changes. For matrix builds (multi-target releases), pass
`with: { key: ${{ matrix.target }} }` so per-target caches don't
clobber each other.

```yaml
- name: Install Rust toolchain
  run: rustup toolchain install stable --profile minimal
- name: Cache cargo registry and build artifacts
  uses: Swatinem/rust-cache@v2
- run: cargo test
```

For GitLab CI or other runners without a dedicated action, use
`actions/cache`-equivalent keyed on `Cargo.lock` to cache `~/.cargo`
and `target/`.

**Expected impact on bullseye-sized projects** (~20 direct deps, one
binary): warm-cache CI wall drops from ~50s to ~20s, with clippy and
test compile each dropping ~78% (from ~17-19s to ~4s). Measured on
linux-amd64 ubuntu-latest on 2026-04-11.

**Risk**: Low. Rust-cache fails closed (forces rebuild) if the cache
is unusable, and cargo's fingerprint tracking means a stale cache
produces extra compile work, not wrong artifacts. Verify with one cold
run (populate) + one warm run (restore) and check both produce green
tests.

**Not a fit for rust-cache**:
- **Multi-machine shared caches** (e.g., a team dev-box or self-hosted
  runner pool). `rust-cache` is per-repo on GitHub Actions; use
  `sccache` with a shared S3 or Redis backend for cross-machine hits.
- **Local dev**: cargo's own incremental cache already handles this.
  sccache adds value locally only when you're regularly blowing away
  `target/` or jumping between many branches that each rebuild deps.

### Workspace without `resolver = "2"`
**Symptom**: Feature unification causes unnecessary recompiles.
**Detection**: workspace `Cargo.toml` missing `resolver = "2"`.
**Fix**: add `resolver = "2"` to `[workspace]`. Default in edition
2021+ but workspaces need it explicit.

### Tests using `--test-threads=1`
**Symptom**: Test suite runs serially.
**Detection**: grep for `--test-threads=1`, `test_threads = 1`, or
`#[serial]` overuse.
**Fix**: fix shared-state tests to not require serialisation, use
per-test fixtures. If truly needed, isolate with `nextest` test
groups.
