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

-- Ascension zone remapping: the ghost map 946 should be treated as Eversong
-- (1941) for pin routing, but Sunstrider Isle (1241) must keep its native
-- render target. Visibility between Sunstrider and Eversong is handled
-- separately in HandleWorldMapPin() so we do not collapse the draw target.
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

-- Sunstrider calibration note:
-- 1241 is the correct uiMapId for Sunstrider Isle and 3431 is the matching
-- areaId. The map texture itself is roughly 510x500, but the Ascension minimap
-- radius is in live-world yards. Using 510x500 compresses all objective
-- distances and makes nearby pins look glued to the player. Match the existing
-- QuestieCompat calibrated pseudo-world scale instead.
local ASCENSION_ZONE_BOUNDS = {
    [1241] = { 1353.0, 1353.0, -6983.33, 9766.67 },
    [946]  = { 1353.0, 1353.0, -6983.33, 9766.67 },
}


-- Apply Ascension bounds overrides immediately.
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
            data[1], data[2], data[3], data[4] = bounds[1], bounds[2], bounds[3], bounds[4]
        end
        if RealHBD and RealHBD.mapData and RealHBD.mapData[zoneId] then
            local rData = RealHBD.mapData[zoneId]
            rData[1], rData[2], rData[3], rData[4] = bounds[1], bounds[2], bounds[3], bounds[4]
        end
    end
end

-- Debug helper for Sunstrider calibration.
-- Future agents: use this only for map-fit work on Sunstrider Isle.
-- areaId 3431 = Sunstrider Isle subzone, uiMapId 1241 = Sunstrider Isle map.
-- It prints the world-space and zone-space values for a 1241 point so we can
-- compare the source coords against the rendered pin location.
function HBD:DebugSunstriderPoint(x, y)
    local worldX, worldY, instanceId = self:GetWorldCoordinatesFromZone(x, y, 1241)
    local zoneX, zoneY = nil, nil
    if worldX and worldY then
        zoneX, zoneY = self:GetZoneCoordinatesFromWorld(worldX, worldY, 1241)
    end
    print(string.format(
        "[SunstriderDebug] zone=1241 input=%.4f,%.4f world=%s,%s inst=%s roundtrip=%s,%s",
        x or -1,
        y or -1,
        tostring(worldX),
        tostring(worldY),
        tostring(instanceId),
        tostring(zoneX),
        tostring(zoneY)
    ))
end
ApplyAscensionBounds()

-- Re-apply Ascension bounds once the player has logged in.
local _boundsDebugPrinted = false
local function PrintBoundsDebug()
    if _boundsDebugPrinted then return end
    _boundsDebugPrinted = true
    ApplyAscensionBounds()
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
    -- mapData[1241] keeps its own calibrated Sunstrider bounds. Do not force
    -- 1241 through the ghost-map redirect here; visibility sharing is handled
    -- separately in HandleWorldMapPin().
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
    -- mapData[1241] keeps its own calibrated Sunstrider bounds. Callers should
    -- pass the real uiMapId they want to project, not the visibility alias.
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
        [0] = 466 + 2/3, -- scale
        [1] = 400,       -- 7/6
        [2] = 333 + 1/3, -- 1.4
        [3] = 266 + 2/6, -- 1.75
        [4] = 200,       -- 7/3
        [5] = 133 + 1/3, -- 3.5
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
local lastDebugPinPoints = setmetatable({}, { __mode = "k" })
local lastDebugPinScreens = setmetatable({}, { __mode = "k" })
local lastDebugPlayerWorldX, lastDebugPlayerWorldY

local function _GetMinimapViewRadius()
    if pins.Minimap and pins.Minimap.GetViewRadius then
        return pins.Minimap:GetViewRadius()
    end
end

local function _IsDebuggableMinimapPin(pin, data, distance, passesCutoff)
    if not pin or not data then return false end
    if passesCutoff then return true end
    if data.uiMapID == 1241 or data.uiMapID == 1941 or data.uiMapID == 946 then return true end
    if distance and distance < 150 then return true end

    local iconData = pin.data
    local label = iconData and (iconData.Name or iconData.name or iconData.Title)
    if label and string.find(string.lower(label), "mana", 1, true) then return true end
    if iconData and (iconData.Type == "available" or iconData.Type == "complete") then return true end

    local id = iconData and (iconData.Id or iconData.id or iconData.questId or iconData.QuestId or iconData.ObjectiveTargetId)
    return id == 8345 or id == 8346 or id == 15274 or id == 15278 or id == 15295
