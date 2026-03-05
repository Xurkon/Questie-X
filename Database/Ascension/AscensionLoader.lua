---@class AscensionLoader
---@type table
local AscensionLoader = QuestieLoader:CreateModule("AscensionLoader")

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")

---@type table
local AscensionDB = QuestieLoader:ImportModule("AscensionDB")
_G.AscensionDB = _G.AscensionDB or AscensionDB

local _overridesInjected = false
local _zonesApplied = false

local function _LoadIfString(data, label)
    if not data then return nil end
    if type(data) == "string" then
        local fn, err = loadstring(data)
        if not fn then
            if Questie and Questie.Debug then
                Questie:Debug(Questie.DEBUG_CRITICAL, "[AscensionLoader] loadstring failed for " .. tostring(label) .. ": " .. tostring(err))
            end
            return nil
        end
        local ok, tbl = pcall(fn)
        if not ok then
            if Questie and Questie.Debug then
                Questie:Debug(Questie.DEBUG_CRITICAL, "[AscensionLoader] executing chunk failed for " .. tostring(label) .. ": " .. tostring(tbl))
            end
            return nil
        end
        return tbl
    end
    return data
end

local function _MergeInto(dst, src)
    if type(dst) ~= "table" or type(src) ~= "table" then return end
    for id, entry in pairs(src) do
        dst[id] = entry
    end
end

