---@class QuestieLearner
local QuestieLearner = QuestieLoader:CreateModule("QuestieLearner")

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")

local _Learner = QuestieLearner.private or {}
QuestieLearner.private = _Learner

local floor = math.floor

_Learner.pendingNpcs = {}
_Learner.pendingQuests = {}
_Learner.pendingItems = {}
_Learner.pendingObjects = {}

local function GetZoneId()
    local mapId = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if mapId then return mapId end
    return GetRealZoneText() and select(8, GetInstanceInfo()) or 0
end

local function GetPlayerCoords()
    local x, y = GetPlayerMapPosition("player")
    if x and y and x > 0 and y > 0 then
        return floor(x * 100 * 100) / 100, floor(y * 100 * 100) / 100
    end
    return nil, nil
end

local function EnsureLearnedData()
    if not Questie.db then return false end
    Questie.db.global.learnedData = Questie.db.global.learnedData or {
        npcs = {},
        quests = {},
        items = {},
        objects = {},
        settings = {
            enabled = true,
            learnNpcs = true,
            learnQuests = true,
            learnItems = true,
            learnObjects = true,
        },
    }
    return true
end

function QuestieLearner:IsEnabled()
    if not EnsureLearnedData() then return false end
    return Questie.db.global.learnedData.settings.enabled
end

function QuestieLearner:GetSettings()
    if not EnsureLearnedData() then return {} end
    return Questie.db.global.learnedData.settings
end

function QuestieLearner:LearnNPC(npcId, name, level, subName, npcFlags, factionString)
    if not self:IsEnabled() then return end
    if not Questie.db.global.learnedData.settings.learnNpcs then return end
    if not npcId or npcId <= 0 then return end

    local zoneId = GetZoneId()
    local x, y = GetPlayerCoords()

    local existing = Questie.db.global.learnedData.npcs[npcId]
    if not existing then
        existing = {}
        Questie.db.global.learnedData.npcs[npcId] = existing
    end

    if name and not existing[1] then existing[1] = name end
    if level then
        if not existing[4] or level < existing[4] then existing[4] = level end
        if not existing[5] or level > existing[5] then existing[5] = level end
    end
    if zoneId and zoneId > 0 and not existing[9] then existing[9] = zoneId end
    if factionString and not existing[13] then existing[13] = factionString end
    if subName and not existing[14] then existing[14] = subName end
    if npcFlags and npcFlags > 0 and not existing[15] then existing[15] = npcFlags end

    if x and y and zoneId then
        existing[7] = existing[7] or {}
        existing[7][zoneId] = existing[7][zoneId] or {}
        local found = false
        for _, coord in ipairs(existing[7][zoneId]) do
            if math.abs(coord[1] - x) < 1 and math.abs(coord[2] - y) < 1 then
                found = true
                break
            end
        end
        if not found then
            table.insert(existing[7][zoneId], { x, y })
        end
    end

    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieLearner] Learned NPC:", npcId, name or "?")
end

function QuestieLearner:LearnQuest(questId, name, questLevel, requiredLevel, zoneOrSort, objectives)
    if not self:IsEnabled() then return end
    if not Questie.db.global.learnedData.settings.learnQuests then return end
    if not questId or questId <= 0 then return end

    local existing = Questie.db.global.learnedData.quests[questId]
    if not existing then
        existing = {}
        Questie.db.global.learnedData.quests[questId] = existing
    end

    if name and not existing[1] then existing[1] = name end
    if requiredLevel and requiredLevel > 0 and not existing[4] then existing[4] = requiredLevel end
    if questLevel and questLevel > 0 and not existing[5] then existing[5] = questLevel end
    if zoneOrSort and zoneOrSort ~= 0 and not existing[17] then existing[17] = zoneOrSort end
    if objectives and not existing[8] then
        if type(objectives) == "table" then
            existing[8] = objectives
        elseif type(objectives) == "string" then
            existing[8] = { objectives }
        end
    end

    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieLearner] Learned Quest:", questId, name or "?")
end

