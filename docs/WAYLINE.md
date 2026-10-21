# Wayline browser

Implementation and integration reference, updated 19 October 2026.

Wayline is a fictional in-game browser made from native Roblox GUI geometry. It
mounts into a host-owned content Frame. It does not create a second window engine,
render arbitrary websites, or depend on HTMLEngine or WindowManager. The optional
HTML adapter connects the existing engine without making either core module depend
on the other. Wayline keeps its own name and tinted image icons while following
Chrome's simple navigation controls: a plain toolbar, one rounded address field
and a narrow bookmarks bar. Each browser window contains one document. The tab
strip, tab search, new-tab controls and tab-creation API have been removed.
Neutral gray surfaces and restrained hover/press states replace the previous
card-like shell. The Home page
centers its search field and circular shortcuts instead of presenting a dashboard.
This visual direction does not change navigation, storage or module boundaries,
and does not imply affiliation with another browser.

The desktop shell uses a 46-pixel toolbar, a 34-pixel address field and an
optional 34-pixel bookmarks bar. Touch-only devices use a 52-pixel toolbar,
44-pixel address field and 42-pixel bookmarks bar. These larger touch targets
are a Roblox adaptation. The toolbar starts at the top of the browser content;
there is no empty header row where tabs used to be. The bookmarks bar appears
on Home only, when enabled and at least one bookmark or folder exists. Empty
collections do not reserve an empty row. Secondary actions remain available
through the browser menu. The Home toolbar button is opt-in with
`ShowHomeButton = true`; Home is always in the menu. The address field is blank
on Home and shows the destination during navigation. Its page-information
button identifies the current provider; it does not assert that a Roblox page
has a browser security certificate.

`HTMLPageDemo` supplies `DesktopHeaderInset = 200` to the optional window host.
On desktop, this reserves 200 pixels at the left of the window title only while
the host window is maximized, to clear Roblox's GUI. Restoring the window removes
the inset immediately. Navigation buttons and the address toolbar keep their
positions. Touch-only devices use no extra inset. Other hosts default to zero.
WindowManager exposes the generic `TitleInset` window option and `SetTitleInset`
method without depending on Browser.

