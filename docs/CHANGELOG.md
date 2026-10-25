# Changelog

## 0.9.0-alpha

- The first login shows a welcome card with three quick starts and "Build my own".
- The week box on Today shows no "missed" mark for days before your first login.
- The calendar day details show each finished reminder one time, as its log line. Raw words such as "completed" and "[prompt]" are gone.
- A reminder row says "Due now", not "In Due now".
- A new-user journey test clicks through the addon by visible text and writes a picture storyboard.

## 0.7.0: WoW calendar

WoW does not let addons save events to the in-game calendar. `C_Calendar.AddEvent` and `C_Calendar.UpdateEvent` are restricted functions. ZugZugFit reads the WoW calendar and helps you copy plans to it by hand.

**WoW events in ZugZugFit.** The Calendar tab shows WoW events in each day of the month grid: holidays in orange, raids and dungeons in blue, and other events in green. Point at a day to see all events with their times. The day details list each event. ZugZugFit converts realm time to your local time and shows the realm time in parentheses when it is different. "Refresh WoW calendar" reads the calendar again. ZugZugFit also reads it when WoW reports a change.

**Reminders before WoW events.** The builder has a new kind: "WoW calendar". Example: "20 burpees 30 min before raids and dungeons in the WoW calendar". Choose raids and dungeons, guild events, or all your events. Declined invites and holidays do not count. If the raid time changes in WoW, the reminder moves with it. "Today's reminders" shows one row for each matching event, and the pop-up says "before Molten Core". These reminders can be shared in chat.

**Add to WoW calendar (experiment).** On the Calendar tab, a "One date" reminder has the button "Add to WoW calendar". ZugZugFit opens Blizzard's calendar. Right-click the day and click "Create Event": ZugZugFit fills in the title, the realm time and a note. You click Create, so Blizzard's own code saves the event. ZugZugFit never calls the restricted function. This was not tested in a real client.

**Full test suite.** [docs/RETAIL-TEST.md](docs/RETAIL-TEST.md) has 82 tests in 10 sessions, each with an ID and an expected result. `/zzf selftest` now also checks the WoW calendar and shows the realm time difference.

## 0.6.4

The lists on Today use the full width of their boxes. The scroll bar shows at the right edge only when a list is longer than its box.

## 0.6.3

**No more points on the guild board.** The board ranks by active days. Active days are easy to understand and do not mix reps with minutes. The bar above the table shows on how many days of the period you moved, for example "You moved on 4 of 7 days".

## 0.6.2

**"Today's reminders" replaces "Coming up today".** The list shows every timed reminder of today, also after its time. A reminder for 08:00 stays in the list at 21:00, with its state: Due now, Done for today, Skipped today, or Paused. Before this change, a reminder disappeared from Today after its time.

**Paused is clear.** When reminders are paused, "Due now" says "Reminders are paused" and has a Resume button. Repeating reminders show "Paused" in the list. "Now" still works while reminders are paused.

When you resume, a daily reminder that you did not do today starts at once.

## 0.6.1: test tools

**Lists scroll with the mouse wheel.** ZugZugFit now has its own scroll lists. They do not use the Blizzard scroll template. A thin gold bar at the right shows the position. The list keeps its position when Today refreshes.

**Full boxes stay tidy.** With more than five exercises, the fifth "Done today" tile shows "+N more today". Point at it for the list, or click it to see today in the calendar. "This week" shows three exercises and a tooltip with all of them.

**`/zzf selftest`** checks the Blizzard templates, the APIs and the trigger events. It also opens each page and dialog. It saves nothing. The report shows in a box that you can copy.

**`/zzf sample`** shows a copy of your data with many sample items, so you can see full lists. Nothing is saved. Close the window to go back to your data.

Follow the [in-game test plan](docs/RETAIL-TEST.md).

## 0.6.0

**Triggers tab.** One page lists every game event that can start an exercise: open the mailbox, turn in a quest, die, use Hearthstone, finish a dungeon, enter a new zone, start eating, start drinking, equip gear and level up.

1. Open the Triggers tab.
2. Find the event, for example "Open the mailbox".
3. Click "Add exercise".
4. Click the exercise and set the amount.
5. Click "Create reminder".

Each event shows its exercises with Test, Pause, Edit and Archive. "Start now" starts the reminders of an event when the game does not detect it. A trigger is a normal reminder, so you can also make one in Routines with "After a game event". The old "Record a game event" button in Routines moved to "Start now" on the Triggers tab.