function QuestieLearner:LearnQuestGiver(questId, npcId, isStart)
    if not self:IsEnabled() then return end
    if not Questie.db.global.learnedData.settings.learnQuests then return end
    if not questId or questId <= 0 or not npcId or npcId <= 0 then return end

    local existing = Questie.db.global.learnedData.quests[questId]
    if not existing then
        existing = {}
        Questie.db.global.learnedData.quests[questId] = existing
    end

    if isStart then
        existing[2] = existing[2] or {}
        existing[2][1] = existing[2][1] or {}
        local found = false
        for _, id in ipairs(existing[2][1]) do
            if id == npcId then
                found = true; break
            end
        end
        if not found then table.insert(existing[2][1], npcId) end
    else
        existing[3] = existing[3] or {}
        existing[3][1] = existing[3][1] or {}
        local found = false
        for _, id in ipairs(existing[3][1]) do
            if id == npcId then
                found = true; break
            end
        end
        if not found then table.insert(existing[3][1], npcId) end
    end
end

function QuestieLearner:LearnItem(itemId, name, itemLevel, requiredLevel, itemClass, itemSubClass)
    if not self:IsEnabled() then return end
    if not Questie.db.global.learnedData.settings.learnItems then return end
    if not itemId or itemId <= 0 then return end

    local existing = Questie.db.global.learnedData.items[itemId]
    if not existing then
        existing = {}
        Questie.db.global.learnedData.items[itemId] = existing
    end

    if name and not existing[1] then existing[1] = name end
    if itemLevel and itemLevel > 0 and not existing[9] then existing[9] = itemLevel end
    if requiredLevel and requiredLevel > 0 and not existing[10] then existing[10] = requiredLevel end
    if itemClass and not existing[12] then existing[12] = itemClass end
    if itemSubClass and not existing[13] then existing[13] = itemSubClass end

    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieLearner] Learned Item:", itemId, name or "?")
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
    local found = false
    for _, id in ipairs(existing[2]) do
        if id == npcId then
            found = true; break
        end
    end
    if not found then table.insert(existing[2], npcId) end
end

function QuestieLearner:LearnObject(objectId, name)
    if not self:IsEnabled() then return end
    if not Questie.db.global.learnedData.settings.learnObjects then return end
    if not objectId or objectId <= 0 then return end

    local zoneId = GetZoneId()
    local x, y = GetPlayerCoords()

    local existing = Questie.db.global.learnedData.objects[objectId]
    if not existing then
        existing = {}
        Questie.db.global.learnedData.objects[objectId] = existing
    end

    if name and not existing[1] then existing[1] = name end
    if zoneId and zoneId > 0 and not existing[5] then existing[5] = zoneId end

    if x and y and zoneId then
        existing[4] = existing[4] or {}
        existing[4][zoneId] = existing[4][zoneId] or {}
        local found = false
        for _, coord in ipairs(existing[4][zoneId]) do
            if math.abs(coord[1] - x) < 1 and math.abs(coord[2] - y) < 1 then
                found = true
                break
            end
        end
        if not found then
            table.insert(existing[4][zoneId], { x, y })
        end
    end

    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieLearner] Learned Object:", objectId, name or "?")
end

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
                        local found = false
                        for _, existCoord in ipairs(existing[7][zoneId]) do
                            if math.abs(existCoord[1] - coord[1]) < 1 and math.abs(existCoord[2] - coord[2]) < 1 then
                                found = true
                                break
                            end
                        end
                        if not found then
                            table.insert(existing[7][zoneId], coord)
                        end
                    end
                end
            end
        end
    end

    for questId, data in pairs(learned.quests) do
        if not QuestieDB.questDataOverrides[questId] then
            QuestieDB.questDataOverrides[questId] = data
            questCount = questCount + 1
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
                        local found = false
                        for _, existCoord in ipairs(existing[4][zoneId]) do
                            if math.abs(existCoord[1] - coord[1]) < 1 and math.abs(existCoord[2] - coord[2]) < 1 then
                                found = true
                                break
                            end
                        end
                        if not found then
                            table.insert(existing[4][zoneId], coord)
                        end
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

