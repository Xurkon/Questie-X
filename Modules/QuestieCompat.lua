---@diagnostic disable: undefined-global, return-type-mismatch, undefined-field
---@class QuestieCompat
---@type table|_G
QuestieCompat = QuestieLoader:CreateModule("QuestieCompat")
setmetatable(QuestieCompat, { __index = _G })
QuestieCompat.addonName = QuestieLoader.addonName


------------------------------------------
-- Lua 5.0 / 5.1 / 5.2 compatibility shims
-- NOTE: string.match, select(), and math.mod shims live in QuestieLoader.lua
--       which is always loaded first.  Do NOT duplicate them here.
------------------------------------------

if not math.mod and math.fmod then
    math.mod = math.fmod
end

-- Polyfill for xpcall variadic arguments (missing in standard Lua 5.0/5.1 WoW clients).
-- Modern Ace3 uses xpcall(func, err, ...) which drops arguments on legacy clients,
-- leading to 'self' being nil in addon callbacks.
local _xpcall = xpcall
local xpcall_supported = false
pcall(function()
    _xpcall(function(a) if a == 1 then xpcall_supported = true end end, function() end, 1)
end)

if not xpcall_supported then
    QuestieCompat.xpcall = function(func, err, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19, arg20, arg21, arg22, arg23, arg24, arg25)
        -- To avoid the GC overhead of building {...} on every event fire, we pre-check argument counts.
        -- We support up to 25 arguments just like our select() polyfill.
        if arg25 ~= nil then return _xpcall(function() return func(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19, arg20, arg21, arg22, arg23, arg24, arg25) end, err) end
        if arg24 ~= nil then return _xpcall(function() return func(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19, arg20, arg21, arg22, arg23, arg24) end, err) end
        if arg23 ~= nil then return _xpcall(function() return func(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19, arg20, arg21, arg22, arg23) end, err) end
        if arg22 ~= nil then return _xpcall(function() return func(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19, arg20, arg21, arg22) end, err) end
        if arg21 ~= nil then return _xpcall(function() return func(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19, arg20, arg21) end, err) end
        if arg20 ~= nil then return _xpcall(function() return func(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19, arg20) end, err) end
        if arg19 ~= nil then return _xpcall(function() return func(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19) end, err) end
        if arg18 ~= nil then return _xpcall(function() return func(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17, arg18) end, err) end
        if arg17 ~= nil then return _xpcall(function() return func(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16, arg17) end, err) end
        if arg16 ~= nil then return _xpcall(function() return func(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15, arg16) end, err) end
        if arg15 ~= nil then return _xpcall(function() return func(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14, arg15) end, err) end
        if arg14 ~= nil then return _xpcall(function() return func(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14) end, err) end
        if arg13 ~= nil then return _xpcall(function() return func(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13) end, err) end
        if arg12 ~= nil then return _xpcall(function() return func(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12) end, err) end
        if arg11 ~= nil then return _xpcall(function() return func(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11) end, err) end
        if arg10 ~= nil then return _xpcall(function() return func(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10) end, err) end
        if arg9  ~= nil then return _xpcall(function() return func(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9) end, err) end
        if arg8  ~= nil then return _xpcall(function() return func(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8) end, err) end
        if arg7  ~= nil then return _xpcall(function() return func(arg1, arg2, arg3, arg4, arg5, arg6, arg7) end, err) end
        if arg6  ~= nil then return _xpcall(function() return func(arg1, arg2, arg3, arg4, arg5, arg6) end, err) end
        if arg5  ~= nil then return _xpcall(function() return func(arg1, arg2, arg3, arg4, arg5) end, err) end
        if arg4  ~= nil then return _xpcall(function() return func(arg1, arg2, arg3, arg4) end, err) end
        if arg3  ~= nil then return _xpcall(function() return func(arg1, arg2, arg3) end, err) end
        if arg2  ~= nil then return _xpcall(function() return func(arg1, arg2) end, err) end
        if arg1  ~= nil then return _xpcall(function() return func(arg1) end, err) end
        
        -- No extra args provided
        return _xpcall(func, err)
    end
    -- Crucial: Expose to the global environment so that unmodified Ace3 libraries (like AceGUI-3.0) 
    -- will pick it up instead of using the broken native version which drops arguments causing crashes.
    _G.xpcall = QuestieCompat.xpcall
else
    -- Native xpcall works fine, expose it
    QuestieCompat.xpcall = _xpcall
end

------------------------------------------
-- GetCurrentRegion polyfill (WotLK/Classic)
------------------------------------------

