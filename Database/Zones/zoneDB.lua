---@class ZoneDB
local ZoneDB = QuestieLoader:CreateModule("ZoneDB")
---@type ZoneDBPrivate
ZoneDB.private = ZoneDB.private or {}

local _ZoneDB = ZoneDB.private

-------------------------
--Import modules.
-------------------------
---@type QuestiePlayer
local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type QuestieCorrections
local QuestieCorrections = QuestieLoader:ImportModule("QuestieCorrections")
---@type QuestieEvent
local QuestieEvent = QuestieLoader:ImportModule("QuestieEvent")
---@type QuestieProfessions
local QuestieProfessions = QuestieLoader:ImportModule("QuestieProfessions")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

--- COMPATIBILITY ---
local C_Map = QuestieCompat.C_Map

ZoneDB.private.areaIdToUiMapId = ZoneDB.private.areaIdToUiMapId or {}
ZoneDB.private.uiMapIdToAreaId = ZoneDB.private.uiMapIdToAreaId or {}
ZoneDB.private.dungeons = ZoneDB.private.dungeons or {}
ZoneDB.private.dungeonLocations = ZoneDB.private.dungeonLocations or {}
ZoneDB.private.dungeonParentZones = ZoneDB.private.dungeonParentZones or {}
ZoneDB.private.subZoneToParentZone = ZoneDB.private.subZoneToParentZone or {}
-- O(1) reverse lookup: uiMapId -> areaId, built from uiMapIdToAreaId at init.
ZoneDB.private.uiMapIdToAreaIdCache = ZoneDB.private.uiMapIdToAreaIdCache or {}

local areaIdToUiMapId = ZoneDB.private.areaIdToUiMapId
local uiMapIdToAreaId = ZoneDB.private.uiMapIdToAreaId
local uiMapIdToAreaIdCache = ZoneDB.private.uiMapIdToAreaIdCache
local dungeons = ZoneDB.private.dungeons
local dungeonLocations = ZoneDB.private.dungeonLocations
local dungeonParentZones = ZoneDB.private.dungeonParentZones
local subZoneToParentZone = ZoneDB.private.subZoneToParentZone
---Zone ids enum
ZoneDB.zoneIDs = ZoneDB.private.zoneIDs or {}


-- Overrides for UiMapId to AreaId
-- IMPORTANT: Only override specific real maps, NOT cosmic/world maps (946, 947, etc.)
-- that span multiple zones. Overriding 946/947 to a single zone breaks all other zones.
local UiMapIdOverrides = {
    [246] = 3713,
    [1415] = 668, -- Eastern Kingdoms (matches Undercity on Ascension)
    -- [1241] intentionally NOT overridden: areaId 3430 = Eversong Woods (the whole zone),
    -- and should map to uiMapId 1941 (Eversong map) for proper coordinate rendering.
    -- Zone 1241 pins render on map 1241 only (separate coordinate space from Eversong).
    [1238] = 668,  -- Northshire Valley child map (Conquest of Azeroth)
    -- [946] = 668 removed: both Sunstrider Isle AND Northshire Valley use 946 as ghost/zone map,
    -- so 946 cannot be overridden to a single zone. Instead, uiMapIdToAreaIdCache handles both.
}

