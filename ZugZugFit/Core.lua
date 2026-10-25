local _, ZZ = ...
local Core = {}
ZZ.Core = Core
ZZ.VERSION = "0.9.0-alpha"
local units = { reps = true, minutes = true, sessions = true }
local triggers = { death=true, hearthstone=true, mailbox=true, quest=true, zone=true,
    dungeon=true, eating=true, drinking=true, gear=true, level=true }
Core.triggers = triggers
-- "Before a WoW calendar event" reminders. Events come from ZZ.Calendar through engine.calendarEvents.
local calendarMatches = { raid=true, guild=true, any=true }
Core.calendarMatches = calendarMatches
local OWN_TYPES = { PLAYER=true, GUILD_EVENT=true, GUILD_ANNOUNCEMENT=true, COMMUNITY_EVENT=true }
function Core.calendarMatch(match, ev)
    if type(ev)~="table" or ev.declined or not OWN_TYPES[ev.calendarType] then return false end
    if match=="raid" then return ev.eventType==0 or ev.eventType==1 end
    if match=="guild" then return ev.calendarType=="GUILD_EVENT" or ev.calendarType=="GUILD_ANNOUNCEMENT" end
    return match=="any"
end
local function copy(t)
    local out = {}; for k,v in pairs(t or {}) do out[k] = type(v)=="table" and copy(v) or v end
    return out
end
Core.copy = copy
local function number(v, low, high)
    if type(v)~="number" then return nil end
    return v and v == v and v >= low and v <= high and v or nil
end
local function label(v)
    return type(v)=="string" and #v > 0 and #v <= 60 and not v:find("[%c|]")
end
local function leap(y) return y%4==0 and (y%100~=0 or y%400==0) end
function Core.monthDays(y,m)
    return ({31,leap(y) and 29 or 28,31,30,31,30,31,31,30,31,30,31})[m]
end
function Core.parseDay(s)
    if type(s)~="string" then return end
    local y,m,d=s:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    y,m,d=tonumber(y),tonumber(m),tonumber(d)
    if y and y>=1900 and y<=2300 and m>=1 and m<=12 and d>=1 and d<=Core.monthDays(y,m) then return y,m,d end
end
function Core.day(y,m,d) return string.format("%04d-%02d-%02d",y,m,d) end
function Core.addDays(s,n)
    local y,m,d=Core.parseDay(s); assert(y,"Invalid date")
    d=d+n
    while d>Core.monthDays(y,m) do d=d-Core.monthDays(y,m); m=m+1; if m>12 then m=1;y=y+1 end end
    while d<1 do m=m-1; if m<1 then m=12;y=y-1 end; d=d+Core.monthDays(y,m) end
    return Core.day(y,m,d)
end
function Core.weekday(s) -- Monday=1; arithmetic independent of locale/DST.
    local y,m,d=Core.parseDay(s)
    local offsets={0,3,2,5,0,3,5,1,4,6,2,4}
    if m<3 then y=y-1 end
    return (y+math.floor(y/4)-math.floor(y/100)+math.floor(y/400)+offsets[m]+d+6)%7+1
end
function Core.period(day,kind)
    local y,m,d=Core.parseDay(day)
    if kind=="week" then local a=Core.addDays(day,1-Core.weekday(day));return a,Core.addDays(a,6) end
    if kind=="month" then return Core.day(y,m,1),Core.day(y,m,Core.monthDays(y,m)) end
    if kind=="three months" then
        m=m-3; if m<1 then m=m+12;y=y-1 end
        return Core.day(y,m,math.min(d,Core.monthDays(y,m))),day
    end
    return day,day
end
function Core.minutes(text)
    if type(text)~="string" then return end
    local h,m=text:match("^(%d%d?):(%d%d)$")
    h,m=tonumber(h),tonumber(m)
    if h and h<24 and m<60 then return h*60+m end
end
function Core.clock(n) return string.format("%02d:%02d",math.floor(n/60),n%60) end
local function active(r,day)
    return r.start<=day and (not r.finish or day<=r.finish)
end
local function daysValid(days)
    return type(days)=="string" and days:match("^[1-7]+$") and #days<=7
