# SVG audit — 2026-10-02

## Coverage and evidence

The accompanying `svg.json` inventories every SVG engine and SVGLab Luau module: **65 engine modules, 71 lab modules, 136 total**. All **67 handwritten modules** were read completely (57 engine, 10 lab). The other **69 modules** are generated payloads (8 font modules, 61 lab fixtures): inventoried by path, size, generator/format and consumers, not represented as a handwritten glyph-by-glyph review. The font payload is 1,959,663 source bytes. Its complete generator `export-svg-font.py` and loading/shaping paths were read. Subsequent infrastructure review also fully read all 30 `sync-svg-*.py` generators, all 5 `test-svg-*-browser.cjs` runners and their 5 HTML/JS templates. `infrastructure-svg.json` records the 36 additional files not already present in `svg.json`, avoiding duplicated coverage counts.

The matrix separates source reading, interaction tracing and tests. Existing tests are mapped by static symbol references and runner wiring; that mapping is not a claim that every test is applicable or passed. `SVGQueuePerformance`, `SVGRasterPerformance`, `SVGRuntimePerformance` and `SVGScenePerformance` were read completely. Both `run-svg-tests.cjs` and `benchmark-svg.cjs` were read completely. Root owns shared baseline/final runs, avoiding concurrent overwrites of their build outputs. This agent only ran isolated experiments under `build/audit-2026-10-02/svg/`.

Reference context: PLAN implementation rules, current `SVG-SUPPORT.md`, `SVG-PERFORMANCE-REVIEW.md`, S37/S38, S39/S40, S41/S42, S43/S44 and S45. Historic stage reports describe the state at their date, not current blanket compliance. In particular the older 8 MiB / 16-entry HTML cache statement is superseded by current Queue defaults of 24 MiB / 48 entries and separate descriptor-field limits. Script support remains an opt-in bounded SVG subset; it does not provide general HTML JavaScript. No native Roblox FPS, GPU upload timing, visual parity or device-memory acceptance is claimed here.

At this report's initial write, production source has not been modified by this agent; findings precede fixes. Root's initial SVG baseline was **blocked before execution** by references to deleted website fixtures. This is a pre-existing test-harness defect, not an engine test failure. Original sources were located in the ignored website archive and reported to root. Root owns their permanent fixture restoration and baseline rerun.

## Prioritized findings

### SVG-01 — P1: synchronous callbacks reset the interpreter's safety budget

**Confirmed by executable reproduction.** `ScriptVM.luau` public `Call` unconditionally resets `Steps=0` and `Depth=0`, including when a host function synchronously re-enters the same VM. `ScriptDOM.luau` installs event listeners which call this method; SVG script `focus()` can synchronously dispatch focus events through `Session:Focus` and the event bus, making this a real integration path. The internal call then decrements a depth counter which an inner invocation reset.

The isolated actual-module reproduction in `build/audit-2026-10-02/svg/experiments.cjs` calls a JS callback through a synchronous host callback 90 times with `MaxSteps=50`. It succeeds with `Steps=6`, `Depth=-178`, despite the declared call-depth cap of 64. This demonstrates both lost aggregate accounting and corrupted nesting state. It can cause unbounded synchronous work or Lua stack exhaustion in script-enabled SVG hosts. It is not reachable through ordinary HTML scripts because those are not enabled by this runtime.

Proposed correction: treat reentrant public calls as part of the current execution, resetting the budget only at the outer entry; restore depth when errors unwind, including when ScriptDOM catches an inner callback error. Check the disposed state while stepping so yielding/callback-driven disposal cannot continue evaluation. Tests must include nested success, depth and step exhaustion, caught nested errors, a fresh independent event afterward, and disposal during a callback. Do not expand the JavaScript language or alter normal layout behavior as part of this repair.

### SVG-02 — P2: retained-layer bounds perform a full synchronous pixel scan