function QuestieLearner:GetStats()
    if not EnsureLearnedData() then return 0, 0, 0, 0 end
    local learned = Questie.db.global.learnedData
    local npcCount, questCount, itemCount, objectCount = 0, 0, 0, 0
    for _ in pairs(learned.npcs) do npcCount = npcCount + 1 end
    for _ in pairs(learned.quests) do questCount = questCount + 1 end
    for _ in pairs(learned.items) do itemCount = itemCount + 1 end
    for _ in pairs(learned.objects) do objectCount = objectCount + 1 end
    return npcCount, questCount, itemCount, objectCount
end

function QuestieLearner:ClearAllData()
    if not EnsureLearnedData() then return end
    Questie.db.global.learnedData.npcs = {}
    Questie.db.global.learnedData.quests = {}
    Questie.db.global.learnedData.items = {}
    Questie.db.global.learnedData.objects = {}
    Questie:Print("Cleared all learned data.")
end

function QuestieLearner:ExportData()
    if not EnsureLearnedData() then return "" end
    local learned = Questie.db.global.learnedData
    local lines = {}

    table.insert(lines, "-- QuestieLearner Export")
    table.insert(lines, "-- NPCs: " .. select(1, self:GetStats()))
    table.insert(lines, "-- Quests: " .. select(2, self:GetStats()))
    table.insert(lines, "-- Items: " .. select(3, self:GetStats()))
    table.insert(lines, "-- Objects: " .. select(4, self:GetStats()))
    table.insert(lines, "")
    table.insert(lines, "QuestieLearnerExport = {")
    table.insert(lines, "  npcs = " .. self:SerializeTable(learned.npcs) .. ",")
    table.insert(lines, "  quests = " .. self:SerializeTable(learned.quests) .. ",")
    table.insert(lines, "  items = " .. self:SerializeTable(learned.items) .. ",")
    table.insert(lines, "  objects = " .. self:SerializeTable(learned.objects) .. ",")
    table.insert(lines, "}")

    return table.concat(lines, "\n")
end

function QuestieLearner:SerializeTable(t, indent)
    indent = indent or ""
    if type(t) ~= "table" then
        if type(t) == "string" then
            return string.format("%q", t)
        end
        return tostring(t)
    end

    local parts = {}
    local isArray = #t > 0
    for k, v in pairs(t) do
        local key = isArray and "" or ("[" .. (type(k) == "string" and string.format("%q", k) or tostring(k)) .. "]=")
        table.insert(parts, key .. self:SerializeTable(v, indent .. "  "))
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

function QuestieLearner:RegisterEvents()
    local frame = CreateFrame("Frame", "QuestieLearnerFrame")

    frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("QUEST_DETAIL")
    frame:RegisterEvent("QUEST_COMPLETE")
    frame:RegisterEvent("QUEST_ACCEPTED")
    frame:RegisterEvent("LOOT_OPENED")
    frame:RegisterEvent("GOSSIP_SHOW")

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
        end
    end)

    Questie:Debug(Questie.DEBUG_INFO, "[QuestieLearner] Events registered")
end

function QuestieLearner:OnMouseoverUnit()
    if not UnitExists("mouseover") or not UnitIsVisible("mouseover") then return end
    if UnitIsPlayer("mouseover") then return end

    local guid = UnitGUID("mouseover")
    if not guid then return end

    local unitType, _, _, _, _, npcId = strsplit("-", guid)
    if unitType ~= "Creature" and unitType ~= "Vehicle" then return end

    npcId = tonumber(npcId)
    if not npcId or npcId <= 0 then return end

    local name = UnitName("mouseover")
    local level = UnitLevel("mouseover")
    local reaction = UnitReaction("mouseover", "player")
    local factionString = nil
    if reaction then
        if reaction >= 5 then
            factionString = UnitFactionGroup("player") == "Alliance" and "A" or "H"
        elseif reaction >= 4 then
            factionString = "AH"
        end
    end

    self:LearnNPC(npcId, name, level, nil, nil, factionString)
end

