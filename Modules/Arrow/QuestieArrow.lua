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

-- Single-frame arrow with SetRotation for perfectly smooth rotation.
-- Texture is a 256x256 SQUARE TGA with arrow 2x horizontally stretched to fill
-- ~70% of canvas. SQUARE is critical: SetRotation rotates UVs inside the display
-- rect, so non-square textures distort at every diagonal angle. No SetTexCoord.
local ARROW_DISPLAY_WIDTH = 160
local ARROW_DISPLAY_HEIGHT = 160

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
    -- Ghost map 946 has no real coordinate data; redirect to Eversong (1941).
    -- NOTE: 1241 (Sunstrider Isle) is no longer redirected here - zoneDB now
    -- maps areaId 3431 → uiMapId 1241, and player is on uiMapId 1241, so 1241
    -- stays as 1241 for correct world-coord computation via its own bounds.
    if uiMapId == 946 then
        return 1941
    end
    return uiMapId
end

local function _GetSunstriderPlayerMapPosition(debugArrow)
    -- NEVER use the calibrated branch here. It returns Eversong-wide normalized coords
    -- (~0.60, 0.44) which are in a completely different coordinate space from
    -- Sunstrider-local target coords (~0.38, 0.21). Mixing them causes bogus distances.
    -- Always obtain Sunstrider-local coords via the 1241 map lookup, then convert
    -- through HBD using Eversong bounds (1941) to get real comparable world coords.
    local mapX2, mapY2

    if QuestieCompat and QuestieCompat.C_Map and QuestieCompat.C_Map.GetPlayerMapPosition then
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

    -- Make room for arrow (square) plus icon and text below
    arrowFrame:SetWidth(ARROW_DISPLAY_WIDTH)
    arrowFrame:SetHeight(ARROW_DISPLAY_HEIGHT + 60)
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

    -- Single arrow texture with SetRotation for smooth rotation
    arrowFrame.arrow = arrowFrame:CreateTexture(nil, "MEDIUM")
    arrowFrame.arrow:SetTexture(QuestieLib.AddonPath .. "Icons\\arrow.tga")
    arrowFrame.arrow:SetWidth(ARROW_DISPLAY_WIDTH)
    arrowFrame.arrow:SetHeight(ARROW_DISPLAY_HEIGHT)
    arrowFrame.arrow:SetPoint("CENTER", arrowFrame, "CENTER", 0, 0)
    arrowFrame.arrow:SetRotation(0)  -- 0 = pointing up (north)

    -- Quest icon texture at bottom (pfQuest style)
    arrowFrame.icon = arrowFrame:CreateTexture(nil, "OVERLAY")
    arrowFrame.icon:SetWidth(28)
    arrowFrame.icon:SetHeight(28)
    arrowFrame.icon:SetPoint("BOTTOM", arrowFrame.arrow, "BOTTOM", 0, 0)

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

        local debugArrow = Questie and Questie.db and Questie.db.profile and Questie.db.profile.debugArrow

        local target = sortedTargets[1]

