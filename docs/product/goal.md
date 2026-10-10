---
id: autotype-goal
type: goal
product: autotype
title: "AutoType — Product goal"
status: active
updated: 2026-10-11
---
# AutoType — Product goal

## Problem
- Designers and developers on a Mac often need a lot of characters typed into a field: filling a Figma text layer with
  placeholder text, checking a font for missing glyphs, stress-testing an input, generating controlled junk data.
  Typing or pasting by hand is slow, and clipboard paste does not exercise the field the way real key input does.

## Audience
- Primary: a designer or developer on macOS 13+ (Intel or Apple Silicon) testing fonts, layouts and text inputs.
- Secondary: anyone who wants a key held down to produce a controlled stream of characters in any app.
- Who pays: nobody - the app is free and MIT licensed.

## Promise
- Hold a hotkey and characters flow into the focused field; let go and it stops at once - with nothing watched,
  nothing sent over the network, and every claim checkable in one readable Swift file.

## Success measures
| Measure | Today (observed 2026-10-11) | Target | How it is measured (command, dashboard, store data) |
|---|---|---|---|
| Release gate | 14 passed · 0 failed (`./verify.sh`, default mode) | 0 failed on every commit | `./verify.sh` (isolated HOME; `--full` adds the typing harness, which takes the foreground) |
| Character fidelity | exact char-for-char at 50 and 200 chars/s; ~0.7% dropped by the receiving app at 2000 chars/s (measured 2026-08-30, not re-run today) | exact at ≤200 chars/s | `./verify.sh --full` (two-process harness) |
| Transparency claims hold | 7 of 7 README claims match the code | 7 of 7 | `./verify.sh` section 5 |
| Shipped versions | 3 GitHub releases (v2.0, v2.1, v2.2) | each release listed in `releases.md` | `gh release list -R wblekhoa/autotype` |
| Downloads / active users | not measured | a number per release | to add: GitHub release asset download counts via `gh api` |

## Non-goals
- No observing of keys typed in other apps (no event tap, no global monitor).
- No network access, no telemetry, no auto-start at login, no background agent.
- No paid Apple Developer signing or notarization; the app is ad-hoc signed.
- No text expansion, macros or scripted sequences beyond the five character sets and custom text.

## Links
- UX: `ux/typing.md`, `ux/hotkey.md` · Logic: `logic/typing.md` (AT-TYPE), `logic/hotkey.md` (AT-KEY) ·
  Decisions: `decisions.md` · Releases: `releases.md`

## Change log
- 2026-10-11: created.
