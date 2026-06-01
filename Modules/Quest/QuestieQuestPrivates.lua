---@type QuestieQuest
local QuestieQuest = QuestieLoader:ImportModule("QuestieQuest")
---@type QuestieQuestPrivate
QuestieQuest.private = QuestieQuest.private or {}
---@class QuestieQuestPrivate
local _QuestieQuest = QuestieQuest.private

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type QuestieCorrections
local QuestieCorrections = QuestieLoader:ImportModule("QuestieCorrections")

local function _GetIconScaleForMonster()
    return Questie.db.profile.monsterScale or 1
end

local function _GetIconScaleForObject()
    return Questie.db.profile.objectScale or 1
end

local function _GetIconScaleForEvent()
    return Questie.db.profile.eventScale or 1.35
end

local function _GetIconScaleForLoot()
    return Questie.db.profile.lootScale or 1
end

local function _CountUniqueSpawnPositions(spawns)
    if type(spawns) ~= "table" then return 0 end

    local seen = {}
    local count = 0
    for _, coords in pairs(spawns) do
        if type(coords) == "table" then
            for _, coord in ipairs(coords) do
                local x = coord and coord[1]
                local y = coord and coord[2]
                if x and y then
                    local key = tostring(x) .. "," .. tostring(y)
                    if not seen[key] then
                        seen[key] = true
                        count = count + 1
                    end
                end
            end
        end
    end

    return count
end


---@class SpawnListBase
---@field Name string
---@field Spawns table<AreaId, CoordPair[]>>
---@field Icon string @Icon path
---@field GetIconScale function Function to get the iconScale
---@field IconScale number Initial value returned by the GetIconScale function


---@class SpawnListTooltip
---@field TooltipKey string

---@class SpawnListObject : SpawnListBase, SpawnListTooltip
---@field Id ObjectId The ID of the Object

---@class SpawnListNPC : SpawnListBase, SpawnListTooltip
---@field Id NpcId The ID of the NPC
---@field Waypoints table<AreaId, CoordPair[]>
---@field Hostile true|boolean

---@class SpawnListItem : SpawnListBase, SpawnListTooltip, SpawnListNPC, SpawnListObject
---@field Id ObjectId|NpcId The ID of the Object or Npc
---@field ItemId ItemId The ID of the item that the spawn drops

---@class SpawnListEvent : SpawnListBase
---@field Id number The ID of the Event (Is this even used?)

local killcredit, monster, object, event, item, spell

---@type table<"killcredit"|"monster"|"object"|"event"|"item", function>
_QuestieQuest.objectiveSpawnListCallTable = {}
---comment
---@param npcId NpcId
---@param objective any
---@param objectiveData KillObjective
---@return table<NpcId, SpawnListNPC>[]
killcredit = function(npcId, objective, objectiveData)
    ---@type SpawnListNPC[]
    local ret = {}
    local foundValid = false

    -- First pass: try all IDs in IdList
    if objectiveData.IdList then
        for npcIdIndex = 1, #objectiveData.IdList do
            local killCreditNpcId = objectiveData.IdList[npcIdIndex]
            if killCreditNpcId and killCreditNpcId > 0 then
                local monsterResult = monster(killCreditNpcId, objective)
                if monsterResult and monsterResult[killCreditNpcId] then
                    ret[killCreditNpcId] = monsterResult[killCreditNpcId]
                    foundValid = true
                end
            end
        end
    end

    -- Second pass: if no valid NPCs found, try name-based lookup from objective description
    -- This helps custom server quests where IdList may have 0 or wrong IDs
    if not foundValid and objective and (objective.Description or objective.text) then
        local desc = objective.Description or objective.text
        local targetName = desc:match("^%d+/%d+%s+(.+)$") or desc:match("^(.-):%s*%d+/%d+$")
        if not targetName then
            targetName = desc:gsub("%d+/%d+", ""):gsub("%d+", ""):gsub("[:!?,.%(%)]", ""):gsub("^%s+", ""):gsub("%s+$", "")
        end

        if targetName and targetName ~= "" then
            -- Search for NPC by name using the npcData table
            local npcData = QuestieDB.npcData or {}
            for searchId, npcRecord in pairs(npcData) do
                if npcRecord and npcRecord[1] and string.lower(npcRecord[1]) == string.lower(targetName) then
                    local monsterResult = monster(searchId, objective)
                    if monsterResult and monsterResult[searchId] then
                        ret[searchId] = monsterResult[searchId]
                        foundValid = true
                        Questie:Debug(Questie.DEBUG_DEVELOP, "[killcredit] Found NPC by name fallback:", searchId, targetName)
                        break
                    end
                end
            end
        end
    end

    return ret
end

