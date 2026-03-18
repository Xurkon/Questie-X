---@class QuestieLearner
local QuestieLearner = QuestieLoader:CreateModule("QuestieLearner")

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type QuestieQuest
local QuestieQuest = QuestieLoader:ImportModule("QuestieQuest")
---@type QuestiePlayer
local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")
---@type QuestLogCache
local QuestLogCache = QuestieLoader:ImportModule("QuestLogCache")

local _Learner = QuestieLearner.private or {}
QuestieLearner.private = _Learner

local floor = math.floor
local abs   = math.abs
local time  = time
local tinsert = table.insert
local ipairs = ipairs
local pairs = pairs
local next = next
local type = type
local tostring = tostring
local tonumber = tonumber
local string_trim = string.trim
local string_sub = string.sub
local string_len = string.len
local string_upper = string.upper
local select = select

-- WoW API locals
local UnitExists = UnitExists
local UnitIsVisible = UnitIsVisible
local UnitIsPlayer = UnitIsPlayer
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitLevel = UnitLevel
local UnitFactionGroup = UnitFactionGroup
local UnitReaction = UnitReaction
local UnitCreatureFamily = UnitCreatureFamily
local GetRealZoneText = GetRealZoneText
local GetTitleText = GetTitleText
local GetObjectiveText = GetObjectiveText
local GetQuestDescription = GetQuestDescription
local GetRewardText = GetRewardText
local GetQuestID = GetQuestID
local GetNumQuestLogEntries = GetNumQuestLogEntries
local GetItemInfo = GetItemInfo
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local CreateFrame = CreateFrame
local GetTime = GetTime

-- Cache for zone lookup: zoneText -> areaId
_Learner.zoneCache = {}

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

-- Minimum match count (Confidence) for a learned pin to appear on the map.
local MIN_CONFIDENCE_PINS = 2

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
local function InsertIfNewBucket(coordList, x, y, customGrid)
    local grid = customGrid or COORD_GRID
    local bx, by = floor(x / grid) * grid, floor(y / grid) * grid
    for _, coord in ipairs(coordList) do
        local cx, cy = floor(coord[1] / grid) * grid, floor(coord[2] / grid) * grid
        if cx == bx and cy == by then return false end
    end
    table.insert(coordList, {x, y})
    return true
end

-- Detects if the current map is a "Micro-Dungeon" (small interior map)
-- This is a heuristic: if we lack map data, we default to standard grid.
local function GetCustomGridPrecision()
    local uiMapId = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not uiMapId then return COORD_GRID end

    -- Known micro-dungeons or small interior maps where 2% precision is too coarse.
    -- (e.g., Northshire Abbey, Anvilmar, Crypts, etc.)
    -- For now, we use a simple list of common starting sub-zones if available.
    -- Or we could check map bounds if we had that data.
    local microDungeons = {
        [425] = 0.5, -- Northshire Abbey
        [468] = 0.5, -- Anvilmar
        [469] = 0.5, -- Coldridge Valley (Interior)
        -- Add more as needed
    }
    return microDungeons[uiMapId] or COORD_GRID
end

------------------------------------------------------------------------
-- Internal state guards
------------------------------------------------------------------------

local function EnsureLearnedData()
    if not Questie.db then return false end
    local ld = Questie.db.global.learnedData
    if not ld then
        Questie.db.global.learnedData = {
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
                minConfidencePins = 2,
                prioritizeMyData = true,
                staleThreshold   = 90,    -- days
                pruneVerified    = false, -- protect verified data by default
            },
        }
    else
        -- Backfill sub-tables that may be missing from older SavedVariables
        ld.npcs    = ld.npcs    or {}
        ld.quests  = ld.quests  or {}
        ld.items   = ld.items   or {}
        ld.objects = ld.objects or {}
        ld.settings = ld.settings or {}
        local s = ld.settings
        if s.enabled      == nil then s.enabled      = true end
        if s.learnNpcs    == nil then s.learnNpcs    = true end
        if s.learnQuests  == nil then s.learnQuests  = true end
        if s.learnItems   == nil then s.learnItems   = true end
        if s.learnObjects == nil then s.learnObjects = true end
        if s.minConfidencePins == nil then s.minConfidencePins = 2 end
        if s.prioritizeMyData == nil then s.prioritizeMyData = true end
    end
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
-- Cross-link engine
-- After ANY entity is learned, scan all other learned data and stitch
-- relationships automatically. Both learnedData (SavedVariables) and
-- live *DataOverrides tables are kept in sync.
--
-- Schema reference:
--  NPC    [7]=spawns  [10]=questStarts  [11]=questEnds
--  Object [2]=questStarts  [3]=questEnds  [4]=spawns
--  Quest  [2]=startedBy{[1]=npcIds,[2]=objIds,[3]=itemIds}
--         [3]=finishedBy{[1]=npcIds,[2]=objIds}
--         [10]=objectives{[1]={{npcId,text},...},[2]={{objId,text},...},[3]={{itemId,text},...}}
--         [11]=sourceItemId  [17]=zoneOrSort
--  Item   [2]=dropNpcs{npcId,...}  [9]=questSource (questId that gives this item)
------------------------------------------------------------------------

-- Add value to array tbl[key] if not already present. Mirrors to live override table.
local function _AddToArray(tbl, key, value, ovrTable, ovrId)
    if not tbl then return end
    tbl[key] = tbl[key] or {}
    for _, v in ipairs(tbl[key]) do if v == value then return end end
    table.insert(tbl[key], value)
    if ovrTable and ovrId then
        local ovr = ovrTable[ovrId] or {}
        ovrTable[ovrId] = ovr
        ovr[key] = ovr[key] or {}
        for _, v in ipairs(ovr[key]) do if v == value then return end end
        table.insert(ovr[key], value)
    end
end

-- Add value to nested array tbl[outerKey][innerKey] if not already present.
local function _AddToNestedArray(tbl, outerKey, innerKey, value, ovrTable, ovrId)
    if not tbl then return end
    tbl[outerKey] = tbl[outerKey] or {}
    tbl[outerKey][innerKey] = tbl[outerKey][innerKey] or {}
    for _, v in ipairs(tbl[outerKey][innerKey]) do if v == value then return end end
    table.insert(tbl[outerKey][innerKey], value)
    if ovrTable and ovrId then
        local ovr = ovrTable[ovrId] or {}
        ovrTable[ovrId] = ovr
        ovr[outerKey] = ovr[outerKey] or {}
        ovr[outerKey][innerKey] = ovr[outerKey][innerKey] or {}
        for _, v in ipairs(ovr[outerKey][innerKey]) do if v == value then return end end
        table.insert(ovr[outerKey][innerKey], value)
    end
