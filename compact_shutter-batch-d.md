# /compact — Shutter, end of Batch D (polish pass)

## Goal
macOS menu bar privacy app "Shutter" — hide apps + close blocked browser tabs when handing your Mac to nosey teachers/parents. Took it from prototype → real-company feel through Batches A (visuals), B (instant kill), C (trust copy + recovery codes), D (full polish pass across all 3 surfaces).

**All four batches are done.** Only minor leftovers remain.

## Context
- project: Shutter (macOS menu bar app)
- path: `/Users/rywn/Documents/Random Projects/Shutter`
- stack: Swift 5.9, SwiftUI + AppKit, macOS 13+
- build: `./build_app.sh` → `build/Shutter.app` + `build/Shutter-<version>.dmg`
- version: `1.0.1` in Info.plist (CFBundleVersion 2). No release notes file exists.
- git: deleted intentionally — do not recreate without asking
- user: non-coder — explain in plain English, no jargon
- user rule: batched changes by file/concept, not all-at-once, not one-by-one
- user rule: rebuild DMG every change automatically
- accent color: warm orange `#E8842E` (`Color.shutterAccent`)
- user prefers: filled prominent accent buttons over default grey, Cards over floating rows, hero illustrations over single-symbol placeholders

## What shipped (cumulative across A–D)

### Batch A — Visuals (menu bar)
- `MenuBarController.swift`: NSPopover (not NSMenu) hosting SwiftUI `MenuBarPopover`. Rebuild `NSHostingController` every open. Right-click on status item gets a temp NSMenu with Quit.
- Popover sizing: explicitly measure `controller.view.fittingSize` after `layoutSubtreeIfNeeded()`. **Do not** use `sizingOptions = [.intrinsicContentSize]` — it reports inflated heights.
- Footer hover: `FooterButton` private struct with `.onHover` → pointing-hand cursor + `Color.primary.opacity(0.08)` background fill. `popoverDidClose` resets `NSCursor.arrow.set()` defensively.

### Batch B — Instant kill (Watcher.swift)
- Already had 1.5s polling. Confirmed adequate for current user — instant-kill via `NSWorkspace.didLaunchApplicationNotification` was NOT added (user chose to skip; said "alr tahts good batch C"). If revisited later: add subscriber in `Watcher.swift:18` `start()`, keep the timer as fallback.

### Batch C — Trust + recovery codes
- `RecoveryCode.swift` (new): generates 12-char codes like `ABCD-EFGH-JKMN`, no ambiguous chars (no 0/O/1/I).
- `KeychainStore.swift`: added `hasRecoveryCode`, `recoveryCode()`, `setRecoveryCode`, `clearRecoveryCode`. `verify()` accepts EITHER password OR recovery code as input.
- `PasswordPrompt.swift`: `setNew` auto-generates a code on success and shows it via new `showRecoveryCode(_:isInitialReveal:)`. Also `generateAndShowRecoveryCode()` for legacy users.
- Unlock prompt placeholder now reads "Password or recovery code" with subtitle "Forgot it? Enter your recovery code instead."

### Batch D — Polish pass (3 surfaces)

**D.1 — Onboarding** (`OnboardingView.swift`): 5 pages (Welcome, Privacy, Picker, Password, Ready) with composed hero illustrations (`OnboardingHero.Welcome/Privacy/Password/Ready` in `Theme.swift`), Card-wrapped trust rows, sliding page transitions (`.move(edge:).combined(with: .opacity)` driven by `withAnimation(.easeInOut(duration: 0.28))`), warmer microcopy ("Meet Shutter" / "Private by design" / "Pick what to keep private" / "Lock it down" / "You're ready" → "Open Shutter"), `PageDots` instead of "1 of 5" text. Filled accent primary button. Skip button on password page when no pw set.

**D.2 — Main window** (`MainWindow.swift`): bigger header (56px icon with accent glow, 24pt bold title, `StatusPill` capsule badge, `HeaderBackdrop` gradient wash). Footer counts ("**3** apps · **0** sites") in accent + filled prominent Done. `AppPickerList` rewritten — rounded pill search bar with x-clear, count bar ("**N** apps selected" + Clear link), custom `AppPickerRow` with `SelectionIndicator` (filled accent circle + white check, 0.12s animation), hover/selected backgrounds. `WebsitesTab` rewritten — chip-styled `SiteRow` (accent dot + name + fade-on-hover trash), polished add bar matching search style, empty state inside a Card with circular accent backdrop on the globe.

**D.3 — Settings** (`SettingsTab` in `MainWindow.swift`): stock `Form` replaced. New `SettingsSection` (uppercase header + icon, wraps Card with rows) and `SettingsRow` (title + subtitle + trailing control) helpers. Four sections: Hotkey (keyboard icon), Startup (power icon), Password Lock (lock.shield icon — status row with circular tinted icon backdrop, then Change/Remove/Recovery as separate rows with subtitles), About (info.circle icon — app icon + name + Bundle.main version + privacy tagline, plus Replay Onboarding). Set Password is a filled accent prominent button.

