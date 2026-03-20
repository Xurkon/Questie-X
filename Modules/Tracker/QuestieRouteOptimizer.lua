---@class QuestieRouteOptimizer
local QuestieRouteOptimizer = QuestieLoader:CreateModule("QuestieRouteOptimizer")

-------------------------
--Import modules.
-------------------------
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type QuestieMap
local QuestieMap = QuestieLoader:ImportModule("QuestieMap")
---@type QuestieTracker
local QuestieTracker = QuestieLoader:ImportModule("QuestieTracker")
---@type TrackerUtils
local TrackerUtils = QuestieLoader:ImportModule("TrackerUtils")
---@type QuestieCompat
local QuestieCompat = QuestieLoader:ImportModule("QuestieCompat")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
---@type QuestieFramePool
local QuestieFramePool = QuestieLoader:ImportModule("QuestieFramePool")

-------------------------
--Compat
-------------------------
local GetTime = GetTime
local pairs = pairs
local ipairs = ipairs
local tinsert = table.insert
local type = type

-------------------------
--Route optimization modes
-------------------------
local ROUTE_MODE_OFF = 1
local ROUTE_MODE_SINGLE_QUEST = 2
local ROUTE_MODE_ALL_TRACKED = 3
local ROUTE_MODE_TSP_APPROXIMATION = 4

-------------------------
--State
-------------------------
local routeFrames = {}
local currentRouteMode = ROUTE_MODE_OFF

--- Calculate distance between two points
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@return number distance
local function _GetDistance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

--- Nearest neighbor TSP approximation
---@param coordinates table<number, {x: number, y: number, data: any}>
---@return table<number, {x: number, y: number, data: any}>
local function _NearestNeighborTSP(coordinates)
    if #coordinates <= 1 then
        return coordinates
    end

    local visited = {}
    local route = {}
    local current = 1
    
    visited[current] = true
    tinsert(route, coordinates[current])
    
    for i = 2, #coordinates do
        local nearestDist = math.huge
        local nearestIdx = 0
        
        for j = 1, #coordinates do
            if not visited[j] then
                local dist = _GetDistance(
                    coordinates[current].x, coordinates[current].y,
                    coordinates[j].x, coordinates[j].y
                )
                if dist < nearestDist then
                    nearestDist = dist
                    nearestIdx = j
                end
            end
        end
        
        if nearestIdx > 0 then
            visited[nearestIdx] = true
            tinsert(route, coordinates[nearestIdx])
            current = nearestIdx
        end
    end
    
    return route
end

--- Get spawn coordinates for a single quest
---@param questId number
---@return table<number, {x: number, y: number, data: any}>?
local function _GetQuestSpawnCoordinates(questId)
    local quest = QuestieDB.GetQuest(questId)
    if not quest then return nil end
    
    local coordinates = {}
    
    ---@param spawnData table
    ---@param zoneId number
    local function AddSpawns(spawnData, zoneId)
        if spawnData and spawnData.Spawns then
            for _, spawn in pairs(spawnData.Spawns) do
                for _, coord in pairs(spawn) do
                    if coord[1] > 0 and coord[2] > 0 then
                        tinsert(coordinates, {
                            x = coord[1] / 100,
                            y = coord[2] / 100,
                            data = spawnData,
                            zone = zoneId
                        })
                    end
                end
            end
        end
    end
    
    if quest.Objectives then
        for _, objective in pairs(quest.Objectives) do
            if objective.Spawns then
                for zoneId, spawnData in pairs(objective.Spawns) do
                    AddSpawns(spawnData, zoneId)
                end
            end
            if objective.KillCredit and objective.KillCredit > 0 then
                local spawns = QuestieDB.QueryNPCSingle(objective.KillCredit, "spawns")
                if spawns then
                    for _, spawn in pairs(spawns) do
                        for _, coord in pairs(spawn) do
                            if coord[1] > 0 and coord[2] > 0 then
                                tinsert(coordinates, {
                                    x = coord[1] / 100,
                                    y = coord[2] / 100,
                                    data = { Id = objective.KillCredit, Name = "Kill Credit" },
                                    zone = zoneId
                                })
                            end
                        end
                    end
                end
            end
        end
    end
    
    if quest.Finishers then
        for _, finisher in pairs(quest.Finishers) do
            if finisher.Spawns then
                for zoneId, spawnData in pairs(finisher.Spawns) do
                    AddSpawns(spawnData, zoneId)
                end
            end
        end
    end
    
    return coordinates
end

--- Get spawn coordinates for all tracked quests
---@return table<number, {x: number, y: number, data: any}>?
local function _GetAllTrackedQuestsCoordinates()
    local coordinates = {}
    local trackedQuests = Questie.db.char.TrackedQuests
    
    if not trackedQuests then return nil end
    
    for questId in pairs(trackedQuests) do
        local questCoords = _GetQuestSpawnCoordinates(questId)
        if questCoords then
            for _, coord in pairs(questCoords) do
                tinsert(coordinates, coord)
            end
        end
    end
    
    return coordinates
end

