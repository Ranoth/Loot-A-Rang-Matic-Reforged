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
local usedRangId = nil

local function MakeSecureButton()
    SecureButton = CreateFrame("Button", "LARMRSecureButton", UIParent, "SecureActionButtonTemplate")
    SecureButton:Hide()
    SecureButton:EnableMouse(true)
    SecureButton:RegisterForClicks("RightButtonDown", "RightButtonUp")
    SecureButton:SetAttribute("action", "nil")

    SecureButton:SetScript("PostClick", function(self, button, up)
        if up then return end
        ClearOverrideBindings(self)
    end)
end

local function IsDoubleClick()
    return (GetTime() - (lastClick or 0)) < 0.2
end

local function DoesPlayerHaveToy()
    if usedRangId ~= nil then return PlayerHasToy(usedRangId) end
    return false
end

local function isPlayerEngineer()
    local requiredSkill = 70
    local engineeringSkillLineID = 202
    local cataEngineeringSkillLineID = 2503
    local profs = { GetProfessions() }
    for _, profIndex in ipairs(profs) do
        local name, icon, skillLevel, maxSkillLevel, numAbilities, spelloffset, skillLine, skillModifier, specializationIndex, specializationOffset =
            GetProfessionInfo(profIndex)
        if skillLine == engineeringSkillLineID then
            local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(cataEngineeringSkillLineID)
            if info and info.skillLevel >= requiredSkill then
                return true
            end
        end
    end
    return false
end

local function IsToyOnCooldown()
    if usedRangId ~= nil then return select(1, C_Container.GetItemCooldown(usedRangId)) == 0 end
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

    if auraSpellId ~= nil then return false end
    return true
end

local function Checks()
    local checks = {
        -- ["IsDoubleClick"] = IsDoubleClick(),
        -- ["DoesPlayerHaveToy"] = DoesPlayerHaveToy(),
        -- ["isPlayerEngineer"] = isPlayerEngineer(),
        -- ["IsToyOnCooldown"] = IsToyOnCooldown(),
        ["IsMoving"] = IsMoving(),
        ["IsInCombat"] = IsInCombat(),
        ["IsPlayerMounted"] = IsPlayerMounted(),
        ["IsPlayerDead"] = IsPlayerDead(),
        ["IsFishing"] = IsFishing()
    }
    for k, v in pairs(checks) do
        if not v then
            -- print(k, "failed")
            return false
        end
    end
    return true
end

local function FindOwnedRang()
    if PlayerHasToy(northrendRangId) then
        usedRangId = northrendRangId
    elseif PlayerHasToy(draenorRangId) then
        usedRangId = draenorRangId
    else
        usedRangId = nil
    end
end

local function UseRang()
    local mouseoverGUID = _G.UnitGUID("mouseover")
    local staticMouseoverGUID
    if mouseoverGUID ~= nil then staticMouseoverGUID = mouseoverGUID end

    SecureButton:SetAttribute("type", "unit")
    SecureButton:SetAttribute("target", staticMouseoverGUID)

    SecureButton:SetAttribute("type", "item")
    SecureButton:SetAttribute("item", select(1, C_Item.GetItemInfo(usedRangId)))

    SetOverrideBindingClick(SecureButton, true, "BUTTON2", "LARMRSecureButton")
    lastClick = 0
end

local function UseFetch()
    local mouseoverGUID = _G.UnitGUID("mouseover")
    local staticMouseoverGUID
    if mouseoverGUID ~= nil then staticMouseoverGUID = mouseoverGUID end

    -- Credit goes to SusuBunny on CurseForge for this fix
    local GetSpellInfo = GetSpellInfo or function(spellId)
        if not spellId then return nil end

        local spellInfo = C_Spell.GetSpellInfo(spellId);
        if spellInfo then
            return spellInfo.name, nil, spellInfo.iconID, spellInfo.castTime, spellInfo.minRange, spellInfo.maxRange,
                spellInfo.spellID, spellInfo.originalIconID;
        end
    end

    SecureButton:SetAttribute("type", "unit")
    SecureButton:SetAttribute("target", staticMouseoverGUID)

    SecureButton:SetAttribute("type", "spell")
    SecureButton:SetAttribute("spell", select(1, GetSpellInfo(fetchSpellId)))
    SetOverrideBindingClick(SecureButton, true, "BUTTON2", "LARMRSecureButton")
    lastClick = 0
end

function LARMR:TOYS_UPDATED()
    FindOwnedRang()
end

function LARMR:OnMouseDown(frame, button)
    if button ~= "RightButton" then return end
    if not IsDoubleClick() then
        lastClick = GetTime()
        return
    end
    if Checks() and isPlayerEngineer() and DoesPlayerHaveToy() and IsToyOnCooldown() then
        UseRang()
    elseif Checks() and HasFetchSpell() then
        UseFetch()
    end
    lastClick = GetTime()
end

function RangUser:OnInitialize()
    MakeSecureButton()
end

function RangUser:OnEnable()
    FindOwnedRang()
    LARMR:SecureHookScript(WorldFrame, "OnMouseDown", "OnMouseDown")
    LARMR:RegisterEvent("TOYS_UPDATED")
end

function RangUser:OnDisable()
    LARMR:UnhookAll()
end
