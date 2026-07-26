---
name: demo
description: >
  Implement and publish an interactive math/3D demo under marcelocantos.github.io
  using the shared shell + per-demo content layout. Stage locally with the demos
  CLI, then publish content-only. Use for /demo natural-language visualization
  requests (vectors, cross products, coordinate systems, etc.).
user-invocable: true
---

# demo

Turn a natural-language visualization request into a GitHub Pages demo on
[`marcelocantos.github.io`](https://marcelocantos.github.io/).

**Host repo:** `~/work/github.com/marcelocantos/marcelocantos.github.io`  
**CLI (always use this — do not invent ad-hoc git):**  
`python3 ~/work/github.com/marcelocantos/marcelocantos.github.io/scripts/demos`

## Arguments

- `/demo <description>` — required. Free-form description of the visualization
  and interaction (e.g. cross product of two vectors with draggable endpoints).

If no description is given, ask once and stop.

## Assumptions (shell provides these — do not reimplement)

- **Rotate:** mouse drag with **no modifier** orbits the scene.
- **Pan:** **Shift+drag** pans.
- **Reset view:** `R`.
- **Endpoint handles:** content calls `ctx.registerHandle({ getPoint, setPoint, color?, radius?, panelIndex? })`. The shell moves the point in a plane **parallel to the screen** through the endpoint. Use this for independent vector tip dragging.

## Content contract

Per-demo directory: `demos/<slug>/`

| File | Role |
|------|------|
| `meta.json` | `slug`, `title`, `description`, `layout` (`single` \| `split`), `footer` |
| `content.js` | ES module: export `meta` (optional) and `mount(ctx)` |
| `index.html` | Thin bootstrap (scaffold with CLI `new`) |

```js
// content.js
import * as THREE from "three";
// pure math: import from "../../shared/math.js"
// arrows: import { makeArrow, updateArrow } from "../../shared/shapes.js"

export const meta = {
  title: "...",
  description: "...",
  layout: "single", // or "split" for two panels
  footer: "…",
};

export function mount(ctx) {
  // ctx.THREE, ctx.panels[{ scene, camera, renderer, root, dom, index }]
  // ctx.registerHandle({ getPoint, setPoint, color, radius, panelIndex })
  // ctx.setTitle / setDescription
  // return { update?, onHandleChange?, onReset?, dispose? }
  const panel = ctx.panels[0];
  // add objects to panel.root
  return {};
}
```

**Do not edit `shared/` for content-only demos.** Only change shell/math when
the capability is missing (then publish with `--with-shared`).

Pure geometry that content relies on belongs in `shared/math.js` (or a small
module under `shared/`) with **unit tests** under `tests/` that import the
shipped functions.

## Steps

### 1. Derive a slug

From the description, choose a kebab-case slug (`cross-product`, `vector-projection`).
If `demos/<slug>/` exists, update that demo instead of creating a parallel one.

### 2. Scaffold if needed

```bash
python3 ~/work/github.com/marcelocantos/marcelocantos.github.io/scripts/demos new <slug> \
  --title "…" --description "…"
```

### 3. Implement `content.js`

- Prefer `shared/math.js` for cross products, dots, screen-plane math.
- Prefer `shared/shapes.js` for arrows.
- Register handles for every user-draggable endpoint.
- Keep the file content-only (no full HTML shell).

### 4. Unit tests when math is non-trivial

Add/extend `tests/*.test.mjs` importing shipped modules. Run:

```bash
cd ~/work/github.com/marcelocantos/marcelocantos.github.io && node --test tests/**/*.test.mjs
```

### 5. Local stage (mandatory before publish)

```bash
python3 ~/work/github.com/marcelocantos/marcelocantos.github.io/scripts/demos serve --port 8765 --demo <slug>
```

Open `http://127.0.0.1:8765/demos/<slug>/` (or pass `--open`).  
**ES modules do not work via `file://`.**

Verify in a browser (Playwright OK): no page errors, canvas present and sized,
handles/orbit respond. Fix before publishing.

### 6. Publish (content-scoped)

Dry-run first:

```bash
python3 …/scripts/demos publish <slug> --dry-run
```

Then commit + push:

```bash
python3 …/scripts/demos publish <slug> --push -m "Publish demo <slug>"
```

This refreshes the root catalog and stages only `demos/<slug>/` + `index.html`
(unless `--with-shared`).

Report the live URL:  
`https://marcelocantos.github.io/demos/<slug>/`  
(Pages may lag a minute after push.)

## CLI reference

| Command | Purpose |
|---------|---------|
| `serve [--demo SLUG] [--open] [--port N]` | Local staging HTTP server |
| `new SLUG [--title T] [--description D]` | Scaffold demo + catalog |
| `list` | List slugs |
| `catalog` | Regenerate root `index.html` |
| `publish SLUG [--dry-run] [--push] [-m MSG] [--with-shared]` | Content-only publish |

## Example

`/demo visualise the cross product between two vectors, showing a×b and b×a…`

→ slug `cross-product` → implement handles on **a** and **b** tips → stage with
`serve --demo cross-product` → `publish cross-product --push`.
