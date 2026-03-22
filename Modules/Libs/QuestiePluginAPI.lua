---@class QuestiePluginAPI
local QuestiePluginAPI = QuestieLoader:CreateModule("QuestiePluginAPI")

QuestiePluginAPI.registeredPlugins = {}
QuestiePluginAPI.loadedDBFlavor    = nil   -- set by the first DB plugin that calls FinishLoading

--- Returns true if at least one DB plugin has fully loaded.
---@return boolean
function QuestiePluginAPI:IsAnyPluginLoaded()
    for _ in pairs(self.registeredPlugins) do return true end
    return false
end

--- Returns the flavor key of the loaded DB plugin ("WotLK", "Classic", "TBC", "Turtle", "Ascension", etc.)
---@return string|nil
function QuestiePluginAPI:GetLoadedFlavor()
    return self.loadedDBFlavor
end

---@class QuestiePlugin
local QuestiePlugin = {}
QuestiePlugin.__index = QuestiePlugin

--- Registers a new Questie plugin
---@param pluginName string The unique name of the plugin
---@return table|nil plugin The initialized plugin object, or nil if already registered
function QuestiePluginAPI:RegisterPlugin(pluginName)
    if not pluginName or type(pluginName) ~= "string" then
        Questie:Debug(Questie.DEBUG_CRITICAL, "[QuestiePluginAPI] RegisterPlugin called with invalid name: " .. tostring(pluginName))
        return nil
    end

    if self.registeredPlugins[pluginName] then
        Questie:Debug(Questie.DEBUG_CRITICAL, "[QuestiePluginAPI] Plugin '" .. pluginName .. "' is already registered — duplicate RegisterPlugin call ignored.")
        return nil
    end

    local plugin = setmetatable({
        name = pluginName,
        stats = {
            QUEST = 0,
            NPC = 0,
            OBJECT = 0,
            ITEM = 0
        }
    }, QuestiePlugin)

    self.registeredPlugins[pluginName] = plugin
    Questie:Debug(Questie.DEBUG_INFO, "[QuestiePluginAPI] Successfully registered plugin: " .. pluginName)

    if pluginName == "WotLKDB" and Questie.wotlkStatsCache then
        Questie:Debug(Questie.DEBUG_INFO, "[QuestiePluginAPI] Applying cached WotLK stats...")
        plugin.stats.QUEST  = Questie.wotlkStatsCache.QUEST  or 0
        plugin.stats.NPC    = Questie.wotlkStatsCache.NPC    or 0
        plugin.stats.OBJECT = Questie.wotlkStatsCache.OBJECT or 0
        plugin.stats.ITEM   = Questie.wotlkStatsCache.ITEM   or 0
    end

    return plugin
end

--- Retrieves a registered plugin
---@param pluginName string
---@return table|nil
function QuestiePluginAPI:GetPlugin(pluginName)
    return self.registeredPlugins[pluginName]
end

---------------------------------------------------------------------------------------------------
-- Plugin Object Methods
---------------------------------------------------------------------------------------------------

--- Safely injects data into the core QuestieDB overrides tables
---@param dbType string "QUEST", "NPC", "OBJECT", or "ITEM"
---@param data table The database to inject
function QuestiePlugin:InjectDatabase(dbType, data)
    if type(data) ~= "table" then return end

    local QuestieDB = QuestieLoader:ImportModule("QuestieDB")

    -- Ensure overrides tables exist
    QuestieDB.npcDataOverrides = QuestieDB.npcDataOverrides or {}
    QuestieDB.objectDataOverrides = QuestieDB.objectDataOverrides or {}
    QuestieDB.itemDataOverrides = QuestieDB.itemDataOverrides or {}
    QuestieDB.questDataOverrides = QuestieDB.questDataOverrides or {}

    local count = 0
    if dbType == "QUEST" then
        for id, entry in pairs(data) do
            QuestieDB.questDataOverrides[id] = entry
            if type(id) == "number" then count = count + 1 end
        end
    elseif dbType == "NPC" then
        for id, entry in pairs(data) do
            QuestieDB.npcDataOverrides[id] = entry
            if type(id) == "number" then count = count + 1 end
        end
    elseif dbType == "OBJECT" then
        for id, entry in pairs(data) do
            QuestieDB.objectDataOverrides[id] = entry
            if type(id) == "number" then count = count + 1 end
        end
    elseif dbType == "ITEM" then
        for id, entry in pairs(data) do
            QuestieDB.itemDataOverrides[id] = entry
            if type(id) == "number" then count = count + 1 end
        end
    else
        Questie:Debug(Questie.DEBUG_CRITICAL, "[QuestiePluginAPI] Plugin '" .. self.name .. "' passed unknown DB type to InjectDatabase: '" .. tostring(dbType) .. "'. Expected QUEST, NPC, OBJECT, or ITEM.")
        return
    end

    self.stats[dbType] = self.stats[dbType] + count
    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestiePluginAPI] Plugin '" .. self.name .. "' injected " .. tostring(count) .. " " .. dbType .. " records.")
end

