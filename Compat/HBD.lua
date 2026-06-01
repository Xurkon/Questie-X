---@type QuestieMap
local QuestieMap = QuestieLoader:ImportModule("QuestieMap")

local mapData = QuestieCompat.UiMapData -- table { width, height, left, top, .instance, .name, .mapType }
local worldMapData = QuestieCompat.worldMapData -- table { width, height, left, top }

-- Keep a reference to the real HBD library (if available) so we can fall back to its map data
-- for maps not present in Questie's UiMapData (e.g., custom Ascension maps).
local RealHBD

-- Try to load the real HBD library under several known names, and if that fails,
-- scan the global environment for any table that looks like an HBD library (has .mapData).
local function LoadRealHBD()
    -- Common library identifiers
    for _, name in ipairs({"HereBeDragonsQuestie-2.0", "HereBeDragons-2.0", "HereBeDragons"}) do
        local ok, lib = pcall(LibStub, name, true)
        if ok and lib and lib.mapData then
            return lib
        end
    end
    -- Fallback: brute-force global scan for a table with a mapData field
    -- Use pcall protection because Ascension's client may have protected globals.
    local ok, _ = pcall(function()
        for _, v in pairs(_G) do
            if type(v) == "table" and v.mapData and type(v.mapData) == "table" then
                RealHBD = v
                error("_found")  -- break out of pcall early
            end
        end
    end)
    -- RealHBD was set inside the pcall if found; otherwise stays nil
    return RealHBD
end

-- Eager attempt at load; will also lazy-load on first use.
-- Wrap in pcall so HBD.lua doesn't fail to load if the global scan hits a protected table.
pcall(function()
    RealHBD = LoadRealHBD()
end)

local HBD = {mapData = mapData}
QuestieCompat.HBD = HBD

-- Ascension zone remapping: Sunstrider Isle (1241) and its ghost map (946) share
-- Eversong Woods' (1941) rendered area on Ascension's client. On Ascension,
-- the Sunstrider Isle map actually uses Eversong's coordinate space — not retail's
-- separate Sunstrider bounds. This means:
--   1. Visibility: zones sharing the same space should show each other's pins
--   2. Bounds: mapData[1241] must use Eversong's bounds so coordinate round-trips
--      produce correct positions on Ascension's Sunstrider map
--   3. Data: Questie spawn coords for Sunstrider (uiMapId=1241) are in the
--      33-38%/18-25% range, which maps to Sunstrider's location WITHIN Eversong
--
-- ZONE_REDIRECT: used by ResolveZone() for visibility logic (isSameZoneSpace).
-- NOTE: 1241 is NOT redirected to 1941. Map 1241 (Sunstrider) has its own
-- calibrated bounds that produce a different world coordinate space than
-- Eversong. Cross-map pin visibility (1241 pin showing on 1941 map, and vice
-- versa) works because QuestieMap.lua's DrawWorldIcon uses _ResolveMapUiMapId()
-- to register pins against the resolved parent map, and HBD's mapData[1241]
-- shares Eversong's bounds on Ascension — so the simplified isSameZoneSpace
-- check (effectiveUiMapID == effectiveDataUiMapID) passes for both maps.
-- Do not remove 1241 from the redirect table or split its bounds from 1941
-- without also re-introducing the sharesSunstriderSpace chain.
local ZONE_REDIRECT = {
    [946]  = 1941,  -- Ghost/transition map -> Eversong Woods (for Sunstrider loading)
}

--- Resolve a zone ID through the redirect table.
--- If the zone has a redirect, return the target zone; otherwise return the zone as-is.
local function ResolveZone(zone)
    return ZONE_REDIRECT[zone] or zone
end

-- Expose for external use (e.g. QuestieCompat coordinate calibration)
HBD.ResolveZone = ResolveZone

-- Ascension bounds override: On Ascension, Sunstrider Isle (1241) uses Eversong
-- Woods' coordinate space, not retail's separate Sunstrider bounds. The retail
-- mapData[1241] bounds (510, 500, -6983.33, 9766.67) are incompatible with
-- Ascension's world coordinates — UnitPosition returns Eversong-scale values
-- like (503.4, 267.9) which produce zone coords of (-14.68, 18.99) when converted
-- through retail Sunstrider bounds. Using Eversong's bounds makes coordinate
-- round-trips work correctly and positions pins at their actual locations.
--
-- Ghost map 946 has all-zeros bounds in retail, which makes it unusable; redirect
-- to Eversong bounds as well (it shares the same rendered area on Ascension).
local ASCENSION_ZONE_BOUNDS = {
    [1241] = { 1600.0, 1066.666666666667, -2721.0066, 8433.9360 },  -- Calibrated bounds for Sunstrider Isle
    [946]  = { 4925.0, 3283.33333, -1824.6778, 8641.6666 },  -- Ghost map shares Eversong geometry
}


-- Apply Ascension bounds overrides immediately
local _boundsApplied = false
local function ApplyAscensionBounds()
    if _boundsApplied then return end
    _boundsApplied = true
    
    if not RealHBD then
        pcall(function() RealHBD = LoadRealHBD() end)
    end
    
    for zoneId, bounds in pairs(ASCENSION_ZONE_BOUNDS) do
        local data = mapData[zoneId]
        if data then
            -- [HBD-Ascension] bounds override applied (debug disabled)
            data[1], data[2], data[3], data[4] = bounds[1], bounds[2], bounds[3], bounds[4]
        else
            -- [HBD-Ascension] WARNING: No mapData for zone (debug disabled)
        end
        
        -- Override the real HBD map data as well, because HBD-Pins bypasses QuestieCompat
        if RealHBD and RealHBD.mapData and RealHBD.mapData[zoneId] then
            local rData = RealHBD.mapData[zoneId]
            rData[1], rData[2], rData[3], rData[4] = bounds[1], bounds[2], bounds[3], bounds[4]
        end
    end
end
ApplyAscensionBounds()

