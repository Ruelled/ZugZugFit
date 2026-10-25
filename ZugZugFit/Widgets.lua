local _,ZZ=...
local W={};ZZ.W=W
-- Only long-lived Classic-era texture paths: the same files exist on Era, Forever and Retail.
local WHITE='Interface\\Buttons\\WHITE8X8'
local EDGE='Interface\\Tooltips\\UI-Tooltip-Border'
W.GOLD='|cffffd100';W.GREY='|cff9d9d9d';W.GREEN='|cff40ff40'
local function acquire(parent,key,kind,template)
    parent.pool=parent.pool or {};local f=parent.pool[key]
    if not f then f=CreateFrame(kind or 'Frame',nil,parent,template);parent.pool[key]=f end
    f:Show();return f
end
W.acquire=acquire
function W.reset(parent)
    for _,f in pairs(parent.pool or {}) do f:Hide() end
    for _,f in pairs(parent.texts or {}) do f:Hide() end
    for _,f in pairs(parent.texs or {}) do f:Hide() end
end
local function place(f,w,h,x,y) f:SetSize(w,h);f:ClearAllPoints();f:SetPoint('TOPLEFT',x or 0,y or 0) end
function W.frame(parent,key,w,h,x,y)
    local f=acquire(parent,key,'Frame','BackdropTemplate');place(f,w,h,x,y)
    f:SetBackdrop({bgFile=WHITE,edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=26,insets={left=6,right=6,top=6,bottom=6}})
    f:SetBackdropColor(0.07,0.055,0.04,0.97);f:SetBackdropBorderColor(1,1,1,1);return f
end
-- Dark inset with a bronze edge, used for every grouped area.
function W.section(parent,key,w,h,x,y,alpha)
    local f=acquire(parent,key,'Frame','BackdropTemplate');place(f,w,h,x,y)
    f:SetBackdrop({bgFile=WHITE,edgeFile=EDGE,edgeSize=14,insets={left=3,right=3,top=3,bottom=3}})
    f:SetBackdropColor(0,0,0,alpha or 0.55);f:SetBackdropBorderColor(0.6,0.48,0.27,1);return f
end
function W.text(parent,key,value,x,y,w,h,style)
    parent.texts=parent.texts or {};local f=parent.texts[key]
    if not f then f=parent:CreateFontString(nil,'OVERLAY',style or 'GameFontHighlight');parent.texts[key]=f end
    f:Show();f:ClearAllPoints();f:SetPoint('TOPLEFT',x,y);f:SetWidth(w or 500);f:SetHeight(h or 28);f:SetJustifyH('LEFT');f:SetJustifyV('TOP');f:SetText(value or '');return f
end
function W.tex(parent,key,path,w,h,x,y,layer)
    parent.texs=parent.texs or {};local t=parent.texs[key]
    if not t then t=parent:CreateTexture(nil,layer or 'ARTWORK');parent.texs[key]=t end
    t:Show();t:ClearAllPoints();t:SetSize(w,h);t:SetPoint('TOPLEFT',x,y);t:SetTexture(path)
    t:SetTexCoord(0,1,0,1);t:SetVertexColor(1,1,1,1);t:SetDesaturated(false);t:SetAlpha(1);return t
end
-- Spell/item icon with the usual Blizzard crop so its baked-in border does not show.
function W.icon(parent,key,path,size,x,y)
    local t=W.tex(parent,key,path,size,size,x,y);t:SetTexCoord(0.08,0.92,0.08,0.92);return t
end
function W.fill(parent,key,r,g,b,a,w,h,x,y,layer)
    local t=W.tex(parent,key,WHITE,w,h,x,y,layer or 'BACKGROUND');t:SetVertexColor(r,g,b,a);return t
end
function W.button(parent,key,title,x,y,w,fn)
    local b=acquire(parent,key,'Button','UIPanelButtonTemplate');b:SetSize(w or 110,24);b:ClearAllPoints();b:SetPoint('TOPLEFT',x,y);b:SetText(title);b:SetScript('OnClick',fn);return b
