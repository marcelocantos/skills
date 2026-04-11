# xcodebuild / Xcode patterns

## Profiling

```bash
# Timing summary
xcodebuild -project Foo.xcodeproj -scheme Foo -showBuildTimingSummary build

# Per-phase timing via build log
xcodebuild -project Foo.xcodeproj -scheme Foo build 2>&1 | \
    tee build.log

# Enable build time logging in Xcode itself
defaults write com.apple.dt.Xcode ShowBuildOperationDuration -bool YES

# Analyse with xcbeautify for readable output
xcodebuild ... | xcbeautify

# Swift compile time hot spots
OTHER_SWIFT_FLAGS="-Xfrontend -warn-long-function-bodies=100 \
                   -Xfrontend -warn-long-expression-type-checking=100"
```

## Patterns

### Debug Information Format = DWARF with dSYM (debug)
**Symptom**: Slow debug builds.
**Detection**: `DEBUG_INFORMATION_FORMAT = dwarf-with-dsym` in debug
config.
**Fix**: debug should use `DEBUG_INFORMATION_FORMAT = dwarf` (no
dSYM). Release keeps dSYM for crash symbolication.

### Whole Module Optimisation in debug
**Symptom**: Slow incremental Swift builds.
**Detection**: `SWIFT_COMPILATION_MODE = wholemodule` in debug.
**Fix**: debug should use `SWIFT_COMPILATION_MODE = singlefile` or
`incremental`.

### `ONLY_ACTIVE_ARCH = NO` in debug
**Symptom**: Building for all architectures when only one is needed.
**Detection**: check `ONLY_ACTIVE_ARCH` in debug build settings.
**Fix**: debug should have `ONLY_ACTIVE_ARCH = YES`. Release builds
for all target archs.

### Large XIBs / Storyboards
**Symptom**: Interface Builder file compilation dominates build time.
**Detection**: `showBuildTimingSummary` shows `ibtool` steps as
top entries.
**Fix**: split large storyboards into per-screen XIBs, or migrate to
SwiftUI / programmatic UI.

### `swift-syntax` / macro-heavy targets
**Symptom**: Swift Macros (5.9+) significantly slow builds.
**Detection**: targets with lots of macro usage, or dependency on
`swift-syntax`.
**Fix**:
- Consolidate macro usage into dedicated small modules.
- Use precompiled macro binaries where possible.
- Consider whether codegen at build time would be cheaper than
  expansion via macros.

### CocoaPods `install` on every build
**Symptom**: Every build runs `pod install`.
**Detection**: pre-build script running `pod install`.
**Fix**: remove — `pod install` should be manual when Podfile
changes, not per-build. Use a `Podfile.lock` check instead.

### Swift Package Manager resolution on every build
**Symptom**: Package resolution in every build log.
**Detection**: package resolution happening when no Package.swift
changed.
**Fix**: usually caused by derived data being cleared. Keep derived
data, use Xcode's "Reset Package Caches" manually only when needed.

### Copy Resources phase copying everything
**Symptom**: Copy Resources phase is slow.
**Detection**: large copy phase in build log.
**Fix**: use Asset Catalogs for images (they get compiled/compressed),
avoid copying entire directories of unused resources.

### Run Script phases without input/output dependencies
**Symptom**: Script phases run on every build.
**Detection**: Run Script phase in project with no declared inputs or
outputs — Xcode defaults to running it every time.
**Fix**: declare Input Files and Output Files for each Run Script
phase so Xcode can track when to skip.
**Risk**: Medium — mis-declared dependencies cause stale outputs.
