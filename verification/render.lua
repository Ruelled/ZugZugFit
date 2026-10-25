-- Shared HTML renderer for the mock UI: records backdrop colors, templates and styles, then draws
-- frames as absolutely positioned boxes. Approximate styling; not native WoW rendering.
local R={}
function R.install()
    local methods=getmetatable(UIParent).__index
    local baseCreate=CreateFrame
    function CreateFrame(kind,name,parent,template) local f=baseCreate(kind,name,parent,template);f.template=template;return f end
    function methods:CreateFontString(_,_,style) local f=baseCreate('FontString',nil,self);f.kind='FontString';f.style=style;return f end
    function methods:SetBackdrop(b) self.backdrop=b end
    function methods:SetBackdropColor(r,g,b,a) self.bg={r,g,b,a or 1} end
    function methods:SetBackdropBorderColor(r,g,b,a) self.border={r,g,b,a or 1} end
    function methods:SetVertexColor(r,g,b,a) self.vertex={r,g,b,a or 1} end
    function methods:SetJustifyH(v) self.justify=v end
    function methods:SetMinMaxValues(a,b) self.min,self.max=a,b end
    function methods:SetDesaturated(v) self.desaturated=v end
    function methods:SetAlpha(v) self.alpha=v end
end
local ICONS={['Interface\\RaidFrame\\ReadyCheck-Ready']='✔',['Interface\\RaidFrame\\ReadyCheck-NotReady']='✖',['Interface\\RaidFrame\\ReadyCheck-Waiting']='⧗'}
local function rgba(c,alpha) return c and string.format('rgba(%d,%d,%d,%.2f)',math.floor(c[1]*255),math.floor(c[2]*255),math.floor(c[3]*255),(c[4] or 1)*(alpha or 1)) or 'transparent' end
local function escape(s)
    s=tostring(s):gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;')
    s=s:gsub('|c%x%x(%x%x%x%x%x%x)','<span style="color:#%1">'):gsub('|r','</span>')
    return s
end
local FONT={GameFontNormalLarge='font-size:17px;color:#ffd100',GameFontNormal='font-size:13px;color:#ffd100',GameFontNormalSmall='font-size:11px;color:#ffd100',
    GameFontHighlight='font-size:13px;color:#fff',GameFontHighlightSmall='font-size:11px;color:#fff',GameFontDisableSmall='font-size:11px;color:#808080',GameFontRedSmall='font-size:11px;color:#f33'}
local function render(f,root)
    if not f:IsVisible() and not root then return '' end
    local p=f.point or {};local x,y=tonumber(p[2]) or 0,-(tonumber(p[3]) or 0);if root then x,y=0,0 end
    local style=string.format('left:%gpx;top:%gpx;width:%gpx;height:%gpx;',x,y,f.width,f.height)
    local body,class='',f.kind
    if f.kind=='Texture' then
        local t=f.texture or ''
        if type(t)=='number' then body='<b style="font-size:9px;color:#888">'..t..'</b>';t='' end
        local icon=t:match('^Interface\\Icons\\(.+)$')
        if icon then body='<img src="https://wow.zamimg.com/images/wow/icons/large/'..icon:lower()..'.jpg">'
        elseif ICONS[t] then body=ICONS[t];class='Texture glyph g'..t:sub(-5)
        elseif t:find('WHITE8X8') then style=style..'background:'..rgba(f.vertex)..';'
        elseif t:find('Header') then class='Texture plaque'
        elseif t:find('Plus') then body='+';class='Texture glyph'
        elseif body=='' then return '' end
        if f.desaturated then style=style..'filter:grayscale(1);' end
        if f.alpha then style=style..'opacity:'..f.alpha..';' end
    elseif f.kind=='FontString' then
        style=style..(FONT[f.style] or FONT.GameFontHighlight)..';text-align:'..((f.justify or 'LEFT'):lower())..';'
        body=escape(f.text or '')
    elseif f.kind=='EditBox' then body=escape(f.text or '')
    elseif f.kind=='CheckButton' then body=f.checked and '✓' or ''
    elseif f.kind=='StatusBar' then
        local pct=math.max(0,math.min(1,(f.barValue or 0)/math.max(1,f.max or 1)))
        body=string.format('<i style="width:%d%%"></i>',math.floor(pct*100))
    elseif f.kind=='Button' and f.template=='UIPanelButtonTemplate' then class='Button red';body=escape(f.text or '')
    elseif f.kind=='Button' and f.template=='UIPanelCloseButton' then class='Button close';body='✕'
    end
    if f.backdrop and f.kind~='Texture' then
        local dialog=f.backdrop.edgeFile and f.backdrop.edgeFile:find('DialogBox')
        style=style..'background:'..rgba(f.bg)..';border:'..(dialog and '5px ridge #b8a07a' or '2px solid '..rgba(f.border))..';'
    end
    local s='<div class="'..class..'" style="'..style..'">'..body
    for _,c in ipairs(f.children) do s=s..render(c) end
    return s..'</div>'
end
R.render=render
R.CSS=[[<style>
body{margin:0;padding:16px;font:14px system-ui;color:#ddd;background:#2b2520}p{line-height:1.5;max-width:900px}
nav{display:flex;gap:6px;flex-wrap:wrap;margin:12px 0}nav button{padding:7px 12px;background:#30251d;color:#f5cf71;border:1px solid #79674b;border-radius:4px;cursor:pointer}
.scene{position:relative;width:920px;height:690px;display:none;font-family:"Friz Quadrata TT",Georgia,serif}.scene.active{display:block}
.scene div{position:absolute;box-sizing:border-box;border-radius:3px}.scene img{width:100%;height:100%;display:block;border-radius:2px}
.FontString{white-space:pre-wrap;overflow:hidden;line-height:1.25;text-shadow:1px 1px 0 #000}
.red{background:linear-gradient(#8c1c13,#4a0b07);border:1px solid #c9a24a;color:#ffd100;font-size:12px;text-align:center;line-height:20px;overflow:hidden;border-radius:4px}
.close{background:#5a120c;border:1px solid #c9a24a;color:#ffd100;text-align:center;line-height:26px;border-radius:50%!important}
.EditBox{background:#0b0b0b;border:1px solid #6d6250;color:#fff;padding:3px 7px;font-size:12px}
.CheckButton{background:#15120c;border:2px ridge #85704a;text-align:center;color:#ffd100;line-height:18px}
.ScrollFrame{overflow:hidden}.StatusBar i{position:absolute;left:0;top:0;bottom:0;background:linear-gradient(#f2b630,#a46b05);border-radius:2px}
.StatusBar .FontString{z-index:2}.glyph{text-align:center;font-size:13px;line-height:16px;color:#ffd100}.gReady{color:#3f3}.gReady,.gWaiting{}.gReady{}
.plaque{background:linear-gradient(#5b4a32,#2a2116);border:2px ridge #c9a24a;border-radius:6px!important;height:30px!important;top:-14px!important}
</style>]]
return R
