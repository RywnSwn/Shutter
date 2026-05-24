# /compact — Shutter elevation, Batch A

## Goal
Elevate macOS menu bar privacy app "Shutter" from prototype → real-company feel via 3 batches (A: visuals, B: instant kill, C: trust/content). Batch A complete, B and C pending.

## Context
- project: Shutter (macOS menu bar app — hides apps/websites when handing Mac to nosey teachers/parents)
- path: `/Users/rywn/Documents/Random Projects/Shutter`
- stack: Swift 5.9, SwiftUI + AppKit, macOS 13+
- build: `./build_app.sh` → `build/Shutter.app` + `build/Shutter-<version>.dmg` (auto-DMG added this session)
- version: `1.0.1` in Info.plist (was 1.0; public release notes still say 1.0.0)
- git: deleted intentionally by user — do not recreate without asking
- user: non-coder — explain in plain English, no jargon
- user rule: batched changes by file/concept, not all-at-once, not one-by-one
- user rule: rebuild DMG every change automatically (build_app.sh handles it)
- accent color: warm orange `#E8842E` matching icon

## Decisions Made
1. Strategy: batch A (visuals) → B (instant kill) → C (trust copy)
2. Accent color: orange pulled from icon gradient
3. Menu bar UI: `NSMenu` → `NSPopover` with SwiftUI content
4. Toggle: custom `SecureModeSwitch` (not native Toggle) — pure state-driven, no optimistic animation
5. Popover: rebuild `NSHostingController` on every open to prevent stale SwiftUI state
6. Popover background: `.regularMaterial` to prevent translucency seam
7. Cursor: pointing-hand on Settings/Quit hover via NSCursor (mac 13 target, no `.pointerStyle`)
8. DMG: extend `build_app.sh` with `hdiutil` + `/Applications` symlink; fancy formatting deferred

## Artifacts
- `Sources/Shutter/Theme.swift` — NEW. `Color.shutterAccent` + `AppIconImage` view
- `Sources/Shutter/MainWindow.swift` — header redesigned with real icon + accent
- `Sources/Shutter/OnboardingView.swift` — welcome uses real icon, checkmark uses accent
- `Sources/Shutter/MenuBarController.swift` — full rewrite, NSPopover + `MenuBarPopover` SwiftUI view + `SecureModeSwitch` + `pointingHandOnHover`
- `build_app.sh` — added DMG step via hdiutil
- `build/Shutter-1.0.1.dmg` — current ship artifact

## Verbatim (auto-preserved)

**Custom switch (driven purely by source-of-truth, no optimistic animation):**
```swift
struct SecureModeSwitch: View {
    let isOn: Bool
    let action: () -> Void
    private let width: CGFloat = 46
    private let height: CGFloat = 26
    private var knobSize: CGFloat { height - 4 }
    var body: some View {
        Button(action: action) {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? Color.shutterAccent : Color.secondary.opacity(0.35))
                    .frame(width: width, height: height)
                Circle().fill(.white)
                    .frame(width: knobSize, height: knobSize)
                    .shadow(color: .black.opacity(0.2), radius: 1, y: 0.5)
                    .padding(2)
            }
            .animation(.easeInOut(duration: 0.18), value: isOn)
        }
        .buttonStyle(.plain)
        .pointingHandOnHover()
    }
}
```

**Cursor hover helper:**
```swift
private extension View {
    func pointingHandOnHover() -> some View {
        self.onHover { hovering in
            (hovering ? NSCursor.pointingHand : NSCursor.arrow).set()
        }
    }
}
```

**Popover lifecycle pattern:**
- Rebuild `NSHostingController` in `openPopover()` every time
- `popoverDidClose` delegate resets `NSCursor.arrow.set()` + stops outside-click monitor
- Right-click on status item: temporary `NSMenu` with Quit, then detached

**DMG build step in build_app.sh:**
```bash
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist 2>/dev/null || echo "dev")
DMG_PATH="$BUILD_DIR/$APP_NAME-$VERSION.dmg"
STAGING_DIR="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"
cp -R "$APP_DIR" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_PATH" >/dev/null
rm -rf "$STAGING_DIR"
```

## Verbatim (user-marked)
N/A

## Status
**Done:** Batch A — all visual changes shipped, DMG auto-build wired up.

**Open bugs:**
1. **Cursor still "weird"** — user reported after `popoverDidClose` fix. Specifics unclear. Possible fix: replace `.onHover` + `NSCursor.set()` with proper `NSTrackingArea` via `NSViewRepresentable`.
2. DMG has no custom layout — parked until after B + C.
3. Version mismatch: Info.plist `1.0.1` vs release notes `1.0.0`. Decide.
4. Pre-existing actor warning in `WebsiteBlocker.swift:51` — not from our changes; mark `runScript` as `nonisolated static` to silence.

**Next:**
- Batch B: replace/augment `Watcher.swift` 1.5s poll with `NSWorkspace.didLaunchApplicationNotification` for instant kill. Keep poll as fallback. Touches `Watcher.swift` + maybe `App.swift`.
- Batch C: trust-forward onboarding copy + password recovery story (recovery code OR "no recovery by design"). Touches `OnboardingView.swift` + `MainWindow.swift` Settings tab.

## Resume
> [COMPACT] Shutter (`/Users/rywn/Documents/Random Projects/Shutter`) — non-coder user, batch A (visuals + NSPopover menu bar) shipped to `build/Shutter-1.0.1.dmg`. Lingering cursor bug from A unresolved (try NSTrackingArea via NSViewRepresentable). Pick up Batch B = instant kill via `NSWorkspace.didLaunchApplicationNotification` in `Watcher.swift`, keep 1.5s poll as fallback. Build with `./build_app.sh`. No git. Explain in plain English.
