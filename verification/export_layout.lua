-- Exports actual mocked frame positions to HTML; approximate styling, not native client rendering.
-- Icons load from Wowhead's public icon CDN in the browser only; nothing is fetched by this script.
local Mock=dofile('tests/wow_mock.lua');local ZZ={};Mock.ZZ=ZZ
local R=dofile('verification/render.lua');R.install()
for _,f in ipairs({'Core','Model','Guild','Widgets','Calendar','UI','Client'}) do assert(loadfile('ZugZugFit/'..f..'.lua'))('ZugZugFit',ZZ) end
ZZ.frame.scripts.OnEvent(ZZ.frame,'ADDON_LOADED','ZugZugFit')
-- Sample WoW calendar: realm time one hour behind local time.
local wowEvents={
    {d=25,ev={eventID=1,title='Molten Core',calendarType='GUILD_EVENT',eventType=0,inviteStatus=3,sequenceType='',startTime={hour=19,minute=0}}},
    {d=25,ev={eventID=2,title="Hallow's End",calendarType='HOLIDAY',eventType=4,inviteStatus=0,sequenceType='ONGOING',startTime={hour=10,minute=0}}},
    {d=27,ev={eventID=3,title='Karazhan',calendarType='PLAYER',eventType=0,inviteStatus=6,sequenceType='',startTime={hour=19,minute=30}}},
    {d=29,ev={eventID=4,title='Guild meeting',calendarType='GUILD_EVENT',eventType=3,inviteStatus=3,sequenceType='',startTime={hour=20,minute=0}}},
    {d=31,ev={eventID=5,title="Hallow's End",calendarType='HOLIDAY',eventType=4,inviteStatus=0,sequenceType='END',startTime={hour=10,minute=0}}},
    {d=21,ev={eventID=6,title='Darkmoon Faire',calendarType='HOLIDAY',eventType=4,inviteStatus=0,sequenceType='START',startTime={hour=0,minute=1}}},
}
C_DateAndTime={GetCurrentCalendarTime=function() local t=os.date('*t',time()-3600);return {year=t.year,month=t.month,monthDay=t.day,hour=t.hour,minute=t.min} end}
C_Calendar={GetMonthInfo=function(o) return {year=2026,month=10+(o or 0)} end,
    GetNumDayEvents=function(o,d) local n=0;for _,e in ipairs(wowEvents) do if o==0 and e.d==d then n=n+1 end end;return n end,
    GetDayEvent=function(o,d,i) local n=0;for _,e in ipairs(wowEvents) do if o==0 and e.d==d then n=n+1;if n==i then return e.ev end end end end}
local e=ZZ.engine;local day=ZZ.Now().day
assert(e:saveRoutine({activityID='yoga',unit='minutes',amount=15,kind='daily',at=1320,days='1234567',windowStart=0,windowEnd=1440},{amount=15,period='day'}))
assert(e:saveRoutine({activityID='push-ups',unit='reps',amount=10,kind='interval',interval=20,days='1234567',windowStart=600,windowEnd=1380,stopAtGoal=true},{amount=100,period='day'}))
assert(e:addRule({activityID='burpees',unit='reps',amount=10,kind='trigger',trigger='mailbox',days='1234567',cooldown=15,cap=20,windowStart=0,windowEnd=1440}))
assert(e:addGoal({activityID='push-ups',unit='reps',amount=100,period='week',days='1234567'}))
for _,l in ipairs({{'gym','minutes',45,-2},{'push-ups','reps',30,-1},{'yoga','minutes',15,-1},{'push-ups','reps',20,0},{'walk','minutes',30,-4},{'squats','reps',30,-4}}) do
    assert(e:saveLog({activityID=l[1],unit=l[2],amount=l[3],day=ZZ.Core.addDays(day,l[4])}))
