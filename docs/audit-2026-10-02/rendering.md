# Rendering, Canvas, media and selected controls audit — 2026-10-02

Scope: 60 Rendering modules (excluding HTMLPage, RenderTree, LayoutJob and WorkBudget owned by the coordinator), Controls/{View,RangeView,NumberView,GaugeView,TextareaView,SelectOptions,State}, and Input/MediaRuntime: **68 modules fully read before any production edit**. `rendering.json` records ownership, dependencies, direct callers and test references. Tests RenderingLifetimes, Canvas2D, CanvasBackground and IFrames were fully read. Canvas/loading/prior-rendering/lifecycle documentation and the relevant runner/module integration were reviewed. Font profiles belong to the layout auditor; existing user calibrations are not changed.

This is a code/evidence audit, not a native Roblox FPS benchmark. Test references identify relevant coverage, not proof that every browser behavior is supported. CLI mocks cannot establish native frame time, EditableImage upload cost, font rasterization or input latency. The coordinator owns baseline/full-suite execution to prevent shared-bundle races.

## R1 — P1: Canvas path construction can escape VM and frame budgets

**Evidence:** `Rendering/CanvasSurface.luau:479–483` (`appendEllipse`) normalizes angles by repeated ±2π loops and calculates segment count directly from radius. `MoveTo/LineTo` at 463–464 append without a total point limit or checkpoint. Host code executes outside the JavaScript VM step counter.

**Trigger:** a finite very large negative end angle clockwise (or positive angle anticlockwise) can require enormous iterations; sufficiently large values do not change when 2π is subtracted, producing a nonterminating loop. A large radius generates arbitrarily many points even for a tiny canvas. Existing quadratic/cubic curve subdivision is capped but shared path growth is not.

**Correction:** constant-time direction-aware normalization; bounded, explicitly diagnosed geometry/path storage; cooperative checkpoints in host geometry work. Preserve ordinary circle/arc direction and existing per-pixel accuracy. Do not silently lower visual quality to claim FPS gains. Test positive/negative/full-turn arcs, large finite angles/radii, cancellation during point construction, limits and BeginPath reset. Avoid executing the known infinite loop in a shared process.

**Risk/measurement:** medium semantic risk around full revolutions and anticlockwise arcs; compare raster/path endpoints against browser specifications and ordinary existing Canvas tests. Count host checkpoints and maximum path storage; native p95 frame time still requires Roblox.

## R2 — P1: Canvas startup failure can leak allocated EditableImages

**Evidence:** `Rendering/CanvasRuntime.luau:117–165`. EditableImages are allocated and immediately uploaded before `runtime:Destroy` and `page:AddCleanup` are defined at 164–165. The first `WritePixelsBuffer`/GUI property failure escapes initialization before cleanup registration. Source image loading can yield with no immediate post-yield page-liveness guard.

**Repro:** asset mock successfully allocates a canvas image, then throws from its first pixel upload. Run page cleanup after `CanvasRuntime.start` throws: the canvas image has no registered owner cleanup and is not destroyed. PageSession immediately invokes cleanups added after death, which covers eventual normal returns, but not exceptions before registration.

**Correction:** establish idempotent cleanup before first allocation/yield, make partial VM/GPU/image initialization safe, and roll back on startup exception. Recheck lifecycle after asynchronous source reads and before publishing/uploading. Maintain exactly-once disposal and existing RAF callback/cancellation semantics. Ensure source temporary images are released on cancellation.

**Risk/measurement:** medium because cancellation can interleave with cooperative canvas script execution. Test upload failure, source-load cancellation, normal cleanup twice, RAF disconnect and no late GUI writes. This is a lifecycle correctness fix; no unsupported FPS percentage claim.

## R3 — P2: transparent document styles retain a prior canvas color

**Evidence:** `Rendering/CanvasBackground.luau:35–47`. When no html/body color resolves, only a previous `color-scheme` value is reset; prior `html`/`body` color stays indefinitely. The color-scheme reset also hardcodes white, ignoring a caller-provided root surface color/transparency.

**Trigger:** a media query or style change changes body background from a color to transparent, or dark scheme returns to a custom surface. Reapplying canvas background leaves stale color.

**Correction:** save the original root surface properties once, restore them when document propagation stops, and clear the source marker. Use weak ownership for remembered roots and no root backreferences. Tests: body→transparent, html→body→transparent, dark→default, configured transparent/custom root, repeated application and initial no-color behavior.

**Risk:** low; preserve existing initial configured surface and html priority/body propagation.

