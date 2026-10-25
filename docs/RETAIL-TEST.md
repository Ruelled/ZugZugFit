# ZugZugFit in-game test suite (0.9.0-alpha)

The offline suite (`python3 verification/build.py`) uses a mock of the WoW API. It cannot show how the real client draws frames, plays sounds, sends events or handles restricted actions. This suite tests these items in the game.

## How to use this suite

1. Do the sessions in sequence. Session A must pass before the other sessions.
2. Do each test in a session from top to bottom. Each test has an ID, an action and an expected result.
3. Record each result as PASS, FAIL or SKIP in the results table at the end.
4. For each FAIL, write the ID, what you saw, and the Lua error text. Add a screenshot (Print Screen in WoW; the files go to `_retail_/Screenshots`).

Before you start:

- Type `/console scriptErrors 1` one time. WoW then shows Lua errors in a window. BugSack is also good.
- Do not test in combat unless the test tells you to.

Time: sessions A to H take about 90 minutes in total. Session I needs a second account or a guildmate. You can stop after any session and continue later.

## A. Start (5 minutes)

| ID | Do this | Expected result |
|---|---|---|
| A1 | Fully close WoW. Start it again. | Chat shows "ZugZugFit: v0.9.0-alpha ready. Zug zug!". |
| A2 | Type `/zzf selftest`. | A report window opens. The second line says "0 failed". |
| A3 | Click "Select all (then Ctrl+C)". Paste the report into a note. | The report has all lines. Send it with your results. |
| A4 | Read the INFO lines about the realm time and the WoW events. | The realm time difference is correct for your realm. Today's WoW events show. |
| A5 | Click the minimap button. | The ZugZugFit window opens on Today. |
| A6 | Right-click the minimap button. Then right-click it again. | Reminders pause, then start again. |
| A7 | Press Escape. | The ZugZugFit window closes. |

## B. Layout and scrolling (10 minutes)

| ID | Do this | Expected result |
|---|---|---|
| B1 | Type `/zzf sample`. | The subtitle shows "SAMPLE DATA" in red. |
| B2 | Put the mouse on "Today's reminders". Turn the mouse wheel. | The list moves. A thin gold bar shows at the right edge. |
| B3 | Do B2 on "Due now" and on "Goals and challenges". | Each list moves. |
| B4 | Wait 10 seconds on Today. | The scroll position stays the same after each refresh. |
| B5 | Point at the "+N more today" tile. Then click it. | A tooltip lists the other exercises. The Calendar tab opens on today. |
| B6 | Point at the "This week" box. | A tooltip lists all exercises of the week. |
| B7 | Open each of the six tabs. | No text runs out of a box. No text covers other text. No button covers another button. |
| B8 | Close the window. Open it again. | The subtitle shows the version. Your own data shows again. |
| B9 | Settings → Reminders → Window size: Small, then Large, then Normal. | The window size changes. The layout stays correct. |

## C. Timed reminders and the pop-up (15 minutes)

| ID | Do this | Expected result |
|---|---|---|
| C1 | Routines → "New reminder". Click Push-ups, "Every X min" and "15 min". | The sentence under the form says "every 15 minutes of play". |
| C2 | Click "Test it". | The pop-up shows "Test – no credit". Its buttons only close it. |
| C3 | Click "Create reminder". | The reminder shows in Routines and in "Today's reminders". |
| C4 | On Today, click "Now" on the new row. | The pop-up shows "Zug zug! Time to move.". The row stays in the list with "In Due now". |
| C5 | In the pop-up, click + one time, then Done. | "Logged!" shows with Undo. "Done today" shows 11 more reps. |
| C6 | Click Undo within 5 seconds. | The log goes away. The reminder is in "Due now" again. |
| C7 | Click the "5 min" chip next to Snooze. | The pop-up closes. After 5 minutes of play, it shows again. |
| C8 | Click Skip. | The pop-up closes. No reps are logged. |
| C9 | Make a "Daily time" reminder for 2 minutes from now. Wait. | The pop-up shows at that time, with a sound if the sound is on. |
| C10 | Make a "One date" reminder for today, 2 minutes from now. Wait. | The pop-up shows at that time. |
| C11 | Start a fight while a reminder is due. | The pop-up hides in combat. It shows again after combat. |
| C12 | Type `/afk` while a reminder is due. | The pop-up hides while you are away. "Every X min" timers stop. |
| C13 | Pause reminders. Look at Today. | "Due now" says "Reminders are paused" with Resume. Rows show "Paused". |
| C14 | Click Resume. | Daily reminders that you did not do today start. They show one after the other. |