end

-- Add {id, text} pair to quest objectives slot (quest[10][slot]).
local function _AddToQuestObjective(qData, slot, entityId, text, ovrTable, questId)
    if not qData then return end
    qData[10] = qData[10] or {}
    qData[10][slot] = qData[10][slot] or {}
    for _, entry in ipairs(qData[10][slot]) do if entry[1] == entityId then return end end
    table.insert(qData[10][slot], { entityId, text or "" })
    if ovrTable and questId then
        local ovr = ovrTable[questId] or {}
        ovrTable[questId] = ovr
        ovr[10] = ovr[10] or {}
        ovr[10][slot] = ovr[10][slot] or {}
        for _, entry in ipairs(ovr[10][slot]) do if entry[1] == entityId then return end end
        table.insert(ovr[10][slot], { entityId, text or "" })
    end
end

local function _GetDB() return Questie.db.global.learnedData end

-- Triggers QuestieQuest:UpdateQuest for every active quest in the player's log
-- that is referenced in the provided set (table with questId keys).
-- Called after cross-linking so map pins refresh immediately.
local function _RefreshActiveQuestPins(questIdSet)
    if not QuestieQuest or not QuestieQuest.UpdateQuest then return end
    if not QuestiePlayer or not QuestiePlayer.currentQuestlog then return end
    local timer = (C_Timer) or (QuestieCompat and QuestieCompat.C_Timer)
    for questId in pairs(questIdSet) do
        if QuestiePlayer.currentQuestlog[questId] then
            if timer then
                timer.After(0.1, function() QuestieQuest:UpdateQuest(questId) end)
            else
                QuestieQuest:UpdateQuest(questId)
            end
        end
    end
end

------------------------------------------------------------------------
-- CrossLinkAfterNPC: called when a new NPC is first learned.
-- Scans all learned quests for any reference to this npcId and stitches
-- back-links in both directions.
local function CrossLinkAfterNPC(npcId)
    local learned = _GetDB()
    local npcData = learned.npcs[npcId]
    if not npcData then return end
    local npcOvr = QuestieDB and QuestieDB.npcDataOverrides

    for questId, qData in pairs(learned.quests) do
        local qOvr = QuestieDB and QuestieDB.questDataOverrides

        -- Quest starters: quest[2][1] lists NPCs that start this quest
        if qData[2] and qData[2][1] then
            for _, id in ipairs(qData[2][1]) do
                if id == npcId then
                    _AddToArray(npcData, 10, questId, npcOvr, npcId)
                    break
                end
            end
        end
        -- Quest finishers: quest[3][1]
        if qData[3] and qData[3][1] then
            for _, id in ipairs(qData[3][1]) do
                if id == npcId then
                    _AddToArray(npcData, 11, questId, npcOvr, npcId)
                    break
                end
            end
        end
        -- Creature objectives: quest[10][1] — this NPC is a kill target
        -- (no back-link needed; NPC spawn data already linked via spawns[7])

        -- Item objective drop chain: quest[10][3] lists items; if any item's
        -- drop list (item[2]) includes this NPC, mark NPC as creature source.
        if qData[10] and qData[10][3] then
            for _, entry in ipairs(qData[10][3]) do
                local itemId = entry[1]
                local iData = learned.items[itemId]
                if iData and iData[2] then
                    for _, dropNpc in ipairs(iData[2]) do
                        if dropNpc == npcId then
                            -- NPC drops a quest objective item → add as creature objective
                            _AddToQuestObjective(qData, 1, npcId, nil, qOvr, questId)
                            break
                        end
                    end
                end
            end
        end
    end

    -- Refresh map pins for any active quests now linked to this NPC
    local activeRefs = {}
    if learned.quests then
        for questId, qData in pairs(learned.quests) do
            local refs = (qData[2] and qData[2][1]) or {}
            for _, id in ipairs(refs) do if id == npcId then activeRefs[questId] = true end end
            refs = (qData[3] and qData[3][1]) or {}
            for _, id in ipairs(refs) do if id == npcId then activeRefs[questId] = true end end
            if qData[10] and qData[10][1] then
                for _, entry in ipairs(qData[10][1]) do
                    if entry[1] == npcId then activeRefs[questId] = true end
                end
            end
        end
    end
    _RefreshActiveQuestPins(activeRefs)
end

------------------------------------------------------------------------
-- CrossLinkAfterQuest: called when a new quest is first learned.
-- Stitches NPCs, objects, and items referenced in the quest data.
local function CrossLinkAfterQuest(questId)
    local learned = _GetDB()
    local qData = learned.quests[questId]
    if not qData then return end
    local qOvr   = QuestieDB and QuestieDB.questDataOverrides
    local npcOvr = QuestieDB and QuestieDB.npcDataOverrides
    local objOvr = QuestieDB and QuestieDB.objectDataOverrides

    -- Starter NPCs: quest[2][1] → npc[10]
    if qData[2] and qData[2][1] then
        for _, npcId in ipairs(qData[2][1]) do
            if learned.npcs[npcId] then
                _AddToArray(learned.npcs[npcId], 10, questId, npcOvr, npcId)
            end
        end
    end
    -- Starter objects: quest[2][2] → obj[2]
    if qData[2] and qData[2][2] then
        for _, objId in ipairs(qData[2][2]) do
            if learned.objects[objId] then
                _AddToArray(learned.objects[objId], 2, questId, objOvr, objId)
            end
        end
    end
    -- Finisher NPCs: quest[3][1] → npc[11]
    if qData[3] and qData[3][1] then
        for _, npcId in ipairs(qData[3][1]) do
            if learned.npcs[npcId] then
                _AddToArray(learned.npcs[npcId], 11, questId, npcOvr, npcId)
            end
        end
    end
    -- Finisher objects: quest[3][2] → obj[3]
    if qData[3] and qData[3][2] then
        for _, objId in ipairs(qData[3][2]) do
            if learned.objects[objId] then
                _AddToArray(learned.objects[objId], 3, questId, objOvr, objId)
            end
        end
    end
    -- Source item: quest[11] → item[5] (item starts this quest, via startQuest key)
    if qData[11] and qData[11] > 0 then
        local iData = learned.items[qData[11]]
        if iData then
            if not iData[5] then
                iData[5] = questId
                if QuestieDB and QuestieDB.itemDataOverrides then
                    local ovr = QuestieDB.itemDataOverrides[qData[11]] or {}
                    QuestieDB.itemDataOverrides[qData[11]] = ovr
                    if not ovr[5] then ovr[5] = questId end
                end
            end
        end
    end
    -- Item drop chain: quest has item objectives [10][3]; if any of those
    -- items have known drop NPCs (item[2]), add those NPCs as creature objectives.
    if qData[10] and qData[10][3] then
        for _, entry in ipairs(qData[10][3]) do
            local itemId = entry[1]
            local iData = learned.items[itemId]
            if iData and iData[2] then
                for _, dropNpcId in ipairs(iData[2]) do
                    _AddToQuestObjective(qData, 1, dropNpcId, nil, qOvr, questId)
                end
            end
        end
    end