end

local function _GetMinimapPinDelta(data)
    local xDist, yDist = lastXY - data.x, lastYY - data.y

    if rotateMinimap then
        local dx, dy = xDist, yDist
        xDist = dx*mapCos - dy*mapSin
        yDist = dx*mapSin + dy*mapCos
    end

    return xDist, yDist
end

local function _GetMinimapPinScreenMetrics(data)
    local xDist, yDist = _GetMinimapPinDelta(data)
    local centerDist = mapRadius and mapRadius > 0 and math.sqrt(xDist*xDist + yDist*yDist) / mapRadius or nil
    local screenX = mapRadius and mapRadius > 0 and (xDist / mapRadius) * minimapWidth or nil
    local screenY = mapRadius and mapRadius > 0 and -(yDist / mapRadius) * minimapHeight or nil
    return xDist, yDist, centerDist, screenX, screenY
end

local function _DebugMinimapPin(pin, data, index, playerX, playerY, playerInstanceID, distance, passesCutoff, cutoff)
    local iconData = pin and pin.data
    local label = iconData and (iconData.Name or iconData.name or iconData.Title or iconData.Id or iconData.id) or "?"
    local questId = iconData and (iconData.questId or iconData.QuestId or iconData.Id or iconData.id) or "?"
    local targetId = iconData and (iconData.ObjectiveTargetId or iconData.objectiveTargetId or iconData.TargetId or iconData.targetId) or "?"
    local pinMapX = pin and pin.x or "?"
    local pinMapY = pin and pin.y or "?"
    local parent = pin and pin:GetParent()
    local point1, rel1, point2, xOff, yOff
    if pin and pin.GetPoint then
        point1, rel1, point2, xOff, yOff = pin:GetPoint()
    end
    local xDist, yDist, centerDist, screenX, screenY = _GetMinimapPinScreenMetrics(data)

    print(string.format(
        "[QD] MinimapPin #%d label=%s type=%s quest=%s target=%s ui=%s area=%s map=(%s,%s) world=(%s,%s) player=(%s,%s) inst=%s/%s dist=%s cutoff=%s pass=%s edge=%s delta=(%s,%s) center=%s screen=(%s,%s) shown=%s hidden=%s parent=%s point=(%s,%s,%s,%s,%s)",
        index,
        tostring(label),
        tostring(iconData and iconData.Type or "?"),
        tostring(questId),
        tostring(targetId),
        tostring(data.uiMapID),
        tostring(pin and pin.AreaID or "?"),
        tostring(pinMapX),
        tostring(pinMapY),
        tostring(data.x),
        tostring(data.y),
        tostring(playerX),
        tostring(playerY),
        tostring(data.instanceID),
        tostring(playerInstanceID),
        tostring(distance),
        tostring(cutoff),
        tostring(passesCutoff),
        tostring(data.onEdge),
        tostring(xDist),
        tostring(yDist),
        tostring(centerDist),
        tostring(screenX),
        tostring(screenY),
        tostring(pin and pin.IsShown and pin:IsShown() or nil),
        tostring(pin and pin.hidden),
        tostring(parent and parent.GetName and parent:GetName() or parent),
        tostring(point1),
        tostring(rel1 and rel1.GetName and rel1:GetName() or rel1),
        tostring(point2),
        tostring(xOff),
        tostring(yOff)
    ))
end

local function _DebugAnyMinimapPin(pin, data, index, label)
    local iconData = pin and pin.data
    local parent = pin and pin:GetParent()
    local point1, rel1, point2, xOff, yOff
    if pin and pin.GetPoint then
        point1, rel1, point2, xOff, yOff = pin:GetPoint()
    end
    print(string.format(
        "[QD] %s #%d label=%s type=%s ui=%s area=%s shown=%s hidden=%s parent=%s point=(%s,%s,%s,%s,%s) keep=%s edge=%s dataKeep=%s dataOnEdge=%s",
        label,
        index,
        tostring(iconData and (iconData.Name or iconData.name or iconData.Title or iconData.Id or iconData.id) or "?"),
        tostring(iconData and iconData.Type or "?"),
        tostring(data and data.uiMapID),
        tostring(pin and pin.AreaID or "?"),
        tostring(pin and pin.IsShown and pin:IsShown() or nil),
        tostring(pin and pin.hidden),
        tostring(parent and parent.GetName and parent:GetName() or parent),
        tostring(point1),
        tostring(rel1 and rel1.GetName and rel1:GetName() or rel1),
        tostring(point2),
        tostring(xOff),
        tostring(yOff),
        tostring(pin and pin.shouldBeShowing),
        tostring(pin and pin.onEdge),
        tostring(data and data.keep),
        tostring(data and data.onEdge)
    ))
