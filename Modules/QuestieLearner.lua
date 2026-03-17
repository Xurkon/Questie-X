---@class QuestieLearner
local QuestieLearner = QuestieLoader:CreateModule("QuestieLearner")

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")

local _Learner = QuestieLearner.private or {}
QuestieLearner.private = _Learner

local floor = math.floor
local abs   = math.abs

-- NPC flags (WoW bitmask)
local NPC_FLAG_GOSSIP          = 0x00000001
local NPC_FLAG_QUESTGIVER      = 0x00000002
local NPC_FLAG_TRAINER         = 0x00000010
local NPC_FLAG_VENDOR          = 0x00000080
local NPC_FLAG_FLIGHTMASTER    = 0x00000200
local NPC_FLAG_INNKEEPER       = 0x00000800
local NPC_FLAG_BANKER          = 0x00001000
local NPC_FLAG_AUCTIONEER      = 0x00004000
local NPC_FLAG_STABLEMASTER    = 0x00010000

-- Only cache/learn mouseover NPCs that carry one of these flags
local MOUSEOVER_LEARN_FLAGS = NPC_FLAG_QUESTGIVER

-- Coordinate grid cell size (in 0–100 map units).
-- ~2 grid units ≈ 2% of zone width — keeps clusters tight without over-splitting.
local COORD_GRID = 2.0

_Learner.pendingNpcs    = {}
_Learner.pendingQuests  = {}
_Learner.pendingItems   = {}
_Learner.pendingObjects = {}
_Learner.pendingItemLinks = {} -- queue for async GetItemInfo retries

-- Direct reference to learnedData, set on Initialize
QuestieLearner.data = nil

------------------------------------------------------------------------
-- Coordinate helpers
------------------------------------------------------------------------

local function GetZoneId()
    local mapId = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if mapId then return mapId end
    return select(8, GetInstanceInfo()) or 0
end

local function GetPlayerCoords()
    local x, y = GetPlayerMapPosition("player")
    if x and y and x > 0 and y > 0 then
        -- Store in 0–100 scale, 2-decimal precision
        return floor(x * 10000) / 100, floor(y * 10000) / 100
    end
    return nil, nil
end

-- Returns the grid-bucket key for a coordinate so nearby points share the same slot
local function CoordBucket(x, y)
    return floor(x / COORD_GRID) * COORD_GRID, floor(y / COORD_GRID) * COORD_GRID
end

-- Inserts {x, y} into coordList only when no existing point falls in the same grid bucket
local function InsertIfNewBucket(coordList, x, y)
    local bx, by = CoordBucket(x, y)
    for _, coord in ipairs(coordList) do
        local cx, cy = CoordBucket(coord[1], coord[2])
        if cx == bx and cy == by then return false end
    end
    table.insert(coordList, {x, y})
    return true
end

------------------------------------------------------------------------
-- Internal state guards
------------------------------------------------------------------------

local function EnsureLearnedData()
    if not Questie.db then return false end
    Questie.db.global.learnedData = Questie.db.global.learnedData or {
        npcs    = {},
        quests  = {},
        items   = {},
        objects = {},
        settings = {
            enabled      = true,
            learnNpcs    = true,
            learnQuests  = true,
            learnItems   = true,
            learnObjects = true,
        },
    }
    return true
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

function QuestieLearner:IsEnabled()
    if not EnsureLearnedData() then return false end
    return Questie.db.global.learnedData.settings.enabled
end

function QuestieLearner:GetSettings()
    if not EnsureLearnedData() then return {} end
    return Questie.db.global.learnedData.settings
end

------------------------------------------------------------------------
-- NPC learning
------------------------------------------------------------------------

