# OSX Desk Notch

A tiny macOS menu-bar utility that turns the camera notch on modern
MacBooks into a hover-activated desktop (Space) switcher. Move the
cursor over the notch — a slim bar slides out underneath listing your
current desktops; click one to jump to it.

> **Distribution model:** Developer ID + notarization (direct download or
> Homebrew Cask). **Not** Mac App Store eligible. See
> [Why this is not on the App Store](#why-this-is-not-on-the-app-store).

---

## Requirements

| | |
|---|---|
| OS | macOS 14 Sonoma or later |
| Hardware | MacBook Pro 14"/16" (2021+) or MacBook Air 13"/15" (2022+) — anything with a notch |
| Tooling | Xcode 15+, [`xcodegen`](https://github.com/yonaskolb/XcodeGen) |

A non-notched display will silently no-op; the menu-bar item still appears
so the user can quit.

## Building

```bash
brew install xcodegen
xcodegen generate
open OSXDeskNotch.xcodeproj
# Then Product → Run (⌘R)
```

Or from the command line:

```bash
xcodegen generate
xcodebuild -project OSXDeskNotch.xcodeproj \
           -scheme OSXDeskNotch \
           -configuration Release \
           -derivedDataPath build \
           build
```

## Shipping (Developer ID)

1. In Xcode, set the team to your Developer ID identity.
2. `Product → Archive`.
3. From Organizer, **Distribute App → Developer ID → Upload** to
   submit the archive for notarization. Wait for the ticket.
4. **Export Notarized App**.
5. Drop the resulting `.app` into a signed `.dmg` (or Homebrew Cask).

CLI alternative once you have an exported `.app`:

```bash
xcrun notarytool submit OSXDeskNotch.zip \
    --keychain-profile "AC_NOTARY" --wait
xcrun stapler staple OSXDeskNotch.app
```

## Architecture

```
OSXDeskNotch/
├── App/            @main entry, AppDelegate, DI container
├── Notch/          Geometry math, overlay panel, hover monitor
├── Spaces/         Private CGS bridge + Combine-friendly observer
├── UI/             SwiftUI bar + tiles + theme tokens
└── Resources/      Info.plist, entitlements, asset catalog, bridging header
```

Data flow:

```
HoverMonitor ──► NotchWindowController ──► NotchBarView
                       │                         │
                       ▼                         │
                 SpacesObserver  ◄────refresh────┘
                       │
                       ▼
                 SpacesService  ──► CGS private SPI
```

Why this layout:

* **`SpacesService`** is the *only* file that touches the private SPI.
  All other layers operate on plain Swift value types (`Space`,
  `DisplaySpaces`). If Apple changes the SPI in a future macOS, the
  blast radius is one file.
* **`HoverMonitor`** polls `NSEvent.mouseLocation` instead of using a
  global event monitor — see the note in that file for why.
* **`NotchWindow`** is an `NSPanel` configured to span all Spaces,
  never accept key focus, and float just above the menu bar. It is the
  *only* AppKit window in the whole product.

## Security & privacy posture

This is the bit you asked to be uncompromising about.

| Concern | What we do |
|---|---|
| Sandboxing | App is **not** sandboxed (private CG SPI is incompatible with sandbox), but Hardened Runtime is **on**. |
| JIT / unsigned executable memory | Disabled in the entitlements file — `allow-jit`, `allow-unsigned-executable-memory`, `disable-library-validation` are all explicitly `false`. |
| Network | Zero network entitlements (`network.client` / `network.server` = false). The app makes no HTTP requests. No telemetry, no analytics, no crash reporter. |
| Camera / Mic | Explicitly disabled. |
| Automation (System Events) | **Required for desktop switching.** Primary path. We execute a one-line AppleScript that asks `System Events` to send `Control + Arrow`. The system prompts once, the user clicks Allow, done. Tied to bundle ID — survives Xcode rebuilds. |
| Accessibility | **Fallback only.** If the user denied the Automation prompt, the switcher falls back to `CGEvent.post`, which needs Accessibility. We don't ask for it up-front. |
| Input Monitoring | **Not required.** We never install a global event monitor for key/mouse events. |
| Screen Recording | **Required for desktop previews.** Uses `SCScreenshotManager` (ScreenCaptureKit) with our own app excluded from the frame. The cache is in-memory only — never written to disk, never transmitted. Granting is optional: deny it and the bar falls back to number-only tiles. |
| Data at rest | None. No file I/O outside the app bundle. Screen previews live in RAM only and are dropped on quit. |
| Code signing | Developer ID + notarization. Hardened Runtime mandatory; library validation kept on. |
| Private API usage | Confined to one file. The four symbols we use are listed in `Resources/CGSPrivate.h` with explanatory comments. |
| Memory safety | Swift's default. No `Unmanaged.passUnretained` shenanigans; all CF bridging is explicit and Swift-checked. |
| Concurrency | `SWIFT_STRICT_CONCURRENCY=complete`. Everything that talks to AppKit is `@MainActor`-isolated. |

If you plan to ship this, fold in:

* a `PrivacyInfo.xcprivacy` manifest with `NSPrivacyTracking=false` and an
  empty `NSPrivacyCollectedDataTypes`,
* an in-app `About` panel that links to a written privacy policy
  ("we collect and transmit nothing"), and
* SHA-256 checksums alongside any downloadable binaries.

## Testing

```bash
xcodegen generate
xcodebuild -project OSXDeskNotch.xcodeproj \
           -scheme OSXDeskNotch \
           -destination 'platform=macOS' \
           test
```

The included tests cover the pure model layer (`NotchGeometry`,
`DisplaySpaces`). UI and CGS interactions need a real WindowServer and
are best verified manually on a notched Mac — see the test plan in
the PR description when one exists.

## Why this is not on the App Store

The four `CGS*` symbols this app calls — `CGSMainConnectionID`,
`CGSCopyManagedDisplaySpaces`, `CGSManagedDisplayGetCurrentSpace`,
`CGSManagedDisplaySetCurrentSpace` — are private SPI. App Review
auto-rejects any binary that imports them. There is no public
replacement. AltTab, Mission Control Plus, Yabai, Total Spaces, and
every other Space-aware tool ship outside the App Store for this exact
reason.

If you ever want an App-Store-compliant variant, the closest you can
get is to drop the live Space enumeration and instead simulate
`⌃1` … `⌃9` via `CGEvent`, asking the user to enable
*System Settings → Keyboard → Shortcuts → Mission Control →
"Switch to Desktop N"*. That trades the current-space indicator and
dynamic count for App Store eligibility.

## License

TBD — add a `LICENSE` file before publishing.
