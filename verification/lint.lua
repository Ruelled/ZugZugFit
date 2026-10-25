package.path='../PaladinRegen/.tools/luacheck-1.2.0/src/?.lua;../PaladinRegen/.tools/luacheck-1.2.0/src/?/init.lua;'..package.path
local lint=require('luacheck')
local report=lint.check_files({'ZugZugFit/Core.lua','ZugZugFit/Model.lua','ZugZugFit/Guild.lua','ZugZugFit/Widgets.lua','ZugZugFit/Calendar.lua','ZugZugFit/UI.lua','ZugZugFit/Client.lua'}, {
    std='lua51', max_line_length=false, unused_args=false,
    globals={'ZugZugFitDB','SLASH_ZUGZUGFIT1','SLASH_ZUGZUGFIT2','SlashCmdList','ZugZugFitWindow','UISpecialFrames'},
    read_globals={'GetCursorPosition','CreateFrame','UIParent','DEFAULT_CHAT_FRAME','time','date','InCombatLockdown','UnitIsAFK','issecretvalue','GetRealZoneText','IsInGroup','IsInGuild','PlaySound','C_ChatInfo','C_Spell','GetSpellInfo','C_UnitAuras','SendChatMessage','Minimap','GameTooltip','GetBuildInfo','UnitFullName','UnitName','GetNormalizedRealmName','GetRealmName','GetGuildInfo','GetNumGuildMembers','GetGuildRosterInfo','C_GuildInfo','GuildRoster','RegisterAddonMessagePrefix','SendAddonMessage','Settings','InterfaceOptions_AddCategory','UnitBuff','Enum','C_Calendar','EventRegistry','ChatFrameUtil','ChatFrame_AddMessageEventFilter','ChatFrame_OpenChat','ChatEdit_GetActiveWindow','GetMacroIcons','GetMacroItemIcons','GetLooseMacroIcons','GetLooseMacroItemIcons','IsInInstance','GetInstanceInfo','UnitIsDeadOrGhost','GameFontHighlightSmall','C_DateAndTime','C_AddOns','LoadAddOn','hooksecurefunc','ShowUIPanel','Calendar_Show','CalendarFrame','CalendarCreateEventFrame','CalendarCreateEventTitleEdit','CalendarCreateEventDescriptionContainer','CalendarCreateEvent_UpdateEventTime','CalendarFrame_ShowEventFrame'},
})
for i,issues in ipairs(report) do
    if issues.fatal then print(issues.msg) else
        for _,issue in ipairs(issues) do print(i..':'..issue.line..': '..issue.code..' '..lint.get_message(issue)) end
    end
end
print(string.format('Lint: %d errors, %d warnings, %d fatal',report.errors,report.warnings,report.fatals))
os.exit(report.errors+report.warnings+report.fatals==0 and 0 or 1)