end
local function selected(r,day) return r.days:find(tostring(Core.weekday(day)),1,true)~=nil end
function Core.new(db,clock)
    if type(db)~="table" then db={} end
    if db.schema and db.schema~=1 then return nil,"Unsupported saved-data version; original data retained." end
    db.schema=1
    for _,k in ipairs({"rules","goals","logs","occurrences","milestones"}) do
        if db[k]~=nil and type(db[k])~="table" then return nil,"Invalid saved "..k.."; original data retained." end
        db[k]=db[k] or {}
    end
    if db.nextID~=nil and (not number(db.nextID,0,1e12) or db.nextID%1~=0) then return nil,"Invalid saved ID counter." end
    db.nextID=db.nextID or 0
    if db.since~=nil and not Core.parseDay(db.since) then return nil,"Invalid saved first day." end
    db.settings=type(db.settings)=="table" and db.settings or {}
    local s=db.settings
    s.channel=(s.channel=="GUILD" or s.channel=="PARTY") and s.channel or "OFF"
    s.announce=s.announce==true;s.milestones=s.milestones==true;s.sound=s.sound==true;s.paused=s.paused==true
    local self=setmetatable({db=db,clock=clock},{__index=Core})
    -- Fail closed instead of discarding or silently rewriting persisted history.
    for id,r in pairs(db.rules) do
        if type(r)~="table" or not self:validateRule(r) or r.id~=id or not Core.parseDay(r.start) or (r.finish and not Core.parseDay(r.finish))
            or (r.elapsed and not number(r.elapsed,0,86400)) or (r.last and not number(r.last,0,1e12))
            or (r.count and not number(r.count,0,1000)) then return nil,"Invalid saved reminder; original data retained." end
    end
    for id,g in pairs(db.goals) do
        if type(g)~="table" or not self:validateGoal(g) or g.id~=id or not Core.parseDay(g.start) or (g.finish and not Core.parseDay(g.finish)) then return nil,"Invalid saved goal; original data retained." end
    end
    for id,l in pairs(db.logs) do
        if type(l)~="table" or not label(l.activity) or not units[l.unit] or not number(l.amount,0.01,100000) or l.id~=id or not Core.parseDay(l.day) or not number(l.revision,1,1e12)
            or not ({prompt=true,manual=true,backfill=true})[l.origin] then return nil,"Invalid saved activity; original data retained." end
    end
    for id,o in pairs(db.occurrences) do
        if type(o)~="table" or not label(o.activity) or not units[o.unit] or not number(o.amount,0.01,100000)
            or not Core.parseDay(o.day) or not ({pending=true,completed=true,skipped=true,expired=true})[o.status]
            or o.id~=id or not db.rules[o.rule] or not number(o.due,0,1e12) then return nil,"Invalid saved occurrence; original data retained." end
    end
    return self
end
function Core:id(prefix)
    local id
    repeat self.db.nextID=self.db.nextID+1;id=prefix..self.db.nextID
    until not (self.db.rules[id] or self.db.goals[id] or self.db.logs[id] or self.db.occurrences[id] or (self.db.activities and self.db.activities[id]))
    return id
end
function Core:validateRule(r)
    if not label(r.activity) or not units[r.unit] or not number(r.amount,0.01,100000) then return nil,"Enter an activity, unit and positive amount." end
    if not daysValid(r.days) then return nil,"Days use 1–7 (Monday–Sunday), e.g. 12345." end
    if not number(r.windowStart,0,1439) or not number(r.windowEnd,1,1440) or r.windowEnd<=r.windowStart then return nil,"Window end must be after start (same day)." end
    if r.kind=="daily" or r.kind=="once" then
        if r.kind=="once" and not Core.parseDay(r.planDay) then return nil,"Choose a valid planned date." end
        if not number(r.at,0,1439) then return nil,"Use a valid daily time, e.g. 21:00." end
    elseif r.kind=="interval" then
        if not number(r.interval,1,1440) then return nil,"Interval must be 1–1440 minutes." end
    elseif r.kind=="trigger" then
        if not triggers[r.trigger] then return nil,"Choose a supported trigger." end
        if not number(r.cooldown,0,1440) or not number(r.cap,1,1000) then return nil,"Cooldown 0–1440 minutes; daily cap 1–1000." end
    elseif r.kind=="calendar" then
        if not calendarMatches[r.calMatch] then return nil,"Choose which WoW calendar events count." end
        if not number(r.lead,0,240) then return nil,"Minutes before the event: 0–240." end
    else return nil,"Choose daily, interval or trigger." end
    return true
