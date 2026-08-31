local addon_name, _ = ...
local LARMR = LibStub("AceAddon-3.0"):GetAddon(addon_name)
local RangUser = LARMR:NewModule("RangUser")

local _G = getfenv(0)
local WorldFrame = _G.WorldFrame
local SecureButton
local lastClick

local fetchSpellId = 125050
local northrendRangId = 60854
local draenorRangId = 109167
local midnightRangId = 275683
local lootingMethod = nil

local function MakeSecureButton()
    SecureButton = CreateFrame("Button", "LARMRSecureButton", UIParent, "SecureActionButtonTemplate")
    SecureButton:Hide()
    SecureButton:EnableMouse(true)
    SecureButton:RegisterForClicks("RightButtonDown", "RightButtonUp")
    SecureButton:SetAttribute("action", "nil")

    SecureButton:SetScript("PostClick", function(self, button, up)
        if up then
            return
        end
        ClearOverrideBindings(self)
    end)
end

local function IsDoubleClick()
    return (GetTime() - (lastClick or 0)) < 0.2
end

local function CanConfigureSecureButton()
    return SecureButton ~= nil and not InCombatLockdown()
end

local function PlayerHasRang()
    if usedRangId ~= nil then
        return PlayerHasToy(usedRangId)
    end
    return false
end

local function SetLootingMethod(capabilities)
    if capabilities["northrendRang"] then
        lootingMethod = {
            ["method"] = "rang",
            ["id"] = northrendRangId
        }
    elseif capabilities["fetch"] then
        lootingMethod = {
            ["method"] = "fetch",
            ["id"] = fetchSpellId
        }
    elseif capabilities["midnightRang"] then
        lootingMethod = {
            ["method"] = "rang",
            ["id"] = midnightRangId
        }
    elseif capabilities["draenorRang"] then
        lootingMethod = {
            ["method"] = "rang",
            ["id"] = draenorRangId
        }
    end
end

local function ToyNotOnCooldown()
    if usedRangId ~= nil then
        return select(1, C_Container.GetItemCooldown(usedRangId)) == 0
    end
    return false
end

local function IsMoving()
    return not ((GetUnitSpeed("player") > 0) or IsFalling())
end

local function IsInCombat()
    return not (UnitAffectingCombat("player"))
end

local function IsPlayerMounted()
    return not IsMounted()
end

local function IsPlayerDead()
    return not UnitIsDeadOrGhost("player")
end

local function IsHunter()
    local _, class = UnitClass("player")
    return class == "HUNTER"
end

local function HasFetchSpell()
    return IsHunter() and IsSpellKnown(fetchSpellId)
end

local function IsFishing()
    -- Check if the player currently has the Fishing For Attention buff
    local buffId = 201354 -- Fishing For Attention

    local aura = C_UnitAuras.GetPlayerAuraBySpellID(buffId)
    local auraSpellId = aura and aura.spellId or nil

    if auraSpellId ~= nil then
        return false
    end
    return true
end

local function Checks()
    local checks = {
        ["IsMoving"] = IsMoving(),
        ["IsInCombat"] = IsInCombat(),
        ["IsPlayerMounted"] = IsPlayerMounted(),
        ["IsPlayerDead"] = IsPlayerDead(),
        ["IsFishing"] = IsFishing()
    }
    for k, v in pairs(checks) do
        if not v then
            return false
        end
    end
    return true
end

local function GetCapabilities()
    local capabilities = {
        ["northrendRang"] = false,
        ["midnightRang"] = false,
        ["draenorRang"] = PlayerHasToy(draenorRangId),
        ["fetch"] = HasFetchSpell()
    }
    local cataRequiredSkillForRang = 70
    local midnightRequiredSkillForRang = 1
    local engineeringSkillLineID = 202
    local cataEngineeringSkillLineID = 2503
    local midnightEngineeringSkillLineID = 2910
    local professions = {GetProfessions()}

    for _, profIndex in ipairs(professions) do
        local name, icon, skillLevel, maxSkillLevel, numAbilities, spelloffset, skillLine, skillModifier,
            specializationIndex, specializationOffset = GetProfessionInfo(profIndex)
        if skillLine == engineeringSkillLineID or skillLine == midnightEngineeringSkillLineID then
            local cataEngineering = C_TradeSkillUI.GetProfessionInfoBySkillLineID(cataEngineeringSkillLineID)
            local midnightEngineering = C_TradeSkillUI.GetProfessionInfoBySkillLineID(midnightEngineeringSkillLineID)
            if cataEngineering and cataEngineering.skillLevel >= cataRequiredSkillForRang and
                PlayerHasToy(northrendRangId) then
                capabilities["northrendRang"] = true
            end
            if midnightEngineering and midnightEngineering.skillLevel >= midnightRequiredSkillForRang and
                PlayerHasToy(midnightRangId) then
                capabilities["midnightRang"] = true
            end
        end
    end
    return capabilities
end

local function UseToy(id)
    if not CanConfigureSecureButton() then
        return false
    end

    if UnitExists("mouseover") then
        SecureButton:SetAttribute("unit", "mouseover")
    else
        SecureButton:SetAttribute("unit", nil)
    end

    SecureButton:SetAttribute("type", "item")
    SecureButton:SetAttribute("item", select(1, C_Item.GetItemInfo(id)))

    SetOverrideBindingClick(SecureButton, true, "BUTTON2", "LARMRSecureButton")
    lastClick = 0
    return true
end

local function UseSpell(id)
    if not CanConfigureSecureButton() then
        return false
    end

    -- Credit goes to SusuBunny on CurseForge for this fix
    local GetSpellInfo = GetSpellInfo or function(spellId)
        if not spellId then
            return nil
        end

        local spellInfo = C_Spell.GetSpellInfo(spellId);
        if spellInfo then
            return spellInfo.name, nil, spellInfo.iconID, spellInfo.castTime, spellInfo.minRange, spellInfo.maxRange,
                spellInfo.spellID, spellInfo.originalIconID;
        end
    end

    if UnitExists("mouseover") then
        SecureButton:SetAttribute("unit", "mouseover")
    else
        SecureButton:SetAttribute("unit", nil)
    end

    SecureButton:SetAttribute("type", "spell")
    SecureButton:SetAttribute("spell", select(1, GetSpellInfo(id)))
    SetOverrideBindingClick(SecureButton, true, "BUTTON2", "LARMRSecureButton")
    lastClick = 0
    return true
end

function LARMR:TOYS_UPDATED()
    SetLootingMethod(GetCapabilities())
end

function LARMR:OnMouseDown(frame, button)
    if button ~= "RightButton" then
        return
    end
    if InCombatLockdown() then
        lastClick = GetTime()
        return
    end
    if not IsDoubleClick() then
        lastClick = GetTime()
        return
    end

    if not Checks() then
        lastClick = GetTime()
        return
    end

    if lootingMethod["method"] == "rang" then
        UseToy(lootingMethod["id"])
    elseif lootingMethod["method"] == "fetch" then
        UseSpell(lootingMethod["id"])
    end

    lastClick = GetTime()
end

function RangUser:OnInitialize()
    MakeSecureButton()
end

function RangUser:OnEnable()
    SetLootingMethod(GetCapabilities())
    LARMR:SecureHookScript(WorldFrame, "OnMouseDown", "OnMouseDown")
    LARMR:RegisterEvent("TOYS_UPDATED")
end

function RangUser:OnDisable()
    LARMR:UnhookAll()
end