HTML camera/microphone requests now show a permission panel below the address
field's page-information control. It identifies the origin and requested devices;
Allow/Block save a session decision, closing or Escape only dismisses it.
Document navigation, window hiding and teardown cancel pending requests. The fallback
HTML window host provides its own matching UI. These are application permissions;
the optional HTML capture host can now supply a virtual Workspace camera stream,
configured in HTMLPageDemo and independent of Browser. Microphone capture is
not connected. See the
[media contract](MEDIA.md#kamera--und-mikrofonberechtigungen--16-oktober-2026).

## Chrome reference profile

The layout reference is the Chromium tag **155.0.8059.79**, matching the locally
installed Chrome executable inspected with REA. This is source-guided
reconstruction of selected browser controls, not decompilation of Chrome's full
interface. The local PE resource inventory identifies the executable and static
icon resources; it does not measure rendered controls or runtime feature flags.

- [Layout constants](https://raw.githubusercontent.com/chromium/chromium/155.0.8059.79/chrome/browser/ui/layout_constants.cc) supply the desktop toolbar, address and bookmarks dimensions.
- [Toolbar state painting](https://raw.githubusercontent.com/chromium/chromium/155.0.8059.79/chrome/browser/ui/views/toolbar/toolbar_ink_drop_util.cc) guides separate hover and press layers. Roblox uses neutral surface-relative colors and existing theme accents rather than claiming to reproduce Chrome's platform-dependent color provider or ripple renderer.

Icons now use the Figma-exported image atlas described below. Menus use compact rows
and section dividers; touch rows remain larger. The retained Chromium tab
references are historical research inputs, not implemented browser features.

Downloaded reference files and their SHA-256 manifest are kept under
`build/chrome-reference-20261015/`. A scoped backup of the previous browser and
this document is `build/browser-before-chromium-detail-20261015-013742.zip`.
Compilation and the standalone/combined Rojo builds verify source integration.
The attempted native Chrome view was blocked because Windows automation could
not confidently determine its current URL; no Chrome or Roblox screenshot
comparison was completed. Exact font rasterization, antialiasing, platform
colors and feature-dependent Chrome variants remain outside that verification.

## Image icons

The [editable Figma icon family](https://www.figma.com/design/OoJD4SuaMjKuOXYfxqzJp9?node-id=4-245)
contains 26 browser symbols and their Light/Dark review instances. Matching
Material 3 components are reused; missing symbols use Google's Material Icon
SVGs. The Wayline mark and double chevron have local SVG masters. The Material
Icons license is retained in `assets/browser-icons/LICENSE-material-icons.txt`.

`assets/browser-icons/browser-icons.png` is the production export: 512 by 256
pixels, transparent, with white glyphs. Each 64-pixel cell contains a 48-pixel
crop at an eight-pixel inset, rendered from a 24-pixel vector master. The 26
named crop rectangles are recorded in `assets/browser-icons/atlas.json`; the
matching Luau configuration is `Browser/IconAssets`. The supplied Roblox image
ID is **72168208218331**. The SVG exports, original source provenance, Figma IDs
and review image are retained beside the PNG.

`Icons.draw` keeps its existing Frame return value and layout contract, and
places a passive ImageLabel inside it. Named symbols share one image asset and
use `ImageRectOffset`/`ImageRectSize` to choose their crop. Theme, disabled and
selected colors tint the white mask through `ImageColor3`. A direct numeric
asset ID or `rbxassetid://` icon value is also accepted for a page favicon and
keeps its original colors. These native image features follow Roblox's
[ImageLabel API](https://create.roblox.com/docs/reference/engine/classes/ImageLabel).

The optional HTML binding restores the document's favicon from `Options.BrowserIcon`
(a numeric ID, URI or named atlas symbol), or a document `link[rel~=icon]` mapped
through the page's `Images` resolver. Direct `rbxassetid://` link values also work.
The authored HTML can keep an ordinary relative image path while the Roblox page
options map it to an image ID. Metadata mutations update the retained document icon
without remounting the document. This bounded selection uses the first mapped
icon with empty/`all` media; full media/type/size negotiation, automatic HTTP
favicon fetching and persistent site-icon discovery are separate features.

The browser does not wait for image downloads during startup. Artwork remains
visible and eligible for rendering while loading; it must not be hidden behind
its own `IsLoaded` condition. Browser symbols use images exclusively; the old
Frame glyph implementation has been removed. Until an asset loads, or if it
cannot load, its icon stays blank. Destroying an icon releases its color
bindings. `IconRenderMode` reports `image` when an image is configured and
`empty` otherwise. All icon GuiObjects keep `Active = false` and
`Selectable = false`.

Set `IconAssets.Image` to change the shared image, or pass `IconAtlasImage` to
`Browser.mount` or the optional `Browser.Integration.WindowHost` for one host's mounts. An
empty string deliberately leaves named icons blank. This changes artwork only;
pointer handling, HTML rendering and window management keep their existing
owners. No HTML renderer or EditableImage permission is needed for icons.

The PNG's dimensions, alpha, white tint and all named crop regions were checked,
and the Figma Light/Dark review was visually inspected. The supplied Roblox ID
is configured, but Studio window capture timed out twice, so live Roblox image
loading and the experience's access to that image were not observed.

## Files and Roblox Explorer mapping

Rojo maps folders with an `init.luau` file to ModuleScripts and their remaining
files to children. Folders without an init file remain folders.

The combined project has exactly three top-level modules in ReplicatedStorage:

```text
ReplicatedStorage
├─ HTMLEngine
│  ├─ Examples (Config, ResizableTestWindow, FontLab, FontComparison)
│  └─ Tests
├─ Browser
│  └─ Integration
│     ├─ HTMLBinding
│     │  └─ InputScope
│     └─ WindowHost
└─ WindowManager
```

Other implementation children remain inside their owning module. `HTMLPageDemo`
supplies all dependencies to the optional integration; requiring Browser does not
load either adapter, HTMLEngine or WindowManager. Engine examples and tests are
not loaded by the HTML core. The former `WaylinePage` journal example is removed.

| Workspace source | Roblox Explorer destination | Responsibility |
| --- | --- | --- |
| `src/Browser/init.luau` | `ReplicatedStorage/Browser` | Mounting, public API, navigation and page lifetimes |
| `src/Browser/Address.luau` | `Browser/Address` | Canonical addresses and ranked local search |
| `src/Browser/Registry.luau` | `Browser/Registry` | Native pages and approved provider metadata |
| `src/Browser/Model.luau` | `Browser/Model` | One document, its navigation stack and generation tickets |
| `src/Browser/Session.luau` | `Browser/Session` | Serializable snapshots and restoration |
| `src/Browser/SharedData.luau` | `Browser/SharedData` | Settings, Home, quick links, bookmarks and visits |
| `src/Browser/Input.luau` | `Browser/Input` | One registered-control pointer and scroll router |
| `src/Browser/Lifetime.luau` | `Browser/Lifetime` | Owned connections, cleanup functions and instances |
| `src/Browser/Signal.luau` | `Browser/Signal` | Owned callback subscriptions |
| `src/Browser/Tokens.luau` | `Browser/Tokens` | Themes, spacing, typography, timing and breakpoints |
| `src/Browser/Theme.luau` | `Browser/Theme` | Live token bindings and conflicting tween cancellation |
| `src/Browser/Gui.luau` | `Browser/Gui` | Passive native GUI construction |
| `src/Browser/Icons.luau` | `Browser/Icons` | Image icons, theme tinting, load switching and cleanup |
| `src/Browser/IconAssets.luau` | `Browser/IconAssets` | Roblox image ID, named atlas crops and per-mount overrides |
| `src/Browser/CursorIcons.luau` | `Browser/CursorIcons` | Browser-owned arrow, hand and text cursor image IDs matching HTML |
| `src/Browser/Controls.luau` | `Browser/Controls` | Reusable buttons, text fields and custom scrollers |
| `src/Browser/Overlay.luau` | `Browser/Overlay` | Menus, dialogs, suggestions, tooltips and notices |
| `src/Browser/View.luau` | `Browser/View` | Responsive browser content layout |
| `src/Browser/BookmarksBar.luau` | `Browser/BookmarksBar` | Root bookmarks, folders and overflow |
| `src/Browser/Pages/init.luau` | `Browser/Pages` | Built-in page definitions |
| `src/Browser/Pages/*.luau` | `Browser/Pages/<filename>` | Home, Search, Bookmarks, History, Settings, Guide, Error and shared page helpers |
| `src/Browser/Persistence/Schema.luau` | `Browser/Persistence/Schema` | Shared validation, defaults, formats and migrations |
| `src/Browser/Persistence/Client.luau` | `Browser/Persistence/Client` | Optional asynchronous client storage transport |
| `src/BrowserServer/init.luau` | Not mapped in supplied projects | Optional server backend source |
| `src/BrowserServer/Store.luau` | Not mapped in supplied projects | Optional DataStore lease and revision source |
| `examples/BrowserPersistence.server.luau` | Not mapped in supplied projects | Optional persistence bootstrap source |
| `examples/compat/RetiredPersistence.server.luau` | Disabled `BrowserPersistenceServer` and `HTMLStorageServer` | Replace previously synced starters with inert source; preserve other game scripts |
| `examples/Browser.client.luau` | `StarterPlayer/StarterPlayerScripts/BrowserDemo` | Standalone content host, only in `browser.project.json` |
| `src/Browser/Integration/HTMLBinding` | `Browser/Integration/HTMLBinding` | Optional HTML content-provider adapter |
| `src/Browser/Integration/WindowHost.luau` | `Browser/Integration/WindowHost` | Optional application glue for the existing window engine |
| `examples/StudioDemoConfig.luau` | `HTMLEngine/Examples/Config` | Active demonstration selection |
| `examples/ResizableTestWindow.luau` | `HTMLEngine/Examples/ResizableTestWindow` | Optional HTML-only demo resizing |
| `examples/FontLab` and `examples/FontComparison` | `HTMLEngine/Examples/FontLab` and `HTMLEngine/Examples/FontComparison` | Optional font demonstrations |
| `tests` | `HTMLEngine/Tests` | Existing checks, excluded from standalone production builds |

`Browser/...` and `HTMLEngine/...` mean children of those ReplicatedStorage modules;
`BrowserServer/...` means a child of `ServerScriptService/BrowserServer`.
`default.project.json` maps the browser, persistence service, HTML engine and
separate WindowManager. `browser.project.json` maps the native browser and its
persistence service without either engine. `htmlpage.project.json` retains HTML
alone, with no browser or window-module requirement.

The standalone LocalScript supplies its own ScreenGui and content Frame because
that project has no surrounding application GUI. A host that already has a GUI
passes its existing Frame directly and creates no additional ScreenGui.

## Mounting inside an existing content Frame

```lua
local Browser = require(game.ReplicatedStorage.Browser)
local browser = Browser.mount(contentFrame, {
    Session = savedHostSnapshot,
    CanReceivePointer = pointerEligibility,
})

browser:SetFocused(true)
browser:SetVisible(true)
browser:Navigate("wayline://guide")

-- Retain this before closing if this client should reopen the same live session.
savedHostSnapshot = browser:ExportSession()
browser:Destroy()
```

`contentFrame` is the host's actual content Frame. `savedHostSnapshot` is an
optional previously exported table. `pointerEligibility` is an optional callback
supplied by that host; it receives the coordinate described below and returns a
boolean. These are adapter inputs, not invented window-engine methods.

The host owns movement, resizing, stacking, focus, minimize, maximize and close.
It forwards focus and visibility changes to the browser. Wayline fills the supplied
Frame and reacts to its size. Its supported minimum is 480 by 360 content pixels.
Below that size, a readable size notice replaces the visual content while retaining
the live session. Narrow is below 640 pixels, medium is 640–899, and wide begins
at 900. Secondary actions remain available through visible overflow controls.

`SetVisible(false)` retains the session, hides browser visuals, releases browser
text focus, cancels pointer presses and drags, and dismisses overlays. Losing focus
cancels the same ephemeral interactions. `Destroy()` is idempotent and disposes
the mounted browser's native objects, subscriptions, input registrations, pending
work and tweens. It does not destroy the supplied host Frame. Closing never waits
for a permanent save.

The supplied projects keep data only for the current play session. Browser mounts
do not create a persistence client by default, and the project files contain no
DataStore server startup. For multiple windows, the application owns one shared
in-memory data object:

```lua
local shared = Browser.SharedData.new()

local primary = Browser.mount(primaryContent, {
    SharedData = shared,
    PersistenceEnabled = false,
})
local auxiliary = Browser.mount(auxiliaryContent, {
    SharedData = shared,
    PersistenceEnabled = false,
    PersistSession = false,
    ShowNavigation = false,
})
```

Destroy the application-owned shared data after its browser windows have been
disposed. The integration WindowHost shares it across the current window family.
HTMLPageDemo supplies `HTMLEngine.Storage.Memory` for page storage, so navigation
and same-origin popup communication work during the run without loading or saving
data over the network. A new play session receives fresh storage areas.

## Public browser API

| Call | Effect |
| --- | --- |
| `Browser.mount(contentFrame, options)` | Mount a complete browser in that content area |
| `browser:SetFocused(boolean)` | Permit input for the focused host window |
| `browser:SetVisible(boolean)` | Show/hide without losing the live session |
| `browser:Navigate(address)` | Resolve and open an address or local search phrase |
| `browser:Open(address?, intent?)` | Open or navigate the window's one document; defaults to Home |
| `browser:GetPage()` | Return the current document context or `nil` |
| `browser:Back()`, `browser:Forward()`, `browser:Reload()` | Traverse or recreate the current page |
| `browser:SetNavigationVisible(boolean)` | Toggle only Back, Forward and Reload; keep the address field |
| `browser:ExportSession()` | Capture a plain in-memory session snapshot |
| `browser:RestoreSession(snapshot, serverOnly?)` | Restore a validated host or server session |
| `browser:RegisterPage(definition)` | Add another native page definition |
| `browser:GetPersistenceStatus()` | Return the current restrained storage-status message |
| `browser:Destroy()` | Release this browser without waiting for a save |

Useful mount options are `Focused`, `Visible`, `Session`, `Pages`, `SharedData`,
`Persistence`, `PersistSession`, `PersistenceEnabled`, `AutoOpen`, `ShowNavigation`,
`ShowHomeButton`, and `CanReceivePointer`. `Browser.new` remains an alias for `mount`.
Use `AutoOpen = false` when an application must connect an external content adapter
before opening its document with `browser:Open(address)`.
In-memory operation is the default. The supplied demo also sets
`PersistenceEnabled = false` explicitly. The optional persistence transport is
created only with `PersistenceEnabled = true` or supplied explicitly through
`Persistence`; no supplied project installs its server backend.
`ShowNavigation = false` is the initial version of the three-button switch; it
never hides the address field.

`Open` always reuses the existing document context and its content target; it
cannot create background documents. `OpenTab`, `ReopenClosedTab`, `MoveTab` and
`GetRecentlyClosedTabs` are not available. `ShowTabs` is no longer a mount option.
The optional HTML/window adapters still use the internal context-boundary names
`GetActiveTab`, `GetTabs`, `SelectTab`, `CloseTab`, `OnSelectTab` and `OnCloseTab`.
They expose at most one current document and provide lifecycle compatibility;
they do not enable tab creation or switching between multiple documents.

## Input and coordinates

All browser-owned GuiObjects are created through `Gui` with `Active = false` and
`Selectable = false`. The browser never enables native button activation. TextBoxes
use explicit `CaptureFocus` while remaining passive. Clickable Frames and labels
register with the browser's router; their decorative icon descendants do not get
separate targets. Native scrolling is disabled where the router owns scrolling.

The input space is GUI-inset screen pixels: `InputObject.Position`,
`GuiObject.AbsolutePosition` and `PlayerGui:GetGuiObjectsAtPosition` are used in
the same space. `CanReceivePointer(position)` receives this same value. Do not
subtract a GUI inset again inside that callback. The router converts the physical
coordinate from `UserInputService:GetMouseLocation()` exactly once for wheel
handling by subtracting the top-left GUI inset. Supplied host geometry must use
the same convention. The standalone ScreenGui uses `IgnoreGuiInset = true` to fill
the available area; this does not justify applying a second event-coordinate
conversion.

The host callback determines whether another window or a host-owned overlay blocks
the pointer. Without that callback, the host must manage focus correctly; Wayline
does not own the stacking model of unrelated application windows. The native GUI
pick order still prevents ordinary foreground GUI surfaces from clicking through.

A click requires a press and release on the same eligible target. Moving more than
six mouse pixels or twelve touch pixels cancels the click. Drag capture belongs
to the particular pointer, including individual touches. A completed drag never
also clicks. In scroll regions, a touch swipe scrolls immediately; holding about
0.28 seconds before moving permits item reordering. Nested scroll regions choose
the eligible inner region, and custom scrollbar positions are clamped after size
or content changes. Focus loss, hiding and destruction cancel these gestures.

The browser menu contains Home, bookmark creation, Bookmarks, History, Settings
and the bookmarks-bar visibility switch. It offers no tab actions. Quick links
and bookmarks retain their own drag ordering. Additional browsing contexts are
separate windows owned by the optional window host, not hidden browser tabs.

Wayline implements no browser keyboard shortcuts or shortcut hints. Normal text
entry and Enter submission are supported in address/search fields. Optional HTML
content retains its own input behavior through the separate adapter.

The browser input router owns its cursor without requiring the HTML module.
Its arrow, hand and text image IDs match HTML: ordinary surfaces and disabled
controls and toolbar buttons use the arrow. Other clickable controls use
the hand, and text fields use the text cursor. An explicit button `Cursor`
overrides its variant's default. Over HTML content or unrelated UI it releases ownership;
touch, hiding, focus loss and destruction also release the cursor. Restoration
preserves cursor changes made by another owner after the browser's last write.

## Native page registration and lifecycle

Pass page definitions in `options.Pages`, or call `RegisterPage`. A definition has
`Route`, `Address`, `Title`, `Icon`, `Description`, optional `Keywords`, `Render`,
and optional `Prepare`. The route is case-insensitive and its canonical address
uses `wayline://`. A bare registered route such as `notes` opens the same page.
Other text becomes a locally encoded search query. Explicit external addresses
require an approved provider; unsupported addresses show an explanatory error page.

Native page definitions can be supplied directly, without a separate root module:

```lua
local browser = Browser.mount(contentFrame, {
    Pages = {{
        Route = "notes",
        Title = "Notes",
        Icon = "edit",
        Render = function(ctx)
            ctx.Controls:Text(ctx.Root, "Your notes", {
                Size = UDim2.new(1, -32, 0, 40),
                Position = UDim2.fromOffset(16, 16),
            })
        end,
    }},
})
browser:Navigate("wayline://notes")
```

`Render(ctx)` receives:

| Context member | Purpose |
| --- | --- |
| `Root` | Page-owned native content target |
| `Gui` | Shared passive factory and theme-bound properties |
| `Controls` | Scoped buttons, fields, labels and custom scrollers |
| `Input` | Explicit registration for custom controls; no new global input listener |
| `Theme.Tokens`, `Theme.Changed` | Current live tokens and theme-change subscription |
| `Scope:Add(resource)`, `Scope:Child()` | Ownership for instances, connections, cleanup functions and child scopes |
| `State` | Serializable page-local state; keep Instances and connections elsewhere |
| `Shared` | Shared settings, Home, bookmark and history mutations |
| `Navigate(address)` | Use normal browser navigation |
| `URL`, `Query`, `Registry`, `Address` | Canonical location and registered-page metadata |
| `Generation`, `IsCancelled()` | Reject obsolete page work |
| `Prepared` | Result from an optional asynchronous preparation function |
| `Refresh()` | Capture and recreate this page from its current state when needed |

Return an optional page object with `Capture()` and `Destroy()` functions. `Capture`
returns serializable state, including custom scroll offsets. The browser captures
it before leaving the page or exporting a session; its scope releases all owned
resources. The example returns `Capture`, while controls own their own cleanup.
Native pages are released when leaving them and recreated from state on return.
Changing themes updates live bindings instead of rebuilding the page or clearing
text. Keep state-dependent labels synchronized through the shared change signal.

Optional `Prepare({URL, Query, IsCancelled})` may yield while preparing real local
work. The browser shows its loading line only while work is pending, ignores old
generations, and presents a themed error if preparation fails. It adds no waiting
time to a synchronous page. A successful native render records a visit; rendering
an error, reloading or restoring does not.

Use `Icons.draw` for artwork so image tinting and cleanup stay shared.
Add a named symbol through the Figma atlas and matching crop manifest, or pass a
Roblox image ID for a page favicon. Keep text glyphs out of browser controls.

## Shared data and limits

The shared API includes `SetSetting`, `SetGreeting`, `SetBackground`, quick-link
add/edit/remove/move, bookmark/folder add/edit/delete/move/sort, history deletion
and clearing, plus `Export` and `Replace`. Mutations return a value or `true` on
success and `false, message` on validation failure. Adding an already bookmarked
address returns its existing item so the page can reveal it. Bookmarks use stable
IDs and an ID-keyed collection, with `Parent = "root"` or a parent folder ID and
manual `Order`. `GetChildren(parent)` returns that stored order.

| Data | Limit |
| --- | --- |
| Documents per browser window | 1 |
| Quick links | 12 |
| Bookmarks | 300 unique canonical addresses |
| Folders | 50, at most five folder levels |
| Global visits | Latest 500 |
| Saved titles and greetings | 120 Unicode characters |
| Saved addresses | 512 Unicode characters |
| Serialized server save payload | 512 KiB, measured as bytes |

Themes are Light/Dark and accents are Blue/Purple/Green. Home backgrounds are
Slate, Ocean, Meadow, Plum, Sand and Rose. Theme colors, touch targets, layers,
breakpoints and animation timing live in `Tokens`; interactions and pages use
the same helpers. Hover/press takes about 0.10 seconds, menus 0.14 seconds,
and theme changes 0.20 seconds. Interrupted tweens are canceled by property and
settle toward the current intended state.

## Optional persistence source APIs — inactive in supplied projects

The supplied Rojo projects deliberately omit the server bootstrap and backend.
HTMLPageDemo and BrowserDemo keep data only in memory and disable persistence.
Two disabled no-op compatibility scripts replace previously synced starters at
their existing names. ServerScriptService preserves unrelated game scripts.
The remaining section documents the optional source APIs for a host that chooses
to install its own backend; it does not describe the active application.
DataStore access in that optional browser backend exists only in `BrowserServer`;
pages and browser clients never call DataStoreService.

The bootstrap uses DataStore `WaylineBrowser_v1` and keys `player_<UserId>`.
Change the `Name` passed to `BrowserServer.new` to use a separate development
store. The service creates `ReplicatedStorage/WaylinePersistence` with `Load`
(RemoteFunction), `Update` and `Status` (RemoteEvents). These are service-owned
transport details, not a page API.

The server validates plain types, UTF-8 text lengths, enum values, addresses,
collection bounds, unique IDs, parent references, folder cycles and depth,
the current document address, table depth and encoded payload size. Current
saved data uses version 2 with one `Session.Page`. Version 0 and version 1 data
migrate to version 2: the previously selected document becomes the sole page,
and shared settings, bookmarks and history are preserved. Legacy background
documents and closed-document lists are not restored. Malformed or
future data is preserved in the store and the current browser falls back to
memory instead of overwriting it with defaults.

The client coalesces changes for 1.5 seconds; the server debounces writes for
eight seconds, with a bounded continuous-change interval. Remotes have a five
request burst with one token replenished every two seconds. Writes use up to
three attempts with bounded backoff and coalesce changes arriving during a write.
Player departure and server shutdown attempt a final save and lease release.
Destroying a browser does not wait for these operations.

`UpdateAsync` owns a per-player lease, valid for 120 seconds and renewed while
active. A token and monotonic revision prevent an older server session from
silently overwriting a newer one. Client transport GUIDs and ordered sequences
reject late updates from a replaced transport. A failed initial load never grants
permission to overwrite stored data. Conflicts and storage failures are reflected
in the Settings status without repeated blocking dialogs. An unavailable save is
never labeled permanently saved.

## Restoration and fallback

Three categories stay separate: shared personal data, a serializable live
document session, and ephemeral UI state. Hover, presses, menus, item drags,
native focus, pending work and live GUI objects do not enter snapshots or saves.

An explicit host `Session` wins over the saved server session, which wins over
default Home. `ExportSession()` returns a version 2 host snapshot with one `Page`:
its canonical address, title, favicon, full navigation stack, serializable page
state and scroll offsets. `Session.Validate(snapshot, serverOnly)` returns a safe
copied table or `nil, message` before UI mutation. Version 1 host snapshots are
read only for migration: the previously selected page is retained, and the result
contains no background or closed pages. A version 2 snapshot containing legacy
`Tabs`, `Selected` or `Closed` fields is rejected.

A server session contains only `Page = {Address = canonicalAddress}`. Rejoining
creates one fresh navigation entry and does not restore temporary page edits or
the previous client navigation stack. The existing `WaylineBrowser_v1` DataStore
name remains unchanged so validated older saves can migrate in place.

Late server responses cannot replace newer local navigation. Locally changed
settings are kept; pre-load history visits and bookmark edits are reconciled
with stored data. If the combined collections cannot fit the limits, the browser
keeps current changes in memory and preserves the stored copy instead of silently
discarding it. Discovery/RPC timeouts, failed loads and write errors retain a usable
browser with a restrained status message. Actual permanent availability depends
on the experience's DataStore configuration and Roblox's service availability.

## Optional HTML and window integration

The [HTML binding](../src/Browser/Integration/HTMLBinding/init.luau) connects approved HTML
catalog addresses through `OnNavigate(pageContext, request)`, `IsCurrent`,
`CompleteNavigation` and `FailNavigation`; native switches signal `OnStartPage`
so an old HTML mount can be released. `OnCapture` lets the provider retain its
serializable navigation state before the native UI is disposed. The core browser
contains no HTML parser, renderer, VM, resource host or arbitrary HTTP transport.

The [window host](../src/Browser/Integration/WindowHost.luau) receives Browser,
WindowManager, the HTML binding and HTMLEngine from the LocalScript. WindowManager
continues to own outer geometry, eight resize grips, stacking, minimize/restore,
maximize and close. Wayline owns only the browser content. Browser popup navigation
buttons remain individually switchable while the address field stays visible.
The existing HTML window handles, same-origin document access, messaging,
navigation and in-game fullscreen remain adapter responsibilities.

With this window host, `window.open()` and links targeting `_blank` create a
separate window, including when no popup features were requested. A named target
can reuse its existing window. The browser core does not create a background
document. A bare HTML binding can forward `_blank` links through its host's
`OpenWindow` callback; without a window callback, those links navigate its
current document.

The optional binding also supplies callback-based simple dialogs and a synchronous
leave-confirmation host to each HTML realm. `BeforeNavigate` and `BeforeCloseTab`
are yieldable guards: rejection retains the current page and navigation history.
The window host installs `Window:SetCloseGuard` and uses `RequestClose` for native
caption and script-created popup closes. Explicit host teardown still uses `Close`.
The HTML module stays independent when these hosts are omitted.

`Overlay:ScriptDialog(request, complete)` returns an idempotent cancellation
function. A request uses `Kind` (`alert`, `confirm`, `prompt`), `Message`, optional
`DefaultValue`, `URL`/`Origin` and host-owned labels. The response callback receives
`accepted, value` once, after modal cleanup. The panel restores the prior native
editor and selection; failed or reentrant native measurement releases its shield
and listeners. Dialogs do not install global browser shortcuts.

Actual document visibility is separate from temporary GUI staging. Document
replacement and window hiding propagate visibility to retained HTML/iframe realms; canceling
a pending mount destroys its suspended realm before its late UI response.
The bounded lifecycle contract is documented in
[WEBSITES](WEBSITES.md#dialoge-und-seitenlebenszyklus--15-oktober-2026).

The supplied WindowManager now includes the complete imported window/dialog
system, including shadows, opening/closing animations, snap preview, owned windows
and modal MessageBox controls. The bridge additionally checks modal input eligibility.
The former native `wayline://windows` demonstration is retained only in the
[regression archive](../tests/fixtures/retired-native-window-demo-20261016.json).
The local website catalog contains all three original game Wikis and 60 site entries,
175 HTML routes in total. Fifteen routes carry explicit content placeholders;
subpages remain routable without appearing as extra Home tiles.
Earlier supplied pages remain only in the non-served regression archive. The host API and source boundary are maintained in
[WEBSITES](WEBSITES.md#eigenständige-fenster--14-oktober-2026).

HTML still mounts alone through `Engine.mountHTML`. Without an injected
WindowHost, the engine provides its own simple window and dialog host, including
`window.open()`; only the raw runtime path without either host returns `null`.
`HTMLPageDemo` selects this fallback automatically when Browser or WindowManager
is absent, immediately after initial place replication has completed; it does
not wait for an intentionally missing optional root. Browser persistence's
server starter also skips initialization when Browser is absent.
`htmlpage.project.json` starts the same DeepWiki document without either
optional module. The engine imports no Wayline or WindowManager module.
The browser-only Rojo project imports neither engine, and Windows10's
desktop, taskbar and application modules are not runtime dependencies.

The `BrowserSingleView` native fixture verifies the desktop and touch toolbar,
absence of tab controls and menu actions, passive hover/press routing, one retained
document target, bookmarks, responsive minimum size, fullscreen and cleanup.
These checks do not render Roblox pixels. This code reference does not assert
that Roblox Studio pixel output or permanent DataStore operations were observed
during its creation.
