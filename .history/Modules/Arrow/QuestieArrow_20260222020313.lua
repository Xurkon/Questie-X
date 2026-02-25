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
        return
    end

    arrowFrame = CreateFrame("Frame", "QuestieArrowFrame", UIParent)

    local pos = _GetProfilePosition()
    if pos and pos.point and pos.relativePoint and pos.x and pos.y then
        arrowFrame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    else
        arrowFrame:SetPoint("CENTER", 0, -100)
    end

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

        local playerX, playerY, playerInstance = HBD:GetPlayerWorldPosition()
        if not playerX or not playerY or not playerInstance then
            self.distance:SetText("Distance: --")
            return
        end

        local targetX, targetY, targetInstance = HBD:GetWorldCoordinatesFromZone(target.x / 100.0, target.y / 100.0,
            target.uiMapId)
        if not targetX or not targetY or not targetInstance then
            self.distance:SetText("Distance: --")
            return
        end

        if targetInstance ~= playerInstance then
            self:Hide()
            return
        end

        -- Calculate arrow direction using pfQuest's method, but in world coordinates
        -- (map coordinates break when the target is in a different zone)
        local xDelta = (playerX - targetX) * 1.5
        local yDelta = (playerY - targetY)
        local angle = atan2(xDelta, -(yDelta))
        angle = angle > 0 and (pi * 2) - angle or -angle
        if angle < 0 then angle = angle + (pi * 2) end

        local player = GetPlayerFacing and GetPlayerFacing() or 0
        angle = angle - player

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
        local dist = HBD:GetWorldDistance(targetInstance, playerX, playerY, targetX, targetY)
        if dist then
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

    local playerX, playerY, playerInstance = HBD:GetPlayerWorldPosition()
    if not playerX or not playerY or not playerInstance then
        return
    end

    local tracked = Questie.db.char.TrackedQuests or {}
    local hasTracked = next(tracked) ~= nil

    -- Auto mode logic: If autoTrack is on OR NOTHING is tracked
    local usingAutoLogic = Questie.db.profile.autoTrackQuests or not hasTracked
    local playerZoneId = QuestiePlayer:GetCurrentZoneId()

    local function _CollectQuestTargets(quest)
        if not quest then
            return
        end

        -- Avoid spamming QuestieQuest:PopulateQuestLogInfo (it can trigger marker rebuilds and flicker).
        -- Only populate when objective completion flags are missing, and throttle per quest id.
        if QuestieQuest and QuestieQuest.PopulateQuestLogInfo and quest.Id then
            local needsPopulate = false

            if not quest.Objectives and not quest.SpecialObjectives then
                needsPopulate = true
            else
                local function _HasMissingCompletedFlag(list)
                    if not list then return false end
                    for _, obj in pairs(list) do
                        if obj and obj.Completed == nil then
                            return true
                        end
                    end
                    return false
                end

                if _HasMissingCompletedFlag(quest.Objectives) or _HasMissingCompletedFlag(quest.SpecialObjectives) then
                    needsPopulate = true
                end
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
        if isComplete then
            quest.isComplete = true
        end

        local function _GetCompleteIconType()
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

        local function _CollectFinisherSpawns(finisher)
            if not finisher then
                return
            end

            local iconPath = ResolveIconTexture(_GetCompleteIconType())

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
                                            -- Auto Logic: Hide distant quests (different zone)
                                            if not (usingAutoLogic and zone ~= playerZoneId) then
                                                local uiMapId = ZoneDB:GetUiMapIdByAreaId(zone)
                                                if uiMapId and x and y then
                                                    local targetX, targetY, targetInstance = HBD:GetWorldCoordinatesFromZone(x / 100.0, y / 100.0, uiMapId)
                                                    if targetX and targetY and targetInstance then
                                                        local dist = HBD:GetWorldDistance(targetInstance, playerX, playerY, targetX, targetY)
                                                        if dist then
                                                            if targetInstance ~= playerInstance then
                                                                dist = 500000 + dist * 100
                                                            end
                                                            table.insert(sortedTargets, {
                                                                x = x, y = y, uiMapId = uiMapId, title = quest.name, questLevel = quest.level, iconPath = iconPath, distance = dist,
                                                            })
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                else
                                    -- Auto Logic: Hide distant quests (different zone)
                                    if not (usingAutoLogic and finisherZone ~= playerZoneId) then
                                        local x = coords[1]
                                        local y = coords[2]
                                        local uiMapId = ZoneDB:GetUiMapIdByAreaId(finisherZone)
                                        if uiMapId then
                                            local targetX, targetY, targetInstance = HBD:GetWorldCoordinatesFromZone(x / 100.0, y / 100.0, uiMapId)
                                            if targetX and targetY and targetInstance then
                                                local dist = HBD:GetWorldDistance(targetInstance, playerX, playerY, targetX, targetY)
                                                if dist then
                                                    if targetInstance ~= playerInstance then
                                                        dist = 500000 + dist * 100
                                                    end
                                                    table.insert(sortedTargets, {
                                                        x = x, y = y, uiMapId = uiMapId, title = quest.name, questLevel = quest.level, iconPath = iconPath, distance = dist,
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
                    -- Auto Logic: Hide distant quests (different zone)
                    if not (usingAutoLogic and zone ~= playerZoneId) then
                        if waypoints and waypoints[1] and waypoints[1][1] and waypoints[1][1][1] then
                            local x = waypoints[1][1][1]
                            local y = waypoints[1][1][2]
                            local uiMapId = ZoneDB:GetUiMapIdByAreaId(zone)
                            if uiMapId and x and y then
                                local targetX, targetY, targetInstance = HBD:GetWorldCoordinatesFromZone(x / 100.0, y / 100.0, uiMapId)
                                if targetX and targetY and targetInstance then
                                    local dist = HBD:GetWorldDistance(targetInstance, playerX, playerY, targetX, targetY)
                                    if dist then
                                        if targetInstance ~= playerInstance then
                                            dist = 500000 + dist * 100
                                        end
                                        table.insert(sortedTargets, {
                                            x = x, y = y, uiMapId = uiMapId, title = quest.name, questLevel = quest.level, iconPath = iconPath, distance = dist,
                                        })
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        local function _CollectObjective(objective)
            if not objective or not objective.spawnList then
                return
            end

            if QuestieQuest.ShouldHideObjective(objective) then
                return
            end

            if objective.Completed == true or objective.Completed == 1 then
                return
            end

            -- If the objective is numerically fulfilled but the server hasn't sent the Completed flag yet
            if objective.Needed and objective.Collected and type(objective.Needed) == "number" and type(objective.Collected) == "number" then
                if objective.Collected >= objective.Needed then
                    return
                end
            end

            for _, spawnData in pairs(objective.spawnList) do
                if spawnData and spawnData.Spawns then
                    for zone, spawns in pairs(spawnData.Spawns) do
                        -- Auto Logic: Hide distant quests (different zone)
                        if not (usingAutoLogic and zone ~= playerZoneId) then
                            for _, spawn in pairs(spawns) do
                                local uiMapId = ZoneDB:GetUiMapIdByAreaId(zone)
                                if uiMapId then
                                    local targetX, targetY, targetInstance = HBD:GetWorldCoordinatesFromZone(spawn[1] / 100.0, spawn[2] / 100.0, uiMapId)
                                    if targetX and targetY and targetInstance then
                                        local dist = HBD:GetWorldDistance(targetInstance, playerX, playerY, targetX, targetY)
                                        if dist then
                                            if targetInstance ~= playerInstance then
                                                dist = 500000 + dist * 100
                                            end
                                            table.insert(sortedTargets, {
                                                x = spawn[1], y = spawn[2], uiMapId = uiMapId, title = quest.name, questLevel = quest.level,
                                                iconPath = ResolveIconTexture(objective.Icon) or ResolveIconTexture(spawnData and spawnData.Icon), distance = dist,
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

        -- Main Logic Route for this quest target
        if isComplete then
            if quest.Finisher and quest.Finisher.Id and quest.Finisher.Type then
                local finisher
                if quest.Finisher.Type == "monster" and QuestieDB and QuestieDB.GetNPC then
                    finisher = QuestieDB:GetNPC(quest.Finisher.Id)
                elseif quest.Finisher.Type == "object" and QuestieDB and QuestieDB.GetObject then
                    finisher = QuestieDB:GetObject(quest.Finisher.Id)
                end
                
                _CollectFinisherSpawns(finisher)
            end
            -- If the quest is complete, do not add normal objectives to the arrow!
            return
        end

        if quest.Objectives then
            for _, objective in pairs(quest.Objectives) do
                _CollectObjective(objective)
            end
        end
        if quest.SpecialObjectives then
            for _, objective in pairs(quest.SpecialObjectives) do
                _CollectObjective(objective)
            end
        end
    end

    if QuestiePlayer and QuestiePlayer.currentQuestlog then
        for questId, quest in pairs(QuestiePlayer.currentQuestlog) do
            if type(quest) == "table" then
                local shouldTrack = false
                if usingAutoLogic then
                    -- If using auto logic (implicit or explicit), verify not explicitly hidden
                    if not Questie.db.char.AutoUntrackedQuests[questId] then
                        shouldTrack = true
                    end
                else
                    -- Strict manual tracking
                    if Questie.db.char.TrackedQuests[questId] then
                        shouldTrack = true
                    end
                end

                if shouldTrack then
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

    if hasManualTarget then
        EnsureArrowFrame()
        arrowFrame:Show()
        return
    end

    QuestieArrow:UpdateNearestTargets()

    EnsureArrowFrame()
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
    arrowFrame:Show()
end

function QuestieArrow:ClearTarget()
    hasManualTarget = false
    sortedTargets = {}

    if arrowFrame then
        arrowFrame:Hide()
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

-- Also expose sortedTargets for external access
function QuestieArrow:GetTargets()
    return sortedTargets
end

-- Hook into Refresh to show debug info when arrow updates
local _OriginalRefresh = QuestieArrow.Refresh
QuestieArrow.Refresh = function(self, ...)
    _OriginalRefresh(self, ...)
    -- You can uncomment the line below to see debug output every refresh:
    -- QuestieArrow:PrintTargetCoords()
end
