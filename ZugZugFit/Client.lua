local addon, ZZ = ...
local frame=CreateFrame("Frame")
ZZ.frame=frame
local ready=false
local members={}
local prefixReady=false
local uiRefresh=0
local caps={};local queue={};local lastSent=0
local eating,drinking,aurasInitialized=false,false,false
local zone,mailOpen,settleUntil=nil,false,0
local lastSignal={}
local calendarAt
-- One dungeon visit: boss kills inside it, and whether "dungeon" already fired for it.
local run=nil
local function readable(v) return not (issecretvalue and issecretvalue(v)) end
ZZ.Readable=readable
function ZZ.Print(msg) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd100ZugZugFit:|r "..tostring(msg)) end end
function ZZ.Now()
    local now=time();local t=date("*t",now)
    return {now=now,day=ZZ.Core.day(t.year,t.month,t.day),minute=t.hour*60+t.min}
end
function ZZ.InCombat() return InCombatLockdown and InCombatLockdown() or false end
function ZZ.IsAFK()
    if not UnitIsAFK then return false end
    local ok,v=pcall(UnitIsAFK,"player");return not ok or not readable(v) or v==true
end
function ZZ.PlayCue() if PlaySound then pcall(PlaySound,8959,"Master") end end
local events={PLAYER_DEAD="death",MAIL_SHOW="mailbox",QUEST_TURNED_IN="quest",ZONE_CHANGED_NEW_AREA="zone",
    PLAYER_EQUIPMENT_CHANGED="gear",PLAYER_LEVEL_UP="level",UNIT_SPELLCAST_SUCCEEDED="hearthstone",LFG_COMPLETION_REWARD="dungeon"}
local function register(event)
    local ok=pcall(frame.RegisterEvent,frame,event);return ok
