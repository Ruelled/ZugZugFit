local Mock=dofile('tests/wow_mock.lua');local ZZ={};Mock.ZZ=ZZ
for _,file in ipairs({'Core','Model','Guild','Widgets','Calendar','UI','Client'}) do assert(loadfile('ZugZugFit/'..file..'.lua'))('ZugZugFit',ZZ) end
local function event(e,...) ZZ.frame.scripts.OnEvent(ZZ.frame,e,...) end
local function update(n) Mock.now=Mock.now+(n or 1);ZZ.frame.scripts.OnUpdate(ZZ.frame,n or 1) end
local n=0
local function test(name,fn) local ok,err=pcall(fn);assert(ok,name..': '..tostring(err));n=n+1;print('PASS '..name) end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function count(t) local total=0;for _ in pairs(t) do total=total+1 end;return total end
local function spec(trigger) return {activityID='push-ups',unit='reps',amount=10,kind='trigger',trigger=trigger,days='1234567',cooldown=0,cap=100,windowStart=0,windowEnd=1440} end
local function dismiss() for id,o in pairs(ZugZugFitDB.occurrences) do if o.status=='pending' then ZZ.engine:dismiss(id) end end end
local function click(parent,key) assert(parent.pool[key],'Missing control '..key):Click() end
event('ADDON_LOADED','ZugZugFit');update(6)
test('Account initialization, native settings launcher, minimap and all five pages',function()
    eq(ZugZugFitDB.schema,2);assert(ZZ.settingsPanel);assert(Mock.category);assert(ZZ.minimap)
    SlashCmdList.ZUGZUGFIT('');eq(ZZ.UI.tab,'Today')
    for _,tab in ipairs({'Today','Calendar','Routines','Triggers','Guild','Settings'}) do ZZ.UI:show(tab);assert(ZZ.UI.frame.panels[tab]:IsVisible()) end
    eq(#Mock.addonSent,0);eq(#Mock.sent,0)
    ZZ.minimap:Click();eq(ZZ.UI.tab,'Today')
end)
test('Reminder builder: exercise tiles, repeat cards, day chips, stepper and live sentence',function()
    ZZ.UI:ruleDialog();local d=ZZ.UI.modal
    click(d,'kind_daily');assert(d.pool.kind_daily.on)
    local f=d.getFields();assert(f.at:IsShown());eq(f.interval,nil);eq(f.trigger,nil)
    click(f.days,'preset2');eq(f.days:GetValue(),'12345');click(f.days,'preset1')
    f.days.boxes[7]:Click();eq(f.days:GetValue(),'123456')
    d.picker.tiles.yoga:Click();eq(d.picker.value,'yoga');eq(d.pool.unit.value,'minutes');eq(d.pool.amount:GetText(),'15')
    click(d,'amountplus');eq(d.pool.amount:GetText(),'20');click(d,'amountminus');eq(d.pool.amount:GetText(),'15')
    click(d.pool.dynamic,'time5');eq(f.at:GetText(),'21:00')
    local sentence=d.summary:GetText();assert(sentence:find('21:00') and sentence:find('15 minutes of Yoga') and sentence:find('Mon, Tue'),sentence)
    click(d,'useGoal');d.pool.goalAmount:SetText('15');click(d,'save')
    local r;for _,v in pairs(ZugZugFitDB.rules) do r=v end
    eq(r.activityID,'yoga');eq(r.at,1260);eq(r.days,'123456');assert(r.goalID)
end)
test('Schedule-specific fields show interval and gameplay options only when needed',function()
    ZZ.UI:ruleDialog();local d=ZZ.UI.modal
    local f=d.getFields();assert(f.interval and f.start and f.stop);eq(f.trigger,nil)
    click(d,'kind_trigger');f=d.getFields();assert(f.trigger and f.cooldown and f.cap);eq(f.interval,nil);eq(f.at,nil)
    Mock.choose(f.trigger,'mailbox');click(d,'save');eq(count(ZugZugFitDB.rules),2)
end)
test('Log activity can backfill, edit, delete and restore from the calendar',function()
    ZZ.UI:logDialog('2026-10-23');local d=ZZ.UI.modal;d.picker.tiles.gym:Click();Mock.choose(d.pool.unit,'minutes');d.pool.amount:SetText('45');click(d,'save')
    local id;for k in pairs(ZugZugFitDB.logs) do id=k end
    eq(ZugZugFitDB.logs[id].day,'2026-10-23');eq(ZugZugFitDB.logs[id].amount,45)
    ZZ.UI:logDialog('2026-10-23',id);ZZ.UI.modal.pool.amount:SetText('60');click(ZZ.UI.modal,'save');eq(ZugZugFitDB.logs[id].amount,60)
    ZZ.UI.day='2026-10-23';ZZ.UI:show('Calendar');local row=ZZ.UI.details.pool['log'..id];click(row,'delete');assert(ZugZugFitDB.logs[id].deleted)
    click(ZZ.UI.details.pool['log'..id],'undo');eq(ZugZugFitDB.logs[id].deleted,nil);eq(#Mock.sent,0)
end)
test('Future log validation and goal validation remain in the form',function()
    ZZ.UI:logDialog('2099-01-01');click(ZZ.UI.modal,'save');assert(ZZ.UI.modal.error:GetText():find('today or earlier'));ZZ.UI:finish()
    ZZ.UI:goalDialog();ZZ.UI.modal.pool.amount:SetText('-1');click(ZZ.UI.modal,'save');assert(ZZ.UI.modal:IsShown());ZZ.UI:finish()
end)
test('Calendar month/week navigation and repeated refresh reuse native controls',function()
    ZZ.UI:show('Calendar');local p=ZZ.UI.frame.panels.Calendar;eq(#ZZ.UI.cells,42)
    click(p,'view_week');eq(#ZZ.UI.cells,7);local before=ZZ.UI.day;click(p,'next');eq(ZZ.UI.day,ZZ.Core.addDays(before,7))
    click(p,'today');click(p,'view_month');eq(#ZZ.UI.cells,42)
    ZZ.UI.day='2026-10-23';ZZ.UI:refresh();local frames=#Mock.frames
    for _=1,20 do ZZ.UI:refresh() end;eq(#Mock.frames,frames)
end)
test('Dialog reopening reuses controls without hidden inputs showing through',function()
    ZZ.UI:ruleDialog();ZZ.UI:finish();ZZ.UI:logDialog('2026-10-25');ZZ.UI:finish()
    local frames=#Mock.frames
    for _=1,10 do ZZ.UI:ruleDialog();ZZ.UI:finish();ZZ.UI:logDialog('2026-10-25');ZZ.UI:finish() end
    eq(#Mock.frames,frames)
end)
test('Custom activity creation and renaming stay connected to records',function()
    ZZ.UI:show('Routines');ZZ.UI:activityDialog();local d=ZZ.UI.modal;d.pool.name:SetText('Incline push-ups');click(d,'icon3');click(d,'save')
    local a=ZZ.engine:findActivity('Incline push-ups');assert(a);eq(a.icon,ZZ.Core.iconChoices[3]);eq(ZZ.Core.iconFor(a),'Interface\\Icons\\'..a.icon)
    ZZ.UI:activityDialog(a.id);ZZ.UI.modal.pool.name:SetText('Wall push-ups');click(ZZ.UI.modal,'save');eq(ZZ.engine.db.activities[a.id].name,'Wall push-ups')
end)
test('Mailbox trigger coalesces and combat defers real reminder prompt',function()
    for _,r in pairs(ZugZugFitDB.rules) do if r.trigger=='mailbox' then r.cooldown=0 end end
    Mock.combat=true;event('MAIL_SHOW');event('MAIL_SHOW');update();assert(not ZZ.UI.prompt:IsShown())
    local total=count(ZugZugFitDB.occurrences);Mock.combat=false;event('PLAYER_REGEN_ENABLED');assert(ZZ.UI.prompt:IsShown())
    click(ZZ.UI.prompt,'snooze');assert(not ZZ.UI.prompt:IsShown());eq(count(ZugZugFitDB.occurrences),total)
    dismiss();event('MAIL_CLOSED');update(3);event('MAIL_SHOW');eq(count(ZugZugFitDB.occurrences),total+1);dismiss()
end)
test('Successful readable player Hearthstone only; secret values are ignored',function()
    ZZ.engine:addRule(spec('hearthstone'));local total=count(ZugZugFitDB.occurrences)
    event('UNIT_SPELLCAST_SUCCEEDED','target','guid',8690);event('UNIT_SPELLCAST_SUCCEEDED','player','guid',123)
    event('UNIT_SPELLCAST_SUCCEEDED',{secret=true},'guid',8690);event('UNIT_SPELLCAST_SUCCEEDED','player','guid',{secret=true})
    eq(count(ZugZugFitDB.occurrences),total);event('UNIT_SPELLCAST_SUCCEEDED','player','guid',8690);eq(count(ZugZugFitDB.occurrences),total+1);dismiss()
end)
test('Eating/drinking coalesce and hidden aura data does not become a trigger',function()
    ZZ.engine:addRule(spec('eating'));ZZ.engine:addRule(spec('drinking'));local total=count(ZugZugFitDB.occurrences)
    Mock.auras={{name='Food'},{name='Drink'}};event('UNIT_AURA','player');eq(count(ZugZugFitDB.occurrences),total+2)
    dismiss();update(3);event('UNIT_AURA','player');eq(count(ZugZugFitDB.occurrences),total+2)
    Mock.auras={{name={secret=true}}};event('UNIT_AURA','player');eq(count(ZugZugFitDB.occurrences),total+2)
end)
test('Zone initialization is silent and new-zone transition triggers',function()
    ZZ.engine:addRule(spec('zone'));local total=count(ZugZugFitDB.occurrences)
    event('PLAYER_ENTERING_WORLD');event('ZONE_CHANGED_NEW_AREA');eq(count(ZugZugFitDB.occurrences),total)
    update(6);Mock.zone='Westfall';event('ZONE_CHANGED_NEW_AREA');eq(count(ZugZugFitDB.occurrences),total+1);dismiss()
end)
test('Announcements require consent and skip corrections/backfills',function()
    local settings=ZugZugFitDB.settings;settings.channel='GUILD';settings.announce=true
    local l=ZZ.engine:saveLog({activityID='yoga',unit='minutes',amount=15,day=ZZ.Now().day});ZZ.OnLogged(l)
    Mock.combat=true;ZZ.FlushAnnouncements();eq(#Mock.sent,0);Mock.combat=false;ZZ.FlushAnnouncements();eq(#Mock.sent,1)
    ZZ.OnLogged(l);update(61);eq(#Mock.sent,1)
    local past=ZZ.engine:saveLog({activityID='gym',unit='minutes',amount=45,day='2026-10-23'});ZZ.OnLogged(past);update(61);eq(#Mock.sent,1)
    settings.announce=false
end)
test('Reminder preview has no credit; settings and pause stay synchronized',function()
    local total=count(ZugZugFitDB.logs);ZZ.UI:testPrompt();click(ZZ.UI.prompt,'log');eq(count(ZugZugFitDB.logs),total)
    ZZ.UI:testPrompt();Mock.combat=true;event('PLAYER_REGEN_DISABLED');assert(not ZZ.UI.prompt:IsShown());Mock.combat=false
    ZZ.UI.settingsTab='Reminders';ZZ.UI:show('Settings');local before=ZugZugFitDB.settings.paused
    SlashCmdList.ZUGZUGFIT('pause');ZZ.UI:refresh();eq(ZZ.UI.frame.panels.Settings.pool.settingsBox.pool.paused:GetChecked(),not before)
    SlashCmdList.ZUGZUGFIT('pause')
    local p=ZZ.UI.frame.panels.Settings.pool.settingsBox;p.pool.snooze:SetText('30');click(p,'save');eq(ZugZugFitDB.settings.snooze,30)
end)
test('Guild UI opt-in registers prefix, sends only guild packets and can withdraw',function()
    ZZ.UI:show('Guild');local p=ZZ.UI.frame.panels.Guild;click(p,'sharing');assert(ZZ.sync.cache.enabled)
    for _=1,20 do update() end;assert(#Mock.addonSent>0)
    for _,packet in ipairs(Mock.addonSent) do eq(packet[1],ZZ.Guild.PREFIX);eq(packet[3],'GUILD');assert(#packet[2]<=255) end
    click(p,'sharing');assert(not ZZ.sync.cache.enabled);update();eq(ZZ.sync.queue[1],nil)
end)
test('Calendar adapter is read-only, handles missing/restricted APIs and valid events',function()
    eq(ZZ.Calendar:read('2026-10-25'),nil)
    C_Calendar={GetMonthInfo=function() return {year=2026,month=10} end,GetNumDayEvents=function() return 1 end,GetDayEvent=function() return {title='Guild raid',startTime={hour=19,minute=0}} end}
    local events=assert(ZZ.Calendar:read('2026-10-25'));eq(events[1].time,'19:00')
    C_Calendar.GetDayEvent=function() return {title={secret=true},startTime={hour=19,minute=0}} end;eq(#ZZ.Calendar:read('2026-10-25'),0)
    Mock.combat=true;eq(ZZ.Calendar:read('2026-10-25'),nil);Mock.combat=false
end)
test('Closing the main window releases a modal and cannot suppress future prompts',function()
    ZZ.UI:show('Today');ZZ.UI:logDialog(ZZ.Now().day);assert(ZZ.UI.modal);assert(ZZ.UI.shield:IsShown())
    ZZ.UI.frame:Hide();eq(ZZ.UI.modal,nil);assert(not ZZ.UI.shield:IsShown())
    ZZ.UI:show('Today')
end)
test('One-off routine editor uses a date and supports appointment copies',function()
    ZZ.UI:ruleDialog();local d=ZZ.UI.modal;click(d,'kind_once')
    local f=d.getFields();assert(f.date and f.at);eq(f.days,nil)
    f.date:SetText('2026-10-27');f.at:SetText('19:00');click(d,'save')
    local found=false;for _,r in pairs(ZugZugFitDB.rules) do if r.kind=='once' and r.planDay=='2026-10-27' then found=true end end;assert(found)
end)
test('Minimap launcher has a visible rim, reset command and persistent drag position',function()
    local b=ZZ.minimap;eq(b.parent,UIParent);eq(b:GetFrameLevel(),100);assert(b.icon.texture)
    ZugZugFitDB.settings.minimap=false;ZZ.UpdateMinimap();assert(not b:IsShown())
    SlashCmdList.ZUGZUGFIT('minimap');assert(b:IsShown());eq(ZugZugFitDB.settings.minimapX,nil)
    b.scripts.OnDragStart();b.scripts.OnUpdate();b.scripts.OnDragStop();eq(b.scripts.OnUpdate,nil)
    eq(ZugZugFitDB.settings.minimapX,1);eq(ZugZugFitDB.settings.minimapY,0)
    local old=ZugZugFitDB.settings.paused;b:Click('RightButton');eq(ZugZugFitDB.settings.paused,not old)
    eq(b.icon.desaturated,not old);b:Click();eq(ZZ.UI.tab,'Today')
end)
test('Quick-start template prefills the builder and the list shows a plain sentence',function()
    ZZ.UI.routineTab='Reminders';ZZ.UI:show('Routines');local p=ZZ.UI.frame.panels.Routines
    local before=count(ZugZugFitDB.rules);click(p,'tpl1');local d=ZZ.UI.modal
    eq(d.picker.value,'yoga');assert(d.pool.kind_daily.on);eq(d.getFields().at:GetText(),'21:00')
    click(d,'save');eq(count(ZugZugFitDB.rules),before+1)
    local body=p.pool.listBox.pool.routineList.body;local found
    for _,row in pairs(body.pool) do if row.shown and row.texts and row.texts.sub and (row.texts.sub.text or ''):find('Every day at 21:00: 15 minutes of Yoga',1,true) then found=row end end
    assert(found,'Routine sentence missing');assert(found.texs.icon.texture:find('Tranquility'))
end)
test('Builder can create a new exercise and come back with it selected',function()
    ZZ.UI:ruleDialog();click(ZZ.UI.modal.pool.pickerBox.pool.grid.body,'actNew')
    local d=ZZ.UI.modal;d.pool.name:SetText('Lunges');click(d,'save')
    local a=ZZ.engine:findActivity('Lunges');assert(a);eq(ZZ.UI.modal.picker.value,a.id);ZZ.UI:finish()
end)
test('Guild board: roster columns, active days and header sorting',function()
    ZZ.UI:show('Guild');local p=ZZ.UI.frame.panels.Guild;if not ZZ.sync.cache.enabled then click(p,'sharing') end
    ZZ.sync.cache.peers['peer-1']={name='Friend',sender='Friend-Realm',receivedAt=Mock.now,revision=1,
        rows={{day=ZZ.Now().day,activity='push-ups',unit='reps',amount=500},{day=ZZ.Now().day,activity='yoga',unit='minutes',amount=10}}}
    local rows,cols=ZZ.sync:board('week',ZZ.Now().day);local friend
    for _,r in ipairs(rows) do if r.name=='Friend' then friend=r end end
    eq(friend.days,1);eq(friend.score,nil);eq(ZZ.UI.guildSort,'days');eq(friend.values['push-ups|reps'],500)
    local found=false;for _,c in ipairs(cols) do if c.key=='push-ups|reps' then found=true end end;assert(found)
    ZZ.UI.guildPeriod='week';ZZ.UI:refresh();click(p,'col_push-ups|reps');eq(ZZ.UI.guildSort,'push-ups|reps')
    ZZ.Guild.sortBoard(rows,'push-ups|reps');eq(rows[1].name,'Friend');eq(rows[1].rank,1)
    ZZ.Guild.sortBoard(rows,'name');eq(rows[1].rank,1)
    assert(p.pool.meBox.texts.rank.text:find('Your rank'));assert(not p.pool.col_score)
    click(p,'period4');eq(ZZ.UI.guildPeriod,'three months')
    ZZ.sync.cache.peers['peer-1']=nil;click(p,'sharing')
end)
test('Today shows due cards with icons and the week strip',function()
    ZugZugFitDB.settings.paused=false;ZZ.engine:addRule(spec('level'));ZZ.engine:trigger('level')
    ZZ.UI:show('Today');local p=ZZ.UI.frame.panels.Today;local body=p.pool.dueBox.pool.dueList.body;local card
    for k,row in pairs(body.pool) do if k:find('^pending') and row.shown then card=row end end
    assert(card,'No due card');assert(card.texs.icon.texture:find('Interface'));assert(card.pool.log and card.pool.later and card.pool.skip)
    click(card,'skip');assert(p.pool.weekBox.texts.sum.text:find('of 7 days active'))
end)
test('Share dialog puts one line in chat; the chat filter links it and import works',function()
    ZugZugFitDB.settings.paused=false
    local r=assert(ZZ.engine:saveRoutine({activityID='burpees',unit='reps',amount=5,kind='interval',interval=20,days='12345',windowStart=0,windowEnd=1440,stopAtGoal=true},{amount=50,period='day'}))
    ZZ.UI:shareDialog();local d=ZZ.UI.modal
    for k,b in pairs(d.pool) do if k:find('^pick') and k~='pickBox' and k~='pick'..r.id and b.checked then b:Click() end end
    d.pool.title:SetText('Burpee week');d.pool.title.scripts.OnTextChanged()
    assert(d.shareText and d.shareText:find('^%[ZugZugFit: Burpee week%] {ZZ1~'),d.shareText)
    click(d,'save');eq(Mock.chatOpened[#Mock.chatOpened],d.shareText)
    local _,linked=Mock.chatFilters.CHAT_MSG_GUILD(nil,'CHAT_MSG_GUILD','try '..d.shareText,'Friend-Realm')
    assert(linked:find('|Haddon:ZugZugFit:ZZ1~',1,true) and linked:find('[ZugZugFit: Burpee week]',1,true),linked)
    eq(ZZ.recentShares[1].title,'Burpee week');eq(ZZ.recentShares[1].sender,'Friend-Realm')
    eq(Mock.chatFilters.CHAT_MSG_GUILD(nil,'CHAT_MSG_GUILD',{secret=true},'Friend-Realm'),false)
    EventRegistry.callbacks.SetItemRef('addon:ZugZugFit:'..ZZ.recentShares[1].code)
    local before=count(ZugZugFitDB.rules);local m=ZZ.UI.modal;assert(m.texts.name.text:find('Burpee week'))
    click(m,'save');eq(count(ZugZugFitDB.rules),before+1);eq(ZZ.UI.tab,'Routines')
    ZZ.UI:importDialog();click(ZZ.UI.modal.pool.recentBox.pool.recent.body.pool.recent1,'open');assert(ZZ.UI.modal.texts.name.text:find('Burpee week'));ZZ.UI:finish()
    ZZ.UI:importDialog('ZZ1~broken');assert(ZZ.UI.modal.error:GetText()~='');ZZ.UI:finish()
    SlashCmdList.ZUGZUGFIT('import '..d.shareText);assert(ZZ.UI.modal.texts.name.text:find('Burpee week'));ZZ.UI:finish()
end)
test('Builder goal row, Test button preview, and goal celebration toast',function()
    ZZ.UI:ruleDialog(nil,ZZ.UI.TEMPLATES[2].spec);local d=ZZ.UI.modal
    assert(d.pool.useGoal:GetChecked());eq(d.pool.goalAmount:GetText(),'100');assert(d.pool.stopAtGoal:GetChecked())
    click(d,'goalAmountplus');assert(d.summary:GetText():find('Goal: 105 reps a day, then stop reminding',1,true),d.summary:GetText())
    click(d,'test');assert(ZZ.UI.prompt:IsShown() and ZZ.UI.prompt.demo);assert(ZZ.UI.prompt.body.text:find('Push%-ups'));click(ZZ.UI.prompt,'log')
    d.pool.amount:SetText('');click(d,'save');assert(d.summary:GetText()~='');assert(ZZ.UI.modal)
    d.pool.amount:SetText('10');click(d,'save');eq(ZZ.UI.modal,nil)
    local rule;for _,r in pairs(ZugZugFitDB.rules) do if r.pack==nil and r.stopAtGoal and r.activityID=='push-ups' then rule=r end end;assert(rule)
    eq(ZugZugFitDB.goals[rule.goalID].amount,105)
    ZZ.UI:ruleDialog(rule.id);assert(ZZ.UI.modal.pool.useGoal:GetChecked());eq(ZZ.UI.modal.pool.goalAmount:GetText(),'105');ZZ.UI:finish()
    local l=ZZ.engine:saveLog({activityID='push-ups',unit='reps',amount=200,day=ZZ.Now().day});ZZ.OnLogged(l)
    assert(ZZ.UI.toast:IsShown());assert(ZZ.UI.toast.body.text:find('Push%-ups'))
    ZZ.OnLogged(ZZ.engine:saveLog({activityID='push-ups',unit='reps',amount=1,day=ZZ.Now().day}))
    for _=1,7 do ZZ.UI.toast.scripts.OnUpdate(ZZ.UI.toast,1) end;assert(not ZZ.UI.toast:IsShown())
end)
test('Today shows done-today tiles and Now starts a coming-up reminder',function()
    ZZ.UI:show('Today');local p=ZZ.UI.frame.panels.Today
    local tile;for k,v in pairs(p.pool.doneBox.pool) do if k:find('^done') and v.shown and v.texts.name.text:find('Push') then tile=v end end
    assert(tile,'No push-up tile');assert(tile.texts.count.text:find('%d'))
    local yoga=assert(ZZ.engine:addRule({activityID='yoga',unit='minutes',amount=15,kind='daily',at=23*60+59,days='1234567',windowStart=0,windowEnd=1440}))
    ZZ.UI:refresh();local row=p.pool.nextBox.pool.nextList.body.pool['next'..yoga.id];assert(row)
    click(row,'now');local o=ZZ.engine:pending(yoga.id);assert(o and o.forced);eq(ZZ.UI.prompt.occurrence,o)
    ZZ.engine:dismiss(o.id);ZZ.UI:updatePrompt()
end)
test('Exercise icons: Blizzard macro icon pages, typed names, and the red light preset',function()
    local roast=ZZ.engine.db.activities['roast-your-nutz'];assert(roast);eq(roast.name,'Roast Your Nutz')
    eq(ZZ.Core.iconFor(roast),'Interface\\Icons\\Spell_Holy_SearingLight')
    ZZ.UI:activityDialog();local d=ZZ.UI.modal;d.pool.name:SetText('Red light');click(d,'src_spells')
    eq(#ZZ.UI.macroIcons('spells'),151) -- duplicates removed
    eq(d.texts.page.text,'1 / 2');click(d,'nextPage');eq(d.texts.page.text,'2 / 2');click(d,'nextPage');eq(d.texts.page.text,'2 / 2')
    assert(d.pool.icon67:IsShown());assert(not d.pool.icon68:IsShown()) -- 151 icons: 84 on page 1, 67 on page 2
    click(d,'prevPage');local icon=d.pool.icon5.icon;click(d,'icon5');eq(d.getIcon(),icon);eq(type(icon),'number')
    click(d,'save');local a=ZZ.engine:findActivity('Red light');eq(a.icon,icon);eq(ZZ.Core.iconFor(a),icon)
    ZZ.UI:activityDialog(a.id);d=ZZ.UI.modal;eq(ZZ.UI.macroIcons('items')[1],'INV_Misc_Bag_08')
    d.pool.iconName:SetText('Interface\\Icons\\Spell_Fire_Fire.blp');click(d,'useName');eq(d.getIcon(),'Spell_Fire_Fire')
    d.pool.iconName:SetText('bad name!');click(d,'useName');assert(d.error:GetText()~='');click(d,'save');eq(a.icon,'Spell_Fire_Fire')
    a.icon=icon;local r=assert(ZZ.engine:addRule({activityID=a.id,unit='reps',amount=1,kind='daily',at=480,days='1234567',windowStart=0,windowEnd=1440}))
    local code=ZZ.Core.findShare(assert(ZZ.engine:shareText('Light',{r.id})));local share=assert(ZZ.engine:decodeShare(code));eq(share.rules[1].icon,icon)
    ZZ.UI.routineTab='Reminders';ZZ.UI:show('Routines');local p=ZZ.UI.frame.panels.Routines;assert(p.pool.tpl6.shown)
    click(p,'tpl6');eq(ZZ.UI.modal.picker.value,'roast-your-nutz');eq(ZZ.UI.modal.getFields().at:GetText(),'08:00');ZZ.UI:finish()
end)
test('One-click Done logs the suggested amount, Undo restores it, repeating rows stay on Today',function()
    ZugZugFitDB.settings.paused=false;ZZ.UI:finish()
    local r=assert(ZZ.engine:addRule({activityID='squats',unit='reps',amount=10,kind='interval',interval=20,days='1234567',windowStart=0,windowEnd=1440}))
    local function logs() local n2=0;for _,l in pairs(ZugZugFitDB.logs) do if l.activityID=='squats' and not l.deleted then n2=n2+l.amount end end;return n2 end
    ZZ.UI:show('Today');local p=ZZ.UI.frame.panels.Today;local function row() return p.pool.nextBox.pool.nextList.body.pool['every'..r.id] end
    assert(row() and row().shown);click(row(),'now');local o=ZZ.engine:pending(r.id);local prompt=ZZ.UI.prompt
    eq(prompt.occurrence,o);assert(row().shown,'Row must stay after Now');assert(row().texts.title.text:find('Due now'))
    local before=logs();click(prompt,'log');eq(logs(),before+10);eq(ZZ.UI.modal,nil) -- no form
    assert(prompt.texts.title.text:find('Logged'));assert(row().shown);assert(row().texts.title.text:find('In ~20 min'),row().texts.title.text)
    click(prompt,'undo');eq(logs(),before);eq(ZZ.engine:pending(r.id).id,o.id);eq(prompt.occurrence,o)
    click(prompt,'didplus');eq(prompt.pool.did:GetText(),'15');click(prompt,'log');eq(logs(),before+15)
    for _=1,6 do prompt.scripts.OnUpdate(prompt,1) end;eq(prompt.confirm,nil)
    click(row(),'now');click(prompt,'snz30');local due=ZZ.engine:pending(r.id).due;eq(due,ZZ.Now().now+1800);assert(not prompt:IsShown() or prompt.occurrence~=ZZ.engine:pending(r.id))
    ZZ.engine.db.occurrences[ZZ.engine:pending(r.id).id].due=ZZ.Now().now;ZZ.UI:refresh()
    local card=p.pool.dueBox.pool.dueList.body.pool['pending'..ZZ.engine:pending(r.id).id];local id=ZZ.engine:pending(r.id).id
    card.pool.log:Click('RightButton');assert(ZZ.UI.modal);ZZ.UI:finish()
    click(card,'log');eq(logs(),before+25);eq(ZugZugFitDB.occurrences[id].status,'completed')
    for _=1,6 do prompt.scripts.OnUpdate(prompt,1) end
end)
test('Challenges: send from Today, chat link, accept a new move, guild list and completion',function()
    ZZ.UI:finish();ZZ.UI:show('Guild');local gp=ZZ.UI.frame.panels.Guild;if not ZZ.sync.cache.enabled then click(gp,'sharing') end
    for _=1,40 do update() end;ZZ.sync.queue={}
    ZZ.UI:show('Today');click(ZZ.UI.frame.panels.Today,'challenge');local d=ZZ.UI.modal
    d.picker.tiles.squats:Click();eq(d.pool.amount:GetText(),'150');click(d,'dur3');assert(d.pool.dur3.on)
    assert(d.pool.previewBox.texts.text.text:find('150 reps Squats'))
    click(d,'save');local sent=Mock.chatOpened[#Mock.chatOpened];assert(sent:find('^%[ZugZugFit Challenge: 150 reps Squats'),sent)
    local kinds={};for _,q in ipairs(ZZ.sync.queue) do kinds[q.message:sub(1,2)]=true end;assert(kinds['C|'] and kinds['A|'])
    -- A guildmate's challenge for a move we do not have yet.
    local code='ZC1~peer9-c4~peer9~Thrallbro~Burpee Twist~r~50~'..ZZ.Now().day..'~'..ZZ.Now().day..'~Spell_Fire_Fire'
    Mock.chatFilters.CHAT_MSG_CHANNEL(nil,'CHAT_MSG_CHANNEL','[ZugZugFit Challenge: x] {'..code..'}','Stranger-Realm')
    eq(ZugZugFitDB.challenges['peer9-c4'],nil) -- public channels never add challenges
    local _,linked=Mock.chatFilters.CHAT_MSG_GUILD(nil,'CHAT_MSG_GUILD','[ZugZugFit Challenge: 50 reps Burpee Twist · today] {'..code..'}','Thrallbro-Realm')
    assert(linked:find('|Haddon:ZugZugFit:ZC1~',1,true),linked);assert(ZugZugFitDB.challenges['peer9-c4'])
    ZZ.UI:show('Today');local row=ZZ.UI.frame.panels.Today.pool.goalBox.pool.goalList.body.pool['chpeer9-c4'];assert(row and row.pool.accept)
    EventRegistry.callbacks.SetItemRef('addon:ZugZugFit:'..code);local m=ZZ.UI.modal;assert(m.texts.move.text:find('New move'))
    click(m,'save');local move=ZZ.engine:findActivity('Burpee Twist');assert(move);eq(move.icon,'Spell_Fire_Fire');eq(ZZ.UI.tab,'Today')
    ZZ.sync:receive('A|peer9-c4|peer9|Thrallbro','GUILD','Friend-Realm')
    ZZ.sync.cache.peers.peer9={name='Thrallbro',sender='Friend-Realm',receivedAt=Mock.now,revision=1,rows={{day=ZZ.Now().day,activity='burpee twist',unit='reps',amount=50}}}
    local l=ZZ.engine:saveLog({activityID=move.id,unit='reps',amount=50,day=ZZ.Now().day});ZZ.OnLogged(l)
    assert(ZZ.UI.toast.title.text:find('Challenge complete'))
    ZZ.UI.guildView='challenges';ZZ.UI.challengeID='peer9-c4';ZZ.UI:show('Guild')
    local detail=gp.pool.challengeDetail;assert(detail.texts.whoHead.text:find('2 took part · 2 done'),detail.texts.whoHead.text)
    ZZ.sync:receive('C|ZC1~peer8-c1~peer8~Lysandra~Plank~m~5~'..ZZ.Now().day..'~'..ZZ.Now().day..'~','GUILD','Friend-Realm')
    assert(ZugZugFitDB.challenges['peer8-c1']);ZZ.UI:refresh();assert(gp.pool.challengeBox.pool.challengeList.body.pool.c1)
    ZZ.UI.guildView='board';ZZ.sync.cache.peers.peer9=nil;click(gp,'sharing')
end)
test('Top tabs: every tab is reachable and the selected one is marked',function()
    for _,name in ipairs({'Today','Calendar','Routines','Triggers','Guild','Settings'}) do
        click(ZZ.UI.frame,'tab'..name);eq(ZZ.UI.tab,name);assert(ZZ.UI.frame.pool['tab'..name].on)
        eq(ZZ.UI.frame.pool['tab'..name].point[3],-50)
    end
end)
test('Triggers tab: add an exercise to an event, start it now, and it is also a reminder',function()
    dismiss();ZZ.UI:show('Triggers');local p=ZZ.UI.frame.panels.Triggers
    local body=p.pool.listBox.pool.triggerList.body
    local quest=body.pool.ev_quest;assert(quest and quest.shown);eq(quest.pool.start and quest.pool.start.shown or false,false)
    local before=count(ZugZugFitDB.rules)
    click(quest,'add');local d=ZZ.UI.modal;eq(d.getFields().trigger.value,'quest')
    d.picker.tiles.squats:Click();click(d,'save');eq(count(ZugZugFitDB.rules),before+1);eq(ZZ.UI.tab,'Triggers')
    local id;for k,r in pairs(ZugZugFitDB.rules) do if r.trigger=='quest' and r.activityID=='squats' then id=k end end;assert(id)
    body=p.pool.listBox.pool.triggerList.body;assert(body.pool['rule_'..id].shown);assert(body.pool.ev_quest.pool.start.shown)
    click(body.pool.ev_quest,'start');assert(ZZ.engine:pending(id))
    ZZ.UI.routineTab='Reminders';ZZ.UI:show('Routines');assert(ZZ.UI.frame.panels.Routines.pool.listBox.pool.routineList.body.pool[id].shown)
    dismiss()
end)
test('Finish a dungeon: Mythic+ or queued completion, or leave after a boss kill; a corpse run does not count',function()
    dismiss();local r=ZZ.engine:addRule(spec('dungeon'))
    Mock.now=Mock.now+10;Mock.instance=36;event('PLAYER_ENTERING_WORLD');Mock.now=Mock.now+6
    Mock.instance=nil;event('PLAYER_ENTERING_WORLD');assert(not ZZ.engine:pending(r.id),'no boss, no clear')
    Mock.instance=36;event('PLAYER_ENTERING_WORLD');event('ENCOUNTER_END',1,'Boss',1,5,1)
    Mock.dead=true;Mock.instance=nil;event('PLAYER_ENTERING_WORLD');assert(not ZZ.engine:pending(r.id),'released to the graveyard')
    Mock.dead=false;Mock.instance=36;event('PLAYER_ENTERING_WORLD');Mock.now=Mock.now+3
    Mock.instance=nil;event('PLAYER_ENTERING_WORLD');assert(ZZ.engine:pending(r.id),'left after a kill');dismiss()
    Mock.now=Mock.now+3;Mock.instance=36;event('PLAYER_ENTERING_WORLD');event('CHALLENGE_MODE_COMPLETED');assert(ZZ.engine:pending(r.id));dismiss()
    Mock.now=Mock.now+3;event('ENCOUNTER_END',2,'Boss',1,5,1);Mock.instance=nil;event('PLAYER_ENTERING_WORLD');assert(not ZZ.engine:pending(r.id),'one clear per run')
    ZZ.engine:retireRule(r.id)
end)
test('Scroll lists: mouse wheel moves the list, the bar shows, and a refresh keeps the position',function()
    for i=1,12 do assert(ZZ.engine:addRule({activityID='water',unit='sessions',amount=1,kind='daily',at=math.min(1439,ZZ.Now().minute+5*i),days='1234567',windowStart=0,windowEnd=1440})) end
    ZZ.UI:show('Today');local p=ZZ.UI.frame.panels.Today;local s=p.pool.nextBox.pool.nextList
    assert(s.body:GetHeight()>s:GetHeight());assert(s.bar.shown)
    s.scripts.OnMouseWheel(s,-1);eq(s.want,48);eq(s.scroll,48)
    ZZ.UI:refresh();eq(s.scroll,48)
    for _=1,50 do s.scripts.OnMouseWheel(s,-1) end;eq(s.want,s.body:GetHeight()-s:GetHeight())
    for _=1,50 do s.scripts.OnMouseWheel(s,1) end;eq(s.want,0)
end)
test('Sample mode fills every list without saving, and the self-test opens every page and dialog',function()
    local rules,logs=count(ZugZugFitDB.rules),count(ZugZugFitDB.logs)
    SlashCmdList.ZUGZUGFIT('sample');assert(ZZ.UI.realEngine);assert(ZZ.UI.frame.texts.subtitle.text:find('SAMPLE'))
    local p=ZZ.UI.frame.panels.Today
    assert(p.pool.doneBox.pool.more.shown);assert(p.pool.doneBox.pool.more.texts.count.text:find('+'))
    assert(p.pool.goalBox.pool.goalList.bar.shown);assert(p.pool.dueBox.pool.dueList.bar.shown)
    click(p.pool.doneBox,'more');eq(ZZ.UI.tab,'Calendar')
    eq(count(ZugZugFitDB.rules),rules);eq(count(ZugZugFitDB.logs),logs)
    ZZ.UI.frame:Hide();eq(ZZ.UI.realEngine,nil);eq(ZZ.engine.db,ZugZugFitDB)
    local passed,failed=ZZ.UI:selfTest();assert(passed>20,passed)
    assert(ZZ.UI.report:find('PASS  Page Triggers',1,true),ZZ.UI.report);assert(ZZ.UI.report:find('PASS  Dialog Send a challenge',1,true))
    assert(not ZZ.UI.report:find('FAIL  Page',1,true) and not ZZ.UI.report:find('FAIL  Dialog',1,true),ZZ.UI.report)
    assert(ZZ.UI.modal.pool.copy);ZZ.UI:finish()
    eq(count(ZugZugFitDB.rules),rules);eq(count(ZugZugFitDB.logs),logs)
end)
test('Today lists a daily reminder after its time, and paused reminders say so with Resume',function()
    dismiss();local r=assert(ZZ.engine:addRule({activityID='roast-your-nutz',unit='minutes',amount=10,kind='daily',at=0,days='1234567',windowStart=0,windowEnd=1440}))
    ZugZugFitDB.settings.paused=true;ZZ.UI:show('Today');local p=ZZ.UI.frame.panels.Today
    for _,o in pairs(ZugZugFitDB.occurrences) do if o.status=='pending' then o.status='skipped' end end;ZZ.UI:refresh()
    local row=p.pool.nextBox.pool.nextList.body.pool['next'..r.id];assert(row and row.shown,'08:00 reminder must stay listed')
    assert(row.texts.sub.text:find('Paused'),row.texts.sub.text)
    local empty=p.pool.dueBox.pool.dueList.body.pool.empty;assert(empty.texts.title.text:find('paused'))
    click(empty,'resume');eq(ZugZugFitDB.settings.paused,false)
    update(6);assert(ZZ.engine:pending(r.id),'resume starts the missed daily reminder')
    ZZ.UI:refresh();row=p.pool.nextBox.pool.nextList.body.pool['next'..r.id];assert(row.texts.sub.text:find('Due now'),row.texts.sub.text)
    dismiss();ZZ.engine:retireRule(r.id)
end)
-- A realistic WoW calendar: realm time is one hour behind local time.
local function wowCalendar(events)
    C_DateAndTime={GetCurrentCalendarTime=function() local t=os.date('*t',Mock.now-3600);return {year=t.year,month=t.month,monthDay=t.day,hour=t.hour,minute=t.min} end}
    C_Calendar={OpenCalendar=function() Mock.calendarOpened=true end,GetMonthInfo=function(o) return {year=2026,month=10+(o or 0)} end,
        GetNumDayEvents=function(o,d) local n=0;for _,e in ipairs(events) do if e.o==o and e.d==d then n=n+1 end end;return n end,
        GetDayEvent=function(o,d,i) local n=0;for _,e in ipairs(events) do if e.o==o and e.d==d then n=n+1;if n==i then return e.ev end end end end,
        GetEventInfo=function() end,EventSetTitle=function(t) Mock.calTitle=t end,EventSetDescription=function(t) Mock.calNote=t end,
        EventSetTime=function(h,m) Mock.calTime={h,m} end}
    ZZ.Calendar:invalidate()
end
local raidEvents={
    {o=0,d=25,ev={eventID=11,title='Molten Core',calendarType='GUILD_EVENT',eventType=0,inviteStatus=3,sequenceType='',startTime={hour=19,minute=0}}},
    {o=0,d=25,ev={eventID=12,title='Book club',calendarType='PLAYER',eventType=3,inviteStatus=2,sequenceType='',startTime={hour=13,minute=0}}},
    {o=0,d=25,ev={eventID=13,title="Hallow's End",calendarType='HOLIDAY',eventType=4,inviteStatus=0,sequenceType='ONGOING',startTime={hour=10,minute=0}}},
    {o=0,d=27,ev={eventID=14,title='Karazhan',calendarType='PLAYER',eventType=0,inviteStatus=6,sequenceType='',startTime={hour=23,minute=30}}},
}
test('WoW calendar adapter: local time, holidays, declined invites, day change and cache',function()
    wowCalendar(raidEvents)
    local days=ZZ.Calendar:range('2026-10-19','2026-11-29')
    local today=days['2026-10-25'];assert(today and #today==3,#(today or {}))
    local mc;for _,ev in ipairs(today) do if ev.title=='Molten Core' then mc=ev end end
    eq(mc.minute,20*60);eq(mc.realm,'19:00');eq(mc.kind,'event');assert(ZZ.Core.calendarMatch('raid',mc));assert(ZZ.Core.calendarMatch('guild',mc))
    local book;for _,ev in ipairs(today) do if ev.title=='Book club' then book=ev end end;assert(book.declined);assert(not ZZ.Core.calendarMatch('any',book))
    local holiday;for _,ev in ipairs(today) do if ev.kind=='holiday' then holiday=ev end end;assert(holiday.ongoing);eq(holiday.minute,nil);assert(not ZZ.Core.calendarMatch('any',holiday))
    -- 23:30 realm is 00:30 local on the next day.
    local kz=days['2026-10-28'] and days['2026-10-28'][1];assert(kz and kz.title=='Karazhan',tostring(kz));eq(kz.minute,30)
    raidEvents[1].ev.title='Changed';eq(ZZ.Calendar:day('2026-10-25')[1].title~=nil,true)
    local again=ZZ.Calendar:range('2026-10-19','2026-11-29');eq(again,days)
    ZZ.Calendar:invalidate();raidEvents[1].ev.title='Molten Core'
    Mock.combat=true;local _,err=ZZ.Calendar:range('2026-01-01','2026-01-02');assert(err:find('combat'));Mock.combat=false
end)
test('Reminder before a WoW calendar event: builder, Today row, prompt note, timing window and share code',function()
    dismiss();wowCalendar(raidEvents)
    ZZ.UI:ruleDialog();local d=ZZ.UI.modal;click(d,'kind_calendar');local f=d.getFields()
    assert(f.calMatch and f.lead);eq(f.calMatch.value,'raid');Mock.choose(f.calMatch,'guild');click(d.pool.dynamic,'leadChip3')
    d.picker.tiles.burpees:Click();assert(d.summary:GetText():find('30 min before guild events'),d.summary:GetText());click(d,'save')
    local r;for _,v in pairs(ZugZugFitDB.rules) do if v.kind=='calendar' then r=v end end;assert(r);eq(r.lead,30);eq(r.calMatch,'guild')
    local e=ZZ.engine;e.calendarEvents=ZZ.Calendar:day(ZZ.Now().day)
    local base=Mock.now
    Mock.now=os.time({year=2026,month=10,day=25,hour=19,min=29});e:tick(1);assert(not e:pending(r.id),'too early')
    Mock.now=os.time({year=2026,month=10,day=25,hour=19,min=31});e:tick(1);local o=e:pending(r.id);assert(o,'30 min before')
    ZZ.UI:show('Today');local row;for k,v in pairs(ZZ.UI.frame.panels.Today.pool.nextBox.pool.nextList.body.pool) do if k:find('^cal') and v.shown then row=v end end
    assert(row and row.texts.title.text:find('before Molten Core'),row and row.texts.title.text)
    ZZ.UI.prompt.confirm=nil;ZZ.UI.prompt.demo=nil;ZZ.UI:drawPrompt(o);assert(ZZ.UI.prompt.texts.body.text:find('before Molten Core'));ZZ.UI:quickLog(o,o.amount)
    e:tick(1);assert(not e:pending(r.id),'one reminder per event')
    local r2=assert(e:addRule({activityID='plank',unit='minutes',amount=1,kind='calendar',calMatch='raid',lead=0,days='1234567',windowStart=0,windowEnd=1440}))
    Mock.now=os.time({year=2026,month=10,day=25,hour=20,min=20});e:tick(1);assert(not e:pending(r2.id),'more than 15 minutes late')
    local text=assert(e:shareText('Raid prep',{r.id}));local share=assert(e:decodeShare(ZZ.Core.findShare(text)))
    eq(share.rules[1].kind,'calendar');eq(share.rules[1].calMatch,'guild');eq(share.rules[1].lead,30)
    Mock.now=base;e:retireRule(r.id);e:retireRule(r2.id);dismiss();ZZ.UI:finish()
end)
test('Calendar tab shows WoW events in the month grid and day details, in local time',function()
    wowCalendar(raidEvents);ZZ.UI.mode='month';ZZ.UI.day='2026-10-25';ZZ.UI.month='2026-10-01';ZZ.UI:show('Calendar')
    local p=ZZ.UI.frame.panels.Calendar;local cell
    for _,c in ipairs(ZZ.UI.cells) do if c.texts.num.text:find('>?25|r') and c.texts.wow and c.texts.wow.shown then cell=c end end
    assert(cell,'a cell shows WoW events');assert(cell.texts.wow.text:find('+2',1,true),cell.texts.wow.text)
    local body=ZZ.UI.details;local found
    for k,v in pairs(body.pool) do if k:find('^wow') and v.shown and v.texts.text.text:find('Molten Core') then found=v end end
    assert(found and found.texts.text.text:find('20:00 %(realm 19:00%)'),found and found.texts.text.text)
    click(found,'plan');local f=ZZ.UI.modal.getFields();eq(f.at:GetText(),'19:30');ZZ.UI:finish()
    click(p,'appointments');assert(Mock.calendarOpened)
end)
test('Add to WoW calendar fills in Blizzard\'s Create Event window but never calls AddEvent',function()
    wowCalendar(raidEvents);C_Calendar.AddEvent=function() error('AddEvent must not be called') end
    local hooks={};function hooksecurefunc(name,fn) hooks[name]=fn end
    CalendarFrame=CreateFrame('Frame');CalendarFrame:Hide();CalendarFrame.militaryTime=true
    CalendarCreateEventFrame=CreateFrame('Frame');CalendarCreateEventTitleEdit=CreateFrame('EditBox')
    CalendarCreateEventDescriptionContainer={ScrollingEditBox=CreateFrame('EditBox')}
    function CalendarFrame_ShowEventFrame(frame) if hooks.CalendarFrame_ShowEventFrame then hooks.CalendarFrame_ShowEventFrame(frame) end end
    function Calendar_Show() CalendarFrame:Show() end
    local r=assert(ZZ.engine:addRule({activityID='yoga',unit='minutes',amount=15,kind='once',planDay='2026-10-27',at=1260,days='1234567',windowStart=0,windowEnd=1440}))
    ZZ.UI.day='2026-10-27';ZZ.UI:show('Calendar');local row=ZZ.UI.details.pool['rule'..r.id];assert(row and row.pool.wowAdd.shown)
    click(row,'wowAdd');assert(CalendarFrame:IsShown());eq(ZZ.UI.frame:IsShown(),false)
    -- Wrong day: nothing is filled in.
    CalendarCreateEventFrame.mode='create';CalendarCreateEventFrame.dayButton={monthOffset=0,day=26};CalendarFrame_ShowEventFrame(CalendarCreateEventFrame);eq(Mock.calTitle,nil)
    CalendarCreateEventFrame.dayButton={monthOffset=0,day=27};CalendarFrame_ShowEventFrame(CalendarCreateEventFrame)
    eq(Mock.calTitle,'ZugZugFit: 15 minutes Yoga');eq(CalendarCreateEventTitleEdit.text,Mock.calTitle)
    -- 21:00 local is 20:00 realm time.
    eq(Mock.calTime[1],20);eq(Mock.calTime[2],0);eq(CalendarCreateEventFrame.selectedHour,20)
    Mock.calTitle=nil;CalendarFrame_ShowEventFrame(CalendarCreateEventFrame);eq(Mock.calTitle,nil,'fills in one time only')
    ZZ.engine:retireRule(r.id);CalendarFrame=nil;CalendarCreateEventFrame=nil;hooksecurefunc=nil;ZZ.UI:show('Today')
end)
print('Client/UI scenarios: '..n..' passed (mock APIs, not native rendering)')