---@param npcId any
---@param objective any
---@return table<NpcId, SpawnListNPC>?
monster = function(npcId, objective)
    if (not npcId) or npcId <= 0 then
        Questie:Debug(Questie.DEBUG_CRITICAL, "Invalid NPC ID passed to monster function:", npcId)
        return nil
    end

    local name = QuestieDB.QueryNPCSingle(npcId, "name")
    if not name or name == "" then
        -- Last resort: extract NPC name from objective description text.
        -- This mirrors the name-parsing logic in the killcredit function.
        if objective then
            local desc = objective.Description or objective.text
            if desc then
                name = desc:match("^%d+/%d+%s+(.+)$") or desc:match("^(.-):%s*%d+/%d+$")
                if not name then
                    name = desc:gsub("%d+/%d+", ""):gsub("[:!?,.%(%)%[%]]", ""):gsub("^%s+", ""):gsub("%s+$", "")
                end
                if name and name ~= "" then
                    Questie:Debug(Questie.DEBUG_DEVELOP, "[monster] Using objective description as name fallback for NPC:", npcId, name)
                end
            end
        end
    end
    if not name or name == "" then
        Questie:Debug(Questie.DEBUG_CRITICAL, "Name missing for NPC:", npcId)
        return nil
    end

    local spawns = QuestieDB.QueryNPCSingle(npcId, "spawns")
    if (not spawns) then
        Questie:Debug(Questie.DEBUG_CRITICAL, "Spawn data missing for NPC:", npcId)
        spawns = {}
    end

    local isLearned = false

    -- Learner safety net: when prioritizeMyData is enabled and the Learner has
    -- verified spawn data for this NPC, prefer it over compiled DB spawns.
    -- This catches edge cases where the npcDataOverrides chain doesn't fully
    -- replace retail positions (e.g. format migration gaps, timing issues).
    if Questie.IsAscension and Questie.dbLearner and Questie.dbLearner.global then
        local ld = Questie.dbLearner.global
        if ld.settings and ld.settings.enabled and ld.settings.prioritizeMyData then
            local learnedNpc = ld.npcs and ld.npcs[npcId]
            if learnedNpc then
                local learnedSpawns = learnedNpc[7]
                local threshold = ld.settings.minConfidencePins or 1
                -- Do not override Ascension-curated spawn data with raw learner data.
                -- AscensionDB hand-curates positions for Ascension-specific zones (e.g. Sunstrider)
                -- which the learner can never improve upon, and the learner coords may be in the
                -- wrong coordinate space due to Sunstrider/Eversong map-zone mismatch.
                local ascProtected = QuestieDB.ascensionOverrideKeys
                    and QuestieDB.ascensionOverrideKeys["NPC"]
                    and QuestieDB.ascensionOverrideKeys["NPC"][npcId]
                    and QuestieDB.ascensionOverrideKeys["NPC"][npcId][7]
                local hasReliableLearnedSpawns = _CountUniqueSpawnPositions(learnedSpawns) > 1
                if learnedSpawns and next(learnedSpawns) and learnedNpc.mc and learnedNpc.mc >= threshold
                        and hasReliableLearnedSpawns and not ascProtected then
                    Questie:Debug(Questie.DEBUG_DEVELOP, "[monster] Preferring learned spawns for NPC:", npcId, "(mc=" .. tostring(learnedNpc.mc) .. ")")
                    spawns = learnedSpawns
                    isLearned = true
                end
            end
        end
    end

    local rank = QuestieDB.QueryNPCSingle(npcId, "rank")

    local enableSpawns = not QuestieCorrections.questNPCBlacklist[npcId]
    local enableWaypoints = enableSpawns and 2 ~= rank -- a rare mob spawn. todo: option for this

    ---@type SpawnListNPC
    local monsterData = {
        Id = npcId,
        Name = name,
        Spawns = enableSpawns and spawns or {},
        Waypoints = enableWaypoints and QuestieDB.QueryNPCSingle(npcId, "waypoints") or {},
        Hostile = true,
        Icon = Questie.ICON_TYPE_SLAY,
        GetIconScale = _GetIconScaleForMonster,
        IconScale = _GetIconScaleForMonster(),
        TooltipKey = "m_" .. npcId, -- todo: use ID based keys
        isLearned = isLearned,
    }

    return {
        [npcId] = monsterData
    }
end

---comment
---@param objectId any
---@param objective any
---@return table<ObjectId, SpawnListObject>?
object = function(objectId, objective)
    if (not objectId) then
        Questie:Error(
            "Corrupted objective data handed to objectiveSpawnListCallTable['object']:",
            "'" .. objective.Description .. "' -",
            "Please report this error on Discord or GitHub."
        )
        return nil
    end

    local name = QuestieDB.QueryObjectSingle(objectId, "name")
    if (not name) then
        Questie:Debug(Questie.DEBUG_CRITICAL, "Name missing for object:", objectId)
        return nil
    end

    local spawns = QuestieDB.QueryObjectSingle(objectId, "spawns")
    if (not spawns) then
        Questie:Debug(Questie.DEBUG_CRITICAL, "Spawn data missing for object:", objectId)
        spawns = {}
    end


    ---@type SpawnListObject
    local retObject = {
        Id = objectId,
        Name = name,
        Spawns = spawns,
        Icon = Questie.ICON_TYPE_OBJECT,
        GetIconScale = _GetIconScaleForObject,
        IconScale = _GetIconScaleForObject(),
        TooltipKey = "o_" .. objectId,
    }

    return {
        [objectId] = retObject
    }