end
-- Flat themed button: selectable tiles, chips, tabs and calendar cells share this look.
local function flat(parent,key,w,h,x,y,on,fn)
    local b=acquire(parent,key,'Button','BackdropTemplate');place(b,w,h,x,y)
    b:SetBackdrop({bgFile=WHITE,edgeFile=EDGE,edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
    b:SetBackdropColor(on and 0.32 or 0.1,on and 0.22 or 0.08,on and 0.05 or 0.06,0.92)
    if on then b:SetBackdropBorderColor(1,0.82,0,1) else b:SetBackdropBorderColor(0.45,0.36,0.22,1) end
    b:SetHighlightTexture('Interface\\Buttons\\UI-Listbox-Highlight2','ADD')
    b.on=on==true;b:SetScript('OnClick',fn);return b
end
W.flat=flat
function W.tile(parent,key,w,h,x,y,iconPath,label,on,fn)
    local b=flat(parent,key,w,h,x,y,on,fn);W.reset(b)
    if label and label~='' then
        W.icon(b,'icon',iconPath,math.min(32,h-26),(w-math.min(32,h-26))/2,-6)
        local t=W.text(b,'label',(on and W.GOLD or '|cffffffff')..label..'|r',3,-h+18,w-6,14,'GameFontHighlightSmall');t:SetJustifyH('CENTER')
    else W.icon(b,'icon',iconPath,h-10,(w-h+10)/2,-5) end
    return b
end
-- Wide choice card: icon left, title and hint right.
function W.card(parent,key,w,h,x,y,iconPath,title,hint,on,fn)
    local b=flat(parent,key,w,h,x,y,on,fn);W.reset(b)
    W.icon(b,'icon',iconPath,h-14,7,-7)
    W.text(b,'title',(on and W.GOLD or '|cffffffff')..title..'|r',h,-7,w-h-6,16,'GameFontNormalSmall')
    W.text(b,'hint',hint or '',h,-23,w-h-6,h-26,'GameFontDisableSmall')
    return b
end
function W.chip(parent,key,label,x,y,w,on,fn)
    local b=flat(parent,key,w or 60,22,x,y,on,fn);W.reset(b)
    local t=W.text(b,'label',(on and W.GOLD or '|cffd8d8d8')..label..'|r',2,-5,(w or 60)-4,14,'GameFontHighlightSmall');t:SetJustifyH('CENTER')
    return b
end
-- Blizzard-style tab hanging under the window edge.
function W.tab(parent,key,label,x,y,w,on,fn,h)
    h=h or 32;local b=flat(parent,key,w,h,x,y,on,fn);W.reset(b)
    b:SetBackdropColor(on and 0.22 or 0.06,on and 0.15 or 0.05,on and 0.04 or 0.04,1)
    local t=W.text(b,'label',(on and W.GOLD or '|cffbbbbbb')..label..'|r',4,-(h-14)/2,w-8,16,'GameFontNormal');t:SetJustifyH('CENTER')
    return b
end
-- Top tab: the selected one is taller, gold-edged, and covers the content border so it reads as attached.
function W.topTab(parent,key,label,iconPath,x,w,on,fn)
    local h=on and 38 or 32
    local b=flat(parent,key,w,h,x,on and -50 or -56,on,fn);W.reset(b)
    b:SetBackdropColor(on and 0.09 or 0.05,on and 0.07 or 0.04,on and 0.05 or 0.03,1)
    if on then W.fill(b,'join',0.09,0.07,0.05,1,w-6,8,3,-(h-8),'OVERLAY') end
    local icon=W.icon(b,'icon',iconPath,20,10,-(h-20)/2-(on and 2 or 0));icon:SetDesaturated(not on)
    W.text(b,'label',(on and W.GOLD or '|cffa0a0a0')..label..'|r',36,-(h-14)/2-(on and 2 or 0),w-42,16,'GameFontNormal')
    return b
end
function W.bar(parent,key,x,y,w,h,value,max,label,r,g,b)
    local s=acquire(parent,key,'StatusBar');place(s,w,h,x,y)
    s:SetStatusBarTexture('Interface\\TargetingFrame\\UI-StatusBar');s:SetStatusBarColor(r or 0.95,g or 0.7,b or 0.1)
    s:SetMinMaxValues(0,math.max(1,max or 1));s:SetValue(math.min(value or 0,math.max(1,max or 1)))
    W.fill(s,'bg',0.12,0.1,0.08,0.9,w,h,0,0,'BACKGROUND')
    local t=W.text(s,'label',label or '',0,-(h-12)/2,w,h,'GameFontHighlightSmall');t:SetJustifyH('CENTER');s.label=t
    return s
end
function W.input(parent,key,label,x,y,value,w)
    W.text(parent,key..'label',label,x,y,w or 240,20,'GameFontNormalSmall')
    local b=acquire(parent,key,'EditBox','InputBoxTemplate');b:SetSize((w or 240)-10,25);b:ClearAllPoints();b:SetPoint('TOPLEFT',x+5,y-21)
    b:SetAutoFocus(false);b:SetMaxLetters(100);b:SetText(tostring(value or ''));b:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
    b:SetScript('OnTextChanged',nil);return b
end
-- Amount with - / + steppers; returns the edit box so callers read one value.
function W.stepper(parent,key,x,y,value,onChange)
    local box=acquire(parent,key,'EditBox','InputBoxTemplate');box:SetSize(58,25);box:ClearAllPoints();box:SetPoint('TOPLEFT',x+34,y)
    box:SetAutoFocus(false);box:SetMaxLetters(6);box:SetText(tostring(value or ''));box:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
    box:SetScript('OnTextChanged',function() if onChange then onChange() end end)
    local function step(sign)
        local n=tonumber(box:GetText()) or 0;local delta=(n<10 or (sign<0 and n<=10)) and 1 or 5
        n=math.max(1,n+sign*delta);box:SetText(tostring(n));if onChange then onChange() end
    end
    W.chip(parent,key..'minus','-',x,y-1,28,false,function() step(-1) end)
    W.chip(parent,key..'plus','+',x+98,y-1,28,false,function() step(1) end)
    return box
end
function W.check(parent,key,label,x,y,value,fn,w)
    local b=acquire(parent,key,'CheckButton','UICheckButtonTemplate');b:SetSize(24,24);b:ClearAllPoints();b:SetPoint('TOPLEFT',x,y);b:SetChecked(value)
    W.text(parent,key..'label',label,x+28,y-5,w or 400,24,'GameFontHighlightSmall')
    b:SetScript('OnClick',function(self) fn(self:GetChecked()==true) end);return b
end
-- Scroll list without the Blizzard scroll template: mouse wheel plus a thin position bar to the right.
-- s.want keeps the wanted position, so a refresh that rebuilds the rows does not jump back to the top.
function W.scrollTo(s,value)
    local h=s:GetHeight() or 1;local full=s.body:GetHeight() or 1;local max=math.max(0,full-h)
    if value then s.want=math.max(0,math.min(value,max)) end
    local v=math.min(s.want or 0,max)
    if s.UpdateScrollChildRect then s:UpdateScrollChildRect() end
    s:SetVerticalScroll(v)
    if max<=0 then s.bar:Hide();return end
    local th=math.max(16,h*h/full);s.bar:Show();s.thumb:SetHeight(th)
    s.thumb:ClearAllPoints();s.thumb:SetPoint('TOPLEFT',0,-(h-th)*v/max)
end
function W.scroll(parent,key,x,y,w,h)
    local s=acquire(parent,key,'ScrollFrame');s:SetSize(w,h);s:ClearAllPoints();s:SetPoint('TOPLEFT',x,y)
    if not s.body then
        s.body=CreateFrame('Frame',nil,s);s:SetScrollChild(s.body);s.want=0
        s.bar=CreateFrame('Frame',nil,s)
        local track=s.bar:CreateTexture(nil,'BACKGROUND');track:SetAllPoints();track:SetColorTexture(0,0,0,0.5)
        s.thumb=s.bar:CreateTexture(nil,'ARTWORK');s.thumb:SetWidth(6);s.thumb:SetColorTexture(0.8,0.62,0.25,0.9)
        s:EnableMouseWheel(true)
        s:SetScript('OnMouseWheel',function(self,delta) W.scrollTo(self,(self.want or 0)-delta*48) end)
        s.body:SetScript('OnSizeChanged',function() W.scrollTo(s) end)
    end
    s.bar:SetSize(6,h);s.bar:ClearAllPoints();s.bar:SetPoint('TOPLEFT',w+4,0)
    s.body:SetSize(w,1);W.scrollTo(s);return s,s.body
end
function W.closeMenu() if W.menu then W.menu:Hide() end end
function W.dropdown(parent,key,label,x,y,options,value,onChange,w)
    w=w or 240
    if label~='' then W.text(parent,key..'label',label,x,y,w,20,'GameFontNormalSmall') end
    local b=W.button(parent,key,'',x,y-21,w,function(self)
        if W.menu and W.menu:IsShown() and W.menu.owner==self then W.closeMenu();return end
        local menu=W.menu or W.section(UIParent,'ZugZugFitMenu',w+28,280,0,0,0.95);W.menu=menu;menu.owner=self
        menu:Show();menu:SetClampedToScreen(true);menu:SetFrameStrata('TOOLTIP');menu:SetSize(w+28,math.min(8,#self.options)*26+16)
        menu:ClearAllPoints();menu:SetPoint('TOPLEFT',self,'BOTTOMLEFT',0,0);menu:EnableMouse(true)
        local _,body=W.scroll(menu,'items',8,-8,w-8,math.min(8,#self.options)*26);W.reset(body)
        for i,option in ipairs(self.options) do
            local v=type(option)=='table' and option.value or option
            local title=type(option)=='table' and option.label or option
            W.chip(body,'option'..i,title,0,-(i-1)*26,w-12,v==self.value,function()
                self:SetValue(v);W.closeMenu();if self.onChange then self.onChange(v) end
            end).optionValue=v
        end
        body:SetHeight(#self.options*26)
    end)
    b.options=options;b.onChange=onChange
    function b:SetValue(v)
        self.value=v;local title=tostring(v or 'Choose...')
        for _,option in ipairs(self.options) do
            local id=type(option)=='table' and option.value or option
            if id==v then title=type(option)=='table' and option.label or option end
        end
        self:SetText(title..'  v')
    end
    b:SetValue(value);return b
end
local DAY_NAMES={'Mon','Tue','Wed','Thu','Fri','Sat','Sun'}
W.DAY_NAMES=DAY_NAMES
-- Weekday toggle chips plus Every day / Weekdays / Weekends shortcuts.
function W.days(parent,key,x,y,days,onChange)
    local group=acquire(parent,key);group:SetSize(500,48);group:ClearAllPoints();group:SetPoint('TOPLEFT',x,y);group.boxes={}
    W.text(group,'label','On these days',0,0,200,16,'GameFontNormalSmall')
    local state={}
    for i=1,7 do state[i]=days:find(tostring(i),1,true)~=nil end
    local function draw()
        for i,name in ipairs(DAY_NAMES) do
            group.boxes[i]=W.chip(group,'day'..i,name:sub(1,2),(i-1)*34,-18,32,state[i],function() state[i]=not state[i];draw();if onChange then onChange() end end)
        end
        for i,preset in ipairs({{'Every day','1234567'},{'Weekdays','12345'},{'Weekends','67'}}) do
            local v=preset[2];local on=group:GetValue()==v
            W.chip(group,'preset'..i,preset[1],246+(i-1)*76,-18,72,on,function()
                for d=1,7 do state[d]=v:find(tostring(d),1,true)~=nil end;draw();if onChange then onChange() end
            end)
        end
    end
    function group:GetValue() local s='';for i=1,7 do if state[i] then s=s..i end end;return s end
    draw();return group
end
function W.daysText(days)
    if days=='1234567' then return 'Every day' elseif days=='12345' then return 'Weekdays' elseif days=='67' then return 'Weekends' end
    local names={};for i=1,7 do if days:find(tostring(i),1,true) then names[#names+1]=DAY_NAMES[i] end end
    return #names>0 and table.concat(names,', ') or 'No days'
end
function W.tooltip(frame,lines)
    frame:SetScript('OnEnter',function(self)
        if GameTooltip then GameTooltip:SetOwner(self,'ANCHOR_RIGHT');GameTooltip:SetText(lines);GameTooltip:Show() end
    end)
    frame:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
end
