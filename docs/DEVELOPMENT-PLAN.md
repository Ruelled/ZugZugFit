# Full development plan — 25 October 2026

Target: a complete private alpha for Forever and Classic Era, with source checks and offline verification before native-client acceptance. No installs or chat messages are sent during development.

## Delivery status

Implemented: all five pages, conditional routine/goal editors, stable activities and migration, read-only calendar appointments and static one-off copies, opt-in guild protocol and boards, modern/legacy adapters. Offline suites: 54 scenarios, zero lint warnings/errors. Separate deterministic Era/Forever packages are produced by the verifier. Native client rendering, persistence and two-player guild acceptance remain open; see [TEST-MATRIX.md](TEST-MATRIX.md).

Next: perform Era acceptance, fix observed client issues, then repeat on Forever. After those gates, consider automatic calendar linking/time conversion and multi-exercise workout sessions.

## Experience

- Today: due reminders, goal progress, quick activity logging, pause and a useful empty state.
- Calendar: month/week, readable status legend, day details, past-date logging, corrections/undo, future plans. Optional read-only Blizzard appointments with an explicit realm-time label.
- Routines: reusable activities and separate daily/interval/gameplay editors; named weekdays; optional goal in the creation flow; goals remain editable from the same section. Manual trigger fallback belongs here.
- Guild: opt-in, one account participant across alts, exercise/unit and period selectors, ranked rows and freshness labels; sync controls, plain-language explanation of what is shared.
- Settings: reminders/sound/snooze/UI, announcements, and separate diagnostics. Register a launcher in Blizzard AddOn settings; also provide minimap and slash access.
- Consistent Blizzard dialog textures/borders, gold headings, familiar red buttons, checkboxes and visible dropdown menus. Keep technical details out of ordinary forms.

## Model

Retain schema-1 history and migrate it transactionally to schema 2. Add stable activity IDs, preset labels, supported units, account identity, data revisions and per-guild sharing preferences. Existing exact-name history becomes linked activity records without changing totals. Log edits/deletions/restores increment revision. New goals can be created together with routines; validation must be atomic.

## Guild protocol

Versioned, bounded plain-text snapshots of the sender's own aggregated daily totals for the last 100 days. No executable deserialization, no whisper spam, no relay of other players' data. Use GUILD addon messages, prefix registration, packet fragmentation, pacing, bounded buffers, timeout and duplicate/out-of-order handling. Apply complete snapshots atomically; edits and deletions replace prior totals rather than adding deltas. Sender identity is supplied by WoW; exercise claims remain on honor. Account participant IDs unify alts, not different Battle.net accounts or computers. Guild caches and consent are separate per guild; changing guild must cancel queued traffic.

Boards: day, Monday-start week, month, trailing three calendar months, grouped by activity and unit. Date-only activity uses the member's reported local calendar date; display that policy, since inventing an epoch for an offline workout would be misleading. Show last receipt and online availability. Peers must overlap online to exchange; no central authoritative service. Withdrawal messages are best effort and cannot erase copies held by offline users.

## Compatibility references

Checked online 25 October 2026:

- FitCraft gallery: https://www.curseforge.com/wow/addons/fitcraft (visual reference only; no copied implementation/assets).
- Questie Era TOC: https://raw.githubusercontent.com/Questie/Questie/master/Questie_Vanilla.toc (11508/11509 and flavor packaging).
- AceComm: https://raw.githubusercontent.com/WoWUIDev/Ace3/master/AceComm-3.0/AceComm-3.0.lua (prefix/fragmentation/throttling reference; not vendored).
- Blizzard shared templates: https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_SharedXML/Classic/SharedUIPanelTemplates.xml
- Blizzard chat API: https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua
- Blizzard Era calendar API: https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/CalendarDocumentation.lua

## Verification

1. Core regression: schedules, weekdays/windows, AFK, DST-style clock changes, snooze/reload, duplicate logs, backfill/edit/delete/restore, goal periods and totals.
2. Migration/activity tests: old histories and pending reminders retain totals; invalid saves preserve original DB; stable activity linkage; combined routine/goal validation and retirement.
3. UX tests: all five pages, conditional fields, dropdown choices, day selection, activity creation, first-run flow, reminder actions, calendar navigation, settings persistence, Escape/close and bounded frame reuse.
4. Guild simulation: two/three peers, fragmented and reordered messages, duplicates, corrupt data, partial/timeouts, old revisions, corrections, account alts, guild changes, opt-out, traffic caps and restrictions.
5. Adapter tests: modern and legacy API paths, unknown events, restricted values, absent calendar/chat APIs, announcement policy, persistent snooze/identity and no traffic before consent.
6. Static API/source inspection, Lua 5.1 lint, syntax and deterministic package/member/hash checks for both flavors.
7. Client acceptance when available: real texture/template rendering at UI scales; Era cold restart and character switch; real trigger mapping; two guildmates syncing/correcting/withdrawing. Forever must be accepted separately.

Mock controls and any offline HTML preview are supplemental evidence, never native-client rendering or network proof.
