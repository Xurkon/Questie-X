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
---@type QuestieCompat
local QuestieCompat = QuestieLoader:ImportModule("QuestieCompat")
---@type QuestieFramePool
local QuestieFramePool = QuestieLoader:ImportModule("QuestieFramePool")
---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

-------------------------
--Compat
-------------------------
local pairs = pairs
local ipairs = ipairs
local tinsert = table.insert

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
local WAYPOINT_ICON = "Interface\\WorldMap\\WorldMapPartyIcon"

--- Calculate distance between two points
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@return number distance
local function _GetDistance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

--- Get player position on current map
---@return number? x
---@return number? y
local function _GetPlayerPosition()
    local mapID = GetCurrentMapAreaID()
    local x, y = GetPlayerMapPosition(mapID)
    if x == 0 and y == 0 then
        x, y = GetPlayerMapPosition("player")
    end
    return x, y
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

--- Get spawn coordinates for objectives in a quest
---@param questId number
---@return table<number, {x: number, y: number, zone: number}>?
local function _GetQuestObjectiveCoords(questId)
    local quest = QuestieDB.GetQuest(questId)
    if not quest then return nil end
    
    local coordinates = {}
    local currentMapId = GetCurrentMapAreaID()
    
    ---@param spawns table?
    ---@param zoneId number
    local function AddCoords(spawns, zoneId)
        if not spawns then return end
        for _, spawn in pairs(spawns) do
            if type(spawn) == "table" then
                for _, coord in pairs(spawn) do
                    if type(coord) == "table" and coord[1] and coord[2] then
                        local x, y = coord[1], coord[2]
                        if x > 0 and x <= 100 and y > 0 and y <= 100 then
                            tinsert(coordinates, {
                                x = x / 100,
                                y = y / 100,
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
                    AddCoords(spawnData, zoneId)
                end
            end
        end
    end
    
    return coordinates
end

--- Get spawn coordinates for all tracked quests
---@return table<number, {x: number, y: number, zone: number}>?
local function _GetAllTrackedQuestCoords()
    local coordinates = {}
    local trackedQuests = Questie.db.char.TrackedQuests
    
    if not trackedQuests then return nil end
    
    for questId in pairs(trackedQuests) do
        local questCoords = _GetQuestObjectiveCoords(questId)
        if questCoords then
            for _, coord in pairs(questCoords) do
                tinsert(coordinates, coord)
            end
        end
    end
    
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

--- Draw a route line between waypoints
---@param waypoints table<number, {x: number, y: number}>
---@param zoneId number
local function _DrawRouteLine(waypoints, zoneId)
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
        return
    end
    
    local optimized = _NearestNeighborTSP(coordinates)
    
    local currentMapId = GetCurrentMapAreaID()
    local mapWaypoints = {}
    local currentZone = nil
    
    for _, coord in ipairs(optimized) do
        if coord.zone == currentZone or not currentZone then
            tinsert(mapWaypoints, {coord.x, coord.y})
            currentZone = coord.zone
        else
            if #mapWaypoints >= 2 then
                _DrawRouteLine(mapWaypoints, currentZone)
            end
            mapWaypoints = {{coord.x, coord.y}}
            currentZone = coord.zone
        end
    end
    
    if #mapWaypoints >= 2 then
        _DrawRouteLine(mapWaypoints, currentZone)
    end
end

--- Update route based on current mode
function QuestieRouteOptimizer:Update()
    local mode = Questie.db.profile.routeMode or ROUTE_MODE_OFF
    
    if mode == ROUTE_MODE_OFF then
        self:ClearRoutes()
    elseif mode == ROUTE_MODE_SINGLE_QUEST then
        local questId = QuestieTracker:GetSelectedQuest()
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
