local Mock=dofile('tests/wow_mock.lua');local ZZ={};Mock.ZZ=ZZ
C_Spell=nil;C_UnitAuras=nil;Settings=nil;Enum=nil;C_ChatInfo=nil
function GetSpellInfo(id) return id==433 and 'Food' or 'Drink' end
function UnitBuff(_,index) return Mock.auras[index] and Mock.auras[index].name end
function RegisterAddonMessagePrefix() return true end
function SendAddonMessage(prefix,message,channel) Mock.addonSent[#Mock.addonSent+1]={prefix,message,channel};return true end
function SendChatMessage(message,channel) Mock.sent[#Mock.sent+1]={message,channel} end
function InterfaceOptions_AddCategory(panel) Mock.legacyCategory=panel end
for _,file in ipairs({'Core','Model','Guild','Widgets','Calendar','UI','Client'}) do assert(loadfile('ZugZugFit/'..file..'.lua'))('ZugZugFit',ZZ) end
local original=ZZ.frame.RegisterEvent
ZZ.frame.RegisterEvent=function(self,name) if name=='LFG_COMPLETION_REWARD' then error('Unknown event') end;original(self,name) end
ZZ.frame.scripts.OnEvent(ZZ.frame,'ADDON_LOADED','ZugZugFit')
assert(Mock.legacyCategory)
Mock.now=Mock.now+6;ZZ.frame.scripts.OnUpdate(ZZ.frame,1)
local rule=ZZ.engine:addRule({activityID='water',unit='sessions',amount=1,kind='trigger',trigger='drinking',days='1234567',windowStart=0,windowEnd=1440,cooldown=0,cap=10})
Mock.auras={{name='Drink'}};ZZ.frame.scripts.OnEvent(ZZ.frame,'UNIT_AURA','player');assert(ZZ.engine:pending(rule.id))
assert(ZZ.CapabilityText():find('dungeon: Mythic+ completion, leave a dungeon after a boss kill',1,true))
ZZ.sync:setEnabled(true);Mock.now=Mock.now+1;ZZ.sync:tick();assert(#Mock.addonSent>0)
assert(ZZ.Calendar:read('2026-10-25')==nil)
print('Legacy adapter scenarios: 4 passed (settings, aura, comms, unavailable APIs)')