--- Safely injects zone, dungeon, and map routing data into ZoneDB
function QuestiePlugin:InjectZoneTables(customZoneTables)
    if type(customZoneTables) ~= "table" then return end

    local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
    if not ZoneDB then return end

    ZoneDB.private = ZoneDB.private or {}
    ZoneDB.private.uiMapIdToAreaId = ZoneDB.private.uiMapIdToAreaId or {}
    ZoneDB.private.areaIdToUiMapId = ZoneDB.private.areaIdToUiMapId or {}
    ZoneDB.private.subZoneToParentZone = ZoneDB.private.subZoneToParentZone or {}
    ZoneDB.private.dungeons = ZoneDB.private.dungeons or {}
    ZoneDB.private.dungeonLocations = ZoneDB.private.dungeonLocations or {}
    ZoneDB.private.dungeonParentZones = ZoneDB.private.dungeonParentZones or {}

    if customZoneTables.uiMapIdToAreaId then
        for uiMapId, areaId in pairs(customZoneTables.uiMapIdToAreaId) do
            if uiMapId and areaId then
                ZoneDB.private.uiMapIdToAreaId[uiMapId] = areaId
                ZoneDB.private.areaIdToUiMapId[uiMapId] = uiMapId

                if type(ZoneDB.private.dungeons) == "table" and ZoneDB.private.dungeons[areaId] then
                    ZoneDB.private.areaIdToUiMapId[areaId] = uiMapId
                end

                if uiMapId ~= areaId then
                    ZoneDB.private.subZoneToParentZone[uiMapId] = areaId
                end
            end
        end
    end

    if type(customZoneTables.dungeons) == "table" then
        for areaId, data in pairs(customZoneTables.dungeons) do
            if areaId and data then
                ZoneDB.private.dungeons[areaId] = data
            end
        end
    end

    if type(customZoneTables.dungeonLocations) == "table" then
        for areaId, data in pairs(customZoneTables.dungeonLocations) do
            if areaId and data then
                ZoneDB.private.dungeonLocations[areaId] = data
            end
        end
    end

    if type(customZoneTables.dungeonParentZones) == "table" then
        for subZoneId, parentZoneId in pairs(customZoneTables.dungeonParentZones) do
            if subZoneId and parentZoneId then
                ZoneDB.private.dungeonParentZones[subZoneId] = parentZoneId
            end
        end
    end

    if customZoneTables.zoneSort then
        ZoneDB.private.zoneSort = ZoneDB.private.zoneSort or {}
        for zoneId, zoneName in pairs(customZoneTables.zoneSort) do
            ZoneDB.private.zoneSort[zoneId] = zoneName
        end
    end

    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestiePluginAPI] Plugin '" .. self.name .. "' injected Custom Zone Tables.")
end

--- Safely injects fallback UiMapData for boundary maps
function QuestiePlugin:InjectUiMapData(customUiMapData)
    if type(customUiMapData) ~= "table" or not customUiMapData.uiMapData then return end

    local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
    if not ZoneDB then return end
    
    ZoneDB.private = ZoneDB.private or {}
    ZoneDB.private.areaIdToUiMapId = ZoneDB.private.areaIdToUiMapId or {}

    for uiMapId, data in pairs(customUiMapData.uiMapData) do
        if uiMapId and ZoneDB.private.areaIdToUiMapId[uiMapId] == nil then
            ZoneDB.private.areaIdToUiMapId[uiMapId] = uiMapId
        end
        if data and type(data.parentMapID) == "number" and ZoneDB.private.areaIdToUiMapId[data.parentMapID] == nil then
            ZoneDB.private.areaIdToUiMapId[data.parentMapID] = uiMapId
        end
    end

    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestiePluginAPI] Plugin '" .. self.name .. "' injected Custom UI Map Data.")
end

--- Signals that the plugin has finished loading. This automatically cleans up necessary caches.
---@param flavorKey string|nil  Optional flavor label e.g. "WotLK", "Classic", "Turtle"
function QuestiePlugin:FinishLoading(flavorKey)
    local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
    if not QuestieDB then
        Questie:Debug(Questie.DEBUG_CRITICAL, "[QuestiePluginAPI] Plugin '" .. self.name .. "' FinishLoading failed: QuestieDB module not found.")
        return
    end

    if QuestieDB.private and QuestieDB.private.zoneCache then
        QuestieDB.private.zoneCache = {}
    end

    if QuestieDB.autoBlacklist then
        QuestieDB.autoBlacklist = {}
    end

    if flavorKey then
        QuestiePluginAPI.loadedDBFlavor = flavorKey
    elseif not QuestiePluginAPI.loadedDBFlavor then
        QuestiePluginAPI.loadedDBFlavor = self.name
    end

    Questie:Debug(Questie.DEBUG_INFO, "[QuestiePluginAPI] Plugin '" .. self.name .. "' finished loading successfully.")
end

--- Injects XP-per-level data used by QuestieXP. The table must be keyed by level number.
---@param xpTable table  { [level] = xp_required, ... }
function QuestiePlugin:InjectXpData(xpTable)
    if type(xpTable) ~= "table" then return end
    local QuestXP = QuestieLoader:ImportModule("QuestieXP")
    if not QuestXP then
        Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestiePluginAPI] Plugin '" .. self.name .. "': InjectXpData — QuestieXP module not loaded, skipping.")
        return
    end
    QuestXP.db = xpTable
    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestiePluginAPI] Plugin '" .. self.name .. "' injected XP data (" .. tostring(#xpTable) .. " levels).")
end

--- Applies expansion-specific correction tables that are stored in QuestieDB
--- correction globals (set by correction files loaded by the plugin TOC).
--- Call this AFTER InjectDatabase calls and BEFORE FinishLoading.
function QuestiePlugin:InjectCorrections()
    local QuestieCorrections = QuestieLoader:ImportModule("QuestieCorrections")
    if not QuestieCorrections then
        Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestiePluginAPI] Plugin '" .. self.name .. "': InjectCorrections — QuestieCorrections module not loaded, skipping.")
        return
    end
    if QuestieCorrections.ApplyAll then
        QuestieCorrections:ApplyAll()
    end
    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestiePluginAPI] Plugin '" .. self.name .. "' applied corrections.")
end