function QuestieLearner:LearnNPC(npcId, name, level, subName, npcFlags, factionString)
    if not self:IsEnabled() then return end
    if not Questie.db.global.learnedData.settings.learnNpcs then return end
    if not npcId or npcId <= 0 then return end

    local zoneId = GetZoneId()
    local x, y   = GetPlayerCoords()

    local existing = Questie.db.global.learnedData.npcs[npcId]
    if not existing then
        existing = {}
        Questie.db.global.learnedData.npcs[npcId] = existing
    end

    if name          and not existing[1]  then existing[1]  = name end
    if level then
        if not existing[4] or level < existing[4] then existing[4] = level end
        if not existing[5] or level > existing[5] then existing[5] = level end
    end
    if zoneId        and zoneId > 0 and not existing[9]  then existing[9]  = zoneId end
    if factionString and not existing[13] then existing[13] = factionString end
    if subName       and not existing[14] then existing[14] = subName end
    if npcFlags      and npcFlags > 0 and not existing[15] then existing[15] = npcFlags end

    if x and y and zoneId and zoneId > 0 then
        existing[7] = existing[7] or {}
        existing[7][zoneId] = existing[7][zoneId] or {}
        InsertIfNewBucket(existing[7][zoneId], x, y)
    end

    existing.mc = (existing.mc or 0) + 1

    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieLearner] Learned NPC:", npcId, name or "?")
    _Learner:BroadcastIfCommsAvailable("NPC", npcId, existing)
end

------------------------------------------------------------------------
-- Quest learning
------------------------------------------------------------------------

-- Captures all fields accessible from the WoW API.
-- Quest data array indices follow the Questie wiki spec exactly:
--  [1]  name           [2]  starters (npc/obj/item arrays)  [3]  finishers
--  [4]  requiredLevel  [5]  questLevel  [6]  infoText (objectives text block)
--  [7]  requiredMoney  [8]  zoneOrSort  [12] requiredRaces   [13] requiredClasses
--  [17] details text   [18] finishText  [19] completedText
function QuestieLearner:LearnQuest(questId, data)
    if not self:IsEnabled() then return end
    if not Questie.db.global.learnedData.settings.learnQuests then return end
    if not questId or questId <= 0 then return end

    local existing = Questie.db.global.learnedData.quests[questId]
    if not existing then
        existing = {}
        Questie.db.global.learnedData.quests[questId] = existing
    end

    for k, v in pairs(data) do
        if v ~= nil and v ~= "" and v ~= 0 and existing[k] == nil then
            existing[k] = v
        end
    end

    existing.mc = (existing.mc or 0) + 1

    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieLearner] Learned Quest:", questId, existing[1] or "?")
    _Learner:BroadcastIfCommsAvailable("QUEST", questId, existing)
end

-- Records the NPC/object that starts or finishes a quest (array index [2] or [3])
function QuestieLearner:LearnQuestGiver(questId, entityId, entityType, isStart)
    if not self:IsEnabled() then return end
    if not Questie.db.global.learnedData.settings.learnQuests then return end
    if not questId or questId <= 0 or not entityId or entityId <= 0 then return end

    local existing = Questie.db.global.learnedData.quests[questId]
    if not existing then
        existing = {}
        Questie.db.global.learnedData.quests[questId] = existing
    end

    -- Starters/finishers: { [1]={npcIds}, [2]={objIds}, [3]={itemIds} }
    local field = isStart and 2 or 3
    existing[field] = existing[field] or {}
    -- entityType: 1=npc, 2=obj, 3=item
    local typeSlot = entityType or 1
    existing[field][typeSlot] = existing[field][typeSlot] or {}
    local list = existing[field][typeSlot]
    for _, id in ipairs(list) do
        if id == entityId then return end
    end
    table.insert(list, entityId)
end

------------------------------------------------------------------------
-- Item learning
------------------------------------------------------------------------

function QuestieLearner:LearnItem(itemId, name, itemLevel, requiredLevel, itemClass, itemSubClass)
    if not self:IsEnabled() then return end
    if not Questie.db.global.learnedData.settings.learnItems then return end
    if not itemId or itemId <= 0 then return end

    local existing = Questie.db.global.learnedData.items[itemId]
    if not existing then
        existing = {}
        Questie.db.global.learnedData.items[itemId] = existing
    end

    if name         and not existing[1]  then existing[1]  = name end
    if itemLevel    and itemLevel > 0    and not existing[9]  then existing[9]  = itemLevel end
    if requiredLevel and requiredLevel > 0 and not existing[10] then existing[10] = requiredLevel end
    if itemClass    and not existing[12] then existing[12] = itemClass end
    if itemSubClass and not existing[13] then existing[13] = itemSubClass end

    existing.mc = (existing.mc or 0) + 1

    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieLearner] Learned Item:", itemId, name or "?")
    _Learner:BroadcastIfCommsAvailable("ITEM", itemId, existing)
end