## R4 — P2 FPS candidate: media hover repeats unchanged native property writes

**Evidence:** `Rendering/MediaBox.luau:240–303` paints roughly 30 fields and calls geometry twice; `Input/MediaRuntime.luau` Hover and periodic playback reads call paint even if the hover action/state is unchanged. The page heartbeat remains attached while media is paused and polls items every 0.1 seconds.

**Correction candidate:** use value-guarded retained-property writes and compute geometry once per paint; skip unchanged hover-action paints. Keep current playback cadence, focus/hover/disabled colors, range geometry and native scrolling. Idle-heartbeat suspension is a separate behavior change requiring native property-change wakeup coverage; do not combine it speculatively.

**Measurement:** instrument a proxy GUI and count actual assignments for a stable second paint and repeated pointer moves; verify a changed state still updates all affected fields. Report assignments, not Roblox FPS. Profile paused vs playing multi-media pages in Studio before considering connection changes.

## R5 — P2 FPS candidate: SVG hover preparation does unbounded synchronous scanning

**Evidence:** `Rendering/SVGImages.luau:63–97` visits every render node and calculates `Style.stateKey` before prewarm state/capacity limits take effect. SVGCursor at 129–147 scans all embedded SVG entries per update to reset old hover. The SVG auditor independently identified the prewarm issue.

**Impact:** large SVG DOMs can block after first upload even when only a small warm capacity is configured; many embedded SVGs add per-pointer linear work.

**Correction direction:** budget/deduplicate candidate discovery or index state-affecting nodes before calculating visual keys; track previous/current hovered SVG for resets. Preserve hit/cursor order, source priority, forced-colors/theme state and unique DOM ownership. Coordinate this with the SVG owner; do not introduce an unverified cache keyed only by source when state differs.

**Measurement:** node visits/stateKey calls and warm occupancy for 100/1000/10000 nodes, idle input assignments, cold vs warm upload timing, native frame-time percentiles.

## R6 — P2 feature/performance gap: CSS animation lists are initialized once

**Evidence:** `Rendering/HTMLAnimations.luau:226–260` adds keyframe items only on first AfterLayout. Later style changes do not reconcile animation-name membership; completed items are removed at 377–378 and cannot be rediscovered by that path. Scroll-driven items keep the active frame connection and repaint unchanged progress.

**Correction direction:** separately reconcile animation identity/list changes and rebuild size-dependent stops, retaining progress according to CSS semantics; skip unchanged scroll samples while ensuring a new layout or style still repaints. This is broader than the safe lifecycle fixes and needs dedicated interaction tests. Existing CSS easing, 1× speed, stable resize transform bases and disabled hover prints must remain intact.

**Risk:** high regression exposure for reversal, fill mode, paused states and resize. Do not claim repaired in this audit unless implemented and tested explicitly.

## R7 — P2 investigation: perspective source cache and transient raster cost

**Evidence:** `Rendering/PerspectivePixels.luau:21–64` source key has no mutable CanvasSurface pixel generation, although it snapshots that surface. Static dimensions/style with changed canvas pixels can reuse a stale 3D texture. `renderScenePixels` allocates depth/RGBA layers per plane; weak source surfaces and temporary layers are not included in VisualEffects' output image budget. Work is synchronous inside one render job.

**Correction direction:** introduce a surface generation for content invalidation, then account for source/transient raster memory and add cooperative raster checkpoints without reducing sampling accuracy. Must cover 3D flattening, nested scenes, masks and active canvas animation together.

**Measurement:** deterministic dirty-canvas snapshot reproduction first; record peak CPU-buffer bytes, maximum plane count and worst uninterrupted host duration. Native EditableImage/memory profiling is required before broad raster changes.

## R8 — P2 load candidate: canvases eagerly decode every id-bearing HTML image

**Evidence:** `Rendering/CanvasRuntime.luau:127–143` loads all ImageItems with IDs using CreateEditableImageAsync whenever the page contains any canvas, irrespective of canvas-script use. This can duplicate native image loading and decoded RGBA memory for unrelated gallery images.

**Correction direction:** demand source resolution through canvas image access/decode/drawImage, with per-source deduplication, lifecycle cancellation and correct pending-image semantics. This is not a one-line removal: scripts currently assume ready pixels before execution. Keep separate from startup cleanup fixes.

**Measurement:** decode counts and bytes on one-canvas/large-gallery pages, cold/warm cache, script requesting one vs all images. Do not alter compatibility solely for a faster benchmark.

## R9 — baseline failure investigated: RenderingLifetimes weak owners