**Confirmed by code and isolated timing.** `Compositing.remember` tests alpha for every pixel of every newly retained non-frame buffer, updating four bounds even in fully opaque interiors. There is no cooperative checkpoint in that scan. A maximum-size 1024×1024 layer means 1,048,576 alpha reads per group; nested filtered/masked/opacity groups repeat it. Raster's row checkpoints do not cover this stage.

A prototype that finds the first and last nontransparent pixel in each row returns exactly the same bounds, including empty images. It passed 80 deterministic randomized image checks. CLI `-O2`, 15 repetitions, 1024² RGBA buffers:

| Alpha occupancy | Existing mean | Prototype mean |
| --- | ---: | ---: |
| Opaque | 28.88 ms | 0.085 ms |
| Central half-width/half-height square | 16.01 ms | 8.42 ms |
| Empty | 11.63 ms | 11.16 ms |

These are CPU microbenchmark numbers, not Studio frame rates; total filter/raster/upload costs remain. A precise fix can use identical nonzero-alpha semantics with per-row cancellation checkpoints. Cache admission must stay transactional across any yield: a disposed/released owner must not regain entries after resumption. Existing pixel and ownership tests plus dedicated empty/sparse/dense/cancel/reset cases are required.

### SVG-03 — P2: requiring SVG raster support eagerly loads all font faces

**Confirmed loading path; native cost not measured.** `Embedded` requires `Text`, which requires `TextFont`; regular font initialization eagerly requires Bold, It and BoldIt. Their generated glyph and kerning/composition strings are parsed into shared tables at require time. Thus an SVG containing only shapes still loads the complete four-face, approximately 1.96 MB source payload. This is separate from HTML font calibration and must not change its values.

Potential improvement: lazy face loading, or defer Text/font loading until text expansion, preserving `Text.Font`, `Faces` and custom resolver behavior. The generator must emit the chosen loader consistently. A high-fidelity loader test is necessary: the current stage runner eagerly builds face modules and replaces requires, so it cannot prove a lazy require improvement or correct ModuleScript load order. First-use text cost is shifted, not eliminated. Native cold-load memory/time should be measured before deciding the scope.

### SVG-04 — P2: stale fixture paths block the entire SVG test suite

**Confirmed baseline failure.** `run-svg-tests.cjs` reads `examples/websites/html-css-stress-media/sample.svg`, plus effects styles and sample SVG, although those test websites were deliberately removed/replaced. The runner fails while bundling, before tests execute. Original files were found under `build/website-archive-20261001/browser/...`; root is moving permanent regression inputs to `tests/fixtures` and changing only test data wiring before rerunning the baseline. Do not restore obsolete website pages as public application pages.

### SVG-05 — profiling required: remaining synchronous build/cache bookkeeping

`RenderQueue` correctly serializes raster jobs, checks cancellation, coalesces superseded requests, prioritizes visible work, reuses image objects, and separates CPU time from time spent yielded. It does **not** checkpoint `Build`, descriptor `fields`, `Compositing.snapshot`, equality walks, or cache admission. Metadata is bounded (262,144 fields per entry, one million queue fields), but a bounded table walk can still exceed a frame. Scene construction parses geometry and resource trees synchronously. `SceneBuilder` lazy bounds closures can keep source contexts reachable; the field counter intentionally does not count closure internals or string heap sizes. Documented field counts are not exact Lua memory measurements.

Any proposed checkpoint inside these loops must preserve cleanup/cancellation and protect against partially published snapshots. First collect per-phase maximum slice durations, cache metadata size and allocation profiles. Avoid unproven broad memoization of mutable DOM state. The downstream `Rendering/SVGImages.scheduleWarm` state-enumeration issue was sent to the rendering auditor: warm-state discovery scans source nodes before a final capacity decision and can repeat selector-state walks. Its ownership and fix are outside this agent's production files.

### SVG-06 — profiling required: a row can itself exceed the cooperative budget

