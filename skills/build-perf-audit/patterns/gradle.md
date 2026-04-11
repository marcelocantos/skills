# gradle patterns

## Profiling

```bash
# Build scan — the definitive profiling tool
./gradlew <task> --scan

# Profile report (no account required)
./gradlew <task> --profile
# Output in build/reports/profile/

# Dry run — see what tasks would execute
./gradlew <task> --dry-run

# Task execution timing
./gradlew <task> --info | grep "Task execution statistics"

# Check cache hits
./gradlew <task> --build-cache
# Then look for "UP-TO-DATE" and "FROM-CACHE" annotations
```

## Patterns

### Build cache not enabled
**Symptom**: No "FROM-CACHE" annotations on task outputs.
**Detection**: `grep "org.gradle.caching" gradle.properties`.
**Fix**: add `org.gradle.caching=true` to `gradle.properties`.
**Risk**: Medium — custom tasks need correct `@Input`/`@Output`
annotations to cache correctly. Incorrect annotations cause silent
stale outputs.

### Configuration cache not enabled
**Symptom**: Slow configuration phase even for no-op builds.
**Detection**: `grep "configuration-cache" gradle.properties`.
**Fix**: add `org.gradle.configuration-cache=true`. Gradle will report
any tasks that aren't compatible.
**Risk**: Medium — not all plugins support it. Report what breaks
rather than auto-applying.

### Parallel execution disabled
**Symptom**: Multi-module builds slow, one module at a time.
**Detection**: `grep "org.gradle.parallel" gradle.properties`.
**Fix**: add `org.gradle.parallel=true`.
**Risk**: Low for decoupled projects, Medium for projects with
cross-module dependencies that rely on evaluation order.

### Daemon disabled
**Symptom**: Every invocation has JVM startup overhead.
**Detection**: `org.gradle.daemon=false`, or `--no-daemon` in
scripts.
**Fix**: enable the daemon. In CI, use `--daemon` — GitHub Actions
runners are ephemeral anyway, but the daemon helps within a single
job.

### Android: `minifyEnabled` in debug
**Symptom**: Debug builds include R8/ProGuard.
**Detection**: `buildTypes.debug.minifyEnabled = true`.
**Fix**: only enable minification for release. Debug builds should
skip R8 entirely.

### KAPT instead of KSP
**Symptom**: Kotlin annotation processing dominates build time.
**Detection**: `apply plugin: 'kotlin-kapt'` or `id("kotlin-kapt")`.
**Fix**: migrate to KSP where the library supports it (Room, Moshi,
Dagger/Hilt 2.48+, etc.). KSP is typically 2x faster than KAPT.
**Risk**: Medium — migration requires changes to each annotation
processor.

### Transformations not using compileOnly
**Symptom**: Heavy dependencies bundled where not needed.
**Detection**: `implementation` used for annotation processor APIs or
codegen runtimes.
**Fix**: use `compileOnly` for build-time-only deps.

### Applied plugins that aren't used
**Symptom**: Longer configuration time.
**Detection**: `./gradlew help --dry-run` shows plugin application
cost in the `--profile` report.
**Fix**: remove unused plugins. In multi-module, apply plugins only
to modules that need them, not globally.

### Wrong `max-workers` or no `--max-workers` tuning
**Symptom**: Build uses default parallelism which may not match
hardware.
**Detection**: no `org.gradle.workers.max` in `gradle.properties`.
**Fix**: on Marcelo's M4 Max (16 cores), set something like
`org.gradle.workers.max=12` to leave headroom for the OS. Not a big
win typically — Gradle defaults are reasonable.