-- One-shot debug: print mapData bounds for key zones on PLAYER_LOGIN
local _boundsDebugPrinted = false
local function PrintBoundsDebug()
    if _boundsDebugPrinted then return end
    _boundsDebugPrinted = true
    ApplyAscensionBounds()
    for _, id in ipairs({1241, 946, 1941}) do
        local d = mapData[id]
        if d then
            -- [HBD-Bounds] debug disabled
        else
            -- [HBD-Bounds] no mapData (debug disabled)
        end
    end
end
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event)
    PrintBoundsDebug()
    self:UnregisterEvent(event)
end)

--- Convert local/point coordinates to world coordinates in yards
--- @param x X position in 0-1 point coordinates
--- @param y Y position in 0-1 point coordinates
--- @param zone uiMapID of the zone
function HBD:GetWorldCoordinatesFromZone(x, y, zone)
    -- Ascension: mapData[946] has been overridden with Eversong bounds.
    -- mapData[1241] has its own calibrated bounds that match the game engine's
    -- Sunstrider coordinate space. Both convert through their own bounds —
    -- no redirect needed here because _ResolveMapUiMapId passes 1241 through.
    local data = mapData[zone]
    if not data or data[1] == 0 or data[2] == 0 then
        -- Attempt to lazy-load the real HBD if we haven't yet
        if not RealHBD then
            pcall(function() RealHBD = LoadRealHBD() end)
        end
        if RealHBD and RealHBD.mapData then
            data = RealHBD.mapData[zone]
        end
        if not data or data[1] == 0 or data[2] == 0 then
            return nil, nil, nil
        end
    end
    if not x or not y then return nil, nil, nil end

    local width, height, left, top = data[1], data[2], data[3], data[4]
    x, y = left - width * x, top - height * y

    return x, y, data.instance
end

--- Convert world coordinates to local/point zone coordinates
--- @param x Global X position
--- @param y Global Y position
--- @param zone uiMapID of the zone
--- @param allowOutOfBounds Allow coordinates to go beyond the current map (ie. outside of the 0-1 range), otherwise nil will be returned
function HBD:GetZoneCoordinatesFromWorld(x, y, zone, allowOutOfBounds)
    -- Ascension: mapData[946] has been overridden with Eversong bounds.
    -- mapData[1241] has its own calibrated bounds matching the engine's space.
    -- No redirect needed — callers pass the correct zone directly.
    local data = mapData[zone]
    if not data or data[1] == 0 or data[2] == 0 then
        if not RealHBD then
            pcall(function() RealHBD = LoadRealHBD() end)
        end
        if RealHBD and RealHBD.mapData then
            data = RealHBD.mapData[zone]
        end
        if not data or data[1] == 0 or data[2] == 0 then
            return nil, nil
        end
    end
    if not x or not y then return nil, nil end

    local width, height, left, top = data[1], data[2], data[3], data[4]
    x, y = (left - x) / width, (top - y) / height

    -- verify the coordinates fall into the zone
    if not allowOutOfBounds and (x < 0 or x > 1 or y < 0 or y > 1) then return nil, nil end

    return x, y
end

--- Convert world coordinates to local/point zone coordinates on the azeroth world map
-- @param x Global X position
-- @param y Global Y position
-- @param instance Instance to translate coordinates from
-- @param allowOutOfBounds Allow coordinates to go beyond the current map (ie. outside of the 0-1 range), otherwise nil will be returned
function HBD:GetAzerothWorldMapCoordinatesFromWorld(x, y, instance, allowOutOfBounds)
    local data = worldMapData[instance]
    if not data or data[1] == 0 or data[2] == 0 then return nil, nil end
    if not x or not y then return nil, nil end

    local width, height, left, top = data[1], data[2], data[3], data[4]
    x, y = (left - x) / width, (top - y) / height

    -- verify the coordinates fall into the zone
    if not allowOutOfBounds and (x < 0 or x > 1 or y < 0 or y > 1) then return nil, nil end

    return x, y
end

--- Return the distance from an origin position to a destination position in the same instance/continent.
-- @param instanceID instance ID
-- @param oX origin X
-- @param oY origin Y
-- @param dX destination X
-- @param dY destination Y
-- @return distance, deltaX, deltaY
function HBD:GetWorldDistance(instanceID, oX, oY, dX, dY)
    if not oX or not oY or not dX or not dY then return nil, nil, nil end
    local deltaX, deltaY = dX - oX, dY - oY
    return (deltaX * deltaX + deltaY * deltaY)^0.5, deltaX, deltaY
end

--- Return the distance between two points on the same continent
-- @param oZone origin zone uiMapID
-- @param oX origin X, in local zone/point coordinates
-- @param oY origin Y, in local zone/point coordinates
-- @param dZone destination zone uiMapID
-- @param dX destination X, in local zone/point coordinates
-- @param dY destination Y, in local zone/point coordinates
-- @return distance, deltaX, deltaY in yards
function HBD:GetZoneDistance(oZone, oX, oY, dZone, dX, dY)
    local oInstance, dInstance
    oX, oY, oInstance = self:GetWorldCoordinatesFromZone(oX, oY, oZone)
    if not oX then return nil, nil, nil end

    -- translate dX, dY to the origin zone
    dX, dY, dInstance = self:GetWorldCoordinatesFromZone(dX, dY, dZone)
    if not dX then return nil, nil, nil end

    if oInstance ~= dInstance then return nil, nil, nil end

    return self:GetWorldDistance(oInstance, oX, oY, dX, dY)
end

-- Position cache: avoid hammering the C API more than 20 times per second.
-- These are invalidated on zone-change events below.
local _pos_cache_interval = 0.05
local _pzp_x, _pzp_y, _pzp_mapID, _pzp_time = nil, nil, nil, 0
local _pwp_x, _pwp_y, _pwp_inst, _pwp_time = nil, nil, nil, 0