function QuestieLearner:LearnItemDrop(itemId, npcId)
    if not self:IsEnabled() then return end
    if not Questie.db.global.learnedData.settings.learnItems then return end
    if not itemId or itemId <= 0 or not npcId or npcId <= 0 then return end

    local existing = Questie.db.global.learnedData.items[itemId]
    if not existing then
        existing = {}
        Questie.db.global.learnedData.items[itemId] = existing
    end

    existing[2] = existing[2] or {}
    for _, id in ipairs(existing[2]) do
        if id == npcId then return end
    end
    table.insert(existing[2], npcId)
end

------------------------------------------------------------------------
-- Object learning
------------------------------------------------------------------------

function QuestieLearner:LearnObject(objectId, name)
    if not self:IsEnabled() then return end
    if not Questie.db.global.learnedData.settings.learnObjects then return end
    if not objectId or objectId <= 0 then return end

    local zoneId = GetZoneId()
    local x, y   = GetPlayerCoords()

    local existing = Questie.db.global.learnedData.objects[objectId]
    if not existing then
        existing = {}
        Questie.db.global.learnedData.objects[objectId] = existing
    end

    if name   and not existing[1] then existing[1] = name end
    if zoneId and zoneId > 0 and not existing[5] then existing[5] = zoneId end

    if x and y and zoneId and zoneId > 0 then
        existing[4] = existing[4] or {}
        existing[4][zoneId] = existing[4][zoneId] or {}
        InsertIfNewBucket(existing[4][zoneId], x, y)
    end

    existing.mc = (existing.mc or 0) + 1

    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieLearner] Learned Object:", objectId, name or "?")
    _Learner:BroadcastIfCommsAvailable("OBJECT", objectId, existing)
end

------------------------------------------------------------------------
-- InjectLearnedData — pushes learnedData into QuestieDB overrides
------------------------------------------------------------------------

function QuestieLearner:InjectLearnedData()
    if not EnsureLearnedData() then return end

    local learned = Questie.db.global.learnedData
    local npcCount, questCount, itemCount, objectCount = 0, 0, 0, 0

    for npcId, data in pairs(learned.npcs) do
        if not QuestieDB.npcDataOverrides[npcId] then
            QuestieDB.npcDataOverrides[npcId] = data
            npcCount = npcCount + 1
        else
            local existing = QuestieDB.npcDataOverrides[npcId]
            if data[7] then
                existing[7] = existing[7] or {}
                for zoneId, coords in pairs(data[7]) do
                    existing[7][zoneId] = existing[7][zoneId] or {}
                    for _, coord in ipairs(coords) do
                        InsertIfNewBucket(existing[7][zoneId], coord[1], coord[2])
                    end
                end
            end
        end
    end

    for questId, data in pairs(learned.quests) do
        if not QuestieDB.questDataOverrides[questId] then
            QuestieDB.questDataOverrides[questId] = data
            questCount = questCount + 1
        else
            local existing = QuestieDB.questDataOverrides[questId]
            for k, v in pairs(data) do
                if k ~= "mc" and existing[k] == nil then
                    existing[k] = v
                end
            end
        end
    end

    for itemId, data in pairs(learned.items) do
        if not QuestieDB.itemDataOverrides[itemId] then
            QuestieDB.itemDataOverrides[itemId] = data
            itemCount = itemCount + 1
        end
    end

    for objectId, data in pairs(learned.objects) do
        if not QuestieDB.objectDataOverrides[objectId] then
            QuestieDB.objectDataOverrides[objectId] = data
            objectCount = objectCount + 1
        else
            local existing = QuestieDB.objectDataOverrides[objectId]
            if data[4] then
                existing[4] = existing[4] or {}
                for zoneId, coords in pairs(data[4]) do
                    existing[4][zoneId] = existing[4][zoneId] or {}
                    for _, coord in ipairs(coords) do
                        InsertIfNewBucket(existing[4][zoneId], coord[1], coord[2])
                    end
                end
            end
        end
    end

    if npcCount > 0 or questCount > 0 or itemCount > 0 or objectCount > 0 then
        Questie:Debug(Questie.DEBUG_INFO, "[QuestieLearner] Injected learned data:",
            npcCount, "NPCs,", questCount, "quests,", itemCount, "items,", objectCount, "objects")
    end
end

------------------------------------------------------------------------
-- Stats / Export helpers
------------------------------------------------------------------------