Filters checkpoint per row, but a row may include up to a radius-256 Gaussian kernel, radius-128 morphology neighborhood, a 225-entry convolution, or multiple turbulence octaves across a wide image. The 4 ms queue budget is therefore cooperative, not a hard maximum slice. Pixel math allocates transient channel tables in several paths. Existing Gaussian exactness tests prevent silently changing accumulation order. Optimize only measured hot paths with equivalent arithmetic and targeted pixel equality; retain antialiasing, source resolution and color precision.

### SVG-07 — existing limitation, not a new regression: animation host throughput

The interactive SVG lab intentionally requests animated frames at up to 30 Hz, and real software-raster throughput can be lower. It coalesces input and retains the last display while work runs. Pure production SVG rendering has no permanent per-element loop. The lab has its own animation/host connections, disconnected on destruction. HTML embedding presently does not automatically enable this SVG animation/script session. Therefore smooth native CSS compositor animation cannot be inferred from passing Luau animation-value tests. Increasing the lab request rate without reducing per-frame raster cost is unlikely to resolve throughput and can increase cancelled work.

## Correctness and lifecycle paths traced

- Prepared SVG trees, source IDs and resource guards feed the same `SceneBuilder` used by HTML embedding and the lab. Text glyph outlines, clipping, masks, transforms and filter resources share the scene/raster path.
- `Session` batches source mutation until Flush and reuses hit geometry for unchanged paint geometry. Capture movement avoids synchronous hit rebuilding; event listeners use stable dispatch snapshots and `once` is removed before invoking it. Queries reuse geometric metrics weakly.
- Queue owner removal/reset/destruction invalidates queued work and releases textures/retained work. The last image deliberately stays while a reset/replacement is pending. Image resolver temporaries are destroyed after decode, including failures.
- CPU cache, texture budget, compositing retained budget and filter intermediate budgets are separate. Their sum and Lua table/string allocations matter; no single counter is total memory.
- Raster uses the established 16-sample edge coverage and bounded geometry; CSS rendering hints are existing explicit choices. No offscreen HTML content virtualization, dropped labels, altered font calibration or quality reduction is proposed.
- Documented scope limits remain: general HTML/SVG cascade and scripts, foreignObject, arbitrary SVG fonts/shaping, several SMIL/viewport/CTM/use-retargeting cases. The audit does not relabel these as completed.

## Test-harness fidelity

`run-svg-tests.cjs` concatenates actual production source but removes/replaces static require declarations and injects aliases. Lab services, task scheduling, GUI/Image objects and upload behavior are mocked. This usefully checks math, lifecycle assertions and logic but can hide module initialization-order errors, eager-loading costs, native memory behavior and real engine scheduling. New imports/changed declarations can also escape its regex rewrites and must be tested in the actual module environment or Rojo build. The test runner's explicit handwritten stage order is not the production dependency loader.

`benchmark-svg.cjs` resolves static require chains into cached module factories, retaining more realistic require order and lazy execution, but still uses Lua Color3/Vector2 stand-ins and CPU/mocked upload work. Its optional comparison checks actual RGBA byte equality for six states; historical `--compare-baseline` data is useful for visual regression but must not substitute for this audit's saved source-before bundle when reporting an improvement. `--baseline` overwrites its saved baseline, so root controls before/after capture.

## Native FPS validation still required

For identical scene, viewport, DPI, resolution, quality, device and idle/interaction state, record native frame median/p95/p99, worst frame, first useful display, full completion, maximum cooperative slice, build/raster/upload phases, GUI/EditableImage counts, Lua memory and texture/CPU cache bytes. Separate cold load, warm hover, continuous movement, animation, resize drag/release, reset and disposal. Run several repetitions without per-frame printing. In particular measure whether full `WritePixelsBuffer` upload dominates after raster dirty-region improvements. Native frame rendering and upload stalls are not reproduced by a CLI loop or mock image object.

User constraints retained: resize only recomputes after release or abrupt size changes; interactive input remains usable during yielding; final layout/geometry/anchors do not drift. Test stale request completion during resize, teardown while yielded, invalid resources and eventual successful retry. Native Studio/browser visual comparison remains separate from passing CPU suites.