end

------------------------------------------------------------------------
-- CrossLinkAfterObject: called when a new object is first learned.
-- Scans all learned quests for references to this objectId.
local function CrossLinkAfterObject(objectId)
    local learned = _GetDB()
    local objData = learned.objects[objectId]
    if not objData then return end
    local objOvr = QuestieDB and QuestieDB.objectDataOverrides
    local qOvr   = QuestieDB and QuestieDB.questDataOverrides

    for questId, qData in pairs(learned.quests) do
        -- Object starters: quest[2][2]
        if qData[2] and qData[2][2] then
            for _, id in ipairs(qData[2][2]) do
                if id == objectId then
                    _AddToArray(objData, 2, questId, objOvr, objectId)
                    break
                end
            end
        end
        -- Object finishers: quest[3][2]
        if qData[3] and qData[3][2] then
            for _, id in ipairs(qData[3][2]) do
                if id == objectId then
                    _AddToArray(objData, 3, questId, objOvr, objectId)
                    break
                end
            end
        end
        -- Object objectives: quest[10][2] — this object is an interact target
        -- Coords are already stored in object spawns; no extra link needed
    end

    -- Refresh map pins for active quests now linked to this object
    local activeRefs = {}
    for questId, qData in pairs(learned.quests) do
        local function checkList(list)
            if list then for _, id in ipairs(list) do if id == objectId then activeRefs[questId] = true end end end
        end
        checkList(qData[2] and qData[2][2])
        checkList(qData[3] and qData[3][2])
        if qData[10] and qData[10][2] then
            for _, entry in ipairs(qData[10][2]) do
                if entry[1] == objectId then activeRefs[questId] = true end
            end
        end
    end
    _RefreshActiveQuestPins(activeRefs)
end

------------------------------------------------------------------------
-- CrossLinkAfterItem: called when an item is first learned or when a
-- new drop-NPC relationship is added to an item.
-- Links drop NPCs → quest creature objectives for any quest needing this item.
local function CrossLinkAfterItem(itemId)
    local learned = _GetDB()
    local iData = learned.items[itemId]
    if not iData then return end
    local qOvr = QuestieDB and QuestieDB.questDataOverrides

    -- If this item starts a quest (item[5]=startQuest), ensure that quest knows
    -- about it via quest[2][3] (starter items slot)
    for questId, qData in pairs(learned.quests) do
        if qData[11] == itemId then
            if not iData[5] then
                iData[5] = questId
                if QuestieDB and QuestieDB.itemDataOverrides then
                    local ovr = QuestieDB.itemDataOverrides[itemId] or {}
                    QuestieDB.itemDataOverrides[itemId] = ovr
                    if not ovr[5] then ovr[5] = questId end
                end
            end
        end
        -- If any quest has this item as an objective (quest[10][3]),
        -- and we know NPCs that drop it (item[2]), add those NPCs as creature objectives.
        if qData[10] and qData[10][3] then
            for _, entry in ipairs(qData[10][3]) do
                if entry[1] == itemId and iData[2] then
                    for _, dropNpcId in ipairs(iData[2]) do
                        _AddToQuestObjective(qData, 1, dropNpcId, nil, qOvr, questId)
                    end
                end
            end
        end
    end
end

------------------------------------------------------------------------
-- CrossLinkAfterQuestGiver: called when a starter/finisher relationship
-- is explicitly recorded. Stitches both the NPC→quest and quest→NPC
-- directions (and objects/items if typeSlot indicates them).
local function CrossLinkAfterQuestGiver(questId, entityId, typeSlot, isStart)
    local learned = _GetDB()
    local qData  = learned.quests[questId]
    local npcOvr = QuestieDB and QuestieDB.npcDataOverrides
    local objOvr = QuestieDB and QuestieDB.objectDataOverrides
    local qOvr   = QuestieDB and QuestieDB.questDataOverrides

    if typeSlot == 1 then
        -- NPC ↔ quest
        local npcData = learned.npcs[entityId]
        if npcData then
            _AddToArray(npcData, isStart and 10 or 11, questId, npcOvr, entityId)
        end
        if qData then
            _AddToNestedArray(qData, isStart and 2 or 3, 1, entityId, qOvr, questId)
        end
    elseif typeSlot == 2 then
        -- Object ↔ quest
        local objData = learned.objects[entityId]
        if objData then
            _AddToArray(objData, isStart and 2 or 3, questId, objOvr, entityId)
        end
        if qData then
            _AddToNestedArray(qData, isStart and 2 or 3, 2, entityId, qOvr, questId)
        end
    elseif typeSlot == 3 then
        -- Item ↔ quest starter (item[3] = starts quest; quest[2][3])
        if qData then
            _AddToNestedArray(qData, 2, 3, entityId, qOvr, questId)
        end
    end
end

------------------------------------------------------------------------
-- NPC learning
------------------------------------------------------------------------

