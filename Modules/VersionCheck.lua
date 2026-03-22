local addonName, _ = ...

--- COMPATIBILITY ---
local C_Timer = QuestieCompat.C_Timer
local WOW_PROJECT_CLASSIC = QuestieCompat.WOW_PROJECT_CLASSIC
local WOW_PROJECT_BURNING_CRUSADE_CLASSIC = QuestieCompat.WOW_PROJECT_BURNING_CRUSADE_CLASSIC
local WOW_PROJECT_WRATH_CLASSIC = QuestieCompat.WOW_PROJECT_WRATH_CLASSIC
local WOW_PROJECT_ID = QuestieCompat.WOW_PROJECT_ID
-- Fix #3: Use QuestieCompat.C_Seasons instead of bare _G[C_Seasons].  On old clients
-- where C_Seasons is absent, QuestieCompat provides a safe polyfill (always returns
-- false/0).  On modern clients the native is used directly.
local C_Seasons = QuestieCompat.C_Seasons

-- Check addon is not renamed to avoid conflicts in global name space.
-- (Removed because Questie-X is meant to be run universally and its folder name is Questie-X)



--Initialized below
---@class Questie : AceAddon, AceConsole-3.0, AceEvent-3.0, AceTimer-3.0, AceComm-3.0, AceBucket-3.0
-- In Questie-X, the Questie object is created early by QuestieLoader.
-- We use that existing object here to ensure all modules share the same instance.
local function InitializeQuestie()
    local existingQuestie = QuestieLoader:ImportModule("Questie")

    local ok, err = pcall(function() 
        LibStub("AceAddon-3.0"):NewAddon(existingQuestie, addonName, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceComm-3.0", "AceBucket-3.0")
    end)
    if not ok then
        Questie:Error("ERROR inside NewAddon: " .. tostring(err))
    end
    
    -- Ensure the global reference points to our unified object
    _G.Questie = existingQuestie
    return existingQuestie
end

Questie = InitializeQuestie()

-- preinit placeholder to stop tukui crashing from literally force-removing one of our features no matter what users select in the config ui
Questie.db = {profile={minimap={hide=false}}}

-- prevent multiple warnings for the same ID, not sure the best place to put this
Questie._sessionWarnings = {}

local clientVersion = GetBuildInfo()
--- Addon is running on Classic Wotlk client
---@type boolean
Questie.IsWotlk = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC

--- Addon is running on Classic TBC client
---@type boolean
Questie.IsTBC = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC

--- Addon is running on Classic "Vanilla" client: Means Classic Era and its seasons like SoM
---@type boolean
Questie.IsClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC

--- Addon is running on Classic "Vanilla" client and on Era realm (non-seasonal)
---@type boolean
Questie.IsEra = Questie.IsClassic and (not C_Seasons.HasActiveSeason())

--- Addon is running on Classic "Vanilla" client and on any Seasonal realm (see: https://wowpedia.fandom.com/wiki/API_C_Seasons.GetActiveSeason )
---@type boolean
Questie.IsEraSeasonal = Questie.IsClassic and C_Seasons.HasActiveSeason()

--- Addon is running on Classic "Vanilla" client and on Season of Mastery realm specifically
---@type boolean
Questie.IsSoM = Questie.IsClassic and C_Seasons.HasActiveSeason() and (C_Seasons.GetActiveSeason() == Enum.SeasonID.SeasonOfMastery)

--- Addon is running on Classic "Vanilla" client and on Season of Discovery realm specifically
---@type boolean
Questie.IsSoD = Questie.IsClassic and C_Seasons.HasActiveSeason() and (C_Seasons.GetActiveSeason() ~= Enum.SeasonID.Hardcore)

--- Addon is running on a HardCore realm specifically
---@type boolean
Questie.IsHardcore = C_GameRules and C_GameRules.IsHardcoreActive()
