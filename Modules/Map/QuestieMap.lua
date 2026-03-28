---@class QuestieMap
local QuestieMap = QuestieLoader:CreateModule("QuestieMap");
---@type QuestieMapUtils
QuestieMap.utils = QuestieMap.utils or {}

-------------------------
--Import modules.
-------------------------
---@type QuestieFramePool
local QuestieFramePool = QuestieLoader:ImportModule("QuestieFramePool");
---@type QuestieDBMIntegration
local QuestieDBMIntegration = QuestieLoader:ImportModule("QuestieDBMIntegration");
---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib");
---@type QuestiePlayer
local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer");
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB");
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")
---@type WeaponMasterSkills
local WeaponMasterSkills = QuestieLoader:ImportModule("WeaponMasterSkills")

--- COMPATIBILITY ---
local C_Timer = QuestieCompat.C_Timer
local C_Map = QuestieCompat.C_Map

QuestieMap.ICON_MAP_TYPE = "MAP";
QuestieMap.ICON_MINIMAP_TYPE = "MINIMAP";

-- List of frames sorted by quest ID (automatic notes)
-- E.g. {[questId] = {[frameName] = frame, ...}, ...}
QuestieMap.questIdFrames = {}
-- List of frames sorted by NPC/object ID (manual notes)
-- id > 0: NPC
-- id < 0: object
-- E.g. {[-objectId] = {[frameName] = frame, ...}, ...}
QuestieMap.manualFrames = {}

--Used in my fadelogic.
local fadeOverDistance = 10;
local normalizedValue = 1 / fadeOverDistance;

local HBD = QuestieCompat.HBD or LibStub("HereBeDragonsQuestie-2.0")
local HBDPins = QuestieCompat.HBDPins or LibStub("HereBeDragonsQuestie-Pins-2.0")

local tostring = tostring;
local tinsert = table.insert;
local pairs = pairs;
local ipairs = ipairs;
local tremove = table.remove;
local tunpack = unpack;

local drawTimer
local fadeLogicTimerShown
local fadeLogicCoroutine

local isDrawQueueDisabled = false

--* TODO: How the frames are handled needs to be reworked, why are we getting them from _G
--Get the frames for a quest, this returns all of the frames
function QuestieMap:GetFramesForQuest(questId)
    local frames = {}
    if QuestieMap.questIdFrames[questId] then
        for _, name in pairs(QuestieMap.questIdFrames[questId]) do
            if _G[name] then
                frames[name] = _G[name]
            end
        end
    end
    return frames
end

function QuestieMap:UnloadQuestFrames(questId, iconType)
    if QuestieMap.questIdFrames[questId] then
        if not iconType then
            for _, frame in pairs(QuestieMap:GetFramesForQuest(questId)) do
                frame:Unload();
            end
            QuestieMap.questIdFrames[questId] = nil;
        else
            for name, frame in pairs(QuestieMap:GetFramesForQuest(questId)) do
                if frame and frame.data and frame.data.Icon == iconType then
                    frame:Unload();
                    QuestieMap.questIdFrames[questId][name] = nil
                    _G[name] = nil
                end
            end
        end
        Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieMap] Unloading quest frames for questid:", questId)
    end
end

--Get the frames for manual note, this returns all of the frames/spawns
---@param id number @The ID of the NPC (>0) or object (<0)
function QuestieMap:GetManualFrames(id, typ)
    typ = typ or "any"
    local frames = {}
    if QuestieMap.manualFrames[typ] and (QuestieMap.manualFrames[typ][id]) then
        for _, name in pairs(QuestieMap.manualFrames[typ][id]) do
            tinsert(frames, _G[name])
        end
    end
    return frames
end

---@param id number @The ID of the NPC (>0) or object (<0)
function QuestieMap:UnloadManualFrames(id, typ)
    typ = typ or "any"
    if QuestieMap.manualFrames[typ] and (QuestieMap.manualFrames[typ][id]) then
        for _, frame in ipairs(QuestieMap:GetManualFrames(id, typ)) do
            frame:Unload();
        end
        QuestieMap.manualFrames[typ][id] = nil;
    end
end

function QuestieMap:ResetManualFrames(typ)
    typ = typ or "any"
    if QuestieMap.manualFrames[typ] then
        for id in pairs(QuestieMap.manualFrames[typ]) do
            QuestieMap:UnloadManualFrames(id, typ)
        end
    end
end