function QuestieLearner:LearnNPC(npcId, name, level, subName, npcFlags, factionString, spawnX, spawnY, spawnZoneId)
    if not self:IsEnabled() then return end
    if not Questie.db.global.learnedData.settings.learnNpcs then return end
    if not npcId or npcId <= 0 then return end

    -- Use provided spawn coords (e.g. from kill event) or fall back to current player position
    local zoneId = spawnZoneId or GetZoneId()
    local x, y
    if spawnX and spawnY then
        x, y = spawnX, spawnY
    else
        x, y = GetPlayerCoords()
    end

    local existing = Questie.db.global.learnedData.npcs[npcId]
    local isNew = existing == nil
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
    if x and y and zoneId and zoneId > 0 then
        existing[7] = existing[7] or {}
        existing[7][zoneId] = existing[7][zoneId] or {}
        InsertIfNewBucket(existing[7][zoneId], x, y)
    end

    existing.ls = time() -- Update last seen
    existing.mc = (existing.mc or 0) + 1

    local threshold = (Questie.db.global.learnedData.settings and Questie.db.global.learnedData.settings.minConfidencePins) or MIN_CONFIDENCE_PINS

    -- Live injection: update npcDataOverrides only if confidence threshold is met
    if existing.mc >= threshold and QuestieDB and QuestieDB.npcDataOverrides then
        local ovr = QuestieDB.npcDataOverrides[npcId]
        if not ovr then
            QuestieDB.npcDataOverrides[npcId] = existing
        else
            -- Merge: fill missing fields only
            for k, v in pairs(existing) do
                if ovr[k] == nil then ovr[k] = v end
            end
            -- Always merge spawn coords
            if existing[7] then
                ovr[7] = ovr[7] or {}
                for zid, coords in pairs(existing[7]) do
                    ovr[7][zid] = ovr[7][zid] or {}
                    for _, coord in ipairs(coords) do
                        InsertIfNewBucket(ovr[7][zid], coord[1], coord[2])
                    end
                end
            end
        end
    end

    if isNew then
        Questie:Debug(Questie.DEBUG_LEARNER, "[QuestieLearner] New NPC learned:", npcId, name or "?")
        CrossLinkAfterNPC(npcId)
    end
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
    if not self:IsEnabled() then
        Questie:Debug(Questie.DEBUG_LEARNER, "[QuestieLearner] LearnQuest blocked: learner not enabled")
        return
    end
    if not Questie.db.global.learnedData.settings.learnQuests then
        Questie:Debug(Questie.DEBUG_LEARNER, "[QuestieLearner] LearnQuest blocked: learnQuests=", tostring(Questie.db.global.learnedData.settings.learnQuests))
        return
    end
    if not questId or questId <= 0 then return end

    local existing = Questie.db.global.learnedData.quests[questId]
    local isNew = existing == nil
    if not existing then
        existing = {}
        Questie.db.global.learnedData.quests[questId] = existing
    end

    existing.ls = time() -- Update last seen

    for k, v in pairs(data) do
        if v ~= nil and v ~= "" and v ~= 0 and existing[k] == nil then
            existing[k] = v
        end
    end

    existing.mc = (existing.mc or 0) + 1

    -- Live injection into questDataOverrides so GetQuest works without reload
    if QuestieDB and QuestieDB.questDataOverrides then
        local ovr = QuestieDB.questDataOverrides[questId]
        if not ovr then
            QuestieDB.questDataOverrides[questId] = existing
        else
            for k, v in pairs(existing) do
                if ovr[k] == nil then ovr[k] = v end
            end
        end
    end

    if isNew then
        Questie:Debug(Questie.DEBUG_LEARNER, "[QuestieLearner] New quest learned:", questId, existing[1] or "?")
        CrossLinkAfterQuest(questId)
    end
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

    -- Live injection into questDataOverrides so starters/finishers take effect without reload
    if QuestieDB and QuestieDB.questDataOverrides then
        local ovr = QuestieDB.questDataOverrides[questId] or {}
        QuestieDB.questDataOverrides[questId] = ovr
        ovr[field] = ovr[field] or {}
        ovr[field][typeSlot] = ovr[field][typeSlot] or {}
        local ovrList = ovr[field][typeSlot]
        local found = false
        for _, id in ipairs(ovrList) do
            if id == entityId then found = true; break end
        end
        if not found then table.insert(ovrList, entityId) end
    end

    -- Cross-link both directions for all entity types
    CrossLinkAfterQuestGiver(questId, entityId, typeSlot, isStart)
end

------------------------------------------------------------------------
-- Quest objective NPC learning (kill objectives)
------------------------------------------------------------------------

-- Adds npcId as a creatureObjective for questId ([10][1] in questKeys schema).
-- If the NPC already exists in the base DB the spawn data is already there;
-- we only need the quest to reference it so tooltips/map-pins get registered.
function QuestieLearner:LearnQuestObjectiveNPC(questId, npcId, objText)
    if not self:IsEnabled() then return end
    if not Questie.db.global.learnedData.settings.learnQuests then return end
    if not questId or questId <= 0 or not npcId or npcId <= 0 then return end

    -- 1. Persist to SavedVariables
    local existing = Questie.db.global.learnedData.quests[questId] or {}
    Questie.db.global.learnedData.quests[questId] = existing
    existing[10] = existing[10] or {}
    existing[10][1] = existing[10][1] or {}  -- creatureObjective slot
    local alreadyInSV = false
    for _, entry in ipairs(existing[10][1]) do
        if entry[1] == npcId then alreadyInSV = true; break end
    end
    if not alreadyInSV then
        table.insert(existing[10][1], { npcId, objText or "" })
    end

    -- 2. Apply to live questDataOverrides immediately (no reload needed)
    if QuestieDB and QuestieDB.questDataOverrides then
        local ovr = QuestieDB.questDataOverrides[questId] or {}
        QuestieDB.questDataOverrides[questId] = ovr
        ovr[10] = ovr[10] or {}
        ovr[10][1] = ovr[10][1] or {}
        local alreadyPresent = false
        for _, entry in ipairs(ovr[10][1]) do
            if entry[1] == npcId then alreadyPresent = true; break end
        end
        if not alreadyPresent then
            table.insert(ovr[10][1], { npcId, objText or "" })
        end
    end

    -- 3. Re-process the quest so PopulateObjective registers tooltips & map pins
    if QuestieQuest and QuestieQuest.UpdateQuest then
        QuestieCompat.C_Timer.After(0.5, function()
            QuestieQuest:UpdateQuest(questId)
        end)
    end

    -- 3. Register with tooltip system immediately
    local QuestieTooltips = QuestieLoader:ImportModule("QuestieTooltips")
    if QuestieTooltips and QuestieTooltips.RegisterObjectiveTooltip then
        QuestieTooltips:RegisterObjectiveTooltip(questId, "m_" .. npcId, { Index = 0, Description = objText or "Learned Objective", Update = function() end })
    end

    Questie:Debug(Questie.DEBUG_LEARNER,
        "[QuestieLearner] Quest", questId, "objective NPC learned:", npcId, objText)
end

------------------------------------------------------------------------
-- Item learning
------------------------------------------------------------------------