end

local function _ComputeZoneSpaceDiff(data, pinWorldX, pinWorldY, playerWorldX, playerWorldY)
    -- For pins on child maps (like Sunstrider 1241 inside Eversong 1941),
    -- Ascension's GetPlayerMapPosition returns Eversong-relative coords, but
    -- GetWorldCoordinatesFromZone(childZone) treats them as child-relative,
    -- producing a wrong player world position.
    --
    -- Strategy: work entirely in the parent (Eversong/1941) zone space:
    --   1. Recover player's Eversong zone coords by reversing the (wrong)
    --      1241-bounds conversion: ep = (left_1241 - playerWorldX) / width_1241
    --   2. Convert pin's stored 1241 zone coord to Eversong zone coord:
    --      pin 1241-zone → 1241-world (via 1241 bounds) → 1941-zone (via 1941 bounds)
    --   3. Delta in Eversong zone-space, scale to pixels.
    local uiMapID = data and data.uiMapID
    local zoneX = data and data.zoneX
    local zoneY = data and data.zoneY
    if not uiMapID or not zoneX or not zoneY then return nil end

    -- Get the child-map bounds
    local childMd = mapData[uiMapID]
    if not childMd or childMd[1] == 0 or childMd[2] == 0 then
        if RealHBD and RealHBD.mapData then
            childMd = RealHBD.mapData[uiMapID]
        end
    end
    if not childMd or childMd[1] == 0 or childMd[2] == 0 then return nil end

    local childLeft, childTop = childMd[3], childMd[4]
    local childWidth, childHeight = childMd[1], childMd[2]

    -- Determine parent/common zone (Eversong 1941 for Sunstrider 1241)
    local parentZone = ZONE_REDIRECT[uiMapID]
    if not parentZone then
        parentZone = (uiMapID == 1241) and 1941 or uiMapID
    end

    -- Get the parent zone bounds
    local parentMd = mapData[parentZone]
    if not parentMd or parentMd[1] == 0 or parentMd[2] == 0 then
        if RealHBD and RealHBD.mapData then
            parentMd = RealHBD.mapData[parentZone]
        end
    end
    if not parentMd or parentMd[1] == 0 or parentMd[2] == 0 then return nil end

    local parentLeft, parentTop = parentMd[3], parentMd[4]
    local parentWidth, parentHeight = parentMd[1], parentMd[2]

    -- Step 1: Recover player's actual Eversong zone coords.
    -- playerWorldX was computed as childLeft - childWidth * ep (where ep is the
    -- Eversong zone coord that GetPlayerMapPosition returned). Reverse it.
    local playerEX = (childLeft - playerWorldX) / childWidth
    local playerEY = (childTop - playerWorldY) / childHeight

    -- Step 2: Convert pin's 1241 zone coord to Eversong world,
    --         then to Eversong zone coord
    local pinWorldX_child = childLeft - childWidth * zoneX
    local pinWorldY_child = childTop - childHeight * zoneY

    local pinEX = (parentLeft - pinWorldX_child) / parentWidth
    local pinEY = (parentTop - pinWorldY_child) / parentHeight

    -- Clamp to valid range
    if pinEX < -0.5 or pinEX > 1.5 or pinEY < -0.5 or pinEY > 1.5 then
        -- Pin is too far from the parent zone to be meaningful
        return nil
    end

    -- Step 3: Delta in Eversong zone-space
    local dX = pinEX - playerEX
    local dY = pinEY - playerEY

    -- Convert to minimap offset.
    -- Eversong zone delta * parentWidth = world-yard delta.
    -- Normalize by mapRadius, scale to pixel half-width.
    local mapRad = (mapRadius and mapRadius > 0) and mapRadius or 1
    local diffX = dX * (parentWidth / mapRad)
    local diffY = dY * (parentHeight / mapRad)

    return diffX, diffY
