if not Questie.IsEbonhold then return end
---@class EbonholdLoader
---@type table
local EbonholdLoader = QuestieLoader:CreateModule("EbonholdLoader")

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")

---@type table
local EbonholdDB = QuestieLoader:ImportModule("EbonholdDB")
_G.EbonholdDB = _G.EbonholdDB or EbonholdDB

local _overridesInjected = false
local _zonesApplied = false

local function _LoadIfString(data, label)
    if not data then return nil end
    if type(data) == "string" then
        local fn, err = loadstring(data)
        if not fn then
            if Questie and Questie.Debug then
                Questie:Debug(Questie.DEBUG_CRITICAL,
                    "[EbonholdLoader] loadstring failed for " .. tostring(label) .. ": " .. tostring(err))
            end
            return nil
        end
        local ok, tbl = pcall(fn)
        if not ok then
            if Questie and Questie.Debug then
                Questie:Debug(Questie.DEBUG_CRITICAL,
                    "[EbonholdLoader] executing chunk failed for " .. tostring(label) .. ": " .. tostring(tbl))
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

-- Apply Ebonhold custom uiMapId->areaId mappings into ZoneDB (used by map/Journey)
function EbonholdLoader:ApplyZoneTables()
    if _zonesApplied then return end
    if not EbonholdZoneTables or not EbonholdZoneTables.uiMapIdToAreaId then return end

    local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
    if not ZoneDB then return end

    ZoneDB.private = ZoneDB.private or {}
    ZoneDB.private.uiMapIdToAreaId = ZoneDB.private.uiMapIdToAreaId or {}
    ZoneDB.private.areaIdToUiMapId = ZoneDB.private.areaIdToUiMapId or {}
    ZoneDB.private.subZoneToParentZone = ZoneDB.private.subZoneToParentZone or {}
    ZoneDB.private.dungeons = ZoneDB.private.dungeons or {}
    ZoneDB.private.dungeonLocations = ZoneDB.private.dungeonLocations or {}
    ZoneDB.private.dungeonParentZones = ZoneDB.private.dungeonParentZones or {}

    for uiMapId, areaId in pairs(EbonholdZoneTables.uiMapIdToAreaId) do
        if uiMapId and areaId then
            -- Always set these mappings (remove the nil check to ensure they're set)
            ZoneDB.private.uiMapIdToAreaId[uiMapId] = areaId

            -- Ebonhold uses custom map ids for spawns/waypoints (e.g. 1238 for Northshire Valley).
            -- QuestieMap draws by converting AreaId->UiMapId, so register these ids as self-mapping.
            ZoneDB.private.areaIdToUiMapId[uiMapId] = uiMapId

            -- If this uiMapId represents a *dungeon* map, prefer it for that dungeon's AreaId.
            -- This keeps normal zones intact (e.g. Elwynn stays 1429), while letting Ebonhold
            -- provide real instance maps (e.g. mapID 691 for The Stockade).
            if type(ZoneDB.private.dungeons) == "table" and ZoneDB.private.dungeons[areaId] then
                ZoneDB.private.areaIdToUiMapId[areaId] = uiMapId
            end

            -- Register subzone to parent zone mapping so GetParentZoneId works with Ebonhold zones
            if uiMapId ~= areaId then
                ZoneDB.private.subZoneToParentZone[uiMapId] = areaId
            end
        end
    end

    -- Optional: allow Ebonhold to define custom dungeon zones/entrances without touching core tables.
    if type(EbonholdZoneTables.dungeons) == "table" then
        for areaId, data in pairs(EbonholdZoneTables.dungeons) do
            if areaId and data then
                ZoneDB.private.dungeons[areaId] = data
            end
        end
    end

    if type(EbonholdZoneTables.dungeonLocations) == "table" then
        for areaId, data in pairs(EbonholdZoneTables.dungeonLocations) do
            if areaId and data then
                ZoneDB.private.dungeonLocations[areaId] = data
            end
        end
    end

    if type(EbonholdZoneTables.dungeonParentZones) == "table" then
        for subZoneId, parentZoneId in pairs(EbonholdZoneTables.dungeonParentZones) do
            if subZoneId and parentZoneId then
                ZoneDB.private.dungeonParentZones[subZoneId] = parentZoneId
            end
        end
    end

    -- Also map parentMapIDs (e.g. 10138) to a usable uiMapId to avoid fallback errors.
    if EbonholdUiMapData and EbonholdUiMapData.uiMapData then
        for uiMapId, data in pairs(EbonholdUiMapData.uiMapData) do
            if uiMapId and ZoneDB.private.areaIdToUiMapId[uiMapId] == nil then
                ZoneDB.private.areaIdToUiMapId[uiMapId] = uiMapId
            end
            if data and type(data.parentMapID) == "number" and ZoneDB.private.areaIdToUiMapId[data.parentMapID] == nil then
                ZoneDB.private.areaIdToUiMapId[data.parentMapID] = uiMapId
            end
        end
    end

    -- Register zone sort names for custom zones
    if EbonholdZoneTables.zoneSort then
        ZoneDB.private.zoneSort = ZoneDB.private.zoneSort or {}
        for zoneId, zoneName in pairs(EbonholdZoneTables.zoneSort) do
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

-- Inject Ebonhold tables into QuestieDB *Overrides* so QueryQuestSingle/QueryNPCSingle can see them
function EbonholdLoader:InjectOverrides()
    if _overridesInjected then return end
    _overridesInjected = true

    -- Apply zone tables FIRST, before any ZoneDB functions use the local variables
    EbonholdLoader:ApplyZoneTables()

    QuestieDB.npcDataOverrides    = QuestieDB.npcDataOverrides or {}
    QuestieDB.objectDataOverrides = QuestieDB.objectDataOverrides or {}
    QuestieDB.itemDataOverrides   = QuestieDB.itemDataOverrides or {}
    QuestieDB.questDataOverrides  = QuestieDB.questDataOverrides or {}

    local npcData                 = _LoadIfString(EbonholdDB and EbonholdDB.npcData, "EbonholdDB.npcData")
    local objectData              = _LoadIfString(EbonholdDB and EbonholdDB.objectData, "EbonholdDB.objectData")
    local itemData                = _LoadIfString(EbonholdDB and EbonholdDB.itemData, "EbonholdDB.itemData")
    local questData               = _LoadIfString(EbonholdDB and EbonholdDB.questData, "EbonholdDB.questData")

    _MergeInto(QuestieDB.npcDataOverrides, npcData)
    _MergeInto(QuestieDB.objectDataOverrides, objectData)
    _MergeInto(QuestieDB.itemDataOverrides, itemData)
    _MergeInto(QuestieDB.questDataOverrides, questData)

    -- Keep a lightweight list of custom quest ids for search/UI (DO NOT touch QuestPointers; those are numeric stream pointers)
    if type(questData) == "table" then
        QuestieDB.ebonholdQuestIds = QuestieDB.ebonholdQuestIds or {}
        for questId, _ in pairs(questData) do
            if type(questId) == "number" then
                QuestieDB.ebonholdQuestIds[questId] = true
            end
        end
    end

    -- Keep a lightweight list of custom NPC ids for search/UI
    if type(npcData) == "table" then
        QuestieDB.ebonholdNpcIds = QuestieDB.ebonholdNpcIds or {}
        for npcId, _ in pairs(npcData) do
            if type(npcId) == "number" then
                QuestieDB.ebonholdNpcIds[npcId] = true
            end
        end
    end

    -- Keep a lightweight list of custom object ids for search/UI
    if type(objectData) == "table" then
        QuestieDB.ebonholdObjectIds = QuestieDB.ebonholdObjectIds or {}
        for objectId, _ in pairs(objectData) do
            if type(objectId) == "number" then
                QuestieDB.ebonholdObjectIds[objectId] = true
            end
        end
    end

    -- Keep a lightweight list of custom item ids for search/UI
    if type(itemData) == "table" then
        QuestieDB.ebonholdItemIds = QuestieDB.ebonholdItemIds or {}
        for itemId, _ in pairs(itemData) do
            if type(itemId) == "number" then
                QuestieDB.ebonholdItemIds[itemId] = true
            end
        end
    end
end

return EbonholdLoader