## D. Goals and exercises (10 minutes)

| ID | Do this | Expected result |
|---|---|---|
| D1 | Edit the Push-ups reminder. Tick "Goal", set 30 a day, and tick "Stop reminding once reached". Save. | The reminder sentence adds "Goal: 30 reps a day, then stop." |
| D2 | Log Push-ups until you reach 30. | A "Goal reached!" banner shows with a fanfare. The reminder row shows "Resting". |
| D3 | Routines → Exercises → "New exercise". Name it "Test move". Open "Spells & abilities". Pick an icon. Save. | The new exercise shows with that icon in the exercise tiles. |
| D4 | Edit "Test move". Type `spell_holy_searinglight` in the icon name box. Click "Use this icon". Save. | The icon changes to the red beam. |
| D5 | On the Calendar tab, select a past day. Log a workout with "Test move". | The day shows the icon. The totals under the grid include it. |
| D6 | Edit that log. Change the amount. Then delete it. Then click Restore. | Each change shows at once in the day details and the totals. |

## E. Triggers (20 minutes)

| ID | Do this | Expected result |
|---|---|---|
| E1 | Open the Triggers tab. | Each event says "Automatic" or "Automatic: ...". |
| E2 | Click "Add exercise" on "Open the mailbox". Set "Min. minutes apart" to 0. Save. | The exercise shows under "Open the mailbox" with "On". |
| E3 | Open a mailbox. | The pop-up shows. |
| E4 | Click Done. Close the mailbox and open it again. | The pop-up shows again. |
| E5 | Add an exercise to "Turn in a quest". Turn in a quest. | The pop-up shows. |
| E6 | Add an exercise to "Use Hearthstone". Use your Hearthstone. | The pop-up shows after the cast completes. A cancelled cast does nothing. |
| E7 | Add an exercise to "Start eating". Eat food out of combat. | The pop-up shows. |
| E8 | Add an exercise to "Finish a dungeon". Do a dungeon and kill at least one boss. Leave the dungeon. | The pop-up shows one time. |
| E9 | In a dungeon, die and release to the graveyard. | No dungeon pop-up shows. |
| E10 | Click "Start now" on an event with an exercise. | Its reminders start at once. |
| E11 | Click Pause on a trigger exercise. Do the event. | No pop-up shows for that exercise. |

## F. WoW calendar (20 minutes)

| ID | Do this | Expected result |
|---|---|---|
| F1 | Open the Calendar tab. | Month cells show WoW holidays in orange, raids and dungeons in blue, and other events in green. |
| F2 | Point at a day with WoW events. | The tooltip lists each event with its local time. |
| F3 | Click a day with a WoW event. Look at the details at the right. | The event shows with its local time. If the realm time is different, the realm time shows in parentheses. |
| F4 | Compare the time with Blizzard's calendar. | The local time equals the realm time plus the difference from A4. |
| F5 | In Blizzard's calendar, make a test event for tomorrow. In ZugZugFit, click "Refresh WoW calendar". | The new event shows in ZugZugFit. |
| F6 | Click "Reminder before it" on a WoW event. | The builder opens with "One date", the event day, and a time 30 minutes before the event. |
| F7 | Make a reminder with "WoW calendar", "All my events" and "15 min". | The sentence says "15 min before all my events in the WoW calendar". |
| F8 | In Blizzard's calendar, make an event for today, 20 minutes from now. Wait 1 minute. | "Today's reminders" shows a row "... before <event name>". |
| F9 | Wait until 15 minutes before the event. | The pop-up shows with "before <event name>". |
| F10 | Decline a WoW event invite. | No reminder starts for that event. |
| F11 | Make a "One date" reminder for tomorrow. On the Calendar tab, select tomorrow. Click "Add to WoW calendar". | The ZugZugFit window closes. Blizzard's calendar opens. Chat tells you which day to right-click. |
| F12 | Right-click a different day and click "Create Event". | ZugZugFit fills in nothing. Chat names the correct day. Close that window. |
| F13 | Right-click the correct day and click "Create Event". | The title is "ZugZugFit: ...". The time is the realm time of the reminder. The description says "Planned in ZugZugFit." |
| F14 | Click Create. | The event shows in Blizzard's calendar. If WoW shows a "blocked" message, record the exact text. |
| F15 | Delete the test events in Blizzard's calendar. Click "Refresh WoW calendar" in ZugZugFit. | The events are gone from ZugZugFit. |

