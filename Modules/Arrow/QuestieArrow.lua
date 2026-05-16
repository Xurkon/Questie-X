---@class QuestieArrow
local QuestieArrow = QuestieLoader:CreateModule("QuestieArrow")

---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
---@type QuestieMap
local QuestieMap = QuestieLoader:ImportModule("QuestieMap")
---@type QuestieTracker
local QuestieTracker = QuestieLoader:ImportModule("QuestieTracker")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type QuestiePlayer
local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")
---@type QuestieQuest
local QuestieQuest = QuestieLoader:ImportModule("QuestieQuest")

local HBD = QuestieCompat.HBD or LibStub("HereBeDragonsQuestie-2.0")
local SharedMedia = LibStub and LibStub("LibSharedMedia-3.0", true)

local atan2 = math.atan2
local pi = math.pi
local floor = math.floor
local abs = math.abs
local max = math.max
local min = math.min

local ARROW_SHEET_SIZE = 512
local ARROW_CELL_W = 56
local ARROW_CELL_H = 42
local ARROW_SHEET_COLS = 9
local ARROW_SHEET_ROWS = 12
local ARROW_TOTAL_CELLS = ARROW_SHEET_COLS * ARROW_SHEET_ROWS

local UPDATE_THROTTLE_SECONDS = 0.05
local RECALC_NEAREST_SECONDS = 1.0
local TRACKER_REFRESH_THROTTLE_SECONDS = 0.5

---@type Frame?
local arrowFrame = nil
---@type Frame?
local driverFrame = nil

-- Current auto-tracked targets sorted by distance
local sortedTargets = {}
local hasManualTarget = false

-- Shared context written by UpdateNearestTargets, read by hoisted helpers.
-- Avoids closure allocation on every call.
local _arrow_playerX, _arrow_playerY, _arrow_playerInstance
local _arrow_playerCalibratedX, _arrow_playerCalibratedY, _arrow_playerCalibratedGroup
local _arrow_usingAutoLogic, _arrow_playerZoneId, _arrow_playerUiMapId
local _arrow_quest  -- current quest being processed by the hoisted helpers

local lastPopulateByQuestId = {}

local function _IsArrowEnabled()
    if not Questie or not Questie.db or not Questie.db.profile then
        return true
    end
    return Questie.db.profile.arrowEnabled ~= false
end

local function _GetArrowScale()
    if not Questie or not Questie.db or not Questie.db.profile then
        return 1
    end
    return Questie.db.profile.arrowScale or 1
end

local function _GetArrowAlpha()
    if not Questie or not Questie.db or not Questie.db.profile then
        return 1.0
    end
    return Questie.db.profile.arrowAlpha or 1.0
end

local function _SetArrowScale(scale)
    if not Questie or not Questie.db or not Questie.db.profile then
        return
    end
    Questie.db.profile.arrowScale = scale
end

local function _GetProfilePosition()
    if not Questie or not Questie.db or not Questie.db.profile then
        return nil
    end
    return Questie.db.profile.arrowPosition
end

local function _SaveProfilePosition(point, relativePoint, x, y)
    if not Questie or not Questie.db or not Questie.db.profile then
        return
    end
    Questie.db.profile.arrowPosition = {
        point = point,
        relativePoint = relativePoint,
        x = x,
        y = y,
    }
end

local function modulo(val, by)
    return val - floor(val / by) * by
end

local function GetColorGradient(perc)
    if perc <= 0.5 then
        return 1, perc * 2, 0
    else
        return 2 - perc * 2, 1, 0
    end
end

local function ResolveIconTexture(icon)
    if not icon then
        return nil
    end

    if type(icon) == "string" then
        return icon
    end

    if type(icon) == "number" then
        if Questie and Questie.usedIcons then
            return Questie.usedIcons[icon]
        end
        return nil
    end

    return nil
end

local function _ResolveArrowUiMapId(uiMapId)
    -- Sunstrider Isle (1241) and its ghost map (946) both resolve to Eversong Woods (1941)
    -- for arrow calculations. This normalizes both player and target uiMapIds so the
    -- same-map branch fires and zone-relative coord math works consistently.
    -- NOTE: _ResolveMapUiMapId in QuestieMap.lua also redirects 1241→1941 because
    -- on Ascension, map 1241 shares Eversong's coordinate space. Zone 3430 data
    -- now maps to uiMapId 1941 via GetUiMapIdByAreaId(3430)=1941, so quest items
    -- render on the Eversong map and appear on Sunstrider via ZONE_REDIRECT.
    if uiMapId == 1241 or uiMapId == 946 then
        return 1941
    end
    return uiMapId
end

local function _GetSunstriderPlayerMapPosition(debugArrow)
    local worldX, worldY, _, mapX, mapY, group = QuestieCompat.GetCalibratedPlayerPosition(_arrow_playerUiMapId, _arrow_playerZoneId, "player")
    if group and mapX and mapY then
        if debugArrow then
            print(string.format("Sunstrider helper: calibrated primary=%s -> mapX=%.4f mapY=%.4f worldX=%.1f worldY=%.1f",
                tostring(group.primaryUiMapId), mapX, mapY, worldX or 0, worldY or 0))
        end
        return mapX, mapY
    end

    local mapX2, mapY2

    if QuestieCompat and QuestieCompat.C_Map and QuestieCompat.C_Map.GetPlayerMapPosition then
        -- For local player map coords on Sunstrider, ask for the actual child map (1241).
        -- Asking for parent 1941 returns parent-relative coords (~60/44) which recreates
        -- the classic 433-yard / backwards-arrow bug when compared against Sunstrider-local
        -- target coords (~38/21).
        local mapPos = QuestieCompat.C_Map.GetPlayerMapPosition(1241, "player")
        if type(mapPos) == "table" then
            mapX2, mapY2 = mapPos.x, mapPos.y
            if debugArrow then
                print(string.format("Sunstrider helper: explicit 1241 lookup -> mapX=%.4f mapY=%.4f", mapX2 or 0, mapY2 or 0))
            end
            if mapX2 and mapY2 and mapX2 > 0 and mapY2 > 0 then
                return mapX2, mapY2
            end
        end
    end

    if QuestieCompat and QuestieCompat.GetCurrentPlayerPosition then
        local resolvedUiMapId, compatX, compatY = QuestieCompat.GetCurrentPlayerPosition()
        mapX2, mapY2 = compatX, compatY
        if debugArrow then
            local has1241 = QuestieCompat and QuestieCompat.UiMapData and QuestieCompat.UiMapData[1241] and true or false
            print(string.format("Sunstrider helper: compat current-zone uiMapId=%s mapX=%.4f mapY=%.4f hasUiMap1241=%s",
                tostring(resolvedUiMapId), mapX2 or 0, mapY2 or 0, tostring(has1241)))
        end
        if mapX2 and mapY2 and mapX2 > 0 and mapY2 > 0 then
            return mapX2, mapY2
        end
    end

    mapX2, mapY2 = GetPlayerMapPosition("player")
    return mapX2, mapY2
