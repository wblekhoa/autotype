---
id: autotype-decisions
type: decision
product: autotype
title: "AutoType — Decisions"
status: active
updated: 2026-10-11
summary: "Append-only record of why AutoType is built as it is: Swift CGEvent engine, safety rails, rate ceiling, pipeline warm-up, SwiftUI rewrite, install paths, transparency claims and doc gates."
tags: [area/input-events, area/permissions, area/release, area/signing, area/testing, stack/swift, surface/macos]
---
# AutoType — Decisions (append-only, newest first)

Reconstructed on 2026-10-11 from the README, the GitHub release notes, commit messages and `ai-memory/lessons/`. Commit
hashes are in this repo; dates are commit dates.

## 2026-10-11 · Product docs live in `docs/product/`, in English, with REQ-IDs in the code
- **Context**: the product had a Vietnamese README and `docs/DEVELOPMENT.md` but no feature-level record of its rules.
- **Decision**: adopt the shared product-doc layout (goal, ux, logic, decisions, releases). REQ-IDs (`AT-TYPE`,
  `AT-KEY`) are trailing comments on existing lines of `AutoType.swift`, so the file stays at 702 lines and the README
  line-count claim checked by `verify.sh` stays true. Rejected: adding new comment lines (would break that claim).
- **Evidence**: `./verify.sh` 14 passed · 0 failed after the edit; `wc -l AutoType.swift` = 702.
- **Reversal**: delete `docs/product/` and the `// AT-…` trailing comments.

## 2026-09-01 · State what the app does with Accessibility, each claim with a command (e9e988b, 6a24616)
- **Context**: Accessibility is a broad permission; users have to trust the app with it.
- **Decision**: a README section lists what the app does and does not do, each "does not" with a command anyone can run
  after cloning (no event tap or global monitor, no network, no login item, Apple frameworks only, line count).
  `verify.sh` checks those claims against the code so they cannot silently go stale.
- **Evidence**: `verify.sh` section 5 ("7 transparency claims match the code").
- **Reversal**: remove the section and its gate together; never one without the other.

## 2026-08-31 · The gate reads the docs, not only the code (3872025)
- **Context**: `docs/DEVELOPMENT.md` described a dead AppKit architecture for several commits while `verify.sh` stayed
  green - no check read documentation.
- **Decision**: `verify.sh` extracts every backticked code symbol from `docs/DEVELOPMENT.md` and fails if it is not in
  `AutoType.swift`; it also checks README images and in-page anchors.
- **Evidence**: lesson `ai-memory/lessons/gate-your-docs-not-just-your-code.md`.
- **Reversal**: new entry; drop the doc checks from `verify.sh`.

