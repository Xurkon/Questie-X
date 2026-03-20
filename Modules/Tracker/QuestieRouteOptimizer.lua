---@class QuestieRouteOptimizer
local QuestieRouteOptimizer = QuestieLoader:CreateModule("QuestieRouteOptimizer")

-------------------------
--Import modules.
-------------------------
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type QuestieMap
local QuestieMap = QuestieLoader:ImportModule("QuestieMap")
---@type QuestieCompat
local QuestieCompat = QuestieLoader:ImportModule("QuestieCompat")
---@type QuestieFramePool
local QuestieFramePool = QuestieLoader:ImportModule("QuestieFramePool")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

-------------------------
--Compat
-------------------------
local pairs = pairs
local ipairs = ipairs
local tinsert = table.insert
local GetTime = GetTime

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
local routeIcons = {}
local routeLines = {}

-------------------------
--Constants
-------------------------
local ROUTE_COLOR = {0.2, 0.8, 1, 0.8}
local ROUTE_ICON_TYPE = "route"

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
---@param coordinates table<number, {x: number, y: number, zone: number}>
---@return table<number, {x: number, y: number, zone: number}>
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

--- Get spawn coordinates for objectives in a quest using the same structure as QuestieMap
---@param questId number
---@return table<number, {x: number, y: number, zone: number}>?
local function _GetQuestObjectiveCoords(questId)
    local quest = QuestieDB.GetQuest(questId)
    if not quest then 
        Questie:Debug(Questie.DEBUG_DEVELOP, "[RouteOptimizer] Quest not found:", questId)
        return nil 
    end
    
    local coordinates = {}
    
    ---@param spawns table?
    ---@param zoneId number
    local function AddCoordsFromSpawns(spawns, zoneId)
        if not spawns then return end
        for _, spawnList in pairs(spawns) do
            if type(spawnList) == "table" then
                for _, coord in pairs(spawnList) do
                    if type(coord) == "table" and coord[1] and coord[2] then
                        local x, y = coord[1], coord[2]
                        if x and y and x > 0 and x <= 100 and y > 0 and y <= 100 then
                            tinsert(coordinates, {
                                x = x,
                                y = y,
                                zone = zoneId
                            })
                        end
                    end
                end
            end
        end
    end
    
    if quest.Objectives then
        for _, objective in pairs(quest.Objectives) do
            if objective.Spawns then
                for zoneId, spawnData in pairs(objective.Spawns) do
                    AddCoordsFromSpawns(spawnData, zoneId)
                end
            end
            if objective.Coordinates then
                for _, coordData in pairs(objective.Coordinates) do
                    if type(coordData) == "table" then
                        for _, coord in pairs(coordData) do
                            if type(coord) == "table" and coord[1] and coord[2] then
                                local x, y = coord[1], coord[2]
                                if x and y and x > 0 and x <= 100 and y > 0 and y <= 100 then
                                    tinsert(coordinates, {
                                        x = x,
                                        y = y,
                                        zone = objective.Zone or 0
                                    })
                                end
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
                    AddCoordsFromSpawns(spawnData, zoneId)
                end
            end
        end
    end
    
    Questie:Debug(Questie.DEBUG_DEVELOP, "[RouteOptimizer] Found", #coordinates, "coordinates for quest", questId)
    return coordinates
end

--- Get spawn coordinates for all tracked quests
---@return table<number, {x: number, y: number, zone: number}>?
local function _GetAllTrackedQuestCoords()
    local coordinates = {}
    local trackedQuests = Questie.db.char.TrackedQuests
    
    if not trackedQuests then 
        Questie:Debug(Questie.DEBUG_DEVELOP, "[RouteOptimizer] No tracked quests")
        return nil 
    end
    
    for questId in pairs(trackedQuests) do
        local questCoords = _GetQuestObjectiveCoords(questId)
        if questCoords then
            for _, coord in pairs(questCoords) do
                tinsert(coordinates, coord)
            end
        end
    end
    
    Questie:Debug(Questie.DEBUG_DEVELOP, "[RouteOptimizer] Found", #coordinates, "total coordinates")
    return coordinates
end

--- Clear all route visuals
function QuestieRouteOptimizer:ClearRoutes()
    for _, icon in pairs(routeIcons) do
        if icon and icon.Hide then
            icon:Hide()
        end
    end
    routeIcons = {}
    
    for _, line in pairs(routeLines) do
        if line and line.Hide then
            line:Hide()
        end
    end
    routeLines = {}
end

--- Draw route lines for a single zone
---@param waypoints table<number, {number, number}>
---@param zoneId number
local function _DrawZoneRoute(waypoints, zoneId)
    if #waypoints < 2 then return end
    
    local icon = CreateFrame("Button", "QuestieRouteIcon" .. #routeIcons, UIParent)
    icon:SetWidth(1)
    icon:SetHeight(1)
    icon:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    icon:SetFrameLevel(1)
    icon:Show()
    tinsert(routeIcons, icon)
    
    local lineFrames = QuestieFramePool:CreateWaypoints(icon, waypoints, 2, ROUTE_COLOR, zoneId)
    for _, lineFrame in ipairs(lineFrames) do
        lineFrame:Show()
        tinsert(routeLines, lineFrame)
    end
end

--- Draw optimized route for given coordinates
---@param coordinates table<number, {x: number, y: number, zone: number}>
function QuestieRouteOptimizer:DrawRoute(coordinates)
    self:ClearRoutes()
    
    if not coordinates or #coordinates < 2 then
        Questie:Debug(Questie.DEBUG_DEVELOP, "[RouteOptimizer] Not enough coordinates to draw route")
        return
    end
    
    local optimized = _NearestNeighborTSP(coordinates)
    
    local currentZone = nil
    local zoneWaypoints = {}
    
    for _, coord in ipairs(optimized) do
        if coord.zone == currentZone or not currentZone then
            tinsert(zoneWaypoints, {coord.x, coord.y})
            currentZone = coord.zone
        else
            if #zoneWaypoints >= 2 then
                _DrawZoneRoute(zoneWaypoints, currentZone)
            end
            zoneWaypoints = {{coord.x, coord.y}}
            currentZone = coord.zone
        end
    end
    
    if #zoneWaypoints >= 2 then
        _DrawZoneRoute(zoneWaypoints, currentZone)
    end
    
    Questie:Debug(Questie.DEBUG_DEVELOP, "[RouteOptimizer] Drew", #routeLines, "route lines")
end

--- Update route based on current mode
function QuestieRouteOptimizer:Update()
    local mode = Questie.db.profile.routeMode or ROUTE_MODE_OFF
    
    Questie:Debug(Questie.DEBUG_DEVELOP, "[RouteOptimizer] Update called, mode:", mode)
    
    if mode == ROUTE_MODE_OFF then
        self:ClearRoutes()
    elseif mode == ROUTE_MODE_SINGLE_QUEST then
        local questId = QuestTrackerFrame and QuestTrackerFrame.selectedQuestID
        if questId then
            local coords = _GetQuestObjectiveCoords(questId)
            if coords and #coords >= 2 then
                self:DrawRoute(coords)
            else
                self:ClearRoutes()
            end
        else
            self:ClearRoutes()
        end
    elseif mode == ROUTE_MODE_ALL_TRACKED or mode == ROUTE_MODE_TSP_APPROXIMATION then
        local coords = _GetAllTrackedQuestCoords()
        if coords and #coords >= 2 then
            self:DrawRoute(coords)
        else
            self:ClearRoutes()
        end
    end
end

--- Toggle route visibility
function QuestieRouteOptimizer:Toggle()
    if routeIcons and #routeIcons > 0 then
        self:ClearRoutes()
        Questie.db.profile.routeMode = ROUTE_MODE_OFF
    else
        self:Update()
    end
end

--- Get current route mode
---@return number mode
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
