local _,ZZ=...
local U={tab='Today',mode='month',routineTab='Reminders',settingsTab='Reminders',guildSort='days',guildPeriod='week',totalPeriod='week'};ZZ.UI=U
local W,C=ZZ.W,ZZ.Core
local FW,FH,CH=900,664,540 -- CH: height of one tab's content area
local TABS={'Today','Calendar','Routines','Triggers','Guild','Settings'}
local TAB_ICONS={Today='Interface\\Icons\\INV_Misc_PocketWatch_01',Calendar='Interface\\Icons\\INV_Misc_Book_09',Routines='Interface\\Icons\\INV_Misc_Note_01',Triggers='Interface\\Icons\\Spell_Nature_Lightning',
    Guild='Interface\\Icons\\INV_Banner_02',Settings='Interface\\Icons\\INV_Misc_Gear_01'}
local READY,NOTREADY,WAITING='Interface\\RaidFrame\\ReadyCheck-Ready','Interface\\RaidFrame\\ReadyCheck-NotReady','Interface\\RaidFrame\\ReadyCheck-Waiting'
local function engine() return ZZ.engine end
local function today() return ZZ.Now().day end
local function fmt(n) return string.format('%g',n) end
local function activity(id) return engine().db.activities[id] end
local function iconOf(id) return C.iconFor(activity(id)) end
local function iconByKey(key)
    for _,a in pairs(engine().db.activities) do if C.activityKey(a.name)==key then return C.iconFor(a),a.name end end
    return C.iconFor(nil),(key:gsub('^%l',string.upper))
end
local periods={{value='day',label='Today'},{value='week',label='This week'},{value='month',label='This month'},{value='three months',label='3 months'}}
local KINDS={
    {value='daily',label='Daily time',hint='e.g. yoga 21:00',icon='Interface\\Icons\\INV_Misc_PocketWatch_01'},
    {value='interval',label='Every X min',hint='while you play',icon='Interface\\Icons\\Spell_Nature_TimeStop'},
    {value='trigger',label='Game event',hint='mailbox, quest...',icon='Interface\\Icons\\INV_Letter_15'},
    {value='calendar',label='WoW calendar',hint='before a raid',icon='Interface\\Icons\\INV_Misc_Book_09'},
    {value='once',label='One date',hint='a single day',icon='Interface\\Icons\\INV_Misc_Note_01'},
}
local calendarOptions={{value='raid',label='Raids and dungeons'},{value='guild',label='Guild events'},{value='any',label='All my events'}}
local function calendarLabel(v) for _,o in ipairs(calendarOptions) do if o.value==v then return o.label:lower() end end;return tostring(v) end
U.calendarOptions=calendarOptions
-- Game events that can start a reminder, in the order the Triggers tab lists them.
local triggerOptions={
    {value='mailbox',label='Open the mailbox',icon='INV_Letter_15'},{value='quest',label='Turn in a quest',icon='INV_Scroll_03'},
    {value='death',label='Die',icon='Ability_Rogue_FeignDeath'},{value='hearthstone',label='Use Hearthstone',icon='INV_Misc_Rune_01'},
    {value='dungeon',label='Finish a dungeon',icon='INV_Misc_Head_Dragon_01'},{value='zone',label='Enter a new zone',icon='INV_Misc_Map_01'},
    {value='eating',label='Start eating',icon='INV_Misc_Food_15'},{value='drinking',label='Start drinking',icon='INV_Drink_07'},
    {value='gear',label='Equip gear',icon='INV_Helmet_03'},{value='level',label='Level up',icon='Spell_ChargePositive'}}