function QuestieLearner:GetStats()
    if not EnsureLearnedData() then return 0, 0, 0, 0 end
    local learned = Questie.db.global.learnedData
    local n, q, i, o = 0, 0, 0, 0
    for _ in pairs(learned.npcs)    do n = n + 1 end
    for _ in pairs(learned.quests)  do q = q + 1 end
    for _ in pairs(learned.items)   do i = i + 1 end
    for _ in pairs(learned.objects) do o = o + 1 end
    return n, q, i, o
end

function QuestieLearner:ClearAllData()
    if not EnsureLearnedData() then return end
    Questie.db.global.learnedData.npcs    = {}
    Questie.db.global.learnedData.quests  = {}
    Questie.db.global.learnedData.items   = {}
    Questie.db.global.learnedData.objects = {}
    Questie:Print("Cleared all learned data.")
end

function QuestieLearner:SerializeTable(t)
    if type(t) ~= "table" then
        if type(t) == "string" then return string.format("%q", t) end
        return tostring(t)
    end
    local parts = {}
    local isArray = #t > 0
    for k, v in pairs(t) do
        local key = isArray and "" or ("[" .. (type(k) == "string" and string.format("%q", k) or tostring(k)) .. "]=")
        table.insert(parts, key .. self:SerializeTable(v))
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

function QuestieLearner:ExportData()
    if not EnsureLearnedData() then return "" end
    local learned = Questie.db.global.learnedData
    local lines = {}
    table.insert(lines, "-- QuestieLearner Export")
    local n, q, i, o = self:GetStats()
    table.insert(lines, "-- NPCs: " .. n .. "  Quests: " .. q .. "  Items: " .. i .. "  Objects: " .. o)
    table.insert(lines, "")
    table.insert(lines, "QuestieLearnerExport = {")
    table.insert(lines, "  npcs    = " .. self:SerializeTable(learned.npcs) .. ",")
    table.insert(lines, "  quests  = " .. self:SerializeTable(learned.quests) .. ",")
    table.insert(lines, "  items   = " .. self:SerializeTable(learned.items) .. ",")
    table.insert(lines, "  objects = " .. self:SerializeTable(learned.objects) .. ",")
    table.insert(lines, "}")
    return table.concat(lines, "\n")
end

------------------------------------------------------------------------
-- GUID parsing
------------------------------------------------------------------------

local HEX_PREFIXES = {
    ["F130"] = "Creature",
    ["F131"] = "Vehicle",
    ["F140"] = "GameObject",
    ["F110"] = "Creature",
    ["F111"] = "Creature",
}

local CREATURE_HEX_PREFIXES = { ["F130"]=true, ["F131"]=true, ["F110"]=true, ["F111"]=true }

local function GetIdAndTypeFromGUID(guid)
    if not guid then return nil, nil end
    -- Modern dash-separated GUID (e.g. "Creature-0-3726-0-189-5638296-...")
    local unitType, _, _, _, _, parsedId = strsplit("-", guid)
    local id = tonumber(parsedId)
    if id and id > 0 and unitType then
        return id, unitType
    end
    -- Legacy hex GUID
    if string.sub(guid, 1, 2) == "0x" and string.len(guid) >= 18 then
        local prefix = string.upper(string.sub(guid, 3, 6))
        local t = HEX_PREFIXES[prefix]
        if t then
            local low32 = tonumber(string.sub(guid, 11, 18), 16)
            if low32 then
                local nid = math.mod(low32, 8388608)
                if nid > 0 then return nid, t end
            end
        end
    end
    return nil, nil
end

local function GetNpcIdFromGUID(guid)
    local id, unitType = GetIdAndTypeFromGUID(guid)
    if unitType == "Creature" or unitType == "Vehicle" then return id end
    return nil
end

local function GetObjectIdFromGUID(guid)
    local id, unitType = GetIdAndTypeFromGUID(guid)
    if unitType == "GameObject" then return id end
    return nil
end

-- Expose for use in event handlers below
_Learner.GetNpcIdFromGUID    = GetNpcIdFromGUID
_Learner.GetObjectIdFromGUID = GetObjectIdFromGUID
_Learner.GetIdAndTypeFromGUID = GetIdAndTypeFromGUID

------------------------------------------------------------------------
-- Event handlers
------------------------------------------------------------------------

-- Checks whether an NPC (by npcFlags bitmask) should be learned on mouseover.
-- Only quest givers and turn-in NPCs are relevant for the learner.
local function NpcFlagsHasQuestGiver(flags)
    if not flags then return false end
    -- bitwise AND for Lua 5.1 (no bit library guaranteed)
    return math.floor(flags / NPC_FLAG_QUESTGIVER) % 2 == 1