--- Clear all route frames
function QuestieRouteOptimizer:ClearRoutes()
    for _, frame in pairs(routeFrames) do
        if frame and frame:Hide then
            frame:Hide()
        end
    end
    routeFrames = {}
end

--- Draw an optimized route for a single quest
---@param questId number
function QuestieRouteOptimizer:DrawQuestRoute(questId)
    self:ClearRoutes()
    
    local coordinates = _GetQuestSpawnCoordinates(questId)
    if not coordinates or #coordinates < 2 then
        return
    end
    
    local optimized = _NearestNeighborTSP(coordinates)
    
    local lastZone = nil
    local zoneRoute = {}
    
    for i, coord in ipairs(optimized) do
        if coord.zone == lastZone or not lastZone then
            tinsert(zoneRoute, {coord.x, coord.y})
            lastZone = coord.zone
        else
            self:_DrawZoneRoute(zoneRoute, lastZone)
            zoneRoute = {{coord.x, coord.y}}
            lastZone = coord.zone
        end
    end
    
    if #zoneRoute > 0 and lastZone then
        self:_DrawZoneRoute(zoneRoute, lastZone)
    end
end

--- Draw route for all tracked quests
function QuestieRouteOptimizer:DrawAllTrackedRoutes()
    self:ClearRoutes()
    
    local coordinates = _GetAllTrackedQuestsCoordinates()
    if not coordinates or #coordinates < 2 then
        return
    end
    
    local optimized = _NearestNeighborTSP(coordinates)
    
    local lastZone = nil
    local zoneRoute = {}
    
    for i, coord in ipairs(optimized) do
        if coord.zone == lastZone or not lastZone then
            tinsert(zoneRoute, {coord.x, coord.y})
            lastZone = coord.zone
        else
            self:_DrawZoneRoute(zoneRoute, lastZone)
            zoneRoute = {{coord.x, coord.y}}
            lastZone = coord.zone
        end
    end
    
    if #zoneRoute > 0 and lastZone then
        self:_DrawZoneRoute(zoneRoute, lastZone)
    end
end

--- Draw a TSP approximation route connecting all objectives
function QuestieRouteOptimizer:DrawTSPRoute()
    self:ClearRoutes()
    
    local coordinates = {}
    
    for questId in pairs(Questie.db.char.TrackedQuests or {}) do
        local questCoords = _GetQuestSpawnCoordinates(questId)
        if questCoords then
            for _, coord in pairs(questCoords) do
                tinsert(coordinates, coord)
            end
        end
    end
    
    if #coordinates < 2 then
        return
    end
    
    local optimized = _NearestNeighborTSP(coordinates)
    
    local lastZone = nil
    local zoneRoute = {}
    
    for i, coord in ipairs(optimized) do
        if coord.zone == lastZone or not lastZone then
            tinsert(zoneRoute, {coord.x, coord.y})
            lastZone = coord.zone
        else
            self:_DrawZoneRoute(zoneRoute, lastZone)
            zoneRoute = {{coord.x, coord.y}}
            lastZone = coord.zone
        end
    end
    
    if #zoneRoute > 0 and lastZone then
        self:_DrawZoneRoute(zoneRoute, lastZone)
    end
end

---@param waypoints table
---@param zoneId number
function QuestieRouteOptimizer:_DrawZoneRoute(waypoints, zoneId)
    if #waypoints < 2 then return end
    
    local uiMapId = ZoneDB:GetUiMapIdByAreaId(zoneId)
    if not uiMapId then return end
    
    local routeData = {
        Title = "Quest Route",
        IconScale = 1.0,
        Type = "route",
        UiMapID = uiMapId,
        x = waypoints[1][1],
        y = waypoints[1][2],
    }
    
    local icon = QuestieMap:DrawWorldIcon(routeData, zoneId, waypoints[1][1], waypoints[1][2])
    
    local lineFrames = QuestieFramePool:CreateWaypoints(icon, waypoints, nil, {0.2, 0.8, 1, 0.7}, zoneId)
    tinsert(routeFrames, icon)
    
    for _, lineFrame in ipairs(lineFrames) do
        tinsert(routeFrames, lineFrame)
    end
end

--- Update route display based on current mode
function QuestieRouteOptimizer:Update()
    local mode = Questie.db.profile.routeMode or ROUTE_MODE_OFF
    
    if mode == ROUTE_MODE_OFF then
        self:ClearRoutes()
    elseif mode == ROUTE_MODE_SINGLE_QUEST then
        local questId = QuestieTracker:GetSelectedQuest()
        if questId then
            self:DrawQuestRoute(questId)
        else
            self:ClearRoutes()
        end
    elseif mode == ROUTE_MODE_ALL_TRACKED then
        self:DrawAllTrackedRoutes()
    elseif mode == ROUTE_MODE_TSP_APPROXIMATION then
        self:DrawTSPRoute()
    end
end

--- Get route mode from settings
function QuestieRouteOptimizer:GetMode()
    return Questie.db.profile.routeMode or ROUTE_MODE_OFF
end

--- Set route mode
---@param mode number
function QuestieRouteOptimizer:SetMode(mode)
    Questie.db.profile.routeMode = mode
    self:Update()
end

return QuestieRouteOptimizer
