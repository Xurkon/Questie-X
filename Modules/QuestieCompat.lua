---@diagnostic disable: undefined-global, return-type-mismatch, undefined-field
---@class QuestieCompat
QuestieCompat = setmetatable({}, { __index = _G })

------------------------------------------
-- Lua 5.0 string compatibility (e.g. Turtle)
------------------------------------------
if type(string) == "table" and type(string.match) ~= "function" then
    function string.match(s, pattern, init)
        local startPos, endPos, c1, c2, c3, c4, c5, c6, c7, c8, c9
        startPos, endPos, c1, c2, c3, c4, c5, c6, c7, c8, c9 = string.find(s, pattern, init or 1)
        if not startPos then
            return nil
        end
        if c1 ~= nil then
            return c1, c2, c3, c4, c5, c6, c7, c8, c9
        end
        return string.sub(s, startPos, endPos)
    end
end

if not select then
    function select(index, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25)
        if index == "#" then
            local n = 25
            while n > 0 do
                if n == 25 and a25 ~= nil then return 25 end
                if n == 24 and a24 ~= nil then return 24 end
                if n == 23 and a23 ~= nil then return 23 end
                if n == 22 and a22 ~= nil then return 22 end
                if n == 21 and a21 ~= nil then return 21 end
                if n == 20 and a20 ~= nil then return 20 end
                if n == 19 and a19 ~= nil then return 19 end
                if n == 18 and a18 ~= nil then return 18 end
                if n == 17 and a17 ~= nil then return 17 end
                if n == 16 and a16 ~= nil then return 16 end
                if n == 15 and a15 ~= nil then return 15 end
                if n == 14 and a14 ~= nil then return 14 end
                if n == 13 and a13 ~= nil then return 13 end
                if n == 12 and a12 ~= nil then return 12 end
                if n == 11 and a11 ~= nil then return 11 end
                if n == 10 and a10 ~= nil then return 10 end
                if n == 9 and a9 ~= nil then return 9 end
                if n == 8 and a8 ~= nil then return 8 end
                if n == 7 and a7 ~= nil then return 7 end
                if n == 6 and a6 ~= nil then return 6 end
                if n == 5 and a5 ~= nil then return 5 end
                if n == 4 and a4 ~= nil then return 4 end
                if n == 3 and a3 ~= nil then return 3 end
                if n == 2 and a2 ~= nil then return 2 end
                if n == 1 and a1 ~= nil then return 1 end
                return 0
            end
            return 0
        end
        if index == 1 then return a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 2 then return a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 3 then return a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 4 then return a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 5 then return a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 6 then return a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 7 then return a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 8 then return a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 9 then return a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 10 then return a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 11 then return a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 12 then return a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 13 then return a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 14 then return a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 15 then return a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 16 then return a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 17 then return a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 18 then return a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 19 then return a19, a20, a21, a22, a23, a24, a25 end
        if index == 20 then return a20, a21, a22, a23, a24, a25 end
        if index == 21 then return a21, a22, a23, a24, a25 end
        if index == 22 then return a22, a23, a24, a25 end
        if index == 23 then return a23, a24, a25 end
        if index == 24 then return a24, a25 end
        if index == 25 then return a25 end
        return nil
    end
end

if not math.mod and math.fmod then
    math.mod = math.fmod
end

-- addon is running on 3.3.5 WotLK client
do
    local _, _, _, build = GetBuildInfo()
    QuestieCompat.Is335 = (build == 30300)
end

local errorMsg = "Questie tried to call a blizzard API function that does not exist..."

------------------------------------------
-- Older client compatibility (pre 1.14.1)
------------------------------------------