-- GetCurrentRegion and GetCurrentRegionName are modern API functions that don't exist in WotLK.
-- AceDB-3.0 uses these for realm identification. Provide fallbacks based on locale.
if not GetCurrentRegion then
    local regionByLocale = {
        ["enUS"] = 1, ["enGB"] = 1, ["koKR"] = 2, ["frFR"] = 3, ["deDE"] = 3,
        ["zhCN"] = 5, ["zhTW"] = 4, ["esES"] = 3, ["esMX"] = 1, ["ruRU"] = 3,
        ["ptBR"] = 1, ["itIT"] = 3,
    }
    GetCurrentRegion = function()
        return regionByLocale[GetLocale()] or 1
    end
end

if not GetCurrentRegionName then
    local regionNames = { "US", "KR", "EU", "TW", "CN" }
    GetCurrentRegionName = function()
        return regionNames[GetCurrentRegion()] or "US"
    end
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
-- Fix #3: Do NOT write to bare _G["C_Seasons"] — store in QuestieCompat namespace only.
-- All callers should use QuestieCompat.C_Seasons.
QuestieCompat.C_Seasons = C_Seasons or {
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

-- Specific subclass of this mixin was added in a minor version and is missing in earlier patches, functionality this makes next to no visual difference
if not TooltipBackdropTemplateMixin then
    TooltipBackdropTemplateMixin = BackdropTemplateMixin
end

-------------------------------------------
-- AceComm/AceSerializer compatibility (WotLK)
-------------------------------------------

-- Ambiguate is used to disambiguate realm names but doesn't exist in WotLK.
-- On WotLK, realm names are already unique in the format, so we can just return the name.
if not Ambiguate then
    Ambiguate = function(name, kind)
        return name
    end
end

-- RegisterAddonMessagePrefix may not exist in all WotLK versions.
if not RegisterAddonMessagePrefix then
    RegisterAddonMessagePrefix = function(prefix)
        -- No-op on versions that don't support it
    end
end

-------------------------------------------
-- API difference compatibility (Era/Wotlk)
-------------------------------------------

-- Fix #2/#13: The old hooksecurefunc polyfill made raw _G table assignments which
-- directly cause taint on all modern WoW clients.  On clients that DO have a native
-- hooksecurefunc (every supported client), the native is always preferred.
-- We never write to bare _G here.  If hooksecurefunc is truly missing (extremely
-- old Lua 5.0 host with no secure-call protection), addon code can still call it
-- but it will simply be a no-op that prints a warning rather than injecting taint.
if not hooksecurefunc then
    -- Lua 5.0 hosts (Turtle WoW pre-2.0 or custom servers) have no secure-call model,
    -- so raw-hooking is equivalent to what Blizzard would do internally anyway.
    -- Use a local to avoid polluting _G unnecessarily.
    local function _rawHook(arg1, arg2, arg3)
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
        if not (t and name and func) then return end
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
    -- Only expose under QuestieCompat, never pollute _G with a replacement.
    QuestieCompat.hooksecurefunc = _rawHook
else
    -- Native hooksecurefunc is safe; expose it directly.
    QuestieCompat.hooksecurefunc = hooksecurefunc
end

-- Fix #3: Never write C_Timer to bare _G. Store polyfill in QuestieCompat.C_Timer only.
-- All callers already use `local C_Timer = QuestieCompat.C_Timer` at top of each file.
if C_Timer then
    QuestieCompat.C_Timer = C_Timer
else
    -- C_Timer polyfill for Lua 5.0/5.1 clients that don't have it (e.g. Turtle WoW pre-2.0).
    -- Only stored in QuestieCompat namespace, NOT in bare _G.
    local TickerFrame = CreateFrame("Frame")
    local tickers = {}

    TickerFrame:SetScript("OnUpdate", function(self, elapsed)
        local i = table.getn(tickers)
        while i >= 1 do
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
            i = i - 1
        end
    end)

    QuestieCompat.C_Timer = {
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
    _G.C_Timer = QuestieCompat.C_Timer
end

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
if not rawget(QuestieCompat, "C_QuestLog") then
    QuestieCompat.C_QuestLog = {}
end

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

function QuestieCompat.C_QuestLog.IsQuestFlaggedCompleted(questID)

    return IsQuestFlaggedCompleted(questID)
end

function QuestieCompat.C_QuestLog.GetQuestPlayerQuestLink(questID)
    return GetQuestLink(questID)
end

--- C_Map Shim
QuestieCompat.C_Map = QuestieCompat.C_Map or {}

function QuestieCompat.C_Map.GetPlayerMapPosition(uiMapID)
    local x, y = GetPlayerMapPosition("player")
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
    local completed = select(4, GetAchievementInfo(achievementID))
    return completed or false
end

--- LibUIDropDownMenu Shim
QuestieCompat.LibUIDropDownMenu = QuestieCompat.LibUIDropDownMenu or {}
QuestieCompat.LibUIDropDownMenu.UIDropDownMenu_Menu_NewSize = function()
end