-- -----------------------------------------------------------------
        -- Get fresh player world position every frame for smooth arrow
        -- rotation. UnitPosition updates every frame via HBD, which is
        -- essential — cached values (updated only every 1s) make the
        -- arrow rotate with the character since only GetPlayerFacing()
        -- changes per frame when position is stale.
        -- On Sunstrider, HBD may return Eastern Kingdoms coords. We
        -- detect this and override with the cached corrected position.
        -- -----------------------------------------------------------------
        local playerX, playerY, playerInstance = HBD:GetPlayerWorldPosition()
        if not playerX or not playerY or not playerInstance then
            self.distance:SetText("Distance: --")
            return
        end
        -- On Sunstrider, HBD returns Eastern Kingdoms continent coords
        -- which are outside Eversong bounds. Instead of replacing fresh
        -- per-frame coords with stale 1-second cache, compute fresh
        -- Sunstrider-local coords via C_Map on EVERY frame so that
        -- both position AND facing update per-frame.
        -- PITFALL: zoneId can be 3431 (Eversong) while player is on uiMap 1241 (Sunstrider).
        -- Check both zoneId and cached uiMapId for robust detection.
        local _curZoneId = QuestiePlayer:GetCurrentZoneId()
        local _sunOnUpdate = (_curZoneId == 3430 or _curZoneId == 3431
            or _arrow_playerUiMapId == 1241)
        if _sunOnUpdate then
            local EXMIN, EXMAX, EYMIN, EYMAX = -2000, 3200, 5300, 8700
            if playerX < EXMIN or playerX > EXMAX or playerY < EYMIN or playerY > EYMAX then
                -- Fresh per-frame computation instead of stale cache
                local mapX, mapY = _GetSunstriderPlayerMapPosition(debugArrow)
                if mapX and mapY and mapX > 0 and mapY > 0 then
                    local wX, wY, wInst = HBD:GetWorldCoordinatesFromZone(mapX, mapY, 1241)  -- use Ascension-calibrated 1241 bounds
                    if wX and wY then
                        if debugArrow then
                            print(string.format("OnUpdate: Sunstrider fresh HBD(%.0f,%.0f) -> computed(%.0f,%.0f)",
                                playerX, playerY, wX, wY))
                        end
                        playerX, playerY, playerInstance = wX, wY, wInst or playerInstance
                    elseif _arrow_playerX and _arrow_playerY then
                        -- Last resort: stale cache only if fresh calc fails
                        if debugArrow then
                            print(string.format("OnUpdate: Sunstrider fresh calc FAILED, using stale cache(%.0f,%.0f)",
                                _arrow_playerX, _arrow_playerY))
                        end
                        playerX, playerY, playerInstance = _arrow_playerX, _arrow_playerY, _arrow_playerInstance
                    end
                elseif _arrow_playerX and _arrow_playerY then
                    -- _GetSunstriderPlayerMapPosition failed, stale cache fallback
                    if debugArrow then
                        print(string.format("OnUpdate: Sunstrider map pos failed, using stale cache(%.0f,%.0f)",
                            _arrow_playerX, _arrow_playerY))
                    end
                    playerX, playerY, playerInstance = _arrow_playerX, _arrow_playerY, _arrow_playerInstance
                end
            end
        end

        -- Convert target spawn coords to world coordinates.
        -- Resolve uiMapId again here as a safety net for targets that may
        -- have raw custom map IDs (1241) bypassing PopulateTargets resolution.
        local targetUiMapId = _ResolveArrowUiMapId(target.uiMapId)
        -- On Sunstrider, convert target through Ascension-calibrated 1241 bounds
        -- so target world coords match player world coords (both through 1241).
        -- PITFALL: zoneId can be 3431 while player is on uiMap 1241.
        if _sunOnUpdate and targetUiMapId == 1941 then
            targetUiMapId = 1241
        end
        local targetX, targetY, targetInstance = HBD:GetWorldCoordinatesFromZone(target.x / 100.0, target.y / 100.0, targetUiMapId)
        if not targetX or not targetY or not targetInstance then
            self.distance:SetText("Distance: --")
            return
        end

        if targetInstance ~= playerInstance then
            self:Hide()
            return
        end

        -- Arrow direction from pure world-coordinate math.
        -- HBD world coords: X decreases going EAST (more negative = more west).
        --                    Y increases going NORTH (larger = more north).
        -- GetPlayerFacing: 0=North, π/2=East, π=South, 3π/2=West (CW from N).
        -- SetRotation(r): rotates texture CW (positive = clockwise).
        -- Arrow image tip is at TOP of file → points UP at SetRotation(0).
        --
        -- dx = targetX - playerX:
        --   targetX > playerX (numerically) → target LESS negative → target EAST
        --   So dx>0 = target EAST of player
        -- dy = targetY - playerY:
        --   targetY > playerY → target MORE north
        --   So dy>0 = target NORTH of player
        --
        -- Bearing CW from North: atan2(dx, dy)
        --   N: dx=0, dy>0  → atan2(0,+) = 0
        --   E: dx>0, dy=0  → atan2(+,0) = π/2
        --   S: dx=0, dy<0  → atan2(0,-) = π
        --   W: dx<0, dy=0  → atan2(-,0) = -π/2 → 3π/2
        --
        -- Screen direction relative to facing:
        --   relative = bearing - facing  (0 = target ahead)
        --
        -- SetRotation wants CW; relative is CW: use it directly.
        --   SetRotation(relative) → arrow points at target on screen.
        local dx = targetX - playerX
        local dy = targetY - playerY
        local bearing = atan2(dx, dy)
        if bearing < 0 then bearing = bearing + (pi * 2) end
        local facing = GetPlayerFacing and GetPlayerFacing() or 0
        local relative = bearing - facing
        if relative < 0 then relative = relative + (pi * 2) end
        local rotAngle = relative  -- CW rotation for SetRotation

        if debugArrow then
            print(string.format("QuestieArrow OnUpdate: target=%s pX=%.1f pY=%.1f tX=%.1f tY=%.1f dx=%.1f dy=%.1f bearing=%.2f facing=%.2f relative=%.2f rotAng=%.2f inst=%s",
                tostring(target.title), playerX, playerY, targetX, targetY, dx, dy, bearing, facing, relative, rotAngle, tostring(playerInstance)))
        end

        -- Calculate distance and alpha
        local dist = HBD:GetWorldDistance(targetInstance, playerX, playerY, targetX, targetY)
        if dist then
            local area = 1
            local alpha = dist - area
            alpha = alpha > 1 and 1 or alpha
            alpha = alpha < 0.5 and 0.5 or alpha

            local texalpha = (1 - alpha) * 2
            texalpha = texalpha > 1 and 1 or texalpha
            texalpha = texalpha < 0 and 0 or texalpha

            self.arrow:SetRotation(rotAngle)
            self.arrow:SetVertexColor(1, 1, 1)
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
    -- On Sunstrider, force target conversion through 1241 bounds to match player coords
    local sunOverride = (pMap == 1241)
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
                                            if sunOverride and resolvedUiMapId == 1941 then resolvedUiMapId = 1241 end
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
                                if sunOverride and resolvedUiMapId == 1941 then resolvedUiMapId = 1241 end
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
                        if sunOverride and resolvedUiMapId == 1941 then resolvedUiMapId = 1241 end
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
    if not objective or not objective.spawnList then
        -- spawnList can be nil if _TryInvalidateObjective cleared it (QuestieLearner
        -- learned new data) but the rebuild via UpdateQuest hasn't happened yet, or if
        -- stale quest.isComplete prevented PopulateObjective from rebuilding it.
        -- Proactively trigger UpdateQuest to rebuild the spawnList for this quest.
        if quest and quest.Id and QuestieQuest and QuestieQuest.UpdateQuest then
            local dbComplete = QuestieDB.IsComplete(quest.Id)
            -- Only request rebuild if quest is NOT complete in the DB
            if dbComplete ~= 1 and not quest.isComplete then
                local now = GetTime()
                local last = lastPopulateByQuestId[quest.Id] or 0
                -- Throttle rebuilds to every 5 seconds per quest
                if (last + 5.0) < now then
                    lastPopulateByQuestId[quest.Id] = now
                    Questie:Debug(Questie.DEBUG_DEVELOP, "[Arrow] _CollectObjective: spawnList nil for quest", quest.Id, "- triggering UpdateQuest rebuild")
                    QuestieQuest:UpdateQuest(quest.Id)
                end
            end
        end
        if debugCollect then
            print(string.format("    _CollectObjective SKIP: obj=%s spawnList=%s (quest=%s)",
                tostring(objective), objective and tostring(objective.spawnList) or "nil", quest and tostring(quest.name) or "?"))
        end
        return
    end
    if QuestieQuest.ShouldHideObjective(objective) then return end
    if objective.Completed == true or objective.Completed == 1 then
        if debugCollect then
            print(string.format("    _CollectObjective SKIP: Completed=%s (quest=%s)", tostring(objective.Completed), quest and tostring(quest.name) or "?"))
        end
        return
    end
    if objective.Needed and objective.Collected
        and type(objective.Needed) == "number" and type(objective.Collected) == "number"
        and objective.Collected >= objective.Needed then
        return
    end
    local pX, pY, pInst = _arrow_playerX, _arrow_playerY, _arrow_playerInstance
    local autoLogic, pZone, pMap = _arrow_usingAutoLogic, _arrow_playerZoneId, _arrow_playerUiMapId
    -- On Sunstrider, force target conversion through 1241 bounds to match player coords
    local sunOverride = (pMap == 1241)
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
                            if sunOverride and resolvedUiMapId == 1941 then resolvedUiMapId = 1241 end
                            local tX, tY, tInst = HBD:GetWorldCoordinatesFromZone(spawn[1] / 100.0, spawn[2] / 100.0, resolvedUiMapId)
                            if tX and tY and tInst then
                                local dist = HBD:GetWorldDistance(tInst, pX, pY, tX, tY)
                                if dist then
                                    if tInst ~= pInst then dist = 500000 + dist * 100 end
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
    -- NOTE: GetCurrentUiMapId() returns 1241 on Sunstrider Isle (not 946 or 1941).
    -- PITFALL: zoneId can be 3431 (Eversong) while player is on uiMap 1241 (Sunstrider).
    local useSunstriderFix = (zoneId == 3430 or zoneId == 3431 or pUiMapId == 1241)

    -- Get player position — always try HBD's direct method first (works when map is OPEN).
    -- If that returns nil (map closed or Sunstrider), fall back to C_Map.GetPlayerMapPosition +
    -- HBD:GetWorldCoordinatesFromZone which works regardless of map open/closed state.
    local playerX, playerY, playerInstance = HBD:GetPlayerWorldPosition()
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
        if zoneId == 3430 or zoneId == 3431 or pUiMapId == 1241 then
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
            if useSunstriderFix then
                -- Sunstrider: use 1941 (Eversong) for coordinate conversion so that
                -- player world coords are in the same space as target world coords.
                -- Targets always use 1941 (via ZoneDB:GetUiMapIdByAreaId(3430)→1941),
                -- so the player must also use 1941 for consistent distance/direction.
                -- Ascension-calibrated 1241 bounds now match Eversong world space.
                playerX, playerY, playerInstance = HBD:GetWorldCoordinatesFromZone(mapX, mapY, 1241)
            else
                -- Normal zone: convert the player's map coords through the ACTUAL zone's
                -- uiMapId bounds. This was hardcoded to 1941 in the original Sunstrider fix,
                -- which broke every zone except Eversong.
                playerX, playerY, playerInstance = HBD:GetWorldCoordinatesFromZone(mapX, mapY, lookupUiMapId)
            end
            if debugArrow then
                print(string.format("UpdateNearestTargets: HBD via lookupUiMapId=%s mapX=%.4f mapY=%.4f -> worldX=%.4f worldY=%.4f",
                    tostring(lookupUiMapId), mapX, mapY, playerX or 0, playerY or 0))
            end
            playerInstance = playerInstance or 0
        end
    end
    -- Sunstrider override: HBD:GetPlayerWorldPosition() may return incorrect
    -- (Eastern Kingdoms offset) coords on Sunstrider Isle. Only override if
    -- the HBD coords appear wrong — specifically, if they fall outside the
    -- Eversong bounding box. Eversong world bounds: X ∈ [-1825, 3100],
    -- Y ∈ [5358, 8642]. If HBD coords are outside this range, they're EK coords.
    -- NOTE: _GetSunstriderPlayerMapPosition returns 1241-local normalized coords.
    -- We convert through 1941 (Eversong) so that player world coords share the
    -- same coordinate space as targets (which always use uiMapId 1941 via ZoneDB).
    if useSunstriderFix and playerX and playerY then
        -- Eversong bounding box in world coordinates (with some margin).
        -- A player on Sunstrider/Eversong should be within these bounds.