function QuestieLearner:LearnItem(itemId, name, itemLevel, requiredLevel, itemClass, itemSubClass)
    if not self:IsEnabled() then return end
    if not Questie.db.global.learnedData.settings.learnItems then return end
    if not itemId or itemId <= 0 then return end

    local existing = Questie.db.global.learnedData.items[itemId]
    local isNew = existing == nil
    if not existing then
        existing = {}
        Questie.db.global.learnedData.items[itemId] = existing
    end

    if name         and not existing[1]  then existing[1]  = name end
    if itemLevel    and itemLevel > 0    and not existing[9]  then existing[9]  = itemLevel end
    if requiredLevel and requiredLevel > 0 and not existing[10] then existing[10] = requiredLevel end
    if itemSubClass and not existing[13] then existing[13] = itemSubClass end
 
    existing.ls = time() -- Update last seen
    existing.mc = (existing.mc or 0) + 1

    -- Live injection into itemDataOverrides so QueryItemSingle works without reload
    if QuestieDB and QuestieDB.itemDataOverrides then
        local ovr = QuestieDB.itemDataOverrides[itemId]
        if not ovr then
            QuestieDB.itemDataOverrides[itemId] = existing
        else
            for k, v in pairs(existing) do
                if ovr[k] == nil then ovr[k] = v end
            end
        end
    end

    if isNew then
        Questie:Debug(Questie.DEBUG_LEARNER, "[QuestieLearner] New item learned:", itemId, name or "?")
        CrossLinkAfterItem(itemId)
    end
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

    existing.ls = time() -- Update last seen

    existing[2] = existing[2] or {}
    for _, id in ipairs(existing[2]) do
        if id == npcId then return end
    end
    table.insert(existing[2], npcId)

    -- Live injection: sync drop list to itemDataOverrides
    if QuestieDB and QuestieDB.itemDataOverrides then
        local ovr = QuestieDB.itemDataOverrides[itemId] or {}
        QuestieDB.itemDataOverrides[itemId] = ovr
        ovr[2] = ovr[2] or {}
        local found = false
        for _, id in ipairs(ovr[2]) do
            if id == npcId then found = true; break end
        end
        if not found then table.insert(ovr[2], npcId) end
    end

    -- New drop relationship: re-run item cross-link to chain drop NPC → quest objectives
    CrossLinkAfterItem(itemId)
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
    local isNew = existing == nil
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
 
    existing.ls = time() -- Update last seen
    existing.mc = (existing.mc or 0) + 1

    -- Live injection into objectDataOverrides so QueryObjectSingle works without reload
    if QuestieDB and QuestieDB.objectDataOverrides then
        local ovr = QuestieDB.objectDataOverrides[objectId]
        if not ovr then
            QuestieDB.objectDataOverrides[objectId] = existing
        else
            for k, v in pairs(existing) do
                if ovr[k] == nil then ovr[k] = v end
            end
            if existing[4] then
                ovr[4] = ovr[4] or {}
                for zid, coords in pairs(existing[4]) do
                    ovr[4][zid] = ovr[4][zid] or {}
                    for _, coord in ipairs(coords) do
                        InsertIfNewBucket(ovr[4][zid], coord[1], coord[2])
                    end
                end
            end
        end
    end

    if isNew then
        Questie:Debug(Questie.DEBUG_LEARNER, "[QuestieLearner] New object learned:", objectId, name or "?")
        CrossLinkAfterObject(objectId)
    end
    _Learner:BroadcastIfCommsAvailable("OBJECT", objectId, existing)
end

------------------------------------------------------------------------
-- InjectLearnedData — pushes learnedData into QuestieDB overrides
------------------------------------------------------------------------

function QuestieLearner:Sanitize(data)
    if not data or type(data) ~= "table" then return end

    -- De-duplicate coordinates if any
    -- NPCs: key 7, Objects: key 4
    for _, coordKey in ipairs({7, 4}) do
        if data[coordKey] and type(data[coordKey]) == "table" then
            for zoneId, coords in pairs(data[coordKey]) do
                local unique = {}
                local grid = COORD_GRID -- use standard for static sanitization
                for _, c in ipairs(coords) do
                    local bx, by = floor(c[1] / grid) * grid, floor(c[2] / grid) * grid
                    local key = bx .. "," .. by
                    if not unique[key] then
                        unique[key] = c
                    end
                end
                local newList = {}
                for _, c in pairs(unique) do table.insert(newList, c) end
                data[coordKey][zoneId] = newList
            end
        end
    end

    -- Trim name/text strings
    if data[1] and type(data[1]) == "string" then
        data[1] = string.trim(data[1])
    end

    return data
end

function QuestieLearner:InjectLearnedData()
    if not EnsureLearnedData() then return end

    local learned = Questie.db.global.learnedData
    local npcCount, questCount, itemCount, objectCount = 0, 0, 0, 0

    -- 1. NPCs
    for npcId, data in pairs(learned.npcs) do
        self:Sanitize(data)
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
            -- Adopt other fields if missing
            for k, v in pairs(data) do
                if k ~= "mc" and k ~= 7 and existing[k] == nil then
                    existing[k] = v
                end
            end
        end
    end

    -- 2. Quests
    for questId, data in pairs(learned.quests) do
        self:Sanitize(data)
        -- Legacy cleanup for malformed objective data
        if data[10] ~= nil then
            local ok = type(data[10]) == "table"
            if ok then
                for _, v in pairs(data[10]) do
                    if type(v) ~= "table" then ok = false; break end
                end
            end
            if not ok then data[10] = nil end
        end
        if data[8] ~= nil and type(data[8]) ~= "table" then
            data[8] = nil
        end

        if not QuestieDB.questDataOverrides[questId] then
            QuestieDB.questDataOverrides[questId] = data
            questCount = questCount + 1
        else
            local existing = QuestieDB.questDataOverrides[questId]
            for k, v in pairs(data) do
                if k ~= "mc" then
                    if k == 10 then
                        -- Special merge: add learned creatureObjective entries to [10][1]
                        existing[10] = existing[10] or {}
                        existing[10][1] = existing[10][1] or {}
                        if type(v[1]) == "table" then
                            for _, entry in ipairs(v[1]) do
                                local found = false
                                for _, ex in ipairs(existing[10][1]) do
                                    if ex[1] == entry[1] then found = true; break end
                                end
                                if not found then
                                    tinsert(existing[10][1], entry)
                                end
                            end
                        end
                    elseif existing[k] == nil then
                        existing[k] = v
                    end
                end
            end
        end
    end

    -- 3. Items
    for itemId, data in pairs(learned.items) do
        if not QuestieDB.itemDataOverrides[itemId] then
            QuestieDB.itemDataOverrides[itemId] = data
            itemCount = itemCount + 1
        end
    end

    -- 4. Objects
    for objectId, data in pairs(learned.objects) do
        self:Sanitize(data)
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
            -- Adopt other fields
            for k, v in pairs(data) do
                if k ~= "mc" and k ~= 4 and existing[k] == nil then
                    existing[k] = v
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
                local nid = low32 % 8388608
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
        -- Silently check raw table — do NOT call GetNPC which logs CRITICAL for every miss
        local rawNpc = QuestieDB and QuestieDB.npcData and QuestieDB.npcData[npcId]
        if rawNpc and (rawNpc[10] or rawNpc[11]) then
            -- known quest starter (key 10) or quest ender (key 11)
            isQuestGiver = true
        end
    end

    if not isQuestGiver then return end

    local name = UnitName("mouseover")
    local level = UnitLevel("mouseover")
    local zoneText = GetRealZoneText()
    local areaId = _Learner.zoneCache[zoneText]
    if not areaId then
        local l10n = QuestieLoader:ImportModule("l10n")
        areaId = l10n:GetAreaIdByLocalName(zoneText)
        if areaId then
            _Learner.zoneCache[zoneText] = areaId
        end
    end
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