-- Sunstrider Isle overrides (separate from Northshire since they're different Ascension realms)
ZoneDB.private.uiMapIdToAreaId = ZoneDB.private.uiMapIdToAreaId or {}
ZoneDB.private.uiMapIdToAreaId[1241] = 3430
-- 946 is a ghost/transition map. On Horde (Sunstrider), it resolves to areaId 3430.
-- On Alliance (Northshire), it resolves to areaId 12 (Elwynn). The AscensionDB
-- zone table handles both via runtime loading; we set the default here for
-- the Sunstrider case since that's where pins break without it.
ZoneDB.private.uiMapIdToAreaId[946] = 3430
-- Reverse mapping: areaId → uiMapId for GetUiMapIdByAreaId lookups.
-- Northshire Valley (areaId 668) uses uiMapId 1238.
ZoneDB.private.areaIdToUiMapId[668] = 1238
areaIdToUiMapId[668] = 1238
-- Eversong Woods (areaId 3430) maps to the Eversong Woods map (uiMapId 1941).
-- Sunstrider Isle (areaId 3431) is a subzone of Eversong Woods — same map (1941).
-- Sunstrider Isle (uiMapId 1241) is a child map of Eversong Woods.
-- Pins for zones 3430 and 3431 render on map 1941 (Eversong).
-- Pins for zone 1241 render on map 1241 (Sunstrider) using Ascension-calibrated bounds.
ZoneDB.private.areaIdToUiMapId[3430] = 1941
areaIdToUiMapId[3430] = 1941
-- Sunstrider Isle (3431) uses its own map (1241) with calibrated bounds.
-- Pins for Sunstrider NPCs (zone 1241 coords) must appear on map 1241, not 1941.
-- Future agents: Sunstrider Isle uses areaId 3431 and uiMapId 1241; convert
-- Eversong-derived source spawns into 1241 map space before injecting pins.
ZoneDB.private.areaIdToUiMapId[3431] = 1241
areaIdToUiMapId[3431] = 1241
-- Allow drawing pins directly on Sunstrider Isle (uiMapId 1241) via areaId 1241.
ZoneDB.private.areaIdToUiMapId[1241] = 1241
areaIdToUiMapId[1241] = 1241
-- Also populate the cache so the fast path works without a lazy lookup.
if uiMapIdToAreaIdCache[1238] == nil then
    uiMapIdToAreaIdCache[1238] = 668
end
-- Sunstrider Isle uiMapId 1241 → areaId 3431 (subzone, not parent 3430).
-- Questie resolves 3431→3430 via GetParentZoneId() automatically when needed.
if uiMapIdToAreaIdCache[1241] == nil then
    uiMapIdToAreaIdCache[1241] = 3431
end
if uiMapIdToAreaIdCache[946] == nil then
    uiMapIdToAreaIdCache[946] = 3430
end
local parentZoneToSubZone = {} -- Generated
local zoneMap = {}             -- Generated


function ZoneDB:Initialize()
    if QuestieCompat and QuestieCompat.LoadUiMapData then
        hooksecurefunc(QuestieCompat, "LoadUiMapData", function()
            ZoneDB:ApplyCustomZones()
        end)
    end

    ZoneDB:ApplyCustomZones()
    _ZoneDB:BuildUiMapIdToAreaIdCache()
    _ZoneDB:GenerateParentZoneToStartingZoneTable()

    -- Run tests if debug enabled
    if Questie.db.profile.debugEnabled then
        _ZoneDB:RunTests()
    end
end

function ZoneDB:ApplyCustomZones()
    if not QuestieCompat or not QuestieCompat.UiMapData then return end

    for uiMapId, data in pairs(QuestieCompat.UiMapData) do
        if not uiMapId or type(uiMapId) ~= "number" then
            -- skip non-numeric keys
        elseif _ZoneDB.areaIdToUiMapId[uiMapId] == nil then
            _ZoneDB.areaIdToUiMapId[uiMapId] = uiMapId
            -- Keep reverse cache in sync
            if uiMapIdToAreaIdCache[uiMapId] == nil then
                uiMapIdToAreaIdCache[uiMapId] = uiMapId
            end
        end

        if data and type(data.parentMapID) == "number" and _ZoneDB.areaIdToUiMapId[data.parentMapID] == nil then
            _ZoneDB.areaIdToUiMapId[data.parentMapID] = uiMapId
        end
    end
end

-- Builds the O(1) uiMapId -> areaId reverse cache from the uiMapIdToAreaId table.
-- Called once at Initialize() after all zone data is loaded.
function _ZoneDB:BuildUiMapIdToAreaIdCache()
    for areaUiMapId, areaId in next, uiMapIdToAreaId do
        -- First entry wins (matches the original scan behaviour)
        if uiMapIdToAreaIdCache[areaUiMapId] == nil then
            uiMapIdToAreaIdCache[areaUiMapId] = areaId
        end
    end
end

function _ZoneDB:GenerateParentZoneToStartingZoneTable()
    for startingZone, parentZone in next, subZoneToParentZone do
        parentZoneToSubZone[parentZone] = startingZone
    end
end

function ZoneDB:GetDungeons()
    return dungeons
end

---@param areaId AreaId
---@return UiMapId
function ZoneDB:GetUiMapIdByAreaId(areaId)
    local uiMapId = areaIdToUiMapId[areaId]
    if uiMapId then
        return uiMapId
    end
    if areaId and areaId > 0 then
        local mapInfo = C_Map.GetMapInfo(areaId)
        if mapInfo and mapInfo.mapID then
            return mapInfo.mapID
        end
        return areaId
    end
    return nil
end

---@param uiMapId UiMapId
---@return AreaId
function ZoneDB:GetAreaIdByUiMapId(uiMapId)
    -- Fast path: override table
    if UiMapIdOverrides[uiMapId] then
        return UiMapIdOverrides[uiMapId]
    end

    -- Fast path: O(1) pre-built reverse cache
    local cached = uiMapIdToAreaIdCache[uiMapId]
    if cached ~= nil then
        return cached ~= false and cached or nil
    end

    -- Slow fallback: name-based lookup (only for unmapped IDs, result is cached for next time)
    local mapInfo = C_Map.GetMapInfo(uiMapId)
    if mapInfo then
        for areaId in next, areaIdToUiMapId do
            local areaName = C_Map.GetAreaInfo(areaId)
            if mapInfo.name == areaName then
                Questie:Debug(Questie.DEBUG_DEVELOP, "[ZoneDB:GetAreaIdByUiMapId] : ", "Found AreaId", areaName, ":", areaId, "for UiMapId", mapInfo.name, ":", uiMapId, "by name")
                -- Cache the result so we don't scan again
                uiMapIdToAreaIdCache[uiMapId] = areaId
                return areaId
            end
        end
    end

    if Questie.db.profile.debugEnabled then
        Questie:Debug(Questie.DEBUG_DEVELOP, "No AreaId found for UiMapId: " .. uiMapId .. ":" .. (mapInfo and mapInfo.name or "nil"))
    end

    -- We must cache that we found nothing so we don't run the slow lookup again
    uiMapIdToAreaIdCache[uiMapId] = false
    return nil
end

---@param areaId AreaId
function ZoneDB:GetDungeonLocation(areaId)
    return dungeonLocations[areaId]
end

---@param areaId AreaId
function ZoneDB.IsDungeonZone(areaId)
    return dungeonLocations[areaId] ~= nil
end

---@param areaId AreaId
function ZoneDB:GetAlternativeZoneId(areaId)
    local entry = dungeons[areaId]
    if entry then
        return entry[2]
    end

    entry = parentZoneToSubZone[areaId]
    if entry then
        return entry
    end

    return nil
end

---@param areaId AreaId
function ZoneDB:GetParentZoneId(areaId)
    return dungeonParentZones[areaId] or subZoneToParentZone[areaId]
end

-- We keep localized variables outside of the function only used by GetZonesWithQuests
do
    -- This is for yielding
    local yieldAmount = 200
    local extraYield = yieldAmount / 4

    --Keep yield here as there is potentially a case where this wants to be run outside of a coroutine

    ---@param yield boolean?
    ---@return table
    function ZoneDB:GetZonesWithQuests(yield)
        local count = 0

        local function ProcessQuestId(questId)
            local _QuestiePlayer = QuestiePlayer or QuestieLoader:ImportModule("QuestiePlayer")
            if (not QuestieCorrections.hiddenQuests[questId]) then
                if _QuestiePlayer.HasRequiredRace(QuestieDB.QueryQuestSingle(questId, "requiredRaces"))
                    and _QuestiePlayer.HasRequiredClass(QuestieDB.QueryQuestSingle(questId, "requiredClasses")) then
                    local zoneOrSort = QuestieDB.QueryQuestSingle(questId, "zoneOrSort")
                    local requiredSkill = QuestieDB.QueryQuestSingle(questId, "requiredSkill")

                    if type(requiredSkill) == "table"
                        and requiredSkill[1]
                        and requiredSkill[1] ~= QuestieProfessions.professionKeys.RIDING then
                        local sortId = QuestieProfessions:GetSortIdByProfessionId(requiredSkill[1])
                        zoneOrSort = sortId or QuestieDB.sortKeys.SPECIAL

                        if (not zoneMap[zoneOrSort]) then zoneMap[zoneOrSort] = {} end
                        zoneMap[zoneOrSort][questId] = true
                    elseif type(zoneOrSort) == "number" and zoneOrSort > 0 then
                        local parentZoneId = ZoneDB:GetParentZoneId(zoneOrSort)

                        if parentZoneId then
                            if (not zoneMap[parentZoneId]) then zoneMap[parentZoneId] = {} end
                            zoneMap[parentZoneId][questId] = true
                        else
                            if (not zoneMap[zoneOrSort]) then zoneMap[zoneOrSort] = {} end
                            zoneMap[zoneOrSort][questId] = true
                        end
                    elseif type(zoneOrSort) == "number" and _ZoneDB:IsSpecialQuest(zoneOrSort) then
                        if (not zoneMap[zoneOrSort]) then zoneMap[zoneOrSort] = {} end
                        zoneMap[zoneOrSort][questId] = true
                    else
                        local startedBy = QuestieDB.QueryQuestSingle(questId, "startedBy")
                        if startedBy then
                            zoneMap = _ZoneDB:GetZonesWithQuestsFromNPCs(zoneMap, startedBy[1], questId)
                            zoneMap = _ZoneDB:GetZonesWithQuestsFromObjects(zoneMap, startedBy[2], questId)
                        end

                        local finishedBy = QuestieDB.QueryQuestSingle(questId, "finishedBy")
                        if finishedBy then
                            zoneMap = _ZoneDB:GetZonesWithQuestsFromNPCs(zoneMap, finishedBy[1], questId)
                            zoneMap = _ZoneDB:GetZonesWithQuestsFromObjects(zoneMap, finishedBy[2], questId)
                        end
                    end
                end
            end

            if yield then
                count = count + 1
                if count >= yieldAmount then
                    count = 0
                    coroutine.yield()
                end
            end
        end

        -- 1) Base Questie quests (QuestPointers values must be numbers; ignore anything weird)
        if type(QuestieDB.QuestPointers) == "table" then
            for questId, ptr in next, QuestieDB.QuestPointers do
                if type(ptr) == "number" then
                    ProcessQuestId(questId)
                end
            end
        end

        -- 2) Ascension custom quests (from overrides list)
        if type(QuestieDB.ascensionQuestIds) == "table" then
            for questId in next, QuestieDB.ascensionQuestIds do
                ProcessQuestId(questId)
            end
        end

        if yield then coroutine.yield() end
        zoneMap = _ZoneDB:SplitSeasonalQuests()
        return zoneMap
    end