## Design system primitives (in `Theme.swift`)
- `Color.shutterAccent` — `#E8842E`
- `AppIconImage(size:)` — bundled icon or `lock.shield.fill` fallback
- `HeroBackground` — linear + radial accent gradient wash (used in onboarding, full-screen)
- `HeaderBackdrop` — lighter linear wash (used at top of main window)
- `Card(padding:cornerRadius:){ ... }` — soft fill + hairline border, `Color.primary.opacity(0.045)` bg + `0.07` stroke
- `StatusPill(isSecured:size:)` — capsule with colored dot, accent when secured
- `SectionHeader(title:)` — uppercase tracked label
- `OnboardingHero.Welcome / Privacy / Password / Ready` — composed SF Symbol + glow + gradient scenes
- `SettingsSection` / `SettingsRow` — private structs in `MainWindow.swift`
- `FooterButton` / `AppPickerRow` / `SelectionIndicator` / `SiteRow` — private structs in their respective files

## Files touched (final state)
| File | Purpose |
|---|---|
| `Theme.swift` | Design system: colors, AppIconImage, Card, StatusPill, SectionHeader, HeroBackground, HeaderBackdrop, OnboardingHero |
| `App.swift` | App lifecycle. Watches `state.$hasCompletedOnboarding` to re-show onboarding when Replay is clicked |
| `MenuBarController.swift` | Menu bar popover + MenuBarPopover SwiftUI view + FooterButton + manual fittingSize measurement |
| `MainWindow.swift` | Header + footer + tabs. Contains AppPickerList, AppPickerRow, SelectionIndicator, SettingsTab, SettingsSection, SettingsRow, WebsitesTab, SiteRow, AppIcon |
| `OnboardingView.swift` | 5-page onboarding with hero scenes, cards, page transitions, PageDots |
| `PasswordPrompt.swift` | NSAlert-based password/recovery prompts. `setNew` auto-generates code |
| `KeychainStore.swift` | Password + recovery code storage. `verify()` accepts either |
| `RecoveryCode.swift` | Generator only (12-char with separators) |
| `WebsiteBlocker.swift` | `runScript` and `extractStringList` marked `nonisolated static` (fixed Swift 6 actor warnings) |
| `Watcher.swift` | Unchanged from start. 1.5s timer polls and kills/sweeps |
| `Info.plist` | CFBundleShortVersionString = 1.0.1, CFBundleVersion = 2 |
| `build_app.sh` | Builds .app + DMG via hdiutil |

## Conventions & pitfalls learned
- **Popover sizing:** explicit `layoutSubtreeIfNeeded()` + `fittingSize` is reliable. `.intrinsicContentSize` sizingOption inflates heights.
- **Custom hover cursor:** SwiftUI `.onHover` + `NSCursor.pointingHand.set()` works IF you also reset `NSCursor.arrow.set()` from `popoverDidClose` defensively (cursor can stick when window dismisses).
- **Card layout:** `Card(padding: 0)` for grouping rows where each row has its own padding. Use `Divider().opacity(0.3).padding(.leading, 14)` between rows for in-card separation.
- **Accent buttons:** `.buttonStyle(.borderedProminent).tint(.shutterAccent)` is the consistent CTA style.
- **`.fixedSize(horizontal: false, vertical: true)`** is essential on multi-line Text in SwiftUI when you want it to hug content vertically. Used throughout.
- **Onboarding window:** `windowWillClose` delegate marks `hasCompletedOnboarding = true` if not already, so even closing via X completes onboarding.

## Open items (none critical)
1. **D.4 — Popover refinements** — was planned conditionally. After D.1–3 the popover already looks consistent. Skip unless user reports something off.
2. **Notifier.swift:57 warning** — pre-existing Swift 6 actor isolation warning, `activeWindows.removeAll` inside an animation completion closure. Cosmetic only. Fix: wrap in `Task { @MainActor in ... }`.
3. **Version bump** — Info.plist still 1.0.1. If user wants to share / re-DMG, bump to 1.0.2. Build script reads version from Info.plist for DMG filename.
4. **DMG fancy layout** — parked since Batch A. Current DMG uses `hdiutil` with a `/Applications` symlink. No custom background or icon positioning. Bigger lift if pursued.
5. **Instant-kill via NSWorkspace notification** — original Batch B plan. User accepted current 1.5s poll as "alright". Could revisit if responsiveness ever feels slow.

## Resume prompt
> [COMPACT] Shutter (`/Users/rywn/Documents/Random Projects/Shutter`) — non-coder user, all 4 polish batches (A visuals, B instant kill skipped as 1.5s poll is fine, C recovery codes, D full polish pass on onboarding + main window + settings) shipped to `build/Shutter-1.0.1.dmg`. The app feels cohesive and "real". See `compact_shutter-batch-d.md` for design system primitives in `Theme.swift`, file conventions, and the 5 open items (none critical: D.4 popover refinements, Notifier.swift:57 warning, version bump, DMG layout, instant-kill). Build with `./build_app.sh`. No git. Explain in plain English. User rule: batched changes by file/concept, not all-at-once, not one-by-one.
