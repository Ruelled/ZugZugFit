# Implementation status — 0.2.0-alpha

The design below records the original product intent. Current implementation and limits are documented in [README.md](README.md), with the [development plan](docs/DEVELOPMENT-PLAN.md) and [test matrix](docs/TEST-MATRIX.md). Solo features and opt-in guild snapshot boards are implemented. Calendar appointment reads and static reminder copies are implemented; native-calendar overlays/writes and automatic appointment tracking are not. Guild periods use reported local dates, not inferred realm dates. Explicit stacking, multi-exercise sessions, retrospective goal-target editing and cross-install sync remain future work. Native client acceptance is pending.

# ZugZugFit — exercise reminders for WoW

Working name. Product specification, 25 October 2026. The solo alpha implements the scope documented in README.md; this specification also includes future work. No live client validation yet. Target: WoW Forever; interpret the dictated “Ball Forever” as that existing project context.

## Solo version

Users choose their own activity and amount. Presets: yoga, stretching, push-ups, burpees; allow custom labels and exercise variations. Track minutes and repetitions separately. Examples:

- Yoga every day at 21:00, target 15 minutes.
- Yoga at 19:00 before raid, initially a manually chosen time.
- Ten push-ups every 30 minutes on selected weekdays within a chosen play window.
- Twenty burpees every 50 minutes, or a different user-selected quantity.

Each reminder offers **Log it**, **Snooze 15 minutes**, and **Dismiss this occurrence**. Log it opens an editable actual amount (e.g. 15 minutes or 12 reps), then explicit confirmation records completion. Snooze can also offer 5/30 minutes and a custom duration. Dismiss never disables the schedule. An optional session timer must never auto-credit an exercise. Everything is on honor; no movement verification or anti-cheat.

Proposed defaults, adjustable during implementation:

- Local computer time for personal schedules; label it clearly. Calendar appointments use realm time through a separate adapter.
- Daily schedules fire once per selected date. Interval schedules count online, non-AFK time within selected days/time windows. Pause when AFK; no overnight backlog.
- After completing or dismissing an interval reminder, start its next interval. Snoozing keeps the same occurrence pending and suppresses overlapping occurrences of that reminder.
- Defer intrusive prompts during combat; show one pending prompt when safe, without a pile of catch-up alerts. Optional gentle sound and movable prompt.
- On login, offer at most one missed daily reminder from the current day; never replay all missed intervals. Persist pending snoozes across reloads; an expired snooze becomes one pending reminder when eligible.
- Snoozes may cross midnight; retain their original occurrence identity. Recheck time-window eligibility before displaying.
- Account-wide only: one set of settings, schedules, goals, history, totals, announcement preferences and participant identity across characters in the same local WoW account SavedVariables scope. No per-character profiles or leaderboards. Switching characters must not reset intervals or duplicate credit. Separate WoW accounts/installs/computers need explicit sync; do not imply Battle.net-wide cloud storage.
- Allow correcting/deleting accidental logs and backfilling offline activities, including gym visits. Keep proposed amount separate from actual amount. Manual logging without a due reminder is required.

These are proposed behavior decisions, not completed features. No OS notification while WoW is closed: an addon runs inside the client.

## Optional gameplay triggers