--- Get the current world position of the player
-- The position is transformed to the current continent, if applicable
-- @return x, y, instanceID
function HBD:GetPlayerWorldPosition()
    local now = GetTime()
    if now - _pwp_time < _pos_cache_interval then
        return _pwp_x, _pwp_y, _pwp_inst
    end

    local x, y, uiMapID = HBD:GetPlayerZonePosition()
    if not x or not y then
        _pwp_x, _pwp_y, _pwp_inst = nil, nil, nil
        _pwp_time = now
        return nil, nil, nil
    end

    local wx, wy, inst = HBD:GetWorldCoordinatesFromZone(x, y, uiMapID)
    _pwp_x, _pwp_y, _pwp_inst = wx, wy, inst
    _pwp_time = now
    if wx and wy then
        return wx, wy, inst
    end
    return nil, nil, nil
end

--- Get the current zone and level of the player
-- The returned mapFile can represent a micro dungeon, if the player currently is inside one.
-- @return uiMapID, mapType
function HBD:GetPlayerZone()
    return QuestieCompat.GetCurrentPlayerPosition()
end

--- Get the current position of the player on a zone level
-- The returned values are local point coordinates, 0-1. The mapFile can represent a micro dungeon.
-- @param allowOutOfBounds Allow coordinates to go beyond the current map (ie. outside of the 0-1 range), otherwise nil will be returned
-- @return x, y, uiMapID, mapType
function HBD:GetPlayerZonePosition(allowOutOfBounds)
    local now = GetTime()
    if now - _pzp_time < _pos_cache_interval then
        return _pzp_x, _pzp_y, _pzp_mapID
    end

    local uiMapID, x, y = QuestieCompat.GetCurrentPlayerPosition()
    _pzp_x, _pzp_y, _pzp_mapID = x, y, uiMapID
    _pzp_time = now

    if uiMapID and x and y then
        return x, y, uiMapID
    end
    return nil, nil, nil, nil
end

local function _InvalidatePositionCache()
    _pzp_time = 0
    _pwp_time = 0
end

-- Data Constants
local WORLD_MAP_ID = 947

-- upvalue lua api
local cos, sin, max = math.cos, math.sin, math.max
local type, pairs = type, pairs

-- upvalue wow api
local GetPlayerFacing = GetPlayerFacing

-- storage for minimap pins
local minimapPins = {}
local activeMinimapPins = {}
local minimapPinRegistry = {}

-- and worldmap pins
local worldmapPins = {}
local worldmapPinRegistry = {}

-- 3.3.5a: C_Minimap.GetViewRadius does NOT exist. Use Minimap:GetViewRadius() (native 3.3.5a API).
-- C_Minimap path is kept as secondary fallback in case some custom client adds it.
local MinimapRadiusAPI = (C_Minimap and C_Minimap.GetViewRadius) or Minimap.GetViewRadius

local pins = {
    Minimap = Minimap,
    updateFrame = CreateFrame("Frame"),
    activeMinimapPins = activeMinimapPins,
    worldmapPins = worldmapPins,
    worldmapProvider = {
        GetMap = function(self) return QuestieCompat.WorldMapFrame end,
    },
}
QuestieCompat.HBDPins = pins

local minimap_size = {
    indoor = {
        [0] = 300, -- scale
        [1] = 240, -- 1.25
        [2] = 180, -- 5/3
        [3] = 120, -- 2.5
        [4] = 80,  -- 3.75
        [5] = 50,  -- 6
    },
    outdoor = {
        -- Ascension (Warcraft Reborn) calibrated values.
        -- Zoom 5 base value 250.
        -- Each lower zoom level multiplies by 1.2 (standard WoW zoom step ratio).
        [0] = 622.08,  -- zoom5 * 1.2^5
        [1] = 518.40,  -- zoom5 * 1.2^4
        [2] = 432.00,  -- zoom5 * 1.2^3
        [3] = 360.00,  -- zoom5 * 1.2^2
        [4] = 300.00,  -- zoom5 * 1.2^1
        [5] = 250.00,  -- base value
    },
}

---@class MinimapShapes
local minimap_shapes = {
    -- { upper-left, lower-left, upper-right, lower-right }
    ["SQUARE"]                = { false, false, false, false },
    ["CORNER-TOPLEFT"]        = { true,  false, false, false },
    ["CORNER-TOPRIGHT"]       = { false, false, true,  false },
    ["CORNER-BOTTOMLEFT"]     = { false, true,  false, false },
    ["CORNER-BOTTOMRIGHT"]    = { false, false, false, true },
    ["SIDE-LEFT"]             = { true,  true,  false, false },
    ["SIDE-RIGHT"]            = { false, false, true,  true },
    ["SIDE-TOP"]              = { true,  false, true,  false },
    ["SIDE-BOTTOM"]           = { false, true,  false, true },
    ["TRICORNER-TOPLEFT"]     = { true,  true,  true,  false },
    ["TRICORNER-TOPRIGHT"]    = { true,  false, true,  true },
    ["TRICORNER-BOTTOMLEFT"]  = { true,  true,  false, true },
    ["TRICORNER-BOTTOMRIGHT"] = { false, true,  true,  true },
}

local tableCache = setmetatable({}, {__mode='k'})

local function newCachedTable()
    local t = next(tableCache)
    if t then
        tableCache[t] = nil
    else
        t = {}
    end
    return t
end

local function recycle(t)
    tableCache[t] = true
end

-------------------------------------------------------------------------------------------
-- Minimap pin position logic

-- minimap rotation
local rotateMinimap = GetCVar("rotateMinimap") == "1"

-- is the minimap indoors or outdoors
local indoors = GetCVar("minimapZoom")+0 == pins.Minimap:GetZoom() and "outdoor" or "indoor"

local minimapPinCount, queueFullUpdate = 0, false
---@type unknown, MinimapShapes?
local minimapScale, minimapShape, mapRadius, minimapWidth, minimapHeight, mapSin, mapCos
local lastZoom, lastFacing, lastXY, lastYY