-- Apply Ascension custom uiMapId->areaId mappings into ZoneDB (used by map/Journey)
function AscensionLoader:ApplyZoneTables()
    if _zonesApplied then return end
    
    -- Skip if not on Ascension server (check if we should even be here)
    if _G.IsAscensionServer == nil and (not Questie or not Questie.db or not Questie.db.profile or not Questie.db.profile.ascensionMode) then
        -- Check if there's actual Ascension data - if quest IDs >= 100000, it's likely Ascension
        local hasAscensionQuests = false
        if AscensionDB and AscensionDB.questData then
            for questId, _ in pairs(AscensionDB.questData or {}) do
                if type(questId) == "number" and questId >= 100000 then
                    hasAscensionQuests = true
                    break
                end
            end
        end
        if not hasAscensionQuests then
            _zonesApplied = true -- Mark as done to prevent rechecking
            return
        end
    end
    
    if not AscensionZoneTables or not AscensionZoneTables.uiMapIdToAreaId then return end

    local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
    if not ZoneDB then return end

    ZoneDB.private = ZoneDB.private or {}
    ZoneDB.private.uiMapIdToAreaId = ZoneDB.private.uiMapIdToAreaId or {}
    ZoneDB.private.areaIdToUiMapId = ZoneDB.private.areaIdToUiMapId or {}
    ZoneDB.private.subZoneToParentZone = ZoneDB.private.subZoneToParentZone or {}

    for uiMapId, areaId in pairs(AscensionZoneTables.uiMapIdToAreaId) do
        if uiMapId and areaId then
            -- Always set these mappings (remove the nil check to ensure they're set)
            ZoneDB.private.uiMapIdToAreaId[uiMapId] = areaId
            
            -- Ascension uses custom map ids for spawns/waypoints (e.g. 1238 for Northshire Valley).
            -- QuestieMap draws by converting AreaId->UiMapId, so register these ids as self-mapping.
            ZoneDB.private.areaIdToUiMapId[uiMapId] = uiMapId
            
            -- Register subzone to parent zone mapping so GetParentZoneId works with Ascension zones
            if uiMapId ~= areaId then
                ZoneDB.private.subZoneToParentZone[uiMapId] = areaId
            end
        end
    end

    -- Also map parentMapIDs (e.g. 10138) to a usable uiMapId to avoid fallback errors.
    if AscensionUiMapData and AscensionUiMapData.uiMapData then
        for uiMapId, data in pairs(AscensionUiMapData.uiMapData) do
            if uiMapId and ZoneDB.private.areaIdToUiMapId[uiMapId] == nil then
                ZoneDB.private.areaIdToUiMapId[uiMapId] = uiMapId
            end
            if data and type(data.parentMapID) == "number" and ZoneDB.private.areaIdToUiMapId[data.parentMapID] == nil then
                ZoneDB.private.areaIdToUiMapId[data.parentMapID] = uiMapId
            end
        end
    end

    -- Register zone sort names for custom zones
    if AscensionZoneTables.zoneSort then
        ZoneDB.private.zoneSort = ZoneDB.private.zoneSort or {}
        for zoneId, zoneName in pairs(AscensionZoneTables.zoneSort) do
            ZoneDB.private.zoneSort[zoneId] = zoneName
        end
    end
    -- Clear cached zone lookups after adding custom zones
    if QuestieDB and QuestieDB.private and QuestieDB.private.zoneCache then
        QuestieDB.private.zoneCache = {}
    end
    
    -- Clear auto-blacklist since zone validation might have changed
    if QuestieDB and QuestieDB.autoBlacklist then
        QuestieDB.autoBlacklist = {}
    end
    _zonesApplied = true
end

-- Inject Ascension tables into QuestieDB *Overrides* so QueryQuestSingle/QueryNPCSingle can see them
function AscensionLoader:InjectOverrides()
    if _overridesInjected then return end
    
    -- Ascension data should only load on Ascension servers
    -- Check if this is an Ascension server by looking for a global or profile setting
    local isAscension = false
    
    -- Method 1: Check for Ascension-specific global (servers may set this)
    if _G.IsAscensionServer then
        isAscension = true
    end
    
    -- Method 2: Check profile setting
    if Questie and Questie.db and Questie.db.profile and Questie.db.profile.ascensionMode then
        isAscension = true
    end
    
    -- Method 3: Check if there's actually Ascension quest data loaded
    -- (this is a fallback - if AscensionDB has real data, use it)
    if not isAscension and AscensionDB and AscensionDB.questData then
        local questDataType = type(AscensionDB.questData)
        -- If it's a table with entries, it's likely real Ascension data
        if questDataType == "table" then
            local hasData = false
            for _ in pairs(AscensionDB.questData) do
                hasData = true
                break
            end
            if hasData then
                -- Only use Ascension data if quest ID ranges suggest it's not standard WoW
                -- Standard WoW quest IDs are typically < 100000
                for questId, _ in pairs(AscensionDB.questData) do
                    if type(questId) == "number" and questId >= 100000 then
                        isAscension = true
                        break
                    end
                end
            end
        end
    end
    
    if not isAscension then
        -- Not an Ascension server, skip loading Ascension data
        _overridesInjected = true -- Mark as done to prevent rechecking
        return
    end

    _overridesInjected = true

    -- Apply zone tables FIRST, before any ZoneDB functions use the local variables
    AscensionLoader:ApplyZoneTables()

    QuestieDB.npcDataOverrides = QuestieDB.npcDataOverrides or {}
    QuestieDB.objectDataOverrides = QuestieDB.objectDataOverrides or {}
    QuestieDB.itemDataOverrides = QuestieDB.itemDataOverrides or {}
    QuestieDB.questDataOverrides = QuestieDB.questDataOverrides or {}

    local npcData    = _LoadIfString(AscensionDB and AscensionDB.npcData, "AscensionDB.npcData")
    local objectData = _LoadIfString(AscensionDB and AscensionDB.objectData, "AscensionDB.objectData")
    local itemData   = _LoadIfString(AscensionDB and AscensionDB.itemData, "AscensionDB.itemData")
    local questData  = _LoadIfString(AscensionDB and AscensionDB.questData, "AscensionDB.questData")

    _MergeInto(QuestieDB.npcDataOverrides, npcData)
    _MergeInto(QuestieDB.objectDataOverrides, objectData)
    _MergeInto(QuestieDB.itemDataOverrides, itemData)
    _MergeInto(QuestieDB.questDataOverrides, questData)

    -- Keep a lightweight list of custom quest ids for search/UI (DO NOT touch QuestPointers; those are numeric stream pointers)
    if type(questData) == "table" then
        QuestieDB.ascensionQuestIds = QuestieDB.ascensionQuestIds or {}
        for questId, _ in pairs(questData) do
            if type(questId) == "number" then
                QuestieDB.ascensionQuestIds[questId] = true
            end
        end
    end
    
    -- Keep a lightweight list of custom NPC ids for search/UI
    if type(npcData) == "table" then
        QuestieDB.ascensionNpcIds = QuestieDB.ascensionNpcIds or {}
        for npcId, _ in pairs(npcData) do
            if type(npcId) == "number" then
                QuestieDB.ascensionNpcIds[npcId] = true
            end
        end
    end
    
    -- Keep a lightweight list of custom object ids for search/UI
    if type(objectData) == "table" then
        QuestieDB.ascensionObjectIds = QuestieDB.ascensionObjectIds or {}
        for objectId, _ in pairs(objectData) do
            if type(objectId) == "number" then
                QuestieDB.ascensionObjectIds[objectId] = true
            end
        end
    end
    
    -- Keep a lightweight list of custom item ids for search/UI
    if type(itemData) == "table" then
        QuestieDB.ascensionItemIds = QuestieDB.ascensionItemIds or {}
        for itemId, _ in pairs(itemData) do
            if type(itemId) == "number" then
                QuestieDB.ascensionItemIds[itemId] = true
            end
        end
    end
end

-- Hook ZoneDB.Initialize to inject custom zones BEFORE standard zones are processed
do
    local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
    if ZoneDB then
        local originalZoneInitialize = ZoneDB.Initialize
        if type(originalZoneInitialize) == "function" then
            function ZoneDB:Initialize(...)
                -- Apply custom zones FIRST, before standard zone processing
                AscensionLoader:ApplyZoneTables()
                
                -- Then initialize standard zones
                return originalZoneInitialize(self, ...)
            end
        end
    end
end

-- Hook QuestieDB.Initialize to guarantee timing for overrides
do
    local originalInitialize = QuestieDB and QuestieDB.Initialize
    if type(originalInitialize) == "function" then
        function QuestieDB:Initialize(...)
            -- 1) Inject overrides before the DB handles are created
            AscensionLoader:InjectOverrides()

            local ret = originalInitialize(self, ...)

            -- 2) Refresh Journey caches (zoneMap/zones) so "Quests by Zone" sees the new data
            local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
            local QuestieJourney = QuestieLoader:ImportModule("QuestieJourney")
            if ZoneDB and QuestieJourney then
                QuestieJourney.zoneMap = ZoneDB:GetZonesWithQuests(true)
                QuestieJourney.zones = ZoneDB:GetRelevantZones()

                -- Clear the UI cache so the tree gets rebuilt
                if QuestieJourney.private then
                    QuestieJourney.private.treeCache = nil
                    QuestieJourney.private.lastZoneSelection = {}
                end

                -- If the Journey window is open, rebuild the current tab
                if QuestieJourneyFrame and QuestieJourneyFrame:IsShown() and QuestieJourney.tabGroup then
                    local p = QuestieJourney.private
                    if p and p.containerCache and p.lastOpenWindow then
                        p:HandleTabChange(p.containerCache, p.lastOpenWindow)
                    end
                end
            end

            return ret
        end
    end
