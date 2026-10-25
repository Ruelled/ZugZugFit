local _,ZZ=...
-- Read-only adapter for the WoW calendar. WoW blocks addons from saving calendar events
-- (C_Calendar.AddEvent and UpdateEvent are restricted), so ZugZugFit only reads events,
-- converts realm time to local time, and can fill in Blizzard's own "Create event" window.
local Calendar={};ZZ.Calendar=Calendar
local function read(v) return not (issecretvalue and issecretvalue(v)) end
local function num(v) return read(v) and type(v)=='number' end
local function api() return C_Calendar end
local SYSTEM={HOLIDAY='holiday',RAID_LOCKOUT='lockout',RAID_RESET='lockout',SYSTEM='system'}
local DECLINED={[2]=true,[4]=true,[7]=true}
Calendar.TTL=60
-- Minutes to add to realm time to get local time, rounded to 15 minutes.
function Calendar:offset()
    local fn=C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime
    if not fn then return 0 end
    local ok,t=pcall(fn)
    if not ok or not read(t) or type(t)~='table' or not num(t.year) or not num(t.month) or not num(t.monthDay) or not num(t.hour) or not num(t.minute) then return 0 end
    local realm=time({year=t.year,month=t.month,day=t.monthDay,hour=t.hour,min=t.minute,sec=0})
    return math.floor((time()-realm)/60/15+0.5)*15
end
local function localTime(y,m,d,hour,minute,offset)
    local stamp=time({year=y,month=m,day=d,hour=hour,min=minute,sec=0})+offset*60
    local t=date('*t',stamp);return ZZ.Core.day(t.year,t.month,t.day),t.hour*60+t.min
