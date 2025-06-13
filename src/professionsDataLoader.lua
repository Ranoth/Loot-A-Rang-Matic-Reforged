local addon_name, _ = ...
local LARMR = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local ProfessionsDataLoader = LARMR:NewModule("ProfessionsDataLoader")

-- Workaround found at https://github.com/Stanzilla/WoWUIBugs/issues/424#issuecomment-1522140660

local version = 5
if _G['ForceLoadTradeSkillData'] then
	if _G['ForceLoadTradeSkillData'].version < version then
		_G['ForceLoadTradeSkillData']:UnregisterAllEvents()
	else
		return
	end
end

local hack = CreateFrame('Frame', 'ForceLoadTradeSkillData')
hack.version = version
hack:SetPropagateKeyboardInput(true) -- make sure we don't own the keyboard
hack:RegisterEvent('PLAYER_LOGIN')
hack:SetScript('OnEvent', function(self, event)
	if event == 'PLAYER_LOGIN' or event == 'SKILL_LINES_CHANGED' then
		self:UnregisterEvent(event)

		local professionID = self:GetAnyProfessionID()
		if not professionID then
			-- player has no professions, wait for them to learn one
			self:RegisterEvent('SKILL_LINES_CHANGED')
		elseif not self:HasProfessionData(professionID) then
			-- player has profession but the session has no data, listen for key event
			self.professionID = professionID
			self:SetScript('OnKeyDown', self.OnKeyDown)
		end
	elseif event == 'TRADE_SKILL_SHOW' then
		if not (C_TradeSkillUI.IsTradeSkillLinked() or C_TradeSkillUI.IsTradeSkillGuild()) then
			-- we've triggered the tradeskill UI, close it again and bail out
			C_Timer.After(0, function()
				-- wait for next frame so we can get full data
				C_TradeSkillUI.CloseTradeSkill()
			end)
			self:UnregisterEvent(event)
			UIParent:RegisterEvent(event)

			-- unmute sounds
			UnmuteSoundFile(SOUNDKIT.UI_PROFESSIONS_WINDOW_OPEN)
			UnmuteSoundFile(SOUNDKIT.UI_PROFESSIONS_WINDOW_CLOSE)
		end
	end
end)

function hack:OnKeyDown()
	-- unregister ourselves first to avoid duplicate queries
	self:SetScript('OnKeyDown', nil)

	-- be silent
	MuteSoundFile(SOUNDKIT.UI_PROFESSIONS_WINDOW_OPEN)
	MuteSoundFile(SOUNDKIT.UI_PROFESSIONS_WINDOW_CLOSE)

	-- listen for tradeskill UI opening then query it
	UIParent:UnregisterEvent('TRADE_SKILL_SHOW')
	self:RegisterEvent('TRADE_SKILL_SHOW')
	C_TradeSkillUI.OpenTradeSkill(self.professionID)
end

function hack:GetAnyProfessionID()
	-- any profession except archaeology is valid for requesting data
	for index, professionIndex in next, {GetProfessions()} do
		if index ~= 3 and professionIndex then
			local _, _, _, _, _, _, professionID = GetProfessionInfo(professionIndex)
			if professionID then
				return professionID
			end
		end
	end
end

function hack:HasProfessionData(professionID)
	local skillInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(professionID)
	return skillInfo and skillInfo.maxSkillLevel and skillInfo.maxSkillLevel > 0
end
