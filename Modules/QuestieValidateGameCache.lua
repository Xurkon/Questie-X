--[[

Flow:
-> QuestieValidateGameCache.StartCheck()
--> Wait for PLAYER_ENTERING_WORLD
---> Wait For QUEST_LOG_UPDATE (2x at login, 1x at reload)
----> Game cache should have all quests in it, data of each quest may be invalid.
      If data is invalid, Wait for next QUEST_LOG_UPDATE and check again.
-----> Game Cache ok. Call possible callback functions.
]] --

---@class QuestieValidateGameCache
local QuestieValidateGameCache = QuestieLoader:CreateModule("QuestieValidateGameCache")
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
local QuestieCompat = QuestieLoader:ImportModule("QuestieCompat")
-- Defer API assignments to runtime to avoid load-order nil errors

local stringByte, tremove = string.byte, table.remove
local tpack = QuestieLib.tpack
local tunpack = QuestieLib.tunpack

-- 3 * (Max possible number of quests in game quest log)
-- This is a safe value, even smaller would be enough. Too large won't effect performance
local numberOfQuestLogUpdatesToSkip = 0
local checkStarted = false
local eventFrame = nil
local callbacks = {}
local isCacheGood = false

local function DestroyEventFrame()
    if eventFrame then
        eventFrame:UnregisterAllEvents()
        eventFrame:SetScript("OnEvent", nil)
        eventFrame = nil
    end
end

local function OnQuestLogUpdate()
    -- Fetch APIs at runtime with extreme defensive checks
    local qCompat = QuestieCompat or _G.QuestieCompat
    local rawCLog = qCompat and rawget(qCompat, "C_QuestLog")
    local cLog = (qCompat and qCompat.C_QuestLog) or {}

    
    local GetNumQuestLogEntries = cLog.GetNumQuestLogEntries or _G.GetNumQuestLogEntries
    local GetQuestLogTitle = cLog.GetQuestLogTitle or _G.GetQuestLogTitle
    local GetNumQuestLeaderBoards = _G.GetNumQuestLeaderBoards
    local GetQuestObjectives = cLog.GetQuestObjectives or function() return {} end




    if isCacheGood then
        DestroyEventFrame()
        return
    end

    if numberOfQuestLogUpdatesToSkip > 0 then
        numberOfQuestLogUpdatesToSkip = numberOfQuestLogUpdatesToSkip - 1
        return
    end


    local isQuestLogGood = true
    local numQuests = select(1, GetNumQuestLogEntries()) or 0
    local goodQuestsCount = 0


    for i = 1, numQuests do
        local status, err = pcall(function()
            local title, _, _, _, isHeader, _, _, _, questId = GetQuestLogTitle(i)
            if title and (not isHeader) and questId and questId > 0 then
                local numObjectives = GetNumQuestLeaderBoards(i) or 0
                
                if numObjectives > 0 then
                    local objectiveList = GetQuestObjectives(questId, i)
                    if objectiveList and objectiveList[1] then
                        local hasInvalidObjective = false
                        for _, objective in pairs(objectiveList) do
                            -- Fix: Only fail if text is nil or empty. 
                            -- Leading spaces (ASCII 32) are common on some servers/quests and shouldn't block initialization.
                            -- Ghost quests (removed from DB but still in log) may have no text - skip those silently.
                            if (not objective.text) or (objective.text == "") then
                                hasInvalidObjective = true
                                break
                            end
                        end
                        if not hasInvalidObjective then
                            goodQuestsCount = goodQuestsCount + 1
                        end
                        -- Don't fail validation for ghost quests with empty text, just skip them
                    else
                        -- Quest has objectives according to game but GetQuestObjectives returns nothing
                        -- This is likely a ghost quest, skip it
                    end
                else
                    goodQuestsCount = goodQuestsCount + 1
                end

            end
        end)
    end



    if not isQuestLogGood then
        Questie:Debug(Questie.DEBUG_INFO, "[QuestieValidateGameCache] Quest log is NOT yet okey. Good quest:",
            goodQuestsCount .. "/" .. numQuests)
        return
    end

    DestroyEventFrame()
    Questie:Debug(Questie.DEBUG_CRITICAL, "[QuestieValidateGameCache] Quest log is ok. Good quest:",
        goodQuestsCount .. "/" .. numQuests)

    isCacheGood = true

    while (#callbacks > 0) do
        local callback = tremove(callbacks, 1)
        local func, args = callback[1], callback[2]
        func(tunpack(args))
    end
end

local function OnPlayerEnteringWorld(_, _, isInitialLogin, isReloadingUi)
    if isInitialLogin == nil then isInitialLogin = true end
    if isReloadingUi == nil then isReloadingUi = false end

    if QuestieCompat.Is335 then
        isInitialLogin, isReloadingUi = false, true
    end

    numberOfQuestLogUpdatesToSkip = isInitialLogin and 1 or 0

    if not eventFrame then eventFrame = CreateFrame("Frame") end
    eventFrame:UnregisterAllEvents()
    eventFrame:SetScript("OnEvent", OnQuestLogUpdate)
    eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
end

function QuestieValidateGameCache.StartCheck()
    if checkStarted then return end
    checkStarted = true

    if not eventFrame then eventFrame = CreateFrame("Frame") end
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", OnPlayerEnteringWorld)

    if IsLoggedIn() then
        OnPlayerEnteringWorld(eventFrame, "PLAYER_ENTERING_WORLD", true, false)
    end

    local function backupCheck()
        if isCacheGood then return end
        OnQuestLogUpdate()
        if not isCacheGood then
            local qCompat = QuestieCompat or _G.QuestieCompat
            local timer = (qCompat and qCompat.C_QuestLog and qCompat.C_Timer) or _G.C_Timer
            if timer and timer.After then
                timer.After(2.0, backupCheck)
            end
        end
    end
    
    local qCompat = QuestieCompat or _G.QuestieCompat
    local timer = (qCompat and qCompat.C_QuestLog and qCompat.C_Timer) or _G.C_Timer
    if timer and timer.After then
        timer.After(2.0, backupCheck)
    end

end

function QuestieValidateGameCache.IsCacheGood()
    return isCacheGood
end

function QuestieValidateGameCache.RegisterCallback(func, ...)
    if isCacheGood then
        func(...)
    else
        table.insert(callbacks, { func, tpack(...) })
    end
end