-- Rescale all the icons
function QuestieMap:RescaleIcons()
    local mapScale = QuestieMap.GetScaleValue()
    for _, framelist in pairs(QuestieMap.questIdFrames) do
        for _, frameName in pairs(framelist) do
            QuestieMap.utils:RescaleIcon(frameName, mapScale)
        end
    end
    for _, frameTypeList in pairs(QuestieMap.manualFrames) do
        for _, framelist in pairs(frameTypeList) do
            for _, frameName in ipairs(framelist) do
                QuestieMap.utils:RescaleIcon(frameName, mapScale)
            end
        end
    end
end

local mapDrawQueue = {};
local minimapDrawQueue = {};

QuestieMap._mapDrawQueue = mapDrawQueue
QuestieMap._minimapDrawQueue = minimapDrawQueue

--- Called at startup (Stage 3) and on PLAYER_ENTERING_WORLD to reset the draw queue.
function QuestieMap:InitializeQueue()
    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieMap] Starting draw queue timer!")
    local isInInstance, instanceType = IsInInstance()

    if (not isInInstance) or instanceType ~= "raid" then
        isDrawQueueDisabled = false
        if not drawTimer then
            drawTimer = C_Timer.NewTicker(0.2, QuestieMap.ProcessQueue)
            fadeLogicTimerShown = C_Timer.NewTicker(0.1, function()
                if fadeLogicCoroutine and coroutine.status(fadeLogicCoroutine) == "suspended" then
                    local success, errorMsg = coroutine.resume(fadeLogicCoroutine)
                    if (not success) then
                        Questie:Error("Please report on Github or Discord. Minimap pins fade logic coroutine stopped:", errorMsg)
                        fadeLogicCoroutine = nil
                    end
                end
            end)
        end
        if not fadeLogicCoroutine then
            fadeLogicCoroutine = coroutine.create(QuestieMap.ProcessShownMinimapIcons)
        end
    else
        if drawTimer then
            drawTimer:Cancel()
            drawTimer = nil
            fadeLogicTimerShown:Cancel()
            fadeLogicTimerShown = nil
        end
        isDrawQueueDisabled = true
    end
end

---@return number @A scale value that is based of the map currently open, smaller icons for World and Continent
function QuestieMap.GetScaleValue()
    if not HBDPins or not HBDPins.worldmapProvider then return 1 end
    local mapId = HBDPins.worldmapProvider:GetMap():GetMapID();
    local scaling = 1;
    if C_Map and C_Map.GetAreaInfo then
        local mapInfo = C_Map.GetMapInfo(mapId)
        if mapInfo then
            if (mapInfo.mapType == 0) then
                scaling = 0.85
            elseif (mapInfo.mapType == 1) then
                scaling = 0.85
            elseif (mapInfo.mapType == 2) then
                scaling = 0.9
            end
        end
    end
    return scaling
end

function QuestieMap:ProcessShownMinimapIcons()
    local getTime, cYield, getWorldPos = GetTime, coroutine.yield, HBD.GetPlayerWorldPosition

    local maxCount = 50
    local doEdgeUpdate = true
    local playerX, playerY
    local count
    local lastUpdate = getTime()
    local xd, yd
    local totalDistance = 0

    while true do
        count = 0
        playerX, playerY = getWorldPos()
        xd = (playerX or 0) - (QuestieMap.playerX or 0)
        yd = (playerY or 0) - (QuestieMap.playerY or 0)
        totalDistance = totalDistance + (xd * xd + yd * yd)
        QuestieMap.playerX = playerX
        QuestieMap.playerY = playerY

        if totalDistance > 3 or getTime() - lastUpdate >= 1 then
            doEdgeUpdate = true
            lastUpdate = getTime()
            totalDistance = 0
        end

        if HBDPins and HBDPins.activeMinimapPins then
            for minimapFrame, data in pairs(HBDPins.activeMinimapPins) do
                if minimapFrame.miniMapIcon and ((data.distanceFromMinimapCenter < 1.1) or doEdgeUpdate) then
                    if minimapFrame.FadeLogic then
                        minimapFrame:FadeLogic()
                    end
                    if minimapFrame.GlowUpdate then
                        minimapFrame:GlowUpdate()
                    end
                end

                if count > maxCount then
                    cYield()
                    if not HBDPins.activeMinimapPins[minimapFrame] then
                        totalDistance = 9000
                        break
                    end
                    count = 0
                else
                    count = count + 1
                end
            end
        end
        cYield()
        doEdgeUpdate = false
    end
end

function QuestieMap:QueueDraw(drawType, ...)
    if (not isDrawQueueDisabled) then
        if (drawType == QuestieMap.ICON_MAP_TYPE) then
            tinsert(mapDrawQueue, { ... });
        elseif (drawType == QuestieMap.ICON_MINIMAP_TYPE) then
            tinsert(minimapDrawQueue, { ... });
        end
    end
