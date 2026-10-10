---
id: autotype-releases
type: release
product: autotype
title: "AutoType — Releases"
status: active
updated: 2026-10-11
relations:
  presentedBy: [github:wblekhoa/autotype/releases]
---
# AutoType — Releases (newest first)

Source of truth: `gh release list -R wblekhoa/autotype` and each release's notes (checked 2026-10-11: v2.2, v2.1,
v2.0). There is no CHANGELOG file. REQ-IDs were introduced on 2026-10-11; they are traced below only where a release note
names the behaviour.

## v2.2 · 2026-08-31
- **What changed for users**: the window was rewritten in SwiftUI (grouped settings form, sized to its content, overlay
  scrollers that appear at the right edge, menu-bar keyboard icon); a window kept its old size after upgrading - fixed.
  Two documented install paths (one-line Terminal, or ZIP + "Open Anyway"). Engine, hotkey, log and safety rails
  unchanged.
- **REQ-IDs shipped**: none new (UI only; engine unchanged per the release notes).
- **Channel**: GitHub release (`AutoType.zip`, universal binary, ad-hoc signed, not notarized) and `install.sh`.
- **Shown in**: GitHub release notes; README.

## v2.1 · 2026-08-31
- **What changed for users**: the first two characters of a session no longer come out as `a`; pressing the hotkey while
  the AutoType window is in front now shows an orange message with a beep; the build no longer leaves a second `.app`;
  a missing icon no longer breaks the build; narrower window; the speed trade-off above ~1000 chars/s is stated.
- **REQ-IDs shipped**: AT-TYPE-006 (pipeline warm-up), AT-TYPE-009 and AT-TYPE-010 (visible refusals).
- **Channel**: GitHub release and `install.sh`.
- **Shown in**: GitHub release notes.

## v2.0 · 2026-08-30
- **What changed for users**: first release of the Swift app: one-line install, universal binary (Intel + Apple
  Silicon), macOS 13+; enable AutoType under Accessibility after installing.
- **REQ-IDs shipped**: not traced (REQ-IDs introduced 2026-10-11; the release notes describe installation only).
- **Channel**: GitHub release and `install.sh`.
- **Shown in**: GitHub release notes.