Adopt FitCraft-inspired behavior as original implementation, with each trigger independently enabled and mapped to a user-selected activity/workout and amount. Include death, successful hearthstone use, quest turn-in, entering a new zone, dungeon completion, equipping new gear, and level-up. Add mailbox opening and beginning in-game eating/drinking. Real-life hydration and eye breaks remain separate timed reminders. FitCraft lists dungeon completion as work in progress; its feature list is not compatibility proof for ours. [FitCraft feature reference](https://www.curseforge.com/wow/addons/fitcraft).

These are requested triggers, not confirmed Forever API capabilities. Probe each client adapter before offering it as available. A cancelled hearthstone must not count; one mailbox opening must not retrigger on each mail interaction; zone/loading events must coalesce; eating/drinking must trigger once on session start rather than every aura update. Dungeon exit does not prove a clear: use a verified completion signal where available and offer manual confirmation otherwise. Restricted or unavailable data disables that automatic trigger, with a clear explanation.

Each rule has an optional cooldown, daily prompt cap, and coalescing behavior. Default to one pending occurrence per rule, with explicit opt-in for stacking. A quest-turn-in batch or several triggers in a short span must not overwhelm the player. Triggered reminders use the same snooze/dismiss/log flow as timed reminders. Trigger firing never counts as exercise completion. Character switching preserves cooldowns and pending state.

## Announcements

Account-wide settings for optional party/guild completion and milestone announcements, inspired by FitCraft. Off by default; choose channel, completion versus milestone messages, and frequency limit. Example: “Completed 15 minutes of yoga” or “Reached 100 push-ups this week.” Only a confirmed log can produce completion credit or an announcement; test prompts and snoozes cannot. Native chat still identifies the sending character, but achievements and totals belong to the account-wide participant.

Use a deduplicated, bounded queue and respect the client's chat restrictions; do not replay stale announcements after a long delay. Backfills, edits and deletions silently update totals by default and do not replay historical milestones. An explicit share action may announce a dated backfill. Guild data syncing and public chat announcements are independent opt-ins. Nothing is sent during this planning work.

## Goals, calendar history and backfill

The calendar is part of the solo product, not postponed until guild features. Provide month/week views with a day detail list, plus text/icons so status is not conveyed by color alone:

- Planned: future scheduled activities and goal deadlines.
- Due/snoozed: outstanding reminders and their next prompt time.
- Partial/completed: actual activity against a goal, including multiple logs contributing to one goal.
- Skipped: an explicitly dismissed occurrence, with no credit.
- Not logged/goal unmet: deadline passed without enough recorded activity. This describes the record, not proof the person did no exercise.
- Unscheduled activity: logged exercise that was not attached to a plan.

Separate reminder occurrences, goals and actual activity logs. A dismissed reminder does not necessarily mean a daily goal failed: later activity can still meet that goal. Examples of explicit goals: 15 yoga minutes each day, 100 push-ups per day, or three gym visits per week. Timed yoga may generate both a plan and a goal; interval/gameplay reminders do not create an offline backlog or automatically imply missed goals when the game is closed. Future gameplay triggers cannot have exact scheduled times; show their enabled rules separately.

Backfill flow: select a past calendar day → Add activity → choose gym/yoga/custom activity → enter actual minutes, reps or sessions → optionally associate with a goal → save. Date-only entries are allowed without inventing a precise workout time. Example: on Sunday, record Friday's 45-minute gym visit even if WoW was never opened Friday. Recompute Friday and the corresponding week/month/three-month totals, not Sunday's activity total. Keep recorded-at time separate from performed-on date/time; mark manual/backfilled origin without requiring proof.

Backfill can satisfy an earlier goal. Preserve the original skipped-reminder state/history while displaying the goal's updated completion. Allow undo/edit/delete and recalculate affected totals, with no double credit. Future activities are plans, never completed backfills. Goal/schedule edits apply prospectively by default; historical targets remain intact unless explicitly edited. History and goal views must work even with no Blizzard calendar access.

## Architecture and acceptance plan

Keep scheduling and logging in pure Lua, with injected clock/storage adapters, independent from WoW frames. Suggested modules: Scheduler, TriggerRules, Activities, Goals, History, Storage, ClientAdapter, Settings, ReminderUI, CalendarView and Announcements; later BlizzardCalendarAdapter and GuildSync.

Use versioned SavedVariables for schedules, occurrence state, and completed logs. A log needs an ID, activity/variation, unit (reps/minutes/sessions), actual amount, performed-on date and optional time with time basis, recorded-at timestamp, origin (prompt/manual/backfill), revision, and optional occurrence/goal links. Keep historical goal targets and occurrence outcomes separately. Use account-level SavedVariables rather than SavedVariablesPerCharacter. Repeated button presses or a reload must not create duplicate credit. Test persistence with full logout and restart on the target client; beta persistence cannot be assumed from offline tests.

Build in this order:

1. Scheduler and log model: test daily 19:00/21:00, weekday filters, online intervals, 15-minute snooze, dismiss, duplicate confirmation, reload, AFK, midnight and daylight-saving clock changes. Decide how nonexistent/repeated local clock times behave (proposal: next valid time; once per date).
2. Solo UI: account-wide settings and prompt; activity and goal editors; reps/minutes/sessions; time/day/window editor; log/snooze/dismiss; month/week calendar with backfill/edit/delete and planned/completed/skipped/unmet states. Verify an offline Friday gym entry updates Friday and its periods exactly once; verify prospective schedule edits preserve past targets. Test modes must not affect real totals.
3. Gameplay triggers and announcements: implement supported triggers individually, test cancellation/coalescing/cooldowns across character switches, and confirm announcements deduplicate and never replay backfill milestones. Unsupported automatic detection remains disabled with a manual alternative.
4. Package for the exact Forever build using feature detection. Check timer, local/server clock, frame, sound, settings, SavedVariables and combat-state APIs in the current client source before coding adapters. Do not infer client family solely from interface-number magnitude.
5. Optional Era smoke test with its own adapter/TOC: validate UI and basic timer flow only. A modern-client test is also useful given Forever's API family. Neither substitutes for Forever acceptance.
6. When Forever is playable: verify cold-start persistence, schedule timing, combat deferral, snoozing/reload, logged totals, UI scaling and zero Lua errors. Record exact build and keep compatibility unconfirmed until then.
7. Add optional Blizzard calendar linking, then pilot guild sync with two consenting users.

## Calendar integration

Use the addon scheduler and local history as the source of truth for frequent personal reminders and goal status. The first implementation should provide an in-game ZugZugFit calendar. Investigate a companion panel/markers alongside Blizzard’s calendar as a subsequent integration; exact UI hooks and stability require client testing. Do not promise native server calendar entries for past completions or custom goal-status fields. Creating user-requested future personal events can be explored separately after permissions and limits are verified. Later let the user select an accessible raid appointment and choose an offset (e.g. yoga 30 minutes before raid). Handle changed/cancelled events and realm/local time conversion. Do not populate the guild calendar with recurring push-up events.

The Forever UI source exposes `C_Calendar.GetDayEvent`, event access and calendar time helpers. It marks some calendar data secret during chat messaging lockdown, and `AddEvent` has restrictions. This establishes source API presence, not accessible guild-calendar behavior on a running server. Disable this optional adapter gracefully when unavailable. [Calendar source](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/CalendarDocumentation.lua), [date/time source](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/DateAndTimeDocumentation.lua).

## Later: guild leaderboard

Opt-in sharing only, among guildmates running the addon. No backend needed for an initial peer-sync experiment. Source exposes addon-message prefix registration and sending through `C_ChatInfo`, with restriction checks and result codes. Queue bounded updates until permitted and handle throttling/failure; verify the GUILD channel live. [Chat API source](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua).

Rank daily, weekly, monthly, and last three months. Proposed periods: realm-calendar day, Monday-start week, calendar month, rolling three calendar months; show exact range. Keep push-up reps, burpee reps, yoga minutes and activity variations in separate boards. Do not invent a conversion equating one push-up with one minute of yoga. An optional overall board can count active days, clearly labeled.

Use one stable account-wide participant ID shared by alts, a chosen display name, unique log IDs, revisions/deletion markers and bounded payload validation. Honor-based exercise does not remove the need to prevent duplicate network packets, malformed data, or loops. Never execute received content. Publish only opted-in data; cache by guild and handle guild changes. Backfills and edits revise their original periods, with a communicated date/time policy for date-only entries; do not assign invented times to resolve personal-versus-realm-day boundaries. Show last-sync time and incomplete/offline state: peer-to-peer data is not an always-current authoritative guild database. Exercise honesty remains completely unverified by design.

## Existing addons researched

- [FitCraft](https://www.curseforge.com/wow/addons/fitcraft): closest Forever-specific alternative; listing shows 1.60.1 / version 1.2.0. Gameplay-triggered exercises, custom exercises/workouts, account/character totals, combat deferral, and a water/eye-break timer. Its public description does not establish the requested arbitrary daily schedules, snooze flow, or period-based guild leaderboard. Good comparison candidate when playable; not tested here. Listed All Rights Reserved: use as product research, not copied implementation.
- [Workout Buddy](https://www.curseforge.com/wow/addons/workout-buddy): timed/event reminders, exercise queues, character profiles and hydration. Listing covers Retail and Classic; stats are described as coming soon. No verified Forever compatibility or requested leaderboard in the reviewed description.

Recommendation: a small original solo scheduler is worthwhile if precise schedules and snoozing are the priority. Try FitCraft first if gameplay-triggered exercise already meets the need. This was a targeted search, not proof no other addon provides the full combination.

## Compatibility evidence boundary

The existing PaladinRegen project targets Forever, but that does not validate this new addon. [Forever addon kit](https://github.com/Thunderz96/forever-addon-kit) reports modern-client APIs and interface 16001 in its measured beta snapshot; it explicitly cautions that observations age across builds. Use that as a porting reference, recheck the actual target, and treat Classic Era as a partial test environment only. No server availability or launch date was independently established in this research.