end

function QuestieLearner:OnMouseoverUnit()
    if not UnitExists("mouseover") or not UnitIsVisible("mouseover") then return end
    if UnitIsPlayer("mouseover") then return end

    local guid = UnitGUID("mouseover")
    if not guid then return end
    if guid == _Learner._lastMouseoverGuid then return end
    _Learner._lastMouseoverGuid = guid

    local npcId = GetNpcIdFromGUID(guid)
    if not npcId or npcId <= 0 then return end

    -- Only learn this NPC if it carries the questgiver flag OR if it is already
    -- known in the database as a starter/finisher (so we can update its coords).
    local npcFlags = UnitNPCFlags and UnitNPCFlags("mouseover") or 0
    local isQuestGiver = NpcFlagsHasQuestGiver(npcFlags)

    if not isQuestGiver then
        -- Check if the DB already knows this NPC as a quest starter or finisher
        local dbNpc = QuestieDB and QuestieDB.GetNPC and QuestieDB:GetNPC(npcId)
        if dbNpc and (dbNpc[7] or dbNpc[8]) then
            -- known quest-related NPC: update coordinates only
            isQuestGiver = true
        end
    end

    if not isQuestGiver then return end

    local name = UnitName("mouseover")
    local level = UnitLevel("mouseover")
    local subName = UnitCreatureFamily and UnitCreatureFamily("mouseover") or nil
    local reaction = UnitReaction("mouseover", "player")
    local factionString = nil
    if reaction then
        if reaction >= 5 then
            factionString = UnitFactionGroup("player") == "Alliance" and "A" or "H"
        elseif reaction >= 4 then
            factionString = "AH"
        end
    end

    _Learner.guidNpcCache = _Learner.guidNpcCache or {}
    _Learner.guidNpcCache[guid] = { npcId = npcId, name = name, ts = time() }

    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieLearner] Cached mouseover NPC:", npcId, name, "guid:", guid)
    self:LearnNPC(npcId, name, level, subName, npcFlags, factionString)
end

function QuestieLearner:OnTargetChanged()
    if not UnitExists("target") or not UnitIsVisible("target") then return end
    if UnitIsPlayer("target") then return end

    local guid = UnitGUID("target")
    if not guid then return end
    if guid == _Learner._lastTargetGuid then return end
    _Learner._lastTargetGuid = guid

    local npcId = GetNpcIdFromGUID(guid)
    if not npcId or npcId <= 0 then return end

    local name = UnitName("target")
    local level = UnitLevel("target")

    _Learner.guidNpcCache = _Learner.guidNpcCache or {}
    _Learner.guidNpcCache[guid] = { npcId = npcId, name = name, ts = time() }

    -- Target changes don't guarantee a quest giver, but we still cache GUID for kill tracking
    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieLearner] Cached target NPC:", npcId, name, "guid:", guid)
end

-- Collects all available quest data from the quest detail/offer screen (before accepting)
function QuestieLearner:OnQuestDetail()
    local questId = GetQuestID and GetQuestID()
    if not questId or questId <= 0 then return end

    local data = {}
    data[1] = GetTitleText and GetTitleText() or nil
    -- requiredLevel and questLevel are not always available on the detail screen;
    -- they will be filled in by OnQuestAccepted from the quest log.
    data[6] = GetObjectiveText and GetObjectiveText() or nil   -- objectives text
    -- Details/description text (body)
    if GetQuestDescription then
        data[17] = GetQuestDescription()
    end

    -- Record current zone as zoneOrSort if not already set
    local zoneId = GetZoneId()
    if zoneId and zoneId > 0 then
        data[8] = zoneId
    end

    self:LearnQuest(questId, data)

    -- Identify the quest giver NPC or object
    local npcGuid = UnitGUID("npc")
    if npcGuid then
        local entityId, unitType = GetIdAndTypeFromGUID(npcGuid)
        if entityId and entityId > 0 then
            local entityName = UnitName("npc")
            if unitType == "GameObject" then
                self:LearnQuestGiver(questId, entityId, 2, true)
                self:LearnObject(entityId, entityName)
            elseif unitType == "Creature" or unitType == "Vehicle" then
                self:LearnQuestGiver(questId, entityId, 1, true)
                local npcFlags = UnitNPCFlags and UnitNPCFlags("npc") or 2
                self:LearnNPC(entityId, entityName, nil, nil, npcFlags, nil)
            end
        end
    end