Coordinator baseline reported `Renderer cleanup records must not retain their render-box owners`. The fully read VisualEffects and BorderCorners cleanup structures retain GUI/image resources but contain no render-box backreference; weak owner lookup values likewise do not point at the owner table. The test uses a bounded allocation burst rather than a guaranteed full collection, which can depend on prior suite heap state. **No genuine owner leak is established by this failure alone, and the test must not simply be weakened.**

Coordinator should run isolated and full-heap reproductions and inspect live roots. Preserve explicit owned-resource lists: they are what releases an image after a weak owner has already been collected. Exactly-once native disposal is independently testable even when mock GC timing is nondeterministic.

## Architecture and preserved invariants

RenderTree owns GUI/render boxes; helpers either mutate those retained instances or own explicit per-page image caches with Destroy. Image/font/source tasks must validate page lifetime after yielding. CanvasRuntime combines a scoped VM with CPU graphics contexts and an on-demand RAF connection. MediaRuntime owns playback instances/signals and delegates GUI representation to MediaBox. HTMLAnimations paints retained boxes, invoking transform/effect helpers; it must not trigger a whole-page layout for paint-only changes. ViewportLayer maintains fixed/sticky presentation separately from logical layout.

Preserve user-calibrated text metrics, ceil size rounding, all prior font factors, resize only after drag release or a sudden viewport change, CSS easing at 1×, stable hover transform origins after resize, native scrolling, and no per-frame diagnostic prints. Native text raster/pixel rounding and unsupported graphics limitations must be documented separately from algorithmic FPS costs.

## Verification ledger

- Original-module read: 68/68 complete before production changes.
- Baseline full suite: coordinator-owned; initial RenderingLifetimes GC-sensitive failure investigated above.
- Isolated baseline/current probes and functional regressions: complete under `build/audit-2026-10-02/rendering/`; exact results follow below.
- Native Roblox/Studio FPS, p95/p99 frame time, visual comparison and upload timings: not measured by this subtask. The user will perform FPS tests; no further performance runs are scheduled.

## Implemented narrow fixes and measured regressions

After the coordinator confirmed that the complete engine inventory was finished, R1/R2/R3 and the retained-paint part of R4 were implemented. The first baseline source is preserved in the coordinator snapshot and the isolated bundle prefix. Reference line numbers in findings above describe that baseline; current implementations have shifted.

- R1: direction-aware constant-time angle normalization, 65,536 path-point limit, explicit oversize diagnosis before ellipse mutation, point checkpoints, and path-budget preservation around text. Ordinary subdivision accuracy is unchanged. Direction/full-turn behavior was checked against the [WHATWG canvas ellipse steps](https://html.spec.whatwg.org/multipage/canvas.html#ellipse-method-steps). This is an explicit implementation limit, not unlimited browser parity.
- R2: cleanup ownership is established before allocation; startup exceptions roll back immediately; cancellation after resource acquisition prevents source read/GUI publication. Pending callbacks check page lifetime. Normal and partial teardown are idempotent.
- R3: weakly stored original canvas surface properties restore configured color/transparency after html/body or scheme propagation ends.
- R4: MediaBox uses guarded retained writes and calculates geometry once per paint; unchanged action hover skips repaint. Playback cadence/idle heartbeat, visual layout and effects are unchanged.

`baseline-probes.luau`/`baseline.log` in the isolated build folder show: a radius-100000 arc reached 1001 intercepted points with **0 checkpoints**; an injected first upload failure left **0 registered cleanups and 0 image destroys**; body→transparent failed to restore the root; identical media paint assigned **34 properties**. The corresponding `after.log` shows preflight arc rejection, **1 cleanup / 1 destroy**, correct root restoration and **4 assignments**. Those four are value-equal UDim2 tables in the CLI mock; native Roblox value types support equality, so these counts must not be represented as measured FPS.

`tests/RenderingAudit.luau` adds endpoint/direction/huge-angle tests, bounded storage and cancellation, text-path preservation, injected upload and lifecycle failures, dark/default surface transitions, unchanged paint counts and changed-state painting. It passes in the isolated current-source bundle. `tests/MediaRuntime.luau` adds 100 pointer moves within one action with zero paint invocations. The coordinator runs integration suites and owns their final results.

RenderingLifetimes is unchanged. It passed **three isolated runs**, and the coordinator reports that the first full-suite rerun also passes unchanged. The baseline failure is intermittent and consistent with GC timing; a retained-owner leak has not been established. No assertion has been weakened.