-- Fires when a quest is accepted.
-- Ascension 3.3.5 passes the quest log index as the first arg; some builds pass questID directly.
-- We detect which by checking if the value could be a log index and resolving via GetQuestLogTitle.
function QuestieLearner:OnQuestAccepted(firstArg, secondArg)
    Questie:Debug(Questie.DEBUG_LEARNER, "[QuestieLearner] OnQuestAccepted raw args: first=" .. tostring(firstArg) .. " second=" .. tostring(secondArg))
    local questId

    -- Try secondArg first (WotLK standard: logIndex, questID)
    if secondArg and type(secondArg) == "number" and secondArg > 0 then
        questId = secondArg
    end

    -- If secondArg was nil/0, firstArg might already be the questID (some 3.3.5 servers),
    -- or it's the log index — try resolving it from the log.
    if not questId or questId <= 0 then
        local maxLog = GetNumQuestLogEntries and GetNumQuestLogEntries() or 25
        if firstArg and type(firstArg) == "number" and firstArg > 0 then
            -- If firstArg looks like a log index (small number), look it up
            if firstArg <= maxLog then
                local resolvedId = QuestieCompat.GetQuestIDFromLogIndex(firstArg)
                Questie:Debug(Questie.DEBUG_LEARNER, "[QuestieLearner] OnQuestAccepted resolved from log index", firstArg, "->", tostring(resolvedId))
                if resolvedId and resolvedId > 0 then
                    questId = resolvedId
                end
            end
            -- Still no questId: scan entire log for recently added quests
            if not questId or questId <= 0 then
                questId = firstArg  -- last resort, may be wrong
            end
        end
    end

    Questie:Debug(Questie.DEBUG_LEARNER, "[QuestieLearner] OnQuestAccepted id=" .. tostring(questId))
    if not questId or questId <= 0 then return end

    -- Build data table from quest log (scan for matching entry)
    -- Only store fields that match the questKeys schema (name=1, questLevel=5).
    -- Do NOT store objectives (key 10) as raw text — the DB compiler expects structured
    -- {creatureId, text} tuples; plain strings crash pairs() in GetQuest.
    local data = {}
    for i = 1, GetNumQuestLogEntries() do
        local title, level, _, isHeader, _, _, _, id = QuestieCompat.GetQuestLogTitle(i)
        if not isHeader and id == questId then
            data[1] = title
            data[5] = level and level > 0 and level or nil
            break
        end
    end

    -- Zone: reverse-lookup from GetRealZoneText() which is always accurate on 3.3.5.
    local zoneText = GetRealZoneText()
    if zoneText and zoneText ~= "" then
        for _, zoneTable in pairs(l10n.zoneLookup) do
            for areaId, name in pairs(zoneTable) do
                if name == zoneText then
                    data[17] = areaId
                    break
                end
            end
            if data[17] then break end
        end
    end

    self:LearnQuest(questId, data)

    -- Associate the quest giver: prefer live UnitGUID("npc"), fall back to last gossip entity
    -- (for Objectives Board quests, GOSSIP_CLOSED fires before QUEST_ACCEPTED so "npc" is nil)
    local npcGuid = UnitGUID("npc")
    local giverEntity = nil
    if npcGuid then
        local entityId, unitType = GetIdAndTypeFromGUID(npcGuid)
        if entityId and entityId > 0 then
            giverEntity = { id = entityId, name = UnitName("npc"), unitType = unitType }
        end
    end
    if not giverEntity and _Learner._lastGossipEntity then
        giverEntity = _Learner._lastGossipEntity
    end
    if giverEntity then
        if giverEntity.unitType == "GameObject" then
            self:LearnQuestGiver(questId, giverEntity.id, 2, true)
            self:LearnObject(giverEntity.id, giverEntity.name)
        elseif giverEntity.unitType == "Creature" or giverEntity.unitType == "Vehicle" then
            self:LearnQuestGiver(questId, giverEntity.id, 1, true)
            local npcFlags = (npcGuid and UnitNPCFlags and UnitNPCFlags("npc")) or 1
            self:LearnNPC(giverEntity.id, giverEntity.name, nil, nil, npcFlags, nil)
        end
    end
end

-- Fires when any quest is turned in (covers auto-complete quests that skip the QUEST_COMPLETE dialog)
function QuestieLearner:OnQuestTurnedIn(questId, xpReward, moneyReward)
    if not self:IsEnabled() then return end
    if not Questie.db.global.learnedData.settings.learnQuests then return end
    if not questId or questId <= 0 then return end

    local data = {}
    -- Capture turn-in NPC/object while the gossip unit is still set
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
                        -- Only record quest items (class 12)
                        if itemClassId == 12 then
                            self:LearnItem(itemId, itemName, itemLevel, requiredLevel, itemClassId, itemSubClassId)
                            if npcId then self:LearnItemDrop(itemId, npcId) end
                        end
                    else
                        -- GetItemInfo returned nil; queue for retry (class check happens on retry)
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
    -- Cache the last gossip entity so OnQuestAccepted can associate it after GOSSIP_CLOSED
    _Learner._lastGossipEntity = { id = id, name = name, unitType = unitType, guid = npcGuid }

    if unitType == "GameObject" then
        self:LearnObject(id, name)
    elseif unitType == "Creature" or unitType == "Vehicle" then
        local npcFlags = UnitNPCFlags and UnitNPCFlags("npc") or 1
        self:LearnNPC(id, name, nil, nil, npcFlags, nil)
    end