local function triggerLabel(v) for _,o in ipairs(triggerOptions) do if o.value==v then return o.label:lower() end end;return v end
U.TEMPLATES={
    {title='Evening yoga',hint='15 min at 21:00',spec={activityID='yoga',unit='minutes',amount=15,kind='daily',at=1260,days='1234567'}},
    {title='Desk push-ups',hint='10 per 30 min, to 100',spec={activityID='push-ups',unit='reps',amount=10,kind='interval',interval=30,days='1234567',windowStart=0,windowEnd=1440,goal={amount=100,period='day'},stopAtGoal=true}},
    {title='Stretch break',hint='5 min every hour',spec={activityID='stretching',unit='minutes',amount=5,kind='interval',interval=60,days='1234567',windowStart=0,windowEnd=1440}},
    {title='Pre-raid burpees',hint='10 at 19:00',spec={activityID='burpees',unit='reps',amount=10,kind='daily',at=1140,days='1234567'}},
    {title='Water break',hint='every 45 min',spec={activityID='water',unit='sessions',amount=1,kind='interval',interval=45,days='1234567',windowStart=0,windowEnd=1440}},
    {title='Roast Your Nutz',hint='10 min, every day',spec={activityID='roast-your-nutz',unit='minutes',amount=10,kind='daily',at=480,days='1234567'}},
}
local function sorted(collection)
    local list={};for _,v in pairs(collection) do list[#list+1]=v end;table.sort(list,function(a,b) return a.id<b.id end);return list
end
local function amountText(amount,unit,name) return fmt(amount)..' '..unit..' of '..name end
-- One plain sentence per routine; the builder and the list both use it.
function U.describe(r)
    local what=amountText(r.amount or 0,r.unit or 'reps',r.activity or (activity(r.activityID) or {}).name or '?')
    local window=(r.windowStart and r.windowEnd and not (r.windowStart==0 and r.windowEnd==1440)) and (', '..C.clock(r.windowStart)..'–'..C.clock(r.windowEnd)) or ''
    if r.kind=='daily' then return W.daysText(r.days or '')..' at '..C.clock(r.at or 0)..': '..what..'.'
    elseif r.kind=='once' then return 'On '..tostring(r.planDay)..' at '..C.clock(r.at or 0)..': '..what..'.'
    elseif r.kind=='interval' then return W.daysText(r.days or '')..window..': '..what..' every '..tostring(r.interval)..' minutes of play.'
    elseif r.kind=='calendar' then
        return W.daysText(r.days or '')..': '..what..(tonumber(r.lead)==0 and ' at the start of ' or (' '..tostring(r.lead)..' min before '))..calendarLabel(r.calMatch)..' in the WoW calendar.'
    end
    return 'After you '..triggerLabel(r.trigger)..' ('..W.daysText(r.days or '')..window..'): '..what..'. At most '..tostring(r.cap)..' a day, '..tostring(r.cooldown)..' min apart.'
end
function U:error(message) if self.modal then self.modal.error:SetText(message or '') else ZZ.Print(message) end end
function U:dialog(title,w,h)
    W.closeMenu();if self.modal then self.modal:Hide() end
    self.shield=self.shield or W.section(self.frame,'modalShield',FW,FH,0,0)
    self.shield:Show();self.shield:EnableMouse(true);self.shield:SetFrameStrata('DIALOG');self.shield:SetFrameLevel(self.frame:GetFrameLevel()+5)
    self.shield:SetBackdropColor(0,0,0,0.6)
    local d=W.frame(self.frame,'dialog',w,h,(FW-w)/2,-math.max(8,(FH-h)/2));W.reset(d);d:EnableMouse(true);d:SetFrameStrata('DIALOG');d:SetFrameLevel(self.shield:GetFrameLevel()+1)
    local t=W.text(d,'title',title,20,-18,w-80,24,'GameFontNormalLarge')
    t:SetJustifyH('LEFT')
    local close=W.acquire(d,'close','Button','UIPanelCloseButton');close:SetSize(30,30);close:ClearAllPoints();close:SetPoint('TOPLEFT',w-38,-8)
    close:SetScript('OnClick',function() self:finish() end)
    d.error=W.text(d,'error','',200,-h+42,w-400,30,'GameFontRedSmall');d.error:SetJustifyH('CENTER')
    d.w,d.h=w,h;self.modal=d;return d
end
function U:finish()
    W.closeMenu();if self.modal then self.modal:Hide();self.modal=nil end
    if self.shield then self.shield:Hide() end
    self:refresh();self:updatePrompt()
end
local function footer(self,d,saveLabel,onSave)
    W.button(d,'save',saveLabel,20,-d.h+44,170,onSave)
    W.button(d,'cancel','Cancel',d.w-190,-d.h+44,170,function() self:finish() end)
end
function U:build()
    self.day=today();self.month=self.day:sub(1,7)..'-01'
    local f=W.frame(UIParent,'ZugZugFitMain',FW,FH,0,0);f:ClearAllPoints();f:SetPoint('CENTER');f:SetFrameStrata('HIGH');f:EnableMouse(true)
    f:SetMovable(true);f:RegisterForDrag('LeftButton');f:SetClampedToScreen(true)
    f:SetScript('OnDragStart',function() W.closeMenu();f:StartMoving() end);f:SetScript('OnDragStop',function() f:StopMovingOrSizing() end)
    f:SetScript('OnHide',function() W.closeMenu();if self.realEngine then self:sampleMode(false) end;if self.modal then self.modal:Hide();self.modal=nil end;if self.shield then self.shield:Hide() end end)
    self.frame=f;f.panels={}
    W.tex(f,'plaque','Interface\\DialogFrame\\UI-DialogBox-Header',340,64,(FW-340)/2,12,'OVERLAY')
    local title=W.text(f,'title','ZugZugFit',(FW-300)/2,-1,300,16,'GameFontNormal');title:SetJustifyH('CENTER')
    W.icon(f,'emblem','Interface\\Icons\\Ability_Rogue_Sprint',30,20,-16)
    W.text(f,'subtitle','Movement journal · account-wide · '..ZZ.VERSION,58,-24,560,18,'GameFontDisableSmall')
    local close=W.acquire(f,'close','Button','UIPanelCloseButton');close:SetSize(32,32);close:ClearAllPoints();close:SetPoint('TOPLEFT',FW-40,-8)
    close:SetScript('OnClick',function() self:finish();f:Hide() end)
    self.tabs={}
    -- One framed content area; the selected tab joins it from above.
    f.content=W.section(f,'content',FW-24,FH-98,12,-86,1);f.content:SetBackdropColor(0.09,0.07,0.05,1)
    for _,name in ipairs(TABS) do
        local p=CreateFrame('Frame',nil,f);p:SetSize(FW-40,CH);p:SetPoint('TOPLEFT',20,-98);f.panels[name]=p;p:SetFrameLevel(f.content:GetFrameLevel()+2)
    end
    if UISpecialFrames then
        -- Global handle is only for the standard Escape-to-close list.
        ZugZugFitWindow=f;UISpecialFrames[#UISpecialFrames+1]='ZugZugFitWindow'
    end
end
function U:show(tab)
    if not self.frame then self:build() end
    if self.modal then self.modal:Hide();self.modal=nil end
    if self.shield then self.shield:Hide() end
    self.tab=tab or self.tab;self.frame:Show();self:refresh()
end
function U:refresh()
    if not self.frame then return end
    W.closeMenu()
    for i,name in ipairs(TABS) do
        self.tabs[name]=W.topTab(self.frame,'tab'..name,name,TAB_ICONS[name],16+(i-1)*145,141,name==self.tab,function() self:show(name) end)
        self.tabs[name]:SetFrameLevel(self.frame.content:GetFrameLevel()+(name==self.tab and 3 or 1))
    end
    self.frame.texts.subtitle:SetText(self.realEngine and '|cffff5040SAMPLE DATA · nothing is saved · close the window or /zzf sample to leave|r' or ('Movement journal · account-wide · '..ZZ.VERSION))
    for name,p in pairs(self.frame.panels) do p:Hide();if name==self.tab then p:Show() end end
    local p=self.frame.panels[self.tab];W.reset(p)
    local scale=engine().db.settings.scale or 1
    self.frame:SetScale(math.min(scale,(UIParent:GetWidth()-20)/FW,(UIParent:GetHeight()-40)/FH))
    if self.tab=='Today' then self:renderToday(p)
    elseif self.tab=='Calendar' then self:renderCalendar(p)
    elseif self.tab=='Routines' then self:renderRoutines(p)
    elseif self.tab=='Triggers' then self:renderTriggers(p)
    elseif self.tab=='Guild' then self:renderGuild(p)
    else self:renderSettings(p) end
end
local function list(p,key,x,y,w,h)
    local _,body=W.scroll(p,key,x,y,w,h);W.reset(body);return body
end
local function heading(p,key,text,x,y,w) return W.text(p,key,text,x,y,w or 400,18,'GameFontNormal') end
-- Card row with icon, gold title and a detail line; callers add buttons on the right.
local function card(body,key,index,w,h,iconPath,title,sub)
    local r=W.section(body,key,w,h,0,-(index-1)*(h+4),0.45);W.reset(r)
    W.icon(r,'icon',iconPath,h-16,8,-8)
    local top=h<48 and -5 or -9
    W.text(r,'title',title,h+2,top,w-h-10,16,'GameFontNormal')
    W.text(r,'sub',sub or '',h+2,top-17,w-h-10,math.max(14,h-30),'GameFontHighlightSmall')
    body:SetHeight(math.max(1,index*(h+4)));return r
end
local function logsBetween(first,last)
    local days,totals={},{}
    for _,l in pairs(engine().db.logs) do if not l.deleted and l.day>=first and l.day<=last then
        days[l.day]=days[l.day] or {};days[l.day][l.activityID or l.activity]=true
        local k=l.activity..'|'..l.unit;totals[k]=(totals[k] or 0)+l.amount
    end end
    return days,totals
end
-- TODAY ------------------------------------------------------------------------------------------
-- Progress line for a reminder: its goal if it has one, otherwise today's total for that exercise.
function U:progress(r)
    local e=engine();local day=today()
    local g=e:ruleGoal(r,day);local d=self:doneOn(day)[(r.activityID or r.activity)..'|'..r.unit]
    local done=d and d.amount or 0
    if g then
        local _,value=e:goalStatus(g,day);value=value or done
        if value>=g.amount then return W.GREEN..'Goal reached: '..fmt(value)..' / '..fmt(g.amount)..'|r' end
        return fmt(value)..' / '..fmt(g.amount)..' '..r.unit..(g.period=='week' and ' this week' or ' today')
    end
    return done>0 and ('Done today: '..fmt(done)..' '..r.unit) or 'Nothing logged yet today'
end
function U:doneOn(day)
    local out={}
    for _,l in pairs(engine().db.logs) do if not l.deleted and l.day==day then
        local k=(l.activityID or l.activity)..'|'..l.unit
        local d=out[k] or {name=l.activity,unit=l.unit,amount=0,sets=0,icon=iconOf(l.activityID)}
        d.amount=d.amount+l.amount;d.sets=d.sets+1;out[k]=d
    end end
    return out
end
function U:renderToday(p)
    local e=engine();local state=e:today();local now=ZZ.Now()
    local doneToday=self:doneOn(now.day)
    local function progress(r) return self:progress(r) end
    heading(p,'dueHead','Due now',0,0)
    local due=W.section(p,'dueBox',530,150,0,-20)
    local body=list(due,'dueList',8,-8,508,134);local i=0
    for _,o in ipairs(state.pending) do
        i=i+1;local wait=o.due>now.now and ('Snoozed · back in '..math.ceil((o.due-now.now)/60)..' min') or 'Ready when you are'
        local rule=e.db.rules[o.rule]
        local r=card(body,'pending'..o.id,i,504,62,iconOf(o.activityID),fmt(o.amount)..' '..o.unit..' · '..o.activity,wait..(rule and ('\n'..progress(rule)) or ''))
        r.texts.sub:SetWidth(190);r.texts.title:SetWidth(190)
        local done=W.button(r,'log','Done',268,-19,72,function(_,button)
            if button=='RightButton' then self:logDialog(today(),nil,o) else self:quickLog(o,o.amount) end
        end)
        done:RegisterForClicks('LeftButtonUp','RightButtonUp')
        W.tooltip(done,'Log '..fmt(o.amount)..' '..o.unit..' now.\nRight-click to log a different amount or date.')
        W.button(r,'later','Snooze',344,-19,82,function() e:snooze(o.id,e.db.settings.snooze);self:refresh();self:updatePrompt() end)
        W.button(r,'skip','Skip',430,-19,64,function() e:dismiss(o.id);self:refresh();self:updatePrompt() end)
    end
    local anyRule=false;for _,r in pairs(e.db.rules) do if not r.retired then anyRule=true end end
    if i==0 and not anyRule then
        -- First start: no reminders yet. Offer three quick starts and the full builder.
        local wel=W.section(body,'welcome',504,124,0,0,0.45);W.reset(wel)
        W.icon(wel,'icon','Interface\\Icons\\Ability_Rogue_Sprint',36,8,-8)
        W.text(wel,'title','Welcome to ZugZugFit',52,-8,440,18,'GameFontNormalLarge')
        W.text(wel,'sub','Zug zug! Click a quick start to make your first reminder. You can change it before you save.',52,-28,440,16,'GameFontHighlightSmall')
        for k,idx in ipairs({2,3,5}) do
            local t=U.TEMPLATES[idx]
            W.card(wel,'start'..k,158,46,8+(k-1)*164,-48,iconOf(t.spec.activityID),t.title,t.hint,false,function() self:ruleDialog(nil,t.spec) end)
        end
        W.button(wel,'own','Build my own',8,-98,158,function() self:ruleDialog() end)
        W.text(wel,'more','Or open Triggers for an exercise after a game event.',176,-102,320,16,'GameFontDisableSmall')
    elseif i==0 then
        local nextUp=state.upcoming[1]
        local paused=e.db.settings.paused
        local r=card(body,'empty',1,504,62,paused and WAITING or READY,paused and 'Reminders are paused' or 'All caught up',
            paused and 'No reminder starts until you resume. “Now” still works.' or nextUp and ('Next: '..nextUp.activity..' at '..C.clock(nextUp.at)) or 'No reminder is waiting. Use “Now” below to start one early.')
        r.texs.icon:SetTexCoord(0,1,0,1)
        if paused then
            r.texts.sub:SetWidth(330);r.texts.title:SetWidth(330)
            W.button(r,'resume','Resume',410,-19,84,function() e.db.settings.paused=false;ZZ.UpdateMinimap();self:refresh();self:updatePrompt() end)
        end
    end
    -- Done today: one tile per exercise, so the count is visible without opening the calendar.
    heading(p,'doneHead','Done today',0,-180)
    local doneBox=W.section(p,'doneBox',530,92,0,-200);W.reset(doneBox)
    local items={};for _,d in pairs(doneToday) do items[#items+1]=d end
    table.sort(items,function(a,b) return a.name<b.name end)
    -- Five tiles fit. With more exercises, the fifth tile becomes "+N more" and opens today in the calendar.
    for k,d in ipairs(items) do
        if k==5 and #items>5 then
            local rest={};for j=5,#items do rest[#rest+1]=items[j].name..': '..fmt(items[j].amount)..' '..items[j].unit end
            local t=W.flat(doneBox,'more',94,76,8+4*97,-8,false,function() self.day=today();self.month=today():sub(1,7)..'-01';self:show('Calendar') end);W.reset(t)
            local m=W.text(t,'count',W.GOLD..'+'..(#items-4)..'|r',4,-14,86,20,'GameFontNormalLarge');m:SetJustifyH('CENTER')
            local l=W.text(t,'label','more today',4,-44,86,14,'GameFontHighlightSmall');l:SetJustifyH('CENTER')
            W.tooltip(t,table.concat(rest,'\n')..'\n\nClick to see today in the calendar.')
            break
        end
        local t=W.flat(doneBox,'done'..k,94,76,8+(k-1)*97,-8,false,nil);W.reset(t)
        W.icon(t,'icon',d.icon,26,8,-8)
        W.text(t,'count',W.GOLD..fmt(d.amount)..'|r',38,-8,54,16,'GameFontNormal')
        W.text(t,'unit',d.unit,38,-24,54,14,'GameFontHighlightSmall')
        local n=W.text(t,'name',d.name..(d.sets>1 and (' ×'..d.sets) or ''),4,-56,86,14,'GameFontHighlightSmall');n:SetJustifyH('CENTER')
        W.tooltip(t,d.name..'\n'..fmt(d.amount)..' '..d.unit..' today in '..d.sets..(d.sets==1 and ' log' or ' logs'))
    end
    if #items==0 then W.text(doneBox,'none','Nothing logged yet today. Press “Done” on a reminder or “Log a workout”.',12,-36,500,20,'GameFontDisableSmall') end
    heading(p,'nextHead','Today’s reminders',0,-302)
    local upcoming=W.section(p,'nextBox',530,218,0,-322)
    local nb=list(upcoming,'nextList',8,-8,508,202);local n=0
    local function upcomingRow(key,r,title,status)
        n=n+1;local row=card(nb,key,n,504,40,iconOf(r.activityID),title,fmt(r.amount)..' '..r.unit..' · '..(status or progress(r)))
        row.texts.title:SetWidth(330);row.texts.sub:SetWidth(330)
        local b=W.button(row,'now','Now',432,-8,64,function()
            local o,err=e:runNow(r.id);if not o then ZZ.Print(err) end;self:refresh();self:updatePrompt()
        end)
        W.tooltip(b,'Start this reminder now. Logging it counts as usual.')
    end
    -- Every timed reminder of today stays listed, also after its time, with its state.
    local paused=e.db.settings.paused
    local timed={}
    for _,r in pairs(e.db.rules) do if (r.kind=='daily' or r.kind=='once') and e:eligible(r,now) then timed[#timed+1]=r end end
    table.sort(timed,function(a,b) return a.at==b.at and a.id<b.id or a.at<b.at end)
    for _,r in ipairs(timed) do
        local o=e.db.occurrences[r.id..':'..now.day]
        local status
        if o then status=o.status=='pending' and (W.GOLD..'Due now|r') or o.status=='completed' and (W.GREEN..'Done for today|r') or (W.GREY..'Skipped today|r')
        elseif paused then status=W.GREY..'Paused'..(r.at<=now.minute and ' · not started|r' or '|r')
        elseif r.at<=now.minute then status=W.GOLD..'Starting…|r' end
        upcomingRow('next'..r.id,r,C.clock(r.at)..'  '..r.activity,status)
        if o and o.status~='pending' then nb.pool['next'..r.id].pool.now:Hide() end
    end
    -- Reminders before WoW calendar events: one row for each matching event of today.
    for _,r in ipairs(sorted(e.db.rules)) do
        if r.kind=='calendar' and e:eligible(r,now) then
            for _,ev in ipairs(e.calendarEvents or {}) do
                if ev.day==now.day and ev.minute and ev.key and C.calendarMatch(r.calMatch,ev) then
                    local o=e.db.occurrences[r.id..':'..now.day..':'..ev.key]
                    local status=o and (o.status=='pending' and (W.GOLD..'Due now|r') or o.status=='completed' and (W.GREEN..'Done|r') or (W.GREY..'Skipped|r'))
                        or (now.minute>ev.minute-r.lead+15 and W.GREY..'Missed|r') or (paused and W.GREY..'Paused|r') or nil
                    upcomingRow('cal'..r.id..ev.key,r,C.clock(math.max(0,ev.minute-r.lead))..'  '..r.activity..' · before '..ev.title,status)
                    if o and o.status~='pending' then nb.pool['cal'..r.id..ev.key].pool.now:Hide() end
                end
            end
        end
    end
    local weekday=tostring(C.weekday(now.day))
    for _,r in ipairs(sorted(e.db.rules)) do
        if r.enabled and not r.retired and r.kind=='interval' and r.days:find(weekday,1,true) and now.minute<r.windowEnd then
            -- Repeating reminders always stay listed; their state changes, not their presence.
            local left=math.max(0,math.ceil((r.interval*60-(r.elapsed or 0))/60))
            local waiting=e:pending(r.id)
            local resting=r.stopAtGoal and not e:eligible(r,ZZ.Now()) and now.minute>=r.windowStart
            local when=waiting and 'Due now' or paused and 'Paused' or resting and 'Resting' or now.minute<r.windowStart and ('From '..C.clock(r.windowStart)) or ('In ~'..left..' min')
            upcomingRow('every'..r.id,r,when..'  '..r.activity..' · every '..r.interval..' min',waiting and progress(r) or nil)
        end
    end
    if n==0 then W.text(nb,'none','Nothing else is scheduled for today.',4,-6,480,20,'GameFontDisableSmall');nb:SetHeight(30) end
    -- Right column: actions, goals and the week strip.
    local x=550
    W.button(p,'log','Log a workout',x,0,310,function() self:logDialog(today()) end)
    W.button(p,'add','New reminder',x,-28,310,function() self:ruleDialog() end)
    W.button(p,'challenge','Send a challenge',x,-56,310,function() self:challengeDialog() end)
    W.chip(p,'pause',paused and 'Reminders paused · click to resume' or 'Reminders on · click to pause',x,-86,310,paused,function()
        e.db.settings.paused=not e.db.settings.paused;ZZ.UpdateMinimap();self:refresh();self:updatePrompt()
    end)
    heading(p,'goalHead','Goals and challenges',x,-116)
    local goals=W.section(p,'goalBox',310,196,x,-134)
    local gb=list(goals,'goalList',8,-8,276,180);local g=0
    -- Challenges come first: open invitations with Accept, then accepted ones with a progress bar.
    for _,ch in ipairs(e:challengeList(now.day)) do
        if ch.finish>=now.day and not ch.ignored then
            g=g+1;local row=W.section(gb,'ch'..ch.id,272,44,0,-(g-1)*48,0.3);W.reset(row)
            row:SetBackdropBorderColor(1,0.5,0.25,1)
            W.icon(row,'icon',U.challengeIcon(ch),30,7,-7)
            if ch.accepted then
                local value=e:challengeProgress(ch);local done=value>=ch.amount
                W.text(row,'title','|cffff9050Challenge|r · '..ch.activity..(ch.mine and '' or (' · '..ch.fromName)),42,-6,224,14,'GameFontNormalSmall')
                W.bar(row,'bar',42,-23,222,14,value,ch.amount,fmt(value)..' / '..fmt(ch.amount)..' '..ch.unit..(ch.start==ch.finish and ' today' or (' · until '..ch.finish:sub(6))),done and 0.2 or 1,done and 0.8 or 0.5,done and 0.2 or 0.15)
            else
                W.text(row,'title','|cffff9050'..ch.fromName..' challenges you|r',42,-6,170,14,'GameFontNormalSmall')
                W.text(row,'what',C.challengeLabel(ch),42,-23,170,14,'GameFontHighlightSmall')
                W.button(row,'accept','Accept',206,-10,58,function() self:challengeOffer(nil,ch.id) end)
            end
            gb:SetHeight(g*48)
        end
    end
    for _,s in ipairs(state.goals) do
        g=g+1;local row=W.section(gb,'goal'..s.goal.id,272,44,0,-(g-1)*48,0.3);W.reset(row)
        W.icon(row,'icon',iconOf(s.goal.activityID),30,7,-7)
        W.text(row,'title',s.goal.activity..(s.goal.period=='week' and ' · this week' or ' · today'),42,-6,224,14,'GameFontNormalSmall')
        local done=s.status=='Completed'
        W.bar(row,'bar',42,-23,222,14,s.value,s.goal.amount,fmt(s.value)..' / '..fmt(s.goal.amount)..' '..s.goal.unit,done and 0.2 or 0.95,done and 0.8 or 0.7,done and 0.2 or 0.1)
        gb:SetHeight(g*48)
    end
    if g==0 then W.text(gb,'none','No goals yet. Tick “Goal” in a reminder, or send a challenge to your guild.',4,-6,268,40,'GameFontDisableSmall');gb:SetHeight(44) end
    heading(p,'weekHead','This week',x,-334)
    local week=W.section(p,'weekBox',310,140,x,-354);W.reset(week)
    local first,last=C.period(now.day,'week');local days,totals=logsBetween(first,last);local active=0
    for d=1,7 do
        local day=C.addDays(first,d-1);local did=days[day]~=nil;if did then active=active+1 end
        local cell=W.flat(week,'d'..d,38,46,10+(d-1)*41,-10,day==now.day,nil);W.reset(cell)
        local t=W.text(cell,'name',W.DAY_NAMES[d]:sub(1,2),0,-4,38,12,'GameFontHighlightSmall');t:SetJustifyH('CENTER')
        if did then W.tex(cell,'mark',READY,18,18,10,-20) elseif day<now.day and day>=(e.db.since or day) then W.tex(cell,'mark',NOTREADY,14,14,12,-22):SetAlpha(0.35) end
    end
    -- One exercise per line, so the box never overflows; the tooltip has the full list.
    local rows={};for k,v in pairs(totals) do local a,u=k:match('^(.*)|(%a+)$');rows[#rows+1]={a=a,text=a..': '..fmt(v)..' '..u} end
    table.sort(rows,function(a,b) return a.a<b.a end)
    local all,shown={},{};for k,r in ipairs(rows) do all[k]=r.text;if k<=3 or (k==4 and #rows==4) then shown[#shown+1]=r.text end end
    if #rows>4 then shown[#shown+1]=W.GREY..'+'..(#rows-3)..' more (point here)|r' end
    W.text(week,'sum',W.GOLD..active..' of 7 days active|r\n'..(#rows>0 and table.concat(shown,'\n') or 'Nothing logged yet this week.'),10,-62,290,72,'GameFontHighlightSmall')
    week:EnableMouse(true);W.tooltip(week,#rows>0 and ('This week\n'..table.concat(all,'\n')) or 'Nothing logged yet this week.')
end
-- EXERCISE PICKER ------------------------------------------------------------------------------
-- Tile grid shared by the reminder builder and the log form; avoids typing exact names.
function U:picker(d,x,y,w,selected,onPick,allowNew)
    local box=W.section(d,'pickerBox',w,140,x,y)
    local _,body=W.scroll(box,'grid',6,-6,w-32,128);W.reset(body)
    local picker={value=selected,tiles={}};d.picker=picker
    local function draw()
        local cols=math.floor((w-32)/72);local items=engine():activityList()
        for i,a in ipairs(items) do
            picker.tiles[a.id]=W.tile(body,'act'..a.id,68,60,((i-1)%cols)*72,-math.floor((i-1)/cols)*64,C.iconFor(a),a.name,a.id==picker.value,function()
                picker.value=a.id;draw();if onPick then onPick(a) end
            end)
        end
        local total=#items
        if allowNew then
            total=total+1;picker.tiles.new=W.tile(body,'actNew',68,60,((total-1)%cols)*72,-math.floor((total-1)/cols)*64,'Interface\\PaperDollInfoFrame\\Character-Plus','New',false,allowNew)
        end
        body:SetHeight(math.ceil(total/cols)*64)
    end
    draw();return picker
end
-- LOG FORM --------------------------------------------------------------------------------------
function U:logDialog(day,logID,occurrence,activityID)
    if not self.frame then self:build() end;self.frame:Show()
    local existing=logID and engine().db.logs[logID]
    local selected=activityID or (existing and existing.activityID) or (occurrence and occurrence.activityID) or 'yoga'
    local a=activity(selected) or engine():activityList()[1]
    local d=self:dialog(logID and 'Edit workout' or 'Log a workout',640,380)
    W.text(d,'step1','What did you do?',20,-50,400,16,'GameFontNormal')
    local unit,amount
    local picker=self:picker(d,20,-68,600,a.id,function(next)
        unit:SetValue(next.unit);amount:SetText(tostring(next.amount))
    end)
    W.text(d,'step2','How much?',20,-218,200,16,'GameFontNormal')
    amount=W.stepper(d,'amount',20,-238,existing and existing.amount or occurrence and occurrence.amount or a.amount)
    unit=W.dropdown(d,'unit','',150,-217,{'reps','minutes','sessions'},existing and existing.unit or occurrence and occurrence.unit or a.unit,nil,130)
    W.text(d,'step3','When?',330,-218,200,16,'GameFontNormal')
    local performed=W.input(d,'date','',330,-217,day or today(),130)
    W.chip(d,'today','Today',470,-240,70,false,function() performed:SetText(today()) end)
    W.chip(d,'yesterday','Yesterday',544,-240,76,false,function() performed:SetText(C.addDays(today(),-1)) end)
    W.text(d,'help','Log what you really did, also workouts away from the game. Past dates count for that day,\nand matching goals update. No proof needed. You can edit or undo this later.',20,-290,600,40,'GameFontHighlightSmall')
    footer(self,d,'Save workout',function()
        local l,err=engine():saveLog({activityID=picker.value,unit=unit.value,amount=tonumber(amount:GetText()),day=performed:GetText(),occurrence=occurrence and occurrence.id},logID)
        if not l then self:error(err);return end
        if not logID then ZZ.OnLogged(l) end;self:finish()
    end)
end
-- EXERCISE FORM ---------------------------------------------------------------------------------
-- Blizzard's macro icon lists: file IDs on modern clients, names on some older ones.
local function macroIcons(kind)
    U.iconCache=U.iconCache or {}
    if U.iconCache[kind] then return U.iconCache[kind] end
    local raw,clean,seen={},{},{}
    local sources=kind=='spells' and {GetLooseMacroIcons,GetMacroIcons} or {GetLooseMacroItemIcons,GetMacroItemIcons}
    for _,fn in pairs(sources) do pcall(fn,raw) end
    for _,v in ipairs(raw) do
        if type(v)=='string' then v=tonumber(v) or v:match('([^\\/]+)$') end
        if C.validIcon(v) and not seen[v] then seen[v]=true;clean[#clean+1]=v end
    end
    U.iconCache[kind]=clean;return clean
end
U.macroIcons=macroIcons
local ICON_COLS,ICON_ROWS=14,6
function U:activityDialog(id,after)
    local a=id and activity(id)
    local d=self:dialog(a and 'Edit exercise' or 'Create an exercise',700,600)
    local name=W.input(d,'name','Name or variation',20,-50,a and a.name or '',260)
    local unit=W.dropdown(d,'unit','Measured in',290,-50,{'reps','minutes','sessions'},a and a.unit or 'reps',nil,150)
    if a then unit:Disable() else unit:Enable() end
    local amount=W.input(d,'amount','Usual amount',460,-50,a and a.amount or 10,120)
    local chosen=a and (a.icon or C.presetIcons[a.id]) or 'Spell_Nature_Strength'
    local preview=W.icon(d,'preview',C.iconPath(chosen),52,620,-44)
    W.text(d,'iconHead','Icon',20,-112,60,16,'GameFontNormal')
    local source,page=self.iconSource or 'suggested',1
    local function iconList() return source=='suggested' and C.iconChoices or macroIcons(source) end
    local draw
    local function choose(icon) chosen=icon;preview:SetTexture(C.iconPath(icon));draw() end
    draw=function()
        local icons=iconList();local per=ICON_COLS*ICON_ROWS;local pages=math.max(1,math.ceil(#icons/per))
        page=math.max(1,math.min(page,pages))
        for i,v in ipairs({{'suggested','Suggested'},{'spells','Spells & abilities'},{'items','Items'}}) do
            local available=v[1]=='suggested' or #macroIcons(v[1])>0
            local chip=W.chip(d,'src_'..v[1],v[2],70+(i-1)*134,-108,130,source==v[1],function() source=v[1];self.iconSource=source;page=1;draw() end)
            if not available then chip:Hide() end
        end
        W.chip(d,'prevPage','<',520,-108,30,false,function() page=page-1;draw() end)
        local t=W.text(d,'page',page..' / '..pages,552,-112,96,16,'GameFontHighlightSmall');t:SetJustifyH('CENTER')
        W.chip(d,'nextPage','>',650,-108,30,false,function() page=page+1;draw() end)
        for k=1,per do
            local icon=icons[(page-1)*per+k]
            local x,y=20+((k-1)%ICON_COLS)*47,-138-math.floor((k-1)/ICON_COLS)*45
            if icon then
                local tile=W.tile(d,'icon'..k,42,42,x,y,C.iconPath(icon),nil,icon==chosen,function() choose(icon) end);tile.icon=icon
            elseif d.pool['icon'..k] then d.pool['icon'..k]:Hide() end
        end
    end
    draw();d.chooseIcon=choose;d.getIcon=function() return chosen end
    local typed=W.input(d,'iconName','Or type an icon name, e.g. spell_holy_searinglight',20,-412,'',420)
    W.button(d,'useName','Use this icon',450,-433,140,function()
        local v=typed:GetText():match('([^\\/]+)$') or '';v=tonumber(v) or v:gsub('%.%a+$','')
        if not C.validIcon(v) then self:error('Use letters, numbers and _ only.');return end
        choose(v);d.error:SetText('')
    end)
    W.text(d,'help',a and 'Renaming keeps this exercise connected to its reminders, goals and history.' or 'Examples: Incline push-ups, Evening yoga, Gym.',20,-472,660,30,'GameFontHighlightSmall')
    footer(self,d,'Save exercise',function()
        local result,err
        if a then result,err=engine():renameActivity(id,name:GetText(),chosen) else result,err=engine():addActivity(name:GetText(),unit.value,tonumber(amount:GetText()),chosen) end
        if not result then self:error(err);return end
        if after then after(a or result) else self:finish() end
    end)
end
-- REMINDER BUILDER ------------------------------------------------------------------------------
-- One screen: exercise, amount, repeat type, timing, with a live sentence of the result.
function U:ruleDialog(id,seed)
    local r=C.copy(seed or id and engine().db.rules[id] or {activityID='push-ups',unit='reps',amount=10,kind='interval',interval=30})
    r.at=r.at or 1260;r.days=r.days or '1234567';r.windowStart=r.windowStart or 0;r.windowEnd=r.windowEnd or 1440
    r.interval=r.interval or 30;r.trigger=r.trigger or 'mailbox';r.cooldown=r.cooldown or 15;r.cap=r.cap or 20
    r.calMatch=r.calMatch or 'raid';r.lead=r.lead or 30
    local d=self:dialog(id and 'Edit reminder' or 'New reminder',740,624)
    local unit,amount,fields,summary,kind,picker={},nil,{},nil,r.kind,nil
    -- Goal prefill: a template/import seed carries r.goal; an edit reads the reminder's latest goal.
    local goal=r.goal and C.copy(r.goal)
    if not goal and id and not seed then
        local g=r.goalID and engine().db.goals[r.goalID]
        if g and not (g.finish and g.finish<today()) then goal={amount=g.amount,period=g.period} end
    end
    local goalBox,goalAmount,goalPeriod,stopBox
    local function spec()
        local f=fields
        local stop=f.stop and f.stop:GetText()
        return {activityID=picker.value,unit=unit.value,amount=tonumber(amount:GetText()),kind=kind,days=kind=='once' and '1234567' or (f.days and f.days:GetValue() or r.days),
            planDay=f.date and f.date:GetText(),windowStart=f.start and C.minutes(f.start:GetText()) or 0,
            windowEnd=f.stop and (stop=='24:00' and 1440 or C.minutes(stop)) or 1440,
            at=f.at and C.minutes(f.at:GetText()),interval=f.interval and tonumber(f.interval:GetText()),
            trigger=f.trigger and f.trigger.value,cooldown=f.cooldown and tonumber(f.cooldown:GetText()),cap=f.cap and tonumber(f.cap:GetText()),
            calMatch=f.calMatch and f.calMatch.value,lead=f.lead and tonumber(f.lead:GetText()),
            stopAtGoal=goalBox and goalBox:GetChecked() and stopBox and stopBox:GetChecked() or nil}
    end
    local function goalSpec() return goalBox and goalBox:GetChecked() and {amount=tonumber(goalAmount:GetText()),period=goalPeriod.value} or nil end
    local function update()
        if not summary then return end
        local s=spec();local a=activity(s.activityID);s.activity=a and a.name
        local ok=s.amount and (kind~='daily' and kind~='once' or s.at) and (kind~='interval' or s.interval) and (kind~='calendar' or s.lead) and (kind=='once' or s.days~='')
        local gs=goalSpec();local goalText=''
        if gs then goalText=' Goal: '..tostring(gs.amount)..' '..tostring(s.unit)..(gs.period=='week' and ' a week' or ' a day')..(s.stopAtGoal and ', then stop reminding.' or '.') end
        summary:SetText(ok and (W.GOLD..U.describe(s)..goalText..'|r') or '|cffff6060Fill in the highlighted choices to finish.|r')
    end
    W.text(d,'step1','1   Exercise',20,-48,300,16,'GameFontNormal')
    picker=self:picker(d,20,-66,700,r.activityID,function(a) unit:SetValue(a.unit);amount:SetText(tostring(a.amount));update() end,function()
        local keep=spec()
        self:activityDialog(nil,function(a) keep.activityID=a.id;keep.unit=a.unit;keep.amount=a.amount;self:ruleDialog(id,keep) end)
    end)
    W.text(d,'step2','2   Amount each time',20,-214,300,16,'GameFontNormal')
    amount=W.stepper(d,'amount',20,-234,r.amount,update)
    unit=W.dropdown(d,'unit','',150,-213,{'reps','minutes','sessions'},r.unit,update,120)
    W.text(d,'step3','3   Repeat',20,-268,300,16,'GameFontNormal')
    local dynamic=W.acquire(d,'dynamic');dynamic:SetSize(700,124);dynamic:ClearAllPoints();dynamic:SetPoint('TOPLEFT',20,-346)
    local function chipRow(parent,key,values,x,y,w,target,label)
        for i,v in ipairs(values) do
            W.chip(parent,key..i,label and label(v) or v,x+(i-1)*(w+4),y,w,target:GetText()==tostring(v),function() target:SetText(tostring(v));update() end)
        end
    end
    local function renderKind(value)
        kind=value;W.closeMenu();W.reset(dynamic);fields={}
        for i,k in ipairs(KINDS) do
            W.card(d,'kind_'..k.value,136,46,20+(i-1)*141,-286,k.icon,k.label,k.hint,k.value==kind,function() for field,v in pairs(spec()) do r[field]=v end;renderKind(k.value) end)
        end
        local times={'07:00','12:00','18:00','19:00','21:00'}
        if kind=='daily' or kind=='once' then
            fields.at=W.input(dynamic,'at','At (local time)',0,0,C.clock(r.at or 1260),110)
            chipRow(dynamic,'time',times,kind=='once' and 350 or 116,-22,54,fields.at)
            fields.at:SetScript('OnTextChanged',update)
            if kind=='once' then
                fields.date=W.input(dynamic,'date','Date (YYYY-MM-DD)',116,0,r.planDay or today(),120)
                fields.date:SetScript('OnTextChanged',update)
                W.chip(dynamic,'dtoday','Today',240,-22,50,false,function() fields.date:SetText(today());update() end)
                W.chip(dynamic,'dtomorrow','Tomorrow',294,-22,52,false,function() fields.date:SetText(C.addDays(today(),1));update() end)
            end
        elseif kind=='interval' then
            fields.interval=W.input(dynamic,'interval','Every (minutes)',0,0,r.interval,110)
            fields.interval:SetScript('OnTextChanged',update)
            chipRow(dynamic,'every',{15,20,30,45,60},116,-22,54,fields.interval,function(v) return v..' min' end)
        elseif kind=='calendar' then
            fields.calMatch=W.dropdown(dynamic,'calMatch','Which events in the WoW calendar',0,0,calendarOptions,r.calMatch,update,220)
            fields.lead=W.input(dynamic,'lead','Minutes before',240,0,r.lead,110)
            fields.lead:SetScript('OnTextChanged',update)
            chipRow(dynamic,'leadChip',{0,15,30,60},356,-22,54,fields.lead,function(v) return v..' min' end)
        else
            fields.trigger=W.dropdown(dynamic,'trigger','After this happens',0,0,triggerOptions,r.trigger,update,220)
            fields.cooldown=W.input(dynamic,'cooldown','Min. minutes apart',240,0,r.cooldown,130)
            fields.cap=W.input(dynamic,'cap','Max per day',380,0,r.cap,110)
        end
        if kind~='once' then fields.days=W.days(dynamic,'days',0,-58,r.days,update) end
        if kind=='interval' or kind=='trigger' then
            fields.start=W.input(dynamic,'start','From',486,-56,C.clock(r.windowStart),100)
            fields.stop=W.input(dynamic,'stop','Until',594,-56,r.windowEnd==1440 and '24:00' or C.clock(r.windowEnd),100)
            fields.start:SetScript('OnTextChanged',update);fields.stop:SetScript('OnTextChanged',update)
        end
        update()
    end
    local summaryBox=W.section(d,'summaryBox',700,40,20,-474,0.35)
    summary=W.text(summaryBox,'text','',10,-6,680,30,'GameFontHighlight')
    d.error:Hide();d.error=summary -- Errors replace the sentence, right where the player is looking.
    -- 4. Optional goal: e.g. 10 push-ups every 20 minutes, aiming for 100 a day.
    local function showGoal(v)
        for _,k in ipairs({'goalAmount','goalAmountminus','goalAmountplus','goalPeriod','stopAtGoal'}) do d.pool[k]:SetShown(v) end
        d.texts.stopAtGoallabel:SetShown(v);d.texts.goalHint:SetShown(not v)
    end
    goalBox=W.check(d,'useGoal','Goal',20,-526,goal~=nil,function(v) showGoal(v);update() end,60)
    W.text(d,'goalHint','Optional: aim for a total, for example 100 push-ups a day.',100,-531,500,16,'GameFontDisableSmall')
    goalAmount=W.stepper(d,'goalAmount',90,-526,goal and goal.amount or math.max(1,(r.amount or 10)*10),update)
    goalPeriod=W.dropdown(d,'goalPeriod','',226,-505,{{value='day',label='Per day'},{value='week',label='Per week'}},goal and goal.period or 'day',update,120)
    stopBox=W.check(d,'stopAtGoal','Stop reminding once reached',360,-526,goal==nil or r.stopAtGoal==true,update,250)
    showGoal(goal~=nil)
    renderKind(kind)
    footer(self,d,id and 'Save changes' or 'Create reminder',function()
        local result,err=engine():saveRoutine(spec(),goalSpec(),id);if not result then self:error(err);return end;self:finish()
    end)
    local test=W.button(d,'test','Test it',310,-580,120,function()
        local sp=spec();local a=activity(sp.activityID);sp.activity=a and a.name or '?'
        if not sp.amount then self:error('Enter an amount first.');return end
        self:testPrompt(sp)
    end)
    W.tooltip(test,'Show the reminder pop-up exactly as it will look. No credit, nothing saved.')
    d.getFields=function() return fields end;d.renderKind=renderKind;d.summary=summary
end
function U:goalDialog(id)
    local g=id and engine().db.goals[id] or {activityID='yoga',unit='minutes',amount=15,period='day',days='1234567'}
    local d=self:dialog(id and 'Edit goal' or 'New goal',640,470)
    W.text(d,'step1','Exercise',20,-48,300,16,'GameFontNormal')
    local unit,amount
    local picker=self:picker(d,20,-66,600,g.activityID,function(a) unit:SetValue(a.unit);amount:SetText(tostring(a.amount)) end)
    W.text(d,'step2','Target',20,-214,200,16,'GameFontNormal')
    amount=W.stepper(d,'amount',20,-234,g.amount)
    unit=W.dropdown(d,'unit','',150,-213,{'minutes','reps','sessions'},g.unit,nil,120)
    local period=W.dropdown(d,'period','',290,-213,{{value='day',label='Per day'},{value='week',label='Per week'}},g.period,nil,140)
    local days=W.days(d,'days',20,-276,g.days)
    W.text(d,'help','Weekly goals count Monday–Sunday. Edits start next day/week,\nso earlier targets and achievements stay as they were.',20,-336,600,40,'GameFontHighlightSmall')
    footer(self,d,'Save goal',function()
        local spec={activityID=picker.value,unit=unit.value,amount=tonumber(amount:GetText()),period=period.value,days=days:GetValue()}
        local result,err;if id then result,err=engine():replaceGoal(id,spec) else result,err=engine():addGoal(spec) end
        if not result then self:error(err);return end;self:finish()
    end)
end
-- ROUTINES ---------------------------------------------------------------------------------------
function U:renderRoutines(p)
    for i,name in ipairs({'Reminders','Goals','Exercises'}) do
        W.chip(p,'sub'..name,name,(i-1)*124,0,120,self.routineTab==name,function() self.routineTab=name;self:refresh() end)
    end
    local addLabel=self.routineTab=='Exercises' and 'New exercise' or self.routineTab=='Goals' and 'New goal' or 'New reminder'
    W.button(p,'add',addLabel,690,0,170,function()
        if self.routineTab=='Exercises' then self:activityDialog() elseif self.routineTab=='Goals' then self:goalDialog() else self:ruleDialog() end
    end)
    local top=-34
    if self.routineTab=='Reminders' then
        heading(p,'quickHead','Quick start · click one, adjust, save',0,top)
        for i,t in ipairs(U.TEMPLATES) do
            W.card(p,'tpl'..i,139,46,(i-1)*144,top-20,iconOf(t.spec.activityID),t.title,t.hint,false,function() self:ruleDialog(nil,t.spec) end)
        end
        top=top-78
        W.button(p,'share','Share in chat',380,top+4,150,function() self:shareDialog() end)
        W.button(p,'import','Import',536,top+4,150,function() self:importDialog() end)
        W.check(p,'archived','Show archived',0,top,self.showArchived,function(v) self.showArchived=v;self:refresh() end,200)
        top=top-30
    end
    local box=W.section(p,'listBox',FW-40,CH+top,0,top)
    local body=list(box,'routineList',8,-8,FW-74,CH-16+top);local i=0
    local w=FW-78
    if self.routineTab=='Exercises' then
        for _,a in ipairs(engine():activityList()) do
            i=i+1;local r=card(body,a.id,i,w,48,C.iconFor(a),a.name,'Usually '..fmt(a.amount)..' '..a.unit)
            W.button(r,'rename','Edit',w-100,-12,90,function() self:activityDialog(a.id) end)
        end
    elseif self.routineTab=='Goals' then
        for _,g in ipairs(sorted(engine().db.goals)) do
            i=i+1
            local state=g.finish and 'Ended '..g.finish or g.start>today() and 'Starts '..g.start or 'Active'
            local r=card(body,g.id,i,w,56,iconOf(g.activityID),g.activity..' · '..fmt(g.amount)..' '..g.unit..(g.period=='week' and ' per week' or ' per day'),state..' · '..W.daysText(g.days or '1234567'))
            if not g.finish then
                local status,value=engine():goalStatus(g,today())
                r.texts.sub:SetWidth(w-490);r.texts.title:SetWidth(w-490)
                if status then W.bar(r,'bar',w-420,-20,200,14,value,g.amount,fmt(value)..' / '..fmt(g.amount)) end
                W.button(r,'edit','Edit',w-200,-16,90,function() self:goalDialog(g.id) end)
                W.button(r,'stop','Stop',w-104,-16,94,function() engine():stopGoal(g.id);self:refresh() end)
            end
        end
    else
        for _,rule in ipairs(sorted(engine().db.rules)) do
            if not rule.retired or self.showArchived then
                i=i+1
                local state=rule.retired and W.GREY..'Archived|r' or rule.enabled and W.GREEN..'On|r' or W.GREY..'Paused|r'
                local f=card(body,rule.id,i,w,62,iconOf(rule.activityID),rule.activity..' · '..fmt(rule.amount)..' '..rule.unit..'   '..state,U.describe(rule))
                if not rule.enabled or rule.retired then f.texs.icon:SetDesaturated(true) end
                f.texts.sub:SetWidth(w-420);f.texts.title:SetWidth(w-420)
                local g=engine():ruleGoal(rule,today())
                if g then f.texts.sub:SetText(U.describe(rule)..' Goal: '..fmt(g.amount)..' '..g.unit..(g.period=='week' and ' a week' or ' a day')..(rule.stopAtGoal and ', then stop.' or '.')) end
                if not rule.retired then
                    W.button(f,'test','Test',w-360,-16,84,function() self:testPrompt(rule) end)
                    W.button(f,'pause',rule.enabled and 'Pause' or 'Resume',w-270,-16,84,function() engine():setRuleEnabled(rule.id,not rule.enabled);self:refresh() end)
                    W.button(f,'edit','Edit',w-182,-16,80,function() self:ruleDialog(rule.id) end)
                    W.button(f,'remove','Archive',w-98,-16,88,function() engine():retireRule(rule.id);self:refresh() end)
                end
            end
        end
    end
    if i==0 then
        local hint=self.routineTab=='Reminders' and 'Pick a quick start above, or use “New reminder”.' or 'Add one with the button above.'
        card(body,'empty',1,w,48,WAITING,'No '..self.routineTab:lower()..' yet',hint).texs.icon:SetTexCoord(0,1,0,1)
    end
end
-- TRIGGERS -------------------------------------------------------------------------------------
-- Every game event on one page: what it starts, and one click to add an exercise to it.
-- These are normal reminders of the kind "After a game event", so the Routines list shows them too.
U.triggerOptions=triggerOptions
function U.triggerSeed(event)
    return {activityID='push-ups',unit='reps',amount=10,kind='trigger',trigger=event,cooldown=15,cap=20,days='1234567',windowStart=0,windowEnd=1440}
end
function U:renderTriggers(p)
    local e=engine()
    heading(p,'head','When this happens in the game, do an exercise.',0,0,600)
    W.text(p,'help','Each exercise here is also a reminder in Routines. “Start now” starts the reminders of an event when the game does not detect it.',0,-20,860,16,'GameFontHighlightSmall')
    W.check(p,'archived','Show archived',700,4,self.showArchived,function(v) self.showArchived=v;self:refresh() end,160)
    local byEvent={}
    for _,r in ipairs(sorted(e.db.rules)) do
        if r.kind=='trigger' and (not r.retired or self.showArchived) then
            byEvent[r.trigger]=byEvent[r.trigger] or {};table.insert(byEvent[r.trigger],r)
        end
    end
    local box=W.section(p,'listBox',FW-40,CH-44,0,-44)
    local body=list(box,'triggerList',8,-8,FW-74,CH-60)
    local w,y=FW-78,0
    for _,t in ipairs(triggerOptions) do
        local rules=byEvent[t.value] or {}
        local active=0;for _,r in ipairs(rules) do if r.enabled and not r.retired then active=active+1 end end
        local status=ZZ.TriggerStatus and ZZ.TriggerStatus(t.value) or 'manual only'
        local detect=status=='manual only' and W.GREY..'Not detected on this client. Use “Start now”.|r' or status=='event available' and 'Automatic' or 'Automatic: '..status
        local head=W.section(body,'ev_'..t.value,w,52,0,-y,active>0 and 0.6 or 0.35);W.reset(head)
        local icon=W.icon(head,'icon',C.iconPath(t.icon),36,8,-8);icon:SetDesaturated(active==0)
        W.text(head,'title',(active>0 and W.GOLD or '|cffd8d8d8')..t.label..'|r'..(active>0 and ('   '..W.GREEN..active..' on|r') or ''),52,-9,w-330,16,'GameFontNormal')
        W.text(head,'sub',detect,52,-27,w-330,16,'GameFontHighlightSmall')
        if active>0 then
            local now=W.button(head,'start','Start now',w-268,-12,110,function() local n=e:trigger(t.value) or 0;ZZ.Print(n>0 and ('Started '..n..' reminder'..(n==1 and '' or 's')..'.') or 'Nothing started: a reminder is already waiting, rests, or reached its daily limit.');self:refresh();self:updatePrompt() end)
            W.tooltip(now,'Start the reminders for “'..t.label..'” now. Use it when the game does not detect the event. It gives no exercise credit by itself.')
        end
        W.button(head,'add','Add exercise',w-152,-12,140,function() self:ruleDialog(nil,U.triggerSeed(t.value)) end)
        y=y+56
        for _,r in ipairs(rules) do
            local state=r.retired and W.GREY..'Archived|r' or r.enabled and W.GREEN..'On|r' or W.GREY..'Paused|r'
            local row=W.section(body,'rule_'..r.id,w-40,40,40,-y,0.2);W.reset(row)
            local ri=W.icon(row,'icon',iconOf(r.activityID),28,6,-6);ri:SetDesaturated(not r.enabled or r.retired)
            W.text(row,'title',fmt(r.amount)..' '..r.unit..' of '..r.activity..'   '..state,42,-5,w-420,16,'GameFontHighlight')
            W.text(row,'sub','At most '..tostring(r.cap)..' a day, '..tostring(r.cooldown)..' min apart · '..W.daysText(r.days or ''),42,-21,w-420,14,'GameFontDisableSmall')
            if not r.retired then
                W.button(row,'test','Test',w-394,-8,70,function() self:testPrompt(r) end)
                W.button(row,'pause',r.enabled and 'Pause' or 'Resume',w-320,-8,84,function() e:setRuleEnabled(r.id,not r.enabled);self:refresh() end)
                W.button(row,'edit','Edit',w-232,-8,80,function() self:ruleDialog(r.id) end)
                W.button(row,'remove','Archive',w-148,-8,96,function() e:retireRule(r.id);self:refresh() end)
            end
            y=y+44
        end
        y=y+4
    end
    body:SetHeight(math.max(1,y))
end
-- CALENDAR ---------------------------------------------------------------------------------------
function U:shift(n)
    if self.mode=='week' then self.day=C.addDays(self.day,n*7) else
        local y,m=C.parseDay(self.month);m=m+n;if m<1 then m=12;y=y-1 elseif m>12 then m=1;y=y+1 end
        if y<1970 or y>2199 then return end;self.month=C.day(y,m,1);self.day=self.month
    end
    self:refresh()
end
local MONTHS={'January','February','March','April','May','June','July','August','September','October','November','December'}
local function longDay(day)
    local y,m,d=C.parseDay(day)
    return ({'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'})[C.weekday(day)]..', '..d..' '..MONTHS[m]..' '..y
end
function U:dayStatus(day)
    local status,icons,seen={},{},{}
    for _,e in ipairs(engine():dayDetails(day)) do
        local word=e.text:match('^(%a+)');status[word]=true
        if e.kind=='log' then
            local l=engine().db.logs[e.id]
            if not l.deleted then status.Log=true;if not seen[l.activityID] then seen[l.activityID]=true;icons[#icons+1]=iconOf(l.activityID) end end
        end
    end
    local marks={}
    if status.Completed then marks[#marks+1]='Goal met' elseif status.Log then marks[#marks+1]='Activity logged' end
    if status.Skipped or status.skipped then marks[#marks+1]='Reminder skipped' end
    if status.Unmet or status.Not then marks[#marks+1]='Goal missed' elseif status.Planned then marks[#marks+1]='Planned' end
    local mark=status.Completed and READY or (status.Unmet or status.Not) and NOTREADY or status.Planned and WAITING or nil
    return marks,mark,icons
end
function U:renderCalendar(p)
    W.button(p,'prev','<',0,0,34,function() self:shift(-1) end);W.button(p,'next','>',38,0,34,function() self:shift(1) end)
    W.button(p,'today','Today',78,0,70,function() self.day=today();self.month=self.day:sub(1,7)..'-01';self:refresh() end)
    local first=self.mode=='week' and C.period(self.day,'week') or C.addDays(self.month,1-C.weekday(self.month))
    local year,m=C.parseDay(self.month)
    W.text(p,'month',self.mode=='month' and (MONTHS[m]..' '..year) or ('Week of '..first),160,-2,240,22,'GameFontNormalLarge')
    W.chip(p,'view_month','Month',400,-1,64,self.mode=='month',function() self.mode='month';self.month=self.day:sub(1,7)..'-01';self:refresh() end)
    W.chip(p,'view_week','Week',468,-1,64,self.mode=='week',function() self.mode='week';self:refresh() end)
    for i,name in ipairs(W.DAY_NAMES) do local t=W.text(p,'weekday'..i,name,(i-1)*76,-32,74,16,'GameFontNormalSmall');t:SetJustifyH('CENTER') end
    self.cells={}
    local count=self.mode=='month' and 42 or 7;local cellH=self.mode=='month' and 60 or 140
    -- WoW calendar events (holidays, raids, invites) for the whole grid, read-only and in local time.
    local wow,wowErr={},nil
    if ZZ.Calendar then wow,wowErr=ZZ.Calendar:range(first,C.addDays(first,count-1)) end
    self.wowEvents=wow
    for i=1,count do
        local day=C.addDays(first,i-1);local marks,mark,icons=self:dayStatus(day)
        local b=W.flat(p,'day'..i,74,cellH,((i-1)%7)*76,-50-math.floor((i-1)/7)*(cellH+2),day==self.day,function() self.day=day;self:refresh() end)
        W.reset(b)
        local inMonth=self.mode=='week' or day:sub(1,7)==self.month:sub(1,7)
        if not inMonth then b:SetBackdropColor(0.04,0.035,0.03,0.85) end
        if day==today() and day~=self.day then b:SetBackdropBorderColor(0.3,0.75,1,1) end
        local color=day==today() and '|cff66ccff' or inMonth and '|cffffffff' or W.GREY
        W.text(b,'num',color..tonumber(day:sub(9,10))..'|r',6,-5,40,16,'GameFontNormal')
        if mark then W.tex(b,'mark',mark,16,16,52,-5) end
        for k=1,math.min(3,#icons) do W.icon(b,'act'..k,icons[k],18,5+(k-1)*21,-cellH+24) end
        if #icons>3 then W.text(b,'more','+'..(#icons-3),66,-cellH+20,20,14,'GameFontHighlightSmall') end
        local evs=wow[day] or {};local lines={}
        for _,ev in ipairs(evs) do lines[#lines+1]=U.wowColor(ev)..ev.title..'|r'..(ev.minute and (' · '..C.clock(ev.minute)) or '') end
        -- Month cells have room for one line above the exercise icons; week cells list up to six events.
        if #evs>0 then
            local month=self.mode=='month';local shown=month and 1 or 6
            local names={};for k=1,math.min(shown,#evs) do names[k]=U.wowColor(evs[k])..evs[k].title..'|r' end
            local more=#evs>shown and (W.GREY..(month and ' +' or '+')..(#evs-shown)..(month and '' or ' more')..'|r') or ''
            local t=W.text(b,'wow',month and (names[1]..more) or (table.concat(names,'\n')..(more~='' and ('\n'..more) or '')),5,-21,66,month and 13 or 96,'GameFontHighlightSmall')
            if t.SetWordWrap then t:SetWordWrap(not month) end
        end
        W.tooltip(b,longDay(day)..(#marks>0 and ('\n'..table.concat(marks,'\n')) or '')..(#lines>0 and ('\n\nWoW calendar\n'..table.concat(lines,'\n')) or ''))
        self.cells[i]=b
    end
    local gridBottom=-50-(count==42 and 6 or 1)*(cellH+2)
    local lx=0
    for i,item in ipairs({{READY,'Goal met'},{NOTREADY,'Goal missed'},{WAITING,'Planned'},{iconOf('push-ups'),'Exercise logged'}}) do
        W.tex(p,'legendIcon'..i,item[1],14,14,lx,gridBottom-6);if i==4 then p.texs['legendIcon'..i]:SetTexCoord(0.08,0.92,0.08,0.92) end
        W.text(p,'legend'..i,item[2],lx+18,gridBottom-7,110,14,'GameFontDisableSmall');lx=lx+128
    end
    for i,o in ipairs(periods) do
        W.chip(p,'tot'..i,o.label,(i-1)*76,gridBottom-28,72,self.totalPeriod==o.value,function() self.totalPeriod=o.value;self:refresh() end)
    end
    local summary,a,b=engine():summary(self.day,self.totalPeriod)
    local tb=list(p,'totals',310,gridBottom-26,222,CH+gridBottom-26)
    local txt=W.GOLD..a..(a~=b and (' – '..b) or '')..'|r\n'..(summary~='' and summary or 'No activity logged.')
    local _,n=txt:gsub('\n','');W.text(tb,'text',txt,0,0,210,(n+2)*14,'GameFontHighlightSmall');tb:SetHeight((n+2)*14)
    -- Selected day details.
    local x=548
    W.text(p,'date',longDay(self.day),x,-2,312,22,'GameFontNormalLarge')
    W.button(p,'log','Log a workout on this day',x,-28,312,function() self:logDialog(self.day) end)
    local box=W.section(p,'detailBox',312,370,x,-58)
    local body=list(box,'details',8,-8,276,354);self.details=body
    local i,y=0,0
    for _,e in ipairs(engine():dayDetails(self.day)) do
        local plan=e.kind=='rule' and engine().db.rules[e.id];plan=plan and plan.kind=='once' and not plan.retired and plan.planDay>=today() and plan or nil
        i=i+1;local h=(e.kind=='log' or plan) and 68 or 44;local r=W.section(body,e.kind..e.id,272,h,0,-y,0.3);W.reset(r);y=y+h+4
        local icon=e.kind=='log' and iconOf(engine().db.logs[e.id].activityID) or e.text:match('^Completed') and READY or e.text:match('^Unmet') and NOTREADY or WAITING
        local t=W.tex(r,'icon',icon,24,24,8,-8);if e.kind=='log' then t:SetTexCoord(0.08,0.92,0.08,0.92) end
        W.text(r,'text',e.text,38,-8,226,32,'GameFontHighlightSmall')
        if plan then
            local add=W.button(r,'wowAdd','Add to WoW calendar',38,-40,170,function() self:sendToWow(plan) end)
            W.tooltip(add,'Opens the WoW calendar. Right-click the day and click "Create Event": ZugZugFit fills in the title and the time. You click Create.')
        end
        if e.kind=='log' then
            local l=engine().db.logs[e.id]
            if l.deleted then t:SetDesaturated(true);W.button(r,'undo','Restore',38,-40,90,function() engine():restoreLog(l.id);self:refresh() end)
            else
                W.button(r,'edit','Edit',38,-40,70,function() self:logDialog(l.day,l.id) end)
                W.button(r,'delete','Delete',112,-40,76,function() engine():deleteLog(l.id);self:refresh() end)
            end
        end
    end
    for k,ev in ipairs(wow[self.day] or {}) do
        i=i+1;local r=W.section(body,'wow'..k,272,68,0,-y,0.3);W.reset(r);y=y+72
        W.icon(r,'icon',ev.icon or 'Interface\\Icons\\INV_Misc_Book_09',24,8,-8)
        local when=ev.minute and (C.clock(ev.minute)..(ev.realm and ev.realm~=C.clock(ev.minute) and (' (realm '..ev.realm..')') or '')) or (ev.ongoing and 'Ongoing' or 'All day')
        W.text(r,'text',U.wowColor(ev)..ev.title..'|r\nWoW calendar · '..when,38,-8,226,32,'GameFontHighlightSmall')
        if ev.minute and ev.kind=='event' then
            W.button(r,'plan','Reminder before it',38,-40,150,function()
                self:ruleDialog(nil,{activityID='push-ups',unit='reps',amount=10,kind='once',planDay=ev.day,at=math.max(0,ev.minute-30),days='1234567',windowStart=0,windowEnd=1440})
            end)
        end
    end
    if i==0 then W.text(body,'empty','Nothing planned or logged on this day.',4,-6,270,40,'GameFontDisableSmall');body:SetHeight(44) else body:SetHeight(y) end
    W.button(p,'appointments','Refresh WoW calendar',x,-434,312,function() ZZ.Calendar:invalidate();ZZ.Calendar:request();self:refresh() end)
    W.text(p,'calendarHelp',wowErr or 'WoW events show in local time. ZugZugFit reads the WoW calendar but cannot change it.',x,-462,312,30,'GameFontDisableSmall')
end
-- Holidays orange, raids and dungeons blue, other own events green, lockouts grey.
function U.wowColor(ev)
    if ev.kind=='holiday' then return '|cffff9933' elseif ev.kind~='event' then return W.GREY end
    if ev.declined then return W.GREY end
    return (ev.eventType==0 or ev.eventType==1) and '|cff66ccff' or '|cff7fff7f'
end
-- Fill in Blizzard's "Create event" window for a one-date reminder. The player clicks Create.
function U:sendToWow(r)
    local plan,err=ZZ.Calendar:prefill({title='ZugZugFit: '..fmt(r.amount)..' '..r.unit..' '..r.activity,note='Planned in ZugZugFit.',day=r.planDay,minute=r.at})
    if not plan then ZZ.Print(err);return end
    self:finish();if self.frame then self.frame:Hide() end
    ZZ.Print(string.format('In the WoW calendar, right-click %04d-%02d-%02d and click "Create Event". ZugZugFit fills in the fields. Then click Create.',plan.year,plan.month,plan.day))
end
-- GUILD ------------------------------------------------------------------------------------------
local UNIT_SHORT={reps=' reps',minutes=' min',sessions='x'}
local RANK_COLORS={'|cffffd100','|cffd0d0d0','|cffcd7f32'}
local function age(seconds)
    seconds=math.max(0,seconds)
    return seconds<60 and 'now' or seconds<3600 and math.floor(seconds/60)..'m' or seconds<86400 and math.floor(seconds/3600)..'h' or math.floor(seconds/86400)..'d'
end
function U:renderGuild(p)
    local guild=ZZ.sync;local cache=guild and guild:context()
    W.text(p,'guildname',guild and guild.guild and ('<'..guild.guild:gsub('%-[^-]*$','')..'>') or 'No guild detected',0,0,420,22,'GameFontNormalLarge')
    W.check(p,'sharing','Share my totals with this guild',440,0,cache and cache.enabled,function(v)
        local ok,err=guild:setEnabled(v);if not ok then ZZ.Print(err) end;self:refresh()
    end,220)
    W.button(p,'refresh','Sync now',740,0,120,function()
        if guild then local _,err=guild:request(true);guild:publish(true);if err then ZZ.Print(err) end end;self:refresh()
    end)
    self.guildView=self.guildView or 'board'
    W.tab(p,'view_board','Leaderboard',0,-30,130,self.guildView=='board',function() self.guildView='board';self:refresh() end,26)
    W.tab(p,'view_challenges','Challenges',134,-30,130,self.guildView=='challenges',function() self.guildView='challenges';self:refresh() end,26)
    if self.guildView=='challenges' then return self:renderChallenges(p,guild) end
    for i,o in ipairs(periods) do
        W.chip(p,'period'..i,o.label,300+(i-1)*84,-32,80,self.guildPeriod==o.value,function() self.guildPeriod=o.value;self:refresh() end)
    end
    local rows,columns,first,last={},{},today(),today()
    if guild then rows,columns,first,last=guild:board(self.guildPeriod,today()) end
    local sortValid=self.guildSort=='days' or self.guildSort=='name'
    for k=1,4 do if columns[k] and columns[k].key==self.guildSort then sortValid=true end end
    if not sortValid then self.guildSort='days' end
    ZZ.Guild.sortBoard(rows,self.guildSort)
    W.text(p,'range',first..(first~=last and (' – '..last) or ''),640,-36,220,16,'GameFontDisableSmall'):SetJustifyH('RIGHT')
    -- Your standing, like the achievement summary bar.
    local mine;for _,r in ipairs(rows) do if r.mine then mine=r end end
    -- Days so far in the period: a week on Wednesday has 3 possible days.
    local possible=0;local d=first;while d<=last and d<=today() and possible<100 do possible=possible+1;d=C.addDays(d,1) end
    possible=math.max(1,possible)
    local best=0;for _,r in ipairs(rows) do best=math.max(best,r.days) end
    local me=W.section(p,'meBox',FW-40,44,0,-60,0.45);W.reset(me)
    W.icon(me,'icon','Interface\\Icons\\Ability_Rogue_Sprint',30,8,-7)
    W.text(me,'rank',mine and (W.GOLD..'Your rank: #'..mine.rank..'|r of '..#rows) or 'Enable sharing to join the board',46,-8,260,16,'GameFontNormal')
    W.text(me,'days',mine and ('Most active days: '..best) or '',46,-24,260,14,'GameFontHighlightSmall')
    local n=mine and mine.days or 0
    W.bar(me,'bar',320,-15,520,16,n,possible,'You moved on '..n..' of '..possible..(possible==1 and ' day' or ' days'))
    -- Column headers sort the roster, like the guild roster frame.
    local cols={{key='rank',label='#',w=40},{key='name',label='Name',w=200},{key='days',label='Active days',w=144}}
    for k=1,4 do
        local c=columns[k]
        if c then local icon,name=iconByKey(c.activity);cols[#cols+1]={key=c.key,label=name,unit=c.unit,w=96,icon=icon}
        else cols[#cols+1]={key='empty'..k,label='—',w=96} end
    end
    cols[#cols+1]={key='updated',label='Updated',w=FW-40-40-200-144-4*96}
    local hx=0
    for _,c in ipairs(cols) do
        local sortable=c.key~='rank' and c.key~='updated' and not c.key:match('^empty')
        local h=W.flat(p,'col_'..c.key,c.w-2,24,hx,-110,self.guildSort==c.key,sortable and function() self.guildSort=c.key;self:refresh() end or nil);W.reset(h)
        local tx=6;if c.icon then W.icon(h,'icon',c.icon,16,4,-4);tx=22 end
        W.text(h,'label',(self.guildSort==c.key and W.GOLD or '|cffe0e0e0')..c.label..'|r',tx,-6,c.w-tx-4,14,'GameFontHighlightSmall')
        if sortable then W.tooltip(h,c.key=='days' and 'Days with at least one logged exercise in this period.\nThe board ranks by this column. Click another column to sort by it.' or (c.label..(c.unit and (' ('..c.unit..')') or '')..'\nClick to sort.')) end
        c.x=hx;hx=hx+c.w
    end
    local box=W.section(p,'boardBox',FW-40,300,0,-136,0.5)
    local body=list(box,'board',4,-4,FW-70,292)
    for i,r in ipairs(rows) do
        local row=W.acquire(body,'row'..r.id);row:SetSize(FW-72,24);row:ClearAllPoints();row:SetPoint('TOPLEFT',0,-(i-1)*24);W.reset(row)
        if r.mine then W.fill(row,'bg',0.6,0.45,0.05,0.35,FW-72,24,0,0) elseif i%2==0 then W.fill(row,'bg',1,1,1,0.05,FW-72,24,0,0) end
        local function cell(k,value,c) W.text(row,k,value,c.x+4,-5,c.w-8,14,'GameFontHighlightSmall') end
        for _,c in ipairs(cols) do
            if c.key=='rank' then cell('rank',(RANK_COLORS[r.rank] or '|cffffffff')..r.rank..'|r',c)
            elseif c.key=='name' then cell('name',(r.mine and W.GOLD or '|cffffffff')..r.name..(r.mine and ' (you)' or '')..'|r',c)
            elseif c.key=='days' then cell('days',W.GOLD..r.days..'|r',c)
            elseif c.key=='updated' then cell('updated',W.GREY..(r.mine and 'live' or age(ZZ.Now().now-r.receivedAt))..'|r',c)
            elseif not c.key:match('^empty') then cell('v'..c.key,r.values[c.key] and (fmt(r.values[c.key])..W.GREY..UNIT_SHORT[c.unit]..'|r') or W.GREY..'–|r',c) end
        end
        body:SetHeight(i*24)
    end
    if #rows<=1 then
        W.text(body,'lonely',(#rows==0 and '' or '\n')..'No guildmates on the board yet. They need ZugZugFit, sharing on, and to be online with you once.',8,-(#rows*24)-6,FW-90,40,'GameFontDisableSmall')
        body:SetHeight(#rows*24+50)
    end
    W.text(p,'status',guild and guild.status or 'Guild API unavailable.',0,-444,FW-40,16,'GameFontNormalSmall')
    W.text(p,'privacy','Honor-based and self-reported. Only daily totals are shared, never notes or times. Turning sharing off sends a best-effort\nwithdrawal; others may keep received copies. Alts on this install share one identity.',0,-464,FW-40,40,'GameFontDisableSmall')
end
-- SETTINGS ---------------------------------------------------------------------------------------
function U:renderSettings(p)
    local settings=engine().db.settings
    for i,name in ipairs({'Reminders','Announcements','Diagnostics'}) do
        W.chip(p,'section'..name,name,(i-1)*144,0,140,self.settingsTab==name,function() self.settingsTab=name;self:refresh() end)
    end
    local box=W.section(p,'settingsBox',FW-40,CH-40,0,-34);W.reset(box)
    if self.settingsTab=='Reminders' then
        W.check(box,'paused','Pause all reminders',16,-16,settings.paused,function(v) settings.paused=v;ZZ.UpdateMinimap();self:updatePrompt() end)
        W.check(box,'sound','Play a sound when a reminder appears',16,-48,settings.sound,function(v) settings.sound=v end)
        W.check(box,'minimap','Show the minimap button',16,-80,settings.minimap,function(v) settings.minimap=v;ZZ.UpdateMinimap() end)
        W.check(box,'celebrate','Play a fanfare when you reach a goal',420,-16,settings.celebrate~=false,function(v) settings.celebrate=v end)
        local snooze=W.input(box,'snooze','Default snooze (minutes)',16,-124,settings.snooze,200)
        W.button(box,'save','Save',220,-145,80,function()
            local n=tonumber(snooze:GetText());if not n or n<1 or n>1440 or n~=n then ZZ.Print('Choose 1–1440 minutes.');return end;settings.snooze=n;ZZ.Print('Snooze preference saved.')
        end)
        W.dropdown(box,'scale','Window size',340,-124,{{value=0.8,label='Small'},{value=1,label='Normal'},{value=1.2,label='Large'}},settings.scale,function(v) settings.scale=v;self:refresh() end,200)
        W.button(box,'test','Preview a reminder',16,-196,200,function() self:testPrompt() end)
        W.text(box,'help','Reminders wait during combat and while you are AFK. Intervals count active play only.\nSettings and history apply to all characters on this installation.',16,-240,800,40,'GameFontHighlightSmall')
    elseif self.settingsTab=='Announcements' then
        W.check(box,'complete','Announce completed workouts',16,-16,settings.announce,function(v) settings.announce=v end)
        W.check(box,'milestones','Announce goal milestones',16,-48,settings.milestones,function(v) settings.milestones=v end)
        W.dropdown(box,'channel','Where should announcements go?',16,-90,{{value='OFF',label='Nowhere (off)'},{value='PARTY',label='Party'},{value='GUILD',label='Guild'}},settings.channel,function(v) settings.channel=v end,300)
        local name=W.input(box,'displayName','My name on the guild board (optional)',16,-150,settings.displayName or '',320)
        W.button(box,'saveName','Save name',346,-171,120,function()
            local v=name:GetText();if #v>60 or v:find('[%c|]') then ZZ.Print('Use up to 60 ordinary characters.');return end
            settings.displayName=v;engine():changed();ZZ.Print('Display name saved.')
        end)
        W.text(box,'help','Example: “Completed 15 minutes of Yoga.”\nBackfills and corrections stay silent. Guild board sharing is a separate choice on the Guild tab.\nMessages are paced and can be unavailable during restricted gameplay.',16,-220,800,60,'GameFontHighlightSmall')
    else
        local body=list(box,'diagnostics',12,-12,FW-90,CH-110)
        W.text(body,'text',ZZ.CapabilityText()..'\n\n'..(ZZ.sync and ZZ.sync.status or ''),0,0,FW-100,400,'GameFontHighlightSmall');body:SetHeight(400)
        W.button(box,'info','Print version / build',12,-(CH-76),200,function() ZZ.PrintInfo() end)
    end
end
-- SHARE / IMPORT ---------------------------------------------------------------------------------
-- A share is one chat line. Guildmates with ZugZugFit get a link; everyone else still sees readable text.
function U:shareDialog()
    if not self.frame then self:build() end;self.frame:Show()
    local e=engine();local d=self:dialog('Share reminders in chat',660,540)
    local title=W.input(d,'title','Name of this routine (others see it in chat)',20,-50,e.db.settings.shareTitle or 'My routine',400)
    W.text(d,'pickHead','Reminders to include',20,-108,400,16,'GameFontNormal')
    local box=W.section(d,'pickBox',620,200,20,-126)
    local body=list(box,'picks',8,-8,584,184);local chosen,i={},0
    local preview,length,code
    local function update()
        local ids={};for _,rule in ipairs(sorted(e.db.rules)) do if chosen[rule.id] then ids[#ids+1]=rule.id end end
        local text,err=e:shareText(title:GetText(),ids)
        d.shareText=text
        preview:SetText(text and (W.GOLD..text:match('^(%[[^%]]+%])')..'|r') or ('|cffff6060'..tostring(err)..'|r'))
        length:SetText(text and (#text..' / '..C.SHARE_MAX..' characters') or '')
        code:SetText(text or '');d.error:SetText('')
    end
    for _,rule in ipairs(sorted(e.db.rules)) do
        if not rule.retired and rule.kind~='once' then
            i=i+1;chosen[rule.id]=rule.enabled
            local row=W.acquire(body,'row'..rule.id);row:SetSize(580,30);row:ClearAllPoints();row:SetPoint('TOPLEFT',0,-(i-1)*32);W.reset(row)
            W.check(row,'pick',' ',0,-3,chosen[rule.id],function(v) chosen[rule.id]=v;update() end,10)
            W.icon(row,'icon',iconOf(rule.activityID),22,30,-4)
            W.text(row,'text',U.describe(rule),58,-8,520,16,'GameFontHighlightSmall')
            body:SetHeight(i*32);d.pool['pick'..rule.id]=row.pool.pick
        end
    end
    if i==0 then W.text(body,'none','You have no repeating reminders to share yet.',4,-6,560,20,'GameFontDisableSmall') end
    W.text(d,'previewHead','In chat it looks like this',20,-338,400,16,'GameFontNormal')
    local pbox=W.section(d,'previewBox',620,64,20,-356,0.4)
    preview=W.text(pbox,'text','',10,-8,600,16,'GameFontHighlight')
    length=W.text(pbox,'length','',10,-40,600,14,'GameFontDisableSmall')
    code=W.input(d,'code','Or copy the code (Ctrl+C) for Discord or a note',20,-428,'',620)
    code:SetScript('OnEditFocusGained',function(self2) self2:HighlightText() end)
    title:SetScript('OnTextChanged',update)
    footer(self,d,'Put in chat',function()
        if not d.shareText then update();return end
        e.db.settings.shareTitle=title:GetText()
        local ok=ZZ.InsertChat(d.shareText)
        if ok then self:finish() else self:error('Could not open the chat box. Copy the code instead.') end
    end)
    W.text(d,'help','Choose a channel, then press Enter. Guildmates with ZugZugFit can click the link to import.',200,-500,260,30,'GameFontDisableSmall')
    update()
end
function U:importDialog(code)
    if not self.frame then self:build() end;self.frame:Show()
    local e=engine();local d=self:dialog('Import shared reminders',660,540)
    local share,err
    if code then share,err=e:decodeShare(code) end
    if not share then
        local paste=W.input(d,'paste','Paste a ZugZugFit code or chat line',20,-50,code or '',480)
        W.button(d,'preview','Preview',510,-71,130,function() self:importDialog(C.findShare(paste:GetText()) or paste:GetText()) end)
        if err then d.error:SetText(err) end
        W.text(d,'recentHead','Seen in chat this session',20,-112,400,16,'GameFontNormal')
        local box=W.section(d,'recentBox',620,330,20,-130)
        local body=list(box,'recent',8,-8,584,314)
        for i,v in ipairs(ZZ.recentShares) do
            local r=card(body,'recent'..i,i,580,48,'Interface\\Icons\\Ability_Rogue_Sprint',v.title,v.count..(v.count==1 and ' reminder' or ' reminders')..(v.sender and (' · from '..v.sender) or ''))
            r.texts.title:SetWidth(400);r.texts.sub:SetWidth(400)
            W.button(r,'open','Preview',480,-12,90,function() self:importDialog(v.code) end)
        end
        if #ZZ.recentShares==0 then W.text(body,'none','Nothing yet. When someone shares a ZugZugFit routine in a chat you can see, it appears here.',4,-6,570,30,'GameFontDisableSmall');body:SetHeight(36) end
        footer(self,d,'Preview',function() self:importDialog(C.findShare(paste:GetText()) or paste:GetText()) end)
        return
    end
    W.text(d,'name',W.GOLD..share.title..'|r',20,-50,600,20,'GameFontNormalLarge')
    W.text(d,'count',#share.rules..(#share.rules==1 and ' reminder' or ' reminders')..'. Nothing changes until you press Import.',20,-74,600,16,'GameFontHighlightSmall')
    local box=W.section(d,'listBox',620,330,20,-96)
    local body=list(box,'rules',8,-8,584,314)
    for i,spec in ipairs(share.rules) do
        local a=e:findActivity(spec.activity)
        local icon=a and C.iconFor(a) or C.iconPath(spec.icon)
        local goal=spec.goal and (' Goal: '..fmt(spec.goal.amount)..' '..spec.unit..(spec.goal.period=='week' and ' a week' or ' a day')..(spec.stopAtGoal and ', then stop.' or '.')) or ''
        local r=card(body,'rule'..i,i,580,52,icon,spec.activity..(a and '' or W.GREY..'  (new exercise)|r'),U.describe(spec)..goal)
        r.texts.sub:SetWidth(510)
    end
    local withGoals=W.check(d,'withGoals','Also import the goals',20,-436,true,function() end,300)
    footer(self,d,'Import '..#share.rules..(#share.rules==1 and ' reminder' or ' reminders'),function()
        local saved,result=e:importShare(code,withGoals:GetChecked())
        if not saved then self:error(result);return end
        ZZ.Print('Imported '..saved..' reminders from “'..result..'”. Same exercises share the same Guild board columns.')
        self.routineTab='Reminders';self.tab='Routines';self:finish()
    end)
end
-- CHALLENGES ----
function U.challengeIcon(ch)
    if ch.icon then return C.iconPath(ch.icon) end
    local a=engine():findActivity(ch.activity);return C.iconFor(a)
end
-- (section)---------------------------------------------------------------------------------
function U.myName()
    local name=engine().db.settings.displayName
    if type(name)=='string' and name~='' then return name end
    return (ZZ.SelfName():match('^[^-]+')) or 'Me'
end
function U:challengeDialog(seed)
    if not self.frame then self:build() end;self.frame:Show()
    local e=engine();seed=seed or {}
    local d=self:dialog('Send a challenge',680,520)
    local days=seed.days or 1
    local amount,preview,draw
    W.text(d,'step1','1   The move (create your own with “New”)',20,-48,500,16,'GameFontNormal')
    local picker=self:picker(d,20,-66,640,seed.activityID or 'burpees',function(a) amount:SetText(tostring(a.amount*10));draw() end,function()
        local keep={days=days,amount=tonumber(amount:GetText())}
        self:activityDialog(nil,function(a) keep.activityID=a.id;self:challengeDialog(keep) end)
    end)
    W.text(d,'step2','2   Target',20,-216,200,16,'GameFontNormal')
    local start=activity(picker.value);amount=W.stepper(d,'amount',20,-236,seed.amount or (start and start.amount*10) or 100,function() draw() end)
    W.text(d,'unit','',156,-240,100,16,'GameFontHighlightSmall')
    W.text(d,'step3','3   Time to finish',280,-216,200,16,'GameFontNormal')
    local sharing=ZZ.sync and ZZ.sync.cache and ZZ.sync.cache.enabled
    draw=function()
        local a=activity(picker.value)
        d.texts.unit:SetText(a and a.unit or '')
        for i,v in ipairs({{1,'Today'},{3,'3 days'},{7,'7 days'}}) do
            W.chip(d,'dur'..v[1],v[2],280+(i-1)*84,-238,80,days==v[1],function() days=v[1];draw() end)
        end
        local n=tonumber(amount:GetText())
        if a and n then
            local label=C.challengeLabel({amount=n,unit=a.unit,activity=a.name,start=today(),finish=C.addDays(today(),days-1)})
            preview:SetText('|cffff8040[ZugZugFit Challenge: '..label..']|r')
        else preview:SetText('|cffff6060Choose a move and a target.|r') end
    end
    W.text(d,'previewHead','In chat it looks like this',20,-284,400,16,'GameFontNormal')
    local box=W.section(d,'previewBox',640,40,20,-302,0.4)
    preview=W.text(box,'text','',10,-12,620,16,'GameFontHighlight')
    local post=W.check(d,'post',sharing and 'Also post it to the guild Challenges list' or 'Guild list needs sharing on (Guild tab); the chat link still works',20,-356,sharing,function() end,560)
    if not sharing then post:SetChecked(false);post:Disable() else post:Enable() end
    W.text(d,'help','Guildmates with ZugZugFit click the link and accept. If they do not have the move yet,\nit is added to their exercises with your name, unit and icon. You take part too.',20,-392,640,40,'GameFontHighlightSmall')
    draw()
    footer(self,d,'Send in chat',function()
        local ch,err=e:createChallenge(picker.value,tonumber(amount:GetText()),days,U.myName())
        if not ch then self:error(err);return end
        local text;text,err=e:challengeText(ch);if not text then e.db.challenges[ch.id]=nil;self:error(err);return end
        if post:GetChecked() and ZZ.sync then ZZ.sync:announceChallenge(ch,true) end
        if not ZZ.InsertChat(text) then ZZ.Print('Copy this into chat: '..text) end
        self:finish()
    end)
end
-- Offer to accept a challenge from a chat link (code) or from the lists (id).
function U:challengeOffer(code,id)
    if not self.frame then self:build() end;self.frame:Show()
    local e=engine();local ch=id and e.db.challenges[id]
    if code then
        local decoded,err=e:decodeChallenge(code)
        if not decoded then ZZ.Print(err);return end
        ch=e:rememberChallenge(decoded) or e.db.challenges[decoded.id];if not ch then ZZ.Print('Too many stored challenges.');return end
    end
    if not ch then return end
    local d=self:dialog(ch.mine and 'Your challenge' or 'Challenge from '..ch.fromName,600,360)
    W.icon(d,'icon',U.challengeIcon(ch),56,20,-52)
    W.text(d,'what','|cffff8040'..fmt(ch.amount)..' '..ch.unit..' of '..ch.activity..'|r',90,-54,490,22,'GameFontNormalLarge')
    W.text(d,'when',(ch.start==ch.finish and ('On '..ch.start) or (ch.start..' to '..ch.finish))..' · from '..ch.fromName,90,-80,490,16,'GameFontHighlight')
    local n=0;for _ in pairs(ch.participants or {}) do n=n+1 end
    W.text(d,'who',n..(n==1 and ' person' or ' people')..' took part so far.',90,-100,490,16,'GameFontHighlightSmall')
    local exists=e:findActivity(ch.activity)
    W.text(d,'move',exists and ('You already have “'..exists.name..'”. Your logs of it count.') or ('|cff66ccffNew move:|r “'..ch.activity..'” ('..ch.unit..') is added to your exercises when you accept.'),20,-140,560,32,'GameFontHighlightSmall')
    W.text(d,'help','Progress counts what you log for this move between those dates, also before you accepted.\nIt shows on Today next to your goals. Honor-based, like everything in ZugZugFit.',20,-184,560,40,'GameFontDisableSmall')
    if ch.finish<today() then d.error:SetText('This challenge has ended.') end
    footer(self,d,ch.accepted and 'Close' or 'Accept challenge',function()
        if ch.accepted then self:finish();return end
        local accepted,added=e:acceptChallenge(ch.id,U.myName())
        if not accepted then self:error(added);return end
        if ZZ.sync then ZZ.sync:announceChallenge(accepted,true) end
        ZZ.Print('Challenge accepted: '..C.challengeLabel(accepted)..(added and ' New move added to your exercises.' or ''))
        self.tab='Today';self:finish()
    end)
end
function U:renderChallenges(p,guild)
    local e=engine();local items=e:challengeList(today())
    W.button(p,'newChallenge','Send a challenge',700,-30,160,function() self:challengeDialog() end)
    if not self.challengeID or not e.db.challenges[self.challengeID] then self.challengeID=items[1] and items[1].id end
    local box=W.section(p,'challengeBox',400,470,0,-64)
    local body=list(box,'challengeList',8,-8,366,454)
    for i,ch in ipairs(items) do
        local ended=ch.finish<today()
        local n,done=0,0;for _,r in ipairs(guild and guild:challengeBoard(ch) or {}) do n=n+1;if r.done then done=done+1 end end
        local row=W.flat(body,'c'..i,362,56,0,-(i-1)*60,ch.id==self.challengeID,function() self.challengeID=ch.id;self:refresh() end);W.reset(row)
        local icon=W.icon(row,'icon',U.challengeIcon(ch),38,8,-9);icon:SetDesaturated(ended)
        W.text(row,'title',(ended and W.GREY or '|cffff9050')..fmt(ch.amount)..' '..ch.unit..' '..ch.activity..'|r',54,-9,300,16,'GameFontNormal')
        W.text(row,'sub','From '..ch.fromName..' · '..(ended and 'ended' or ch.start==ch.finish and 'today' or ('until '..ch.finish:sub(6)))..' · '..n..' took part · '..done..' done'..(ch.accepted and '' or ' · |cff66ccffopen|r'),54,-28,300,24,'GameFontHighlightSmall')
        body:SetHeight(i*60)
    end
    if #items==0 then W.text(body,'none','No challenges yet.\nSend one from Today or with the button above. Challenges from guild chat and guildmates appear here.',4,-6,356,60,'GameFontDisableSmall');body:SetHeight(60) end
    local detail=W.section(p,'challengeDetail',448,470,412,-64);W.reset(detail)
    local ch=self.challengeID and e.db.challenges[self.challengeID]
    if not ch then return end
    W.icon(detail,'icon',U.challengeIcon(ch),44,12,-12)
    W.text(detail,'title','|cffff9050'..fmt(ch.amount)..' '..ch.unit..' of '..ch.activity..'|r',66,-14,370,18,'GameFontNormalLarge')
    W.text(detail,'from','Challenged by '..ch.fromName..' · '..(ch.start==ch.finish and ch.start or (ch.start..' to '..ch.finish)),66,-36,370,16,'GameFontHighlightSmall')
    local ended=ch.finish<today()
    if not ch.accepted and not ended then W.button(detail,'accept','Accept',12,-66,120,function() self:challengeOffer(nil,ch.id) end)
    elseif ch.accepted and not ended then
        W.button(detail,'reshare','Share in chat again',12,-66,170,function()
            local text=e:challengeText(ch);if text and not ZZ.InsertChat(text) then ZZ.Print(text) end
        end)
    end
    local rows=guild and guild:challengeBoard(ch) or {}
    local done=0;for _,r in ipairs(rows) do if r.done then done=done+1 end end
    W.text(detail,'whoHead',#rows..' took part · '..done..' done',12,-102,420,16,'GameFontNormal')
    local pbody=list(detail,'people',8,-122,414,300)
    for i,r in ipairs(rows) do
        local row=W.acquire(pbody,'p'..r.id);row:SetSize(410,26);row:ClearAllPoints();row:SetPoint('TOPLEFT',0,-(i-1)*28);W.reset(row)
        if r.mine then W.fill(row,'bg',0.6,0.45,0.05,0.3,410,26,0,0) end
        W.text(row,'name',(r.mine and W.GOLD or '|cffffffff')..r.name..(r.mine and ' (you)' or '')..'|r',6,-6,140,14,'GameFontHighlightSmall')
        if r.shared then
            W.bar(row,'bar',150,-5,190,16,r.amount,ch.amount,fmt(r.amount)..' / '..fmt(ch.amount),r.done and 0.2 or 1,r.done and 0.8 or 0.5,r.done and 0.2 or 0.15)
            W.text(row,'state',r.done and (W.GREEN..'Done|r') or '',346,-6,60,14,'GameFontHighlightSmall')
        else W.text(row,'state',W.GREY..'No shared totals|r',150,-6,250,14,'GameFontHighlightSmall') end
        pbody:SetHeight(i*28)
    end
    W.text(detail,'note','Others\' progress comes from their shared daily totals (Guild sharing on).',12,-436,424,28,'GameFontDisableSmall')
end
-- CELEBRATION ------------------------------------------------------------------------------------
function U:celebrate(goal,value,title)
    local t=self.toast
    if not t then
        t=W.frame(UIParent,'ZugZugFitToast',380,84,0,0);t:ClearAllPoints();t:SetPoint('TOP',UIParent,'TOP',0,-140);t:SetFrameStrata('FULLSCREEN_DIALOG')
        t.icon=W.icon(t,'icon','Interface\\Icons\\Ability_Rogue_Sprint',48,18,-18)
        t.title=W.text(t,'title',W.GOLD..'Goal reached!|r',78,-18,290,22,'GameFontNormalLarge')
        t.body=W.text(t,'body','',78,-44,290,30,'GameFontHighlight')
        t:SetScript('OnUpdate',function(f,dt) f.left=(f.left or 0)-dt;if f.left<=0 then f:Hide() end end)
        self.toast=t
    end
    t.icon:SetTexture(iconOf(goal.activityID));t.title:SetText(W.GOLD..(title or 'Goal reached!')..'|r')
    t.body:SetText(fmt(value)..' / '..fmt(goal.amount)..' '..goal.unit..' of '..goal.activity..(goal.period=='week' and ' this week' or goal.period=='day' and ' today' or ''))
    t.left=6;t:Show()
    if engine().db.settings.celebrate~=false and PlaySound then pcall(PlaySound,888,'Master') end
    if self.frame and self.frame:IsShown() and not self.modal then self:refresh() end
end
-- PROMPT -----------------------------------------------------------------------------------------
-- One click does the obvious thing: Done logs the suggested amount, Snooze snoozes. "I did" adjusts the amount.
function U:buildPrompt()
    local p=W.frame(UIParent,'ZugZugFitPrompt',460,176,0,0);p:ClearAllPoints();p:SetPoint('CENTER',UIParent,'CENTER',0,170);p:SetFrameStrata('FULLSCREEN_DIALOG');p:EnableMouse(true);p:SetClampedToScreen(true)
    p:SetMovable(true);p:RegisterForDrag('LeftButton');p:SetScript('OnDragStart',function() p:StartMoving() end);p:SetScript('OnDragStop',function() p:StopMovingOrSizing() end)
    p:SetScript('OnUpdate',function(f,dt)
        if not f.confirm then return end
        f.confirm.left=f.confirm.left-dt
        if f.confirm.left<=0 then f.confirm=nil;f:Hide();self:updatePrompt() end
    end)
    self.prompt=p;p:Hide()
end
function U:drawPrompt(o,demo)
    if not self.prompt then self:buildPrompt() end
    local p=self.prompt;local settings=engine().db.settings;W.reset(p)
    p.occurrence=not demo and o or nil;p.demo=demo or nil;p.confirm=nil
    p.icon=W.icon(p,'icon',iconOf(o.activityID),52,20,-20)
    p.title=W.text(p,'title',demo and 'Test – no credit' or 'Zug zug! Time to move.',84,-18,350,22,'GameFontNormalLarge')
    local rule=not demo and engine().db.rules[o.rule] or (demo and o.kind and o)
    p.body=W.text(p,'body',W.GOLD..amountText(o.amount,o.unit,o.activity)..(o.note and (' · before '..o.note) or '')..'|r\n'..(demo and 'This is how it will look. The buttons only close it.' or (rule and self:progress(rule) or '')),84,-44,360,32,'GameFontHighlight')
    W.text(p,'didLabel','I did',20,-92,40,16,'GameFontNormalSmall')
    p.did=W.stepper(p,'did',56,-88,o.amount)
    W.text(p,'unit',o.unit,190,-92,60,16,'GameFontHighlightSmall')
    W.text(p,'snzLabel','Snooze',248,-92,50,16,'GameFontNormalSmall')
    for i,v in ipairs({5,30,60}) do W.chip(p,'snz'..v,v<60 and (v..' min') or '1 hour',298+(i-1)*48,-88,46,false,function() self:promptSnooze(v) end) end
    W.button(p,'log','Done',20,-128,150,function() self:promptDone() end)
    W.button(p,'snooze','Snooze '..fmt(settings.snooze)..' min',176,-128,136,function() self:promptSnooze(settings.snooze) end)
    W.button(p,'dismiss','Skip',318,-128,122,function()
        if not p.demo and p.occurrence then engine():dismiss(p.occurrence.id) end
        p.demo=nil;p:Hide();self:updatePrompt();if self.frame and self.frame:IsShown() and not self.modal then self:refresh() end
    end)
    p:Show();return p
end
function U:promptSnooze(minutes)
    local p=self.prompt
    if p.demo then p.demo=nil;p:Hide();return end
    local ok,err=engine():snooze(p.occurrence.id,minutes);if not ok then ZZ.Print(err) end
    p:Hide();self:updatePrompt();if self.frame and self.frame:IsShown() and not self.modal then self:refresh() end
end
function U:promptDone()
    local p=self.prompt
    if p.demo then p.demo=nil;p:Hide();return end
    if p.occurrence then self:quickLog(p.occurrence,tonumber(p.did:GetText())) end
end
-- Log a reminder in one step, then show "Logged!" with Undo for a few seconds.
function U:quickLog(o,amount)
    local l,err=engine():saveLog({activityID=o.activityID,unit=o.unit,amount=amount,day=today(),occurrence=o.id})
    if not l then ZZ.Print(err);return end
    ZZ.OnLogged(l)
    if not self.prompt then self:buildPrompt() end
    local p=self.prompt;W.reset(p);p.occurrence=nil;p.demo=nil
    W.icon(p,'icon',iconOf(o.activityID),52,20,-20)
    p.title=W.text(p,'title',W.GREEN..'Logged!|r',84,-18,350,22,'GameFontNormalLarge')
    local rule=engine().db.rules[o.rule]
    p.body=W.text(p,'body',W.GOLD..amountText(l.amount,l.unit,l.activity)..'|r\n'..(rule and self:progress(rule) or ''),84,-44,360,32,'GameFontHighlight')
    W.button(p,'undo','Undo',20,-128,150,function()
        engine():undoLog(l.id);ZZ.Print('Removed '..amountText(l.amount,l.unit,l.activity)..'.')
        p.confirm=nil;p:Hide();self:updatePrompt();if self.frame and self.frame:IsShown() and not self.modal then self:refresh() end
    end)
    W.button(p,'ok','OK',318,-128,122,function() p.confirm=nil;p:Hide();self:updatePrompt() end)
    p.confirm={log=l.id,left=5};p:Show()
    if self.frame and self.frame:IsShown() and not self.modal then self:refresh() end
end
function U:testPrompt(spec)
    if ZZ.InCombat() then ZZ.Print('Leave combat to preview a reminder.');return end
    self:drawPrompt(spec or {activityID='yoga',activity='Yoga',amount=15,unit='minutes'},true)
end
function U:updatePrompt()
    if not self.prompt then self:buildPrompt() end
    local p=self.prompt
    if ZZ.InCombat() or ZZ.IsAFK() then p:Hide();p.demo=nil;p.confirm=nil;return end
    if p.demo or p.confirm then return end
    local o=engine():nextPrompt();if not o then p:Hide();p.occurrence=nil;return end
    if self.modal and self.modal:IsShown() then p:Hide();return end
    if p.occurrence~=o or not p:IsShown() then
        self:drawPrompt(o)
        if engine().db.settings.sound and p.sounded~=o.id then ZZ.PlayCue();p.sounded=o.id end
    end
end
-- TEST TOOLS -------------------------------------------------------------------------------------
-- Sample mode: the window shows a full copy of your data plus many sample items, to test lists that
-- overflow. The copy is never saved. Closing the window or "/zzf sample" returns to your data.
function U:sampleMode(on)
    if on==nil then on=not self.realEngine end
    if not on then
        if not self.realEngine then return end
        ZZ.engine=self.realEngine;self.realEngine=nil;self:updatePrompt()
        if self.frame and self.frame:IsShown() then self:refresh() end
        ZZ.Print('Sample mode off. You see your own data again.');return
    end
    if self.realEngine then return end
    local e=C.new(ZZ.engine.db,ZZ.engine.clock or ZZ.Now);if not e then ZZ.Print('Sample mode could not start.');return end
    local now=ZZ.Now();local day=now.day
    local function try(fn,...) local ok,a,b=pcall(fn,...);if ok then return a,b end end
    local ids={'yoga','stretching','push-ups','burpees','gym','water','eyes','squats','plank'}
    for i,id in ipairs(ids) do
        local a=e.db.activities[id]
        if a then
            try(e.saveLog,e,{activityID=id,unit=a.unit,amount=a.amount*(1+i%3),day=day})
            try(e.addRule,e,{activityID=id,unit=a.unit,amount=a.amount,kind='daily',at=math.min(1439,now.minute+10*i),days='1234567',windowStart=0,windowEnd=1440})
        end
    end
    for i,id in ipairs({'push-ups','squats','water','eyes'}) do
        local a=e.db.activities[id]
        local r=a and try(e.saveRoutine,e,{activityID=id,unit=a.unit,amount=a.amount,kind='interval',interval=15*i,days='1234567',windowStart=0,windowEnd=1440},i<3 and {amount=a.amount*8,period='day'} or nil)
        if r and i<=3 then try(e.runNow,e,r.id) end
    end
    for _,t in ipairs({{'mailbox','push-ups'},{'quest','squats'},{'dungeon','burpees'}}) do
        local sp=U.triggerSeed(t[1]);sp.activityID=t[2];try(e.addRule,e,sp)
    end
    for i,id in ipairs({'burpees','plank'}) do
        local ch=try(e.createChallenge,e,id,i*50,i*3,U.myName())
        if ch then ch.participants.sample1={name='Thrallbro',at=now.now} end
    end
    for i,name in ipairs({'Thrallbro','Moonfeather','Grimbeard','Lysandra','Brewfist'}) do
        local code='ZC1~sample'..i..'-c1~sample'..i..'~'..name..'~'..(i==1 and 'Burpee Twist' or ids[i])..'~r~'..(i*40)..'~'..day..'~'..C.addDays(day,i)..'~'
        local ch=try(e.decodeChallenge,e,code)
        if ch then try(e.rememberChallenge,e,ch,name);if i<=3 then try(e.acceptChallenge,e,ch.id,U.myName()) end end
    end
    self.realEngine=ZZ.engine;ZZ.engine=e
    ZZ.Print('Sample mode on. Nothing you do now is saved. Type /zzf sample or close the window to leave.')
    self:show('Today')
end
-- Self-test: checks the Blizzard templates and APIs that ZugZugFit uses, then opens every page and
-- dialog in protected calls. It saves nothing. The report is in a box you can copy.
function U:selfTest()
    local rows,passed,failed={},0,0
    local function check(name,ok,detail)
        if ok then passed=passed+1 else failed=failed+1 end
        rows[#rows+1]=(ok and 'PASS  ' or 'FAIL  ')..name..(detail and detail~='' and ('  ('..tostring(detail)..')') or '')
    end
    local build=GetBuildInfo and {pcall(GetBuildInfo)} or {}
    rows[1]='ZugZugFit '..ZZ.VERSION..' · client '..tostring(build[2])..' '..tostring(build[3])..' · interface '..tostring(build[5])
    for _,t in ipairs({{'Frame','BackdropTemplate'},{'Button','UIPanelButtonTemplate'},{'Button','UIPanelCloseButton'},{'EditBox','InputBoxTemplate'},{'CheckButton','UICheckButtonTemplate'},{'ScrollFrame'},{'StatusBar'}}) do
        local ok,f=pcall(CreateFrame,t[1],nil,UIParent,t[2]);if ok and f then f:Hide() end
        check('Frame '..t[1]..(t[2] and (' + '..t[2]) or ''),ok,not ok and f or nil)
    end
    local env=_G or {}
    local function api(path)
        local v=env;for part in path:gmatch('[^%.]+') do if type(v)~='table' then return nil end;v=v[part] end;return v
    end
    for _,name in ipairs({'C_ChatInfo.SendAddonMessage','C_ChatInfo.RegisterAddonMessagePrefix','PlaySound','IsInInstance','GetInstanceInfo','C_Calendar.GetDayEvent','GetMacroIcons','GetMacroItemIcons'}) do
        check('API '..name,api(name)~=nil)
    end
    check('Chat links (click handler)',api('EventRegistry.RegisterCallback')~=nil,'without it, use Routines > Import')
    check('Chat filter',api('ChatFrameUtil.AddMessageEventFilter')~=nil or api('ChatFrame_AddMessageEventFilter')~=nil)
    -- WoW calendar: the reader, the realm offset, today's events and Blizzard's create window.
    local offset=ZZ.Calendar:offset()
    rows[#rows+1]='INFO  Realm time is '..(offset==0 and 'the same as local time' or (math.abs(offset)..' min '..(offset>0 and 'behind' or 'ahead of')..' local time'))
    ZZ.Calendar:invalidate();local evs,calErr=ZZ.Calendar:day(today())
    check('WoW calendar read',calErr==nil,calErr or (#evs..' event(s) today'))
    for _,ev in ipairs(evs) do rows[#rows+1]='INFO  WoW event: '..ev.title..' · '..(ev.minute and C.clock(ev.minute) or 'all day')..' · '..ev.kind..(ev.declined and ' · declined' or '') end
    check('WoW create-event fill-in',api('hooksecurefunc')~=nil and (api('CalendarFrame_ShowEventFrame')~=nil or api('C_AddOns.LoadAddOn')~=nil or api('LoadAddOn')~=nil),'loads Blizzard_Calendar when used')
    for line in (ZZ.CapabilityText()..'\n'):gmatch('(.-)\n') do
        local name,state=tostring(line):match('^(%l+): (.+)$')
        if name then check('Trigger '..name,state~='manual only',state) end
    end
    local wasShown=self.frame and self.frame:IsShown()
    for _,tab in ipairs(TABS) do local ok,err=pcall(self.show,self,tab);check('Page '..tab,ok,err) end
    local d=today()
    for _,t in ipairs({{'New reminder',function() self:ruleDialog() end},{'Trigger reminder',function() self:ruleDialog(nil,U.triggerSeed('mailbox')) end},
        {'Log a workout',function() self:logDialog(d) end},{'New goal',function() self:goalDialog() end},{'New exercise',function() self:activityDialog() end},
        {'Send a challenge',function() self:challengeDialog() end},{'Share',function() self:shareDialog() end},{'Import',function() self:importDialog() end}}) do
        local ok,err=pcall(t[2]);check('Dialog '..t[1],ok,err);pcall(self.finish,self)
    end
    self.tab='Today';if not wasShown and self.frame then self.frame:Hide() end
    table.insert(rows,2,'Result: '..passed..' passed, '..failed..' failed')
    ZZ.Print('Self-test: '..passed..' passed, '..failed..' failed. The report window shows the details.')
    self:show('Today')
    local box=self:dialog('Self-test report',720,540)
    local text=table.concat(rows,'\n')
    local body=list(box,'reportList',20,-52,660,400)
    local eb=W.acquire(body,'report','EditBox');eb:SetMultiLine(true);eb:SetAutoFocus(false);eb:SetFontObject(GameFontHighlightSmall)
    eb:SetWidth(650);eb:SetHeight(#rows*14+20);eb:ClearAllPoints();eb:SetPoint('TOPLEFT',0,0);eb:SetText(text)
    eb:SetScript('OnEscapePressed',function(e) e:ClearFocus() end);body:SetHeight(#rows*14+20)
    W.button(box,'copy','Select all (then Ctrl+C)',20,-470,240,function() eb:SetFocus();eb:HighlightText() end)
    W.button(box,'cancel','Close',520,-470,180,function() self:finish() end)
    self.report=text;return passed,failed
end