end

function QuestieLearner:OnQuestComplete()
    local questId = GetQuestID and GetQuestID()
    if not questId or questId <= 0 then return end

    -- Capture completion/finish text
    local data = {}
    if GetRewardText then
        data[18] = GetRewardText()
    end
    self:LearnQuest(questId, data)

    -- Identify the quest turn-in NPC or object
    local npcGuid = UnitGUID("npc")
    if npcGuid then
        local entityId, unitType = GetIdAndTypeFromGUID(npcGuid)
        if entityId and entityId > 0 then
            local entityName = UnitName("npc")
            if unitType == "GameObject" then
                self:LearnQuestGiver(questId, entityId, 2, false)
                self:LearnObject(entityId, entityName)
            elseif unitType == "Creature" or unitType == "Vehicle" then
                self:LearnQuestGiver(questId, entityId, 1, false)
                local npcFlags = UnitNPCFlags and UnitNPCFlags("npc") or 2
                self:LearnNPC(entityId, entityName, nil, nil, npcFlags, nil)
            end
        end
    end
end

-- Fires after the player clicks Accept; questLogIndex and questId are available here
function QuestieLearner:OnQuestAccepted(questLogIndex, questId)
    -- Resolve questId from log index if not provided
    if not questId or questId <= 0 then
        if questLogIndex then
            local _, _, _, _, _, _, _, id = GetQuestLogTitle(questLogIndex)
            questId = id
        end
    end
    if not questId or questId <= 0 then return end

    -- Build data table from quest log entry (richest source)
    local data = {}
    if questLogIndex then
        local title, level, _, isHeader, _, isComplete, frequency, id = GetQuestLogTitle(questLogIndex)
        if not isHeader then
            data[1]  = title
            data[5]  = level and level > 0 and level or nil  -- questLevel
        end

        -- Objectives from leaderboard
        local numObj = GetNumQuestLeaderBoards and GetNumQuestLeaderBoards(questLogIndex) or 0
        if numObj > 0 then
            local objList = {}
            for i = 1, numObj do
                local text = GetQuestLogLeaderBoard and GetQuestLogLeaderBoard(i, questLogIndex)
                if text then table.insert(objList, text) end
            end
            if #objList > 0 then data[6] = objList end
        end

        -- Required money
        local reqMoney = GetQuestLogRequiredMoney and GetQuestLogRequiredMoney(questLogIndex) or 0
        if reqMoney and reqMoney > 0 then data[7] = reqMoney end
    else
        -- Fallback: use GetTitleText from the still-open quest frame
        data[1] = GetTitleText and GetTitleText() or nil
    end

    -- Zone sort: record current map zone
    local zoneId = GetZoneId()
    if zoneId and zoneId > 0 then data[8] = zoneId end

    self:LearnQuest(questId, data)
end

-- Loot handler with async GetItemInfo retry
function QuestieLearner:OnLootOpened()
    if not self:IsEnabled() then return end
    if not Questie.db.global.learnedData.settings.learnItems then return end

    local targetGuid = UnitGUID("target")
    local npcId = targetGuid and GetNpcIdFromGUID(targetGuid) or nil

    -- Also try to record the object if target is a game object
    if targetGuid then
        local objId = GetObjectIdFromGUID(targetGuid)
        if objId and objId > 0 then
            local objName = UnitName("target")
            self:LearnObject(objId, objName)
        end
    end

    local numItems = GetNumLootItems()
    for i = 1, numItems do
        local _, lootName, _, _, lootQuality = GetLootSlotInfo(i)
        if lootName then
            local link = GetLootSlotLink(i)
            if link then
                local itemId = tonumber(string.match(link, "item:(%d+)"))
                if itemId and itemId > 0 then
                    local itemName, _, _, itemLevel, requiredLevel, _, _, _, _, _, _, itemClassId, itemSubClassId = GetItemInfo(link)
                    if itemName then
                        self:LearnItem(itemId, itemName, itemLevel, requiredLevel, itemClassId, itemSubClassId)
                        if npcId then self:LearnItemDrop(itemId, npcId) end
                    else
                        -- GetItemInfo returned nil (item not in cache); queue for retry
                        table.insert(_Learner.pendingItemLinks, { link = link, itemId = itemId, npcId = npcId })
                    end
                end
            end
        end
    end
