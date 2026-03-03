---@type QuestieTooltips
local QuestieTooltips = QuestieLoader:ImportModule("QuestieTooltips");
local _QuestieTooltips = QuestieTooltips.private

---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")

--- COMPATIBILITY ---
local UnitGUID = QuestieCompat.UnitGUID

local lastGuid

-- ============================================================
-- NPCs that DROP an item which STARTS a quest (quest-starter drops)
-- Shows in tooltip like:
--   (yellow quest icon) Drops quest item !
--   (item icon) [ItemLink (quality colored)] [ID: <QuestId> (light blue)]
-- Works with Questie-335 compiled databases (binary + pointers).
-- ============================================================

local QUEST_START_LINE = "|TInterface\\GossipFrame\\AvailableQuestIcon:18:18:0:0|t |cFFFFD200Drops a quest !|r"
local QUEST_ID_COLOR = "|cFF80C8FF" -- light blue
local RESET_COLOR = "|r"

local _npcQuestStarterDrops = nil
local _npcQuestStarterDropsBuilt = false

-- ============================================================
-- Quest state cache (so we don't scan the log for every tooltip)
-- Hide lines if:
--   - quest is in quest log
--   - quest is flagged completed (turned in)
-- ============================================================

local _questInLogCache = {}
local _questInLogCacheBuilt = false

local function _WipeTable(t)
    if wipe then
        wipe(t)
    else
        for k in pairs(t) do
            t[k] = nil
        end
    end
end

local function _RebuildQuestInLogCache()
    _WipeTable(_questInLogCache)
    _questInLogCacheBuilt = true

    if not GetNumQuestLogEntries or not GetQuestLogTitle then
        return
    end

    local n = GetNumQuestLogEntries()
    for i = 1, n do
        -- WotLK: title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID
        local _, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(i)
        if not isHeader and questID then
            questID = tonumber(questID)
            if questID then
                _questInLogCache[questID] = true
            end
        end
    end
end

local function _QuestInLog(questId)
    if not questId then return false end
    if not _questInLogCacheBuilt then
        _RebuildQuestInLogCache()
    end
    return _questInLogCache[questId] == true
end

-- Invalidate cache on quest log changes
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("QUEST_LOG_UPDATE")
    f:RegisterEvent("QUEST_ACCEPTED")
    f:RegisterEvent("QUEST_REMOVED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function()
        _questInLogCacheBuilt = false
    end)
end

local function _GetItemPointers()
    -- QuestieDB exposes these after DB init:
    --   QuestieDB.ItemPointers = QuestieDB.QueryItem.pointers
    if QuestieDB and type(QuestieDB.ItemPointers) == "table" then
        return QuestieDB.ItemPointers
    end
    if QuestieDB and QuestieDB.QueryItem and type(QuestieDB.QueryItem.pointers) == "table" then
        return QuestieDB.QueryItem.pointers
    end
    return nil
end

-- Check if player already has the quest (in log or turned in)
local function _PlayerHasQuest(questId)
    questId = tonumber(questId)
    if not questId then return false end

    -- 1) Active in log
    if _QuestInLog(questId) then
        return true
    end

    -- 2) Turned in / completed
    if IsQuestFlaggedCompleted and IsQuestFlaggedCompleted(questId) then
        return true
    end

    -- Optional fallback (some cores implement this reliably)
    if GetQuestLogIndexByID then
        local idx = GetQuestLogIndexByID(questId)
        if idx and idx > 0 then
            return true
        end
    end

    return false
end

