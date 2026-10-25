# rainy-flixel 技术说明

基线是 6.2.0 的完整树。

## 与 6.2.0 的差异

Perf work and instrumentation for the Rainy engine. Every commit says why; short
version:

### FlxFrameStats
Frame timing split into update / draw / render with p50/p99 percentiles, plus
per-frame `drawCalls`. Upstream counted draw calls with `++` and never reset
them, so every reader was looking at a since-launch total. `beginFrame()` now
zeroes them *before* the `if (!enabled) return`, so the numbers are correct even
with instrumentation off.

`periodMS` is the wall-clock frame interval — it contains present, the driver and
the frame limiter's sleep. `totalMS` is only update+draw+render work. Diagnosing
"work is 2.2 ms but I only get 170 fps" is a `percentilePeriod` question, not a
`totalMS` one.

### FlxCamera
- `renderInterval` throttles a camera to every N frames. `stepRenderDue()`
  advances the tick *before* deciding, otherwise `renderInterval = 2` skips the
  very first frame (tick 0 → 1, and 1 is not a multiple of 2) and a fresh
  throttled camera renders an empty canvas.
- `sortDrawItems` clusters the draw stack by texture to cut state changes.
  Default off, needs A/B against real scenes. `stableSortDrawStack` rebuilds the
  chain and moves `_currentDrawItem` to the new tail; leaving it on the pre-sort
  tail made any post-`render()` append splice into the middle of the new order
  and orphan everything behind it.

### FlxText
`updateDefaultFormat` compares against an `_appliedFormat` snapshot; `set_text`
returns early on an identical value; `set_alignment` compares before assigning.
Re-asserting an unchanged format used to re-rasterise the glyph bitmap every
frame. The snapshot covers `leading` / `indent` / `blockIndent` / `bullet` /
`kerning` too — those have no setter here, so `defaultTextFormat` is the only
route to them and a missed field made the change a silent no-op.

`FlxText.textPager` is an optional shared-texture sink (`FlxTextPager`). Null by
default, and with it null every line below is dead code. When a pager is
installed, `regenGraphic()` asks it *before* rasterising — a hit skips the whole
`TextField` pass — and offers it the finished bitmap afterwards. The text keeps
its own canvas either way, so the pixels are unchanged; only which texture a
label draws from moves, which is what lets flixel batch thirty labels into one
draw call.

The reason this needs a fork rather than a subclass: `regenGraphic()` paints into
`graphic.bitmap` and clears it with `fillRect` on the "same size" path. Once a
label draws from a shared page, that `fillRect` would erase every other label on
the page. So the canvas is tracked separately in `_canvas`, and `detachPager()`
returns a label to it before any edit touches pixels. A label that was never
rasterised locally has no canvas at all — it reports `oldWidth = 0`, which forces
the "make a new buffer" branch, so it still ends up with one.

### FlxSprite skew
`skewX` / `skewY` in degrees, applied by `applySkew()` inside
`prepareComplexMatrix`. flixel has no shear at all: `angle` rotates, `scale`
stretches, and neither can make an arrow lean while its vertical edges stay
vertical, which is what modcharts ask for.

The placement is the whole point. openfl's `Matrix` is row-vector with right
multiplication, so every helper appends an *inner* transform and the last call
acts on texture coordinates first. The shear sits between the origin shift and
the `scale` call:

- after `scale` the lean would be measured in screen pixels, so a sprite drawn at
  an uneven scale would shear by the wrong visual angle;
- after `rotateWithTrig` it would be measured in screen axes, so a rotated arrow
  would lean across its own edges instead of along them.

The six components are written directly — the product of a shear and an affine
matrix is closed form, and routing it through a temporary 3×3 multiply would cost
more than the four additions it saves. Angles clamp to ±80°, because the tangent
runs away towards 90° and a degenerate shear collapses the sprite to a line.

`draw()` skips `drawSimple` while either axis is off zero: a sheared quad cannot
be blitted. Sprites that never set skew are unaffected beyond one comparison per
camera.

### Smaller
- `FlxMouseEventManager` uses frame stamps (`_overEpoch` / `_wasOverPrev` /
  `_clickGen`) instead of allocating a fresh `Array` per frame and scanning it
  O(n²). `_overList` must be committed before any `return`, or over state freezes
  once the mouse is disabled.
- `FlxDrawQuadsItem` / `FlxDrawTrianglesItem` `reset()` uses `resize(0)`;
  `splice(0, len)` allocated an equal-length copy on every call.
- `FlxPool.put` scans `[0, _count)`. The backing array only grows, so `indexOf`
  over the whole thing charges for the historical peak and can match an object
  that was already taken out.
- `FlxPointer` guards against an empty camera list.
- `extraParams.hxml` defines `rainy_fork_flixel` so engine code can `#if` on the
  fork instead of guessing from the version number.

## Install

```bash
haxelib git flixel https://github.com/GengYan0/flixel-rainy-fork
```

The renderer-side fixes live in the OpenFL fork; use the pair together:

```bash
haxelib git openfl https://github.com/GengYan0/openfl-rainy-fork
haxelib git lime    https://github.com/GengYan0/lime-rainy-fork
```

`haxelib git` drops the checkout under `<haxelib>/git/<name>`. If a released
version of the same library is already installed, remove it first — haxelib
resolves one version per library name.