**Finish a dungeon works for ordinary runs.** The trigger now fires on a queued dungeon completion, on a Mythic+ completion (Retail), or when you leave a 5-player dungeon after at least one boss kill. A release to the graveyard does not count. Each dungeon run fires one time only.

## 0.5.0

**Tabs at the top.** The five tabs (Today, Calendar, Routines, Guild, Settings) are now at the top of the window. Each tab has an icon. The selected tab is taller and joins the page below it.

**Guild challenges.**

1. On Today, click "Send a challenge".
2. Click an exercise tile. Click "New" to make your own move, for example a special burpee.
3. Set the target with − / +.
4. Click the time to finish: Today, 3 days or 7 days.
5. Click "Send in chat".

ZugZugFit puts one line in your chat box, for example `[ZugZugFit Challenge: 100 reps Burpees · today]`. Press Enter to send it to guild chat. A guildmate with ZugZugFit clicks the link and clicks Accept. If the guildmate does not have the move, ZugZugFit adds it with your name, unit and icon. You take part in your own challenge.

An accepted challenge shows in "Goals and challenges" on Today with a progress bar. A "Challenge complete!" banner shows when you reach the target. If guild sharing is on, Guild → Challenges lists each challenge: who sent it, the move, the target, the end date, who took part, and the progress of each participant. Progress comes from the normal guild snapshots, so a participant must also share.

## 0.4.2

**One-click logging.** On the reminder pop-up, Done logs the suggested amount at once, with no form. If you did a different amount, use the "I did" − / + before you click Done. After Done, the pop-up shows "Logged!" with Undo for 5 seconds. Undo removes the log and puts the reminder back in Due now. Snooze is also one click: the default time, or 5 minutes, 30 minutes or 1 hour. Done on a Today card works the same way. Right-click Done on a Today card to open the full form for a different date or exercise.

**Repeating reminders stay in the list on Today.** After "Now", a reminder that repeats stays in the list and shows its state: Due now, In ~20 min, or Resting after its goal. A daily reminder shows "Done for today" or "Skipped today".

## 0.4.1

**Blizzard macro icons for exercises.** Routines → Exercises → Edit, or "New" in the reminder builder, opens an icon browser. "Suggested" has the ZugZugFit icons. "Spells & abilities" and "Items" are the same lists as the Blizzard macro icon picker, with pages of 84 icons. You can also type an icon name, for example `spell_holy_searinglight`. Shares include custom icons, so a guildmate who imports a new exercise also gets its icon. Macro icons are file IDs, so an icon can look different on another game client.

**Roast Your Nutz.** A new preset exercise: 10 minutes of red light, with a red beam icon. A quick-start template sets it once a day at 08:00. Change the time in the builder.

## 0.4.0

**Test a reminder now.** "Test it" in the builder and "Test" on each reminder show the pop-up exactly as it will look. A test gives no credit and saves nothing. On Today, "Now" starts a coming-up reminder at once. That is a real reminder: logging it counts, and it shows even when reminders are paused.

**Done today.** Today shows one tile per exercise with today's total and the number of logs. Each reminder card shows progress, for example "60 / 100 reps today".

**Goals on reminders.** In the builder, tick "Goal" to set a total, for example 10 push-ups every 20 minutes with a goal of 100 a day. "Stop reminding once reached" rests that reminder for the rest of the day or week. When a log reaches a goal, a "Goal reached!" banner appears with a fanfare. Turn the sound off in Settings. Editing a goal target starts the new target next day or week, so today's target does not move.

**Share routines in chat.**

1. Routines → Share in chat.
2. Name the routine and choose the reminders.
3. Click "Put in chat", choose a channel and press Enter.

Players without ZugZugFit see readable text. Players with ZugZugFit see a clickable "[ZugZugFit: name]" link on clients that support addon links. ZugZugFit also lists every share it sees in chat under Routines → Import. Click "Preview" there, then "Import". You can also paste a code, or type `/zzf import <code>`. Nothing changes until you press Import. Imports keep the exercise names, so everyone who imports a routine competes in the same Guild board columns.

A share must fit in one chat line (255 characters), which is about six reminders. One-off dates cannot be shared. Share codes contain only the reminder settings: no logs, no names and no history.