-- Add missing Seasons object, if not available (e.g. 1.14.0 and below is missing it)
if not C_Seasons then
    C_Seasons = {
        ---[C_Seasons.HasActiveSeason Documentation](https://wowpedia.fandom.com/wiki/API_C_Seasons.HasActiveSeason)
        ---Returns true if the player is on a seasonal realm.
        HasActiveSeason = function()
            return false
        end,
        ---[C_Seasons.GetActiveSeason Documentation](https://wowpedia.fandom.com/wiki/API_C_Seasons.GetActiveSeason)
        ---Returns the ID of the season that is active on the current realm.
        GetActiveSeason = function()
            return 0
        end
    }
end

-- Specific subclass of this mixin was added in a minor version and is missing in earlier patches, functionality this makes next to no visual difference
if not TooltipBackdropTemplateMixin then
    TooltipBackdropTemplateMixin = BackdropTemplateMixin
end

-------------------------------------------
-- API difference compatibility (Era/Wotlk)
-------------------------------------------

if not hooksecurefunc then
    function hooksecurefunc(arg1, arg2, arg3)
        local t, name, func
        if type(arg1) == "string" then
            t = _G
            name = arg1
            func = arg2
        elseif type(arg1) == "table" then
            t = arg1
            name = arg2
            func = arg3
        end
        local original = t[name]
        t[name] = function(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25)
            local ret1, ret2, ret3, ret4
            if original then
                ret1, ret2, ret3, ret4 = original(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25)
            end
            func(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25)
            return ret1, ret2, ret3, ret4
        end
    end
end
QuestieCompat.hooksecurefunc = hooksecurefunc

if not C_Timer then
    local TickerFrame = CreateFrame("Frame")
    local tickers = {}

    TickerFrame:SetScript("OnUpdate", function()
        local elapsed = 1 / GetFramerate()
        for i = table.getn(tickers), 1, -1 do
            local ticker = tickers[i]
            if not ticker._cancelled then
                ticker._elapsed = ticker._elapsed + elapsed
                if ticker._elapsed >= ticker._duration then
                    ticker._elapsed = ticker._elapsed - ticker._duration
                    ticker._callback()
                    if ticker._iterations then
                        ticker._iterations = ticker._iterations - 1
                        if ticker._iterations <= 0 then
                            ticker._cancelled = true
                            table.remove(tickers, i)
                        end
                    end
                end
            else
                table.remove(tickers, i)
            end
        end
    end)

    C_Timer = {
        After = function(duration, callback)
            table.insert(tickers, {
                _duration = duration,
                _elapsed = 0,
                _callback = callback,
                _iterations = 1,
                _cancelled = false
            })
        end,
        NewTicker = function(duration, callback, iterations)
            local ticker = {
                _duration = duration,
                _elapsed = 0,
                _callback = callback,
                _iterations = iterations,
                _cancelled = false,
                Cancel = function(self)
                    self._cancelled = true
                end
            }
            table.insert(tickers, ticker)
            return ticker
        end
    }
end
QuestieCompat.C_Timer = C_Timer

---[SetMinResize Documentation](https://wowpedia.fandom.com/wiki/API_Frame_SetMinResize)
---[SetMaxResize Documentation](https://wowpedia.fandom.com/wiki/API_Frame_SetMaxResize)
---[SetResizeBounds Documentation](https://wowpedia.fandom.com/wiki/API_Frame_SetMinResize)
---Specifies the minimum [and maximum] width and height that the object can be resized to.
---@param frame frame
---@param minWidth number The minimum width the object can be resized to.
---@param minHeight number The minimum height the object can be resized to.
---@param maxWidth number The maximum width the object can be resized to.
---@param maxHeight number The maximum height the object can be resized to.
function QuestieCompat.SetResizeBounds(frame, minWidth, minHeight, maxWidth, maxHeight)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
        return
    else
        if frame.SetMinResize and frame.SetMaxResize then
            if minWidth and minWidth ~= 0 then
                frame:SetMinResize(minWidth, minHeight)
            end
            if maxWidth and maxWidth ~= 0 then
                frame:SetMaxResize(maxWidth, maxHeight)
            end
            return
        end
    end
    error(errorMsg, 2)
end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_GossipInfo.GetAvailableQuests)
---Returns the available quests at a quest giver.
---@return GossipQuestUIInfo[] info
function QuestieCompat.GetAvailableQuests()
    if C_GossipInfo and C_GossipInfo.GetAvailableQuests then
        local info = C_GossipInfo.GetAvailableQuests()
        local availableQuests = {}
        local index = 1
        for _, availableQuest in pairs(info) do
            availableQuests[index] = availableQuest.title
            availableQuests[index + 1] = availableQuest.questLevel
            availableQuests[index + 2] = availableQuest.isTrivial
            availableQuests[index + 3] = availableQuest.frequency
            availableQuests[index + 4] = availableQuest.repeatable
            availableQuests[index + 5] = availableQuest.isLegendary
            availableQuests[index + 6] = availableQuest.isIgnored
            index = index + 7
        end
        return unpack(availableQuests)
    elseif GetGossipAvailableQuests then
        return GetGossipAvailableQuests() -- https://wowpedia.fandom.com/wiki/API_GetGossipAvailableQuests
    end
    error(errorMsg, 2)
end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_GossipInfo.GetActiveQuests)
---Returns the quests which can be turned in at a quest giver.
---@return GossipQuestUIInfo[] info
function QuestieCompat.GetActiveQuests()
    if C_GossipInfo and C_GossipInfo.GetActiveQuests then
        -- QuestieDB needs to be loaded locally, otherwise it will be an empty module
        local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
        local info = C_GossipInfo.GetActiveQuests()
        local activeQuests = {}
        local index = 1
        for _, activeQuest in pairs(info) do
            activeQuests[index] = activeQuest.title
            activeQuests[index + 1] = activeQuest.questLevel
            activeQuests[index + 2] = activeQuest.isTrivial
            activeQuests[index + 3] = activeQuest.isComplete or QuestieDB.IsComplete(activeQuest.questID) == 1
            activeQuests[index + 4] = activeQuest.isLegendary
            activeQuests[index + 5] = activeQuest.isIgnored
            index = index + 6
        end
        return unpack(activeQuests)
    elseif GetGossipActiveQuests then
        return GetGossipActiveQuests() -- https://wowpedia.fandom.com/wiki/API_GetGossipActiveQuests
    end
    error(errorMsg, 2)
end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_GossipInfo.SelectAvailableQuest)
---Selects an available quest from the gossip window.
---@param index number Index of the quest to select (I think questId might work here too...)
function QuestieCompat.SelectAvailableQuest(index)
    if C_GossipInfo and C_GossipInfo.SelectAvailableQuest then
        local questId = C_GossipInfo.GetAvailableQuests()[index].questID
        return C_GossipInfo.SelectAvailableQuest(questId)
    elseif SelectGossipAvailableQuest then
        return SelectGossipAvailableQuest(index)
    end
    error(errorMsg, 2)
end

---[Documentation](https://wowpedia.fandom.com/wiki/API_C_GossipInfo.SelectActiveQuest)
---Selects an active quest from the gossip window.
---@param index number|QuestId Index of the active quest to select, from 1 to GetNumGossipActiveQuests(); order corresponds to the order of return values from GetGossipActiveQuests().
function QuestieCompat.SelectActiveQuest(index)
    if C_GossipInfo and C_GossipInfo.SelectActiveQuest then
        local questId = C_GossipInfo.GetActiveQuests()[index].questID
        return C_GossipInfo.SelectActiveQuest(questId)
    elseif SelectGossipActiveQuest then
        return SelectGossipActiveQuest(index)
    end
    error(errorMsg, 2)
end

---[Documentation](https://wowpedia.fandom.com/wiki/API_GetContainerNumSlots)
---Returns the total number of slots in the bag specified by the index.
---@param bagID number the slot containing the bag, e.g. 0 for backpack, etc.
---@return number numberOfSlots the number of slots in the specified bag, or 0 if there is no bag in the given slot.
function QuestieCompat.GetContainerNumSlots(bagID)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bagID)
    elseif GetContainerNumSlots then
        return GetContainerNumSlots(bagID)
    end
    error(errorMsg, 2)
end

---[Documentation](https://wowpedia.fandom.com/wiki/API_GetContainerItemInfo)
---Returns info for an item in a container slot.
---@param bagID number BagID of the bag the item is in, e.g. 0 for your backpack.
---@param slot number index of the slot inside the bag to look up.
---@return number texture The icon texture (FileID) for the item in the specified bag slot.
---@return number itemCount The number of items in the specified bag slot.
---@return boolean locked True if the item is locked by the server, false otherwise.
---@return number quality The Quality of the item.
---@return boolean readable True if the item can be "read" (as in a book), false otherwise.
---@return boolean lootable True if the item is a temporary container containing items that can be looted, false otherwise.
---@return string itemLink The itemLink of the item in the specified bag slot.
---@return boolean isFiltered True if the item is grayed-out during the current inventory search, false otherwise.
---@return boolean noValue True if the item has no gold value, false otherwise.
---@return number itemID The unique ID for the item in the specified bag slot.
---@return boolean isBound True if the item is bound to the current character, false otherwise.
function QuestieCompat.GetContainerItemInfo(bagID, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local containerInfo = C_Container.GetContainerItemInfo(bagID, slot)
        if containerInfo then
            return containerInfo.iconFileID,
                   containerInfo.stackCount,
                   containerInfo.isLocked,
                   containerInfo.quality,
                   containerInfo.isReadable,
                   containerInfo.hasLoot,
                   containerInfo.hyperlink,
                   containerInfo.isFiltered,
                   containerInfo.hasNoValue,
                   containerInfo.itemID,
                   containerInfo.isBound
       else
            return nil
       end
    elseif GetContainerItemInfo then
        return GetContainerItemInfo(bagID, slot)
    end
    error(errorMsg, 2)
end

---[Documentation](https://wowpedia.fandom.com/wiki/API_GetItemCooldown)
---Returns info about the cooldown state and time of an item.
---@param itemID number The item ID.
---@return number startTime The time when the cooldown started (as returned by GetTime()) or zero if no cooldown.
---@return number duration The number of seconds the cooldown will last, or zero if no cooldown.
---@return number enable 1 if the item is ready or on cooldown, 0 if the item is used, but the cooldown didn't start yet (e.g. potion in combat).
function QuestieCompat.GetItemCooldown(itemID)
    if C_Container and C_Container.GetItemCooldown then
        return C_Container.GetItemCooldown(itemID)
    else
        return GetItemCooldown(itemID)
    end
end

--- C_QuestLog Shim
QuestieCompat.C_QuestLog = QuestieCompat.C_QuestLog or {}

function QuestieCompat.C_QuestLog.GetNumQuestLogEntries()
    return GetNumQuestLogEntries()
end

function QuestieCompat.C_QuestLog.GetQuestLogTitle(questIndex)
    return GetQuestLogTitle(questIndex)
end

function QuestieCompat.C_QuestLog.GetQuestLogSelection()
    return GetQuestLogSelection()
end

function QuestieCompat.C_QuestLog.GetQuestInfo(questID)
    return QuestieCompat.GetQuestInfo(questID)
end

function QuestieCompat.C_QuestLog.GetAllQuestIDs()
    local questIDs = {}
    local numEntries = GetNumQuestLogEntries()
    for i = 1, numEntries do
        local questTitle, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID = GetQuestLogTitle(i)
        if questID and questID ~= 0 then
            table.insert(questIDs, questID)
        end
    end
    return questIDs
end

function QuestieCompat.C_QuestLog.GetQuestObjectives(questID)
    local questIndex = GetQuestLogIndexByID(questID)
    if not questIndex then return nil end
    return QuestieCompat.GetQuestObjectives(questIndex)
end

function QuestieCompat.C_QuestLog.IsQuestFlaggedCompleted(questID)
    return IsQuestFlaggedCompleted(questID)
end

function QuestieCompat.C_QuestLog.GetQuestPlayerQuestLink(questID)
    return GetQuestLink(questID)
end

--- C_Map Shim
QuestieCompat.C_Map = QuestieCompat.C_Map or {}

function QuestieCompat.C_Map.GetPlayerMapPosition(uiMapID)
    local x, y = GetPlayerMapPosition(uiMapID)
    if x == 0 and y == 0 then
        x, y = GetPlayerMapPosition("player")
    end
    return x, y
end

function QuestieCompat.C_Map.GetBestMapForUnit(unit)
    if unit == "player" then
        return GetCurrentMapAreaID()
    end
    return GetCurrentMapAreaID()
end

function QuestieCompat.C_Map.GetMapInfo(uiMapID)
    return GetMapInfo(uiMapID)
end

--- GetTrackedAchievements Shim
QuestieCompat.GetTrackedAchievements = QuestieCompat.GetTrackedAchievements or function()
    return {}
end

--- IsAchievementCompleted Shim
QuestieCompat.IsAchievementCompleted = QuestieCompat.IsAchievementCompleted or function(achievementID)
    return GetAchievementNumCriteria(achievementID) > 0
end

--- LibUIDropDownMenu Shim
QuestieCompat.LibUIDropDownMenu = QuestieCompat.LibUIDropDownMenu or {}
QuestieCompat.LibUIDropDownMenu.UIDropDownMenu_Menu_NewSize = function()
end