end

local function drawMinimapPin(pin, data)
    local xDist, yDist = _GetMinimapPinDelta(data)

    -- Try zone-space projection when the pin has uiMapID and zone coords.
    -- This avoids the world-coordinate conversion path that depends on
    -- ASCENSION_ZONE_BOUNDS being perfectly calibrated.
    local zDiffX, zDiffY
    if data and data.uiMapID and data.zoneX and data.zoneY and lastXY and lastYY then
        zDiffX, zDiffY = _ComputeZoneSpaceDiff(
            data, data.x, data.y, lastXY, lastYY)
    end

    -- Debug: trace pin projection when QuestieDebugPins is enabled
    if _G.QuestieDebugPins and pin and data then
        local iconData = pin.data
        local label = iconData and (iconData.Name or iconData.name or iconData.Title or "?") or "?"
        local pinType = iconData and iconData.Type or "?"
        -- Only print for available/complete quest pins (the ? and ! markers)
        if pinType == "available" or pinType == "complete" or pinType == "turnin" then
            local diffX_debug = mapRadius and mapRadius ~= 0 and (xDist / mapRadius) or 0
            local diffY_debug = mapRadius and mapRadius ~= 0 and (yDist / mapRadius) or 0
            local mmpw = minimapWidth or 0
            local mmph = minimapHeight or 0
            local screenX_debug = diffX_debug * mmpw
            local screenY_debug = -diffY_debug * mmph
            if zDiffX then
                print(string.format(
                    "[QD] drawPin ZONE label=%s type=%s zDiff=(%.4f,%.4f) zScreen=(%.1f,%.1f) | world delta=(%.2f,%.2f) diff=(%.4f,%.4f)",
                    tostring(label), tostring(pinType),
                    zDiffX, zDiffY, zDiffX * mmpw, -zDiffY * mmph,
                    xDist, yDist, diffX_debug, diffY_debug))
            else
                print(string.format(
                    "[QD] drawPin label=%s type=%s pinWorld=(%.2f,%.2f) playerWorld=(%.2f,%.2f) delta=(%.2f,%.2f) diff=(%.4f,%.4f) radius=%.2f screen=(%.1f,%.1f)",
                    tostring(label), tostring(pinType),
                    data.x or 0, data.y or 0,
                    lastXY or 0, lastYY or 0,
                    xDist, yDist,
                    diffX_debug, diffY_debug,
                    mapRadius or 0,
                    screenX_debug, screenY_debug))
            end
        end
    end

    -- Use zone-space diff if available, otherwise fall back to world-space
    local diffX, diffY
    if zDiffX and zDiffY then
        diffX, diffY = zDiffX, zDiffY
    else
        diffX = xDist / mapRadius
        diffY = yDist / mapRadius
    end

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
    local wx, wy, inst = HBD:GetPlayerWorldPosition()
    if _G.QuestieDebugPins and wx and wy then
        local px, py = pins.Minimap:GetCenter()
        local indoors = IsIndoor and IsIndoor() or false
        local viewRadius = _GetMinimapViewRadius()
        local zoom = pins.Minimap and pins.Minimap:GetZoom() or 0
        local shape = GetMinimapShape and GetMinimapShape() or "?"
        local mmpw = pins.Minimap:GetWidth() and (pins.Minimap:GetWidth() / 2) or 0
        local mmph = pins.Minimap:GetHeight() and (pins.Minimap:GetHeight() / 2) or 0
        print(string.format(
            "[QD] PlayerPos world=(%.2f,%.2f) viewRadius=%.2f zoom=%d shape=%s indoors=%s mmpSize=(%.1f,%.1f)",
            wx, wy, viewRadius or -1, zoom, tostring(shape), tostring(indoors), mmpw, mmph
        ))
    end
    return wx, wy, inst
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
        minimapWidth = pins.Minimap:GetWidth() / 2
        minimapHeight = pins.Minimap:GetHeight() / 2
        local viewRadius = _GetMinimapViewRadius()
        if viewRadius then
            mapRadius = viewRadius
        elseif MinimapRadiusAPI then
            mapRadius = C_Minimap.GetViewRadius()
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

        -- update upvalues for icon placement
        lastZoom = zoom
        lastFacing = facing
        lastXY, lastYY = x, y

        if rotateMinimap then
            mapSin = sin(facing)
            mapCos = cos(facing)
        end

        local debugPins = _G.QuestieDebugPins
        local debugPinIndex = 0
        if debugPins then
            _G.QuestieDebugPins = false
            print(string.format("[QD] UpdateMinimapPins playerWorld=(%s,%s) inst=%s zoom=%s radius=%s size=(%s,%s) rotate=%s totalPins=%s",
                tostring(x), tostring(y), tostring(instanceID), tostring(zoom), tostring(mapRadius),
                tostring(minimapWidth), tostring(minimapHeight), tostring(rotateMinimap), tostring(minimapPinCount)))
        end
        local playerMoveX, playerMoveY
        if debugPins and lastDebugPlayerWorldX and lastDebugPlayerWorldY then
            playerMoveX = x - lastDebugPlayerWorldX
            playerMoveY = y - lastDebugPlayerWorldY
        end
        if debugPins then
            lastDebugPlayerWorldX, lastDebugPlayerWorldY = x, y
        end

        local debugDeferredPins = {}
        local debugDeferredCount = 0
        local debugLimit = _G.QuestieDebugPinLimit or 8
        for pin, data in pairs(minimapPins) do
            -- Use the live minimap radius when the client exposes it. Sunstrider
            -- uses inflated pseudo-world bounds for placement, so mapData size is
            -- no longer a good visibility cutoff there.
            local cutoff = mapRadius and (mapRadius * 1.05) or 500
            if not _GetMinimapViewRadius() and data.uiMapID and HBD.mapData[data.uiMapID] then
                local w, h = HBD.mapData[data.uiMapID][1], HBD.mapData[data.uiMapID][2]
                if w and h and w > 0 and h > 0 then
                    cutoff = math.max(100, math.min(500, math.sqrt(w*w + h*h) * 0.15))
                end
            end
            local rawXDist, rawYDist = x - data.x, y - data.y
            local distance = math.sqrt(rawXDist*rawXDist + rawYDist*rawYDist)
            local passesCutoff = instanceID == data.instanceID and distance <= cutoff
            if debugPins and debugPinIndex < debugLimit and passesCutoff then
                debugPinIndex = debugPinIndex + 1
                _DebugMinimapPin(pin, data, debugPinIndex, x, y, instanceID, distance, passesCutoff, cutoff)
            elseif debugPins and _IsDebuggableMinimapPin(pin, data, distance, passesCutoff) then
                debugDeferredCount = debugDeferredCount + 1
                debugDeferredPins[debugDeferredCount] = {pin, data, distance, passesCutoff, cutoff}
            end
            if debugPins and pin and data then
                local _, _, _, screenX, screenY = _GetMinimapPinScreenMetrics(data)
                local lastScreen = lastDebugPinScreens[pin]
                if lastScreen and screenX and screenY then
                    print(string.format(
                        "[QD] PinMotion name=%s pass=%s playerMove=(%s,%s) screenMove=(%s,%s) screenNow=(%s,%s) screenPrev=(%s,%s)",
                        tostring(pin:GetName()),
                        tostring(passesCutoff),
                        tostring(playerMoveX),
                        tostring(playerMoveY),
                        tostring(screenX - lastScreen[1]),
                        tostring(screenY - lastScreen[2]),
                        tostring(screenX),
                        tostring(screenY),
                        tostring(lastScreen[1]),
                        tostring(lastScreen[2])
                    ))
                end
                if screenX and screenY then
                    lastDebugPinScreens[pin] = { screenX, screenY }
                end
            end
            if passesCutoff then -- questie specific fix
                activeMinimapPins[pin] = data
                data.keep = true
                -- draw the pin (this may reset data.keep if outside of the map)
                drawMinimapPin(pin, data)
                if debugPins and pin and pin.GetPoint then
                    local point1, rel1, point2, xOff, yOff = pin:GetPoint()
                    local pointKey = table.concat({
                        tostring(point1),
                        tostring(rel1 and rel1.GetName and rel1:GetName() or rel1),
                        tostring(point2),
                        tostring(xOff),
                        tostring(yOff)
                    }, "|")
                    if lastDebugPinPoints[pin] ~= pointKey then
                        print(string.format(
                            "[QD] PinAnchorChanged name=%s point=(%s,%s,%s,%s,%s) shown=%s hidden=%s parent=%s",
                            tostring(pin:GetName()),
                            tostring(point1),
                            tostring(rel1 and rel1.GetName and rel1:GetName() or rel1),
                            tostring(point2),
                            tostring(xOff),
                            tostring(yOff),
                            tostring(pin:IsShown()),
                            tostring(pin.hidden),
                            tostring(pin:GetParent() and pin:GetParent():GetName() or pin:GetParent())
                        ))
                        lastDebugPinPoints[pin] = pointKey
                    end
                end
            else
                pin:Hide()
                data.onEdge = nil
                data.keep = nil
                activeMinimapPins[pin] = nil
            end
        end

        if debugPins then
            local i = 1
            while debugPinIndex < debugLimit and i <= debugDeferredCount do
                local entry = debugDeferredPins[i]
                debugPinIndex = debugPinIndex + 1
                _DebugMinimapPin(entry[1], entry[2], debugPinIndex, x, y, instanceID, entry[3], entry[4], entry[5])
                i = i + 1
            end
            if debugPinIndex == 0 then
                local fallbackIndex = 0
                for pin, data in pairs(minimapPins) do
                    fallbackIndex = fallbackIndex + 1
                    if fallbackIndex > debugLimit then break end
                    _DebugAnyMinimapPin(pin, data, fallbackIndex, "MinimapPinState")
                end
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
        if debugPins then
            print("[QD] QuestieDebugPins complete; set QuestieDebugPins=true again for another one-shot trace.")
        end
    end
