local _, ZZ = ...
local C=ZZ.Core
local baseNew=C.new
local baseRule,baseReplaceRule=C.addRule,C.replaceRule
local baseGoal,baseReplaceGoal=C.addGoal,C.replaceGoal
local baseLog,baseDelete,baseRestore=C.saveLog,C.deleteLog,C.restoreLog
local function trim(s) return type(s)=="string" and s:match("^%s*(.-)%s*$") or "" end
local function key(s) return trim(s):lower() end
local function fmtNumber(n) return string.format("%g",n) end
C.activityKey=key
C.presets={
    {id="yoga",name="Yoga",unit="minutes",amount=15},
    {id="stretching",name="Stretching",unit="minutes",amount=5},
    {id="push-ups",name="Push-ups",unit="reps",amount=10},
    {id="burpees",name="Burpees",unit="reps",amount=10},
    {id="gym",name="Gym",unit="sessions",amount=1},
    {id="water",name="Water break",unit="sessions",amount=1},
    {id="eyes",name="Eye break",unit="sessions",amount=1},
    {id="squats",name="Squats",unit="reps",amount=15},
    {id="plank",name="Plank",unit="minutes",amount=1},
    {id="walk",name="Walk",unit="minutes",amount=10},
    {id="roast-your-nutz",name="Roast Your Nutz",unit="minutes",amount=10},
}
-- Classic-era icon names so the same artwork resolves on Era, Forever and Retail clients.
C.presetIcons={yoga="Spell_Nature_Tranquility",stretching="Spell_Holy_Renew",["push-ups"]="Spell_Nature_Strength",
    burpees="Ability_Warrior_Charge",gym="Ability_Warrior_InnerRage",water="INV_Drink_07",eyes="Spell_Holy_MindVision",
    squats="Ability_Warrior_Sunder",plank="Ability_Warrior_ShieldWall",walk="Ability_Rogue_Sprint",
    ["roast-your-nutz"]="Spell_Holy_SearingLight"}
C.iconChoices={"Spell_Nature_Tranquility","Spell_Holy_Renew","Ability_Warrior_Revenge","Ability_Warrior_Charge",
    "Ability_Warrior_InnerRage","Ability_Warrior_Sunder","Ability_Warrior_ShieldWall","Ability_Rogue_Sprint",
    "INV_Drink_07","Spell_Holy_MindVision","Spell_Nature_Strength","Spell_Holy_PowerWordShield",
    "Spell_Nature_Rejuvenation","Spell_Shadow_Teleport","INV_Misc_Food_15","Spell_Holy_SearingLight","INV_Misc_QuestionMark"}
-- An icon is a texture name in Interface\\Icons or a numeric file ID from Blizzard's macro icon list.
local function validIcon(icon)
    if type(icon)=="number" then return icon>=1 and icon<2^31 and icon%1==0 end
    return type(icon)=="string" and #icon<=60 and icon:match("^[%w_]+$")~=nil
end
C.validIcon=validIcon
function C.iconPath(icon)
    if type(icon)=="number" then return icon end
    return "Interface\\Icons\\"..(validIcon(icon) and icon or "INV_Misc_QuestionMark")
end
function C.iconFor(a)
    return C.iconPath(a and (validIcon(a.icon) and a.icon or C.presetIcons[a.id]) or nil)
end
local function validName(name)
    return #name>0 and #name<=60 and not name:find("[%c|]")
end
function C:findActivity(name)
    if self.db.activities[name] then return self.db.activities[name] end
    for _,a in pairs(self.db.activities) do if key(a.name)==key(name) then return a end end
end
function C:addActivity(name,unit,amount,icon)
    name=trim(name)
    if not validName(name) or not ({minutes=true,reps=true,sessions=true})[unit] then return nil,"Choose a name (1–60 characters) and a unit." end
    amount=tonumber(amount)
    if not amount or amount~=amount or amount<=0 or amount>100000 then return nil,"Enter a positive suggested amount." end
    local existing=self:findActivity(name)
    if existing then return existing end
    local id=self:id("a");local a={id=id,name=name,unit=unit,amount=amount,icon=validIcon(icon) and icon or nil}
    self.db.activities[id]=a;return a