end

local function _ApplyOutline(fontString)
    if not fontString or not fontString.GetFont or not fontString.SetFont then
        return
    end

    local font, size, flags = fontString:GetFont()
    if not font then
        return
    end

    flags = flags or ""
    if not string.find(flags, "OUTLINE", 1, true) then
        if flags ~= "" then
            flags = flags .. ",OUTLINE"
        else
            flags = "OUTLINE"
        end
    end

    fontString:SetFont(font, size, flags)
end

local function EnsureArrowFrame()
    if arrowFrame then
        -- Apply current scale and alpha settings even if frame already exists
        arrowFrame:SetScale(_GetArrowScale())
        arrowFrame:SetAlpha(_GetArrowAlpha())
        return
    end

    arrowFrame = CreateFrame("Frame", "QuestieArrowFrame", UIParent)

    local pos = _GetProfilePosition()
    if pos and pos.point and pos.relativePoint and pos.x and pos.y then
        arrowFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    else
        arrowFrame:SetPoint("CENTER", 0, -100)
    end

    -- Store whether we should use saved position or default
    arrowFrame._useDefaultPosition = not (pos and pos.point)

    -- Make room for the objective icon below the arrow (no overlap)
    arrowFrame:SetWidth(56)
    arrowFrame:SetHeight(64)
    arrowFrame:SetScale(_GetArrowScale())
    arrowFrame:SetClampedToScreen(true)
    arrowFrame:SetMovable(true)
    arrowFrame:EnableMouse(true)
    arrowFrame:EnableMouseWheel(true)
    arrowFrame:RegisterForDrag("LeftButton")
    arrowFrame:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then
            self:StartMoving()
        end
    end)
    arrowFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()

        local point, _, relativePoint, x, y = self:GetPoint(1)
        if point and relativePoint and x and y then
            _SaveProfilePosition(point, relativePoint, x, y)
        end
    end)

    arrowFrame:SetScript("OnMouseWheel", function(self, delta)
        if not IsShiftKeyDown() then
            return
        end

        local scale = _GetArrowScale() or 1
        local step = 0.05
        if delta and delta > 0 then
            scale = scale + step
        else
            scale = scale - step
        end

        if scale < 0.5 then scale = 0.5 end
        if scale > 2.0 then scale = 2.0 end

        _SetArrowScale(scale)
        self:SetScale(scale)
    end)

    -- Arrow sprite sheet texture (108 cells: 9 columns, 12 rows)
    arrowFrame.arrow = arrowFrame:CreateTexture(nil, "MEDIUM")
    arrowFrame.arrow:SetTexture(QuestieLib.AddonPath .. "Icons\\arrow.tga")
    -- Render at native cell size; use frame scaling if you want it larger.
    arrowFrame.arrow:SetWidth(ARROW_CELL_W)
    arrowFrame.arrow:SetHeight(ARROW_CELL_H)
    arrowFrame.arrow:SetPoint("TOP", arrowFrame, "TOP", 0, 0)
    arrowFrame.arrow:SetTexCoord(0, 0.109375, 0, 0.08203125) -- First cell

    -- Quest icon texture at bottom (pfQuest style)
    arrowFrame.icon = arrowFrame:CreateTexture(nil, "OVERLAY")
    arrowFrame.icon:SetWidth(28)
    arrowFrame.icon:SetHeight(28)
    arrowFrame.icon:SetPoint("BOTTOM", arrowFrame.arrow, "BOTTOM", 0, -20)

    arrowFrame.title = arrowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arrowFrame.title:SetPoint("TOP", arrowFrame.icon, "BOTTOM", 0, -2)
    arrowFrame.title:SetJustifyH("CENTER")
    _ApplyOutline(arrowFrame.title)

    arrowFrame.distance = arrowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arrowFrame.distance:SetPoint("TOP", arrowFrame.title, "BOTTOM", 0, -2)
    arrowFrame.distance:SetJustifyH("CENTER")
    arrowFrame.distance:SetTextColor(1, 1, 1, 1)
    _ApplyOutline(arrowFrame.distance)

    arrowFrame._lastUpdate = 0
    arrowFrame._lastRecalc = 0
    arrowFrame._lastTarget = nil

    -- Right-click to clear manual target and resume auto-tracking
    arrowFrame:EnableMouse(true)
    arrowFrame:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            hasManualTarget = false
            sortedTargets = {}
            QuestieArrow:Refresh()
        end
    end)

