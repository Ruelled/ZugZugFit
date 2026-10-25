local _,ZZ=...
local G={PREFIX="ZugZugFit2",MAX_PARTS=400,PART_SIZE=180,MAX_PEERS=500}
ZZ.Guild=G
local C=ZZ.Core
local function split(s,sep)
    local out={};for field in (s..sep):gmatch('(.-)'..sep) do out[#out+1]=field end;return out
end
local function encode(s) return (s:gsub('([^%w ._-])',function(ch) return string.format('%%%02X',string.byte(ch)) end)) end
local function decode(s)
    if s:find('%%[^%x]') or s:find('%%$') or s:find('%%[%x]$') then return nil end
    return (s:gsub('%%(%x%x)',function(hex) return string.char(tonumber(hex,16)) end))
end
local function safe(s,max) return type(s)=='string' and #s>0 and #s<=(max or 60) and not s:find('[%c|]') end
local function integer(n,min,max) return type(n)=='number' and n==n and n>=min and n<=max and n%1==0 end
local function count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
function G.new(engine,env)
    local self=setmetatable({engine=engine,env=env,buffers={},queue={},requests={},lastSend=0,lastPublish=-1000,lastRequest=-1000,serial=0,status='Sharing is off.'},{__index=G})
    self:context();return self
end
function G:context()
    local guild=self.env.guild()
    if guild~=self.guild then
        self.guild=guild;self.queue={};self.buffers={};self.requests={};self.lastPublished=nil;self.lastPublish=-1000
        self.joined=false;self.respondAt=nil;self.lastRequest=-1000
        if guild then
            local d=self.engine.db.guilds
            if type(d[guild])~='table' then d[guild]={enabled=false,peers={},withdrawn={}} end
            self.cache=d[guild]
            if type(self.cache.peers)~='table' then self.cache.peers={} end
            if type(self.cache.withdrawn)~='table' then self.cache.withdrawn={} end
            self.status=self.cache.enabled and 'Waiting to sync with this guild.' or 'Sharing is off for this guild.'
        else self.cache=nil;self.status='Join a guild to share totals.' end
    end
    return self.cache
end
function G:setEnabled(enabled)
    self:context();if not self.cache then return nil,'You are not in a guild.' end
    self.queue={};self.buffers={}
    if self.cache.enabled and not enabled then
        self.engine:changed()
        self.queue[1]={message='X|'..self.engine.db.participant..'|'..self.engine.db.revision,withdraw=true}
    end
    if enabled and not self.cache.enabled then self.engine:changed() end
    self.cache.enabled=enabled==true;self.joined=false
    self.status=enabled and 'Sharing enabled. Waiting for sync.' or 'Sharing off. Withdrawal is best effort for online peers.'
    if enabled then self:publish(true);self:request(true) end
    return true
end
function G:snapshot()
    local d=self.engine.db;local now=self.env.now();local day=self.env.day();local first=C.addDays(day,-100)
    local name=d.settings.displayName
    if not safe(name) then name=self.env.selfName() end
    if not safe(name) then return nil,'Set a display name before sharing.' end
    local buckets={}
    for _,l in pairs(d.logs) do if not l.deleted and l.day>=first and l.day<=day then
        local activity=C.activityKey(l.activity);local k=l.day..'|'..activity..'|'..l.unit
        local row=buckets[k] or {day=l.day,activity=activity,unit=l.unit,amount=0}
        row.amount=row.amount+l.amount;buckets[k]=row
    end end
    local keys={};for k in pairs(buckets) do keys[#keys+1]=k end;table.sort(keys)
    if #keys>2000 then return nil,'Too many daily activity categories to share (limit 2000).' end
    local rows={'2|'..d.participant..'|'..d.revision..'|'..day..'|'..now..'|'..encode(name)}
    for _,k in ipairs(keys) do
        local r=buckets[k]
        rows[#rows+1]=r.day..'|'..encode(r.activity)..'|'..r.unit..'|'..string.format('%.4f',r.amount)
    end
    local payload=table.concat(rows,'\n')
    if #payload>G.MAX_PARTS*G.PART_SIZE then return nil,'Snapshot too large; sharing paused.' end
    return payload
end
function G:publish(force)
    self:context();if not self.cache or not self.cache.enabled then return nil,'Enable guild sharing first.' end
    if #self.queue>0 then return nil,'A transfer is already queued.' end
    local now=self.env.now()
    if now-self.lastPublish<60 then return nil,'Next update is available in '..math.ceil(60-(now-self.lastPublish))..' seconds.' end
    local signature=self.engine.db.revision..':'..self.env.day()
    if not force and signature==self.lastPublished then return true end
    local payload,err=self:snapshot();if not payload then self.status=err;return nil,err end
    self.serial=self.serial+1;local sid=string.format('%x-%x',now,self.serial)
    local total=math.ceil(#payload/G.PART_SIZE)
    for i=1,total do
        self.queue[#self.queue+1]={message='D|'..sid..'|'..i..'|'..total..'|'..payload:sub((i-1)*G.PART_SIZE+1,i*G.PART_SIZE)}
    end
    self.lastPublish=now;self.lastPublished=signature;self.status='Sharing '..total..' packets with guildmates.'
    -- Late joiners learn about running challenges when a full snapshot goes out.
    if force then for _,m in ipairs(self:challengeMessages()) do self.queue[#self.queue+1]={message=m} end end
    return true
end
function G:request(force)
    self:context();if not self.cache or not self.cache.enabled then return nil,'Enable sharing first.' end
    local now=self.env.now()
    if now-self.lastRequest<120 then return nil,'Refresh is limited to once every two minutes.' end
    if not force and self.joined then return end
    self.queue[#self.queue+1]={message='Q|2'};self.lastRequest=now;self.joined=true;return true
end
function G:parse(payload)
    if type(payload)~='string' or #payload>G.MAX_PARTS*G.PART_SIZE then return nil end
    local lines=split(payload,'\n');if #lines>2001 then return nil end
    local h=split(lines[1],'|')
    if #h~=6 or h[1]~='2' or not h[2]:match('^[%w-]+$') or #h[2]>40 then return nil end
    local rev,stamp=tonumber(h[3]),tonumber(h[5]);local name=decode(h[6]);local today=self.env.day()
    if not integer(rev,1,1e12) or not C.parseDay(h[4]) or h[4]>C.addDays(today,1) or h[4]<C.addDays(today,-101)
        or not integer(stamp,0,self.env.now()+300) or not safe(name) then return nil end
    local result={id=h[2],revision=rev,day=h[4],stamp=stamp,name=name,rows={}}
    local seen={};local earliest=C.addDays(h[4],-100)
    for i=2,#lines do
        local r=split(lines[i],'|');if #r~=4 then return nil end
        local activity=decode(r[2]);local amount=tonumber(r[4])
        if not C.parseDay(r[1]) or r[1]<earliest or r[1]>h[4] or not safe(activity)
            or not ({minutes=true,reps=true,sessions=true})[r[3]] or not amount or amount~=amount or amount<=0 or amount>1e9 then return nil end
        local k=r[1]..'|'..activity..'|'..r[3];if seen[k] then return nil end;seen[k]=true
        result.rows[#result.rows+1]={day=r[1],activity=activity,unit=r[3],amount=amount}
    end
    return result
end
function G:receive(message,channel,sender)
    self:context()
    if not self.cache or not self.cache.enabled or channel~='GUILD' or not safe(sender,100) or not self.env.isMember(sender)
        or sender==self.env.selfName() or type(message)~='string' or #message>255 then return end
    local now=self.env.now()
    if message=='Q|2' then
        if not self.requests[sender] or now-self.requests[sender]>120 then
            self.requests[sender]=now;self.respondAt=now+2+(#sender%7)
        end
        return
    end
    local challenge=message:match('^C|(ZC1~.+)$')
    if challenge then
        local ch=self.engine:decodeChallenge(challenge)
        if ch and ch.finish>=C.addDays(self.env.day(),-30) and self.engine:rememberChallenge(ch,sender) then self.status='Challenge received from '..ch.fromName..'.' end
        return
    end
    local cid,pid,pname=message:match('^A|([%w-]+)|([%w-]+)|(.+)$')
    if cid then
        local ch=self.engine.db.challenges[cid];pname=decode(pname)
        if ch and #pid<=40 and safe(pname) then
            ch.participants=ch.participants or {}
            if ch.participants[pid] or count(ch.participants)<200 then ch.participants[pid]={name=pname,sender=sender,at=now} end
        end
        return
    end
    local uid,revision=message:match('^X|([%w-]+)|(%d+)$')
    if uid then
        local p=self.cache.peers[uid];revision=tonumber(revision)
        if p and p.owners and p.owners[sender] and integer(revision,1,1e12) and revision>=p.revision then
            self.cache.peers[uid]=nil;self.cache.withdrawn[uid]=revision
        end
        return
    end
    local sid,index,total,part=message:match('^D|([%w-]+)|(%d+)|(%d+)|(.*)$')
    index,total=tonumber(index),tonumber(total)
    if not sid or #sid>40 or not integer(total,1,G.MAX_PARTS) or not integer(index,1,total) or #part>G.PART_SIZE then return end
    local buffer=self.buffers[sender]
    if not buffer or buffer.sid~=sid then
        if buffer and buffer.expires>now and index~=1 then return end
        if not buffer and count(self.buffers)>=32 then return end
        buffer={sid=sid,total=total,parts={},count=0,bytes=0,expires=now+900};self.buffers[sender]=buffer
    end
    if buffer.total~=total then self.buffers[sender]=nil;return end
    if buffer.parts[index] and buffer.parts[index]~=part then self.buffers[sender]=nil;return end
    if not buffer.parts[index] then buffer.parts[index]=part;buffer.count=buffer.count+1;buffer.bytes=buffer.bytes+#part end
    if buffer.bytes>G.MAX_PARTS*G.PART_SIZE then self.buffers[sender]=nil;return end
    if buffer.count~=total then return end
    self.buffers[sender]=nil
    local p=self:parse(table.concat(buffer.parts));if not p or p.id==self.engine.db.participant then return end
    local old=self.cache.peers[p.id]
    if self.cache.withdrawn[p.id] and p.revision<=self.cache.withdrawn[p.id] then return end
    if old and (p.revision<old.revision or (p.revision==old.revision and p.stamp<=old.stamp)) then return end
    if not old and count(self.cache.peers)>=G.MAX_PEERS then return end
    p.receivedAt=now;p.sender=sender;p.owners=old and old.owners or {};p.owners[sender]=true
    self.cache.peers[p.id]=p;self.cache.withdrawn[p.id]=nil;self.status='Updated '..p.name..'.'
end
function G:tick()
    self:context();if not self.cache then return end
    local now=self.env.now()
    for sender,b in pairs(self.buffers) do if now>b.expires then self.buffers[sender]=nil end end
    for sender,t in pairs(self.requests) do if now-t>300 then self.requests[sender]=nil end end
    for id,p in pairs(self.cache.peers) do
        if type(p)~='table' or type(p.receivedAt)~='number' or now-p.receivedAt>100*86400 then self.cache.peers[id]=nil end
    end
    if self.cache.enabled then
        if not self.joined then self:request() end
        if self.respondAt and now>=self.respondAt then self.respondAt=nil;self:publish(true) else self:publish(false) end
    end
    if not self.queue[1] or now-self.lastSend<1 or self.env.blocked() then return end
    local item=self.queue[1]
    if not self.cache.enabled and not item.withdraw then self.queue={};return end
    local ok=self.env.send(item.message)
    self.lastSend=now
    if ok then
        table.remove(self.queue,1)
        if #self.queue==0 then self.status=self.cache.enabled and 'Own snapshot sent. Other members update when online.' or 'Sharing off; online peers were notified.' end
    else
        item.retries=(item.retries or 0)+1
        if item.retries>=3 then self.queue={};self.lastPublished=nil;self.status='Guild channel unavailable. Will retry later.' end
    end
end
function G:rank(activity,unit,period,day)
    self:context();local first,last=C.period(day,period);local rows={};local k=C.activityKey(activity)
    local function add(id,name,data,received,sender)
        local sum=0
        for _,r in ipairs(data) do if r.day>=first and r.day<=last and r.activity==k and r.unit==unit then sum=sum+r.amount end end
        rows[#rows+1]={id=id,name=name,amount=sum,receivedAt=received,sender=sender}
    end
    local own=self:parse(self:snapshot() or '')
    if own then add(own.id,own.name..' (you)',own.rows,self.env.now(),self.env.selfName()) end
    if self.cache and self.cache.enabled then
        for id,p in pairs(self.cache.peers) do
            if self.env.isMember(p.sender) and type(p.rows)=='table' then add(id,p.name,p.rows,p.receivedAt,p.sender) end
        end
    end
    table.sort(rows,function(a,b) return a.amount==b.amount and a.name<b.name or a.amount>b.amount end)
    local position,previous
    for i,r in ipairs(rows) do if r.amount~=previous then position=i;previous=r.amount end;r.rank=position end
    return rows,first,last
end
-- Roster-style board: active days for one period plus one column per exercise. Units never mix.
function G:board(period,day)
    self:context();local first,last=C.period(day,period);local rows,totals={},{}
    local function add(id,name,data,received,sender,mine)
        local values,days={},{}
        for _,r in ipairs(data) do if r.day>=first and r.day<=last and r.amount>0 then
            local k=r.activity..'|'..r.unit;values[k]=(values[k] or 0)+r.amount;totals[k]=(totals[k] or 0)+r.amount
            days[r.day]=days[r.day] or {};days[r.day][r.activity]=true
        end end
        rows[#rows+1]={id=id,name=name,mine=mine,values=values,days=count(days),receivedAt=received,sender=sender}
    end
    local own=self:parse(self:snapshot() or '')
    if own then add(own.id,own.name,own.rows,self.env.now(),self.env.selfName(),true) end
    if self.cache and self.cache.enabled then
        for id,p in pairs(self.cache.peers) do
            if id~=(own and own.id) and self.env.isMember(p.sender) and type(p.rows)=='table' then add(id,p.name,p.rows,p.receivedAt,p.sender,false) end
        end
    end
    local columns={}
    for k,v in pairs(totals) do local a,u=k:match('^(.*)|(%a+)$');columns[#columns+1]={key=k,activity=a,unit=u,total=v} end
    table.sort(columns,function(a,b) return a.total==b.total and a.key<b.key or a.total>b.total end)
    return rows,columns,first,last
end
function G.sortBoard(rows,key)
    local function value(r) if key=='days' then return r.days end;return r.values[key] or 0 end
    if key=='name' then table.sort(rows,function(a,b) return a.name:lower()<b.name:lower() end)
    else table.sort(rows,function(a,b) local x,y=value(a),value(b);return x==y and a.name:lower()<b.name:lower() or x>y end) end
    local position,previous
    for i,r in ipairs(rows) do
        local v=key=='name' and i or value(r)
        if v~=previous then position=i;previous=v end;r.rank=position
    end
    return rows
end
-- Challenges travel as C| (the challenge) and A| (someone took part). Both need guild sharing on.
function G:challengeMessages()
    local out,day,me={},self.env.day(),self.engine.db.participant
    for _,ch in ipairs(self.engine:challengeList(day)) do
        if #out>=20 or ch.finish<day then break end
        if ch.mine then local _,code=self.engine:challengeText(ch);if code then out[#out+1]='C|'..code end end
        if ch.accepted then
            local p=ch.participants and ch.participants[me]
            out[#out+1]='A|'..ch.id..'|'..me..'|'..encode(p and p.name or self.env.selfName())
        end
    end
    return out
end
function G:announceChallenge(ch,joined)
    self:context();if not self.cache or not self.cache.enabled then return nil,'Guild sharing is off; only the chat link was shared.' end
    if ch.mine then local _,code=self.engine:challengeText(ch);if code then self.queue[#self.queue+1]={message='C|'..code} end end
    if joined then
        local p=ch.participants[self.engine.db.participant]
        self.queue[#self.queue+1]={message='A|'..ch.id..'|'..self.engine.db.participant..'|'..encode(p and p.name or self.env.selfName())}
    end
    return true
end
-- Who took part and how far each person got. Others' progress comes from their shared daily totals.
function G:challengeBoard(ch)
    self:context();local rows={};local me=self.engine.db.participant;local k=C.activityKey(ch.activity)
    for pid,p in pairs(ch.participants or {}) do
        local row={id=pid,name=p.name,mine=pid==me,amount=0,shared=false}
        if row.mine then row.amount=self.engine:challengeProgress(ch);row.shared=true
        else
            local peer=self.cache and self.cache.peers[pid]
            if peer and type(peer.rows)=='table' then
                row.shared=true
                for _,r in ipairs(peer.rows) do if r.activity==k and r.unit==ch.unit and r.day>=ch.start and r.day<=ch.finish then row.amount=row.amount+r.amount end end
            end
        end
        row.done=row.amount>=ch.amount;rows[#rows+1]=row
    end
    table.sort(rows,function(a,b) return a.amount==b.amount and a.name<b.name or a.amount>b.amount end)
    return rows
end
