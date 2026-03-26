---@class QuestieServer
local QuestieServer = QuestieLoader:CreateModule("QuestieServer")

---@type string
local realmName = GetRealmName() or ""

-- Client flavor detection from WoW globals
local WOW_PROJECT_ID        = WOW_PROJECT_ID or -1
local WOW_PROJECT_CLASSIC   = WOW_PROJECT_CLASSIC or 2
local WOW_PROJECT_BURNING_CRUSADE_CLASSIC = WOW_PROJECT_BURNING_CRUSADE_CLASSIC or 5
local WOW_PROJECT_WRATH_CLASSIC = WOW_PROJECT_WRATH_CLASSIC or 11
local WOW_PROJECT_MAINLINE  = WOW_PROJECT_MAINLINE or 1

-- Expansion detection
Questie.IsRetail    = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
Questie.IsWotlk     = (WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC)
Questie.IsTBC       = (WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC)
Questie.IsClassicEra = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)

-- Try GetBuildInfo for Turtle WoW (Interface: 11200, no WOW_PROJECT globals)
local _, _, _, tocVersion = GetBuildInfo()
Questie.IsTurtle    = (not Questie.IsRetail and not Questie.IsWotlk and not Questie.IsTBC and
                       not Questie.IsClassicEra and tocVersion and tocVersion < 20000)

-- Custom server detection
Questie.IsEbonhold  = false
Questie.IsAscension = false
Questie.IsValanior  = false

if _G.IsAscensionServer or realmName:find("Ascension") or realmName:find("Area 52") or
   realmName:find("Al'ar") or realmName:find("Thrall") then
    Questie.IsAscension = true
elseif realmName == "Ebonhold" or realmName == "Test Ebonhold" then
    Questie.IsEbonhold = true
elseif realmName == "Valanior" then
    Questie.IsValanior = true
end

-- Derive expected DB plugin name for this client
local function GetExpectedPluginFlavor()
    if Questie.IsAscension  then return "AscensionDB",  "Questie-X-AscensionDB"  end
    if Questie.IsEbonhold   then return "EbonholdDB",   "Questie-X-EbonholdDB"   end
    if Questie.IsValanior   then return "ValaniorDB",   "Questie-X-ValaniorDB"   end
    if Questie.IsTurtle     then return "TurtleDB",     "Questie-X-TurtleDB"     end
    if Questie.IsWotlk      then return "WotLKDB",      "Questie-X-WotLKDB"      end
    if Questie.IsTBC        then return "TBCDB",        "Questie-X-TBCDB"        end
    if Questie.IsClassicEra then return "ClassicDB",    "Questie-X-ClassicDB"    end
    if Questie.IsRetail     then return "RetailDB",     "Questie-X-RetailDB"     end
    return nil, nil
end

function QuestieServer:Init()
    Questie:Debug(Questie.DEBUG_INFO, "[QuestieServer] Realm:", realmName)
    Questie:Debug(Questie.DEBUG_INFO, "[QuestieServer] WOW_PROJECT_ID:", tostring(WOW_PROJECT_ID))
    Questie:Debug(Questie.DEBUG_INFO, "[QuestieServer] IsWotlk:", tostring(Questie.IsWotlk), "IsTBC:", tostring(Questie.IsTBC),
        "IsClassicEra:", tostring(Questie.IsClassicEra), "IsTurtle:", tostring(Questie.IsTurtle),
        "IsAscension:", tostring(Questie.IsAscension), "IsEbonhold:", tostring(Questie.IsEbonhold))
end

--- Checks if the correct DB plugin is loaded for the detected client/server.
--- Prints a friendly actionable warning to the chat frame if none is found.
function QuestieServer:WarnIfMissingPlugin()
    local QuestiePluginAPI = QuestieLoader:ImportModule("QuestiePluginAPI")
    if not QuestiePluginAPI then return end

    if QuestiePluginAPI:IsAnyPluginLoaded() then
        local flavor, addonName = GetExpectedPluginFlavor()
        local loadedFlavor = QuestiePluginAPI:GetLoadedFlavor()

        if flavor and loadedFlavor and loadedFlavor ~= flavor then
            Questie:Print(string.format(
                "|cFFFF8800[Questie-X]|r Warning: loaded database is |cFFFFFFFF%s|r but this client expects |cFFFFFFFF%s|r. " ..
                "Quest data may be incorrect. Install |cFF5EBAF3%s|r for best results.",
                loadedFlavor, flavor, addonName or flavor
            ))
        end
        return
    end

    -- No plugin at all
    local flavor, addonName = GetExpectedPluginFlavor()
    local msg
    if addonName then
        msg = string.format(
            "|cFFFF4444[Questie-X]|r No database plugin loaded. " ..
            "Download and install |cFF5EBAF3%s|r into your |cFFFFFFFFInterface/AddOns/|r folder, then reload. " ..
            "Questie-X will show no quest data until a database is installed.",
            addonName
        )
    else
        msg = "|cFFFF4444[Questie-X]|r No database plugin loaded and server type is unknown. " ..
              "Install the appropriate Questie-X database plugin for your server."
    end

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(msg)
    end
    Questie:Debug(Questie.DEBUG_CRITICAL, msg)
end

function QuestieServer:GetCustomQuest(questId)
    local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
    if not QuestieDB.questDataOverrides or not QuestieDB.questDataOverrides[questId] then
        return nil
    end

    local name = QuestieDB.QueryQuestSingle(questId, "name")
    if not name then return nil end

    local level    = QuestieDB.QueryQuestSingle(questId, "level") or QuestieDB.QueryQuestSingle(questId, "questLevel")
    local reqLevel = QuestieDB.QueryQuestSingle(questId, "requiredLevel") or QuestieDB.QueryQuestSingle(questId, "minLevel")
    local desc     = QuestieDB.QueryQuestSingle(questId, "objectiveText") or QuestieDB.QueryQuestSingle(questId, "description")

    local startedBy  = QuestieDB.QueryQuestSingle(questId, "startedBy")
    local finishedBy = QuestieDB.QueryQuestSingle(questId, "finishedBy")
    local specialFlags = QuestieDB.QueryQuestSingle(questId, "specialFlags")
    local isRepeatable = specialFlags and (bit.band(specialFlags, 1) ~= 0) or false

    return {
        Id           = questId,
        id           = questId,
        name         = name,
        level        = level or reqLevel or 0,
        requiredLevel = reqLevel or 0,
        Description  = desc,
        Starts       = { NPC = startedBy and startedBy[1] or {}, GameObject = startedBy and startedBy[2] or {}, Item = startedBy and startedBy[3] or {} },
        finishedBy   = finishedBy,
        IsRepeatable = isRepeatable,
    }
end

return QuestieServer
