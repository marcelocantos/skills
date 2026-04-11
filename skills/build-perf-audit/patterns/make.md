# make / GNU make patterns

## Profiling

```bash
# Overall timing
time make <target>

# Per-target timing via --trace
make --trace <target> 2>&1 | ts '[%H:%M:%.S]'

# Job graph (understand parallelism potential)
make -n -d <target> 2>&1 | less

# Dry-run to see what would execute
make -n <target>

# Find targets that always rebuild
make <target>; make <target>    # second run should be a no-op
```

## Patterns

### `.PHONY` misuse
**Symptom**: targets always rebuild.
**Detection**: grep `.PHONY:` and check which targets are listed. Real
file targets should not be phony. Common mistake: `.PHONY: all build
install test` where `build` is actually a file.
**Fix**: only phony targets that don't correspond to files. For real
output files, use stamp files if the real output is a directory.

### Missing `MAKEFLAGS := -j`
**Symptom**: CPU underutilised.
**Detection**: no `MAKEFLAGS` in the Makefile, and users aren't passing
`-j` themselves.
**Fix**: add near the top of the Makefile:
```make
MAKEFLAGS := --jobs
```
Note the user's global rule: **never pass `-j` on the command line**.
Projects that want parallelism set it in the Makefile.

### Recursive make without `.NOTPARALLEL` discipline
**Symptom**: Broken parallel builds, or sub-makes that serialise.
**Detection**: multiple `$(MAKE) -C subdir` invocations without proper
dependency declaration between them.
**Fix**: either flatten to a single make instance (preferred), or
declare proper inter-directory dependencies so `-j` works at the top
level.

### Implicit rules triggering unexpected rebuilds
**Symptom**: Files rebuild when they shouldn't.
**Detection**: `make -d` output shows implicit rule matches you didn't
expect.
**Fix**: explicit rules for your files, or `MAKEFLAGS += --no-builtin-rules`.

### `$(shell ...)` re-running on every parse
**Symptom**: Even no-op make invocations are slow.
**Detection**: `$(shell ...)` in top-level scope — runs every time make
parses the Makefile, including for `make -n`.
**Fix**: move shell invocations into recipe bodies, or cache the
result into a file and read that.

### Missing order-only prerequisites for directories
**Symptom**: Build fails on first run but succeeds on second, or
directories rebuild as prerequisites trigger rebuilds.
**Fix**: use order-only prerequisites (`target: normal-prereqs | dir-prereqs`)
for output directories.