end

function QuestieLearner:LearnSpellCast(spellId, spellName, dstGUID, dstName)
    if not spellId or not spellName then return end

    local npcId = dstGUID and GetNpcIdFromGUID(dstGUID)
    local objId = dstGUID and GetObjectIdFromGUID(dstGUID)

    -- Check if this spell is a quest objective
    for i = 1, GetNumQuestLogEntries() do
        local _, _, _, isHeader, _, _, _, questId = QuestieCompat.GetQuestLogTitle(i)
        if not isHeader and questId and questId > 0 then
            local quest = QuestLogCache.GetQuest(questId)
            if quest and quest.objectives then
                for _, obj in pairs(quest.objectives) do
                    -- If the objective is a spell or requires this spell
                    if obj.type == "spell" and obj.text and obj.text:find(spellName, 1, true) then
                        Questie:Debug(Questie.DEBUG_LEARNER, "[QuestieLearner] Learning spell cast:", spellId, spellName, "on", dstName or "nil")
                        Questie:Debug(Questie.DEBUG_LEARNER, "[QuestieLearner] Found spell objective match for quest", questId)
                        local data = { [10] = { [1] = {} } }
                        if npcId then
                            tinsert(data[10][1], { npcId, spellName })
                        elseif objId then
                            -- Store object as target if applicable
                            tinsert(data[10][1], { -objId, spellName })
                        end
                        self:LearnQuest(questId, data)
                    end
                end
            end
        end
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
                -- Only record quest items (class 12)
                if itemClassId == 12 then
                    self:LearnItem(itemId, itemName, itemLevel, requiredLevel, itemClassId, itemSubClassId)
                    if entry.npcId then self:LearnItemDrop(itemId, entry.npcId) end
                end
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