## G. Settings and announcements (5 minutes)

| ID | Do this | Expected result |
|---|---|---|
| G1 | Settings → Reminders. Turn the sound on. Click "Preview a reminder". | The pop-up shows with the raid-warning sound. |
| G2 | Set the default snooze to 10 minutes. Save. Click the main Snooze button on a reminder. | It comes back after 10 minutes of play. |
| G3 | Turn the minimap button off. Type `/zzf minimap`. | The button shows again near the minimap. |
| G4 | Settings → Announcements. Set "Party". Tick "Announce completed workouts". Be in a party. Log a reminder. | One line goes to party chat. A log on a past day stays silent. |
| G5 | Set "Nowhere (off)". | No more lines go to chat. |
| G6 | Settings → Diagnostics. | The trigger list and the guild status show. |

## H. Data safety (5 minutes)

| ID | Do this | Expected result |
|---|---|---|
| H1 | Type `/reload`. | All reminders, logs, goals and settings are the same. |
| H2 | Log in on an alt. | The data is the same, because ZugZugFit keeps one journal for the account. |
| H3 | Quit WoW. Start it again. | All data is the same. No log is counted two times. |
| H4 | Type `/zzf sample`. Log a workout. Close the window. | Your real data does not have that log. |

## I. Guild features (needs a second account or a guildmate)

Both players install the same version and are in the same guild.

| ID | Do this | Expected result |
|---|---|---|
| I1 | Both players: Guild tab → tick "Share my totals with this guild". | Each board shows both players after one minute. |
| I2 | Player A logs 10 push-ups. Player B clicks "Sync now". | B's board shows A's push-ups within one minute. |
| I3 | Click each column header on the board. | The board sorts by that column. "Active days" is the default. |
| I4 | Player A: Routines → "Share in chat". Send the line to guild chat. | B sees a link. |
| I5 | Player B clicks the link. Clicks Import. | B gets the reminders, and the new exercises with their icons. |
| I6 | Player A: Today → "Send a challenge" with "Test move" (D3). Send it in guild chat. | B sees a challenge link. |
| I7 | Player B clicks the link and clicks Accept. | B gets "Test move" with A's icon. The challenge shows in "Goals and challenges" on Today. |
| I8 | Both players log "Test move". Open Guild → Challenges. | The list shows who sent the challenge, who took part, and the progress of each player. |
| I9 | Player B reaches the target. | B sees "Challenge complete!". |
| I10 | Player A turns sharing off. | A goes away from B's board after the next update. |

## J. Other clients (optional)

Do sessions A, B, C, E and F with the Era package and with the Forever package. Record the results for each client in a separate table. Chat links (I4 to I7) probably do not work on Era and Forever. There, use Routines → Import, which lists shares and challenges seen in chat.

## Results

Copy this table and fill it in. Add one row for each ID.

| ID | Result | Notes |
|---|---|---|
| A1 | | |
| A2 | | |
| ... | | |

Also record the date, the client version from `/dump GetBuildInfo()`, the ZugZugFit version and the realm.
