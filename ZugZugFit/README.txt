ZugZugFit 0.9.0-alpha — private account-wide movement journal

Extract this ZugZugFit folder into the chosen client's Interface/AddOns directory.
Restart WoW, enable the addon, then /zzf or /zugzug. Minimap access and a
Blizzard AddOn settings launcher are included. Check the TOC's Interface line:
Forever targets 16001; the separate Era package targets 11508/11509.

Testing: /zzf selftest checks templates, APIs, triggers, pages and dialogs and
shows a report you can copy. /zzf sample shows many sample items (nothing saved;
close the window to leave). Lists scroll with the mouse wheel.
WoW calendar: holidays, raids and invites show in the Calendar tab in local time.
New reminder kind "WoW calendar": e.g. 20 burpees 30 min before each raid. "Add to WoW
calendar" fills in Blizzard's Create Event window; you click Create (addons cannot).
Tabs: Today, Calendar, Routines, Triggers, Guild and Settings are at the top of the window.
Triggers: one page per game event (mailbox, quest, death, Hearthstone, dungeon, zone,
eating, drinking, gear, level). "Add exercise" adds a reminder to an event, "Start now"
starts them by hand. Finish a dungeon fires on a queued or Mythic+ completion, or when
you leave a 5-player dungeon after a boss kill (not on a release to the graveyard).
Challenges: Today > Send a challenge. Pick a move (or "New" for your own move),
a target and Today / 3 days / 7 days, then "Send in chat". Guildmates click the
link and Accept. A missing move is added with its name, unit and icon. Accepted
challenges show in "Goals and challenges" on Today. Guild > Challenges shows
who challenged, who took part and their progress (needs guild sharing).
Pop-up: Done logs the suggested amount in one click ("I did" - / + changes it).
"Logged!" shows Undo for 5 seconds. Snooze buttons: default, 5 min, 30 min, 1 hour.
Today: due reminders as cards (Done / Snooze / Skip; right-click Done for the form), "Done today" totals per
exercise, coming-up reminders with a "Now" button, goal bars, week strip.
Goals: a reminder can carry a goal (e.g. 10 push-ups every 20 minutes, goal 100
a day) and can stop reminding once the goal is reached. Reaching a goal shows
a "Goal reached!" banner with a fanfare (Settings can turn the sound off).
Test: "Test it" in the builder and "Test" on each reminder show the pop-up
exactly as it will look, without credit.
Share: Routines > Share in chat puts one line in your chat box. Guildmates with
ZugZugFit see a link they can click to import (Retail addon links; on other
clients use Routines > Import, which lists shares seen in chat this session).
/zzf share and /zzf import <code> do the same.
Icons: Routines > Exercises > Edit (or "New" in the builder) opens Blizzard's
macro icon lists (Spells & abilities, Items) with pages, or type an icon name.
New preset: Roast Your Nutz, 10 minutes of red light, with a daily template.
Calendar: month/week, backfill, edits, restore, future plans, optional read-only
WoW appointments. Appointment copies require confirming LOCAL time and do not
follow subsequent changes to the original appointment.
Routines: quick-start templates and a one-screen reminder builder: pick an
exercise tile, set the amount with - / +, pick how it repeats, choose time and
day chips. A sentence shows the result before you save. Goals and exercises
(custom names and icons) are on the same tab.
Guild: roster-style board with sortable columns, period tabs and your rank.
Ranked by active days (days with at least one logged exercise). Each guildmate
installs this version and opts in while online together.
Settings: reminders/UI, announcements and diagnostics.

All exercise is self-reported. Sharing sends all your daily activity aggregates
for today and the preceding 100 days to current guildmates. Sharing defaults off;
public announcements are separate and off by default. No backend. Offline peers
may retain outdated totals; withdrawals are best effort. Alts share local data.

/zzf test previews without credit; /zzf info
shows version/build information. Backfills and edits never publicly announce.
Ordinary dungeon clears use Routines' manual trigger. Hearthstone and Food/Drink
coverage is limited. Blizzard calendar writes/overlays and live links are absent.

66 offline scenarios pass. Native rendering, restart persistence and real guild
delivery still require client acceptance. No third-party addon code is bundled.
Back up SavedVariables with WoW closed before upgrading an earlier alpha.
