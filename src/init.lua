--- Initialize the addon and set up the settings database.
--- @module "Init"

local addon_name, _ = ...
local LARMR = LibStub("AceAddon-3.0"):NewAddon(addon_name, "AceEvent-3.0", "AceHook-3.0")

function LARMR:OnInitialize()
end

function LARMR:OnEnable()
end

function LARMR:OnDisable()
    LARMR:UnhookAll()
    LARMR:UnregisterAllEvents()
end