local function drawMinimapPin(pin, data)
    local xDist, yDist = lastXY - data.x, lastYY - data.y

    -- handle rotation
    if rotateMinimap then
        local dx, dy = xDist, yDist
        xDist = dx*mapCos - dy*mapSin
        yDist = dx*mapSin + dy*mapCos
    end

    -- adapt delta position to the map radius
    local diffX = xDist / mapRadius
    local diffY = yDist / mapRadius

    -- different minimap shapes
    ---@type boolean|number
    local isRound = true
    if minimapShape and not (xDist == 0 or yDist == 0) then
        isRound = (xDist < 0) and 1 or 3
        if yDist < 0 then
            isRound = minimapShape[isRound]
        else
            isRound = minimapShape[isRound + 1]
        end
    end

    -- calculate distance from the center of the map
    local dist
    if isRound then
        dist = (diffX*diffX + diffY*diffY) / 0.9^2
    else
        dist = max(diffX*diffX, diffY*diffY) / 0.9^2
    end

    -- if distance > 1, then adapt node position to slide on the border
    if dist > 1 and data.floatOnEdge then
        dist = dist^0.5
        diffX = diffX/dist
        diffY = diffY/dist
    end

    -- Questie Modification.
    -- data.floatOnEdge is replaced by (data.floatOnEdge and ((pin.texture and pin.texture.a and pin.texture.a ~= 0) or pin.texture == nil))
    -- icons will now only float on edge if they have an opacity which is not 0 or if no texture exist.
    data.distanceFromMinimapCenter = dist
    if dist <= 1 or (data.floatOnEdge and ((pin.texture and pin.texture.a and pin.texture.a ~= 0) or pin.texture == nil)) then
        pin:Show()
        pin:ClearAllPoints()
        pin:SetPoint("CENTER", pins.Minimap, "CENTER", diffX * minimapWidth, -diffY * minimapHeight)
        data.onEdge = (dist > 1)
    else
        pin:Hide()
        data.onEdge = nil
        pin.keep = nil
    end
end

local function _GetEffectiveMinimapPlayerWorldPosition()
    -- For minimap pins we MUST use HBD's native world coordinate space.
    -- Minimap pins store their positions in HBD world coords, so the player
    -- position must also be in HBD world coords. The calibrated pseudo-world
    -- space (used by the arrow) has a different origin/scale on Ascension and
    -- must never be mixed with minimap pin positions.
    return HBD:GetPlayerWorldPosition()
end