end

---comment
---@param eventId any
---@param objective any
---@return { [1]: SpawnListEvent }?
event = function(eventId, objective)
    local spawns = objective.Coordinates
    if (not spawns) then
        Questie:Debug(Questie.DEBUG_DEVELOP, "No coordinates for event objective:", objective.Description, "id:", eventId)
        return nil
    end

    ---@type SpawnListEvent
    local retEvent = {
        Id = eventId or 0,
        Name = objective.Description or "Event Trigger",
        Spawns = spawns,
        Icon = Questie.ICON_TYPE_EVENT,
        GetIconScale = _GetIconScaleForEvent,
        IconScale = _GetIconScaleForEvent(),
    }

    return {
        [1] = retEvent
    }
end

---comment
---@param itemId any
---@param objective any
---@return table<ItemId, SpawnListItem>?
item = function(itemId, objective)
    if (not itemId) then
        Questie:Error(
            "Corrupted objective data handed to objectiveSpawnListCallTable['item']:",
            "'" .. (objective.Description or "Unknown") .. "' -",
            "Please report this error on Discord or GitHub."
        )
        return nil
    end

    local ret = {}
    local itemData = QuestieDB:GetItem(itemId)
    if itemData and itemData.Sources and (not itemData.Hidden) then
        for _, source in pairs(itemData.Sources) do
            if _QuestieQuest.objectiveSpawnListCallTable[source.Type] and source.Type ~= "item" then -- anti-recursive-loop check, should never be possible but would be bad if it was
                local sourceList = _QuestieQuest.objectiveSpawnListCallTable[source.Type](source.Id, objective)
                if not sourceList then
                    Questie:Error("Missing objective data for", source.Type, "'", objective, "'", source.Id)
                else
                    for id, sourceData in pairs(sourceList) do
                        if (not ret[id]) then
                            local icon, GetIconScale
                            if source.Type == "object" then
                                icon = Questie.ICON_TYPE_OBJECT
                                GetIconScale = _GetIconScaleForObject
                            else
                                icon = Questie.ICON_TYPE_LOOT
                                GetIconScale = _GetIconScaleForLoot
                            end

                            ret[id] = {
                                Id = id,
                                Name = sourceData.Name,
                                Hostile = true,
                                ItemId = itemData.Id,
                                TooltipKey = sourceData.TooltipKey,
                                Spawns = {},
                                Waypoints = {},
                                Icon = icon,
                                GetIconScale = GetIconScale,
                                IconScale = GetIconScale(),
                            }
                        end
                        if sourceData.Spawns then
                            local itemSpawns = ret[id].Spawns
                            for zone, spawns in pairs(sourceData.Spawns) do
                                if (not itemSpawns[zone]) then
                                    itemSpawns[zone] = {}
                                end

                                local itemSpawnsInZone = itemSpawns[zone]
                                for _, spawn in pairs(spawns) do
                                    itemSpawnsInZone[#itemSpawnsInZone+1] = spawn
                                end
                            end
                        end
                        if sourceData.Waypoints then
                            local itemWaypoints = ret[id].Waypoints
                            for zone, spawns in pairs(sourceData.Waypoints) do
                                if (not itemWaypoints[zone]) then
                                    itemWaypoints[zone] = {}
                                end

                                local itemWaypointsInZone = itemWaypoints[zone]
                                for _, spawn in pairs(spawns) do
                                    itemWaypointsInZone[#itemWaypointsInZone+1] = spawn
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return ret
end

---comment
---@param spellId number
---@param objective any
---@return table<ItemId, SpawnListItem>?
spell = function(spellId, objective, objectiveData)
    if (not spellId) then
        Questie:Error(
            "Corrupted objective data handed to objectiveSpawnListCallTable['spell']:",
            "'" .. (objective.Description or "Unknown") .. "' -",
            "Please report this error on Discord or GitHub."
        )
        return nil
    end

    local itemSource = objectiveData.ItemSourceId

    return item(itemSource, objective)
end

_QuestieQuest.objectiveSpawnListCallTable["killcredit"] = killcredit
_QuestieQuest.objectiveSpawnListCallTable["monster"] = monster
_QuestieQuest.objectiveSpawnListCallTable["object"] = object
_QuestieQuest.objectiveSpawnListCallTable["event"] = event
_QuestieQuest.objectiveSpawnListCallTable["item"] = item
_QuestieQuest.objectiveSpawnListCallTable["spell"] = spell