end
e:trigger('mailbox')
ZZ.sync:setEnabled(true)
for i,p in ipairs({{'Thrallbro',{{'push-ups','reps',220},{'yoga','minutes',45},{'burpees','reps',60}},4},{'Moonfeather',{{'yoga','minutes',120},{'walk','minutes',90}},6},{'Grimbeard',{{'push-ups','reps',80}},2},{'Lysandra',{{'squats','reps',150},{'push-ups','reps',40}},3}}) do
    local rows={}
    for d=0,p[3]-1 do for _,r in ipairs(p[2]) do rows[#rows+1]={day=ZZ.Core.addDays(day,-d),activity=r[1],unit=r[2],amount=r[3]/p[3]} end end
    ZZ.sync.cache.peers['peer'..i]={name=p[1],sender='Friend-Realm',receivedAt=Mock.now-i*420,revision=1,rows=rows}
end
-- Challenges: one of ours, one accepted from Thrallbro (custom move), one open invitation.
local mine=assert(e:createChallenge('burpees',100,3,'Juuw'));mine.participants.peer1={name='Thrallbro',at=Mock.now};mine.participants.peer2={name='Moonfeather',at=Mock.now}
local twist=assert(e:decodeChallenge('ZC1~peer1-c7~peer1~Thrallbro~Burpee Twist~r~60~'..day..'~'..day..'~Spell_Fire_Fire'));e:rememberChallenge(twist);e:acceptChallenge(twist.id,'Juuw')
assert(e:saveLog({activityID=e:findActivity('Burpee Twist').id,unit='reps',amount=35,day=day}))
e:rememberChallenge(assert(e:decodeChallenge('ZC1~peer2-c3~peer2~Moonfeather~Plank~m~10~'..day..'~'..ZZ.Core.addDays(day,6)..'~')))
print([[<!doctype html><meta charset="utf-8"><title>ZugZugFit layout review</title>]]..R.CSS..[[<p><strong>ZugZugFit offline layout review.</strong> Positions, sizes, text and icons come from the Lua controls through the mock. Fonts and textures are approximate; this is not a WoW screenshot.</p><nav>]])
local screens={'Today','Calendar','Routines','Guild','Settings','New reminder','Log a workout','Share','Import','Reminder prompt','Goal toast','New exercise','Guild challenges','Send a challenge','Triggers','Sample mode','Self-test','Calendar reminder'}
for i,t in ipairs(screens) do print('<button onclick="show('..i..')">'..t..'</button>') end
print('</nav>')
for i,t in ipairs(screens) do
    local root
    if i<=5 then ZZ.UI:show(t);root=ZZ.UI.frame
    elseif i==6 then ZZ.UI:show('Routines');ZZ.UI:ruleDialog(nil,ZZ.UI.TEMPLATES[2].spec);root=ZZ.UI.frame
    elseif i==7 then ZZ.UI:show('Today');ZZ.UI:logDialog(day);root=ZZ.UI.frame
    elseif i==8 then ZZ.UI:show('Routines');ZZ.UI:shareDialog();root=ZZ.UI.frame
    elseif i==9 then
        local ids={};for id in pairs(e.db.rules) do ids[#ids+1]=id end;table.sort(ids)
        local text=e:shareText('Raid week challenge',ids);ZZ.RememberShare(ZZ.Core.findShare(text),'Thrallbro-Realm')
        ZZ.UI:show('Routines');ZZ.UI:importDialog(ZZ.Core.findShare(text));root=ZZ.UI.frame
    elseif i==10 then ZZ.UI:finish();ZZ.UI.frame:Hide();ZZ.UI:updatePrompt();root=ZZ.UI.prompt
    elseif i==12 then ZZ.UI.toast:Hide();ZZ.UI:show('Routines');ZZ.UI:activityDialog();root=ZZ.UI.frame
    elseif i==13 then ZZ.UI:finish();ZZ.UI.guildView='challenges';ZZ.UI.challengeID=mine.id;ZZ.UI:show('Guild');root=ZZ.UI.frame
    elseif i==14 then ZZ.UI.guildView='board';ZZ.UI:show('Today');ZZ.UI:challengeDialog();root=ZZ.UI.frame
    elseif i==15 then
        ZZ.UI:finish()
        for _,t in ipairs({{'mailbox','push-ups',10},{'mailbox','squats',15},{'dungeon','burpees',20},{'death','plank',1}}) do
            local sp=ZZ.UI.triggerSeed(t[1]);sp.activityID=t[2];sp.amount=t[3];if t[2]=='plank' then sp.unit='minutes' end
            local r=assert(e:addRule(sp));if t[2]=='squats' then e:setRuleEnabled(r.id,false) end
        end
        ZZ.UI:show('Triggers');root=ZZ.UI.frame
    elseif i==16 then ZZ.UI:sampleMode(true);root=ZZ.UI.frame
    elseif i==17 then ZZ.UI:sampleMode(false);ZZ.UI:selfTest();root=ZZ.UI.frame
    elseif i==18 then ZZ.UI:finish();ZZ.UI:show('Today');ZZ.UI:ruleDialog(nil,{activityID='burpees',unit='reps',amount=20,kind='calendar',calMatch='raid',lead=30});root=ZZ.UI.frame
    else local g;for _,v in pairs(e.db.goals) do if v.activityID=='push-ups' then g=v end end;ZZ.UI:celebrate(g,100);root=ZZ.UI.toast end
    print('<div class="scene'..(i==1 and ' active' or '')..'" id="s'..i..'"><div style="left:10px;top:20px;width:'..root.width..'px;height:'..root.height..'px">'..R.render(root,true)..'</div></div>')
end
print('<script>function show(n){document.querySelectorAll(".scene").forEach((e,i)=>e.classList.toggle("active",i==n-1))}</script>')