local function UpdateMinimapPins(force)
    -- get the current player position
    local x, y, instanceID = _GetEffectiveMinimapPlayerWorldPosition()

    -- get data from the API for calculations
    local zoom = pins.Minimap:GetZoom()
    local diffZoom = zoom ~= lastZoom

    -- for rotating minimap support
    local facing
    if rotateMinimap then
        facing = GetPlayerFacing()
    else
        facing = lastFacing
    end

    -- check for all values to be available (starting with 7.1.0, instances don't report coordinates)
    if not x or not y or (rotateMinimap and not facing) then
        minimapPinCount = 0
        for pin in pairs(activeMinimapPins) do
            pin:Hide()
            activeMinimapPins[pin] = nil
        end
        return
    end

    local newScale = pins.Minimap:GetScale()
    if minimapScale ~= newScale then
        minimapScale = newScale
        force = true
    end

    if x ~= lastXY or y ~= lastYY or diffZoom or facing ~= lastFacing or force then
        -- minimap information
        minimapShape = GetMinimapShape and minimap_shapes[GetMinimapShape() or "ROUND"]
        -- Compute mapRadius and width/height from the same minimap_size table each frame.
        -- Both values must stay in sync regardless of UI scale changes.
        -- mapRadius: used for diffX/diffY normalization in drawMinimapPin
        -- minimapWidth/minimapHeight: used for pixel offset in SetPoint
        if MinimapRadiusAPI then
            mapRadius = MinimapRadiusAPI(Minimap)
        else
            local sizeTable = minimap_size[indoors] or minimap_size.outdoor
            local size = sizeTable[zoom]
                or sizeTable[5] or sizeTable[4] or sizeTable[3]
                or sizeTable[2] or sizeTable[1] or sizeTable[0]
            mapRadius = size / 2
        end
        -- minimapWidth = actual half-width of the visible minimap frame in screen pixels.
        -- diffX (yards) / mapRadius (yards in viewport) * minimapWidth (pixels) = correct screen offset.
        -- No additional scaling needed when mapRadius comes from the live API.
        minimapWidth  = pins.Minimap:GetWidth()  * pins.Minimap:GetScale() / 2
        minimapHeight = pins.Minimap:GetHeight() * pins.Minimap:GetScale() / 2

        --[[ DEBUG: One-shot per (zoom, indoors, diffZoom) — shows pixel math state
        if not _G.QuestieDebugPinMath then _G.QuestieDebugPinMath = {} end
        local dbgKey = zoom .. ":" .. (indoors or "?") .. ":" .. tostring(diffZoom)
        if not _G.QuestieDebugPinMath[dbgKey] then
            _G.QuestieDebugPinMath[dbgKey] = true
            print("QDMATH:", dbgKey,
                "mw="..math.floor(minimapWidth),
                "mh="..math.floor(minimapHeight),
                "mapR="..math.floor(mapRadius),
                "ratio="..math.floor((minimapWidth/mapRadius)*100)/100)
        end
        --]]

        local px, py = x, y
        local pInst = instanceID
        --[[ DEBUG: One-shot on first UpdateMinimapPins entry
        if not _G.QuestieDebugPinMath.entering then
            _G.QuestieDebugPinMath.entering = true
            print("UPDATE entering")
        end
        --]]
        lastFacing = facing
        lastXY, lastYY = x, y

        if rotateMinimap then
            mapSin = sin(facing)
            mapCos = cos(facing)
        end

        for pin, data in pairs(minimapPins) do
            if instanceID == data.instanceID and math.abs(x-data.x) + math.abs(y-data.y) < 500 then -- questie specific fix
                activeMinimapPins[pin] = data
                data.keep = true
                -- draw the pin (this may reset data.keep if outside of the map)
                drawMinimapPin(pin, data)
            end
        end

        minimapPinCount = 0
        for pin, data in pairs(activeMinimapPins) do
            if not data.keep then
                pin:Hide()
                activeMinimapPins[pin] = nil
            else
                minimapPinCount = minimapPinCount + 1
                data.keep = nil
            end
        end
    end
end

local function UpdateMinimapIconPosition()
    -- we have no active minimap pins, just return early
    if minimapPinCount == 0 then return end

    local x, y = _GetEffectiveMinimapPlayerWorldPosition()

    --[[ DEBUG: per-frame player world X trace — fires on first 5 calls then on x change
    if not _G.QuestieDebugPinMath.iconCalled then
        _G.QuestieDebugPinMath.iconCalled = 0
        _G.QuestieDebugPinMath.iconCalled_lastXY = -9999
    end
    _G.QuestieDebugPinMath.iconCalled = _G.QuestieDebugPinMath.iconCalled + 1
    local call = _G.QuestieDebugPinMath.iconCalled
    if call <= 5 or x ~= _G.QuestieDebugPinMath.iconCalled_lastXY then
        print("ICON", call, "x=", x and math.floor(x*100)/100, "lastXY=", lastXY and math.floor(lastXY*100)/100, "diffX=", x and (x-lastXY) and math.floor((x-lastXY)*100)/100 or "nil", "zoom=", zoom)
    end
    _G.QuestieDebugPinMath.iconCalled_lastXY = x
    --]]

    local zoom = pins.Minimap:GetZoom()
    local diffZoom = zoom ~= lastZoom
    -- if the map zoom changed, run a full update sweep
    if diffZoom then
        UpdateMinimapPins()
        return
    end

    -- for rotating minimap support
    local facing
    if rotateMinimap then
        facing = GetPlayerFacing()
    else
        facing = lastFacing
    end

    -- check for all values to be available (starting with 7.1.0, instances don't report coordinates)
    if not x or not y or (rotateMinimap and not facing) then
        UpdateMinimapPins()
        return
    end

    local refresh
    local newScale = pins.Minimap:GetScale()
    if minimapScale ~= newScale then
        minimapScale = newScale
        refresh = true
    end

    if x ~= lastXY or y ~= lastYY or facing ~= lastFacing or refresh then
        -- Use mapRadius for width/height to stay self-consistent with the minimap_size
        -- lookup table. GetWidth() returns scaled size which diverges from mapRadius
        -- when UI/interface scale changes, causing drift at different zoom levels.
        if MinimapRadiusAPI then
            mapRadius = MinimapRadiusAPI(Minimap)
        else
            local sizeTable = minimap_size[indoors] or minimap_size.outdoor
			local size = sizeTable[zoom]
			or sizeTable[5]
			or sizeTable[4]
			or sizeTable[3]
			or sizeTable[2]
			or sizeTable[1]
			or sizeTable[0]

			mapRadius = size / 2
        end
        -- minimapWidth = actual half-width of the visible minimap frame in screen pixels.
        minimapWidth  = pins.Minimap:GetWidth()  * pins.Minimap:GetScale() / 2
        minimapHeight = pins.Minimap:GetHeight() * pins.Minimap:GetScale() / 2

        --[[ DEBUG: One-shot per (zoom, indoors) per-pin — shows ratio stability across zooms
        if not _G.QuestieDebugPinMath.pinMath then _G.QuestieDebugPinMath.pinMath = {} end
        local pmKey = zoom .. ":" .. (indoors or "?")
        if not _G.QuestieDebugPinMath.pinMath[pmKey] then
            _G.QuestieDebugPinMath.pinMath[pmKey] = true
            -- diffX = xDist / mapRadius, then final = diffX * minimapWidth
            -- If mapRadius changes but minimapWidth doesn't, the multiplier (minimapWidth/mapRadius) changes per zoom
            -- If both change proportionally, multiplier stays near 1.0
            print("QDMATH:", pmKey,
                "mw="..math.floor(minimapWidth),
                "mh="..math.floor(minimapHeight),
                "mapR="..math.floor(mapRadius),
                "ratio="..math.floor((minimapWidth/mapRadius)*100)/100)
        end
        --]]

        -- Compute pixel offset for this pin
        lastXY, lastYY = x, y
        lastFacing = facing

        if rotateMinimap then
            mapSin = sin(facing)
            mapCos = cos(facing)
        end

        -- iterate all nodes and check if they are still in range of our minimap display
        for pin, data in pairs(activeMinimapPins) do
            -- update the position of the node
            drawMinimapPin(pin, data)
        end
    end
end

local function UpdateMinimapZoom()
    if not MinimapRadiusAPI then
        local zoom = pins.Minimap:GetZoom()
        if GetCVar("minimapZoom") == GetCVar("minimapInsideZoom") then
            pins.Minimap:SetZoom(zoom < 2 and zoom + 1 or zoom - 1)
        end
        indoors = GetCVar("minimapZoom")+0 == pins.Minimap:GetZoom() and "outdoor" or "indoor"
        pins.Minimap:SetZoom(zoom)
    end
end

-------------------------------------------------------------------------------------------
-- WorldMap data provider

local Enum = {
    -- https://wowpedia.fandom.com/wiki/Enum.UIMapType
	UIMapType = {
		Cosmic = 0,
		World = 1,
		Continent = 2,
		Zone = 3,
		Dungeon = 4,
		Micro = 5,
		Orphan = 6
	}
}

local worldmapWidth, worldmapHeight

local function HandleWorldMapPin(icon, data)
    if not WorldMapFrame:IsVisible() then return end

    local uiMapID = QuestieCompat.GetCurrentUiMapID()

    -- check for a valid map
    if not uiMapID then return end

    --Questie Modification
    -- Child-map / zone-redirect exception: if we're viewing a child map (e.g. Sunstrider 1241)
    -- and the pin belongs to a parent map (e.g. Eversong 1941) or a zone that shares the same
    -- coordinate space, SHOW_CURRENT pins should still be visible.
    -- Also handles the reverse: pins tagged 1241/946 should show on 1941, and vice versa,
    -- because these maps share the same rendered area on Ascension.
    local effectiveUiMapID = ResolveZone(uiMapID)
    local effectiveDataUiMapID = ResolveZone(data.uiMapID)
    local isChildMap = false
    local ancestorMapID = HBD.mapData[uiMapID] and HBD.mapData[uiMapID].parentMapID
    while ancestorMapID and HBD.mapData[ancestorMapID] do
        if ancestorMapID == data.uiMapID then
            isChildMap = true
            break
        end
        ancestorMapID = HBD.mapData[ancestorMapID].parentMapID
    end
    -- Zone-redirect equivalence: if the viewed map and pin's map redirect to the same
    -- target, they share the same coordinate space and should show each other's pins.
    local isSameZoneSpace = (effectiveUiMapID == effectiveDataUiMapID)

    if (Questie.db.profile.hideIconsOnContinents == true) and (HBD.mapData[uiMapID].mapType == Enum.UIMapType.Continent or uiMapID == 947) or (uiMapID ~= data.uiMapID and data.worldMapShowFlag == HBD_PINS_WORLDMAP_SHOW_CURRENT and not isChildMap and not isSameZoneSpace) then
        icon:Hide();
        return;
    elseif(uiMapID == data.uiMapID and data.worldMapShowFlag == HBD_PINS_WORLDMAP_SHOW_CURRENT) or (isChildMap and data.worldMapShowFlag == HBD_PINS_WORLDMAP_SHOW_CURRENT) or (isSameZoneSpace and data.worldMapShowFlag == HBD_PINS_WORLDMAP_SHOW_CURRENT) then
        icon:Show();
    end

    if icon.type == "line" then return end

    local x, y
    if uiMapID == WORLD_MAP_ID then
        -- should this pin show on the world map?
        if uiMapID ~= data.uiMapID and data.worldMapShowFlag ~= HBD_PINS_WORLDMAP_SHOW_WORLD then return end

        -- translate to the world map
        x, y = HBD:GetAzerothWorldMapCoordinatesFromWorld(data.x, data.y, data.instanceID)
    else
        -- check that it matches the instance
        if not HBD.mapData[uiMapID] or HBD.mapData[uiMapID].instance ~= data.instanceID then return end

        if uiMapID ~= data.uiMapID then
            local mapType = HBD.mapData[uiMapID].mapType
            if not data.uiMapID then
                if mapType == Enum.UIMapType.Continent and data.worldMapShowFlag >= HBD_PINS_WORLDMAP_SHOW_CONTINENT then
                    --pass
                elseif mapType ~= Enum.UIMapType.Zone and mapType ~= Enum.UIMapType.Dungeon and mapType ~= Enum.UIMapType.Micro then
                    -- fail
                    return
                end
            else
                local show = true -- Questie fix to show icons in neighbour areas
                local parentMapID = HBD.mapData[data.uiMapID].parentMapID
                while parentMapID and HBD.mapData[parentMapID] do
                    if parentMapID == uiMapID then
                        local parentMapType = HBD.mapData[parentMapID].mapType
                        -- show on any parent zones if they are normal zones
                        if data.worldMapShowFlag >= HBD_PINS_WORLDMAP_SHOW_PARENT and
                            (parentMapType == Enum.UIMapType.Zone or parentMapType == Enum.UIMapType.Dungeon or parentMapType == Enum.UIMapType.Micro) then
                            show = true
                        -- show on the continent
                        elseif data.worldMapShowFlag >= HBD_PINS_WORLDMAP_SHOW_CONTINENT and
                            parentMapType == Enum.UIMapType.Continent then
                            show = true
                        elseif data.worldMapShowFlag == HBD_PINS_WORLDMAP_SHOW_CURRENT then
                            -- Questie modifications!
                            show = false
                        end
                        break
                        -- worldmap is handled above already
                    else
                        parentMapID = HBD.mapData[parentMapID].parentMapID
                    end
                end

                if not show then return end
            end
        end

        -- translate coordinates
        -- Ascension: mapData[1241] has calibrated Sunstrider bounds matching
        -- the game engine's coordinate space. Pins on zone 1241 use these
        -- bounds for world coord conversion, so they align with the player.
        x, y = HBD:GetZoneCoordinatesFromWorld(data.x, data.y, uiMapID)
        -- [HBD-Pins] pin position debug disabled
    end

    if x and y then
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", WorldMapButton, "TOPLEFT", x * worldmapWidth, -y * worldmapHeight)
        icon:Show()
    else
        icon:Hide()
    end
end

-- map event handling
local function UpdateMinimap()
    UpdateMinimapZoom()
    UpdateMinimapPins()
end

local function UpdateWorldMap()
    if not WorldMapFrame:IsVisible() then return end

    local scale = WorldMapButton:GetScale()
    worldmapWidth  = WorldMapButton:GetWidth()*scale
    worldmapHeight = WorldMapButton:GetHeight()*scale

    local mapScale = QuestieMap.GetScaleValue()

    for icon, data in pairs(worldmapPins) do
        icon:Hide()
        --icon:ClearAllPoints()

        QuestieMap.utils:RescaleIcon(icon, mapScale)
        HandleWorldMapPin(icon, data)
    end
end
pins.UpdateWorldMap = UpdateWorldMap

local last_update = 0
local function OnUpdateHandler(frame, elapsed)
    last_update = last_update + elapsed
    if last_update > 1 or queueFullUpdate then
        UpdateMinimapPins(queueFullUpdate)
        last_update = 0
        queueFullUpdate = false
    else
        UpdateMinimapIconPosition()
    end
end
pins.updateFrame:SetScript("OnUpdate", OnUpdateHandler)

local function OnEventHandler(frame, event, ...)
    if event == "CVAR_UPDATE" then
        local cvar, value = ...
        if cvar == "ROTATE_MINIMAP" then
            rotateMinimap = (value == "1")
            queueFullUpdate = true
        end
    elseif event == "MINIMAP_UPDATE_ZOOM" then
        UpdateMinimap()
    elseif event == "PLAYER_LOGIN" then
        -- recheck cvars after login
        rotateMinimap = GetCVar("rotateMinimap") == "1"
    elseif event == "PLAYER_ENTERING_WORLD" then
        _InvalidatePositionCache()
        UpdateMinimap()
        UpdateWorldMap()
    elseif event == "WORLD_MAP_UPDATE" then
        UpdateWorldMap()
    elseif string.find(event, "ZONE_CHANGED") then
        _InvalidatePositionCache()
        UpdateMinimap()
        UpdateWorldMap()
    end
end

pins.updateFrame:SetScript("OnEvent", OnEventHandler)
pins.updateFrame:RegisterEvent("CVAR_UPDATE")
pins.updateFrame:RegisterEvent("MINIMAP_UPDATE_ZOOM")
pins.updateFrame:RegisterEvent("WORLD_MAP_UPDATE")
pins.updateFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
pins.updateFrame:RegisterEvent("ZONE_CHANGED")
pins.updateFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
pins.updateFrame:RegisterEvent("PLAYER_LOGIN")
pins.updateFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Showing quest objectives does not trigger WORLD_MAP_UPDATE event
hooksecurefunc("WorldMapFrame_DisplayQuests", UpdateWorldMap)

--- Add a icon to the minimap (x/y world coordinate version)
-- Note: This API does not let you specify a map to limit the pin to, it'll be shown on all maps these coordinates are valid for.
-- @param ref Reference to your addon to track the icon under (ie. your "self" or string identifier)
-- @param icon Icon Frame
-- @param instanceID Instance ID of the map to add the icon to
-- @param x X position in world coordinates
-- @param y Y position in world coordinates
-- @param floatOnEdge flag if the icon should float on the edge of the minimap when going out of range, or hide immediately (default false)
function pins:AddMinimapIconWorld(ref, icon, instanceID, x, y, floatOnEdge)
    if not ref then
        error(MAJOR..": AddMinimapIconWorld: 'ref' must not be nil", 2)
    end
    if type(icon) ~= "table" or not icon.SetPoint then
        error(MAJOR..": AddMinimapIconWorld: 'icon' must be a frame", 2)
    end
    if type(instanceID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        error(MAJOR..": AddMinimapIconWorld: 'instanceID', 'x' and 'y' must be numbers", 2)
    end

    if not minimapPinRegistry[ref] then
        minimapPinRegistry[ref] = {}
    end

    minimapPinRegistry[ref][icon] = true

    local t = minimapPins[icon] or newCachedTable()
    t.instanceID = instanceID
    t.x = x
    t.y = y
    t.floatOnEdge = floatOnEdge
    t.uiMapID = nil
    t.showInParentZone = nil

    minimapPins[icon] = t
    queueFullUpdate = true

    icon:SetParent(pins.MinimapGroup or pins.Minimap)
end

--- Add a icon to the minimap (UiMapID zone coordinate version)
-- The pin will only be shown on the map specified, or optionally its parent map if specified
-- @param ref Reference to your addon to track the icon under (ie. your "self" or string identifier)
-- @param icon Icon Frame
-- @param uiMapID uiMapID of the map to place the icon on
-- @param x X position in local/point coordinates (0-1), relative to the zone
-- @param y Y position in local/point coordinates (0-1), relative to the zone
-- @param showInParentZone flag if the icon should be shown in its parent zone - ie. an icon in a microdungeon in the outdoor zone itself (default false)
-- @param floatOnEdge flag if the icon should float on the edge of the minimap when going out of range, or hide immediately (default false)
function pins:AddMinimapIconMap(ref, icon, uiMapID, x, y, showInParentZone, floatOnEdge)
    if not ref then
        error(MAJOR..": AddMinimapIconMap: 'ref' must not be nil", 2)
    end
    if type(icon) ~= "table" or not icon.SetPoint then
        error(MAJOR..": AddMinimapIconMap: 'icon' must be a frame", 2)
    end
    if type(uiMapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        error(MAJOR..": AddMinimapIconMap: 'uiMapID', 'x' and 'y' must be numbers", 2)
    end

    -- convert to world coordinates and use our known adding function
    local xCoord, yCoord, instanceID = HBD:GetWorldCoordinatesFromZone(x, y, uiMapID)
    if not xCoord then return end

    self:AddMinimapIconWorld(ref, icon, instanceID, xCoord, yCoord, floatOnEdge)

    -- store extra information
    minimapPins[icon].uiMapID = uiMapID
    minimapPins[icon].showInParentZone = showInParentZone
end

--- Check if a floating minimap icon is on the edge of the map
-- @param icon the minimap icon
function pins:IsMinimapIconOnEdge(icon)
    if not icon then return false end
    local data = minimapPins[icon]
    if not data then return nil end

    return data.onEdge
end

--- Remove a minimap icon
-- @param ref Reference to your addon to track the icon under (ie. your "self" or string identifier)
-- @param icon Icon Frame
function pins:RemoveMinimapIcon(ref, icon)
    if not ref or not icon or not minimapPinRegistry[ref] then return end
    minimapPinRegistry[ref][icon] = nil
    if minimapPins[icon] then
        recycle(minimapPins[icon])
        minimapPins[icon] = nil
        activeMinimapPins[icon] = nil
    end
    icon:Hide()
end

--- Remove all minimap icons belonging to your addon (as tracked by "ref")
-- @param ref Reference to your addon to track the icon under (ie. your "self" or string identifier)
function pins:RemoveAllMinimapIcons(ref)
    if not ref or not minimapPinRegistry[ref] then return end
    for icon in pairs(minimapPinRegistry[ref]) do
        recycle(minimapPins[icon])
        minimapPins[icon] = nil
        activeMinimapPins[icon] = nil
        icon:Hide()
    end
    wipe(minimapPinRegistry[ref])
end

--- Set the minimap object to position the pins on. Needs to support the usual functions a Minimap-type object exposes.
-- @param minimapObject The new minimap object, or nil to restore the default
function pins:SetMinimapObject(minimapObject)
    pins.Minimap = minimapObject or Minimap
    for pin in pairs(minimapPins) do
        pin:SetParent(pins.Minimap)
    end
    UpdateMinimapPins(true)
end

-- world map constants
-- show worldmap pin only on zone map (Questie modification)
HBD_PINS_WORLDMAP_SHOW_CURRENT   = -1
-- show worldmap pin on its parent zone map (if any)
HBD_PINS_WORLDMAP_SHOW_PARENT    = 1
-- show worldmap pin on the continent map
HBD_PINS_WORLDMAP_SHOW_CONTINENT = 2
-- show worldmap pin on the continent and world map
HBD_PINS_WORLDMAP_SHOW_WORLD     = 3

--- Add a icon to the world map (x/y world coordinate version)
-- Note: This API does not let you specify a map to limit the pin to, it'll be shown on all maps these coordinates are valid for.
-- @param ref Reference to your addon to track the icon under (ie. your "self" or string identifier)
-- @param icon Icon Frame
-- @param instanceID Instance ID of the map to add the icon to
-- @param x X position in world coordinates
-- @param y Y position in world coordinates
-- @param showFlag Flag to control on which maps this pin will be shown
-- @param frameLevel Optional Frame Level type registered with the WorldMapFrame, defaults to PIN_FRAME_LEVEL_AREA_POI
function pins:AddWorldMapIconWorld(ref, icon, instanceID, x, y, showFlag, frameLevel)
    if not ref then
        error(MAJOR..": AddWorldMapIconWorld: 'ref' must not be nil", 2)
    end
    if type(icon) ~= "table" or not icon.SetPoint then
        error(MAJOR..": AddWorldMapIconWorld: 'icon' must be a frame", 2)
    end
    if type(instanceID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        error(MAJOR..": AddWorldMapIconWorld: 'instanceID', 'x' and 'y' must be numbers", 2)
    end
    if showFlag ~= nil and type(showFlag) ~= "number" then
        error(MAJOR..": AddWorldMapIconWorld: 'showFlag' must be a number (or nil)", 2)
    end

    if not worldmapPinRegistry[ref] then
        worldmapPinRegistry[ref] = {}
    end

    worldmapPinRegistry[ref][icon] = true

    local t = worldmapPins[icon] or newCachedTable()
    t.instanceID = instanceID
    t.x = x
    t.y = y
    t.uiMapID = nil
    t.worldMapShowFlag = showFlag or 0
    t.frameLevelType = frameLevel

    worldmapPins[icon] = t

    icon.icon = icon --LOL!
    icon:SetParent(WorldMapButton)
    HandleWorldMapPin(icon, t)
end

--- Add a icon to the world map (uiMapID zone coordinate version)
-- @param ref Reference to your addon to track the icon under (ie. your "self" or string identifier)
-- @param icon Icon Frame
-- @param uiMapID uiMapID of the map to place the icon on
-- @param x X position in local/point coordinates (0-1), relative to the zone
-- @param y Y position in local/point coordinates (0-1), relative to the zone
-- @param showFlag Flag to control on which maps this pin will be shown
-- @param frameLevel Optional Frame Level type registered with the WorldMapFrame, defaults to PIN_FRAME_LEVEL_AREA_POI
function pins:AddWorldMapIconMap(ref, icon, uiMapID, x, y, showFlag, frameLevel)
    if not ref then
        error(MAJOR..": AddWorldMapIconMap: 'ref' must not be nil", 2)
    end
    if type(icon) ~= "table" or not icon.SetPoint then
        error(MAJOR..": AddWorldMapIconMap: 'icon' must be a frame", 2)
    end
    if type(uiMapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        error(MAJOR..": AddWorldMapIconMap: 'uiMapID', 'x' and 'y' must be numbers", 2)
    end
    if showFlag ~= nil and type(showFlag) ~= "number" then
        error(MAJOR..": AddWorldMapIconMap: 'showFlag' must be a number (or nil)", 2)
    end

    -- convert to world coordinates
    local xCoord, yCoord, instanceID = HBD:GetWorldCoordinatesFromZone(x, y, uiMapID)
    if not xCoord then return end

    if not worldmapPinRegistry[ref] then
        worldmapPinRegistry[ref] = {}
    end

    worldmapPinRegistry[ref][icon] = true

    local t = worldmapPins[icon] or newCachedTable()
    t.instanceID = instanceID
    t.x = xCoord
    t.y = yCoord
    t.uiMapID = uiMapID
    t.worldMapShowFlag = showFlag or 0
    t.frameLevelType = frameLevel

    worldmapPins[icon] = t

    icon.icon = icon --LOL!
    icon:SetParent(WorldMapDetailFrame or WorldMapButton or WorldMapFrame)
    HandleWorldMapPin(icon, t)
end

--- Remove a worldmap icon
-- @param ref Reference to your addon to track the icon under (ie. your "self" or string identifier)
-- @param icon Icon Frame
function pins:RemoveWorldMapIcon(ref, icon)
    if not ref or not icon or not worldmapPinRegistry[ref] then return end
    worldmapPinRegistry[ref][icon] = nil
    if worldmapPins[icon] then
        recycle(worldmapPins[icon])
        worldmapPins[icon] = nil
    end
    icon:Hide()
    icon:ClearAllPoints()
    icon:SetParent(UiParent)
end

--- Remove all worldmap icons belonging to your addon (as tracked by "ref")
-- @param ref Reference to your addon to track the icon under (ie. your "self" or string identifier)
function pins:RemoveAllWorldMapIcons(ref)
    if not ref or not worldmapPinRegistry[ref] then return end
    for icon in pairs(worldmapPinRegistry[ref]) do
        recycle(worldmapPins[icon])
        worldmapPins[icon] = nil
        icon:Hide()
        icon:ClearAllPoints()
        icon:SetParent(UiParent)
    end
    wipe(worldmapPinRegistry[ref])
end