## 2026-08-31 · Rewrite the UI in SwiftUI `Form`, keep the engine byte-identical (cd1f1ed → v2.2)
- **Context**: the hand-tuned AppKit window came out too wide and needed per-row point tuning.
- **Decision**: a grouped SwiftUI `Form` (Apple's settings-window idiom), sized by its content and clamped to 380-420 pt;
  `ObservableObject` rather than `@Observable` because the app supports macOS 13. Engine code unchanged, confirmed by the
  gate's hash comparison. Follow-ups the same day: clear the saved window frame at launch (b8dcf67), overlay scrollers
  that appear when hovering the right edge (ae0be14, d870baa).
- **Evidence**: v2.2 release notes; source went from 814 to 588 lines (before later additions).
- **Reversal**: new entry; the AppKit version is in history before cd1f1ed.

## 2026-08-31 · Refusals must be visible: orange message plus a beep (d516118)
- **Context**: a user pressed the hotkey three times while looking at the AutoType window and concluded the app was
  broken; the refusal was a small grey status line.
- **Decision**: refusals (AutoType in front, empty set, no permission) show an orange message and beep for 6 s
  (AT-TYPE-009, AT-TYPE-010).
- **Evidence**: v2.1 release notes; `Engine.shout(_:)`.
- **Reversal**: new entry.

## 2026-08-31 · The typing-harness part of the gate is opt-in (`--full`) (dbdb225)
- **Context**: the end-to-end measurement opens a window and takes the foreground from whoever is using the Mac.
- **Decision**: `./verify.sh` skips it by default; `./verify.sh --full` runs it. When the receiver cannot take focus the
  gate reports "machine busy", not "engine broken".
- **Evidence**: `verify.sh` section 3.
- **Reversal**: new entry; make `--full` the default.

## 2026-08-31 · Build leaves no second `.app` in the source folder (47ebbaa)
- **Context**: two copies with the same bundle id at different paths; opening the wrong one made macOS ask for the
  Accessibility grant again.
- **Decision**: `build.sh` installs to `~/Applications` and removes the copy in the source folder; the README tells users
  to keep exactly one AutoType.
- **Evidence**: comment in `build.sh`; v2.1 release notes.
- **Reversal**: new entry.

## 2026-08-30 · Warm the event pipeline at launch; the shared event source was not the cause (f8cc3bd)
- **Context**: the first two characters of a session arrived as `a` ("XYZ" → "aa", 3 of 3, across two processes).
- **Decision**: post three zero-width-space events at launch while no text field of the user has focus
  (AT-TYPE-006). A first A/B test seemed to show that a shared `CGEventSource` fixed it; re-running each variant in its
  own process showed both fail - the test had measured run order. The shared source was kept, but it is not the fix.
- **Evidence**: lesson `ai-memory/lessons/ab-test-order-is-a-confound.md`; plan `ai-memory/plans/verify-typing-engine.md`.
  Note: the comment above `Typist.source` still gives the disproved rationale; correcting it is open.
- **Reversal**: new entry.

## 2026-08-30 · Rate ceiling 2000 chars/s; recommend ≤200 for exact delivery (f8cc3bd)
- **Context**: measured with the two-process harness: exact at ≤200 chars/s; from ~1000 some receivers drop characters
  (~0.7% at 2000).
- **Decision**: allow up to 2000 (AT-TYPE-003) and state the trade-off in the UI footer and README instead of hiding it.
- **Evidence**: plan `ai-memory/plans/verify-typing-engine.md` (round 3); v2.1 release notes.
- **Reversal**: new entry.

## 2026-08-30 · Two install paths: one-line `curl`, or ZIP with "Open Anyway" (6f798b1, 4e8979d)
- **Context**: no paid Apple Developer certificate, so the app is ad-hoc signed and not notarized; browser downloads are
  quarantined and blocked on first open.
- **Decision**: primary path `curl … install.sh | bash` (curl sets no quarantine flag, no `sudo`); alternative ZIP from
  the latest GitHub release plus the per-app "Open Anyway" exception. Gatekeeper is never disabled.
- **Evidence**: README install section; `install.sh`; v2.2 release notes. Correction 0414845 removed a wrong Gatekeeper
  requirement after re-measuring.
- **Reversal**: new entry (e.g. if the app is ever notarized).

## 2026-08-30 · Bundle id and settings domain `com.lekhoa.autotype` (5463a82)
- **Context**: settings and the Accessibility grant are keyed by bundle id.
- **Decision**: one personal bundle id for the app and its `UserDefaults` suite; settings keys prefixed `v2.`.
- **Evidence**: `build.sh` (`BUNDLE_ID`), `Prefs` in `AutoType.swift`.
- **Reversal**: new entry; changing it costs every user a new Accessibility grant.

## 2026-08-30 · Safety rails built into the engine
- **Context**: an infinite stream of keystrokes into the wrong window is destructive, and an early version typed into its
  own settings fields and overwrote them.
- **Decision**: never type into AutoType itself (AT-TYPE-009); Esc always stops (AT-TYPE-007); every run stops after
  60 s as a second brake (AT-TYPE-008); a master on/off switch (AT-KEY-005); ⌥ banned from the hotkey because it inserts
  characters such as `†` before typing starts (AT-KEY-001, AT-KEY-007); the recorder times out after 6 s because an
  untimed recorder once captured a combination pressed minutes later.
- **Evidence**: comments in `AutoType.swift`; README "Lưu ý" section.
- **Reversal**: new entry per rail.

## 2026-08-08 · Swift with CGEvent instead of AppleScript; poll key state instead of an event tap
- **Context**: AppleScript cannot read whether a key is held, and System Events `keystroke` silently dropped the tail of
  long strings (94 characters sent → 58-61 arrived).
- **Decision**: one Swift file, built with `swiftc` (no Xcode project); characters posted as Unicode `CGEvent`s
  (layout- and input-method-independent, AT-TYPE-005); the hotkey read by polling the system key state for exactly the
  hotkey and Esc, with no event tap or global monitor (AT-KEY-002).
- **Evidence**: header comment of `AutoType.swift` (measurement dated 2026-08-08, before this repo's first commit).
- **Reversal**: new entry.