end
function ZZ.CapabilityText()
    local rows={"Automatic triggers (registered API; live compatibility unverified):"}
    for _,name in ipairs({"death","mailbox","quest","zone","gear","level","hearthstone","dungeon","eating","drinking"}) do
        rows[#rows+1]=name..": "..(caps[name] or "manual only")
    end
    return table.concat(rows,"\n").."\nDungeon: fires on a queued or Mythic+ completion, or when you leave a 5-player dungeon after a boss kill.\nEating/drinking: recognized Food/Drink auras only; restricted data is ignored."
end
function ZZ.TriggerStatus(name) return caps[name] or "manual only" end
local function signal(name)
    local now=ZZ.Now().now
    -- Coalesce duplicate event delivery independently of the user-configured cooldown.
    if lastSignal[name] and now-lastSignal[name]<2 then return end
    lastSignal[name]=now;ZZ.engine:trigger(name)
end
local function partyInstance()
    if not IsInInstance then return nil end
    local ok,inside,kind=pcall(IsInInstance)
    if not ok or not readable(inside) or not readable(kind) or not inside or kind~="party" then return nil end
    local id=GetInstanceInfo and select(8,GetInstanceInfo())
    return readable(id) and id or 0
end
local function dungeonDone()
    if run then if run.fired then return end;run.fired=true end
    signal("dungeon")
end
-- Called on each loading screen. Leaving a 5-player dungeon after a boss kill counts as a clear;
-- a release to the graveyard does not, because the player comes back for the same run.
local function checkDungeon()
    local id=partyInstance()
    if id then if not run or run.id~=id then run={id=id,kills=0} end;return end
    if not run then return end
    local ok,dead=pcall(UnitIsDeadOrGhost or function() return false end,"player")
    if ok and readable(dead) and dead then return end
    if run.kills>0 then dungeonDone() end
    run=nil
end
local function spellName(id)
    local fn=C_Spell and C_Spell.GetSpellInfo
    if fn then
        local ok,v=pcall(fn,id)
        if ok and readable(v) and type(v)=="table" and readable(v.name) then return v.name end
    elseif GetSpellInfo then local ok,v=pcall(GetSpellInfo,id);if ok and readable(v) then return v end end
end
local function scanAuras()
    if ZZ.InCombat() then return end
    local fn=C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not fn and UnitBuff then
        fn=function(unit,index) local name=UnitBuff(unit,index);return name and {name=name} or nil end
    end
    if not fn then return end
    local foodName,drinkName=spellName(433),spellName(430)
    if not foodName or not drinkName then return end
    local food,drink=false,false
    for i=1,40 do
        local ok,a=pcall(fn,"player",i,"HELPFUL")
        if not ok or not readable(a) then return end
        if not a then break end
        if not readable(a.name) then return end
        food=food or a.name==foodName;drink=drink or a.name==drinkName
    end
    if aurasInitialized then
        if food and not eating then signal("eating") end
        if drink and not drinking then signal("drinking") end
    end
    eating,drinking,aurasInitialized=food,drink,true
end
local function enqueue(key,message,category)
    local s=ZZ.engine.db.settings
    if s.channel=="OFF" then return end
    for _,v in ipairs(queue) do if v.key==key then return end end
    if #queue>=10 then return end
    queue[#queue+1]={key=key,message=message,category=category,channel=s.channel,expires=ZZ.Now().now+120}
end
function ZZ.OnLogged(log)
    ZZ.Print("Logged "..log.amount.." "..log.unit.." of "..log.activity.." on "..log.day..".")
    if log.origin=="backfill" or log.day~=ZZ.Now().day or log.revision~=1 or log.announcementHandled then return end
    log.announcementHandled=true
    local s=ZZ.engine.db.settings
    if s.announce then enqueue(log.id,"Completed "..log.amount.." "..log.unit.." of "..log.activity..".","announce") end
    for _,ch in pairs(ZZ.engine.db.challenges) do
        if ch.accepted and not ch.completed and log.day>=ch.start and log.day<=ch.finish and log.unit==ch.unit
            and (log.activityID==ch.activityID or ZZ.Core.activityKey(log.activity)==ZZ.Core.activityKey(ch.activity)) then
            local value=ZZ.engine:challengeProgress(ch)
            if value>=ch.amount then
                ch.completed=log.day
                ZZ.UI:celebrate({activityID=ch.activityID,activity=ch.activity,unit=ch.unit,amount=ch.amount},value,'Challenge complete!')
            end
        end
    end
    for _,g in pairs(ZZ.engine.db.goals) do
        local state,value,first=ZZ.engine:goalStatus(g,log.day)
        if state=="Completed" and log.activity==g.activity and log.unit==g.unit and value-log.amount<g.amount then
            local key=g.id..":"..first
            -- The celebration is local and always on; the public milestone message stays opt-in.
            if not ZZ.engine.db.milestones[key] then
                ZZ.engine.db.milestones[key]=true;ZZ.UI:celebrate(g,value)
                if s.milestones then enqueue(key,"Reached my "..g.period.." goal: "..g.amount.." "..g.unit.." of "..g.activity.."!","milestones") end
            end
        end
    end
end
function ZZ.FlushAnnouncements()
    local now=ZZ.Now().now;local s=ZZ.engine.db.settings
    while queue[1] and (queue[1].expires<now or s.channel~=queue[1].channel or not s[queue[1].category]) do table.remove(queue,1) end
    if not queue[1] or now-lastSent<60 or ZZ.InCombat() then return end
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
        local ok,v=pcall(C_ChatInfo.InChatMessagingLockdown);if not ok or not readable(v) or v then return end
    end
    local item=queue[1]
    if item.channel=="GUILD" and (not IsInGuild or not IsInGuild()) then table.remove(queue,1);return end
    if item.channel=="PARTY" and (not IsInGroup or not IsInGroup()) then table.remove(queue,1);return end
    local fn=C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
    if not fn then table.remove(queue,1);return end
    table.remove(queue,1);lastSent=now
    local ok=pcall(fn,"[ZugZugFit] "..item.message,item.channel)
    if not ok then ZZ.Print("Announcement unavailable in this context; activity is still saved.") end
end
local function normalize(name)
    if not readable(name) or type(name)~='string' then return nil end
    if not name:find('-',1,true) then
        local realm=(GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName()) or 'Unknown'
        name=name..'-'..realm:gsub('%s','')
    end
    return name
end
function ZZ.SelfName()
    local name,realm
    if UnitFullName then name,realm=UnitFullName('player') elseif UnitName then name=UnitName('player') end
    if not readable(name) or not readable(realm) then return 'Player-Unknown' end
    return normalize(realm and realm~='' and (name..'-'..realm:gsub('%s','')) or name) or 'Player-Unknown'
end
local function guildKey()
    if not GetGuildInfo then return nil end
    local ok,name,_,_,realm=pcall(GetGuildInfo,'player')
    if not ok or not readable(name) or type(name)~='string' then return nil end
    if not readable(realm) or not realm or realm=='' then realm=GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName and GetRealmName() or 'Unknown' end
    return name..'-'..realm:gsub('%s','')
end
local function refreshRoster()
    members={}
    if not GetNumGuildMembers or not GetGuildRosterInfo then return end
    local ok,n=pcall(GetNumGuildMembers)
    if not ok or not readable(n) or type(n)~='number' then return end
    for i=1,math.min(n,1000) do
        local success,name=pcall(GetGuildRosterInfo,i)
        if success then name=normalize(name);if name then members[name]=true end end
    end
end
local function chatBlocked()
    if ZZ.InCombat() or not prefixReady then return true end
    for _,name in ipairs({'InChatMessagingLockdown','AreOutgoingAddonChatMessagesRestricted'}) do
        local fn=C_ChatInfo and C_ChatInfo[name]
        if fn then local ok,v=pcall(fn);if not ok or not readable(v) or v then return true end end
    end
    return false
end
local function apiSuccess(value,enumName)
    if not readable(value) then return false end
    if value==true or value==nil then return true end
    local enumeration=Enum and Enum[enumName]
    return enumeration and ((enumeration.Success~=nil and value==enumeration.Success) or (enumName=='RegisterAddonMessagePrefixResult' and value==enumeration.DuplicatePrefix)) or false
end
local function initializeGuild()
    local registerPrefix=(C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix
    if registerPrefix then local ok,result=pcall(registerPrefix,ZZ.Guild.PREFIX);prefixReady=ok and apiSuccess(result,'RegisterAddonMessagePrefixResult') end
    register('CHAT_MSG_ADDON');register('GUILD_ROSTER_UPDATE');register('PLAYER_GUILD_UPDATE')
    refreshRoster()
    ZZ.sync=ZZ.Guild.new(ZZ.engine,{
        now=function() return ZZ.Now().now end,day=function() return ZZ.Now().day end,
        selfName=ZZ.SelfName,guild=guildKey,isMember=function(name) return members[normalize(name)]==true end,blocked=chatBlocked,
        send=function(message)
            local fn=(C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
            if not fn then return false end
            local ok,result=pcall(fn,ZZ.Guild.PREFIX,message,'GUILD')
            return ok and apiSuccess(result,'SendAddonMessageResult')
        end,
    })
end
-- Shared routines: remember codes seen in chat and show them as clickable links where the client supports addon links.
ZZ.recentShares={}
local LINK_PREFIX="addon:ZugZugFit:"
local function addonLinks() return EventRegistry and EventRegistry.RegisterCallback and true or false end
function ZZ.RememberShare(code,sender)
    local share=ZZ.engine:decodeShare(code);if not share then return end
    for i,v in ipairs(ZZ.recentShares) do if v.code==code then table.remove(ZZ.recentShares,i);break end end
    table.insert(ZZ.recentShares,1,{code=code,title=share.title,count=#share.rules,sender=sender,seen=ZZ.Now().now})
    while #ZZ.recentShares>10 do table.remove(ZZ.recentShares) end
    return share
end
-- Challenges are remembered only from people you play with, not from public channels.
local PRIVATE={CHAT_MSG_GUILD=true,CHAT_MSG_OFFICER=true,CHAT_MSG_PARTY=true,CHAT_MSG_PARTY_LEADER=true,CHAT_MSG_RAID=true,CHAT_MSG_RAID_LEADER=true,
    CHAT_MSG_INSTANCE_CHAT=true,CHAT_MSG_INSTANCE_CHAT_LEADER=true,CHAT_MSG_WHISPER=true,CHAT_MSG_WHISPER_INFORM=true}
local function chatFilter(_,event,message,sender,...)
    if not ready or not readable(message) or type(message)~='string' or not (message:find('{ZZ1~',1,true) or message:find('{ZC1~',1,true)) then return false end
    local who=readable(sender) and sender or nil
    local changed=message:gsub('%[ZugZugFit: ([^%]]-)%] {(ZZ1~[^}]+)}',function(title,code)
        local share=ZZ.RememberShare(code,who)
        if not share or not addonLinks() then return nil end
        return '|cff66ccff|H'..LINK_PREFIX..code..'|h[ZugZugFit: '..title..']|h|r'
    end)
    changed=changed:gsub('%[ZugZugFit Challenge: ([^%]]-)%] {(ZC1~[^}]+)}',function(title,code)
        local ch=ZZ.engine:decodeChallenge(code)
        if not ch then return nil end
        if PRIVATE[event] then ZZ.engine:rememberChallenge(ch,who) end
        if not addonLinks() then return nil end
        return '|cffff8040|H'..LINK_PREFIX..code..'|h[ZugZugFit Challenge: '..title..']|h|r'
    end)
    if changed~=message then return false,changed,sender,... end
    return false
end
local function initializeSharing()
    local add=(ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
    if add then
        for _,event in ipairs({'CHAT_MSG_GUILD','CHAT_MSG_OFFICER','CHAT_MSG_PARTY','CHAT_MSG_PARTY_LEADER','CHAT_MSG_RAID','CHAT_MSG_RAID_LEADER',
            'CHAT_MSG_INSTANCE_CHAT','CHAT_MSG_INSTANCE_CHAT_LEADER','CHAT_MSG_WHISPER','CHAT_MSG_WHISPER_INFORM','CHAT_MSG_SAY','CHAT_MSG_YELL','CHAT_MSG_CHANNEL'}) do
            pcall(add,event,chatFilter)
        end
    end
    if addonLinks() then
        pcall(EventRegistry.RegisterCallback,EventRegistry,'SetItemRef',function(_,link)
            if readable(link) and type(link)=='string' and link:sub(1,#LINK_PREFIX)==LINK_PREFIX then
                local code=link:sub(#LINK_PREFIX+1)
                if code:sub(1,4)=='ZC1~' then ZZ.UI:challengeOffer(code) else ZZ.UI:importDialog(code) end
            end
        end,ZZ)
    end
end
-- Put text in the chat box like an item link; the player picks the channel and presses Enter.
function ZZ.InsertChat(text)
    local active=ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
    if active and active.Insert then active:Insert(text);return true end
    local open=(ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
    if open then return pcall(open,text) end
    return false
end
function ZZ.PrintInfo()
    local version,build,_,interface='unknown','unknown',nil,'unknown'
    if GetBuildInfo then version,build,_,interface=GetBuildInfo() end
    ZZ.Print('v'..ZZ.VERSION..'; client '..tostring(version)..' / '..tostring(build)..'; interface '..tostring(interface)..'; native acceptance pending.')
end
function ZZ.UpdateMinimap()
    local b=ZZ.minimap;if not b then return end
    local settings=ZZ.engine.db.settings
    local x,y=settings.minimapX or -0.707,settings.minimapY or -0.707
    local radius=Minimap:GetWidth()/2+10
    b:ClearAllPoints();b:SetPoint('CENTER',Minimap,'CENTER',x*radius,y*radius)
    b:SetShown(settings.minimap~=false)
    b.icon:SetDesaturated(settings.paused==true)
end
local function launchers()
    if Minimap then
        -- Parent to UIParent so Retail minimap masks/overlays cannot clip the launcher.
        local b=CreateFrame('Button','ZugZugFitMinimapButton',UIParent)
        b:SetSize(32,32);b:SetFrameStrata('HIGH');b:SetFrameLevel(100);b:EnableMouse(true)
        b:SetClampedToScreen(true)
        local background=b:CreateTexture(nil,'BACKGROUND');background:SetSize(26,26);background:SetPoint('CENTER')
        background:SetTexture('Interface\\Minimap\\UI-Minimap-Background')
        local icon=b:CreateTexture(nil,'ARTWORK');icon:SetSize(20,20);icon:SetPoint('TOPLEFT',7,-5)
        icon:SetTexture('Interface\\Icons\\Ability_Rogue_Sprint');icon:SetTexCoord(0.08,0.92,0.08,0.92);b.icon=icon
        local rim=b:CreateTexture(nil,'OVERLAY');rim:SetSize(54,54);rim:SetPoint('TOPLEFT')
        rim:SetTexture('Interface\\Minimap\\MiniMap-TrackingBorder');rim:SetVertexColor(1,0.85,0.5)
        b:SetHighlightTexture('Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight','ADD')
        b:RegisterForClicks('LeftButtonUp','RightButtonUp');b:RegisterForDrag('LeftButton')
        b:SetScript('OnDragStart',function()
            if GameTooltip then GameTooltip:Hide() end
            b:SetScript('OnUpdate',function()
                local cx,cy=Minimap:GetCenter();if not cx then return end
                local px,py=GetCursorPosition();local scale=Minimap:GetEffectiveScale()
                local x,y=px/scale-cx,py/scale-cy;local length=math.sqrt(x*x+y*y)
                if length>0 then
                    ZZ.engine.db.settings.minimapX=x/length;ZZ.engine.db.settings.minimapY=y/length;ZZ.UpdateMinimap()
                end
            end)
        end)
        b:SetScript('OnDragStop',function() b:SetScript('OnUpdate',nil) end)
        b:SetScript('OnClick',function(_,button)
            if button=='RightButton' then
                ZZ.engine.db.settings.paused=not ZZ.engine.db.settings.paused
                ZZ.Print(ZZ.engine.db.settings.paused and 'Reminders paused.' or 'Reminders resumed.')
                ZZ.UpdateMinimap();ZZ.UI:updatePrompt();if ZZ.UI.frame and ZZ.UI.frame:IsShown() then ZZ.UI:refresh() end
            else ZZ.UI:show('Today') end
        end)
        ZZ.W.tooltip(b,'ZugZugFit\nLeft-click: movement journal\nRight-click: pause / resume\nDrag: move around the minimap\n/zzf minimap: show and reset position')
        ZZ.minimap=b;ZZ.UpdateMinimap()
    end
    local panel=CreateFrame('Frame');panel.name='ZugZugFit'
    ZZ.W.text(panel,'title','ZugZugFit',16,-20,500,30,'GameFontNormalLarge')
    ZZ.W.text(panel,'text','Account-wide movement reminders, journal and opt-in guild totals.',16,-65,600,50,'GameFontHighlight')
    ZZ.W.button(panel,'open','Open ZugZugFit settings',16,-130,260,function() ZZ.UI:show('Settings') end)
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local ok,category=pcall(Settings.RegisterCanvasLayoutCategory,panel,'ZugZugFit')
        if ok then pcall(Settings.RegisterAddOnCategory,category) end
    elseif InterfaceOptions_AddCategory then pcall(InterfaceOptions_AddCategory,panel) end
    ZZ.settingsPanel=panel
end
local function initialize()
    local engine,err=ZZ.Core.new(ZugZugFitDB,ZZ.Now)
    if not engine then ZZ.Print(err);return end
    ZZ.engine=engine;ZugZugFitDB=engine.db;ready=true
    engine.db.since=engine.db.since or ZZ.Now().day
    initializeGuild();initializeSharing();launchers()
    for event,name in pairs(events) do caps[name]=register(event) and "event available" or "manual only" end
    local ways={}
    if caps.dungeon=="event available" then ways[#ways+1]="queued completion" end
    if register("CHALLENGE_MODE_COMPLETED") then ways[#ways+1]="Mythic+ completion" end
    if register("ENCOUNTER_END") then ways[#ways+1]="leave a dungeon after a boss kill" end
    caps.dungeon=#ways>0 and table.concat(ways,", ") or "manual only"
    if register("CALENDAR_UPDATE_EVENT_LIST") then ZZ.Calendar:request() end
    for _,event in ipairs({"MAIL_CLOSED","PLAYER_ENTERING_WORLD","PLAYER_LEAVING_WORLD","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","UNIT_AURA"}) do register(event) end
    local aura=(C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) or UnitBuff
    caps.eating=aura and "recognized auras, out of combat" or "manual only"
    caps.drinking=caps.eating
    settleUntil=ZZ.Now().now+5
    SLASH_ZUGZUGFIT1="/zzf";SLASH_ZUGZUGFIT2="/zugzug"
    SlashCmdList.ZUGZUGFIT=function(msg)
        local raw=msg or "";msg=raw:lower()
        if msg:match("^import") and ZZ.Core.findChallenge(raw:match("^%S+%s*(.*)$") or "") then ZZ.UI:challengeOffer(ZZ.Core.findChallenge(raw:match("^%S+%s*(.*)$")))
        elseif msg:match("^import") then ZZ.UI:importDialog(ZZ.Core.findShare(raw:match("^%S+%s*(.*)$") or ""))
        elseif msg=="challenge" then ZZ.UI:challengeDialog()
        elseif msg=="share" then ZZ.UI:shareDialog()
        elseif msg=="test" then ZZ.UI:testPrompt()
        elseif msg=="selftest" then ZZ.UI:selfTest()
        elseif msg=="sample" then ZZ.UI:sampleMode()
        elseif msg=="pause" then engine.db.settings.paused=not engine.db.settings.paused;ZZ.Print(engine.db.settings.paused and "Reminders paused." or "Reminders resumed.");ZZ.UI:updatePrompt()
        elseif msg=="minimap" then engine.db.settings.minimap=true;engine.db.settings.minimapX=nil;engine.db.settings.minimapY=nil;ZZ.UpdateMinimap();ZZ.Print("Minimap button shown and position reset.")
        elseif msg=="info" then ZZ.PrintInfo()
        elseif msg=="guild" then ZZ.UI:show("Guild")
        else ZZ.UI:show() end
    end
    ZZ.Print("v"..ZZ.VERSION.." ready. Zug zug! /zzf opens your journal.")
end
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent",function(_,event,...)
    if event=="ADDON_LOADED" then if ...==addon then initialize() end;return end
    if not ready then return end
    if event=='CHAT_MSG_ADDON' then
        local prefix,message,channel,sender=...
        if readable(prefix) and readable(message) and readable(channel) and readable(sender) and prefix==ZZ.Guild.PREFIX then ZZ.sync:receive(message,channel,normalize(sender)) end
    elseif event=='GUILD_ROSTER_UPDATE' or event=='PLAYER_GUILD_UPDATE' then refreshRoster();ZZ.sync:context()
    elseif event=="PLAYER_ENTERING_WORLD" then
        settleUntil=ZZ.Now().now+5;zone=nil;mailOpen=false;aurasInitialized=false
        local roster=(C_GuildInfo and C_GuildInfo.GuildRoster) or GuildRoster
        if roster and not ZZ.InCombat() then pcall(roster) end
        refreshRoster();ZZ.sync:context();checkDungeon()
    elseif event=="CALENDAR_UPDATE_EVENT_LIST" then
        ZZ.Calendar:invalidate();calendarAt=0
        if ZZ.UI.frame and ZZ.UI.frame:IsShown() and ZZ.UI.tab=='Calendar' and not ZZ.UI.modal then ZZ.UI:refresh() end
    elseif event=="ENCOUNTER_END" then
        local success=select(5,...)
        if run and readable(success) and (success==1 or success==true) then run.kills=run.kills+1 end
    elseif event=="LFG_COMPLETION_REWARD" or event=="CHALLENGE_MODE_COMPLETED" then dungeonDone()
    elseif event=="PLAYER_LEAVING_WORLD" then settleUntil=ZZ.Now().now+3600
    elseif event=="PLAYER_REGEN_DISABLED" then ZZ.UI:updatePrompt()
    elseif event=="PLAYER_REGEN_ENABLED" then scanAuras();ZZ.UI:updatePrompt()
    elseif event=="MAIL_CLOSED" then mailOpen=false
    elseif event=="UNIT_AURA" then local unit=...;if readable(unit) and unit=="player" then scanAuras() end
    elseif event=="MAIL_SHOW" then if not mailOpen then mailOpen=true;signal("mailbox") end
    elseif event=="UNIT_SPELLCAST_SUCCEEDED" then
        local unit,_,spell=...
        if readable(unit) and readable(spell) and unit=="player" and spell==8690 then signal("hearthstone") end
    elseif event=="ZONE_CHANGED_NEW_AREA" then
        if ZZ.Now().now<settleUntil then return end
        local ok,new=pcall(GetRealZoneText)
        if ok and readable(new) and type(new)=="string" then if zone and zone~=new then signal("zone") end;zone=new end
    elseif event=="PLAYER_EQUIPMENT_CHANGED" then
        local _,equipped=...;if readable(equipped) and equipped and ZZ.Now().now>=settleUntil then signal("gear") end
    elseif events[event] then signal(events[event]) end
end)
local elapsed=0
calendarAt=0
-- Today's WoW calendar events feed the "before a WoW event" reminders; read at most every 30 seconds.
local function feedCalendar()
    local now=ZZ.Now().now
    if now-calendarAt<30 then return end
    calendarAt=now;ZZ.engine.calendarEvents=ZZ.Calendar:day(ZZ.Now().day)
end
frame:SetScript("OnUpdate",function(_,dt)
    if not ready then return end
    elapsed=elapsed+dt;if elapsed<1 then return end
    local seconds=elapsed;elapsed=0
    if ZZ.Now().now<settleUntil then return end
    if not zone and GetRealZoneText then local ok,z=pcall(GetRealZoneText);if ok and readable(z) then zone=z end end
    if not aurasInitialized then scanAuras() end
    feedCalendar();ZZ.engine:tick(seconds,ZZ.IsAFK());ZZ.UI:updatePrompt();ZZ.FlushAnnouncements();ZZ.sync:tick()
    uiRefresh=uiRefresh+seconds
    if uiRefresh>=5 then
        uiRefresh=0
        if ZZ.UI.frame and ZZ.UI.frame:IsShown() and not ZZ.UI.modal and (ZZ.UI.tab=='Today' or ZZ.UI.tab=='Guild') and not (ZZ.W.menu and ZZ.W.menu:IsShown()) then ZZ.UI:refresh() end
    end
end)