end


---@param zoneOrSort ZoneOrSort
function _ZoneDB:IsSpecialQuest(zoneOrSort)
    for _, v in next, QuestieDB.sortKeys do
        if zoneOrSort == v then
            return true
        end
    end
    return false
end

---@param zones table
---@param npcIds table|nil
---@param questId number
---@return table
function _ZoneDB:GetZonesWithQuestsFromNPCs(zones, npcIds, questId)
    if (not npcIds) then
        return zones
    end

    for npcId in next, npcIds do
        local spawns = QuestieDB.QueryNPCSingle(npcId, "spawns")
        if spawns then
            for zone in next, spawns do
                if (not zones[zone]) then zones[zone] = {} end
                zones[zone][questId] = true
            end
        end
    end

    return zones
end

---@param zones table
---@param objectIds table|nil
---@param questId number
---@return table
function _ZoneDB:GetZonesWithQuestsFromObjects(zones, objectIds, questId)
    if (not objectIds) then
        return zones
    end

    for objectId in next, objectIds do
        local spawns = QuestieDB.QueryObjectSingle(objectId, "spawns")
        if spawns then
            for zone in next, spawns do
                if (not zones[zone]) then zones[zone] = {} end
                zones[zone][questId] = true
            end
        end
    end

    return zones
end

