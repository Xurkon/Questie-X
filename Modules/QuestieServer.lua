---@class QuestieServer
local QuestieServer = QuestieLoader:CreateModule("QuestieServer")

-- Check for runtime server globals or profile matches early in the initialization phase.
-- We do this BEFORE any database tables evaluate so their memory isn't allocated if unused.

---@type string
local realmName = GetRealmName() or ""

Questie.IsEbonhold = false
Questie.IsAscension = false
Questie.IsValanior = false

if _G.IsAscensionServer or realmName == "Ascension" or realmName:find("Area 52") or realmName:find("Al'ar") or realmName:find("Thrall") then
    Questie.IsAscension = true
elseif realmName == "Ebonhold" or realmName == "Test Ebonhold" then
    Questie.IsEbonhold = true
elseif realmName == "Valanior" then
    Questie.IsValanior = true
end

-- Also check QuestieConfig if it was loaded (fallback for forcing a profile)
if QuestieConfig and QuestieConfig.profileKeys then
    -- It's theoretically possible a player has explicitly overridden the profile in Ace3 Options
    -- but usually we trust the dynamic realm name detection over saved profiles for the core loader.
end

function QuestieServer:Init()
    -- This handles any universal server logic before Database Init
    Questie:Debug(Questie.DEBUG_INFO, "[QuestieServer] Detected Realm:", realmName)
    Questie:Debug(Questie.DEBUG_INFO, "[QuestieServer] IsAscension:", Questie.IsAscension)
    Questie:Debug(Questie.DEBUG_INFO, "[QuestieServer] IsEbonhold:", Questie.IsEbonhold)
    Questie:Debug(Questie.DEBUG_INFO, "[QuestieServer] IsValanior:", Questie.IsValanior)
end

function QuestieServer:GetCustomQuest(questId)
    -- This provides a formal API for fetching quests injected by custom server DBs
    -- that bypasses the binary stream without using function monkeypatching.
    local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
    if not QuestieDB.questDataOverrides or not QuestieDB.questDataOverrides[questId] then
        return nil
    end

    local name = QuestieDB.QueryQuestSingle(questId, "name")
    if not name then return nil end

    local level = QuestieDB.QueryQuestSingle(questId, "level") or QuestieDB.QueryQuestSingle(questId, "questLevel")
    local reqLevel = QuestieDB.QueryQuestSingle(questId, "requiredLevel") or QuestieDB.QueryQuestSingle(questId, "minLevel")
    local desc = QuestieDB.QueryQuestSingle(questId, "objectiveText") or QuestieDB.QueryQuestSingle(questId, "description") or QuestieDB.QueryQuestSingle(questId, "details")

    local startedBy = QuestieDB.QueryQuestSingle(questId, "startedBy")
    local starts = {
        NPC = startedBy and startedBy[1] or {},
        GameObject = startedBy and startedBy[2] or {},
        Item = startedBy and startedBy[3] or {},
    }

    local finishedBy = QuestieDB.QueryQuestSingle(questId, "finishedBy")
    local specialFlags = QuestieDB.QueryQuestSingle(questId, "specialFlags")
    local isRepeatable = specialFlags and (bit.band(specialFlags, 1) ~= 0) or false

    return {
        Id = questId,
        id = questId,
        name = name,
        level = level or reqLevel or 0,
        requiredLevel = reqLevel or 0,
        Description = desc,
        Starts = starts,
        finishedBy = finishedBy,
        IsRepeatable = isRepeatable,
    }
end

return QuestieServer