end

local function UpdateMinimapIconPosition()
    -- get the current map  zoom
    local zoom = pins.Minimap:GetZoom()
    local diffZoom = zoom ~= lastZoom
    -- if the map zoom changed, run a full update sweep
    if diffZoom then
        UpdateMinimapPins()
        return
    end

    -- we have no active minimap pins, just return early
    if minimapPinCount == 0 then return end

    local x, y = _GetEffectiveMinimapPlayerWorldPosition()

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
        -- update radius of the map
        local viewRadius = _GetMinimapViewRadius()
        if viewRadius then
            mapRadius = viewRadius
        elseif MinimapRadiusAPI then
            mapRadius = C_Minimap.GetViewRadius()
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
        -- update upvalues for icon placement
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
    if not _GetMinimapViewRadius() and not MinimapRadiusAPI then
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
    -- Sunstrider and Eversong share visibility, but 1241 must remain the actual render target.
    local effectiveUiMapID = ResolveZone(uiMapID)
    local effectiveDataUiMapID = ResolveZone(data.uiMapID)
    local sharesSunstriderSpace = (
        (uiMapID == 1241 and data.uiMapID == 1941) or
        (uiMapID == 1941 and data.uiMapID == 1241) or
        (uiMapID == 946 and data.uiMapID == 1241) or
        (uiMapID == 1241 and data.uiMapID == 946) or
        (uiMapID == 946 and data.uiMapID == 1941) or
        (uiMapID == 1941 and data.uiMapID == 946) or
        (effectiveUiMapID == 1941 and effectiveDataUiMapID == 1941 and (uiMapID == 1241 or data.uiMapID == 1241 or uiMapID == 946 or data.uiMapID == 946))
    )
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
    local isSameZoneSpace = (effectiveUiMapID == effectiveDataUiMapID) or sharesSunstriderSpace

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

    -- Sunstrider is small enough that edge-floating objective pins read like
    -- player-following pins. Hide out-of-radius pins instead.
    if uiMapID == 1241 then
        floatOnEdge = false
    end

    self:AddMinimapIconWorld(ref, icon, instanceID, xCoord, yCoord, floatOnEdge)

    -- store extra information
    minimapPins[icon].uiMapID = uiMapID
    minimapPins[icon].showInParentZone = showInParentZone
    -- store original 0-1 zone coords so drawMinimapPin can compute a
    -- zone-space delta without going through world-conversion bounds
    minimapPins[icon].zoneX = x
    minimapPins[icon].zoneY = y
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
