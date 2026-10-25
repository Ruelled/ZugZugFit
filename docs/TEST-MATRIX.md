# Verification and client acceptance

Updated for 0.9.0-alpha, 25 October 2026. Automated checks use pure Lua and an explicit WoW API mock. They make no network sends. Lua 5.4 executes the suite; Luacheck applies Lua 5.1 language/global rules. Neither is a real WoW Lua runtime.

| Area | Automated evidence (0.9.0-alpha) | Still needs a client |
|---|---|---|
| Scheduling | 14 core scenarios: dates, windows, AFK, snooze, midnight, trigger cooldown and cap, backfill, goals | Real timers, combat and AFK changes, daylight saving time |
| Model | 10 scenarios: activities, icons, routines with goals, migration, share codes, challenges | Upgrade of real SavedVariables |
| Guild | 11 scenarios: consent, exchange, corrections, withdrawal, malformed traffic, pacing | Real guild delivery and restrictions |
| Client/UI | 39 scenarios: six tabs, builder for each kind, pop-up, triggers and dungeon detection, scroll lists, sample mode, self-test, challenges, chat links, WoW calendar reading, calendar reminders, create-event fill-in | Rendering, fonts, scrolling, taint, restricted calendar actions |
| Legacy paths | 4 scenarios: old settings launcher, auras, comms, missing APIs | Era and Forever clients |
| New-user journey | 17 steps and 22 clicks by visible text: welcome, quick start, pop-ups, a trigger, the calendar, a challenge, settings. Writes `verification/journey.html` | Real mouse input, real timing, the look in the game |
| Layout | Lua controls exported to `verification/layout-review.html` | Real WoW rendering |

The in-game test suite is in [RETAIL-TEST.md](RETAIL-TEST.md). The sections below are the older Era and guild checklists.

## First Era run (about 20–30 minutes)

1. Quit the client. Back up any ZugZugFit SavedVariables. Extract the Era ZIP so `Interface/AddOns/ZugZugFit/ZugZugFit.toc` exists. Start the client; enable the addon. Record `/dump GetBuildInfo()` and `/zzf info`. Enable Lua errors using `/console scriptErrors 1` for this test.
2. Open each page through `/zzf`, the minimap and Blizzard's AddOn settings launcher. Try normal UI scale, a smaller scale and a smaller window. Inspect labels, dropdowns, scroll lists, tooltips and bottom buttons. Escape and closing a modal must leave subsequent prompts usable.
3. Add Yoga 15 minutes at a time two minutes ahead, with a daily goal. Add Push-ups every one minute with a weekday/time window that includes now. Wait for a reminder; snooze it, then log a different actual amount. Confirm exactly one log and correct progress. Dismiss the next occurrence; the rule should remain enabled with no credit for the skip.
4. Enter combat/AFK while due. Prompts should wait. Open a mailbox repeatedly with a mailbox routine enabled; only one pending prompt should exist. Test successful/cancelled Hearthstone separately. Record each supported trigger, especially consumables and dungeon completion; use manual completion for walk-in dungeons.
5. Calendar: backfill a past Gym session, edit amount and date, delete and restore. Check day/week/month/trailing-three-month totals. Future completion logs must be rejected. Add a future one-off reminder and confirm it appears only on that date. Read available WoW appointments; absence/restriction must produce a useful message, not an error. Confirm realm/local time before copying one.
6. Snooze again, `/reload`, switch characters, then fully quit/restart. Verify rules, pause/snooze settings, logs and account identity remain; no duplicate credit. Existing schema-1 users should compare totals before/after migration using their backup.
7. Leave announcements off unless intentionally testing chat. When enabled, one new completion may announce; edits/backfills must remain silent. Verify throttling and disabled destinations.

## Two guildmates (about 10–15 minutes, both consenting)

1. Install the same version, join the same guild and overlap online. Before opting in, verify no ZugZugFit addon traffic using a suitable local diagnostic if available. Both enable Guild sharing and select the same activity/unit/period.
2. A logs 10 Push-ups and B logs 20. Allow delivery (one packet/second, snapshots no more than once/minute). Both boards should show A=10, B=20 with freshness. Repeated Sync should not increase totals.
3. A corrects 10 to 15, then deletes/restores it. After each allowed update, B should show 15, 0, 15. Backfill A's prior-day log and verify period selection. Switch A to a guilded alt; it must remain one participant, not two rows.
4. A turns sharing off while B is online: B removes A after withdrawal. A re-enables: A's newer snapshot returns. Repeat with B offline to observe the explicitly best-effort limitation. Switching to another guild must default sharing off and stop the old queue.
5. Check that public chat remains silent unless separately enabled. Exercise restrictions/combat and reconnection; delivery must recover without a flood. Record any mismatched sender/realm normalization, stale roster or prefix errors.

## Forever acceptance

Repeat the relevant checklist on the exact Forever build using its package. Era success does not close this gate. Verify restricted values, supported events, native calendar access and chat return codes independently.

For each result record date, addon ZIP/hash, client version/build/interface, character realm, test action, expected/actual behavior, Lua error text and screenshot if visual. Mark PASS/FAIL/NOT TESTED; only change `in_game_validated` after recording actual acceptance evidence for that flavor.