end
function C:renameActivity(id,name,icon)
    name=trim(name)
    local a=self.db.activities[id];if not a or not validName(name) then return nil,"Enter a valid activity name." end
    local other=self:findActivity(name)
    if other and other.id~=id then return nil,"That activity already exists." end
    a.name=name;if validIcon(icon) then a.icon=icon end
    for _,collection in ipairs({"rules","goals","logs","occurrences"}) do
        for _,r in pairs(self.db[collection]) do if r.activityID==id then r.activity=name end end
    end
    self:changed();return true
end
function C:activityList()
    local list={};for _,a in pairs(self.db.activities) do list[#list+1]=a end
    table.sort(list,function(a,b) return a.name<b.name end);return list
end
function C:changed() self.db.revision=(self.db.revision or 0)+1 end
function C:prepare(spec)
    local out=C.copy(spec)
    local a=out.activityID and self.db.activities[out.activityID] or self:findActivity(out.activity or "")
    if out.activityID and not a then return nil,"Choose an existing activity." end
    if not a then
        local err;a,err=self:addActivity(out.activity,out.unit,out.amount);if not a then return nil,err end
    end
    out.activityID=a.id;out.activity=a.name;return out
end
function C.new(db,clock)
    if type(db)=="table" and db.schema and db.schema~=1 and db.schema~=2 then return nil,"Unsupported saved-data version; original data retained." end
    local candidate=C.copy(type(db)=="table" and db or {})
    candidate.schema=1
    local self,err=baseNew(candidate,clock);if not self then return nil,err end
    local d=self.db
    if d.activities~=nil and type(d.activities)~="table" then return nil,"Invalid activity catalog; original data retained." end
    d.activities=d.activities or {}
    for id,a in pairs(d.activities) do
        if type(a)~="table" or type(a.name)~="string" or not validName(a.name) or a.id~=id
            or not ({reps=true,minutes=true,sessions=true})[a.unit] or type(a.amount)~="number" or a.amount<=0 or a.amount>100000 or a.amount~=a.amount then
            return nil,"Invalid activity catalog; original data retained."
        end
        if a.icon~=nil and not validIcon(a.icon) then a.icon=nil end -- Cosmetic only; never block history.
    end
    for _,p in ipairs(C.presets) do if not self:findActivity(p.name) then d.activities[p.id]=C.copy(p) end end
    for _,collection in ipairs({"rules","goals","logs","occurrences"}) do
        for _,r in pairs(d[collection]) do
            local a=r.activityID and d.activities[r.activityID] or self:findActivity(r.activity)
            if not a then a=self:addActivity(r.activity,r.unit,r.amount) end
            if not a then return nil,"Activity migration failed; original data retained." end
            r.activityID=a.id;r.activity=a.name
        end
    end
    d.schema=2
    d.revision=type(d.revision)=="number" and d.revision>=1 and d.revision<1e12 and math.floor(d.revision) or 1
    d.participant=d.participant or string.format("%x-%x",clock().now,math.random(1,2147483646))
    if type(d.participant)~="string" or #d.participant>40 or not d.participant:match("^[%w-]+$") then return nil,"Invalid participant identity." end
    if d.guilds~=nil and type(d.guilds)~="table" then return nil,"Invalid guild cache." end
    d.guilds=d.guilds or {}
    if d.challenges~=nil and type(d.challenges)~="table" then return nil,"Invalid challenge list; original data retained." end
    d.challenges=d.challenges or {}
    -- Challenges are social extras: drop a damaged entry instead of blocking the journal.
    for id,ch in pairs(d.challenges) do if not C.validChallenge(ch) or ch.id~=id then d.challenges[id]=nil end end
    d.settings.snooze=tonumber(d.settings.snooze) or 15
    if d.settings.snooze<1 or d.settings.snooze>1440 then d.settings.snooze=15 end
    d.settings.minimap=d.settings.minimap~=false
    d.settings.scale=tonumber(d.settings.scale) or 1
    if d.settings.scale<0.65 or d.settings.scale>1.4 then d.settings.scale=1 end
    return self
end
function C:addRule(spec)
    local p,err=self:prepare(spec);if not p then return nil,err end
    return baseRule(self,p)
end
function C:replaceRule(id,spec)
    local p,err=self:prepare(spec);if not p then return nil,err end
    return baseReplaceRule(self,id,p)
end
function C:addGoal(spec)
    local p,err=self:prepare(spec);if not p then return nil,err end
    return baseGoal(self,p)
end
function C:replaceGoal(id,spec)
    local p,err=self:prepare(spec);if not p then return nil,err end
    return baseReplaceGoal(self,id,p)
end
-- The goal that applies to a reminder today: an edited goal starts next period, so fall back to its predecessor.
function C:ruleGoal(r,day)
    local g=r and r.goalID and self.db.goals[r.goalID]
    if g and g.start>day and g.prev then g=self.db.goals[g.prev] or g end
    if g and g.start<=day and (not g.finish or day<=g.finish) then return g end
end
function C:saveRoutine(spec,goalSpec,id)
    -- Validate before either mutation: a bad optional goal cannot leave half a routine.
    local p,err=self:prepare(spec);if not p then return nil,err end
    local ok;ok,err=self:validateRule(p);if not ok then return nil,err end
    local old=id and self.db.rules[id]
    if id and not old then return nil,"Reminder no longer exists." end
    local gp
    if goalSpec then
        gp={activity=p.activity,activityID=p.activityID,unit=p.unit,amount=goalSpec.amount,period=goalSpec.period,days=p.days}
        ok,err=self:validateGoal(gp);if not ok then return nil,err end
    end
    p.goalID=nil;p.stopAtGoal=(gp and p.stopAtGoal==true) or nil
    local r;if id then r,err=self:replaceRule(id,p) else r,err=self:addRule(p) end
    if not r then return nil,err end
    local today=self.clock().day
    local current=old and old.goalID and self.db.goals[old.goalID]
    if current and current.finish and current.finish<today then current=nil end
    if gp then
        local g=current
        if not g then g=self:addGoal(gp)
        elseif g.amount~=gp.amount or g.period~=gp.period or g.unit~=gp.unit or g.activityID~=gp.activityID or g.days~=gp.days then
            -- Edits begin next period; today's target and history stay as they were.
            local previous=g.id;g=self:replaceGoal(g.id,gp);g.prev=previous
        end
        r.goalID=g.id
    elseif current then self:stopGoal(current.id) end
    return r
end
-- A reminder with "stop at goal" rests once its goal is complete for the current period.
local baseEligible=C.eligible
function C:eligible(r,c)
    if not baseEligible(self,r,c) then return false end
    if r.stopAtGoal then
        local g=self:ruleGoal(r,c.day)
        if g and self:goalStatus(g,c.day)=="Completed" then return false end
    end
    return true
end
-- "Now": make a real reminder due immediately, even outside its window or before its time.
function C:runNow(id)
    local r=self.db.rules[id];local c=self.clock()
    if not r or r.retired or not r.enabled then return nil,"Turn this reminder on first." end
    local o=self:pending(id)
    if o then o.due=c.now;o.forced=true;return o end
    if (r.kind=="daily" or r.kind=="once") and self.db.occurrences[r.id..":"..c.day] then return nil,"This reminder is already done for today." end
    o=self:makeOccurrence(r,c);if not o then return nil,"This reminder is already waiting." end
    o.forced=true;r.elapsed=0;return o
end
function C:nextPrompt()
    local c=self.clock();local result;local paused=self.db.settings.paused
    for _,o in pairs(self.db.occurrences) do
        local r=self.db.rules[o.rule]
        if o.status=="pending" and o.due<=c.now and r and ((not paused and self:eligible(r,c)) or (o.forced and o.day==c.day and not r.retired)) then
            if not result or o.due<result.due or (o.due==result.due and o.id<result.id) then result=o end
        end
    end
    return result
end
-- Undo a quick log: remove it and, for today's reminder, put that reminder back in Due now.
function C:undoLog(id)
    local l=self.db.logs[id];if not l or l.deleted then return nil,"Nothing to undo." end
    self:deleteLog(id)
    local o=l.occurrence and self.db.occurrences[l.occurrence];local c=self.clock()
    if o and o.status=="completed" and o.log==id and o.day==c.day then o.status="pending";o.log=nil;o.due=c.now end
    return true
end
-- Share codes: one chat line, readable by people without the addon, no pipes or brackets.
C.SHARE_MAX=255
local UNIT_CODE,CODE_UNIT={reps="r",minutes="m",sessions="s"},{r="reps",m="minutes",s="sessions"}
local KIND_CODE,CODE_KIND={daily="d",interval="i",trigger="t",calendar="c"},{d="daily",i="interval",t="trigger",c="calendar"}
local function esc(v) return (tostring(v):gsub("[^%w .-]",function(ch) return string.format("%%%02X",ch:byte()) end)) end
local function unesc(v) return (v:gsub("%%(%x%x)",function(h) return string.char(tonumber(h,16)) end)) end
local function split(s,sep) local out={};for part in (s..sep):gmatch("(.-)%"..sep) do out[#out+1]=part end;return out end
function C:encodeRule(r)
    local a=self.db.activities[r.activityID];local g=self:ruleGoal(r,self.clock().day)
    local param=r.kind=="daily" and r.at or r.kind=="interval" and r.interval or r.kind=="calendar" and (r.calMatch.."-"..r.lead) or r.trigger
    -- Defaults cost nothing: every day, the whole day, and preset icons the receiver already knows.
    local icon=a and a.icon or ""
    if C.presetIcons[r.activityID] and (icon=="" or icon==C.presetIcons[r.activityID]) then icon="" end
    local window=(r.windowStart==0 and r.windowEnd==1440) and "" or (r.windowStart.."-"..r.windowEnd)
    return table.concat({esc(r.activity),UNIT_CODE[r.unit],fmtNumber(r.amount),KIND_CODE[r.kind],tostring(param),r.days=="1234567" and "" or r.days,window,
        r.kind=="trigger" and r.cooldown or "",r.kind=="trigger" and r.cap or "",g and (fmtNumber(g.amount)..(g.period=="week" and "w" or "d")) or "",
        r.stopAtGoal and "1" or "",icon},",")
end
function C:shareText(title,ids)
    title=trim(title or "")
    if not validName(title) or title:find("[%[%]{}~]") then return nil,"Give the share a name (no brackets)." end
    local parts={}
    for _,id in ipairs(ids) do
        local r=self.db.rules[id]
        if r and not r.retired and KIND_CODE[r.kind] then parts[#parts+1]=self:encodeRule(r) end
    end
    if #parts==0 then return nil,"Choose at least one repeating reminder. One-off dates cannot be shared." end
    local text="[ZugZugFit: "..title.."] {ZZ1~"..esc(title).."~"..table.concat(parts,";").."}"
    if #text>C.SHARE_MAX then return nil,"Too long for one chat line ("..#text.."/"..C.SHARE_MAX.."). Choose fewer reminders or a shorter name." end
    return text
end
function C.findShare(text)
    if type(text)~="string" then return end
    return text:match("{(ZZ1~[^}]+)}") or text:match("^%s*(ZZ1~[^%s}]+)%s*$")
end
-- Decode and validate without saving anything.
function C:decodeShare(code)
    if type(code)~="string" or #code>C.SHARE_MAX then return nil,"This is not a ZugZugFit share code." end
    local head=split(code,"~")
    if #head~=3 or head[1]~="ZZ1" then return nil,"This is not a ZugZugFit share code." end
    local title=unesc(head[2]);if not validName(title) then return nil,"The share has an invalid name." end
    local rules={}
    for _,item in ipairs(split(head[3],";")) do
        local f=split(item,",")
        if #f~=12 then return nil,"The share code is damaged." end
        local kind=CODE_KIND[f[4]];local window=f[7]=="" and {"0","1440"} or split(f[7],"-")
        local spec={activity=unesc(f[1]),unit=CODE_UNIT[f[2]],amount=tonumber(f[3]),kind=kind,days=f[6]=="" and "1234567" or f[6],
            windowStart=tonumber(window[1]),windowEnd=tonumber(window[2]),cooldown=tonumber(f[8]),cap=tonumber(f[9]),stopAtGoal=f[11]=="1" or nil,
            icon=f[12]~="" and (tonumber(f[12]) or f[12]) or nil}
        if kind=="daily" then spec.at=tonumber(f[5]) elseif kind=="interval" then spec.interval=tonumber(f[5])
        elseif kind=="calendar" then local m,l=f[5]:match("^(%a+)%-(%d+)$");spec.calMatch=m;spec.lead=tonumber(l)
        else spec.trigger=f[5] end
        local amount,period=f[10]:match("^([%d.]+)([dw])$")
        if amount then spec.goal={amount=tonumber(amount),period=period=="w" and "week" or "day"} end
        if not validName(spec.activity) or not spec.unit or not kind then return nil,"The share code is damaged." end
        local ok,err=self:validateRule(spec);if not ok then return nil,"A reminder in this share is invalid: "..err end
        rules[#rules+1]=spec
    end
    if #rules==0 or #rules>20 then return nil,"The share code is damaged." end
    return {title=title,rules=rules}
end
function C:importShare(code,withGoals)
    local share,err=self:decodeShare(code);if not share then return nil,err end
    local saved=0
    for _,spec in ipairs(share.rules) do
        local isNew=not self:findActivity(spec.activity)
        local s=C.copy(spec);s.goal=nil;s.icon=nil;s.pack=share.title;if not withGoals then s.stopAtGoal=nil end
        local r;r,err=self:saveRoutine(s,withGoals and spec.goal or nil)
        if not r then return nil,err,saved end
        local a=self.db.activities[r.activityID]
        if isNew and a and validIcon(spec.icon) then a.icon=spec.icon end
        saved=saved+1
    end
    return saved,share.title
end
function C:saveLog(spec,id)
    local p,err=self:prepare(spec);if not p then return nil,err end
    local l;l,err=baseLog(self,p,id)
    if l then l.activityID=p.activityID;self:changed() end
    return l,err
end
function C:deleteLog(id) local ok=baseDelete(self,id);if ok then self:changed() end;return ok end
function C:restoreLog(id) local ok=baseRestore(self,id);if ok then self:changed() end;return ok end
function C:total(activity,unit,first,last)
    local a=self:findActivity(activity);local sum=0
    for _,l in pairs(self.db.logs) do
        if not l.deleted and l.unit==unit and l.day>=first and l.day<=last and
            ((a and l.activityID==a.id) or (not a and key(l.activity)==key(activity))) then sum=sum+l.amount end
    end
    return sum
end
function C:today()
    local c=self.clock();local result={pending={},goals={},upcoming={}}
    for _,o in pairs(self.db.occurrences) do
        local r=self.db.rules[o.rule]
        if o.status=="pending" and r and r.enabled and not r.retired then result.pending[#result.pending+1]=o end
    end
    table.sort(result.pending,function(a,b) return a.due==b.due and a.id<b.id or a.due<b.due end)
    for _,g in pairs(self.db.goals) do
        local status,value=self:goalStatus(g,c.day)
        if status then result.goals[#result.goals+1]={goal=g,status=status,value=value} end
    end
    table.sort(result.goals,function(a,b) return a.goal.activity<b.goal.activity end)
    for _,r in pairs(self.db.rules) do
        if r.enabled and not r.retired and r.kind=="daily" and r.days:find(tostring(C.weekday(c.day)),1,true) and r.at>c.minute then result.upcoming[#result.upcoming+1]=r end
    end
    table.sort(result.upcoming,function(a,b) return a.at<b.at end)
    return result
end
-- CHALLENGES: one move, one target, one window of days. Anyone can accept; progress is honor-based.
local UNITS={reps=true,minutes=true,sessions=true}
function C.validChallenge(ch)
    return type(ch)=="table" and type(ch.id)=="string" and #ch.id<=60 and ch.id:match("^[%w-]+$")~=nil
        and type(ch.by)=="string" and #ch.by<=40 and ch.by:match("^[%w-]+$")~=nil
        and type(ch.fromName)=="string" and validName(ch.fromName) and type(ch.activity)=="string" and validName(ch.activity)
        and UNITS[ch.unit] and type(ch.amount)=="number" and ch.amount>0 and ch.amount<=100000
        and C.parseDay(ch.start)~=nil and C.parseDay(ch.finish)~=nil and ch.finish>=ch.start and C.addDays(ch.start,30)>=ch.finish
        and (ch.icon==nil or validIcon(ch.icon)) and (ch.participants==nil or type(ch.participants)=="table")
end
function C:createChallenge(activityID,amount,days,fromName)
    local a=self.db.activities[activityID];amount=tonumber(amount);days=tonumber(days)
    if not a then return nil,"Choose an exercise." end
    if not amount or amount<=0 or amount>100000 then return nil,"Enter a positive target." end
    if not days or days<1 or days>30 or days%1~=0 then return nil,"Choose 1–30 days." end
    if not validName(fromName or "") then return nil,"Set a display name in Settings first." end
    local c=self.clock()
    local ch={id=self.db.participant.."-"..self:id("c"),by=self.db.participant,fromName=fromName,activity=a.name,activityID=a.id,unit=a.unit,
        amount=amount,start=c.day,finish=C.addDays(c.day,days-1),icon=a.icon or C.presetIcons[a.id],created=c.now,mine=true,accepted=true,
        participants={[self.db.participant]={name=fromName,at=c.now}}}
    self.db.challenges[ch.id]=ch;self:changed();return ch
end
local function plain(v) return (tostring(v):gsub("[%[%]{}|]","")) end
function C.challengeLabel(ch)
    local window=ch.start==ch.finish and "today" or ("until "..ch.finish:sub(6))
    return fmtNumber(ch.amount).." "..ch.unit.." "..plain(ch.activity).." · "..window
end
function C:challengeText(ch)
    local code=table.concat({"ZC1",ch.id,ch.by,esc(ch.fromName),esc(ch.activity),UNIT_CODE[ch.unit],fmtNumber(ch.amount),ch.start,ch.finish,ch.icon and tostring(ch.icon) or ""},"~")
    local text="[ZugZugFit Challenge: "..C.challengeLabel(ch).."] {"..code.."}"
    if #text>C.SHARE_MAX then return nil,"This challenge is too long for one chat line. Use a shorter exercise name." end
    return text,code
end
function C.findChallenge(text) return type(text)=="string" and (text:match("{(ZC1~[^}]+)}") or text:match("^%s*(ZC1~[^%s}]+)%s*$")) or nil end
function C:decodeChallenge(code)
    if type(code)~="string" or #code>C.SHARE_MAX then return nil,"This is not a ZugZugFit challenge." end
    local f=split(code,"~")
    if #f~=10 or f[1]~="ZC1" then return nil,"This is not a ZugZugFit challenge." end
    local ch={id=f[2],by=f[3],fromName=unesc(f[4]),activity=unesc(f[5]),unit=CODE_UNIT[f[6]],amount=tonumber(f[7]),start=f[8],finish=f[9],
        icon=f[10]~="" and (tonumber(f[10]) or f[10]) or nil}
    if not C.validChallenge(ch) then return nil,"The challenge is damaged." end
    return ch
end
-- Keep a challenge seen in chat or from the guild; never overwrite our own accepted state.
function C:rememberChallenge(ch,sender)
    local old=self.db.challenges[ch.id]
    if old then return old end
    local n=0;for _ in pairs(self.db.challenges) do n=n+1 end
    if n>=200 then
        local oldest;for _,v in pairs(self.db.challenges) do if not v.mine and not v.accepted and (not oldest or v.finish<oldest.finish) then oldest=v end end
        if not oldest then return nil end;self.db.challenges[oldest.id]=nil
    end
    local copy=C.copy(ch);copy.accepted=false;copy.mine=nil;copy.seenFrom=sender;copy.seenAt=self.clock().now
    copy.participants={[ch.by]={name=ch.fromName,at=copy.seenAt}}
    self.db.challenges[ch.id]=copy;return copy
end
-- Accepting adds the move to your exercises when you do not have it, with the challenger's icon.
function C:acceptChallenge(id,selfName)
    local ch=self.db.challenges[id];local c=self.clock()
    if not ch then return nil,"Challenge not found." end
    if ch.finish<c.day then return nil,"This challenge has ended." end
    local a=self:findActivity(ch.activity);local added=false
    if not a then
        local err;a,err=self:addActivity(ch.activity,ch.unit,math.max(1,math.floor(ch.amount/10)),ch.icon);if not a then return nil,err end
        added=true
    end
    ch.activityID=a.id;ch.accepted=true;ch.ignored=nil
    ch.participants=ch.participants or {};ch.participants[self.db.participant]={name=selfName or "You",at=c.now}
    self:changed();return ch,added
end
function C:challengeProgress(ch)
    local sum=0
    for _,l in pairs(self.db.logs) do
        if not l.deleted and l.unit==ch.unit and l.day>=ch.start and l.day<=ch.finish
            and ((ch.activityID and l.activityID==ch.activityID) or key(l.activity)==key(ch.activity)) then sum=sum+l.amount end
    end
    return sum
end
function C:challengeList(day)
    local list={}
    for _,ch in pairs(self.db.challenges) do list[#list+1]=ch end
    table.sort(list,function(a,b)
        local x,y=a.finish>=day,b.finish>=day
        if x~=y then return x end
        return (a.created or a.seenAt or 0)>(b.created or b.seenAt or 0)
    end)
    return list
end
