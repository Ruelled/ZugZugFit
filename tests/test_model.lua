local ZZ={};for _,file in ipairs({'Core','Model'}) do assert(loadfile('ZugZugFit/'..file..'.lua'))('ZugZugFit',ZZ) end
local C=ZZ.Core;local n=0
local clock={now=100000,day='2026-10-25',minute=1260}
local function fresh() return assert(C.new({},function() return clock end)) end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function test(name,fn) fn();n=n+1;print('PASS '..name) end
local function rule() return {activityID='yoga',unit='minutes',amount=15,days='1234567',kind='daily',at=1260,windowStart=0,windowEnd=1440} end
test('Activity identity links routines, goals and backfill without exact name typing',function()
    local e=fresh();local r=assert(e:saveRoutine(rule(),{amount=15,period='day'}));e:tick(1,false)
    local o=e:nextPrompt();eq(o.activityID,'yoga')
    local l=assert(e:saveLog({activityID='yoga',unit='minutes',amount=15,day=clock.day,occurrence=o.id}))
    eq(l.activityID,'yoga');eq(e:goalStatus(e.db.goals[r.goalID],clock.day),'Completed')
    e:renameActivity('yoga','Evening yoga');eq(e:total('Evening yoga','minutes',clock.day,clock.day),15);eq(e.db.rules[r.id].activity,'Evening yoga')
end)
test('Invalid optional goal does not save half a routine',function()
    local e=fresh();local result=e:saveRoutine(rule(),{amount=-1,period='day'});eq(result,nil);eq(next(e.db.rules),nil);eq(next(e.db.goals),nil)
    eq(e:saveRoutine(rule(),nil,'missing'),nil);eq(next(e.db.rules),nil)
end)
test('Schema-1 history migrates transactionally and retains totals',function()
    local old={schema=1,nextID=5,logs={l5={id='l5',activity=' yoga ',unit='minutes',amount=20,day=clock.day,revision=1,origin='manual'}},rules={},goals={},occurrences={}}
    local e=assert(C.new(old,function() return clock end));eq(e.db.schema,2);eq(old.schema,1);eq(old.logs.l5.activity,' yoga ')
    eq(e.db.logs.l5.activityID,'yoga');eq(e:total('Yoga','minutes',clock.day,clock.day),20)
    local re=assert(C.new(e.db,function() return clock end));eq(re.db.participant,e.db.participant);eq(re.db.logs.l5.amount,20)
end)
test('Bad migration retains original and invalid versions fail closed',function()
    local old={schema=1,rules='bad'};local e=C.new(old,function() return clock end);eq(e,nil);eq(old.rules,'bad');eq(old.schema,1)
    eq(C.new({schema=999},function() return clock end),nil)
end)
test('Log edits, delete, restore and rename bump snapshot revision',function()
    local e=fresh();local old=e.db.revision
    local l=e:saveLog({activityID='gym',unit='sessions',amount=1,day=clock.day});eq(e.db.revision,old+1)
    e:deleteLog(l.id);e:restoreLog(l.id);e:renameActivity('gym','Gym visit');eq(e.db.revision,old+4)
end)
test('Today groups pending, goals and upcoming',function()
    local e=fresh();local r=rule();r.at=1300;e:saveRoutine(r,{amount=15,period='day'})
    local t=e:today();eq(#t.upcoming,1);eq(#t.goals,1);eq(#t.pending,0)
    clock.minute=1300;e:tick(1,false);eq(#e:today().pending,1);clock.minute=1260
end)
test('One-off plans appear on the chosen day and never recur',function()
    local e=fresh();local r=rule();r.kind='once';r.planDay='2026-10-26';r.at=600
    local saved=assert(e:addRule(r));e:tick(1,false);eq(e:nextPrompt(),nil)
    local rows=e:dayDetails('2026-10-26');assert(rows[1].text:find('Planned'))
    clock.day='2026-10-26';clock.minute=600;e:tick(1,false);local o=e:nextPrompt();assert(o);e:dismiss(o.id)
    clock.day='2026-10-27';e:tick(1,false);eq(e:nextPrompt(),nil)
    clock.day='2026-10-25';clock.minute=1260;assert(saved)
end)
test('Reminder goal: stop at goal, edit keeps link, Now forces a prompt',function()
    local e=fresh();clock.minute=1200
    local spec={activityID='push-ups',unit='reps',amount=10,kind='interval',interval=20,days='1234567',windowStart=0,windowEnd=1440,stopAtGoal=true}
    local r=assert(e:saveRoutine(spec,{amount=30,period='day'}));assert(r.goalID);eq(r.stopAtGoal,true)
    local o=assert(e:runNow(r.id));eq(e:nextPrompt(),o);assert(e:saveLog({activityID='push-ups',unit='reps',amount=30,day=clock.day,occurrence=o.id}))
    for _=1,300 do e:tick(5,false) end;eq(e:pending(r.id),nil) -- goal reached: the interval rests for the day
    local o2=assert(e:runNow(r.id));eq(e:nextPrompt(),o2);e:dismiss(o2.id) -- an explicit Now still works
    local edited=assert(e:saveRoutine(spec,{amount=30,period='day'},r.id));eq(edited.goalID,r.goalID)
    local changed=assert(e:saveRoutine(spec,{amount=50,period='day'},edited.id));assert(changed.goalID~=r.goalID)
    eq(e:ruleGoal(changed,clock.day).id,r.goalID) -- the new target starts tomorrow
    local stopped=assert(e:saveRoutine(spec,nil,changed.id));eq(stopped.goalID,nil);eq(stopped.stopAtGoal,nil)
    e.db.settings.paused=true;local o3=assert(e:runNow(stopped.id));eq(e:nextPrompt(),o3);e.db.settings.paused=false
    clock.minute=1260
end)
test('Share codes round-trip, stay one chat line and reject damage',function()
    local e=fresh()
    local a=assert(e:saveRoutine({activityID='push-ups',unit='reps',amount=10,kind='interval',interval=20,days='12345',windowStart=1140,windowEnd=1380,stopAtGoal=true},{amount=107,period='day'}))
    local b=assert(e:addActivity('Wall sit, long','minutes',2,'Spell_Holy_Renew'))
    local c=assert(e:saveRoutine({activityID=b.id,unit='minutes',amount=2,kind='trigger',trigger='mailbox',days='1234567',windowStart=0,windowEnd=1440,cooldown=10,cap=5}))
    local text=assert(e:shareText('Week challenge',{a.id,c.id}));assert(#text<=255);assert(not text:find('|',1,true))
    local f=fresh();local n,title=f:importShare(C.findShare('hey '..text..' go!'),true);eq(n,2);eq(title,'Week challenge')
    local imported=f:findActivity('Wall sit, long');assert(imported);eq(imported.icon,'Spell_Holy_Renew')
    local goals=0;for _,g in pairs(f.db.goals) do goals=goals+1;eq(g.amount,107) end;eq(goals,1)
    for _,r in pairs(f.db.rules) do eq(r.pack,'Week challenge');if r.kind=='trigger' then eq(r.cap,5);eq(r.cooldown,10) end end
    eq(f:decodeShare('ZZ1~x~bad'),nil);eq(f:decodeShare('MB2~x~y'),nil)
    eq(e:shareText('[bad]',{a.id}),nil);eq(e:shareText('Ok',{}),nil)
    local ids={};for i=1,12 do ids[i]=assert(e:addRule({activityID='yoga',unit='minutes',amount=i,kind='daily',at=600+i,days='1234567',windowStart=0,windowEnd=1440})).id end
    eq(e:shareText('Too many',ids),nil)
end)
test('Challenges: create, encode, accept adds the move, progress, ended and damaged codes',function()
    local e=fresh();local a=assert(e:addActivity('Burpee Twist','reps',10,'Spell_Fire_Fire'))
    eq(e:createChallenge(a.id,100,3,''),nil);eq(e:createChallenge(a.id,-1,3,'Juuw'),nil);eq(e:createChallenge(a.id,10,31,'Juuw'),nil)
    local ch=assert(e:createChallenge(a.id,100,3,'Juuw'));eq(ch.finish,'2026-10-27');assert(ch.accepted and ch.mine)
    local text,code=assert(e:challengeText(ch));assert(#text<=255);eq(C.findChallenge('go '..text),code)
    local f=fresh();local d=assert(f:decodeChallenge(code));eq(d.fromName,'Juuw');eq(d.icon,'Spell_Fire_Fire')
    local seen=f:rememberChallenge(d,'Juuw-Realm');eq(seen.accepted,false);assert(seen.participants[d.by])
    assert(f:saveLog({activityID='yoga',unit='minutes',amount=5,day=clock.day}))
    local acc,added=assert(f:acceptChallenge(d.id,'Friend'));eq(added,true);local move=f:findActivity('Burpee Twist');eq(move.icon,'Spell_Fire_Fire');eq(move.unit,'reps')
    assert(f:saveLog({activityID=move.id,unit='reps',amount=60,day=clock.day}));eq(f:challengeProgress(acc),60)
    eq(f:rememberChallenge(d).accepted,true) -- seeing it again keeps our state
    eq(f:decodeChallenge('ZC1~x'),nil);eq(f:decodeChallenge(code:gsub('~r~','~q~')),nil)
    local old=C.copy(d);old.id='peer-old';old.start='2026-10-01';old.finish='2026-10-02';f:rememberChallenge(old)
    eq(f:acceptChallenge('peer-old','Friend'),nil)
    local g=assert(C.new(f.db,function() return clock end));assert(g.db.challenges[d.id]) -- persists through reload validation
    f.db.challenges.bad={id='bad'};local h=assert(C.new(f.db,function() return clock end));eq(h.db.challenges.bad,nil)
end)
print('Model scenarios: '..n..' passed')
