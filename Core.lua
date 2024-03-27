local _G = _ENV or getfenv(0)
local WorldFrame = _G.WorldFrame
local SecureButton
local lastClick

LAR_M_R = LibStub("AceAddon-3.0"):NewAddon("ThisAddon", "AceEvent-3.0", "AceHook-3.0")

local fetchSpellId = 125050
local northredRangId = 60854
local draenorRangId = 109167
local usedRangId = nil

local function MakeSecureButton()
    SecureButton = CreateFrame("Button", "SecureButton", UIParent, "SecureActionButtonTemplate")
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
    local prof1, prof2 = GetProfessions()
    if prof1 and prof2 then
        local _, _, _, _, _, _, prof1 = GetProfessionInfo(prof1)
        local _, _, _, _, _, _, prof2 = GetProfessionInfo(prof2)
        return prof1 == 202 or prof2 == 202
    end
    return false
end

local function IsToyOnCooldown()
    if usedRangId ~= nil then return select(1, GetItemCooldown(usedRangId)) == 0 end
    return false
end

local function IsMoving()
    return not ((GetUnitSpeed("player") > 0) or IsFalling())
end

local function IsInCombat()
    return not (UnitAffectingCombat("player"))
end

local function IsPlayerMounted()
    return not (IsMounted() or IsFlying() or IsSwimming())
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

local function Checks()
    local checks = {
        ["IsDoubleClick"] = IsDoubleClick(),
        -- ["DoesPlayerHasToy"] = DoesPlayerHaveToy(),
        -- ["isPlayerEngineer"] = isPlayerEngineer(),
        -- ["IsToyOnCooldown"] = IsToyOnCooldown(),
        ["IsMoving"] = IsMoving(),
        ["IsInCombat"] = IsInCombat(),
        ["IsPlayerMounted"] = IsPlayerMounted(),
        ["IsPlayerDead"] = IsPlayerDead()
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
    if PlayerHasToy(northredRangId) then
        usedRangId = northredRangId
    elseif PlayerHasToy(draenorRangId) then
        usedRangId = draenorRangId
    else
        usedRangId = nil
    end
end

local function UseRang()
    local targetGUID, mouseoverGUID = _G.UnitGUID("target"), _G.UnitGUID("mouseover")
    -- print(targetGUID, mouseoverGUID)
    SecureButton:SetAttribute("type", "unit")
    SecureButton:SetAttribute("target", targetGUID or mouseoverGUID)
    
    SecureButton:SetAttribute("type", "item")
    SecureButton:SetAttribute("item", select(1, GetItemInfo(usedRangId)))
    
    SetOverrideBindingClick(SecureButton, true, "BUTTON2", "SecureButton")
    lastClick = 0
end

local function UseFetch()
    local targetGUID, mouseoverGUID = _G.UnitGUID("target"), _G.UnitGUID("mouseover")
    -- print(targetGUID, mouseoverGUID)
    SecureButton:SetAttribute("type", "unit")
    SecureButton:SetAttribute("target", targetGUID or mouseoverGUID)

    SecureButton:SetAttribute("type", "spell")
    SecureButton:SetAttribute("spell", select(1, GetSpellInfo(fetchSpellId)))
    SetOverrideBindingClick(SecureButton, true, "BUTTON2", "SecureButton")
    lastClick = 0
end

function LAR_M_R:OnToyUpdate()
    FindOwnedRang()
end

function LAR_M_R:OnMouseDown(frame, button)
    if button ~= "RightButton" then return end
    if Checks() and isPlayerEngineer() and DoesPlayerHaveToy() and IsToyOnCooldown() then
        UseRang()
    elseif Checks() and HasFetchSpell() then
        UseFetch()
    end
    lastClick = GetTime()
end

function LAR_M_R:OnInitialize()
    MakeSecureButton()
end

function LAR_M_R:OnEnable()
    FindOwnedRang()
    self:SecureHookScript(WorldFrame, "OnMouseDown", "OnMouseDown")
    self:RegisterEvent("TOYS_UPDATED", "OnToyUpdate")
end

function LAR_M_R:OnDisable()
    self:UnhookAll()
end
