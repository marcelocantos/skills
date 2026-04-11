# Node.js patterns (npm / yarn / pnpm / bun)

## Profiling

```bash
# Install timing
time npm ci
time pnpm install --frozen-lockfile
time bun install

# Webpack bundle analysis
npx webpack-bundle-analyzer stats.json

# Vite build profiling
vite build --profile

# tsc profiling
tsc --extendedDiagnostics --generateTrace trace_out
npx @typescript/analyze-trace trace_out

# Jest
jest --detectOpenHandles --logHeapUsage
```

## Patterns

### Using `npm install` instead of `npm ci` in CI
**Symptom**: Slow and non-deterministic installs.
**Detection**: CI config has `npm install`.
**Fix**: use `npm ci` (or `pnpm install --frozen-lockfile`, or
`yarn install --immutable`) in CI. Faster and fails on lockfile
drift.

### Not using `bun install` or `pnpm`
**Symptom**: `npm install` dominates install time.
**Detection**: project uses npm.
**Fix**: migrate to `pnpm` (ecosystem-compatible, massively faster) or
`bun` (even faster, but less compatible). `pnpm` is the safer
default.
**Risk**: Low for pnpm (drop-in replacement in most cases), Medium
for bun (some native module incompatibilities).

### `node_modules` cache not used in CI
**Symptom**: CI reinstalls dependencies every run.
**Detection**: CI config lacks cache step for `node_modules` or
`~/.npm`.
**Fix**: cache by lockfile hash. `actions/setup-node` supports
`cache: 'npm'|'yarn'|'pnpm'`.

### Webpack without persistent cache
**Symptom**: Each webpack build is full.
**Detection**: no `cache: { type: 'filesystem' }` in webpack config.
**Fix**: enable filesystem cache. Webpack 5 supports it out of the
box.
**Risk**: Low — but watch for stale cache bugs on config changes.

### Migrate Webpack to Vite / esbuild / Rspack
**Symptom**: Webpack is dominant cost and config is legacy.
**Detection**: project uses Webpack 4 or old-style config.
**Fix**: evaluate Vite (dev server), esbuild (bundler), or Rspack
(drop-in Webpack replacement, much faster).
**Risk**: High — build tool migration is a project, not a quick fix.
Propose as a deferred recommendation, not an auto-fix.

### TypeScript `noEmit: false` without project references
**Symptom**: Monorepo recompiles everything on any change.
**Detection**: monorepo with TypeScript but no `tsconfig.json`
project references (`references: [...]`).
**Fix**: set up project references for incremental compilation.

### `ts-node` in the hot loop
**Symptom**: Running scripts is slow.
**Detection**: `ts-node` without transpile-only mode, or `tsx`/`bun`
alternatives.
**Fix**: `ts-node --transpile-only`, or migrate to `tsx` or `bun run`.

### Jest without `--maxWorkers` tuning
**Symptom**: Jest slow on modern multi-core machines.
**Detection**: Jest config defaults.
**Fix**: set `--maxWorkers=50%` or a specific number. For CI with
limited cores, set to the available count.

### ESLint running on all files every time
**Symptom**: Lint slow even on small changes.
**Detection**: `eslint .` without cache.
**Fix**: `eslint --cache --cache-location .eslintcache`. In CI, cache
the `.eslintcache` file keyed on commit range.

### Large `postinstall` scripts
**Symptom**: Install is slow due to native compilation (node-gyp,
sharp, etc.).
**Detection**: `npm ci` spending time in postinstall for specific
packages.
**Fix**:
- Use prebuilt binaries where possible.
- Consider whether the native dep is actually needed.
- In Docker, use multi-stage builds to cache the compilation.

### Running `tsc` and a bundler separately
**Symptom**: Both type-check and bundle steps in the build.
**Detection**: build script has both `tsc` and `webpack`/`vite` calls.
**Fix**: use `tsc --noEmit` for type-checking only (faster), let the
bundler handle transpilation. Or use `tsc-watch` in dev.

### `npm run build` in every Docker layer
**Symptom**: Docker builds don't benefit from layer caching.
**Detection**: Dockerfile copies source before installing deps.
**Fix**: copy `package.json` and lockfile first, install deps, THEN
copy source. Standard Dockerfile optimisation.