arrowFrame:SetScript("OnUpdate", function(self)
        local now = GetTime()

        local target = sortedTargets[1]
        if not target then
            self:Hide()
            return
        end

        if not self:IsShown() then
            self:Show()
        end

        if (self._lastUpdate or 0) + UPDATE_THROTTLE_SECONDS > now then
            return
        end
self._lastUpdate = now

        -- Persistent debug: print every frame so we can see what OnUpdate sees
        local debugArrow = Questie and Questie.db and Questie.db.profile and Questie.db.profile.debugArrow
        if debugArrow then
            print(string.format("QuestieArrow OnUpdate: frameShown=%s target=%s pX=%s pY=%s pInst=%s _playerUiMapId=%s targetUiMapId=%s",
                tostring(self:IsShown()), tostring(target and target.title),
                tostring(_arrow_playerX), tostring(_arrow_playerY), tostring(_arrow_playerInstance),
                tostring(_arrow_playerUiMapId), tostring(target and target.uiMapId)))
        end

local pX, pY, pInst = _arrow_playerX, _arrow_playerY, _arrow_playerInstance
        if not pX or not pY or not pInst then
            -- Fallback to HBD if upvalues aren't set yet
            pX, pY, pInst = HBD:GetPlayerWorldPosition()
        end
        if debugArrow then
            local hbPX, hbPY, hbPInst = HBD:GetPlayerWorldPosition()
            print(string.format("DEBUG PLAYER COMPARE: UnitPos pX=%.1f pY=%.1f | HBD pX=%.1f pY=%.1f | inst=%s",
                pX or 0, pY or 0, hbPX or 0, hbPY or 0, tostring(hbPInst)))
            print(string.format("DEBUG MAP RELATIVE: pX=%.4f pY=%.4f (from _arrow_playerX/Y, UnitPosition world coords)", pX or 0, pY or 0))
            print(string.format("DEBUG OnUpdate: rawUiMapId=%s resolved=%s targetUiMapId=%s", tostring(_arrow_playerUiMapId), tostring(playerUiMapId), tostring(targetUiMapId)))
            print(string.format("DEBUG SPAWN COORDS: target worldX=%.1f worldY=%.1f rawMapX=%.2f rawMapY=%.2f",
                targetX or 0, targetY or 0, rawMapX or 0, rawMapY or 0))
        end
        if not pX or not pY or not pInst then
            local debugArrow = Questie and Questie.db and Questie.db.profile and Questie.db.profile.debugArrow
            if debugArrow then
                print(string.format("QuestieArrow OnUpdate: player position nil (x=%s y=%s inst=%s)", tostring(pX), tostring(pY), tostring(pInst)))
            end
            self.distance:SetText("Distance: --")
            self:Hide()
            return
        end

-- Player's ACTUAL uiMapId (1241 on Sunstrider) vs target's uiMapId.
    -- _arrow_playerUiMapId is the real map the player is on (1241 on Sunstrider).
    -- target.uiMapId is the resolved uiMapId for the spawn (1941 for Sunstrider targets).
    -- Use the player's REAL uiMapId for the same-map check — not the resolved one.
    -- _ResolveArrowUiMapId normalizes both player and target uiMapIds to the same
    -- coordinate system: 1241→1941, 946→1941. This lets the same-map branch work
    -- on Sunstrider Isle where player is on 946 but targets resolve to 1941.
    local playerUiMapId = _ResolveArrowUiMapId(_arrow_playerUiMapId) or 0
    local targetUiMapId = _ResolveArrowUiMapId(target.uiMapId) or 0

        -- Declare world coords outside the branches so they're in scope for direction calc
        local playerWorldX, playerWorldY

-- If target and player are on the same uiMapId, they're in the same instance.
        -- If they're on different maps, we need to compare instances via HBD.
        if playerUiMapId ~= targetUiMapId then
            -- Different maps: just skip instance check since UnitPosition gives us
            -- the real instance — if player and target instances differ, HBD will return
            -- nil for distance anyway. Fall through to direction calc with player coords.
        end

        -- Calculate arrow direction using zone-relative coords when on same map (avoids
        -- world-coordinate mismatch on Sunstrider Isle where player is in EK world space).
        -- For cross-map, fall back to world coords via HBD.
        -- The key insight: on Sunstrider, _arrow_playerX/Y (world EK coords) and target.x/y
        -- (zone coords in Sunstrider space) are incompatible. We use C_Map to get the player's
        -- zone coords in Sunstrider space so they align with target zone coords.
        local targetX, targetY, targetInstance
        local useZoneAngle = false
        local zoneAngle = nil
        local zoneBasedDist = nil
        -- Declare worldPlayerX/Y here so they're in scope for the debug print at line 478
        -- even when the same-map branch takes the zone-relative path (useZoneAngle=true).
        local worldPlayerX, worldPlayerY
        if debugArrow then
            print(string.format("DEBUG BRANCH CHECK: playerUiMapId=%s targetUiMapId=%s sameMap=%s",
                tostring(playerUiMapId), tostring(targetUiMapId),
                tostring(playerUiMapId == targetUiMapId and playerUiMapId ~= 0)))
        end
        if playerUiMapId == targetUiMapId and playerUiMapId ~= 0 then
            -- Same uiMapId on Sunstrider/Eversong: use zone-relative coordinates for BOTH
            -- distance and direction. Mixing player UnitPosition world coords with HBD target
            -- coords recreates the classic 433-yard / backwards-arrow bug.
            local pZoneX, pZoneY = _GetSunstriderPlayerMapPosition(debugArrow)
            local playerZoneX, playerZoneY = pZoneX * 100, pZoneY * 100
            local targetZoneX, targetZoneY = target.x, target.y
            local zoneDist = sqrt((playerZoneX - targetZoneX) ^ 2 + (playerZoneY - targetZoneY) ^ 2)
            -- Eversong/Sunstrider: 100 zone-units ≈ 1353 yards (full map width from HBD bounds)
            local zoneScale = 13.53 -- yards per zone-unit
            zoneBasedDist = zoneDist * zoneScale

            local zoneXDelta = (playerZoneX - targetZoneX) * 1.5
            local zoneYDelta = -(playerZoneY - targetZoneY)
            zoneAngle = atan2(zoneXDelta, -zoneYDelta)
            zoneAngle = zoneAngle > 0 and (pi * 2) - zoneAngle or -zoneAngle
            if zoneAngle < 0 then zoneAngle = zoneAngle + (pi * 2) end

            targetX, targetY, targetInstance = targetZoneX, targetZoneY, 0
            useZoneAngle = true

            if debugArrow then
                local dbg1941x, dbg1941y = HBD:GetZoneCoordinatesFromWorld(pX, pY, 1941, true)
                local dbg1241x, dbg1241y = HBD:GetZoneCoordinatesFromWorld(pX, pY, 1241, true)
                print(string.format("DEBUG SAME_MAP: zoneDist=%.4f zoneYards≈%.1f | pZone(%.2f,%.2f) tZone(%.2f,%.2f) angle=%.2f | world->1941(%.4f,%.4f) world->1241(%.4f,%.4f)",
                    zoneDist, zoneBasedDist, playerZoneX, playerZoneY, targetZoneX, targetZoneY,
                    zoneAngle or 0,
                    (dbg1941x or -1), (dbg1941y or -1),
                    (dbg1241x or -1), (dbg1241y or -1)))
            end
        else
            -- Different maps: convert target to world coords using its uiMapId (works for 1941).
            -- Player is already in world coords from UnitPosition via pX/pY.
            local tWX, tWY, tInst = HBD:GetWorldCoordinatesFromZone(target.x / 100.0, target.y / 100.0, targetUiMapId)
            if tWX and tWY then
                targetX, targetY, targetInstance = tWX, tWY, tInst or pInst or 0
                if debugArrow then
                    print(string.format("DEBUG OnUpdate else-branch: tWX=%.4f tWY=%.4f tInst=%s using HBD", tWX, tWY, tostring(tInst)))
                end
            else
                -- HBD failed: fall back to zone coords (target.x, target.y) for direction only.
                -- Distance will be wrong (zone units instead of yards) but arrow will point correctly.
                targetX, targetY = target.x, target.y
                targetInstance = pInst or 0
                if debugArrow then
                    print(string.format("DEBUG OnUpdate else-branch: HBD failed for target uiMapId=%s, falling back to zone coords (%.2f, %.2f)", tostring(targetUiMapId), targetX, targetY))
                end
            end
        end

        -- If targetX is still nil at this point, bail out
        if not targetX or not targetY then
            self.distance:SetText("Distance: --")
            return
        end

        -- Skip world direction calc when same-map; zoneAngle already computed above
        if useZoneAngle then
            -- zoneAngle already set; apply facing and proceed.
            -- Sunstrider calibrated zone-space currently resolves to the inverse heading
            -- relative to the arrow sprite sheet, so flip by 180 degrees after facing.
            angle = zoneAngle - (GetPlayerFacing and GetPlayerFacing() or 0) + pi
            if angle < 0 then angle = angle + (pi * 2) end
            if angle >= (pi * 2) then angle = angle - (pi * 2) end
        else
            -- Use world coords for direction: both player and target must be in world coordinate space.
            -- UnitPosition("player") gives world coords directly. For same-uiMapId: pX/pY from
            -- UpdateNearestTargets are world coords from UnitPosition — use directly.
            if playerWorldX then
                worldPlayerX, worldPlayerY = playerWorldX, playerWorldY
            else
                worldPlayerX, worldPlayerY = pX, pY
            end

            if not targetX or not targetY then
                self.distance:SetText("Distance: --")
                return
            end

            local xDelta = (worldPlayerX - targetX) * 1.5
            local yDelta = (worldPlayerY - targetY)
            angle = atan2(xDelta, -(yDelta))
            angle = angle > 0 and (pi * 2) - angle or -angle
            if angle < 0 then angle = angle + (pi * 2) end

            angle = angle - (GetPlayerFacing and GetPlayerFacing() or 0)
        end

        -- Calculate color gradient based on direction
        local perc = abs(((pi - abs(angle)) / pi))
        local r, g, b = GetColorGradient(perc)

        -- Select sprite sheet cell
        local cell = modulo(floor(angle / (pi * 2) * ARROW_TOTAL_CELLS + 0.5), ARROW_TOTAL_CELLS)
        local column = modulo(cell, ARROW_SHEET_COLS)
        local row = floor(cell / ARROW_SHEET_COLS)
        local xstart = (column * ARROW_CELL_W) / ARROW_SHEET_SIZE
        local ystart = (row * ARROW_CELL_H) / ARROW_SHEET_SIZE
        local xend = ((column + 1) * ARROW_CELL_W) / ARROW_SHEET_SIZE
        local yend = ((row + 1) * ARROW_CELL_H) / ARROW_SHEET_SIZE

        -- Avoid bleeding from neighboring cells when texture filtering is enabled.
        local padX = 0.5 / ARROW_SHEET_SIZE
        local padY = 0.5 / ARROW_SHEET_SIZE
        xstart = xstart + padX
        ystart = ystart + padY
        xend = xend - padX
        yend = yend - padY

-- Calculate distance and alpha
        -- Override distance with zone-based when same-map (avoids cross-world-system mismatch)
        local dist = nil
        if useZoneAngle and zoneBasedDist then
            dist = zoneBasedDist
        else
            dist = HBD:GetWorldDistance(targetInstance, worldPlayerX, worldPlayerY, targetX, targetY)
        end
        if debugArrow then
            local dbgDist = dist or 0
            local dbgPX = worldPlayerX or 0
            local dbgPY = worldPlayerY or 0
            print(string.format("DEBUG DIST: dist=%s inst=%s pX=%.1f pY=%.1f tX=%.1f tY=%.1f rawMapX=%s rawMapY=%s",
                tostring(dbgDist), tostring(targetInstance),
                dbgPX, dbgPY,
                targetX or 0, targetY or 0,
                tostring(target.x), tostring(target.y)))
        end
        if dist then
            if debugArrow then
                local dbgWorldPX = worldPlayerX or targetX or 0
                local dbgWorldPY = worldPlayerY or targetY or 0
                print(string.format("QuestieArrow OnUpdate: dist=%.1f worldPlayerX=%.1f worldPlayerY=%.1f targetX=%.1f targetY=%.1f targetInst=%s title='%s' rawMapX=%s rawMapY=%s", dist, dbgWorldPX, dbgWorldPY, targetX or 0, targetY or 0, tostring(targetInstance), tostring(target.title), tostring(target.x), tostring(target.y)))
            end
            local area = 1
            local alpha = dist - area
            alpha = alpha > 1 and 1 or alpha
            alpha = alpha < 0.5 and 0.5 or alpha

            local texalpha = (1 - alpha) * 2
            texalpha = texalpha > 1 and 1 or texalpha
            texalpha = texalpha < 0 and 0 or texalpha

            r, g, b = r + texalpha, g + texalpha, b + texalpha

            self.arrow:SetTexCoord(xstart, xend, ystart, yend)
            self.arrow:SetVertexColor(r, g, b)
            self.arrow:SetAlpha(alpha)

            local distText = string.format("%.1f", dist)
            self.distance:SetText("Distance: " .. distText)
        end

        -- Update title and icon when target changes
        if target ~= self._lastTarget then
            self._lastTarget = target

            local title = target.title or ""
            if target.questLevel then
                title = "[" .. target.questLevel .. "] " .. title
            end
            self.title:SetText(Questie:Colorize(title, "gold"))

            if target.iconPath then
                self.icon:SetTexture(target.iconPath)
                self.icon:Show()
            else
                self.icon:Hide()
            end
        end
    end)

    arrowFrame:Hide()
