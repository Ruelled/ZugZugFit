-- Journey test: a new user with no saved data uses ZugZugFit for one evening.
-- The test clicks only what a player can see, by the text on the control, like a person does.
-- Each step saves a picture to verification/journey.html. Mock APIs, not native rendering.
local Mock=dofile('tests/wow_mock.lua');local ZZ={};Mock.ZZ=ZZ
local R=dofile('verification/render.lua');R.install()
for _,file in ipairs({'Core','Model','Guild','Widgets','Calendar','UI','Client'}) do assert(loadfile('ZugZugFit/'..file..'.lua'))('ZugZugFit',ZZ) end
local function event(e,...) ZZ.frame.scripts.OnEvent(ZZ.frame,e,...) end
-- One second of play: the addon timer, and the timers of the pop-up and the banner, as WoW runs them.
local function play(seconds)
    for _=1,seconds do
        Mock.now=Mock.now+1;ZZ.frame.scripts.OnUpdate(ZZ.frame,1)
        for _,f in ipairs({ZZ.UI.prompt,ZZ.UI.toast}) do if f and f.shown and f.scripts.OnUpdate then f.scripts.OnUpdate(f,1) end end
    end
end
local function plain(s) return tostring(s or ''):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','') end
local steps,n={},0
local function shot(caption,note)
    local main=ZZ.UI.frame and ZZ.UI.frame:IsShown() and ZZ.UI.frame
    local prompt=ZZ.UI.prompt and ZZ.UI.prompt:IsShown() and ZZ.UI.prompt
    local toast=ZZ.UI.toast and ZZ.UI.toast:IsShown() and ZZ.UI.toast
    local html=''
    if main then html=html..'<div style="left:10px;top:20px;width:'..main.width..'px;height:'..main.height..'px">'..R.render(main,true)..'</div>' end
    if prompt then html=html..'<div style="left:230px;top:'..(main and 120 or 40)..'px;width:'..prompt.width..'px;height:'..prompt.height..'px;z-index:5">'..R.render(prompt,true)..'</div>' end
    if toast then html=html..'<div style="left:270px;top:30px;width:'..toast.width..'px;height:'..toast.height..'px;z-index:6">'..R.render(toast,true)..'</div>' end
    local chat={};for i=math.max(1,#Mock.messages-2),#Mock.messages do chat[#chat+1]=plain(Mock.messages[i]) end
    steps[#steps+1]={caption=caption,note=note or '',html=html,chat=table.concat(chat,'\n'),tall=main~=nil}
end
-- Find a visible control by its text, the way a player looks for a button.
local function visible(f) while f do if not f.shown then return false end;f=f.parent end;return true end
local function label(f)
    local t=plain(f.text)
    for _,c in pairs(f.texts or {}) do if c.shown then t=t..' '..plain(c.text) end end
    return t
end
local function find(root,text,exact)
    local best
    local function walk(f)
        if best or not f.shown then return end
        if f.scripts and f.scripts.OnClick and visible(f) then
            local l=label(f)
            if (exact and (plain(f.text)==text or l:match('^%s*'..text:gsub('%p','%%%0')..'%s*$'))) or (not exact and l:find(text,1,true)) then best=f;return end
        end
        for _,c in ipairs(f.children) do walk(c) end
    end
    walk(root);return best
end
local function click(root,text,exact)
    local b=find(root,text,exact);assert(b,'No visible control "'..text..'"')
    n=n+1;b:Click();return b
end
local function sees(root,text)
    local found=false
    local function walk(f)
        if found or not f.shown then return end
        if f.kind=='FontString' and visible(f) and plain(f.text):find(text,1,true) then found=true;return end
        if f.kind=='EditBox' and visible(f) and plain(f.text):find(text,1,true) then found=true;return end
        for _,c in ipairs(f.children) do walk(c) end
    end
    walk(root);return found
end
-- The box that shows a text: the player looks at that row and clicks a button in it.
local function row(root,text)
    local hit
    local function walk(f)
        if hit or not f.shown then return end
        if f.kind=='FontString' and visible(f) and plain(f.text):find(text,1,true) then hit=f.parent;return end
        for _,c in ipairs(f.children) do walk(c) end
    end
    walk(root);assert(hit,'No row with "'..text..'"');return hit
end
-- The tabs at the top of the window. The calendar also has a "Today" button, so tabs are found by their place.
local function tab(name) n=n+1;local t=ZZ.UI.frame.pool['tab'..name];assert(t and visible(t),'No tab '..name);t:Click() end
local function expect(root,text) assert(sees(root,text),'The player does not see "'..text..'"') end
-- 1. First login: no saved data at all.
assert(ZugZugFitDB==nil)
event('ADDON_LOADED','ZugZugFit');play(6)
assert(ZugZugFitDB and next(ZugZugFitDB.rules)==nil,'new users start empty')
local main
ZZ.minimap:Click();main=ZZ.UI.frame
expect(main,'Welcome to ZugZugFit')
-- A new user has no misses: days before the first login have no mark.
for d=1,7 do local m=(main.panels.Today.pool.weekBox.pool['d'..d].texs or {}).mark;assert(not (m and m.shown),'day '..d..' shows a mark before the first login') end
shot('First login. I click the minimap button.','A new user sees a welcome and three ways to start.')
-- 2. Quick start from the welcome card.
click(main,'Desk push-ups')
local d=ZZ.UI.modal;assert(d,'the builder opens')
expect(d,'10 reps of Push-ups every 30 minutes of play')
shot('I click the "Desk push-ups" quick start.','The builder is filled in. The sentence tells me what will happen.')
click(d,'Test it',true)
expect(ZZ.UI.prompt,'Test')
shot('I click "Test it" to see the pop-up.','The test pop-up gives no credit.')
click(ZZ.UI.prompt,'Skip',true)
click(d,'Create reminder',true)
assert(ZZ.UI.modal==nil,'the builder closes')
ZZ.UI:show('Today')
expect(main,'Push-ups · every 30 min')
shot('I click "Create reminder" and go back to Today.','The new reminder is in "Today\'s reminders".')
-- 3. Do it now from Today.
click(main,'Now',true)
expect(ZZ.UI.prompt,'Zug zug! Time to move.')
shot('I click "Now".','The pop-up asks for 10 push-ups.')
click(ZZ.UI.prompt,'Done',true)
expect(ZZ.UI.prompt,'Logged!')
shot('I click Done.','One click logs 10 reps. Undo is there for 5 seconds.')
play(6)
expect(main,'10')
shot('Five seconds later.','"Done today" shows 10 reps of push-ups.')
-- 4. Play for 30 minutes: the reminder comes by itself.
play(30*60)
expect(ZZ.UI.prompt,'Zug zug! Time to move.')
local did=ZZ.UI.prompt.pool.didplus;n=n+1;did:Click()
expect(ZZ.UI.prompt,'15')
shot('I play for 30 minutes. The pop-up comes by itself. I click + one time.','+ adds 5, so the pop-up now says 15.')
click(ZZ.UI.prompt,'Done',true);play(6)
expect(main,'25')
assert(not sees(main,'In Due now'),'a row says "In Due now"')
shot('I click Done.','Today shows 25 reps.')
-- 5. A trigger: squats each time I open the mailbox.
tab('Triggers')
expect(main,'Open the mailbox')
shot('I open the Triggers tab.','Each game event has "Add exercise".')
click(row(main,'Open the mailbox'),'Add exercise',true)
d=ZZ.UI.modal;click(d,'Squats',true)
expect(d,'After you open the mailbox')
shot('I click "Add exercise" on "Open the mailbox" and pick Squats.','The sentence says what will happen.')
click(d,'Create reminder',true)
expect(main,'15 reps of Squats')
event('MAIL_SHOW');play(1)
expect(ZZ.UI.prompt,'Squats')
shot('I open a mailbox.','The squats pop-up shows.')
click(ZZ.UI.prompt,'Done',true);play(6);event('MAIL_CLOSED')
-- 6. The calendar shows the evening.
tab('Calendar')
expect(main,'Logged: 15 reps Push-ups')
assert(not sees(main,'[prompt]') and not sees(main,'completed:'),'the day details show raw words')
shot('I open the Calendar tab.','Today has my exercise icons. The details list each log.')
-- 7. A challenge for the guild.
tab('Today')
click(main,'Send a challenge',true)
d=ZZ.UI.modal;click(d,'Burpees',true);click(d,'3 days',true)
expect(d,'ZugZugFit Challenge')
shot('I click "Send a challenge", Burpees and "3 days".','The preview shows the chat line.')
click(d,'Send in chat',true)
assert(Mock.chatOpened and Mock.chatOpened[#Mock.chatOpened]:find('ZugZugFit Challenge',1,true),'the line goes to the chat box')
expect(main,'Challenge')
shot('I click "Send in chat".','The line is in my chat box. The challenge is in "Goals and challenges".')
-- 8. Settings: the reminder sound.
tab('Settings')
-- The label is next to the box; the player clicks the box.
expect(main,'Play a sound when a reminder appears');n=n+1;ZZ.UI.frame.panels.Settings.pool.settingsBox.pool.sound:Click()
assert(ZugZugFitDB.settings.sound==true)
shot('I open Settings and turn the reminder sound on.','')
-- 9. Close and open again: the data stays.
tab('Today');main:Hide();ZZ.minimap:Click()
expect(main,'25')
shot('I close the window and open it again.','My evening is still there.')
-- Storyboard: one picture per step, newest last.
local out=io.open('verification/journey.html','w')
out:write('<!doctype html><meta charset="utf-8"><title>ZugZugFit journey: a new user</title><style>'..R.CSS:gsub('^<style>',''):gsub('</style>$','')..
    '.step{margin:0 0 28px}.step h2{font:600 16px system-ui;color:#f5cf71;margin:4px 0}.step p{margin:2px 0 8px;color:#ccc}.chat{font:12px monospace;color:#9fd5ff;white-space:pre}'..
    '.scene{display:block!important;height:auto;min-height:220px}.scene.tall{height:690px}</style>')
out:write('<p><strong>ZugZugFit journey test.</strong> A new user, clicking by the text on each control. Mock APIs; not WoW rendering.</p>')
for i,s in ipairs(steps) do
    out:write('<div class="step"><h2>'..i..'. '..s.caption..'</h2><p>'..s.note..'</p><div class="chat">'..s.chat:gsub('&','&amp;'):gsub('<','&lt;')..'</div><div class="scene'..(s.tall and ' tall' or '')..'">'..s.html..'</div></div>')
end
out:close()
print('Journey: a new user, '..#steps..' steps and '..n..' clicks passed (mock APIs, not native rendering)')