end

-- >>> NEW: Make QuestieDB.GetQuest work for Ascension override quests (Journey needs this)
do
    local originalGetQuest = QuestieDB.GetQuest
    if type(originalGetQuest) == "function" then
        function QuestieDB.GetQuest(questId)
            local q = originalGetQuest(questId)
            if q then return q end

            -- Fallback: build a minimal quest object from QueryQuestSingle (works with overrides)
            local name = QuestieDB.QueryQuestSingle(questId, "name")
            if not name then return nil end

            local level = QuestieDB.QueryQuestSingle(questId, "level") or QuestieDB.QueryQuestSingle(questId, "questLevel")
            local reqLevel = QuestieDB.QueryQuestSingle(questId, "requiredLevel") or QuestieDB.QueryQuestSingle(questId, "minLevel")
            local desc = QuestieDB.QueryQuestSingle(questId, "objectiveText") or QuestieDB.QueryQuestSingle(questId, "description") or QuestieDB.QueryQuestSingle(questId, "details")
            
            -- Build the Starts field from startedBy (CRITICAL for available quests to show icons!)
            local startedBy = QuestieDB.QueryQuestSingle(questId, "startedBy")
            
            local starts = {
                NPC = startedBy and startedBy[1] or {},
                GameObject = startedBy and startedBy[2] or {},
                Item = startedBy and startedBy[3] or {},
            }
            
            -- Also get other fields needed for quest display
            local finishedBy = QuestieDB.QueryQuestSingle(questId, "finishedBy")
            local specialFlags = QuestieDB.QueryQuestSingle(questId, "specialFlags")
            local isRepeatable = specialFlags and (bit.band(specialFlags, 1) ~= 0) or false

            -- Questie modules expect these common fields
            return {
                Id = questId,
                id = questId,
                name = name,
                level = level or reqLevel or 0,
                requiredLevel = reqLevel or 0,
                Description = desc, -- Journey tooltip reads quest.Description
                Starts = starts, -- CRITICAL: AvailableQuests needs this!
                finishedBy = finishedBy,
                IsRepeatable = isRepeatable,
            }
        end
    end
end


-- Ensure zones also get applied when Questie finishes loading (covers edge cases)
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(_, _, name)
        if name ~= "Questie-X" then return end
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function() AscensionLoader:ApplyZoneTables() end)
        else
            AscensionLoader:ApplyZoneTables()
        end
    end)
end

return AscensionLoader