end

local function EnsureDriverFrame()
    if driverFrame then
        return
    end

    driverFrame = CreateFrame("Frame", "QuestieArrowDriverFrame", UIParent)
    driverFrame:Show()
    driverFrame._lastRecalc = 0

    driverFrame:SetScript("OnUpdate", function(self)
        local now = GetTime()
        if (self._lastRecalc or 0) + RECALC_NEAREST_SECONDS < now then
            self._lastRecalc = now
            if not _IsArrowEnabled() then
                if arrowFrame then
                    arrowFrame:Hide()
                end
                return
            end
            QuestieArrow:Refresh()
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Hoisted helpers for UpdateNearestTargets.
-- These were previously closures recreated on every call; now they are
-- module-level functions that read shared upvalue state set each cycle.
-- ---------------------------------------------------------------------------

local function _HasMissingCompletedFlag(list)
    if not list then return false end
    for _, obj in pairs(list) do
        if obj and obj.Completed == nil then
            return true
        end
    end
    return false
end

local function _GetCompleteIconType(quest)
    local iconType = Questie.ICON_TYPE_COMPLETE
    if QuestieDB and QuestieDB.IsActiveEventQuest and QuestieDB.IsActiveEventQuest(quest.Id) then
        iconType = Questie.ICON_TYPE_EVENTQUEST_COMPLETE
    elseif QuestieDB and QuestieDB.IsPvPQuest and QuestieDB.IsPvPQuest(quest.Id) then
        iconType = Questie.ICON_TYPE_PVPQUEST_COMPLETE
    elseif quest.IsRepeatable then
        iconType = Questie.ICON_TYPE_REPEATABLE_COMPLETE
    end
    return iconType
end

local function _CollectFinisherSpawns(finisher, quest)
    if not finisher then return end
    local pX, pY, pInst = _arrow_playerX, _arrow_playerY, _arrow_playerInstance
    local autoLogic, pZone, pMap = _arrow_usingAutoLogic, _arrow_playerZoneId, _arrow_playerUiMapId
    local iconPath = ResolveIconTexture(_GetCompleteIconType(quest))
    if finisher.spawns then
        for finisherZone, spawns in pairs(finisher.spawns) do
            if finisherZone and spawns then
                for _, coords in ipairs(spawns) do
                    if coords and coords[1] and coords[2] then
                        if coords[1] == -1 or coords[2] == -1 then
                            local dungeonLocation = ZoneDB:GetDungeonLocation(finisherZone)
                            if dungeonLocation then
                                for _, value in ipairs(dungeonLocation) do
                                    local zone = value[1]
                                    local x = value[2]
                                    local y = value[3]
                                    -- Zone filtering disabled (zone ID vs area ID mismatch)
                                    if true then
                                        local uiMapId = ZoneDB:GetUiMapIdByAreaId(zone)
                                        if uiMapId and x and y then
                                            local resolvedUiMapId = _ResolveArrowUiMapId(uiMapId)
                                            local tX, tY, tInst = HBD:GetWorldCoordinatesFromZone(x / 100.0, y / 100.0, resolvedUiMapId)
                                            if tX and tY and tInst then
                                                local dist = HBD:GetWorldDistance(tInst, pX, pY, tX, tY)
                                                if dist then
                                                    if tInst ~= pInst then dist = 500000 + dist * 100 end
                                                    table.insert(sortedTargets, {
                                                        x = x, y = y, uiMapId = resolvedUiMapId, title = quest.name, questLevel = quest.level, iconPath = iconPath, distance = dist,
                                                    })
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        else
                            -- Zone filtering disabled (same zone ID vs area ID mismatch issue)
                            if true then
                                local x = coords[1]
                                local y = coords[2]
                                local uiMapId = ZoneDB:GetUiMapIdByAreaId(finisherZone)
                                if uiMapId then
                                    local resolvedUiMapId = _ResolveArrowUiMapId(uiMapId)
                                    local tX, tY, tInst = HBD:GetWorldCoordinatesFromZone(x / 100.0, y / 100.0, resolvedUiMapId)
                                    if tX and tY and tInst then
                                        local dist = HBD:GetWorldDistance(tInst, pX, pY, tX, tY)
                                        if dist then
                                            if tInst ~= pInst then dist = 500000 + dist * 100 end
                                            table.insert(sortedTargets, {
                                                x = x, y = y, uiMapId = resolvedUiMapId, title = quest.name, questLevel = quest.level, iconPath = iconPath, distance = dist,
                                            })
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if finisher.waypoints then
        for zone, waypoints in pairs(finisher.waypoints) do
            -- Zone filtering disabled (same zone ID vs area ID mismatch issue)
            if true then
                if waypoints and waypoints[1] and waypoints[1][1] and waypoints[1][1][1] then
                    local x = waypoints[1][1][1]
                    local y = waypoints[1][1][2]
                    local uiMapId = ZoneDB:GetUiMapIdByAreaId(zone)
                    if uiMapId and x and y then
                        local resolvedUiMapId = _ResolveArrowUiMapId(uiMapId)
                        local tX, tY, tInst = HBD:GetWorldCoordinatesFromZone(x / 100.0, y / 100.0, resolvedUiMapId)
                        if tX and tY and tInst then
                            local dist = HBD:GetWorldDistance(tInst, pX, pY, tX, tY)
                            if dist then
                                if tInst ~= pInst then dist = 500000 + dist * 100 end
                                table.insert(sortedTargets, {
                                    x = x, y = y, uiMapId = resolvedUiMapId, title = quest.name, questLevel = quest.level, iconPath = iconPath, distance = dist,
                                })
                            end
                        end
                    end
                end
            end
        end
    end
end

local function _CollectObjective(objective, quest)
    if not objective or not objective.spawnList then return end
    if QuestieQuest.ShouldHideObjective(objective) then return end
    if objective.Completed == true or objective.Completed == 1 then return end
    if objective.Needed and objective.Collected
        and type(objective.Needed) == "number" and type(objective.Collected) == "number"
        and objective.Collected >= objective.Needed then
        return
    end
    local pX, pY, pInst = _arrow_playerX, _arrow_playerY, _arrow_playerInstance
    local autoLogic, pZone, pMap = _arrow_usingAutoLogic, _arrow_playerZoneId, _arrow_playerUiMapId
    local debugCollect = Questie and Questie.db and Questie.db.profile and Questie.db.profile.debugArrow
    if debugCollect then
        print(string.format("    _CollectObjective: spawnList=%s", objective.spawnList and "yes" or "nil"))
    end
    if not objective.spawnList then return end
    for _, spawnData in pairs(objective.spawnList) do
        if debugCollect then
            print(string.format("      spawnData=%s Spawns=%s", spawnData and "yes" or "nil", spawnData and spawnData.Spawns and "yes" or "nil"))
        end
        if spawnData and spawnData.Spawns then
            for zone, spawns in pairs(spawnData.Spawns) do
                -- Zone filtering is disabled in auto mode because zone IDs and area IDs
                -- are different systems that don't directly compare. The distance
                -- calculation handles instance mismatches.
                local zoneFiltered = false -- Disabled: autoLogic and zone ~= pZone and zone ~= pMap
                if debugCollect then
                    print(string.format("        zone=%s filtered=%s (pZone=%s pMap=%s)", tostring(zone), tostring(zoneFiltered), tostring(pZone), tostring(pMap)))
                end
                if not zoneFiltered then
                    for _, spawn in pairs(spawns) do
                        local uiMapId = ZoneDB:GetUiMapIdByAreaId(zone)
                        if debugCollect then
                            print(string.format("          spawn=(%.1f,%.1f) uiMapId=%s", spawn[1], spawn[2], tostring(uiMapId)))
                        end
                        if uiMapId then
                            local resolvedUiMapId = _ResolveArrowUiMapId(uiMapId)
                            local tX, tY, tInst, calibratedTargetGroup = QuestieCompat.GetCalibratedWorldCoordinatesFromZone(spawn[1] / 100.0, spawn[2] / 100.0, resolvedUiMapId, zone)
                            if tX and tY and tInst then
                                local dist
                                if calibratedTargetGroup and _arrow_playerCalibratedGroup and _arrow_playerCalibratedX and _arrow_playerCalibratedY then
                                    dist = sqrt((_arrow_playerCalibratedX - tX) ^ 2 + (_arrow_playerCalibratedY - tY) ^ 2)
                                else
                                    dist = HBD:GetWorldDistance(tInst, pX, pY, tX, tY)
                                end
                                if dist then
                                    if (not calibratedTargetGroup) and tInst ~= pInst then dist = 500000 + dist * 100 end
                                    if debugCollect then
                                        print(string.format("            ADDED dist=%.0f", dist))
                                    end
                                    table.insert(sortedTargets, {
                                        x = spawn[1], y = spawn[2], uiMapId = resolvedUiMapId,
                                        title = quest.name, questLevel = quest.level,
                                        iconPath = ResolveIconTexture(objective.Icon) or ResolveIconTexture(spawnData and spawnData.Icon),
                                        distance = dist,
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Gather all objectives from tracked quests and sort by distance
function QuestieArrow:UpdateNearestTargets()
    -- Don't override manual targets with auto-updates
    if hasManualTarget then
        return
    end

sortedTargets = {}

    if not Questie.db or not Questie.db.char then
        return
    end

    local debugArrow = Questie and Questie.db and Questie.db.profile and Questie.db.profile.debugArrow

    -- Detect Sunstrider Isle first (before calling HBD) since HBD:GetPlayerWorldPosition()
    -- returns non-nil but WRONG coords on Sunstrider (Eastern Kingdoms position instead of
    -- Sunstrider's actual position), causing the fallback below to never fire.
    local zoneId = QuestiePlayer:GetCurrentZoneId()
    local pUiMapId = QuestiePlayer:GetCurrentUiMapId()

    -- On Sunstrider Isle (areaId 3430, uiMapId 1241), HBD:GetPlayerWorldPosition() returns
    -- Eastern Kingdoms world coords because that's the continent HBD thinks the player is on.
    -- We must use C_Map.GetPlayerMapPosition(1241) + HBD:GetWorldCoordinatesFromZone(..., 1941).
    -- NOTE: GetCurrentUiMapId() returns 946 (ghost map) on Sunstrider, not 1241 or 1941,
    -- so we check zoneId == 3430 as the primary indicator.
    local useSunstriderFix = (zoneId == 3430)

    -- Get player position from the calibrated transform layer first for broken/custom maps.
    local playerX, playerY, playerInstance, calibratedMapX, calibratedMapY, calibratedGroup = QuestieCompat.GetCalibratedPlayerPosition(pUiMapId, zoneId, "player")

    -- Get player position — first try HBD's direct method (works when map is OPEN).
    -- If that returns nil (map closed), fall back to C_Map.GetPlayerMapPosition +
    -- HBD:GetWorldCoordinatesFromZone which works regardless of map open/closed state.
    -- Also skip HBD directly on Sunstrider since it returns wrong coords.
    if useSunstriderFix and calibratedGroup then
        -- already resolved via calibrated transform layer
    elseif not playerX or not playerY or not playerInstance then
        playerX, playerY, playerInstance = HBD:GetPlayerWorldPosition()
    end
    if not playerX or not playerY or not playerInstance then
        -- Fallback: get map-relative position then convert to world coords via HBD.
        -- IMPORTANT: never use 946/947 (world/cosmic maps) — they have no world coord data.
        -- If GetCurrentUiMapId returns a world map, fall back to ZoneDB from the actual zone.
        if not pUiMapId or pUiMapId == 946 or pUiMapId == 947 or pUiMapId == 0 then
            zoneId = QuestiePlayer:GetCurrentZoneId() or select(7, GetInstanceInfo())
            if debugArrow then
                print(string.format("UpdateNearestTargets: pUiMapId=%s (invalid), looking up via zoneId=%s", tostring(pUiMapId), tostring(zoneId)))
            end
            if zoneId then
                pUiMapId = ZoneDB:GetUiMapIdByAreaId(zoneId)
            end
        end
        -- Additional safeguard: if pUiMapId is still a world/cosmic map, force lookup from zone
        if not pUiMapId or pUiMapId == 946 or pUiMapId == 947 or pUiMapId == 0 then
            zoneId = QuestiePlayer:GetCurrentZoneId()
            if zoneId and zoneId ~= 0 then
                pUiMapId = ZoneDB:GetUiMapIdByAreaId(zoneId)
                if debugArrow then
                    print(string.format("UpdateNearestTargets: forced pUiMapId=%s via zoneId=%s", tostring(pUiMapId), tostring(zoneId)))
                end
            end
        end
        pUiMapId = pUiMapId or 0

        -- On Sunstrider Isle (zoneId 3430), C_Map.GetPlayerMapPosition returns Sunstrider
        -- map-space coords. We must look up with the actual Sunstrider uiMapId (1241) and
        -- then convert through Eversong's 1941 bounds to get correct world coords.
        local lookupUiMapId = pUiMapId
        if zoneId == 3430 then
            lookupUiMapId = 1241 -- always use Sunstrider's real uiMapId for C_Map
        end
        if debugArrow then
            print(string.format("UpdateNearestTargets: trying C_Map with lookupUiMapId=%s zoneId=%s", tostring(lookupUiMapId), tostring(zoneId)))
        end

        -- On Sunstrider, raw GetPlayerMapPosition(1941, "player") returns 0/0 when the map is
        -- closed because the client map context is still the ghost/current map. Use the helper
        -- above to obtain current-zone coords, then convert them through Eversong's 1941 bounds.
        local mapX, mapY = _GetSunstriderPlayerMapPosition(debugArrow)
        if debugArrow then
            print(string.format("UpdateNearestTargets: _GetSunstriderPlayerMapPosition() -> mapX=%.4f mapY=%.4f", mapX or -1, mapY or -1))
        end
        if mapX and mapY and mapX > 0 and mapY > 0 then
            if calibratedGroup then
                playerX, playerY, playerInstance = QuestieCompat.GetCalibratedWorldCoordinatesFromZone(mapX, mapY, lookupUiMapId, zoneId)
            else
                local worldUiMapId = 1941 -- always use Eversong bounds for world coord conversion
                playerX, playerY, playerInstance = HBD:GetWorldCoordinatesFromZone(mapX, mapY, worldUiMapId)
            end
            if debugArrow then
                print(string.format("UpdateNearestTargets: HBD via lookupUiMapId=%s mapX=%.4f mapY=%.4f -> worldX=%.4f worldY=%.4f",
                    tostring(lookupUiMapId), mapX, mapY, playerX or 0, playerY or 0))
            end
            playerInstance = playerInstance or 0
        end
    end
    if debugArrow then
            print(string.format("UpdateNearestTargets: HBD.GetPlayerWorldPosition() = x=%.4f y=%.4f inst=%s", playerX or 0, playerY or 0, tostring(playerInstance)))
        end
        if not playerX or not playerY or not playerInstance then
            if debugArrow then
                print("UpdateNearestTargets: player position unavailable, returning early")
            end
            return
        end

    playerInstance = playerInstance or 0

    if debugArrow then
        print(string.format("UpdateNearestTargets: playerX=%.4f playerY=%.4f playerInstance=%s",
            playerX, playerY, tostring(playerInstance)))
    end

    local tracked = Questie.db.char.TrackedQuests or {}
    local hasTracked = next(tracked) ~= nil

    -- Auto mode logic: If autoTrack is on OR NOTHING is tracked
    local usingAutoLogic = Questie.db.profile.autoTrackQuests or not hasTracked
    local playerZoneId = QuestiePlayer:GetCurrentZoneId()
    -- Get a valid uiMapId for the player — needed for _CollectObjective zone filtering.
    -- Use QuestiePlayer which calls C_Map.GetBestMapForUnit — if that returns 947 (wrong)
    -- fall back to ZoneDB from the player's actual zone (areaId).
    local playerUiMapId = QuestiePlayer:GetCurrentUiMapId()
    if not playerUiMapId or playerUiMapId == 947 then
        local zoneId = playerZoneId or select(7, GetInstanceInfo())
        if zoneId then
            playerUiMapId = ZoneDB:GetUiMapIdByAreaId(zoneId) or playerUiMapId
        end
    end
    playerUiMapId = playerUiMapId or 0

    -- Publish context for hoisted helper functions (avoids closure allocation every call)
    _arrow_playerX, _arrow_playerY, _arrow_playerInstance = playerX, playerY, playerInstance
    _arrow_playerCalibratedX, _arrow_playerCalibratedY, _arrow_playerCalibratedGroup = playerX, playerY, calibratedGroup
    _arrow_usingAutoLogic = usingAutoLogic
    _arrow_playerZoneId, _arrow_playerUiMapId = playerZoneId, playerUiMapId

    local function _CollectQuestTargets(quest)
        if not quest then return end

        local debugCollect = Questie and Questie.db and Questie.db.profile and Questie.db.profile.debugArrow

        -- Avoid spamming QuestieQuest:PopulateQuestLogInfo (it can trigger marker rebuilds and flicker).
        -- Only populate when objective completion flags are missing, and throttle per quest id.
        if QuestieQuest and QuestieQuest.PopulateQuestLogInfo and quest.Id then
            local needsPopulate = false
            if not quest.Objectives and not quest.SpecialObjectives then
                needsPopulate = true
            elseif _HasMissingCompletedFlag(quest.Objectives) or _HasMissingCompletedFlag(quest.SpecialObjectives) then
                needsPopulate = true
            end
            if needsPopulate then
                local now = GetTime()
                local last = lastPopulateByQuestId[quest.Id] or 0
                if (last + 2.0) < now then
                    lastPopulateByQuestId[quest.Id] = now
                    QuestieQuest:PopulateQuestLogInfo(quest)
                end
            end
        end

        local isComplete = quest.isComplete or (QuestieDB.IsComplete(quest.Id) == 1)
        if isComplete then quest.isComplete = true end

        if debugCollect then
            print(string.format("  _CollectQuestTargets: %s isComplete=%s hasObjectives=%s hasSpecialObjectives=%s hasFinisher=%s",
                tostring(quest.name), tostring(isComplete),
                tostring(quest.Objectives ~= nil),
                tostring(quest.SpecialObjectives ~= nil),
                tostring(quest.Finisher ~= nil)))
        end

        -- _GetCompleteIconType, _CollectFinisherSpawns, _CollectObjective are hoisted
        -- to module level above; no closures are created here.

        -- Main Logic Route for this quest target
        if isComplete then
            if quest.Finisher and quest.Finisher.Id and quest.Finisher.Type then
                local finisher
                if quest.Finisher.Type == "monster" and QuestieDB and QuestieDB.GetNPC then
                    finisher = QuestieDB:GetNPC(quest.Finisher.Id)
                elseif quest.Finisher.Type == "object" and QuestieDB and QuestieDB.GetObject then
                    finisher = QuestieDB:GetObject(quest.Finisher.Id)
                end
                _CollectFinisherSpawns(finisher, quest)
            end
            -- If the quest is complete, do not add normal objectives to the arrow!
            return
        end

        if quest.Objectives then
            if debugCollect then print(string.format("    Collecting %d objectives", #quest.Objectives)) end
            for _, objective in pairs(quest.Objectives) do
                _CollectObjective(objective, quest)
            end
        else
            if debugCollect then print("    No Objectives") end
        end
        if quest.SpecialObjectives then
            if debugCollect then print(string.format("    Collecting %d special objectives", #quest.SpecialObjectives)) end
            for _, objective in pairs(quest.SpecialObjectives) do
                _CollectObjective(objective, quest)
            end
        end
    end

    if QuestiePlayer and QuestiePlayer.currentQuestlog then
        local debugCollect = Questie and Questie.db and Questie.db.profile and Questie.db.profile.debugArrow
        for questId, quest in pairs(QuestiePlayer.currentQuestlog) do
            if debugCollect then
                print(string.format("Processing questId=%d type=%s", questId, type(quest)))
            end
            if type(quest) == "number" then
                if QuestieDB and QuestieDB.GetQuest then
                    quest = QuestieDB.GetQuest(questId)
                end
            end
            if type(quest) == "table" then
                local shouldTrack = false
                if usingAutoLogic then
                    if not Questie.db.char.AutoUntrackedQuests or not Questie.db.char.AutoUntrackedQuests[questId] then
                        shouldTrack = true
                    end
                else
                    if Questie.db.char.TrackedQuests and Questie.db.char.TrackedQuests[questId] then
                        shouldTrack = true
                    end
                end

                if debugCollect then
                    print(string.format("  questId=%d shouldTrack=%s usingAutoLogic=%s", questId, tostring(shouldTrack), tostring(usingAutoLogic)))
                end

                if shouldTrack then
                    if debugCollect then
                        print(string.format("  Calling _CollectQuestTargets for %s", tostring(quest.name)))
                    end
                    _CollectQuestTargets(quest)
                end
            end
        end
    end

    -- Sort by distance
    table.sort(sortedTargets, function(a, b) return a.distance < b.distance end)
end

function QuestieArrow:Refresh()
    if not _IsArrowEnabled() then
        if arrowFrame then
            arrowFrame:Hide()
        end
        return
    end

    QuestieArrow:UpdateNearestTargets()

    EnsureArrowFrame()

    local alpha = _GetArrowAlpha()
    local scale = _GetArrowScale()
    if arrowFrame then
        arrowFrame:SetAlpha(alpha)
        arrowFrame:SetScale(scale)
    end

    if sortedTargets[1] then
        arrowFrame:Show()
    else
        arrowFrame:Hide()
    end
end

-- Manual target setting (called from tracker TomTom bind)
---@param title string
---@param zoneOrUiMapId number
---@param x number
---@param y number
function QuestieArrow:SetTarget(title, zoneOrUiMapId, x, y)
    if not _IsArrowEnabled() then
        return
    end
    -- For manual targets, insert at front of sorted list
    local uiMapId = ZoneDB:GetUiMapIdByAreaId(zoneOrUiMapId) or zoneOrUiMapId

    hasManualTarget = true
    sortedTargets = { {
        x = x,
        y = y,
        uiMapId = uiMapId,
        title = title,
        distance = 0,     -- Manual targets always go first
    } }

    EnsureArrowFrame()
    arrowFrame:SetAlpha(_GetArrowAlpha())
    arrowFrame:Show()
end

function QuestieArrow:ClearTarget()
    hasManualTarget = false
    sortedTargets = {}

    if arrowFrame then
        arrowFrame:Hide()
    end
end

function QuestieArrow:ResetPosition()
    Questie.db.profile.arrowPosition = nil
    -- Ensure frame exists, then reset to default center position
    EnsureArrowFrame()
    if arrowFrame then
        arrowFrame:ClearAllPoints()
        arrowFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -100)
        arrowFrame._useDefaultPosition = true
    end
end

function QuestieArrow:ApplyScale()
    EnsureArrowFrame()
    if arrowFrame then
        arrowFrame:SetScale(_GetArrowScale())
    end
end

function QuestieArrow:ApplyAlpha()
    EnsureArrowFrame()
    if arrowFrame then
        arrowFrame:SetAlpha(_GetArrowAlpha())
    end
end

function QuestieArrow:UpdateSettings()
    EnsureArrowFrame()
    if arrowFrame then
        arrowFrame:SetScale(_GetArrowScale())
        arrowFrame:SetAlpha(_GetArrowAlpha())
        QuestieArrow:UpdateFont()
    end
end

function QuestieArrow:UpdateFont()
    if not arrowFrame then return end
    local fontSize = Questie.db.profile.arrowFontSize or 10
    local fontName = Questie.db.profile.arrowFont or "Friz Quadrata TT"
    local fontFace = (SharedMedia and SharedMedia.Fetch and SharedMedia:Fetch("font", fontName)) or fontName
    if arrowFrame.title then
        arrowFrame.title:SetFont(fontFace, fontSize, "OUTLINE")
    end
    if arrowFrame.distance then
        arrowFrame.distance:SetFont(fontFace, fontSize - 2, "OUTLINE")
    end
end

function QuestieArrow:Initialize()
    EnsureArrowFrame()

    EnsureDriverFrame()

    -- Refresh immediately on tracker updates (quest progress, objective completion, etc.)
    if QuestieTracker and QuestieTracker.Update and hooksecurefunc then
        local lastTrackerRefresh = 0
        hooksecurefunc(QuestieTracker, "Update", function()
            if hasManualTarget or not _IsArrowEnabled() then
                return
            end

            local now = GetTime()
            if (lastTrackerRefresh + TRACKER_REFRESH_THROTTLE_SECONDS) > now then
                return
            end

            lastTrackerRefresh = now
            QuestieArrow:Refresh()
        end)
    end

    QuestieArrow:Refresh()
end

-- Debug function to show current arrow target coordinates
function QuestieArrow:PrintTargetCoords()
    if not sortedTargets or not sortedTargets[1] then
        print("Questie Arrow: No target currently set!")
        return
    end
    local target = sortedTargets[1]
    print("Questie Arrow Target:")
    print("  Quest: " .. tostring(target.title))
    print("  Level: " .. tostring(target.questLevel))
    print("  Zone Coords: " .. string.format("%.1f, %.1f", target.x, target.y))
    print("  UI Map ID: " .. tostring(target.uiMapId))
    print("  Distance: " .. string.format("%.0f", target.distance))
end

function QuestieArrow:DebugPrint()
    print("=== Questie Arrow Debug ===")
    print("sortedTargets count: " .. tostring(#sortedTargets))
    print("hasManualTarget: " .. tostring(hasManualTarget))
    print("_arrow_usingAutoLogic: " .. tostring(_arrow_usingAutoLogic))
    print("_arrow_playerX: " .. tostring(_arrow_playerX))
    print("_arrow_playerY: " .. tostring(_arrow_playerY))
    print("_arrow_playerZoneId: " .. tostring(_arrow_playerZoneId))
    print("_arrow_playerUiMapId: " .. tostring(_arrow_playerUiMapId))
    if Questie and Questie.db and Questie.db.profile then
        print("autoTrackQuests: " .. tostring(Questie.db.profile.autoTrackQuests))
    end
    if Questie and Questie.db and Questie.db.char then
        local tracked = Questie.db.char.TrackedQuests or {}
        local autoUntracked = Questie.db.char.AutoUntrackedQuests or {}
        local trackedCount = 0
        for _ in pairs(tracked) do trackedCount = trackedCount + 1 end
        local autoUntrackedCount = 0
        for _ in pairs(autoUntracked) do autoUntrackedCount = autoUntrackedCount + 1 end
        print("TrackedQuests count: " .. tostring(trackedCount))
        print("AutoUntrackedQuests count: " .. tostring(autoUntrackedCount))
    end
    if QuestiePlayer and QuestiePlayer.currentQuestlog then
        local count = 0
        for _ in pairs(QuestiePlayer.currentQuestlog) do count = count + 1 end
        print("currentQuestlog count: " .. tostring(count))
    end
    if sortedTargets and #sortedTargets > 0 then
        print("First 3 targets:")
        for i = 1, math.min(3, #sortedTargets) do
            local t = sortedTargets[i]
            print(string.format("  [%d] %s (%.1f, %.1f) dist=%.0f", i, tostring(t.title), t.x, t.y, t.distance))
        end
    end
    print("========================")
end

-- Also expose sortedTargets for external access
function QuestieArrow:GetTargets()
    return sortedTargets
end

-- Hook into Refresh to show debug info when arrow updates
local _OriginalRefresh = QuestieArrow.Refresh
QuestieArrow.Refresh = function(self, ...)
    _OriginalRefresh(self, ...)
    if Questie and Questie.db and Questie.db.profile and Questie.db.profile.debugArrow then
        if sortedTargets and sortedTargets[1] then
            QuestieArrow:PrintTargetCoords()
        end
    end
end