---@return table
function _ZoneDB:SplitSeasonalQuests()
    if (not zoneMap[QuestieDB.sortKeys.SPECIAL]) or (not zoneMap[QuestieDB.sortKeys.SEASONAL]) then
        return zoneMap
    end
    local questsToSplit = zoneMap[QuestieDB.sortKeys.SEASONAL]
    -- Merging SEASONAL and SPECIAL quests to be split into real groups
    for k, v in next, zoneMap[QuestieDB.sortKeys.SPECIAL] do questsToSplit[k] = v end

    local updatedZoneMap = zoneMap
    updatedZoneMap[-400] = {}
    updatedZoneMap[-401] = {}
    updatedZoneMap[-402] = {}
    updatedZoneMap[-403] = {}
    updatedZoneMap[-404] = {}

    for questId, _ in next, questsToSplit do
        local eventName = QuestieEvent:GetEventNameFor(questId)
        if eventName == "Love is in the Air" then
            updatedZoneMap[-400][questId] = true
        elseif eventName == "Children's Week" then
            updatedZoneMap[-401][questId] = true
        elseif eventName == "Harvest Festival" then
            updatedZoneMap[-402][questId] = true
        elseif eventName == "Hallow's End" then
            updatedZoneMap[-403][questId] = true
        elseif eventName == "Winter Veil" then
            updatedZoneMap[-404][questId] = true
        end
    end

    updatedZoneMap[QuestieDB.sortKeys.SEASONAL] = nil
    updatedZoneMap[QuestieDB.sortKeys.SPECIAL] = nil
    return updatedZoneMap