-- Extract the NPC entry ID from a GUID string.
-- Supports both modern string format (Creature-0-...-entryID) and
-- 3.3.5a/Ascension hex format (0x[4-char prefix][6-char entryID][spawn]).
-- Logic mirrors DataExporter's DE:GetCreatureIDFromGUID.
local function GetNpcIdFromGUID(guid)
    if not guid or type(guid) ~= "string" then return nil end

    -- Modern string format: "Creature-0-XXXX-XXXX-XXXX-entryID-XXXX"
    local strId = guid:match("Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    if strId then return tonumber(strId) end

    -- 3.3.5a / Ascension hex format: 0x[prefix:4][entryID:6][spawn:...]
    if guid:match("^0x") then
        local hex = guid:sub(3)
        local prefix = hex:sub(1, 4)

        -- Known creature prefixes (F130/F131 = standard WotLK, F110/F111 = Ascension)
        local isCreature = (
            prefix == "F130" or prefix == "F131" or
            prefix == "F110" or prefix == "F111" or
            prefix == "F150" or prefix == "F151" or
            (prefix:sub(1,1) == "F" and prefix ~= "F140" and prefix ~= "F141")
        )
        if not isCreature then return nil end

        -- Entry ID sits at hex chars 5-10 (6 hex chars = 24-bit field)
        if #hex >= 10 then
            local id = tonumber(hex:sub(5, 10), 16)
            if id and id > 0 then return id end
        end
        -- Fallback for shorter GUIDs
        if #hex >= 8 then
            local id = tonumber(hex:sub(5, 8), 16)
            if id and id > 0 then return id end
        end
    end

    return nil
end

-- Same logic for game objects (interactable quest objects)
local function GetObjectIdFromGUID(guid)
    if not guid or type(guid) ~= "string" then return nil end

    local strId = guid:match("GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    if strId then return tonumber(strId) end

    if guid:match("^0x") then
        local hex = guid:sub(3)
        if #hex >= 10 then
            local id = tonumber(hex:sub(5, 10), 16)
            if id and id > 0 then return id end
        end
        if #hex >= 8 then
            local id = tonumber(hex:sub(5, 8), 16)
            if id and id > 0 then return id end
        end
    end

    return nil
end

-- Cache recent kills: guid → {npcId, name, x, y, zoneId, ts}
_Learner.recentKills = _Learner.recentKills or {}
-- Previous objective counts for active quests: questId → {[idx] = count}
_Learner.prevObjCounts = _Learner.prevObjCounts or {}

function QuestieLearner:OnCombatLogEvent(...)
    local timestamp, eventType, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName = ...
    -- In some versions (Retail/WotLK), we should use CombatLogGetCurrentEventInfo()
    if not timestamp and CombatLogGetCurrentEventInfo then
        timestamp, eventType, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName = CombatLogGetCurrentEventInfo()
    end

    if eventType == "SPELL_CAST_SUCCESS" then
        if srcGUID == UnitGUID("player") then
            self:LearnSpellCast(spellId, spellName, dstGUID, dstName)
        end
        return
    end

    if eventType ~= "PARTY_KILL" and eventType ~= "UNIT_DIED" then return end
    if not dstGUID then return end

    local npcId = GetNpcIdFromGUID(dstGUID)

    if not npcId and _Learner.guidNpcCache then
        local cached = _Learner.guidNpcCache[dstGUID]
        if cached then
            npcId = cached.npcId
            if not dstName then dstName = cached.name end
        end
    end

    if not npcId or npcId <= 0 then return end

    local _mapId, px, py = QuestieCompat.GetCurrentPlayerPosition()
    if px and py and px > 0 and py > 0 then
        px = floor(px * 10000) / 100
        py = floor(py * 10000) / 100
    end
    local zoneId  = GetZoneId()
    local zoneText = GetRealZoneText and GetRealZoneText() or ""
    _Learner.recentKills[dstGUID] = {
        npcId  = npcId,
        name   = dstName or "",
        x      = px,
        y      = py,
        zoneId = zoneId,
        zone   = zoneText,
        ts     = time(),
    }

    if dstName and dstName ~= "" then
        Questie:Debug(Questie.DEBUG_LEARNER, "[QuestieLearner] Kill cached for correlation:", npcId, dstName, "@", tostring(px), tostring(py), "zone", tostring(zoneId))
    end

    -- TTL cleanup: drop entries older than 10 minutes
    local now = time()
    for g, entry in pairs(_Learner.recentKills) do
        if (now - (entry.ts or 0)) > 600 then
            _Learner.recentKills[g] = nil
        end
    end
end

-- Periodic cleanup for guidNpcCache to prevent unbounded growth
function QuestieLearner:PruneGuidNpcCache()
    if not _Learner.guidNpcCache then return end
    local now = time()
    local count = 0
    -- Prune entries older than 2 hours. This is used for combat log correlation
    -- and doesn't need to persist indefinitely.
    for guid, entry in pairs(_Learner.guidNpcCache) do
        if entry.ts and (now - entry.ts) > 7200 then
            _Learner.guidNpcCache[guid] = nil
            count = count + 1
        end
    end
    if count > 0 then
        Questie:Debug(Questie.DEBUG_LEARNER, "[QuestieLearner] Pruned", count, "entries from guidNpcCache")
    end
end

-- Clear objective tracking for a specific quest
function QuestieLearner:ClearQuestObjectiveTracking(questId)
    if not questId then return end
    if _Learner.prevObjCounts and _Learner.prevObjCounts[questId] then
        _Learner.prevObjCounts[questId] = nil
        Questie:Debug(Questie.DEBUG_LEARNER, "[QuestieLearner] Cleared prevObjCounts for quest", questId)
    end
end

-- Fired when quest objectives update — correlate with recent kills to learn objective NPCs
function QuestieLearner:OnQuestLogUpdate()
    local numEntries = GetNumQuestLogEntries()
    for i = 1, numEntries do
        local _, _, _, isHeader, _, _, _, questId = QuestieCompat.GetQuestLogTitle(i)
        if not isHeader and questId and questId > 0 then
            local numObj = GetNumQuestLeaderBoards and GetNumQuestLeaderBoards(i) or 0
            Questie:Debug(Questie.DEBUG_LEARNER, "[QuestieLearner] OnQuestLogUpdate scanning quest", questId, "logIdx", i, "numObj", numObj)
            _Learner.prevObjCounts[questId] = _Learner.prevObjCounts[questId] or {}
            for j = 1, numObj do
                local objText, objType, finished = GetQuestLogLeaderBoard(j, i)
                -- Accept "monster", "item", or nil/unknown types — custom server quests
                -- may report a different type string. Skip only finished objectives.
                if not finished and objText then
                    -- Parse "Kill Felboar: 3/40" or "Felboar slain 3/40" → count = 3
                    local count = tonumber(objText:match(":?%s*(%d+)%s*/"))
                    local prev  = _Learner.prevObjCounts[questId][j]

                    Questie:Debug(Questie.DEBUG_LEARNER,
                        "[QuestieLearner] OnQuestLogUpdate quest", questId,
                        "obj", j, "type:", tostring(objType),
                        "count:", tostring(count), "prev:", tostring(prev),
                        "text:", tostring(objText))

                    -- Seed on first sight; only correlate on confirmed increase
                    if prev == nil then
                        _Learner.prevObjCounts[questId][j] = count or 0
                    elseif count and count > prev then
                        local now = time()
                        local bestGuid, bestKill = nil, nil
                        for guid, kill in pairs(_Learner.recentKills) do
                            if (now - kill.ts) <= 10 then
                                if not bestKill or kill.ts > bestKill.ts then
                                    bestGuid, bestKill = guid, kill
                                end
                            end
                        end
                        if bestKill and bestKill.npcId then
                            local cleanText = objText:match("^(.-)%s*:") or (bestKill.name or "")
                            Questie:Debug(Questie.DEBUG_LEARNER,
                                "[QuestieLearner] Quest", questId, "obj", j,
                                "progressed — learning kill NPC:", bestKill.npcId, bestKill.name)
                            -- Pass exact kill coordinates so spawn list reflects NPC location, not player location
                            self:LearnNPC(bestKill.npcId, bestKill.name, nil, nil, nil, nil, bestKill.x, bestKill.y, bestKill.zoneId)
                            self:LearnQuestObjectiveNPC(questId, bestKill.npcId, cleanText)
                            _Learner.recentKills[bestGuid] = nil
                        end
                        _Learner.prevObjCounts[questId][j] = count
                    end
                end
            end
        end
    end
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
    frame:RegisterEvent("QUEST_TURNED_IN")
    frame:RegisterEvent("QUEST_ACCEPTED")
    frame:RegisterEvent("LOOT_OPENED")
    frame:RegisterEvent("GOSSIP_SHOW")
    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    frame:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
    frame:RegisterEvent("QUEST_REMOVED")

    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "UPDATE_MOUSEOVER_UNIT" then
            self:OnMouseoverUnit()
        elseif event == "PLAYER_TARGET_CHANGED" then
            self:OnTargetChanged()
        elseif event == "QUEST_DETAIL" then
            self:OnQuestDetail()
        elseif event == "QUEST_COMPLETE" then
            self:OnQuestComplete()
        elseif event == "QUEST_TURNED_IN" then
            self:OnQuestTurnedIn(...)
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
        elseif event == "UNIT_QUEST_LOG_CHANGED" then
            self:OnQuestLogUpdate()
        elseif event == "QUEST_REMOVED" or event == "QUEST_TURNED_IN" then
            local questId = ...
            self:ClearQuestObjectiveTracking(questId)
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

    -- Start periodic cleanup ticker (every 30 mins)
    QuestieCompat.C_Timer.NewTicker(1800, function()
        self:PruneGuidNpcCache()
    end)

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
function QuestieLearner:HandleNetworkData(typ, id, d, op)
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
        self:InjectLearnedData()
        QuestieLearner.data = Questie.db.global.learnedData
        return
    end

    local changed = false
    -- Merge: adopt non-nil fields we don't have locally
    for k, v in pairs(d) do
        if k ~= "mc" and existing[k] == nil then
            existing[k] = v
            changed = true
        end
    end

    -- Merge coordinates
    local coordKey = (typ == "NPC") and 7 or (typ == "OBJECT" and 4 or nil)
    if coordKey and type(d[coordKey]) == "table" then
        existing[coordKey] = existing[coordKey] or {}
        local grid = GetCustomGridPrecision()
        for zoneId, coords in pairs(d[coordKey]) do
            existing[coordKey][zoneId] = existing[coordKey][zoneId] or {}
            for _, coord in ipairs(coords) do
                if InsertIfNewBucket(existing[coordKey][zoneId], coord[1], coord[2], grid) then
                    changed = true
                end
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
            if not found then
                table.insert(existing[2], npcId)
                changed = true
            end
        end
    end

    if changed or (op == "NEW" or op == "UPDATE") then
        existing.ls = time() -- Refresh timestamp on network confirmation
        existing.mc = (existing.mc or 0) + 1
        QuestieLearner.data = Questie.db.global.learnedData
        self:InjectLearnedData()
    end
end

return QuestieLearner
