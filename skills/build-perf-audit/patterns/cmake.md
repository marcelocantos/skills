# cmake patterns

## Profiling

```bash
# Configure time
time cmake -S . -B build

# Build time with Ninja (preferred generator)
cmake -S . -B build -G Ninja
time cmake --build build

# Ninja build stats — the main profiling tool
ninja -C build -d stats <target>

# Per-target timing
ninja -C build -t graph | dot -Tpng > graph.png   # dependency graph

# Find slowest compilations
# Use ClangBuildAnalyzer for -ftime-trace output
cmake -S . -B build -DCMAKE_CXX_FLAGS=-ftime-trace
cmake --build build
ClangBuildAnalyzer --all build trace.bin
ClangBuildAnalyzer --analyze trace.bin
```

## Patterns

### Using Makefiles generator instead of Ninja
**Symptom**: Slower builds and worse dependency tracking.
**Detection**: no `-G Ninja` in build scripts. Look for `Makefile` in
`build/`.
**Fix**: use `-G Ninja`. Ninja is faster, parallelises better, and
has superior dependency tracking for incremental builds.
**Risk**: Low — CMake supports both generators equally.

### No ccache/sccache wrapper
**Symptom**: Recompiling the same translation units takes full time.
**Detection**: no `CMAKE_CXX_COMPILER_LAUNCHER` set.
**Fix**:
```cmake
find_program(CCACHE ccache)
if(CCACHE)
    set(CMAKE_C_COMPILER_LAUNCHER ${CCACHE})
    set(CMAKE_CXX_COMPILER_LAUNCHER ${CCACHE})
endif()
```
**Risk**: Low, but verify cache hits with `ccache -s` after a second
build.

### Glob-based source lists
**Symptom**: New files not picked up without reconfigure; unnecessary
reconfigures when unrelated files change.
**Detection**: `file(GLOB ...)` for source files.
**Fix**: explicit source lists. The CMake docs warn against GLOB for
this reason. Use `CONFIGURE_DEPENDS` only as a last resort.

### Missing precompiled headers
**Symptom**: Clean builds slow, common headers re-parsed thousands of
times.
**Detection**: no `target_precompile_headers` usage.
**Fix**: precompile stable external headers (`<vector>`, `<string>`,
project-wide internal headers). Modern CMake makes this easy.
**Risk**: Medium — PCH interacts with include ordering and can mask
missing includes in source files.

### Include-what-you-use not enforced
**Symptom**: Changing a low-level header rebuilds the world.
**Detection**: widely-included "convenience" headers.
**Fix**: run IWYU or `clangd --include-cleaner`, split monolithic
headers, forward-declare where possible.
**Risk**: Medium — mechanical refactor but can be tedious.

### `CMAKE_BUILD_TYPE` default is `RelWithDebInfo` or unset
**Symptom**: Dev iteration is slow because of optimisation.
**Detection**: `cat build/CMakeCache.txt | grep CMAKE_BUILD_TYPE`.
**Fix**: document that dev should use `-DCMAKE_BUILD_TYPE=Debug`.
Ensure release builds in CI explicitly set Release.

### Unity builds off
**Symptom**: Clean build dominated by compilation of many small files.
**Detection**: no `CMAKE_UNITY_BUILD` or `set_target_properties(... UNITY_BUILD ON)`.
**Fix**: enable unity builds for clean-build speed. Trade-off:
incremental becomes slower per-change.
**Risk**: Medium — unity builds can expose hidden ODR violations and
affect incremental speed.

### Multiple `find_package` calls without CONFIG mode
**Symptom**: Slow configure step.
**Detection**: `find_package` without `CONFIG` on libraries that ship
CMake configs.
**Fix**: use `CONFIG` mode when available — skips the FindXxx.cmake
module search.