end

function QuestieLearner:OnGossipShow()
    local npcGuid = UnitGUID("npc")
    if not npcGuid then return end

    local id, unitType = GetIdAndTypeFromGUID(npcGuid)
    if not id or id <= 0 then return end

    local name = UnitName("npc")
    if unitType == "GameObject" then
        self:LearnObject(id, name)
    elseif unitType == "Creature" or unitType == "Vehicle" then
        local npcFlags = UnitNPCFlags and UnitNPCFlags("npc") or 1
        self:LearnNPC(id, name, nil, nil, npcFlags, nil)
    end
end

-- Resolves pending item info once the client has cached it
function QuestieLearner:OnGetItemInfoReceived(itemId)
    if not _Learner.pendingItemLinks then return end
    local remaining = {}
    for _, entry in ipairs(_Learner.pendingItemLinks) do
        if entry.itemId == itemId then
            local itemName, _, _, itemLevel, requiredLevel, _, _, _, _, _, _, itemClassId, itemSubClassId = GetItemInfo(entry.link)
            if itemName then
                self:LearnItem(itemId, itemName, itemLevel, requiredLevel, itemClassId, itemSubClassId)
                if entry.npcId then self:LearnItemDrop(itemId, entry.npcId) end
            else
                table.insert(remaining, entry) -- still not cached, keep
            end
        else
            table.insert(remaining, entry)
        end
    end
    _Learner.pendingItemLinks = remaining
end

------------------------------------------------------------------------
-- Combat log: kill tracking with GUID-keyed cache
------------------------------------------------------------------------

-- Returns true if npcId is referenced in any active quest objective (monster kill type)
local function IsQuestObjectiveNpc(npcId)
    if not QuestieDB then return false end
    -- Check if this NPC appears in DB as a quest NPC (spawns field [7] or quest objectives)
    local dbNpc = QuestieDB.GetNPC and QuestieDB:GetNPC(npcId)
    if dbNpc then return true end
    -- Check npcDataOverrides (from learner or plugins)
    if QuestieDB.npcDataOverrides and QuestieDB.npcDataOverrides[npcId] then return true end
    return false
end

function QuestieLearner:OnCombatLogEvent(...)
    local args = { CombatLogGetCurrentEventInfo and CombatLogGetCurrentEventInfo() or ... }
    local event    = args[2]
    local destGUID = args[8]
    local destName = args[9]

    if event ~= "UNIT_DIED" or not destGUID then return end

    local npcId = GetNpcIdFromGUID(destGUID)

    -- Fallback: GUID-keyed cache from OnTargetChanged / OnMouseoverUnit
    if not npcId and _Learner.guidNpcCache then
        local cached = _Learner.guidNpcCache[destGUID]
        if cached then
            npcId = cached.npcId
            if not destName then destName = cached.name end
        end
    end

    if not npcId or npcId <= 0 then return end

    -- Only record kill coordinates for NPCs that are known quest objective targets
    -- (already in DB, or previously cached from quest interaction).
    -- This avoids polluting the learner with every random mob kill.
    local isCached = _Learner.guidNpcCache and _Learner.guidNpcCache[destGUID] ~= nil
    if not isCached and not IsQuestObjectiveNpc(npcId) then return end

    -- TTL cleanup: drop entries older than 10 minutes
    if _Learner.guidNpcCache then
        local now = time()
        for g, cached in pairs(_Learner.guidNpcCache) do
            if (now - (cached.ts or 0)) > 600 then
                _Learner.guidNpcCache[g] = nil
            end
        end
    end

    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieLearner] UNIT_DIED: recording kill NPC", npcId, destName)
    self:LearnNPC(npcId, destName, nil, nil, nil, nil)
end

------------------------------------------------------------------------
-- Event registration
------------------------------------------------------------------------