local EVERSENG_XMIN, EVERSENG_XMAX = -2000, 3200
        local EVERSENG_YMIN, EVERSENG_YMAX = 5300, 8700
        local coordsOutsideEversong = (playerX < EVERSENG_XMIN or playerX > EVERSENG_XMAX
            or playerY < EVERSENG_YMIN or playerY > EVERSENG_YMAX)
        if debugArrow then
            print(string.format("UpdateNearestTargets: Sunstrider check outsideEv=%s px=%.0f py=%.0f bounds=[%d..%d,%d..%d]",
                tostring(coordsOutsideEversong), playerX, playerY,
                EVERSENG_XMIN, EVERSENG_XMAX, EVERSENG_YMIN, EVERSENG_YMAX))
        end
        if coordsOutsideEversong then
            local mapX, mapY = _GetSunstriderPlayerMapPosition(debugArrow)
            if debugArrow then
                print(string.format("UpdateNearestTargets: Sunstrider mapPos mapX=%.4f mapY=%.4f", mapX or -1, mapY or -1))
            end
            if mapX and mapY and mapX > 0 and mapY > 0 then
                -- Use Ascension-calibrated 1241 bounds for consistent world space.
                local wX, wY, wInst = HBD:GetWorldCoordinatesFromZone(mapX, mapY, 1241)
                if debugArrow then
                    print(string.format("UpdateNearestTargets: Sunstrider HBD1941 wX=%s wY=%s wInst=%s", tostring(wX), tostring(wY), tostring(wInst)))
                end
                if wX and wY then
                    if debugArrow then
                        print(string.format("UpdateNearestTargets: Sunstrider override HBD(%.4f,%.4f) -> HBD1941(%.4f,%.4f)", playerX, playerY, wX, wY))
                    end
                    playerX, playerY, playerInstance = wX, wY, wInst or 0
                else
                    -- HBD 1941 conversion failed — no fallback available.
                    if debugArrow then
                        print("UpdateNearestTargets: Sunstrider HBD1941 conversion FAILED")
                    end
                end
            end
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
    _arrow_usingAutoLogic = usingAutoLogic
    _arrow_playerZoneId, _arrow_playerUiMapId = playerZoneId, playerUiMapId

    

    local function _CollectQuestTargets(quest)
        if not quest then return end

        local debugCollect = Questie and Questie.db and Questie.db.profile and Questie.db.profile.debugArrow

        -- Periodic quest state verification: call PopulateQuestLogInfo when
        --   (a) objectives/completion flags are missing (original logic), OR
        --   (b) the quest hasn't been populated in the last 30 seconds
        --   (c) quest.isComplete is stale (does not match DB)
        -- This ensures the arrow always has accurate completion data, catching
        -- cases where events didn't fire or stale flags survived a reload.
        if QuestieQuest and QuestieQuest.PopulateQuestLogInfo and quest.Id then
            local needsPopulate = false
            if not quest.Objectives and not quest.SpecialObjectives then
                needsPopulate = true
            elseif _HasMissingCompletedFlag(quest.Objectives) or _HasMissingCompletedFlag(quest.SpecialObjectives) then
                needsPopulate = true
            end

            -- Periodic force-refresh: if more than 30 seconds since last populate, re-sync
            -- quest state from live quest log. This catches stale isComplete/WasComplete
            -- that survived event-driven updates (e.g., Ascension missing QUEST_LOG_UPDATE).
            local now = GetTime()
            local last = lastPopulateByQuestId[quest.Id] or 0
            if (last + 30.0) < now then
                needsPopulate = true
            end

            if needsPopulate then
                if (last + 2.0) < now then
                    lastPopulateByQuestId[quest.Id] = now
                    QuestieQuest:PopulateQuestLogInfo(quest)
                end
            end
        end

        local dbComplete = QuestieDB.IsComplete(quest.Id)
        -- Defensive: if quest.isComplete is stale from a prior complete-then-abandon, and
        -- QuestLogCache says the quest is NOT complete (0 or nil), clear the stale flag so
        -- objective pins are drawn. AcceptQuest normally resets this, but this guards
        -- against edge cases where AcceptQuest's reset didn't fire.
        if quest.isComplete and dbComplete ~= 1 then
            quest.isComplete = nil
        end
        local isComplete = quest.isComplete or (dbComplete == 1)

        if debugCollect then
            local objCount = quest.Objectives and #quest.Objectives or 0
            print(string.format("  _CollectQuestTargets: %s isComplete=%s (quest.isComplete=%s dbComplete=%s) objCount=%d hasObjectives=%s hasSpecialObjectives=%s hasFinisher=%s",
                tostring(quest.name), tostring(isComplete),
                tostring(quest.isComplete), tostring(dbComplete),
                objCount,
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