local function _TryBuildNpcQuestStarterDrops()
    if _npcQuestStarterDropsBuilt and _npcQuestStarterDrops then
        return true
    end

    -- DB not ready yet? Try again later.
    if not QuestieDB or type(QuestieDB.QueryItemSingle) ~= "function" then
        return false
    end

    local pointers = _GetItemPointers()
    if type(pointers) ~= "table" then
        return false
    end

    _npcQuestStarterDrops = {}

    -- Helper function to process an item and add it to the lookup table
    local function processItem(itemId)
        local questId = QuestieDB.QueryItemSingle(itemId, "startQuest")
        if questId and questId ~= 0 then
            local npcDrops = QuestieDB.QueryItemSingle(itemId, "npcDrops")
            if npcDrops and type(npcDrops) == "table" then
                local itemName = QuestieDB.QueryItemSingle(itemId, "name")
                for _, npcId in pairs(npcDrops) do
                    local list = _npcQuestStarterDrops[npcId]
                    if not list then
                        list = {}
                        _npcQuestStarterDrops[npcId] = list
                    end
                    list[#list + 1] = { itemId = itemId, questId = tonumber(questId), name = itemName }
                end
            end
        end
    end

    -- Iterate all items from compiled database
    for itemId, _ in pairs(pointers) do
        processItem(itemId)
    end

    -- Also iterate Ascension override items (they don't have pointers)
    if QuestieDB.itemDataOverrides and type(QuestieDB.itemDataOverrides) == "table" then
        for itemId, _ in pairs(QuestieDB.itemDataOverrides) do
            processItem(itemId)
        end
    end

    _npcQuestStarterDropsBuilt = true
    return true
end

local function _TooltipHasQuestStarterLine(tooltip)
    local n = tooltip:NumLines()
    local base = tooltip:GetName() .. "TextLeft"
    for i = 1, n do
        local left = _G[base .. i]
        if left then
            local t = left:GetText()
            if t and t:find("Drops quest item", 1, true) then
                return true
            end
        end
    end
    return false
end

local function _AddQuestStarterDropsToTooltip(npcId)
    if not _TryBuildNpcQuestStarterDrops() then return end
    if not _npcQuestStarterDrops then return end

    local drops = _npcQuestStarterDrops[npcId]
    if not drops or #drops == 0 then return end

    if _TooltipHasQuestStarterLine(GameTooltip) then
        return
    end

    -- Filter drops to only show items where player doesn't have the quest yet
    local filteredDrops = {}
    for _, info in ipairs(drops) do
        if info.questId and (not _PlayerHasQuest(info.questId)) then
            filteredDrops[#filteredDrops + 1] = info
        end
    end

    if #filteredDrops == 0 then
        return
    end

    GameTooltip:AddLine(QUEST_START_LINE)

    for _, info in ipairs(filteredDrops) do
        local itemId = info.itemId
        local questId = info.questId

        -- Item link with correct quality color when cached by client
        local itemLink = select(2, GetItemInfo(itemId))
        if not itemLink then
            local itemName = info.name
            if not itemName or itemName == "" then
                itemName = "Item " .. tostring(itemId)
            end
            itemLink = ("|Hitem:%d:::::::::|h[%s]|h"):format(itemId, itemName)
        end

        local icon = GetItemIcon and GetItemIcon(itemId)
        local qid = ("%s[ID: %d]%s"):format(QUEST_ID_COLOR, questId, RESET_COLOR)

        if icon then
            GameTooltip:AddLine(("|T%s:14:14:0:0|t %s %s"):format(icon, itemLink, qid))
        else
            GameTooltip:AddLine(("%s %s"):format(itemLink, qid))
        end
    end
end

function _QuestieTooltips:AddUnitDataToTooltip()
    if (self.IsForbidden and self:IsForbidden()) or (not Questie.db.profile.enableTooltips) then
        return
    end

    local name, unitToken = self:GetUnit();
    if not unitToken then return end
    local guid = UnitGUID(unitToken);
    if (not guid) then
        guid = UnitGUID("mouseover");
    end

    local type, _, _, _, _, npcId, _ = strsplit("-", guid or "");

    if name and (type == "Creature" or type == "Vehicle") and (
            name ~= QuestieTooltips.lastGametooltipUnit or
            (not QuestieTooltips.lastGametooltipCount) or
            _QuestieTooltips:CountTooltip() < QuestieTooltips.lastGametooltipCount or
            QuestieTooltips.lastGametooltipType ~= "monster" or
            lastGuid ~= guid
        ) then
        QuestieTooltips.lastGametooltipUnit = name

        local tooltipData = QuestieTooltips:GetTooltip("m_" .. npcId);

        if tooltipData then
            if Questie.db.profile.enableTooltipsNPCID == true then
                GameTooltip:AddDoubleLine("NPC ID", "|cFFFFFFFF" .. npcId .. "|r")
            end
            for _, v in pairs(tooltipData) do
                GameTooltip:AddLine(v)
            end
        else
            -- Even if Questie has no objective tooltip for this NPC, we still want to show quest-starter drops.
            if Questie.db.profile.enableTooltipsNPCID == true then
                GameTooltip:AddDoubleLine("NPC ID", "|cFFFFFFFF" .. npcId .. "|r")
            end
        end

        local npcNum = tonumber(npcId)
        if npcNum then
            _AddQuestStarterDropsToTooltip(npcNum)
        end

        QuestieTooltips.lastGametooltipCount = _QuestieTooltips:CountTooltip()
    end
    lastGuid = guid;
    QuestieTooltips.lastGametooltipType = "monster";
end

-- =======================
-- Rest of original file
-- =======================

local lastItemId = 0;
function _QuestieTooltips:AddItemDataToTooltip()
    if (self.IsForbidden and self:IsForbidden()) or (not Questie.db.profile.enableTooltips) then
        return
    end

    local name, link = self:GetItem()
    local itemId
    if link then
        itemId = select(3,
            string.match(link,
                "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*):?(%d*):?(%-?%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?"))
    end
    if name and itemId and (
            name ~= QuestieTooltips.lastGametooltipItem or
            (not QuestieTooltips.lastGametooltipCount) or
            _QuestieTooltips:CountTooltip() < QuestieTooltips.lastGametooltipCount or
            QuestieTooltips.lastGametooltipType ~= "item" or
            lastItemId ~= itemId or
            QuestieTooltips.lastFrameName ~= self:GetName()
        ) then
        QuestieTooltips.lastGametooltipItem = name
        local tooltipData = QuestieTooltips:GetTooltip("i_" .. (itemId or 0));
        if tooltipData then
            if Questie.db.profile.enableTooltipsItemID == true then
                GameTooltip:AddDoubleLine("Item ID", "|cFFFFFFFF" .. itemId .. "|r")
            end
            for _, v in pairs(tooltipData) do
                self:AddLine(v)
            end
        end
        QuestieTooltips.lastGametooltipCount = _QuestieTooltips:CountTooltip()
    end
    lastItemId = itemId;
    QuestieTooltips.lastGametooltipType = "item";
    QuestieTooltips.lastFrameName = self:GetName();
end

function _QuestieTooltips:AddObjectDataToTooltip(name)
    if (not Questie.db.profile.enableTooltips) then
        return
    end
    if name then
        local titleAdded = false
        local lookup = l10n.objectNameLookup[name] or {}
        local count = table.getn(lookup)

        if Questie.db.profile.enableTooltipsObjectID == true and count ~= 0 then
            if count == 1 then
                GameTooltip:AddDoubleLine("Object ID", "|cFFFFFFFF" .. lookup[1] .. "|r")
            else
                GameTooltip:AddDoubleLine("Object ID", "|cFFFFFFFF" .. lookup[1] .. " (" .. count .. ")|r")
            end
        end

        local alreadyAddedObjectiveLines = {}
        for _, gameObjectId in pairs(lookup) do
            local tooltipData = QuestieTooltips:GetTooltip("o_" .. gameObjectId);

            if type(gameObjectId) == "number" and tooltipData then
                if (not titleAdded) then
                    GameTooltip:AddLine(tooltipData[1])
                    titleAdded = true
                end

                if tooltipData[2] then
                    -- Quest has objectives
                    for index, line in pairs(tooltipData) do
                        if index > 1 and (not alreadyAddedObjectiveLines[line]) then -- skip the first entry, it's the title
                            local _, _, acquired, needed = string.find(line, "(%d+)/(%d+)")
                            -- We need "tonumber", because acquired can contain parts of the color string
                            if acquired and tonumber(acquired) == tonumber(needed) then
                                -- We don't want to show completed objectives on game objects
                                break;
                            end
                            alreadyAddedObjectiveLines[line] = true
                            GameTooltip:AddLine(line)
                        end
                    end
                end
            end
        end
        GameTooltip:Show()
    end
    QuestieTooltips.lastGametooltipType = "object";
end

function _QuestieTooltips:CountTooltip()
    local tooltipCount = 0
    for i = 1, GameTooltip:NumLines() do
        local frame = _G["GameTooltipTextLeft" .. i]
        if frame and frame:GetText() then
            tooltipCount = tooltipCount + 1
        else
            return tooltipCount
        end
    end
    return tooltipCount
end