function QuestieLearner:OnTargetChanged()
    if not UnitExists("target") or not UnitIsVisible("target") then return end
    if UnitIsPlayer("target") then return end

    local guid = UnitGUID("target")
    if not guid then return end

    local unitType, _, _, _, _, npcId = strsplit("-", guid)
    if unitType ~= "Creature" and unitType ~= "Vehicle" then return end

    npcId = tonumber(npcId)
    if not npcId or npcId <= 0 then return end

    local name = UnitName("target")
    local level = UnitLevel("target")

    self:LearnNPC(npcId, name, level, nil, nil, nil)
end

function QuestieLearner:OnQuestDetail()
    local questId = GetQuestID and GetQuestID()
    if not questId or questId <= 0 then return end

    local title = GetTitleText()
    local questLevel = 0
    local objectives = GetObjectiveText and GetObjectiveText()

    self:LearnQuest(questId, title, questLevel, 0, nil, objectives)

    local npcGuid = UnitGUID("npc")
    if npcGuid then
        local unitType, _, _, _, _, npcId = strsplit("-", npcGuid)
        if unitType == "Creature" or unitType == "Vehicle" then
            npcId = tonumber(npcId)
            if npcId and npcId > 0 then
                self:LearnQuestGiver(questId, npcId, true)
                local npcName = UnitName("npc")
                self:LearnNPC(npcId, npcName, nil, nil, 2, nil)
            end
        end
    end
end

function QuestieLearner:OnQuestComplete()
    local questId = GetQuestID and GetQuestID()
    if not questId or questId <= 0 then return end

    local npcGuid = UnitGUID("npc")
    if npcGuid then
        local unitType, _, _, _, _, npcId = strsplit("-", npcGuid)
        if unitType == "Creature" or unitType == "Vehicle" then
            npcId = tonumber(npcId)
            if npcId and npcId > 0 then
                self:LearnQuestGiver(questId, npcId, false)
                local npcName = UnitName("npc")
                self:LearnNPC(npcId, npcName, nil, nil, 2, nil)
            end
        end
    end
end

function QuestieLearner:OnQuestAccepted(questLogIndex, questId)
    if not questId or questId <= 0 then
        if questLogIndex then
            questId = select(8, GetQuestLogTitle(questLogIndex))
        end
    end
    if not questId or questId <= 0 then return end

    local title = GetQuestLogTitle(questLogIndex) or GetTitleText()
    self:LearnQuest(questId, title, nil, nil, nil, nil)
end

function QuestieLearner:OnLootOpened()
    local targetGuid = UnitGUID("target")
    local npcId = nil

    if targetGuid then
        local unitType, _, _, _, _, id = strsplit("-", targetGuid)
        if unitType == "Creature" then
            npcId = tonumber(id)
        end
    end

    local numItems = GetNumLootItems()
    for i = 1, numItems do
        local lootIcon, lootName, lootQuantity, currencyID, lootQuality, locked, isQuestItem, questId, isActive =
            GetLootSlotInfo(i)
        if lootName then
            local link = GetLootSlotLink(i)
            if link then
                local itemId = tonumber(string.match(link, "item:(%d+)"))
                if itemId then
                    local _, _, _, itemLevel, requiredLevel, itemType, itemSubType, _, _, _, _, itemClassId, itemSubClassId =
                        GetItemInfo(link)
                    self:LearnItem(itemId, lootName, itemLevel, requiredLevel, itemClassId, itemSubClassId)

                    if npcId then
                        self:LearnItemDrop(itemId, npcId)
                    end
                end
            end
        end
    end
end

function QuestieLearner:OnGossipShow()
    local npcGuid = UnitGUID("npc")
    if not npcGuid then return end

    local unitType, _, _, _, _, npcId = strsplit("-", npcGuid)
    if unitType ~= "Creature" and unitType ~= "Vehicle" then return end

    npcId = tonumber(npcId)
    if not npcId or npcId <= 0 then return end

    local npcName = UnitName("npc")
    self:LearnNPC(npcId, npcName, nil, nil, 1, nil)
end

function QuestieLearner:Initialize()
    EnsureLearnedData()
    self:RegisterEvents()
    self:InjectLearnedData()
    Questie:Debug(Questie.DEBUG_INFO, "[QuestieLearner] Initialized")
end

return QuestieLearner
