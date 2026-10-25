local ZZ={};for _,file in ipairs({'Core','Model','Guild'}) do assert(loadfile('ZugZugFit/'..file..'.lua'))('ZugZugFit',ZZ) end
local C,G=ZZ.Core,ZZ.Guild;local n=0
local now=100000;local day='2026-10-25'
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function test(name,fn) fn();n=n+1;print('PASS '..name) end
local function peer(name,id)
    local e=assert(C.new({},function() return {now=now,day=day,minute=1200} end));e.db.participant=id
    local out={};local env={now=function() return now end,day=function() return day end,selfName=function() return name end,guild=function() return 'Guild-Realm' end,isMember=function(sender) return sender=='Alice-Realm' or sender=='Bob-Realm' or sender=='Alt-Realm' end,blocked=function() return false end,send=function(s) out[#out+1]=s;return true end}
    local g=G.new(e,env);return e,g,out,env
end
local function log(e,amount,date) return assert(e:saveLog({activityID='push-ups',unit='reps',amount=amount,day=date or day})) end
local function deliver(g,other,sender,reverse)
    local packets={};for _,p in ipairs(g.queue) do if p.message:sub(1,2)=='D|' then packets[#packets+1]=p.message end end
    if reverse then for i=#packets,1,-1 do other:receive(packets[i],'GUILD',sender) end else for _,p in ipairs(packets) do other:receive(p,'GUILD',sender) end end
    g.queue={};return packets
end
test('No traffic or peer data before consent',function()
    local e,g,out=peer('Alice-Realm','a');log(e,10);g:tick();eq(#out,0)
    g:receive('Q|2','GUILD','Bob-Realm');eq(g.respondAt,nil)
end)
test('Two peers exchange snapshots and rank totals by period/unit',function()
    local a,ga=peer('Alice-Realm','a');local b,gb=peer('Bob-Realm','b');log(a,20);log(b,10)
    ga:setEnabled(true);gb:setEnabled(true);deliver(ga,gb,'Alice-Realm');deliver(gb,ga,'Bob-Realm')
    local rows=gb:rank('Push-ups','reps','week',day);eq(#rows,2);eq(rows[1].amount,20);eq(rows[2].amount,10)
    eq(gb:rank('Push-ups','minutes','day',day)[1].amount,0)
end)
test('Fragmented reverse order and duplicates do not double count',function()
    local a,ga=peer('Alice-Realm','a');local _,gb=peer('Bob-Realm','b')
    for i=0,20 do log(a,10,C.addDays(day,-i)) end
    ga:setEnabled(true);gb:setEnabled(true);local packets=deliver(ga,gb,'Alice-Realm',true);assert(#packets>1)
    for _,p in ipairs(packets) do gb:receive(p,'GUILD','Alice-Realm') end
    eq(gb.cache.peers.a.rows[1].amount,10);eq(#gb.cache.peers.a.rows,21)
end)
test('Corrections replace snapshots, including deletion and backfill',function()
    local a,ga=peer('Alice-Realm','a');local _,gb=peer('Bob-Realm','b');local l=log(a,20)
    ga:setEnabled(true);gb:setEnabled(true);deliver(ga,gb,'Alice-Realm')
    a:deleteLog(l.id);log(a,45,'2026-10-23');now=now+61;assert(ga:publish(true));deliver(ga,gb,'Alice-Realm')
    eq(#gb.cache.peers.a.rows,1);eq(gb.cache.peers.a.rows[1].day,'2026-10-23');eq(gb.cache.peers.a.rows[1].amount,45)
end)
test('Old revisions cannot undo newer totals',function()
    local a,ga=peer('Alice-Realm','a');local _,gb=peer('Bob-Realm','b');log(a,10)
    ga:setEnabled(true);gb:setEnabled(true);local old=deliver(ga,gb,'Alice-Realm')
    log(a,20);now=now+61;ga:publish(true);deliver(ga,gb,'Alice-Realm')
    for _,p in ipairs(old) do gb:receive(p,'GUILD','Alice-Realm') end;eq(gb.cache.peers.a.rows[1].amount,30)
end)
test('Alts share a participant; guild switch cancels pending traffic and consent',function()
    local a,ga,_,env=peer('Alice-Realm','a');local _,gb=peer('Bob-Realm','b');log(a,10)
    ga:setEnabled(true);gb:setEnabled(true);deliver(ga,gb,'Alice-Realm');now=now+61;ga:publish(true);deliver(ga,gb,'Alt-Realm');eq(#gb:rank('Push-ups','reps','day',day),2)
    env.guild=function() return 'OtherGuild-Realm' end;ga:context();eq(ga.cache.enabled,false);eq(#ga.queue,0)
end)
test('Withdrawals remove online peer totals and reject older replays',function()
    local a,ga=peer('Alice-Realm','a');local _,gb=peer('Bob-Realm','b');log(a,10)
    ga:setEnabled(true);gb:setEnabled(true);local packets=deliver(ga,gb,'Alice-Realm')
    ga:setEnabled(false);gb:receive(ga.queue[1].message,'GUILD','Alice-Realm');eq(gb.cache.peers.a,nil)
    for _,p in ipairs(packets) do gb:receive(p,'GUILD','Alice-Realm') end;eq(gb.cache.peers.a,nil)
end)
test('Sharing can resume after withdrawal with a newer revision',function()
    local a,ga=peer('Alice-Realm','a');local _,gb=peer('Bob-Realm','b');log(a,10)
    ga:setEnabled(true);gb:setEnabled(true);deliver(ga,gb,'Alice-Realm')
    ga:setEnabled(false);gb:receive(ga.queue[1].message,'GUILD','Alice-Realm');eq(gb.cache.peers.a,nil)
    now=now+61;ga:setEnabled(true);deliver(ga,gb,'Alice-Realm');eq(gb.cache.peers.a.rows[1].amount,10)
end)
test('Malformed, non-guild, outsider, partial and oversized traffic is ignored',function()
    local _,g=peer('Bob-Realm','b');g:setEnabled(true)
    for _,message in ipairs({'','D|sid|0|1|x','D|sid|1|999999|x','X|a|nan',string.rep('x',256),'D|sid|1|1|loadstring(bad)'}) do g:receive(message,'GUILD','Alice-Realm') end
    eq(next(g.cache.peers),nil)
    g:receive('D|partial|1|2|abc','GUILD','Alice-Realm');assert(g.buffers['Alice-Realm'])
    now=now+901;g:tick();eq(g.buffers['Alice-Realm'],nil)
    g:receive('D|sid|1|2|abc','WHISPER','Alice-Realm');eq(g.buffers['Alice-Realm'],nil)
    g:receive('D|sid|1|2|abc','GUILD','Outsider-Realm');eq(g.buffers['Outsider-Realm'],nil)
end)
test('Pacing, bounded retries and lockdown prevent flood',function()
    local a,g,out,env=peer('Alice-Realm','a');log(a,10);g:setEnabled(true)
    for _=1,20 do g:tick() end;eq(#out,1)
    now=now+1;env.blocked=function() return true end;g:tick();eq(#out,1)
    env.blocked=function() return false end;env.send=function() return false end
    for _=1,3 do now=now+1;g:tick() end;eq(#g.queue,0)
end)
test('Snapshot parser rejects duplicate buckets and nonfinite/negative totals',function()
    local a,g=peer('Alice-Realm','a');log(a,10);local data=g:snapshot();assert(g:parse(data))
    eq(g:parse(data..'\n'..data:match('\n(.*)$')),nil)
    eq(g:parse(data:gsub('10%.0000','-1')),nil);eq(g:parse(data:gsub('10%.0000','1e999')),nil)
end)
print('Guild scenarios: '..n..' passed')
