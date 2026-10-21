# R04: Native contenteditable profile

`JavaScript/Editing.luau` applies native text proposals to the existing DOM through live Range operations. `Input/NativeContentEditable.luau` retains one transparent Roblox TextBox as its keyboard/text source. Actual text, selection and caret remain renderer-owned. The native TextBox is one pixel at the rendered caret, so it does not cover links, formatting or pointer-selection targets in the editing host.

## Implemented behavior

- `contentEditable` states `true`, `false`, `plaintext-only` and `inherit`, inherited `isContentEditable`, and `document.designMode` on/off. HTML namespace and parent-element inheritance are respected; a shadow-root editor establishes its own editing host.
- Editable hosts participate in native focus and Tab order. Nested editable elements are not additional Tab stops unless given `tabindex`. Existing focus, shadow retargeting, event dispatch and reconciler adapters are reused.
- Committed text uses UTF-16 DOM offsets and native UTF-8 cursor positions, including astral characters. Selected inline text is replaced without flattening surrounding elements or recreating unrelated GUI objects/listeners.
- Native edits dispatch cancelable, composed, bubbling `beforeinput`, containing a branded `StaticRange`, followed by `input` after the DOM and caret change. Cancellation restores the native text/selection. A synchronous handler that changes the DOM, editability or selection owns those changes; the previous proposal is discarded.
- `contenteditable=false` text islands are protected. Plaintext hosts insert newlines as text. Rich Enter splits/extracts the retained formatted block tail; Shift+Enter inserts a `br`.
- Arrow/Home/End keys use the existing `Selection.modify` implementation and rendered fragment geometry, with Shift extension and Control/Meta word/boundary navigation. Movement is constrained to the editing host. Canceled `keydown` also suppresses native cursor changes.
- The caret uses actual retained fragment rectangles, computed style color/shape/blink mode and scroll-ancestor clipping. Geometry watches rebind if reconciliation replaces the host GUI. Selection, resize and scroll updates retain the native input object; blinking schedules a focused-only half-second timer rather than an idle RenderStepped loop.
- Blur, hidden/inert/removed editing hosts, removed shadow hosts and page disposal release focus, caret timers and geometry/property callbacks. Validation anchors can focus an editable or other focusable DOM element without requiring a native form-control record.
- Scriptless pages containing an explicit editable host initialize the adapter too.
- DOM editing ownership, CSS `:read-write`/`:read-only` and native input use the same live-tree `DOM/EditingHost` helper. Inherited and case-insensitive states, plaintext hosts, protected islands, reparenting and independent shadow hosts cannot diverge between those paths. A real `designMode` change invalidates selector state without a fake attribute mutation; assigning the existing mode does nothing.

## Verification

`node scripts/run-html-tests.cjs JavaScriptContentEditing JavaScriptTextControlSelectionRendering JavaScriptShadowSelection JavaScriptDocuments JavaScriptComponents JavaScriptRuntimeStorage JavaScriptRealmLifetime`

The mounted editing test exercises real Controller/native TextBox property signals, Runtime event dispatch, DOM mutations and retained rendering. It checks UTF-16 replacement, StaticRange boundaries/event order, canceled text and keyboard input, locked islands, plaintext/rich breaks, native/DOM cursor synchronization, fragment-based caret geometry, LayerCollector ancestry, visibility, inertness, shadow editors, resize, removed hosts and cleanup.

`tests/fixtures/javascript-r04-editing-browser.json` records the native Chromium Enter result. Splitting `<p contenteditable>ab<strong>cd</strong></p>` at text offset 1 produces `a<div>b<strong>cd</strong></div>` and places the caret at the retained tail's first text node, offset 0. The implementation and mounted test use that structure. The Selection group separately compares 20 native Chromium cases.

The additional `EditingSelectors` suite compares 91 frozen records from Chrome 154: 76 exact results and 15 explicit normative expectations with untouched raw browser values. One difference concerns protected `contenteditable=false` below `designMode`; fourteen concern `:optional` on the seven input states to which HTML says `required` does not apply. All 22 current input types, unknown/legacy fallback types and uppercase spelling are covered with and without `readonly`, alongside placeholder, required/optional and validation selectors. Selector capability checks use the same normalized type as the form control, rather than the raw attribute.

The mounted `JavaScriptCSSOMRendering` suite additionally compares 14 native paint states. It checks actual retained text/control colors and the ancestor `:has` background after editing-mode changes, with no layout, new GUI allocation, control replacement or loss of backward editor selection. The frozen fixture and reproducible capture are `tests/fixtures/editing-selectors-browser.json` and `scripts/capture-editing-selectors.cjs`; run the capture without `--update` to verify the reference is unchanged.

## Remaining boundaries

This is a bounded editing profile, not a complete browser rich-text editor. The text projection handles text nodes, `br` and common block boundaries; arbitrary CSS whitespace/hidden content, replaced elements, every block/display combination and clipboard serialization need additional browser-reference coverage. Rich clipboard HTML, browser paragraph normalization for multiline paste, formatting commands, undo/redo history and drag/drop editing are not implemented.

Roblox exposes committed TextBox text, not the browser/OS IME preedit stream. Committed Unicode input is supported; native composition events, preedit target ranges and browser IME cancellation are not simulated. Full mixed-direction caret motion, platform-specific keyboard conventions, ligature caret stops and accessibility text-provider behavior remain separate work. The existing Selection navigation profile determines the current visual movement accuracy.

References: [HTML editing and focus](https://html.spec.whatwg.org/multipage/interaction.html), [Input Events Level 2](https://www.w3.org/TR/input-events-2/), [Roblox TextBox](https://create.roblox.com/docs/reference/engine/classes/TextBox).
