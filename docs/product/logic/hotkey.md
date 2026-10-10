---
id: autotype-logic-hotkey
type: logic
product: autotype
title: "AutoType — Hotkey and activation (logic)"
status: active
updated: 2026-10-11
reqPrefix: AT-KEY
relations:
  specifiedBy: [autotype-ux-hotkey]
  implements: [AutoType.swift, verify.sh, tools/make-logic-test.sh]
  dependsOn: [autotype-logic-typing]
---
# AutoType — Hotkey and activation (logic)

## Purpose
- Decide when a typing run starts and stops: a global hotkey, held (hold-to-type) or pressed once (one-shot), behind a
  master on/off switch - without observing any key the user types elsewhere.
- Success signal: holding the hotkey types, releasing stops on the next 40 ms poll; a wrong combination is diagnosable
  from the log.

## Rules

Evidence notes: all code lives in `AutoType.swift`; each REQ-ID is a trailing comment on the line that implements it.
"verify §4" = the pure-logic test run by `./verify.sh` (injects `struct Hotkey`). The global hotkey and the
Accessibility grant cannot be exercised headlessly - a real held key on a granted build is needed - so rules marked
"code only" are evidenced by reading the code, not by a runtime test.

| REQ-ID | Rule (behaviour-changing) | Status (live / not built / blocked) | Evidence (code path or test) |
|---|---|---|---|
| AT-KEY-001 | With no saved hotkey, the hotkey is ⌃⌘T - deliberately without ⌥. | live | `Prefs.hotkey`; verify §4 (`⌃⌘T` displays and is set) |
| AT-KEY-002 | The hotkey counts as held only when its main key is physically down (read from the system key state, no event tap) and the live set of ⌃⌥⇧⌘ equals the saved modifiers exactly; an unset hotkey is never held. Polled every 40 ms. | live | `Hotkey.isHeld`, `Engine.init()` (0.04 s timer); verify §4 (unset never held) |
| AT-KEY-003 | Hold mode (default): while the hotkey is held a run starts with no count limit; releasing it stops the run and reports how many characters were typed. | live | `Engine.tick()` (`holdMode` branch); code only |
| AT-KEY-004 | One-shot mode: each new press (not held → held) starts a run when idle, or stops the running run. | live | `Engine.tick()` (`held && !wasHeld`); code only |
| AT-KEY-005 | The master switch (in the window and the menu bar): off means the hotkey is ignored entirely; switching off during a run stops it. The setting persists and defaults to on. | live | `Engine.armed` (`didSet`), `Prefs.armed`, `AutoTypeApp` menu-bar toggle; code only |
| AT-KEY-006 | While a new hotkey is being recorded, the hotkey never starts a run. | live | `Engine.tick()` (`guard !recording, armed`); code only |
| AT-KEY-007 | Recording a hotkey: click the field, then press a combination; at least one modifier is required, ⌥ is refused with a hint, Esc cancels, and recording cancels itself after 6 seconds or when the field disappears. It listens with a local monitor only (keys sent to the AutoType window). | live | `HotkeyField.toggle()`, `HotkeyField.end(_:)`; code only |
| AT-KEY-008 | When the hotkey's main key is down but the modifiers differ, the log records the saved and the held combination, at most about once per second. | live | `Engine.tick()` (mismatch log line); code only |
| AT-KEY-009 | Accessibility trust is re-checked about every 0.5 s (every 12th tick), so the window updates as soon as the user grants it, without a relaunch. | live | `Engine.tick()` (`permTick % 12`); code only |

## States and transitions
| State | Trigger | Next state | Edge case |
|---|---|---|---|
| armed, idle | hotkey held (hold mode) | running | refusals from AT-TYPE-009/010 keep it idle |
| armed, idle | hotkey pressed (one-shot) | running | |
| running (hold) | hotkey released | armed, idle | |
| running (one-shot) | hotkey pressed again | armed, idle | |
| any | switch off | disarmed | a run in progress stops (AT-KEY-005) |
| disarmed | switch on | armed, idle | |
| armed, idle | click the hotkey field | recording | hotkey ignored while recording (AT-KEY-006) |
| recording | valid combo / Esc / 6 s / field gone | armed, idle | ⌥ or no modifier → hint, stays recording |

## Fixed vs flexible
- Fixed (logic the UI must not change): no ⌥ in the hotkey; no global key monitoring (system key state for exactly the
  hotkey and Esc); exact modifier match; the master switch stops a running run.
- Flexible (UI may explore): the default combination (as long as it has no ⌥), how the recorder looks, wording of hints.

## Open questions
- None recorded.

## Change log
- 2026-10-11: created; REQ-IDs added as trailing comments in `AutoType.swift` in the same commit.