end
-- Events of one realm day, already converted. Returns nil when the API is missing or restricted.
local function readDay(offsetMonths,y,m,d,offset,out)
    local c=api();local n=c.GetNumDayEvents(offsetMonths,d)
    if not num(n) then return nil end
    for i=1,math.min(n,50) do
        local ev=c.GetDayEvent(offsetMonths,d,i)
        if read(ev) and type(ev)=='table' and read(ev.title) and type(ev.title)=='string' then
            local t=ev.startTime;local kind=SYSTEM[ev.calendarType] or 'event'
            local seq=read(ev.sequenceType) and ev.sequenceType or ''
            local timed=type(t)=='table' and num(t.hour) and num(t.minute) and (seq=='' or seq=='START' or seq=='INFO')
            local row={title=ev.title:gsub('[%c|]',''):sub(1,80),calendarType=read(ev.calendarType) and ev.calendarType or '',kind=kind,
                eventType=num(ev.eventType) and ev.eventType or nil,declined=num(ev.inviteStatus) and DECLINED[ev.inviteStatus] or nil,
                icon=num(ev.iconTexture) and ev.iconTexture or nil,ongoing=(seq=='ONGOING' or seq=='END') or nil}
            if timed then
                row.day,row.minute=localTime(y,m,d,t.hour,t.minute,offset)
                row.realm=ZZ.Core.clock(t.hour*60+t.minute)
            else row.day=ZZ.Core.day(y,m,d) end
            row.key=(num(ev.eventID) and tostring(ev.eventID) or row.title:gsub('[^%w]',''):sub(1,24))..'@'..row.day..(row.minute and ('-'..row.minute) or '')
            out[#out+1]=row
        end
    end
    return true
end
-- All WoW events from first to last (local days), grouped by day. Cached for TTL seconds.
function Calendar:range(first,last)
    local now=time()
    local key=first..last;self.caches=self.caches or {};local cached=self.caches[key]
    if cached and now-cached.at<self.TTL then return cached.days end
    if ZZ.InCombat() then return cached and cached.days or {},'Calendar access waits until you leave combat.' end
    local c=api()
    if not c or not c.GetMonthInfo or not c.GetNumDayEvents or not c.GetDayEvent then return {},'The WoW calendar is unavailable on this client.' end
    local offset=self:offset();local rows={}
    local ok,result=pcall(function()
        local base=c.GetMonthInfo(0)
        if not read(base) or type(base)~='table' or not num(base.year) or not num(base.month) then return nil end
        local day=ZZ.Core.addDays(first,-1);local stop=ZZ.Core.addDays(last,1);local guard=0
        while day<=stop and guard<120 do
            guard=guard+1
            local y,m,d=ZZ.Core.parseDay(day)
            if not readDay((y-base.year)*12+m-base.month,y,m,d,offset,rows) then return nil end
            day=ZZ.Core.addDays(day,1)
        end
        return true
    end)
    if not ok or not result then return {},'Calendar data is restricted or not ready. Open the WoW calendar one time, then click Refresh.' end
    local days,seen={},{}
    for _,r in ipairs(rows) do
        if r.day>=first and r.day<=last and not seen[r.key] then
            seen[r.key]=true;days[r.day]=days[r.day] or {};table.insert(days[r.day],r)
        end
    end
    for _,list in pairs(days) do table.sort(list,function(a,b) return (a.minute or -1)==(b.minute or -1) and a.title<b.title or (a.minute or -1)<(b.minute or -1) end) end
    if not cached then local n=0;for _ in pairs(self.caches) do n=n+1 end;if n>8 then self.caches={} end end
    self.caches[key]={at=now,days=days}
    return days
end
function Calendar:day(day) local days,err=self:range(day,day);return days[day] or {},err end
function Calendar:invalidate() self.caches={} end
-- Old single-day reader, kept for callers that want a plain list.
function Calendar:read(day)
    if not ZZ.Core.parseDay(day) then return nil,'Choose a valid date.' end
    if ZZ.InCombat() then return nil,'Calendar access waits until you leave combat.' end
    local c=api()
    if not c or not c.GetMonthInfo or not c.GetNumDayEvents or not c.GetDayEvent then return nil,'The WoW calendar is unavailable on this client.' end
    self:invalidate();local list,err=self:day(day)
    if err then return nil,err end
    local out={}
    for _,r in ipairs(list) do out[#out+1]={day=r.day,title=r.title,time=r.minute and ZZ.Core.clock(r.minute) or 'All day'} end
    return out
end
-- Ask the server for calendar data. Blizzard's calendar does the same when it opens.
function Calendar:request()
    local c=api();if c and c.OpenCalendar and not ZZ.InCombat() then pcall(c.OpenCalendar) end
end
-- PREFILL: the player opens "Create Event" in Blizzard's calendar; ZugZugFit fills in the fields.
-- ZugZugFit never calls the restricted AddEvent: the player clicks Blizzard's Create button.
function Calendar:prefill(plan)
    if ZZ.InCombat() then return nil,'Leave combat first.' end
    local load=(C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
    if not CalendarFrame and load then pcall(load,'Blizzard_Calendar') end
    if not CalendarFrame or not CalendarCreateEventFrame or not hooksecurefunc or not CalendarFrame_ShowEventFrame then
        return nil,'The WoW calendar window is not available on this client.'
    end
    local y,m,d=ZZ.Core.parseDay(plan.day)
    local stamp=time({year=y,month=m,day=d,hour=math.floor(plan.minute/60),min=plan.minute%60,sec=0})-self:offset()*60
    local t=date('*t',stamp)
    self.pending={title=plan.title:sub(1,60),note=plan.note or '',year=t.year,month=t.month,day=t.day,hour=t.hour,minute=t.min,expires=time()+900}
    if not self.hooked then
        self.hooked=true
        hooksecurefunc('CalendarFrame_ShowEventFrame',function(frame) Calendar:fill(frame) end)
    end
    if not CalendarFrame:IsShown() then if Calendar_Show then pcall(Calendar_Show) else pcall(ShowUIPanel,CalendarFrame) end end
    return self.pending
end
function Calendar:fill(frame)
    local p=self.pending
    if not p or frame~=CalendarCreateEventFrame or frame.mode~='create' then return end
    if time()>p.expires then self.pending=nil;return end
    local ok,info=pcall(function() local b=frame.dayButton;local mi=C_Calendar.GetMonthInfo(b.monthOffset);return {year=mi.year,month=mi.month,day=b.day} end)
    if not ok or not info or info.year~=p.year or info.month~=p.month or info.day~=p.day then
        ZZ.Print(string.format('ZugZugFit fills in the event only on %04d-%02d-%02d. Right-click that day, then click Create Event.',p.year,p.month,p.day));return
    end
    self.pending=nil
    pcall(function()
        CalendarCreateEventTitleEdit:SetText(p.title);C_Calendar.EventSetTitle(p.title)
        local box=CalendarCreateEventDescriptionContainer and CalendarCreateEventDescriptionContainer.ScrollingEditBox
        if box and box.SetText then box:SetText(p.note) end;C_Calendar.EventSetDescription(p.note)
        local minute=math.floor(p.minute/5)*5
        if CalendarFrame.militaryTime then frame.selectedHour=p.hour
        else frame.selectedHour=(p.hour%12==0) and 12 or p.hour%12;frame.selectedAM=p.hour<12 end
        frame.selectedMinute=minute
        if CalendarCreateEvent_UpdateEventTime then CalendarCreateEvent_UpdateEventTime() end
        C_Calendar.EventSetTime(p.hour,minute)
    end)
    ZZ.Print('ZugZugFit filled in the title, the time and a note. Check them, then click Create.')
end