function QuestieLearner:RegisterEvents()
    local frame = CreateFrame("Frame", "QuestieLearnerFrame")

    frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("QUEST_DETAIL")
    frame:RegisterEvent("QUEST_COMPLETE")
    frame:RegisterEvent("QUEST_ACCEPTED")
    frame:RegisterEvent("LOOT_OPENED")
    frame:RegisterEvent("GOSSIP_SHOW")
    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "UPDATE_MOUSEOVER_UNIT" then
            self:OnMouseoverUnit()
        elseif event == "PLAYER_TARGET_CHANGED" then
            self:OnTargetChanged()
        elseif event == "QUEST_DETAIL" then
            self:OnQuestDetail()
        elseif event == "QUEST_COMPLETE" then
            self:OnQuestComplete()
        elseif event == "QUEST_ACCEPTED" then
            self:OnQuestAccepted(...)
        elseif event == "LOOT_OPENED" then
            self:OnLootOpened()
        elseif event == "GOSSIP_SHOW" then
            self:OnGossipShow()
        elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
            self:OnCombatLogEvent(...)
        elseif event == "GET_ITEM_INFO_RECEIVED" then
            local itemId = ...
            self:OnGetItemInfoReceived(itemId)
        end
    end)

    Questie:Debug(Questie.DEBUG_INFO, "[QuestieLearner] Events registered")
end

------------------------------------------------------------------------
-- Initialize
------------------------------------------------------------------------

function QuestieLearner:Initialize()
    EnsureLearnedData()
    QuestieLearner.data = Questie.db.global.learnedData
    self:RegisterEvents()
    self:InjectLearnedData()
    Questie:Debug(Questie.DEBUG_INFO, "[QuestieLearner] Initialized")
end

------------------------------------------------------------------------
-- Network bridge
------------------------------------------------------------------------

function _Learner:BroadcastIfCommsAvailable(typ, id, data)
    local QuestieLearnerComms = QuestieLoader:ImportModule("QuestieLearnerComms")
    if QuestieLearnerComms and QuestieLearnerComms.BroadcastLearnedData then
        local op = (data.mc and data.mc > 1) and "UPDATE" or "NEW"
        QuestieLearnerComms:BroadcastLearnedData(op, typ, id, data)
    end
end

-- Receives validated, decoded data from QuestieLearnerComms or QuestieLearnerExport:MergeImport
function QuestieLearner:HandleNetworkData(typ, id, d)
    if not self:IsEnabled() then return end
    if not EnsureLearnedData() then return end
    if not typ or not id or not d then return end

    local store
    if typ == "NPC" then
        if not Questie.db.global.learnedData.settings.learnNpcs then return end
        store = Questie.db.global.learnedData.npcs
    elseif typ == "QUEST" then
        if not Questie.db.global.learnedData.settings.learnQuests then return end
        store = Questie.db.global.learnedData.quests
    elseif typ == "ITEM" then
        if not Questie.db.global.learnedData.settings.learnItems then return end
        store = Questie.db.global.learnedData.items
    elseif typ == "OBJECT" then
        if not Questie.db.global.learnedData.settings.learnObjects then return end
        store = Questie.db.global.learnedData.objects
    else
        return
    end

    local existing = store[id]
    if not existing then
        store[id] = d
        store[id].mc = 1
        Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieLearner] Network NEW", typ, id)
        -- Immediately inject into QuestieDB overrides
        self:InjectLearnedData()
        QuestieLearner.data = Questie.db.global.learnedData
        return
    end

    -- Merge: adopt non-nil fields we don't have locally
    for k, v in pairs(d) do
        if k ~= "mc" and existing[k] == nil then
            existing[k] = v
        end
    end

    -- Merge coordinates
    local coordKey = (typ == "NPC") and 7 or (typ == "OBJECT" and 4 or nil)
    if coordKey and type(d[coordKey]) == "table" then
        existing[coordKey] = existing[coordKey] or {}
        for zoneId, coords in pairs(d[coordKey]) do
            existing[coordKey][zoneId] = existing[coordKey][zoneId] or {}
            for _, coord in ipairs(coords) do
                InsertIfNewBucket(existing[coordKey][zoneId], coord[1], coord[2])
            end
        end
    end

    -- Merge item drop list
    if typ == "ITEM" and type(d[2]) == "table" then
        existing[2] = existing[2] or {}
        for _, npcId in ipairs(d[2]) do
            local found = false
            for _, existId in ipairs(existing[2]) do
                if existId == npcId then found = true; break end
            end
            if not found then table.insert(existing[2], npcId) end
        end
    end

    existing.mc = (existing.mc or 0) + 1
    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieLearner] Network MERGE", typ, id, "mc:", existing.mc)

    QuestieLearner.data = Questie.db.global.learnedData
end

return QuestieLearner