end
function Core:addRule(spec)
    local ok,err=self:validateRule(spec); if not ok then return nil,err end
    local r=copy(spec);r.id=self:id("r");r.start=self.clock().day;r.enabled=true;r.elapsed=0
    self.db.rules[r.id]=r;return r
end
function Core:setRuleEnabled(id,enabled)
    local r=self.db.rules[id];if not r or r.retired then return end
    r.enabled=enabled
    if not enabled then r.pauseStart=self.clock().day
    elseif r.pauseStart then
        r.pauses=r.pauses or {};r.pauses[#r.pauses+1]={first=r.pauseStart,last=self.clock().day};r.pauseStart=nil
    end
end
function Core:retireRule(id)
    local r=self.db.rules[id];if not r then return end
    r.enabled=false;r.finish=self.clock().day;r.retired=true
    for _,o in pairs(self.db.occurrences) do if o.rule==id and o.status=="pending" then o.status="skipped" end end
end
function Core:replaceRule(id,spec)
    local ok,err=self:validateRule(spec);if not ok then return nil,err end
    if not self.db.rules[id] then return nil,"Reminder no longer exists." end
    self:retireRule(id);return self:addRule(spec)
end
function Core:validateGoal(g)
    if not label(g.activity) or not units[g.unit] or not number(g.amount,0.01,100000) then return nil,"Enter an activity, unit and positive target." end
    if g.period~="day" and g.period~="week" then return nil,"Goal period must be day or week." end
    if not daysValid(g.days) then return nil,"Select goal days (1=Monday, 7=Sunday)." end
    return true
end
function Core:addGoal(spec)
    local ok,err=self:validateGoal(spec);if not ok then return nil,err end
    local g=copy(spec);g.id=self:id("g");g.start=self.clock().day
    self.db.goals[g.id]=g;return g
end
function Core:replaceGoal(id,spec)
    local ok,err=self:validateGoal(spec);if not ok then return nil,err end
    local old=self.db.goals[id];if not old then return nil,"Goal no longer exists." end
    -- Changes begin at the next period boundary; historical period targets survive.
    local _,last=Core.period(self.clock().day,old.period)
    old.finish=last
    local g=copy(spec);g.id=self:id("g");g.start=Core.addDays(last,1)
    self.db.goals[g.id]=g;return g
end
function Core:stopGoal(id)
    local g=self.db.goals[id];if g then local _,last=Core.period(self.clock().day,g.period);g.finish=last end
end
function Core:pending(rule)
    for _,o in pairs(self.db.occurrences) do if o.rule==rule and o.status=="pending" then return o end end
end
function Core:makeOccurrence(r,c,key)
    if self:pending(r.id) then return end
    local id=key and (r.id..":"..c.day..":"..key) or (r.kind=="daily" or r.kind=="once") and (r.id..":"..c.day) or self:id("o")
    if self.db.occurrences[id] then return end
    local o={id=id,rule=r.id,activity=r.activity,activityID=r.activityID,unit=r.unit,amount=r.amount,day=c.day,due=c.now,status="pending",kind=r.kind}
    self.db.occurrences[id]=o;return o
end
function Core:eligible(r,c)
    return r.enabled and not r.retired and active(r,c.day) and selected(r,c.day)
        and (r.kind~="once" or r.planDay==c.day)
        and (r.kind=="daily" or r.kind=="once" or r.kind=="calendar" or (c.minute>=r.windowStart and c.minute<r.windowEnd))
end
function Core:tick(seconds,isAFK)
    local c=self.clock()
    -- Unhandled daily prompts expire at midnight; explicit snoozes survive.
    for _,o in pairs(self.db.occurrences) do
        if o.status=="pending" and o.day<c.day and not o.snoozed then o.status="expired" end
    end
    if self.db.settings.paused then return end
    for _,r in pairs(self.db.rules) do
        if self:eligible(r,c) then
            if (r.kind=="daily" or r.kind=="once") and c.minute>=r.at then self:makeOccurrence(r,c)
            elseif r.kind=="calendar" then
                -- Start at "lead" minutes before the event; a reminder that is more than 15 minutes late does not start.
                for _,ev in ipairs(self.calendarEvents or {}) do
                    if ev.day==c.day and ev.minute and ev.key and Core.calendarMatch(r.calMatch,ev)
                        and c.minute>=ev.minute-r.lead and c.minute<=ev.minute-r.lead+15 then
                        local o=self:makeOccurrence(r,c,ev.key);if o then o.note=ev.title end
                    end
                end
            elseif r.kind=="interval" and not isAFK and not self:pending(r.id) then
                r.elapsed=(r.elapsed or 0)+math.max(0,math.min(seconds,5))
                if r.elapsed>=r.interval*60 then self:makeOccurrence(r,c);r.elapsed=0 end
            end
        end
    end
end
function Core:trigger(name)
    if self.db.settings.paused then return end
    local c=self.clock();local count=0
    for _,r in pairs(self.db.rules) do
        if r.kind=="trigger" and r.trigger==name and self:eligible(r,c) and not self:pending(r.id) then
            if r.countDay~=c.day then r.countDay=c.day;r.count=0 end
            if (not r.last or c.now-r.last>=r.cooldown*60) and (r.count or 0)<r.cap then
                self:makeOccurrence(r,c);r.last=c.now;r.count=(r.count or 0)+1;count=count+1
            end
        end
    end
    return count
end
function Core:nextPrompt()
    if self.db.settings.paused then return end
    local c=self.clock();local result
    for _,o in pairs(self.db.occurrences) do
        local r=self.db.rules[o.rule]
        if o.status=="pending" and o.due<=c.now and r and self:eligible(r,c) then
            if not result or o.due<result.due or (o.due==result.due and o.id<result.id) then result=o end
        end
    end
    return result
end
function Core:snooze(id,minutes)
    local o=self.db.occurrences[id]
    if not o or o.status~="pending" then return nil,"Reminder already handled." end
    minutes=number(minutes,1,1440);if not minutes then return nil,"Snooze must be 1–1440 minutes." end
    o.due=self.clock().now+minutes*60;o.snoozed=true;return true
end
function Core:dismiss(id)
    local o=self.db.occurrences[id];if not o or o.status~="pending" then return nil,"Reminder already handled." end
    o.status="skipped";local r=self.db.rules[o.rule];if r then r.elapsed=0 end;return true
end
function Core:saveLog(spec,id)
    local c=self.clock()
    if not label(spec.activity) or not units[spec.unit] or not number(spec.amount,0.01,100000) then return nil,"Enter an activity and positive amount (up to 100000)." end
    if not Core.parseDay(spec.day) or spec.day>c.day then return nil,"Use a real date, today or earlier (YYYY-MM-DD)." end
    local old=id and self.db.logs[id]
    if id and (not old or old.deleted) then return nil,"Activity no longer exists." end
    local o=spec.occurrence and self.db.occurrences[spec.occurrence]
    if spec.occurrence and (not o or o.status~="pending") and not old then return nil,"Reminder already handled; no duplicate credit." end
    local l={id=id or self:id("l"),activity=spec.activity,unit=spec.unit,amount=tonumber(spec.amount),day=spec.day,
        recordedAt=old and old.recordedAt or c.now,updatedAt=c.now,revision=old and old.revision+1 or 1,
        origin=old and old.origin or (spec.day<c.day and "backfill" or (o and "prompt" or "manual")),
        occurrence=old and old.occurrence or spec.occurrence}
    self.db.logs[l.id]=l
    if o and not old then o.status="completed";o.log=l.id;local r=self.db.rules[o.rule];if r then r.elapsed=0 end end
    return l
end
function Core:deleteLog(id)
    local l=self.db.logs[id];if not l or l.deleted then return end
    l.deleted=true;l.revision=l.revision+1;l.updatedAt=self.clock().now;return true
end
function Core:restoreLog(id)
    local l=self.db.logs[id];if l and l.deleted then l.deleted=nil;l.revision=l.revision+1;l.updatedAt=self.clock().now;return true end
end
function Core:total(activity,unit,first,last)
    local sum=0
    for _,l in pairs(self.db.logs) do if not l.deleted and l.activity==activity and l.unit==unit and l.day>=first and l.day<=last then sum=sum+l.amount end end
    return sum
end
function Core:goalStatus(g,day)
    if not active(g,day) or (g.period=="day" and not selected(g,day)) then return end
    local a,b=Core.period(day,g.period)
    if a<g.start then a=g.start end;if g.finish and b>g.finish then b=g.finish end
    local value=self:total(g.activity,g.unit,a,b);local today=self.clock().day
    local state=value>=g.amount and "Completed" or (b<today and "Unmet" or (value>0 and "Partial" or (day>today and "Planned" or "Due")))
    return state,value,a,b
end
function Core:dayDetails(day)
    local rows={};local c=self.clock()
    for _,g in pairs(self.db.goals) do
        local state,value=self:goalStatus(g,day)
        if state then rows[#rows+1]={kind="goal",id=g.id,text=state..": "..g.activity.." "..value.."/"..g.amount.." "..g.unit.." ("..g.period..")"} end
    end
    for _,r in pairs(self.db.rules) do
        if (r.kind=="daily" or (r.kind=="once" and r.planDay==day)) and active(r,day) and selected(r,day) then
            local o=self.db.occurrences[r.id..":"..day]
            local state=o and ({pending=o.snoozed and "Snoozed" or "Due",completed="Logged",skipped="Skipped",expired="Not logged"})[o.status]
                or (day<c.day and "Not logged" or ((day>c.day or c.minute<r.at) and "Planned" or "Due"))
            if not o then
                local paused=r.pauseStart and day>=r.pauseStart
                for _,p in ipairs(r.pauses or {}) do if day>=p.first and day<=p.last then paused=true end end
                if paused then state="Paused" end
                if r.retired and day==r.finish then state="Retired" end
            elseif o.status=="completed" and o.log and self.db.logs[o.log] and self.db.logs[o.log].deleted then state="Log removed" end
            rows[#rows+1]={kind="rule",id=r.id,text=state..": "..Core.clock(r.at).." "..r.activity}
        end
    end
    -- A done reminder with a log shows once, as the log row.
    local words={completed="Done",skipped="Skipped",expired="Not logged"}
    for _,o in pairs(self.db.occurrences) do if o.kind~="daily" and o.kind~="once" and o.day==day and not (o.status=="completed" and o.log and self.db.logs[o.log]) then
        rows[#rows+1]={kind="occurrence",id=o.id,text=(o.status=="pending" and (o.snoozed and "Snoozed" or "Due") or words[o.status] or o.status)..": "..o.activity}
    end end
    local how={prompt="",manual=" (by hand)",backfill=" (added later)"}
    for _,l in pairs(self.db.logs) do if l.day==day then
        rows[#rows+1]={kind="log",id=l.id,text=(l.deleted and "Deleted: " or "Logged: ")..l.amount.." "..l.unit.." "..l.activity..(how[l.origin] or "")}
    end end
    table.sort(rows,function(a,b) return a.kind==b.kind and a.id<b.id or a.kind<b.kind end)
    return rows
end
function Core:summary(day,period)
    local a,b=Core.period(day,period);local rows={};local seen={}
    for _,l in pairs(self.db.logs) do
        local key=l.activity.."/"..l.unit
        if not l.deleted and l.day>=a and l.day<=b and not seen[key] then
            seen[key]=true;rows[#rows+1]=l.activity..": "..self:total(l.activity,l.unit,a,b).." "..l.unit
        end
    end
    table.sort(rows);return table.concat(rows,"\n"),a,b
end
