---
id: autotype-logic-typing
type: logic
product: autotype
title: "AutoType — Typing engine (logic)"
status: active
updated: 2026-10-11
reqPrefix: AT-TYPE
relations:
  specifiedBy: [autotype-ux-typing]
  implements: [AutoType.swift, verify.sh, tools/make-logic-test.sh, tools/make-harness.sh]
---
# AutoType — Typing engine (logic)

## Purpose
- Turn one run (started by the hotkey) into a stream of characters posted to the focused app, at a chosen rate and
  count, from a chosen character set - and always be stoppable.
- Success signal: what arrives equals what was sent at ≤200 chars/s; Esc, release or the 60 s cap always end a run.

## Rules

Evidence notes: all code lives in `AutoType.swift`; each REQ-ID is a trailing comment on the line that implements it.
"verify §4" = the pure-logic test (`tools/make-logic-test.sh`, run by `./verify.sh`, 17 assertions, injects `enum Pool`
verbatim). "verify --full" = the two-process typing harness (`tools/make-harness.sh`), which takes the foreground and
was **not run** on 2026-10-11. Rules marked "code only" have no automated test: posting real key events to another app
needs the Accessibility grant and a focused window, which cannot be exercised headlessly.

| REQ-ID | Rule (behaviour-changing) | Status (live / not built / blocked) | Evidence (code path or test) |
|---|---|---|---|
| AT-TYPE-001 | Five character sets: Letters = `A-Z a-z` (52), Digits = `0-9` (10), Letters and digits (62), Full keyboard = the 94 printable ASCII characters `!` (33) to `~` (126), Custom text = the user's text exactly as entered. | live | `Pool.characters(custom:)`; verify §4 (94/52/62/10 counts, `!`…`~`, custom passthrough) |
| AT-TYPE-002 | Random order picks each character independently from the set; sequential order types the set in order and wraps to the start. | live | `Engine.emit()` (`randomOrder` branch, `seqIndex % chars.count`); code only |
| AT-TYPE-003 | Rate is characters per second, clamped to 1…2000; the engine emits on a 25 Hz tick, `round(rate / 25)` characters per tick, at least 1. | live | `Engine.emit()` (`perTick`), `Prefs.charsPerSecond`; code only |
| AT-TYPE-004 | A one-shot run types exactly Count characters (minimum 1) and stops; with Infinite on, or in hold mode, the run has no count limit. | live | `Engine.start(forceInfinite:)` (`remaining`), `Prefs.count`; code only |
| AT-TYPE-005 | Each character is posted as a keyDown/keyUp pair carrying the Unicode string, with all modifier flags cleared, so keyboard layout and Vietnamese input methods do not alter it and the held hotkey modifiers do not leak into the target. | live | `Typist.type(_:)`; verify --full (char-for-char at 50 and 200 chars/s; not run 2026-10-11) |
| AT-TYPE-006 | At launch, when Accessibility is granted, three zero-width-space events are posted to warm the event pipeline, because the first two key events of a process lose their Unicode payload and arrive as `a`. | live | `Typist.primePipeline()`, called from `Engine.init()`; the harness primes the same way |
| AT-TYPE-007 | Esc stops a running run at any time, including infinite runs (polled every 40 ms). | live | `Engine.tick()`; code only |
| AT-TYPE-008 | Every run stops by itself after 60 seconds, as a second brake for apps that swallow Esc. | live | `Engine.tick()` (`maxRunSeconds = 60`); code only |
| AT-TYPE-009 | AutoType never types into itself: a run refuses to start while the AutoType window is frontmost, and a running run stops if AutoType becomes frontmost. | live | `Engine.start(forceInfinite:)`, `Engine.emit()` (`isSelfFrontmost`); code only |
| AT-TYPE-010 | A run refuses to start when the character set is empty (empty custom text) or Accessibility is not granted; the refusal is logged, beeps, and shows an orange message for 6 seconds. | live | `Engine.start(forceInfinite:)`, `Engine.shout(_:)`; code only |
| AT-TYPE-011 | First-run defaults: Full keyboard set, random order on, Count 100, Infinite off, 200 chars/s. A missing setting is read as "unset", never as 0 (0 is the Letters set). | live | `Prefs.pool` (`object(forKey:)`), `Prefs.randomOrder/count/infinite/charsPerSecond`; code only |

## States and transitions
| State | Trigger | Next state | Edge case |
|---|---|---|---|
| idle | start request (from the hotkey logic, AT-KEY) | running | refused (AT-TYPE-009/010) → idle with orange message + beep |
| running | 25 Hz tick | running | AutoType becomes frontmost → idle (AT-TYPE-009) |
| running | count reached | idle | only in one-shot mode with Infinite off (AT-TYPE-004) |
| running | Esc held | idle | polled every 40 ms (AT-TYPE-007) |
| running | 60 s elapsed | idle | applies to every run, not only infinite ones (AT-TYPE-008) |
| running | hotkey released / pressed again / switch off | idle | owned by `logic/hotkey.md` (AT-KEY-003…005) |

## Fixed vs flexible
- Fixed (logic the UI must not change): Unicode posting with cleared modifiers; Esc and the 60 s cap always stop; never
  type into AutoType's own window; the 2000 chars/s ceiling.
- Flexible (UI may explore): labels and grouping of the settings, the default rate within the ≤200 exact-delivery range,
  how refusals are shown.

## Open questions
- None recorded. Above ~1000 chars/s some receiving apps drop characters (~0.7% at 2000, measured 2026-08-30); this is a
  limit of the receiver and is stated in the UI and README rather than enforced.

## Change log
- 2026-10-11: created; REQ-IDs added as trailing comments in `AutoType.swift` in the same commit (line count unchanged,
  so the README "702 lines" claim gated by `verify.sh` still holds).