end

function ZoneDB:GetRelevantZones()
    local zones = {}
    if type(l10n.zoneCategoryLookup) == "table" then
        for category, data in next, l10n.zoneCategoryLookup do
            zones[category] = {}
            for id, zoneName in next, data do
                local zoneQuests = zoneMap[id]
                if (not zoneQuests) then
                    zones[category][id] = nil
                else
                    zones[category][id] = l10n(zoneName)
                end
            end
        end
    end

    return zones
end

----- Tests -----

function _ZoneDB:RunTests()
    -- Fetch all UiMapIds (WOTLK/TBC, ERA)
    local maps = C_Map.GetMapChildrenInfo(946, nil, true) or C_Map.GetMapChildrenInfo(947, nil, true)
    Questie:Debug(Questie.DEBUG_CRITICAL, "[" .. Questie:Colorize("ZoneDBTests", "yellow") .. "] Testing ZoneDB")
    local buggedMaps = {
        [306] = true, -- ScholomanceOLD
        [307] = true, -- ScholomanceOLD
        [308] = true, -- ScholomanceOLD
        [309] = true, -- ScholomanceOLD
    }
    if type(maps) == "table" then
        for _, map in next, maps do
            --- We don't care about World, Continent or Cosmic
            if map.mapType ~= Enum.UIMapType.World and map.mapType ~= Enum.UIMapType.Continent and map.mapType ~= Enum.UIMapType.Cosmic then
                local success, result = pcall(ZoneDB.GetAreaIdByUiMapId, ZoneDB, map.mapID)
                if not success and not buggedMaps[map.mapID] then
                    Questie:Error("[ZoneDBTests] ZoneDB.GetAreaIdByUiMapId fails for " .. map.name .. " (" .. map.mapID .. "). Result: " .. result)
                end
            end
        end
    end
    Questie:Debug(Questie.DEBUG_CRITICAL, "[" .. Questie:Colorize("ZoneDBTests", "yellow") .. "] Testing ZoneDB done")
end

do
    local originalZoneInitialize = ZoneDB.Initialize
    if type(originalZoneInitialize) == "function" then
        function ZoneDB:Initialize(...)
            ZoneDB:ApplyCustomZones()
            return originalZoneInitialize(self, ...)
        end
    end
end

return ZoneDB
