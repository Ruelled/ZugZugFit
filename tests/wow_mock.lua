-- Explicit API surface mock; no arbitrary no-op fallback. This is not rendering proof.
unpack=table.unpack
local Mock={frames={},messages={},sent={},now=os.time({year=2026,month=10,day=25,hour=12}),combat=false,afk=false,auras={}}
local methods={}
local function make(kind,parent)
    local f={kind=kind,parent=parent,children={},scripts={},shown=true,width=1,height=1}
    setmetatable(f,{__index=methods});Mock.frames[#Mock.frames+1]=f
    if parent then parent.children[#parent.children+1]=f end
    return f
end
function CreateFrame(kind,_,parent) return make(kind,parent) end
function methods:CreateTexture() return make('Texture',self) end
function methods:SetTexture(v) self.texture=v end
function methods:SetTexCoord() end
function methods:SetVertexColor() end
function methods:SetDesaturated(v) self.desaturated=v end
function methods:GetCenter() return 100,100 end
function methods:GetEffectiveScale() return 1 end
function GetCursorPosition() return 200,100 end
function methods:CreateFontString() return make('FontString',self) end
function methods:SetSize(w,h) self.width=w;self.height=h;if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self,w,h) end end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetWidth(v) self.width=v end
function methods:SetHeight(v) self.height=v;if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self,self.width,v) end end
function methods:SetPoint(...) self.point={...} end
function methods:SetText(v) self.text=v end
function methods:GetText() return self.text end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false;if self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:SetShown(value) if value then self:Show() else self:Hide() end end
function methods:ClearAllPoints() self.point=nil end
function methods:GetName() return self.name end
function methods:GetFrameLevel() return self.level or 1 end
function methods:SetFrameLevel(v) self.level=v end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:HookScript(k,v) local old=self.scripts[k];self.scripts[k]=function(...) if old then old(...) end;v(...) end end
function methods:RegisterEvent(e) self.events=self.events or {};self.events[e]=true end
function methods:SetScrollChild(f) self.scrollChild=f end
function methods:SetVerticalScroll(v) self.scroll=v end
function methods:SetFocus() self.focused=true end
function methods:SetChecked(v) self.checked=v end
function methods:SetValue(v) self.barValue=v end
function methods:Enable() self.disabled=false end
function methods:Disable() self.disabled=true end
function methods:GetChecked() return self.checked end
for _,name in ipairs({'SetBackdrop','SetBackdropColor','SetBackdropBorderColor','SetJustifyH','SetFrameStrata','EnableMouse','SetScale','SetMovable','RegisterForDrag','StartMoving','StopMovingOrSizing','SetAutoFocus','SetMaxLetters','ClearFocus','SetTextColor','SetJustifyV','SetClampedToScreen','SetNormalTexture','SetHighlightTexture','RegisterForClicks','SetAlpha','SetStatusBarTexture','SetStatusBarColor','SetMinMaxValues','EnableMouseWheel','SetAllPoints','SetColorTexture','SetMultiLine','SetFontObject','HighlightText','SetTextInsets'}) do methods[name]=function() end end
function methods:Click(button) assert(self.scripts.OnClick,'Not clickable');if self.kind=='CheckButton' then self.checked=not self.checked end;self.scripts.OnClick(self,button or 'LeftButton') end
UIParent=make('Frame');UIParent:SetSize(1920,1080)
DEFAULT_CHAT_FRAME={AddMessage=function(_,s) Mock.messages[#Mock.messages+1]=s end}
SlashCmdList={}
UISpecialFrames={}
Minimap=make('Frame');Minimap:SetSize(140,140)
function time(value) return value and os.time(value) or Mock.now end
function date(...) return os.date(...) end
function InCombatLockdown() return Mock.combat end
function UnitIsAFK() return Mock.afk end
function issecretvalue(v) return type(v)=='table' and v.secret==true end
function GetRealZoneText() return Mock.zone or 'Elwynn Forest' end
function IsInGroup() return true end
function IsInInstance() return Mock.instance~=nil,Mock.instance and 'party' or 'none' end
function GetInstanceInfo() return 'Deadmines','party',1,'Normal',5,0,false,Mock.instance or 0 end
function UnitIsDeadOrGhost() return Mock.dead==true end
function IsInGuild() return Mock.guild~=false end
function GetGuildInfo() return Mock.guild~=false and (Mock.guild or 'TestGuild') or nil,'Member',1,'Realm' end
function GetNormalizedRealmName() return 'Realm' end
function UnitFullName() return 'Tester','Realm' end
function GetNumGuildMembers() return 3 end
function GetGuildRosterInfo(index) return ({'Tester-Realm','Friend-Realm','Other-Realm'})[index] end
function GetBuildInfo() return '1.15.9','12345','today',11509 end
C_GuildInfo={GuildRoster=function() end}
Enum={RegisterAddonMessagePrefixResult={Success=0,DuplicatePrefix=1},SendAddonMessageResult={Success=0}}
Settings={RegisterCanvasLayoutCategory=function(p) return {panel=p} end,RegisterAddOnCategory=function(c) Mock.category=c end}
function PlaySound() Mock.sounds=(Mock.sounds or 0)+1 end
C_ChatInfo={SendChatMessage=function(message,channel) Mock.sent[#Mock.sent+1]={message,channel} end,InChatMessagingLockdown=function() return Mock.lockdown or false end}
Mock.addonSent={}
C_ChatInfo.RegisterAddonMessagePrefix=function() return 0 end
C_ChatInfo.SendAddonMessage=function(prefix,message,channel) Mock.addonSent[#Mock.addonSent+1]={prefix,message,channel};return 0 end
C_Spell={GetSpellInfo=function(id) return {name=id==433 and 'Food' or 'Drink'} end}
C_UnitAuras={GetAuraDataByIndex=function(_,i) return Mock.auras[i] end}
function Mock.button(parent,label)
    for _,f in ipairs(parent.children) do if f.kind=='Button' and f.text==label and f:IsVisible() then return f end end
    error('Visible button missing: '..label)
end
function Mock.choose(button,value)
    button:Click()
    local menu=Mock.ZZ.W.menu
    for _,item in pairs(menu.pool.items.body.pool) do
        if item.shown and item.optionValue==value then item:Click();return end
    end
    error('Option not found: '..tostring(value))
end
Mock.chatFilters={};Mock.chatOpened={}
function ChatFrame_AddMessageEventFilter(event,fn) Mock.chatFilters[event]=fn end
function ChatFrame_OpenChat(text) Mock.chatOpened[#Mock.chatOpened+1]=text end
EventRegistry={callbacks={}}
function EventRegistry:RegisterCallback(event,fn,owner) self.callbacks[event]=function(...) return fn(owner,...) end end
function GetMacroIcons(t) for i=1,150 do t[#t+1]=100000+i end;t[#t+1]='Spell_Fire_Fire';t[#t+1]=100001 end
function GetMacroItemIcons(t) t[#t+1]='Interface\\Icons\\INV_Misc_Bag_08' end
return Mock