end

function QuestieMap.ProcessQueue()
    if (not next(mapDrawQueue) and (not next(minimapDrawQueue))) then
        return
    end

    local scaleValue = QuestieMap.GetScaleValue()
    for _ = 1, math.min(24, math.max(#mapDrawQueue, #minimapDrawQueue)) do
        local mapDrawCall = tremove(mapDrawQueue, 1);
        if mapDrawCall then
            local frame = mapDrawCall[2];
            HBDPins:AddWorldMapIconMap(tunpack(mapDrawCall));

            local size = (16 * (frame.data.IconScale or 1) * (Questie.db.profile.globalScale or 0.7)) * scaleValue;
            frame:SetSize(size, size)
            QuestieMap.utils:SetDrawOrder(frame);
        end

        local minimapDrawCall = tremove(minimapDrawQueue, 1);
        if minimapDrawCall then
            local frame = minimapDrawCall[2];
            HBDPins:AddMinimapIconMap(tunpack(minimapDrawCall));
            QuestieMap.utils:SetDrawOrder(frame);
        end

        if mapDrawCall then
            mapDrawCall[2]._loaded = true
            if mapDrawCall[2]._needsUnload then
                mapDrawCall[2]:Unload()
            end
        end

        if minimapDrawCall then
            minimapDrawCall[2]._loaded = true
            if minimapDrawCall[2]._needsUnload then
                minimapDrawCall[2]:Unload()
            end
        end
    end
end

-- Show NPC on map
---@param npcID number @The ID of the NPC
function QuestieMap:ShowNPC(npcID, icon, scale, title, body, disableShiftToRemove, typ, excludeDungeon)
    if type(npcID) ~= "number" then
        Questie:Debug(Questie.DEBUG_CRITICAL, "[QuestieMap:ShowNPC] Got <" .. type(npcID) .. "> instead of <number>")
        return
    end
    local npc = QuestieDB:GetNPC(npcID)
    if (not npc) or (not npc.spawns) then return end

    local data = {}
    data.id = npc.id
    data.Icon = icon or "Interface\\WorldMap\\WorldMapPartyIcon"
    data.GetIconScale = function() return scale or Questie.db.profile.manualScale or 0.7 end
    data.IconScale = data:GetIconScale()
    data.Type = "manual"
    data.spawnType = "monster"
    data.npcData = npc
    data.Name = npc.name
    data.IsObjectiveNote = false
    data.ManualTooltipData = {}
    local baseTitle = title or (npc.name .. " (" .. l10n("NPC") .. ")")
    data.ManualTooltipData.Title = WeaponMasterSkills and WeaponMasterSkills.AppendSkillsToTitle(baseTitle, data.id) or baseTitle
    local level = tostring(npc.minLevel)
    local health = tostring(npc.minLevelHealth)
    if npc.minLevel ~= npc.maxLevel then
        level = level .. '-' .. tostring(npc.maxLevel)
        health = health .. '-' .. tostring(npc.maxLevelHealth)
    end
    data.ManualTooltipData.Body = body or {
        { 'ID:',     tostring(npc.id) },
        { 'Level:',  level },
        { 'Health:', health },
    }
    data.ManualTooltipData.disableShiftToRemove = disableShiftToRemove

    local manualIcons = {}
    for zone, spawns in pairs(npc.spawns) do
        if (zone ~= nil and spawns ~= nil) and ((not excludeDungeon) or (not ZoneDB.IsDungeonZone(zone))) then
            for _, coords in ipairs(spawns) do
                local dungeonLocation = ZoneDB:GetDungeonLocation(zone)
                if dungeonLocation ~= nil then
                    for _, value in ipairs(dungeonLocation) do
                        QuestieMap:DrawManualIcon(data, value[1], value[2], value[3], typ)
                    end
                else
                    manualIcons[zone] = QuestieMap:DrawManualIcon(data, zone, coords[1], coords[2], typ)
                end
            end
        end
    end
    if npc.waypoints then
        for zone, waypoints in pairs(npc.waypoints) do
            if not ZoneDB:GetDungeonLocation(zone) and waypoints[1] and waypoints[1][1] and waypoints[1][1][1] then
                if not manualIcons[zone] then
                    manualIcons[zone] = QuestieMap:DrawManualIcon(data, zone, waypoints[1][1][1], waypoints[1][1][2])
                end
                QuestieMap:DrawWaypoints(manualIcons[zone], waypoints, zone)
            end
        end
    end
end

-- Show object on map
---@param objectID number
function QuestieMap:ShowObject(objectID, icon, scale, title, body, disableShiftToRemove, typ)
    if type(objectID) ~= "number" then return end
    local object = QuestieDB:GetObject(objectID)
    if not object or not object.spawns then return end

    local data = {}
    if typ then
        data.id = object.id
    else
        data.id = -object.id
    end
    data.Icon = icon or "Interface\\WorldMap\\WorldMapPartyIcon"
    data.GetIconScale = function() return scale or Questie.db.profile.manualScale or 0.7 end
    data.IconScale = data:GetIconScale()
    data.Type = "manual"
    data.spawnType = "object"
    data.objectData = object
    data.Name = object.name
    data.IsObjectiveNote = false
    data.ManualTooltipData = {}
    data.ManualTooltipData.Title = title or (object.name .. " (object)")
    data.ManualTooltipData.Body = body or {
        { 'ID:', tostring(object.id) },
    }
    data.ManualTooltipData.disableShiftToRemove = disableShiftToRemove

    for zone, spawns in pairs(object.spawns) do
        if (zone ~= nil and spawns ~= nil) then
            for _, coords in ipairs(spawns) do
                local dungeonLocation = ZoneDB:GetDungeonLocation(zone)
                if dungeonLocation ~= nil then
                    for _, value in ipairs(dungeonLocation) do
                        QuestieMap:DrawManualIcon(data, value[1], value[2], value[3], typ)
                    end
                else
                    QuestieMap:DrawManualIcon(data, zone, coords[1], coords[2], typ)
                end
            end
        end
    end
end

function QuestieMap:DrawLineIcon(lineFrame, areaID, x, y)
    if type(areaID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        Questie:Debug(Questie.DEBUG_CRITICAL, "[QuestieMap:DrawLineIcon] 'AreaID', 'x' and 'y' must be numbers:", areaID, x, y)
        return nil, nil
    end

    local uiMapId = ZoneDB:GetUiMapIdByAreaId(areaID)
    if not uiMapId then
        Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieMap:DrawLineIcon] No UiMapID for areaId:", areaID)
        return nil, nil
    end

    HBDPins:AddWorldMapIconMap(Questie, lineFrame, uiMapId, x, y, HBD_PINS_WORLDMAP_SHOW_CURRENT)
end

-- Draw manually added NPC/object notes
function QuestieMap:DrawManualIcon(data, areaID, x, y, typ)
    if type(data) ~= "table" then
        Questie:Debug(Questie.DEBUG_CRITICAL, "[QuestieMap:DrawManualIcon] must have some data")
        return nil, nil
    end
    if type(areaID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
        Questie:Debug(Questie.DEBUG_CRITICAL, "[QuestieMap:DrawManualIcon] 'AreaID', 'x' and 'y' must be numbers:", areaID, x, y)
        return nil, nil
    end
    if type(data.id) ~= "number" then
        Questie:Debug(Questie.DEBUG_CRITICAL, "[QuestieMap:DrawManualIcon] Data.id must be set to the NPC or object ID!")
        return nil, nil
    end

    data.Id = data.id

    local uiMapId = ZoneDB:GetUiMapIdByAreaId(areaID)
    if (not uiMapId) then
        Questie:Debug(Questie.DEBUG_CRITICAL, "[QuestieMap:DrawManualIcon] No UiMapID for areaId:", areaID, tostring(data.Name))
        return nil, nil
    end

    local texture = data.Icon or "Interface\\WorldMap\\WorldMapPartyIcon"
    typ = typ or "any"
    if not QuestieMap.manualFrames[typ] then
        QuestieMap.manualFrames[typ] = {}
    end
    if not QuestieMap.manualFrames[typ][data.id] then
        QuestieMap.manualFrames[typ][data.id] = {}
    end

    local icon = QuestieFramePool:GetFrame()
    icon.data = data
    icon.x = x
    icon.y = y
    icon.AreaID = areaID
    icon.UiMapID = uiMapId
    icon.miniMapIcon = false;
    icon.texture:SetTexture(texture)
    icon:SetWidth(16 * (data:GetIconScale() or 0.7))
    icon:SetHeight(16 * (data:GetIconScale() or 0.7))

    QuestieMap:QueueDraw(QuestieMap.ICON_MAP_TYPE, Questie, icon, icon.UiMapID, x / 100, y / 100, 3)
    tinsert(QuestieMap.manualFrames[typ][data.id], icon:GetName())

    local iconMinimap = QuestieFramePool:GetFrame()
    local colorsMinimap = { 1, 1, 1 }
    if data.IconColor ~= nil and Questie.db.profile.questMinimapObjectiveColors then
        colorsMinimap = data.IconColor
    end
    iconMinimap:SetWidth(16 * ((data:GetIconScale() or 1) * (Questie.db.profile.globalMiniMapScale or 0.7)))
    iconMinimap:SetHeight(16 * ((data:GetIconScale() or 1) * (Questie.db.profile.globalMiniMapScale or 0.7)))
    iconMinimap.data = data
    iconMinimap.x = x
    iconMinimap.y = y
    iconMinimap.AreaID = areaID
    iconMinimap.UiMapID = uiMapId
    iconMinimap.texture:SetTexture(texture)
    iconMinimap.texture:SetVertexColor(colorsMinimap[1], colorsMinimap[2], colorsMinimap[3], 1);
    iconMinimap.miniMapIcon = true;

    QuestieMap:QueueDraw(QuestieMap.ICON_MINIMAP_TYPE, Questie, iconMinimap, iconMinimap.UiMapID, x / 100, y / 100, true, true);
    tinsert(QuestieMap.manualFrames[typ][data.id], iconMinimap:GetName())

    if (not Questie.db.profile.enabled) then
        icon:FakeHide()
        iconMinimap:FakeHide()
    else
        if (not Questie.db.profile.enableMapIcons) then
            icon:FakeHide()
        end
        if (not Questie.db.profile.enableMiniMapIcons) then
            iconMinimap:FakeHide()
        end
    end

    if QuestieMap.utils and QuestieMap.utils.RescaleIcon then
        QuestieMap.utils:RescaleIcon(icon)
    end

    return icon, iconMinimap;
end

--A layer to keep the area conversion away from the other parts of the code
--coordinates need to be 0-1 instead of 0-100
---@return IconFrame, IconFrame
function QuestieMap:DrawWorldIcon(data, areaID, x, y, showFlag)
    if type(data) ~= "table" then
        Questie:Debug(Questie.DEBUG_CRITICAL, "[QuestieMap:DrawWorldIcon] must have some data")
        return nil, nil
    end

    local uiMapId = ZoneDB:GetUiMapIdByAreaId(areaID)
    if (not uiMapId) then
        local parentMapId
        local mapInfo = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(areaID)
        if mapInfo then
            parentMapId = mapInfo.parentMapID
        else
            parentMapId = ZoneDB:GetParentZoneId(areaID)
        end

        if (not parentMapId) then
            Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieMap:DrawWorldIcon] No UiMapID or fitting parentAreaId for areaId:", areaID, tostring(data.Name))
            return nil, nil
        else
            areaID = parentMapId
            uiMapId = ZoneDB:GetUiMapIdByAreaId(areaID)
        end
    end

    if (not showFlag) then
        showFlag = HBD_PINS_WORLDMAP_SHOW_WORLD
    end

    if not uiMapId then
        Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieMap:DrawWorldIcon] No UiMapID or fitting uiMapId for areaId:", areaID, tostring(data.Name))
        return nil, nil
    end

    local floatOnEdge = true

    ---@type IconFrame
    local iconMap = QuestieFramePool:GetFrame()
    iconMap.data = data
    iconMap.x = x
    iconMap.y = y
    iconMap.AreaID = areaID
    iconMap.UiMapID = uiMapId
    iconMap.miniMapIcon = false;
    iconMap:UpdateTexture(Questie.usedIcons[data.Icon]);

    ---@type IconFrame
    local iconMinimap = QuestieFramePool:GetFrame()
    iconMinimap.data = data
    iconMinimap.x = x
    iconMinimap.y = y
    iconMinimap.AreaID = areaID
    iconMinimap.UiMapID = uiMapId
    iconMinimap.miniMapIcon = true;
    iconMinimap:UpdateTexture(Questie.usedIcons[data.Icon]);

    if (not iconMinimap.FadeLogic) then
        function iconMinimap:SetFade(value)
            if self.lastGlowFade ~= value then
                self.lastGlowFade = value
                if self.glowTexture then
                    local r, g, b = self.glowTexture:GetVertexColor()
                    self.glowTexture:SetVertexColor(r, g, b, value)
                end
                self.texture:SetVertexColor(self.texture.r, self.texture.g, self.texture.b, value)
            end
        end

        function iconMinimap:FadeLogic()
            local profile = Questie.db.profile
            if self.miniMapIcon and self.x and self.y and self.texture and self.UiMapID and self.texture.SetVertexColor and HBD and HBD.GetPlayerZonePosition and QuestieLib and QuestieLib.Euclid then
                if (QuestieMap.playerX and QuestieMap.playerY) then
                    local x, y
                    if not self.worldX then
                        x, y = HBD:GetWorldCoordinatesFromZone(self.x / 100, self.y / 100, self.UiMapID)
                        self.worldX = x
                        self.worldY = y
                    else
                        x = self.worldX
                        y = self.worldY
                    end
                    if (x and y) then
                        local distance = QuestieLib:Euclid(QuestieMap.playerX, QuestieMap.playerY, x, y) / 10;

                        if (distance > profile.fadeLevel) then
                            local fade = 1 - (math.min(10, (distance - profile.fadeLevel)) * normalizedValue);
                            self:SetFade(fade)
                        elseif (distance < profile.fadeOverPlayerDistance) and profile.fadeOverPlayer then
                            local fadeAmount = profile.fadeOverPlayerLevel + distance * (1 - profile.fadeOverPlayerLevel) / profile.fadeOverPlayerDistance
                            if self.faded and fadeAmount > profile.iconFadeLevel then
                                fadeAmount = profile.iconFadeLevel
                            end
                            self:SetFade(fadeAmount)
                        else
                            if self.faded then
                                self:SetFade(profile.iconFadeLevel)
                            else
                                self:SetFade(1)
                            end
                        end
                    end
                else
                    if self.faded then
                        self:SetFade(profile.iconFadeLevel)
                    else
                        self:SetFade(1)
                    end
                end
            end
        end

        -- We do not want to hook the OnUpdate again!
        -- iconMinimap:SetScript("OnUpdate", )
    end

    QuestieMap:QueueDraw(QuestieMap.ICON_MINIMAP_TYPE, Questie, iconMinimap, uiMapId, x / 100, y / 100, true, floatOnEdge)
    QuestieMap:QueueDraw(QuestieMap.ICON_MAP_TYPE, Questie, iconMap, uiMapId, x / 100, y / 100, showFlag)
    local r, g, b = iconMinimap.texture:GetVertexColor()
    if QuestieDBMIntegration.RegisterHudQuestIcon then
        QuestieDBMIntegration:RegisterHudQuestIcon(tostring(iconMap), data.Icon, uiMapId, x, y, r, g, b)
    end

    if not QuestieMap.questIdFrames[data.Id] then
        QuestieMap.questIdFrames[data.Id] = {}
    end

    QuestieMap.questIdFrames[data.Id][iconMap:GetName()] = iconMap:GetName()
    QuestieMap.questIdFrames[data.Id][iconMinimap:GetName()] = iconMinimap:GetName()

    if iconMap:ShouldBeHidden() then
        iconMap:FakeHide()
    end

    if iconMinimap:ShouldBeHidden() then
        iconMinimap:FakeHide()
    end

    return iconMap, iconMinimap;
end

--- The return type also contains, distance, zone and type but we never really use it.
---@type table<QuestId, {x:X, y:Y}>
local closestStarter = {}
function QuestieMap:FindClosestStarter()
    local playerX, playerY, _ = HBD:GetPlayerWorldPosition();
    local playerZone = HBD:GetPlayerWorldPosition();
    for questId in pairs(QuestiePlayer.currentQuestlog) do
        if (not closestStarter[questId]) then
            local quest = QuestieDB.GetQuest(questId);
            if quest then
                closestStarter[questId] = {
                    distance = 999999,
                    x = -1,
                    y = -1,
                    zone = -1,
                    type = "",
                }
                for starterType, starters in pairs(quest.Starts) do
                    if (starterType == "GameObject") then
                        for _, ObjectID in ipairs(starters or {}) do
                            local obj = QuestieDB:GetObject(ObjectID)
                            if (obj ~= nil and obj.spawns ~= nil) then
                                for Zone, Spawns in pairs(obj.spawns) do
                                    if (Zone ~= nil and Spawns ~= nil) then
                                        for _, coords in ipairs(Spawns) do
                                            if (coords[1] == -1 or coords[2] == -1) then
                                                local dungeonLocation = ZoneDB:GetDungeonLocation(Zone)
                                                if dungeonLocation ~= nil then
                                                    for _, value in ipairs(dungeonLocation) do
                                                        if (value[1] and value[2]) then
                                                            local x, y, _ = HBD:GetWorldCoordinatesFromZone(value[1] / 100, value[2] / 100, ZoneDB:GetUiMapIdByAreaId(value[3]))
                                                            if (x and y) then
                                                                local distance = QuestieLib:Euclid(playerX or 0, playerY or 0, x, y);
                                                                if (closestStarter[questId].distance > distance) then
                                                                    closestStarter[questId].distance = distance;
                                                                    closestStarter[questId].x = x;
                                                                    closestStarter[questId].y = y;
                                                                    closestStarter[questId].zone = ZoneDB:GetUiMapIdByAreaId(Zone);
                                                                    closestStarter[questId].type = "GameObject - " .. obj.name;
                                                                end
                                                            end
                                                        end
                                                    end
                                                end
                                            else
                                                local uiMapId = ZoneDB:GetUiMapIdByAreaId(Zone)
                                                local x, y, _ = HBD:GetWorldCoordinatesFromZone(coords[1] / 100, coords[2] / 100, uiMapId)
                                                if (x and y) then
                                                    local distance = QuestieLib:Euclid(playerX or 0, playerY or 0, x, y);
                                                    if (closestStarter[questId].distance > distance) then
                                                        closestStarter[questId].distance = distance;
                                                        closestStarter[questId].x = x;
                                                        closestStarter[questId].y = y;
                                                        closestStarter[questId].zone = uiMapId
                                                        closestStarter[questId].type = "GameObject - " .. obj.name;
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    elseif (starterType == "NPC") then
                        for _, NPCID in ipairs(starters or {}) do
                            local NPC = QuestieDB:GetNPC(NPCID)
                            if (NPC ~= nil and NPC.spawns ~= nil and NPC.friendly) then
                                for Zone, Spawns in pairs(NPC.spawns) do
                                    if (Zone ~= nil and Spawns ~= nil) then
                                        for _, coords in ipairs(Spawns) do
                                            if (coords[1] == -1 or coords[2] == -1) then
                                                local dungeonLocation = ZoneDB:GetDungeonLocation(Zone)
                                                if dungeonLocation ~= nil then
                                                    for _, value in ipairs(dungeonLocation) do
                                                        if (value[1] and value[2]) then
                                                            local uiMapId = ZoneDB:GetUiMapIdByAreaId(value[3])
                                                            local x, y, _ = HBD:GetWorldCoordinatesFromZone(value[1] / 100, value[2] / 100, uiMapId)
                                                            if (x and y) then
                                                                local distance = QuestieLib:Euclid(playerX or 0, playerY or 0, x, y);
                                                                if (closestStarter[questId].distance > distance) then
                                                                    closestStarter[questId].distance = distance;
                                                                    closestStarter[questId].x = x;
                                                                    closestStarter[questId].y = y;
                                                                    closestStarter[questId].zone = ZoneDB:GetUiMapIdByAreaId(Zone);
                                                                    closestStarter[questId].type = "NPC - " .. NPC.name;
                                                                end
                                                            end
                                                        end
                                                    end
                                                end
                                            elseif (coords[1] and coords[2]) then
                                                local uiMapId = ZoneDB:GetUiMapIdByAreaId(Zone)
                                                local x, y, _ = HBD:GetWorldCoordinatesFromZone(coords[1] / 100, coords[2] / 100, uiMapId)
                                                if (x and y) then
                                                    local distance = QuestieLib:Euclid(playerX or 0, playerY or 0, x, y);
                                                    if (closestStarter[questId].distance > distance) then
                                                        closestStarter[questId].distance = distance;
                                                        closestStarter[questId].x = x;
                                                        closestStarter[questId].y = y;
                                                        closestStarter[questId].zone = ZoneDB:GetUiMapIdByAreaId(Zone);
                                                        closestStarter[questId].type = "NPC - " .. NPC.name;
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
                if (closestStarter[questId].x == -1) then
                    closestStarter[questId].distance = 0;
                    closestStarter[questId].x = playerX;
                    closestStarter[questId].y = playerY;
                    closestStarter[questId].zone = playerZone;
                    closestStarter[questId].type = "player";
                end
            end
        end
    end
    return closestStarter;
end

function QuestieMap:GetNearestSpawn(objective)
    if not objective then
        return nil
    end
    local playerX, playerY, playerI = HBD:GetPlayerWorldPosition()
    local bestDistance = 999999999
    local bestSpawn, bestSpawnZone, bestSpawnId, bestSpawnType, bestSpawnName
    if objective and objective.spawnList and next(objective.spawnList) then
        for id, spawnData in pairs(objective.spawnList) do
            for zone, spawns in pairs(spawnData.Spawns) do
                for _, spawn in pairs(spawns) do
                    local uiMapId = ZoneDB:GetUiMapIdByAreaId(zone)
                    local dX, dY, dInstance = HBD:GetWorldCoordinatesFromZone(spawn[1] / 100.0, spawn[2] / 100.0, uiMapId)
                    local dist = HBD:GetWorldDistance(dInstance, playerX, playerY, dX, dY)
                    if dist then
                        if dInstance ~= playerI then
                            dist = 500000 + dist * 100
                        end
                        if dist < bestDistance then
                            bestDistance = dist
                            bestSpawn = spawn
                            bestSpawnZone = zone
                            bestSpawnId = id
                            bestSpawnType = spawnData.Type
                            bestSpawnName = spawnData.Name
                        end
                    end
                end
            end
        end
    end
    return bestSpawn, bestSpawnZone, bestSpawnName, bestSpawnId, bestSpawnType, bestDistance
end

---@param quest Quest
function QuestieMap:GetNearestQuestSpawn(quest)
    if not quest then
        return nil
    end
    if quest:IsComplete() == 1 then
        local finisherSpawns
        local finisherName
        if quest.Finisher ~= nil then
            if quest.Finisher.Type == "monster" then
                finisherSpawns, finisherName = QuestieDB.QueryNPCSingle(quest.Finisher.Id, "spawns"), QuestieDB.QueryNPCSingle(quest.Finisher.Id, "name")
            elseif quest.Finisher.Type == "object" then
                finisherSpawns, finisherName = QuestieDB.QueryObjectSingle(quest.Finisher.Id, "spawns"), QuestieDB.QueryObjectSingle(quest.Finisher.Id, "name")
            end
        end
        if finisherSpawns then
            local bestDistance = 999999999
            local playerX, playerY, playerI = HBD:GetPlayerWorldPosition()
            local bestSpawn, bestSpawnZone, bestSpawnType, bestSpawnName
            for zone, spawns in pairs(finisherSpawns) do
                for _, spawn in pairs(spawns) do
                    local uiMapId = ZoneDB:GetUiMapIdByAreaId(zone)
                    local dX, dY, dInstance = HBD:GetWorldCoordinatesFromZone(spawn[1] / 100.0, spawn[2] / 100.0, uiMapId)
                    local dist = HBD:GetWorldDistance(dInstance, playerX, playerY, dX, dY)
                    if dist then
                        if dInstance ~= playerI then
                            dist = 500000 + dist * 100
                        end
                        if dist < bestDistance then
                            bestDistance = dist
                            bestSpawn = spawn
                            bestSpawnZone = zone
                            bestSpawnType = quest.Finisher.Type
                            bestSpawnName = finisherName
                        end
                    end
                end
            end
            return bestSpawn, bestSpawnZone, bestSpawnName, bestSpawnType, bestDistance
        end
        return nil
    end

    local bestDistance = 999999999
    local bestSpawn, bestSpawnZone, bestSpawnId, bestSpawnType, bestSpawnName

    for _, objective in pairs(quest.Objectives) do
        local spawn, zone, Name, id, Type, dist = QuestieMap:GetNearestSpawn(objective)
        if spawn and dist < bestDistance and ((not objective.Needed) or objective.Needed ~= objective.Collected) then
            bestDistance = dist
            bestSpawn = spawn
            bestSpawnZone = zone
            bestSpawnId = id
            bestSpawnType = Type
            bestSpawnName = Name
        end
    end

    for _, objective in pairs(quest.SpecialObjectives) do
        local spawn, zone, Name, id, Type, dist = QuestieMap:GetNearestSpawn(objective)
        if spawn and dist < bestDistance and ((not objective.Needed) or objective.Needed ~= objective.Collected) then
            bestDistance = dist
            bestSpawn = spawn
            bestSpawnZone = zone
            bestSpawnId = id
            bestSpawnType = Type
            bestSpawnName = Name
        end
    end
    return bestSpawn, bestSpawnZone, bestSpawnName, bestSpawnId, bestSpawnType, bestDistance
end

QuestieMap.zoneWaypointColorOverrides = {
    --    [14] = {0,0.1,0.9,0.7}, -- durotar
    --    [38] = {0,0.1,0.9,0.7} -- loch modan
}

QuestieMap.zoneWaypointHoverColorOverrides = {
    --    [14] = {0,0.6,1,1}, -- durotar
    --    [38] = {0,0.6,1,1} -- loch modan
}

function QuestieMap:DrawWaypoints(icon, waypoints, zone, color)
    if waypoints and waypoints[1] and waypoints[1][1] and waypoints[1][1][1] then
        local lineFrames = QuestieFramePool:CreateWaypoints(icon, waypoints, nil, color or QuestieMap.zoneWaypointColorOverrides[zone], zone)
        for _, lineFrame in ipairs(lineFrames) do
            QuestieMap:DrawLineIcon(lineFrame, zone, waypoints[1][1][1], waypoints[1][1][2])
        end
    end
end

return QuestieMap