## Implemented after the global inventory gate

Root authorized the two scoped fixes after the inventory/baseline gate. SVG-01 now uses a shared execution budget for synchronous reentry, resets only on an independent entry, restores depth after errors, and checks disposal before instructions and after cooperative checkpoints. SVG-02 now scans only first/last occupied alpha pixels per row and cooperatively checks each row. Cache admission remains unpublished until the scan completes; cancellation is propagated separately from a normal skipped cache entry, and disposal during a checkpoint cannot re-register cache contents.

Changed production files: `SVG/ScriptVM.luau`, `SVG/Compositing.luau`, `SVG/Raster.luau`. Regression additions are in the already registered `tests/SVGScript.luau` and `tests/SVGRasterPerformance.luau`. An isolated factory-based bundle of the actual modules passes both tests with normal and `-O2` Luau execution. Logs: `build/audit-2026-10-02/svg/targeted-tests.log` and `targeted-tests-O2.log`. Tests cover nested Call/Run budgets, depth limits and restoration, fresh independent execution, caught nested errors, synchronous DOM focus cycles, disposal during host callbacks/checkpoints, dense/sparse/empty/edge alpha bounds, exact cropped pixels, one-shot cancellation, no cancelled admission/eviction, and release while scanning. The central full-suite result is maintained by root.

The final direct production benchmark loads the pre-change `Compositing.luau` from this audit's `source-before.zip` and the changed module. It includes snapshot, crop copying and actual cache admission, alternates before/after order, and byte-compares resulting retained RGBA in every sample. 15 samples each, 1024² RGBA, Luau `-O2`, a non-yielding checkpoint callback:

| Alpha occupancy | Before mean / median | After mean / median | Pixel comparison |
| --- | ---: | ---: | --- |
| Opaque | 30.71 / 30.20 ms | 1.50 / 1.52 ms | Identical |
| Central square | 16.33 / 16.36 ms | 8.97 / 8.88 ms | Identical |
| Empty | 11.50 / 11.49 ms | 11.00 / 10.99 ms | Identical |

Script and full log: `build/audit-2026-10-02/svg/benchmark-admission.cjs` / `.log`. These are more representative than the isolated scan prototype above but still only CPU admission measurements. No raster quality changed. The empty-buffer worst case benefits primarily from cooperative scheduling in the real host, not lower aggregate CPU time. Font loading, full-scene construction, metadata walks, filter kernels and native full-image uploads remain explicitly unoptimized in this patch.

## Additional infrastructure verification

All **30 SVG generator `--check` invocations and 5 browser DOM-mock runners passed** without rewriting generated files. Individual commands/results are saved in `build/audit-2026-10-02/svg/infrastructure-checks.json`. The source-based generators and templates examined here no longer reference the deleted HTML stress websites; the confirmed stale paths were confined to the central SVG runner addressed by root. Fonts, S21 image data, S34 ramp pixels, fixture SVGs, split/combined pages and runtime templates passed their existing source/output consistency checks. These checks establish consistency, not broad standards or pixel conformance.

**SVG-INFRA-01, compatibility risk, not a confirmed new rendering failure:** historical S25–S36 comparison generators still access `frame.contentDocument` to check embedded font loading and, in S36, install hit-status listeners on Blob SVG frames. The newer S37+ templates explicitly execute inside srcdoc frames and route messages using window identity/generation tokens, avoiding parent DOM access under opaque-origin conditions. Whether older Blob access fails depends on the actual origin/host/browser. Existing DOM-mock runners cover the newer pages, not that older native-origin path. A native comparison should check those old font/hit readouts before treating them as reference evidence; no historical generator was changed speculatively.

Historical comparison pages also intentionally serialize/embed all four font faces per isolated frame and run browser animation/resize clocks even while their action is paused. Those costs are properties of the comparison harness, not evidence of production Roblox idle work. Font-loading and frame-rate measurements must identify whether the browser reference is a stage laboratory or the real website.
