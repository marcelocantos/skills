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

### sccache not configured
**Symptom**: First-time builds of common deps slow.
**Detection**: `which sccache; cat ~/.cargo/config.toml | grep rustc-wrapper`.
**Fix**: install sccache, set `[build] rustc-wrapper = "sccache"` in
`~/.cargo/config.toml` or the project's `.cargo/config.toml`.
**Risk**: Low — sccache is well-tested with cargo.

### `cargo clean` in scripts or CI
**Symptom**: CI always does clean builds.
**Detection**: grep CI config for `cargo clean`.
**Fix**: use `actions/cache` keyed on `Cargo.lock` to cache `target/`.
Rust-specific cache actions like `Swatinem/rust-cache` handle this
well.

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
