--- COMPATIBILITY ---
local IsQuestFlaggedCompleted = QuestieCompat.IsQuestFlaggedCompleted or C_QuestLog.IsQuestFlaggedCompleted

---@class QuestieQuest
local QuestieQuest = QuestieLoader:CreateModule("QuestieQuest")
---@type QuestieQuestPrivate
QuestieQuest.private = QuestieQuest.private or {}
local _QuestieQuest = QuestieQuest.private
-------------------------
--Import modules.
-------------------------
---@type QuestieProfessions
local QuestieProfessions = QuestieLoader:ImportModule("QuestieProfessions")
---@type QuestieReputation
local QuestieReputation = QuestieLoader:ImportModule("QuestieReputation")
---@type QuestieTooltips
local QuestieTooltips = QuestieLoader:ImportModule("QuestieTooltips")
---@type QuestieTracker
local QuestieTracker = QuestieLoader:ImportModule("QuestieTracker")
---@type QuestieDBMIntegration
local QuestieDBMIntegration = QuestieLoader:ImportModule("QuestieDBMIntegration")
---@type QuestieMap
local QuestieMap = QuestieLoader:ImportModule("QuestieMap")
---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
---@type QuestiePlayer
local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")
---@type TaskQueue
local TaskQueue = QuestieLoader:ImportModule("TaskQueue")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type ZoneDB
local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
---@type QuestieCombatQueue
local QuestieCombatQueue = QuestieLoader:ImportModule("QuestieCombatQueue")
---@type QuestieAnnounce
local QuestieAnnounce = QuestieLoader:ImportModule("QuestieAnnounce")
---@type QuestieMenu
local QuestieMenu = QuestieLoader:ImportModule("QuestieMenu")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")
---@type QuestLogCache
local QuestLogCache = QuestieLoader:ImportModule("QuestLogCache")
---@type ThreadLib
local ThreadLib = QuestieLoader:ImportModule("ThreadLib")
---@type AvailableQuests
local AvailableQuests = QuestieLoader:ImportModule("AvailableQuests")

--- COMPATIBILITY ---
local C_Timer = QuestieCompat.C_Timer
local GetQuestsCompleted = QuestieCompat.GetQuestsCompleted
local xpcall = QuestieCompat.xpcall

--We should really try and squeeze out all the performance we can, especially in this.
local tostring = tostring;
local tinsert = table.insert;
local pairs = pairs;
local ipairs = ipairs;
local yield = coroutine.yield
local NewThread = ThreadLib.ThreadSimple

local NOP_FUNCTION = function()
end
local ERR_FUNCTION = function(err)
    Questie:Error("[QuestieQuest] " .. tostring(err))
    if debugstack then
        local stack = debugstack()
        if stack and type(stack) == "string" then
            Questie:Debug(Questie.DEBUG_CRITICAL, "Stack Trace:\n" .. stack:sub(1, 1000))
        end
    end
end

-- forward declaration
local _UnloadAlreadySpawnedIcons
local _RegisterObjectiveTooltips, _DetermineIconsToDraw, _GetIconsSortedByDistance
local _DrawObjectiveIcons, _DrawObjectiveWaypoints

local HBD = QuestieCompat.HBD or LibStub("HereBeDragonsQuestie-2.0")

function QuestieQuest:Initialize()
    Questie:Debug(Questie.DEBUG_INFO, "[QuestieQuest]: Getting all completed quests")
    Questie.db.char.complete = GetQuestsCompleted()

    QuestieProfessions:Update()
    QuestieReputation:Update(true)
end

---@param category AutoBlacklistString
function QuestieQuest.ResetAutoblacklistCategory(category)
    Questie:Debug(Questie.DEBUG_SPAM, "[QuestieQuest]: Resetting autoblacklist category", category)
    local questId, questCategory = next(QuestieDB.autoBlacklist)
    while questId do
        if questCategory == category then
            QuestieDB.autoBlacklist[questId] = nil
        end
        questId, questCategory = next(QuestieDB.autoBlacklist, questId)
    end
end

function QuestieQuest:ToggleNotes(showIcons)
    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest:ToggleNotes] showIcons:", showIcons)
    QuestieQuest:GetAllQuestIds() -- add notes that weren't added from previous hidden state

    if showIcons then
        _QuestieQuest:ShowQuestIcons()
        _QuestieQuest:ShowManualIcons()
    else
        _QuestieQuest:HideQuestIcons()
        _QuestieQuest:HideManualIcons()
    end
end

function _QuestieQuest:ShowQuestIcons()
    local trackerHiddenQuests = Questie.db.char.TrackerHiddenQuests
    local questId, frameList = next(QuestieMap.questIdFrames)
    while questId do
        if (not trackerHiddenQuests) or (not trackerHiddenQuests[questId]) then -- Skip quests which are completely hidden from the Tracker menu
            local _, frameName = next(frameList)
            while _ do -- this may seem a bit expensive, but its actually really fast due to the order things are checked
                ---@type IconFrame
                local icon = _G[frameName];
                if not icon.data then
                    error("Desync! Icon has not been removed correctly, but has already been reset. Skipping frame \"" ..
                    frameName .. "\" for quest " .. questId)
                else
                    local objectiveString = tostring(questId) .. " " .. tostring(icon.data.ObjectiveIndex)
                    if (not Questie.db.char.TrackerHiddenObjectives) or (not Questie.db.char.TrackerHiddenObjectives[objectiveString]) then
                        if icon ~= nil and icon.hidden and (not icon:ShouldBeHidden()) then
                            icon:FakeShow()

                            if icon.data.lineFrames then
                                local __, lineIcon = next(icon.data.lineFrames)
                                while __ do
                                    lineIcon:FakeShow()
                                    __, lineIcon = next(icon.data.lineFrames, __)
                                end
                            end
                        end
                        if (icon.data.QuestData.FadeIcons or (icon.data.ObjectiveData and icon.data.ObjectiveData.FadeIcons)) and icon.data.Type ~= "complete" then
                            icon:FadeOut()
                        else
                            icon:FadeIn()
                        end
                    end
                end
                _, frameName = next(frameList, _)
            end
        end
        questId, frameList = next(QuestieMap.questIdFrames, questId)
    end
end

function _QuestieQuest:ShowManualIcons()
    local _, frameList = next(QuestieMap.manualFrames)
    while _ do
        local __, frameName = next(frameList)
        while __ do
            local icon = _G[frameName];
            if icon ~= nil and icon.hidden and (not icon:ShouldBeHidden()) then -- check for function to make sure its a frame
                icon:FakeShow()
            end
            __, frameName = next(frameList, __)
        end
        _, frameList = next(QuestieMap.manualFrames, _)
    end
end

function _QuestieQuest:HideQuestIcons()
    local _, frameList = next(QuestieMap.questIdFrames)
    while _ do
        local __, frameName = next(frameList)
        while __ do -- this may seem a bit expensive, but its actually really fast due to the order things are checked
            local icon = _G[frameName];
            if icon ~= nil and (not icon.hidden) and icon:ShouldBeHidden() then -- check for function to make sure its a frame
                -- Hides Objective Icons
                icon:FakeHide()

                -- Hides Objective Tooltips
                QuestieTooltips:RemoveQuest(icon.data.Id)

                if icon.data.lineFrames then
                    local ___, lineIcon = next(icon.data.lineFrames)
                    while ___ do
                        lineIcon:FakeHide()
                        ___, lineIcon = next(icon.data.lineFrames, ___)
                    end
                end
            end
            if (icon.data.QuestData.FadeIcons or (icon.data.ObjectiveData and icon.data.ObjectiveData.FadeIcons)) and icon.data.Type ~= "complete" then
                icon:FadeOut()
            else
                icon:FadeIn()
            end
            __, frameName = next(frameList, __)
        end
        _, frameList = next(QuestieMap.questIdFrames, _)
    end
end

function _QuestieQuest:HideManualIcons()
    local _, frameList = next(QuestieMap.manualFrames)
    while _ do
        local __, frameName = next(frameList)
        while __ do
            local icon = _G[frameName];
            if icon ~= nil and (not icon.hidden) and icon:ShouldBeHidden() then -- check for function to make sure its a frame
                icon:FakeHide()
            end
            __, frameName = next(frameList, __)
        end
        _, frameList = next(QuestieMap.manualFrames, _)
    end
end

function QuestieQuest:ClearAllNotes()
    local questId, _ = next(QuestiePlayer.currentQuestlog)
    while questId do
        local quest = QuestieDB.GetQuest(questId)

        if not quest then
            return
        end

        local index, s = next(quest.Objectives)
        while index do
            s.AlreadySpawned = {}
            index, s = next(quest.Objectives, index)
        end

        if next(quest.SpecialObjectives) then
            local sIndex, s = next(quest.SpecialObjectives)
            while sIndex do
                s.AlreadySpawned = {}
                sIndex, s = next(quest.SpecialObjectives, sIndex)
            end
        end
        questId, _ = next(QuestiePlayer.currentQuestlog, questId)
    end

    local _, frameList = next(QuestieMap.questIdFrames)
    while _ do
        local __, frameName = next(frameList)
        while __ do
            local icon = _G[frameName]
            if icon and icon.Unload then
                icon:Unload()
            end
            __, frameName = next(frameList, __)
        end
        _, frameList = next(QuestieMap.questIdFrames, _)
    end

    QuestieMap.questIdFrames = {}
end

function QuestieQuest:ClearAllToolTips()
    local questId, _ = next(QuestiePlayer.currentQuestlog)
    while questId do
        local quest = QuestieDB.GetQuest(questId)

        if not quest then
            return
        end

        if quest.Objectives then
            local oId, objective = next(quest.Objectives)
            while oId do
                if objective.hasRegisteredTooltips then
                    objective.hasRegisteredTooltips = false
                end

                if objective.registeredItemTooltips then
                    objective.registeredItemTooltips = false
                end
                oId, objective = next(quest.Objectives, oId)
            end
        end

        if quest.ObjectiveData then
            local odId, objective = next(quest.ObjectiveData)
            while odId do
                if objective.hasRegisteredTooltips then
                    objective.hasRegisteredTooltips = false
                end

                if objective.registeredItemTooltips then
                    objective.registeredItemTooltips = false
                end
                odId, objective = next(quest.ObjectiveData, odId)
            end
        end

        if next(quest.SpecialObjectives) then
            local soId, objective = next(quest.SpecialObjectives)
            while soId do
                if objective.hasRegisteredTooltips then
                    objective.hasRegisteredTooltips = false
                end

                if objective.registeredItemTooltips then
                    objective.registeredItemTooltips = false
                end
                soId, objective = next(quest.SpecialObjectives, soId)
            end
        end
        questId, _ = next(QuestiePlayer.currentQuestlog, questId)
    end

    QuestieTooltips.lookupByKey = {}
    QuestieTooltips.lookupKeyByQuestId = {}
end

-- This is only needed for SmoothReset(), normally special objectives don't need to update
---@param questId number
local function _UpdateSpecials(questId)
    local quest = QuestieDB.GetQuest(questId)
    if quest and next(quest.SpecialObjectives) then
        local _, objective = next(quest.SpecialObjectives)
        while _ do
            local result, err = xpcall(QuestieQuest.PopulateObjective, ERR_FUNCTION, QuestieQuest, quest, 0, objective,
                true)
            if not result then
                Questie:Error("[QuestieQuest]: [SpecialObjectives] " ..
                l10n("There was an error populating objectives for %s %s %s %s", quest.name or "No quest name",
                    quest.Id or "No quest id", 0 or "No objective", err or "No error"));
            end
            _, objective = next(quest.SpecialObjectives, _)
        end
    end
end

function QuestieQuest:SmoothReset()
    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest:SmoothReset]")
    if QuestieQuest._isResetting then
        QuestieQuest._resetAgain = true
        return
    end
    QuestieQuest._isResetting = true
    QuestieQuest._resetNeedsAvailables = false

    -- bit of a hack (there has to be a better way to do logic like this
    QuestieDBMIntegration:ClearAll()
    local stepTable = {
        function()
            -- Wait until game cache has quest log okay.
            return QuestLogCache.TestGameCache()
        end,
        function()
            return table.getn(QuestieMap._mapDrawQueue) == 0 and
            table.getn(QuestieMap._minimapDrawQueue) == 0                                           -- wait until draw queue is finished
        end,
        function()
            QuestieQuest:ClearAllNotes()
            QuestieQuest:ClearAllToolTips()
            return true
        end,
        function()
            QuestieMenu:OnLogin(true) -- remove icons
            return true
        end,
        function()
            return table.getn(QuestieMap._mapDrawQueue) == 0 and
            table.getn(QuestieMap._minimapDrawQueue) == 0                                           -- wait until draw queue is finished
        end,
        function()
            -- reset quest log
            QuestiePlayer.currentQuestlog = {}

            --- reset the blacklist
            QuestieDB.autoBlacklist = {}

            -- make sure complete db is correct
            Questie.db.char.complete = GetQuestsCompleted()
            QuestieProfessions:Update()
            QuestieReputation:Update(true)

            -- populate QuestiePlayer.currentQuestlog
            QuestieQuest:GetAllQuestIdsNoObjectives()
            QuestieQuest._nextRestQuest = next(QuestiePlayer.currentQuestlog)
            return true
        end,
        function()
            QuestieMenu:OnLogin()
            return true
        end,
        function()
            QuestieQuest._resetNeedsAvailables = true
            AvailableQuests.CalculateAndDrawAll(function() QuestieQuest._resetNeedsAvailables = false end)
            return true
        end,
        function()
            for _ = 1, 64 do
                if QuestieQuest._nextRestQuest then
                    QuestieQuest:UpdateQuest(QuestieQuest._nextRestQuest)
                    _UpdateSpecials(QuestieQuest._nextRestQuest)
                    QuestieQuest._nextRestQuest = next(QuestiePlayer.currentQuestlog, QuestieQuest._nextRestQuest)
                else
                    QuestieCombatQueue:Queue(function()
                        C_Timer.After(2.0, function()
                            QuestieTracker:Update()
                        end)
                    end)
                    break
                end
            end
            return not QuestieQuest._nextRestQuest
        end,
        function()
            return (not QuestieQuest._resetNeedsAvailables) and table.getn(QuestieMap._mapDrawQueue) == 0 and
            table.getn(QuestieMap._minimapDrawQueue) == 0
        end,
        function()
            QuestieQuest._isResetting = nil
            if QuestieQuest._resetAgain then
                QuestieQuest._resetAgain = nil
                QuestieQuest:SmoothReset()
            end
            return true
        end
    }
    local step = 1
    local ticker
    ticker = C_Timer.NewTicker(0.01, function()
        if stepTable[step]() then
            step = step + 1
            if not stepTable[step] then
                ticker:Cancel()
            end
        end
        if QuestieQuest._resetAgain and not QuestieQuest._resetNeedsAvailables then -- we can stop the current reset
            ticker:Cancel()
            QuestieQuest._resetAgain = nil
            QuestieQuest._isResetting = nil
            QuestieQuest:SmoothReset()
        end
    end)
end

---@param questId number
---@return boolean
function QuestieQuest:ShouldShowQuestNotes(questId)
    if not Questie.db.profile.hideUntrackedQuestsMapIcons then
        return true
    end

    local autoWatch = Questie.db.profile.autoTrackQuests
    local trackedAuto = autoWatch and
    (not Questie.db.char.AutoUntrackedQuests or not Questie.db.char.AutoUntrackedQuests[questId])
    local trackedManual = not autoWatch and (Questie.db.char.TrackedQuests and Questie.db.char.TrackedQuests[questId])
    return trackedAuto or trackedManual
end

function QuestieQuest:HideQuest(id)
    Questie.db.char.hidden[id] = true
    -- Only unload frames/tooltips if the quest is NOT in the live quest log.
    -- A completed-but-logged quest (e.g. Quest 8325) must keep its pins even when hidden.
    if not QuestiePlayer.currentQuestlog[id] then
        QuestieMap:UnloadQuestFrames(id)
        QuestieTooltips:RemoveQuest(id)
    end
end

function QuestieQuest:UnhideQuest(id)
    Questie.db.char.hidden[id] = nil
    AvailableQuests.CalculateAndDrawAll()
end

--- Returns true when a quest can be safely unloaded from the map/tooltip tracker.
--- Completion is in char.complete AND the quest is not in the live quest log.
--- Prevents Quest 8325 flicker: completed-but-logged quests must keep their pins.
---@param questId number
---@return boolean
function QuestieQuest:IsSafeToUnloadQuestFrames(questId)
    return Questie.db.char.complete[questId] and not QuestiePlayer.currentQuestlog[questId]
end

local allianceTournamentMarkerQuests = { [13684] = true, [13685] = true, [13688] = true, [13689] = true, [13690] = true,
    [13593] = true, [13703] = true, [13704] = true, [13705] = true, [13706] = true }
local hordeTournamentMarkerQuests = { [13691] = true, [13693] = true, [13694] = true, [13695] = true, [13696] = true,
    [13707] = true, [13708] = true, [13709] = true, [13710] = true, [13711] = true }

---@param questId number
function QuestieQuest:AcceptQuest(questId)
    local quest = QuestieDB.GetQuest(questId)

    if quest then
        -- If any of these flags exist, this quest was previously accepted and may
        -- have stale completion state (e.g. complete-then-abandon-then-reaccept leaves
        -- quest.isComplete=true, WasComplete=true). Only check quest-object flags
        -- (WasComplete, isComplete), NOT QuestieDB.IsComplete, because IsComplete
        -- returns 0 for any incomplete quest — including brand new acceptances.
        -- The original code also checked complete==0 and complete==-1, but those
        -- combined with removing the currentQuestlog guard caused every quest
        -- acceptance to enter this block and unload freshly-drawn pins.
        -- DEBUG: Log stale flag state on accept
        Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest] AcceptQuest state check - questId:", questId,
            " WasComplete:", tostring(quest.WasComplete),
            " isComplete:", tostring(quest.isComplete),
            " currentQuestlog:", tostring(QuestiePlayer.currentQuestlog[questId] and "present" or "nil"))

        if quest.WasComplete or quest.isComplete then
            Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest] AcceptQuest RESET BLOCK firing for questId:", questId)

            -- Reset quest log (may already be nil after QUEST_REMOVED)
            QuestiePlayer.currentQuestlog[questId] = nil

            -- Reset quest objectives (clear stale Completed/isUpdated flags that
            -- would prevent map pins from being drawn on re-accept)
            if type(quest.Objectives) == "table" then
                for k in pairs(quest.Objectives) do
                    quest.Objectives[k] = nil
                end
            else
                quest.Objectives = {}
            end

            -- Reset SpecialObjectives too
            if type(quest.SpecialObjectives) == "table" then
                for k in pairs(quest.SpecialObjectives) do
                    quest.SpecialObjectives[k] = nil
                end
            end

            -- Reset quest flags
            quest.WasComplete = nil
            quest.isComplete = nil

            -- Ensure isUpdated flags are reset so ObjectiveUpdate will refresh
            -- objective state from the quest log instead of short-circuiting
            QuestieQuest:SetObjectivesDirty(questId)

            -- Reset tooltips
            QuestieTooltips:RemoveQuest(questId)

            -- Unload map pins from previous acceptance so they don't linger
            QuestieMap:UnloadQuestFrames(questId)
        end

        if not QuestiePlayer.currentQuestlog[questId] then
            Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest] AcceptQuest NORMAL path - questId:", questId,
                " quest.isComplete:", tostring(quest.isComplete),
                " quest.WasComplete:", tostring(quest.WasComplete),
                " quest.Objectives:", quest.Objectives and next(quest.Objectives) and "has entries" or "empty")

            QuestiePlayer.currentQuestlog[questId] = quest

            if allianceTournamentMarkerQuests[questId] then
                Questie.db.char.complete[13686] = true -- Alliance Tournament Eligibility Marker
            elseif hordeTournamentMarkerQuests[questId] then
                Questie.db.char.complete[13687] = true -- Horde Tournament Eligibility Marker
            end

            TaskQueue:Queue(
            -- Get all the Frames for the quest and unload them, the available quest icon for example.
                function() QuestieMap:UnloadQuestFrames(questId) end,
                -- Make sure there isn't any lingering tooltip data hanging around in the quest table.
                function() QuestieTooltips:RemoveQuest(questId) end,
                function()
                    -- Re-accepted quest can be collapsed. Expand it. Especially dailies.
                    if Questie.db.char.collapsedQuests then
                        Questie.db.char.collapsedQuests[questId] = nil
                    end
                    -- Re-accepted quest can be untracked. Clear it. Especially timed quests.
                    if Questie.db.char.AutoUntrackedQuests[questId] then
                        Questie.db.char.AutoUntrackedQuests[questId] = nil
                    end
                end,
                function() QuestieQuest:PopulateQuestLogInfo(quest) end,
                function()
                    -- This needs to happen after QuestieQuest:PopulateQuestLogInfo because that is the place where quest.Objectives is generated
                    Questie:SendMessage("QC_ID_BROADCAST_QUEST_UPDATE", questId)
                end,
                function() QuestieQuest:PopulateObjectiveNotes(quest) end,
                function() AvailableQuests.CalculateAndDrawAll() end,
                function()
                    QuestieCombatQueue:Queue(function()
                        QuestieTracker:Update()
                    end)
                end,
                function()
                    if QuestieArrow and QuestieArrow.Refresh then
                        QuestieArrow:Refresh()
                    end
                end
            )
        else
            Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest] AcceptQuest DUPLICATE - questId:", questId,
                " Warning: Quest already exists in currentQuestlog, not processing!")
        end
    end
end

local allianceChampionMarkerQuests = { [13699] = true, [13713] = true, [13723] = true, [13724] = true, [13725] = true }
local hordeChampionMarkerQuests = { [13726] = true, [13727] = true, [13728] = true, [13729] = true, [13731] = true }

---@param questId number
function QuestieQuest:CompleteQuest(questId)
    -- Skip quests which are turn in only and are not added to the quest log in the first place
    local questLogEntry = QuestiePlayer.currentQuestlog[questId]
    if questLogEntry then
        -- Only reset flags if the entry is a table (not a legacy number)
        if type(questLogEntry) == "table" then
            questLogEntry.WasComplete = nil
            questLogEntry.isComplete = nil
        end
        QuestiePlayer.currentQuestlog[questId] = nil;
    end

    -- Only quests that are daily quests or aren't repeatable should be marked complete,
    -- otherwise objectives for repeatable quests won't track correctly - #1433
    if QuestieCompat.Is335 then
        QuestieCompat.SetQuestComplete(questId)
    else
        Questie.db.char.complete[questId] = (not QuestieDB.IsRepeatable(questId)) or QuestieDB.IsDailyQuest(questId) or
        QuestieDB.IsWeeklyQuest(questId);
    end

    if allianceChampionMarkerQuests[questId] then
        Questie.db.char.complete[13700] = true -- Alliance Champion Marker
        Questie.db.char.complete[13686] = nil  -- Alliance Tournament Eligibility Marker
    elseif hordeChampionMarkerQuests[questId] then
        Questie.db.char.complete[13701] = true -- Horde Champion Marker
        Questie.db.char.complete[13687] = nil  -- Horde Tournament Eligibility Marker
    end
    -- Clear stale objective data so a subsequent re-accept doesn't inherit
    -- Cached Completed=true / isUpdated=true flags that would cause
    -- PopulateObjectiveNotes to skip drawing map pins (bug: complete-abandon-reaccept).
    local quest = QuestieDB.GetQuest(questId)
    if quest and type(quest.Objectives) == "table" then
        quest.Objectives = {}
    end

    QuestieMap:UnloadQuestFrames(questId)

    -- Clear the pending-complete guard now that frames are unloaded
    if QuestiePlayer.pendingCompleteQuestIds then
        QuestiePlayer.pendingCompleteQuestIds[questId] = nil
    end

    if (QuestieMap.questIdFrames[questId]) then
        Questie:Error("Just removed all frames but the framelist seems to still be there!", questId)
    end

    -- Delayed verification to ensure all objective icons are removed
    -- This handles race conditions where AvailableQuests might redraw icons or UnloadQuestFrames misses some
    C_Timer.After(0.5, function()
        if QuestieMap.questIdFrames[questId] then
            Questie:Debug(Questie.DEBUG_INFO, "[QuestieQuest:CompleteQuest] Lingering frames detected for quest:",
                questId, "- forcing cleanup")
            QuestieMap:UnloadQuestFrames(questId)
        end
    end)

    QuestieTooltips:RemoveQuest(questId)
    QuestieTracker:RemoveQuest(questId)
    QuestieCombatQueue:Queue(function()
        QuestieTracker:Update()
    end)

    -- TODO: Should this be done first? Because CalculateAndDrawAll looks at QuestieMap.questIdFrames[QuestId] to add available
    AvailableQuests.CalculateAndDrawAll()

    Questie:Debug(Questie.DEBUG_INFO, "[QuestieQuest] Completed Quest:", questId)
end

---@param questId number
function QuestieQuest:AbandonedQuest(questId)
    -- NOTE: Some servers remove quests without firing QUEST_REMOVED reliably.
    -- Always cleanup frames/tracker even if the quest isn't currently in QuestiePlayer.currentQuestlog.
    if QuestiePlayer.currentQuestlog then
        QuestiePlayer.currentQuestlog[questId] = nil
    end

    QuestieMap:UnloadQuestFrames(questId)

    local quest = QuestieDB.GetQuest(questId)
    if quest then
        Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest] AbandonedQuest - questId:", questId,
            " WasComplete:", tostring(quest.WasComplete),
            " isComplete:", tostring(quest.isComplete),
            " Objectives:", quest.Objectives and next(quest.Objectives) and "has entries" or "empty")

        -- Reset quest objectives
        quest.Objectives = {}

        -- Reset quest flags
        quest.WasComplete = nil
        quest.isComplete = nil

        if allianceTournamentMarkerQuests[questId] then
            Questie.db.char.complete[13686] = nil -- Alliance Tournament Eligibility Marker
        elseif hordeTournamentMarkerQuests[questId] then
            Questie.db.char.complete[13687] = nil -- Horde Tournament Eligibility Marker
        end

        local childQuests = QuestieDB.QueryQuestSingle(questId, "childQuests")
        if childQuests then
            local _, childQuestId = next(childQuests)
            while _ do
                Questie.db.char.complete[childQuestId] = nil
                QuestLogCache.RemoveQuest(childQuestId)
                _, childQuestId = next(childQuests, _)
            end
        end
    end

    AvailableQuests.UnloadUndoable()

    QuestieTracker:RemoveQuest(questId)
    QuestieTooltips:RemoveQuest(questId)
    QuestieCombatQueue:Queue(function()
        QuestieTracker:Update()
    end)

    AvailableQuests.CalculateAndDrawAll()

    -- Delayed verification to ensure all objective icons are removed
    -- This handles race conditions where QuestieQuest:UpdateQuest might redraw icons
    -- just as we are abandoning the quest
    C_Timer.After(0.5, function()
        if QuestieMap.questIdFrames[questId] then
            Questie:Debug(Questie.DEBUG_INFO, "[QuestieQuest:AbandonedQuest] Lingering frames detected for quest:",
                questId, "- forcing cleanup")
            QuestieMap:UnloadQuestFrames(questId)
        end
    end)

    Questie:Debug(Questie.DEBUG_INFO, "[QuestieQuest] Abandoned Quest:", questId)
end

---@param questId number
function QuestieQuest:UpdateQuest(questId)
    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest:UpdateQuest]", questId)

    ---@type Quest
    local quest = QuestieDB.GetQuest(questId)

    local sourceItemId = (quest and tonumber(quest.sourceItemId)) or 0

    if quest and (not Questie.db.char.complete[questId] or QuestiePlayer.currentQuestlog[questId]) then
        -- Skip this update if the quest is mid-completion to avoid redrawing objective pins
        -- that CompleteQuest is about to remove via UnloadQuestFrames.
        if QuestiePlayer.pendingCompleteQuestIds and QuestiePlayer.pendingCompleteQuestIds[questId] then
            Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest:UpdateQuest] Skipping - quest is pending completion:", questId)
            return
        end
        QuestieQuest:PopulateQuestLogInfo(quest)

        -- Defensive: clear stale isComplete/WasComplete after PopulateQuestLogInfo
        -- syncs quest log state. This catches cases where PopulateQuestLogInfo ran
        -- but the quest log cache didn't have the isComplete field (nil), in which
        -- case the else branch above wouldn't clear the flags.
        if quest.isComplete then
            local dbComplete = QuestieDB.IsComplete(questId)
            if dbComplete ~= 1 then
                quest.isComplete = nil
                Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest:UpdateQuest] Cleared stale isComplete for quest:", questId)
            end
        end
        if quest.WasComplete then
            local dbComplete = QuestieDB.IsComplete(questId)
            if dbComplete ~= 1 then
                quest.WasComplete = nil
                Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest:UpdateQuest] Cleared stale WasComplete for quest:", questId)
            end
        end

        local showNotes = QuestieQuest:ShouldShowQuestNotes(questId)
        Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest:UpdateQuest] ShouldShowQuestNotes:", tostring(showNotes), "questId:", questId)
        if showNotes then
            QuestieQuest:UpdateObjectiveNotes(quest)
        else
            Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest:UpdateQuest] ShouldShowQuestNotes=false, removing tooltips for questId:", questId)
            QuestieTooltips:RemoveQuest(questId)
        end

        local isComplete = QuestieDB.IsComplete(questId)

        Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest:UpdateQuest] QuestDB:IsComplete() flag is: " .. isComplete)

        if isComplete == 1 then
            -- Quest is complete
            Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest:UpdateQuest] Quest is: Complete!")

            QuestieMap:UnloadQuestFrames(questId)
            QuestieQuest:AddFinisher(quest)
            quest.WasComplete = true
        elseif isComplete == -1 then
            -- Failed quests should be shown as available again
            Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest:UpdateQuest] Quest has: Failed!")

            QuestieMap:UnloadQuestFrames(questId)
            QuestieTooltips:RemoveQuest(questId)
            AvailableQuests.DrawAvailableQuest(quest)

            -- Reset any collapsed quest flags
            if Questie.db.char.collapsedQuests then
                Questie.db.char.collapsedQuests[questId] = nil
            end
        elseif isComplete == 0 then
            -- Quest was somehow reset back to incomplete after being completed (quest.WasComplete == true).
            -- The "or" check looks for a sourceItemId then checks to see if it's NOT in the players bag.
            -- Player destroyed quest items? Or some other quest mechanic removed the needed quest item.
            -- Check if all objectives are already complete before treating a missing source item as a reset.
            -- Some quests use consumable key items (e.g. Cold Iron Key for quest 12843). After using the key
            -- the item leaves the bag, making CheckQuestSourceItem return false. Without this guard, Questie
            -- would reset the quest and draw the key-drop NPC on the map even though all objectives are done.
            local allObjectivesComplete = false
            if quest.Objectives and table.getn(quest.Objectives) > 0 then
                local doneCount = 0
                for i = 1, table.getn(quest.Objectives) do
                    if quest.Objectives[i] and quest.Objectives[i].Completed == true then
                        doneCount = doneCount + 1
                    end
                end
                allObjectivesComplete = (doneCount == table.getn(quest.Objectives))
            end

            if quest and not allObjectivesComplete and (quest.WasComplete or (sourceItemId > 0 and QuestieQuest:CheckQuestSourceItem(questId) == false)) then
                Questie:Debug(Questie.DEBUG_DEVELOP,
                    "[QuestieQuest:UpdateQuest] Quest was once complete or Quest Item(s) were removed. Resetting quest.")

                -- Reset quest objectives
                quest.Objectives = {}

                -- Reset quest flags
                quest.WasComplete = nil
                quest.isComplete = nil

                -- Reset tooltips
                QuestieTooltips:RemoveQuest(questId)

                QuestieQuest:CheckQuestSourceItem(questId, true)
                QuestieMap:UnloadQuestFrames(questId)

                -- Reset any collapsed quest flags
                if Questie.db.char.collapsedQuests then
                    Questie.db.char.collapsedQuests[questId] = nil
                end

                QuestieQuest:PopulateQuestLogInfo(quest)
                QuestieQuest:PopulateObjectiveNotes(quest)
                AvailableQuests.CalculateAndDrawAll()
            else
                -- Robustness: ensure objective pins are present for incomplete quests.
                -- On Ascension, quest log cache can be stale after reload/abandon-reaccept,
                -- leaving objectives empty or AlreadySpawned pointing to dead frames.
                if showNotes then
                    local hasObjectives = quest.Objectives and table.getn(quest.Objectives) > 0
                    local hasFrames = QuestieMap.questIdFrames[questId] ~= nil

                    if not hasObjectives then
                        Questie:Debug(Questie.DEBUG_DEVELOP,
                            "[QuestieQuest:UpdateQuest] Objectives missing for incomplete quest, re-populating:", questId)
                        QuestieQuest:PopulateQuestLogInfo(quest)
                        hasObjectives = quest.Objectives and table.getn(quest.Objectives) > 0
                        if hasObjectives then
                            QuestieQuest:PopulateObjectiveNotes(quest)
                        end
                    elseif not hasFrames then
                        -- Objectives exist but no frames on map: AlreadySpawned may be stale
                        Questie:Debug(Questie.DEBUG_DEVELOP,
                            "[QuestieQuest:UpdateQuest] Incomplete quest has objectives but no map frames, clearing AlreadySpawned:", questId)
                        for _, objective in pairs(quest.Objectives) do
                            if objective.AlreadySpawned then
                                objective.AlreadySpawned = {}
                            end
                        end
                        QuestieQuest:PopulateObjectiveNotes(quest)
                    end
                end

                -- Sometimes objective(s) are all complete but the quest doesn't get flagged as "1". So far the only
                -- quests I've found that does this are quests involving an item(s). Checks all objective(s) and if they
                -- are all complete, simulate a "Complete Quest" so the quest finisher appears on the map.
                if quest.Objectives and table.getn(quest.Objectives) > 0 then
                    local numCompleteObjectives = 0

                    for i = 1, table.getn(quest.Objectives) do
                        if quest.Objectives[i] and quest.Objectives[i].Completed and quest.Objectives[i].Completed == true then
                            numCompleteObjectives = numCompleteObjectives + 1
                        end
                    end

                    if numCompleteObjectives == table.getn(quest.Objectives) then
                        Questie:Debug(Questie.DEBUG_DEVELOP,
                            "[QuestieQuest:UpdateQuest] All Quest Objective(s) are Complete! Manually setting quest to Complete!")
                        QuestieMap:UnloadQuestFrames(questId)
                        QuestieQuest:AddFinisher(quest)
                        quest.WasComplete = true
                        quest.isComplete = true
                    else
                        Questie:Debug(Questie.DEBUG_DEVELOP,
                            "[QuestieQuest:UpdateQuest] Quest Objective Status is: " ..
                            numCompleteObjectives .. ", out of: " .. table.getn(quest.Objectives) .. ". No updates required.")
                    end
                end
            end
        end

        Questie:SendMessage("QC_ID_BROADCAST_QUEST_UPDATE", questId)
    end
end

---@param questId number
function QuestieQuest:SetObjectivesDirty(questId)
    local quest = QuestieDB.GetQuest(questId)

    if quest then
        local objKey, objective = next(quest.Objectives or {})
        while objKey do
            objective.isUpdated = false
            objKey, objective = next(quest.Objectives, objKey)
        end
        -- Also dirty SpecialObjectives (e.g. demonic runestones, portal-closing mechanics).
        -- Without this, ObjectiveUpdate's isUpdated early-exit prevents objective.Completed
        -- from being set to true, so _UnloadAlreadySpawnedIcons is never reached and icons
        -- linger on the map/minimap after the objectives are fulfilled.
        local soKey, sObjective = next(quest.SpecialObjectives or {})
        while soKey do
            sObjective.isUpdated = false
            soKey, sObjective = next(quest.SpecialObjectives, soKey)
        end
    end
end

--Run this if you want to update the entire table
function QuestieQuest:GetAllQuestIds()
    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest] Getting all quests")

    QuestiePlayer.currentQuestlog = {}

    local questId, data = next(QuestLogCache.questLog_DO_NOT_MODIFY)
    while questId do
        local quest = QuestieDB.GetQuest(questId)

        if not quest then
            if not Questie._sessionWarnings[questId] then
                if not Questie.IsSoD then
                    Questie:Error(l10n(
                    "The quest %s is missing from Questie's database. Please report this on GitHub or Discord!",
                        tostring(questId)))
                end
                Questie._sessionWarnings[questId] = true
            end

            QuestiePlayer.currentQuestlog[questId] = questId -- legacy behavior
        else
            local complete = QuestieDB.IsComplete(questId)

            QuestiePlayer.currentQuestlog[questId] = quest
            quest.LocalizedName = data.title

            if complete == -1 then
                QuestieQuest:UpdateQuest(questId)
            else
                -- Only draw the source item objective when the quest is not yet complete.
                -- If the quest is complete (complete == 1), the source item was consumed during
                -- the quest (e.g. Cold Iron Key for quest 12843) and should not draw its drop NPC.
                if complete == 1 then
                    -- Mark the quest object as complete so QuestieArrow collects finisher spawns
                    -- instead of objective spawns. Without this, the arrow falls through to the
                    -- objective collection path and picks up any stale fake item objectives.
                    quest.isComplete = true
                    quest.WasComplete = true
                else
                    QuestieQuest:CheckQuestSourceItem(questId, true)
                end
                QuestieQuest:PopulateQuestLogInfo(quest)

                if QuestieQuest:ShouldShowQuestNotes(questId) then
                    QuestieQuest:PopulateObjectiveNotes(quest)
                else
                    QuestieTooltips:RemoveQuest(questId)
                end
            end

            Questie:Debug(Questie.DEBUG_INFO, "[QuestieQuest] Adding the quest", questId,
                QuestiePlayer.currentQuestlog[questId])
        end
        questId, data = next(QuestLogCache.questLog_DO_NOT_MODIFY, questId)
    end

    QuestieCombatQueue:Queue(function()
        QuestieTracker:Update()
    end)
end

-- This checks and manually adds quest item tooltips for sourceItems
local function _AddSourceItemObjective(quest)
    local sourceItemId = tonumber(quest.sourceItemId) or 0
    if sourceItemId <= 0 then
        return
    end

    local questObjectives = QuestieDB.QueryQuestSingle(quest.Id, "objectives")
    local itemObjectives = questObjectives and questObjectives[3]

    -- If sourceItemId is already part of an item objective, do nothing
    if itemObjectives then
        local k1, itemObjectiveIndex = next(itemObjectives)
        while k1 do
            local k2, itemObjectiveId = next(itemObjectiveIndex or {})
            while k2 do
                if itemObjectiveId == sourceItemId then
                    Questie:Debug(Questie.DEBUG_INFO,
                        "[QuestieQuest:_AddSourceItemObjective] This item is already part of a quest objective.")
                    return
                end
                k2, itemObjectiveId = next(itemObjectiveIndex, k2)
            end
            k1, itemObjectiveIndex = next(itemObjectives, k1)
        end
    end

    local itemName = QuestieDB.QueryItemSingle(sourceItemId, "name")
    if not itemName then
        return
    end

    Questie:Debug(Questie.DEBUG_INFO, "[QuestieQuest:_AddSourceItemObjective] Adding Source Item Id for:", sourceItemId)

    local fakeObjective = {
        Id = quest.Id,
        IsSourceItem = true,
        QuestData = quest,
        Index = 1,
        Needed = 1,
        Collected = 1,
        text = itemName,
        Description = itemName
    }

    QuestieTooltips:RegisterObjectiveTooltip(quest.Id, "i_" .. sourceItemId, fakeObjective);
end

-- This checks and manually adds quest item tooltips for SpellItems
local function _AddSpellItemObjective(quest)
    if not quest.SpellItemId then
        return
    end

    local questObjectives = QuestieDB.QueryQuestSingle(quest.Id, "objectives")
    local spellObjectives = questObjectives and questObjectives[6]
    if not spellObjectives then
        return
    end

    local depthIndex = 1 -- TODO: What is better for this?
    local needed = (quest.Objectives and quest.Objectives[depthIndex] and quest.Objectives[depthIndex].Needed) or 0
    local collected = (quest.Objectives and quest.Objectives[depthIndex] and quest.Objectives[depthIndex].Collected) or 0
    local desc = (quest.Objectives and quest.Objectives[depthIndex] and quest.Objectives[depthIndex].Description) or ""

    local fakeObjective = {
        Id = quest.Id,
        IsSourceItem = true,
        QuestData = quest,
        Index = 1,
        Needed = needed,
        Collected = collected,
        text = nil,
        Description = desc,
    }

    QuestieTooltips:RegisterObjectiveTooltip(quest.Id, "i_" .. quest.SpellItemId, fakeObjective);
end


-- This checks and manually adds quest item tooltips for requiredSourceItems
local function _AddRequiredSourceItemObjective(quest)
    if not quest.requiredSourceItems then
        return
    end

    local questObjectives = QuestieDB.QueryQuestSingle(quest.Id, "objectives")
    local itemObjectives = questObjectives and questObjectives[3]

    local index, requiredSourceItemId = next(quest.requiredSourceItems or {})
    while index do
        local alreadyInObjectives = false

        if itemObjectives then
            local k1, itemObjectiveIndex = next(itemObjectives)
            while k1 do
                local k2, itemObjectiveId = next(itemObjectiveIndex or {})
                while k2 do
                    if itemObjectiveId == requiredSourceItemId or quest.sourceItemId == requiredSourceItemId then
                        Questie:Debug(Questie.DEBUG_INFO,
                            "[QuestieQuest:_AddRequiredSourceItemObjective] This item is already part of a quest objective.")
                        alreadyInObjectives = true
                        break
                    end
                    k2, itemObjectiveId = next(itemObjectiveIndex, k2)
                end
                if alreadyInObjectives then
                    break
                end
                k1, itemObjectiveIndex = next(itemObjectives, k1)
            end
        end

        if not alreadyInObjectives then
            local itemName = QuestieDB.QueryItemSingle(requiredSourceItemId, "name")
            if itemName then
                Questie:Debug(Questie.DEBUG_INFO,
                    "[QuestieQuest:_AddRequiredSourceItemObjective] Adding Source Item Id for:", requiredSourceItemId)

                local fakeObjective = {
                    Id = quest.Id,
                    IsRequiredSourceItem = true,
                    QuestData = quest,
                    Index = index,
                    text = itemName,
                    Description = itemName
                }

                QuestieTooltips:RegisterObjectiveTooltip(quest.Id, "i_" .. requiredSourceItemId, fakeObjective);
            end
        end
        index, requiredSourceItemId = next(quest.requiredSourceItems, index)
    end
end



function QuestieQuest:GetAllQuestIdsNoObjectives()
    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest] Getting all quests without objectives")
    QuestiePlayer.currentQuestlog = {}

    local questId, data = next(QuestLogCache.questLog_DO_NOT_MODIFY)
    while questId do
        local quest = QuestieDB.GetQuest(questId)

        if not quest then
            if not Questie._sessionWarnings[questId] then
                if not Questie.IsSoD then
                    Questie:Error(l10n(
                    "The quest %s is missing from Questie's database. Please report this on GitHub or Discord!",
                        tostring(questId)))
                end
                Questie._sessionWarnings[questId] = true
            end

            QuestiePlayer.currentQuestlog[questId] = questId
        else
            QuestiePlayer.currentQuestlog[questId] = quest
            quest.LocalizedName = data.title
            _AddSourceItemObjective(quest)
            _AddRequiredSourceItemObjective(quest)

            Questie:Debug(Questie.DEBUG_INFO, "[QuestieQuest] Adding the quest", questId,
                QuestiePlayer.currentQuestlog[questId])
        end
        questId, data = next(QuestLogCache.questLog_DO_NOT_MODIFY, questId)
    end
end

-- iterate all notes, update / remove as needed
---@param quest Quest
function QuestieQuest:UpdateObjectiveNotes(quest)
    -- DEBUG: Log currentQuestlog state
    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest] UpdateObjectiveNotes - questId:", quest.Id,
        " currentQuestlog present:", tostring(QuestiePlayer.currentQuestlog and QuestiePlayer.currentQuestlog[quest.Id] and "yes" or "no"))

    if (not QuestiePlayer.currentQuestlog) or (not QuestiePlayer.currentQuestlog[quest.Id]) then
        Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest] UpdateObjectiveNotes - EARLY RETURN: quest not in currentQuestlog, questId:", quest.Id)
        return
    end

    -- Fallback quests have no static DB data; their objectives are managed in PopulateQuestLogInfo
    if quest._isLogFallback then
        return
    end

    Questie:Debug(Questie.DEBUG_INFO, "[QuestieQuest] UpdateObjectiveNotes:", quest.Id)
    local objectiveIndex, objective = next(quest.Objectives or {})
    while objectiveIndex do
        -- Skip tracker-only fallback objectives — they have no DB Id and can't be populated
        if objective.Type ~= "fallback" then
            local result, err = xpcall(QuestieQuest.PopulateObjective, ERR_FUNCTION, QuestieQuest, quest, objectiveIndex,
                objective, false)
            if (not result) then
                Questie:Debug(Questie.DEBUG_ELEVATED, "[QuestieQuest] There was an error populating objectives for",
                    quest.name, quest.Id, objectiveIndex, err)
            end
        end
        objectiveIndex, objective = next(quest.Objectives, objectiveIndex)
    end

    if quest.SpecialObjectives and next(quest.SpecialObjectives) then
        local specKey, objective = next(quest.SpecialObjectives)
        while specKey do
            if objective.Type ~= "fallback" then
                local result, err = xpcall(QuestieQuest.PopulateObjective, ERR_FUNCTION, QuestieQuest, quest, 0, objective,
                    true)
                if not result then
                    Questie:Error("[QuestieQuest]: [SpecialObjectives] " ..
                    l10n("There was an error populating objectives for %s %s %s %s", quest.name or "No quest name",
                        quest.Id or "No quest id", 0 or "No objective", err or "No error"));
                end
            end
            specKey, objective = next(quest.SpecialObjectives, specKey)
        end
    end
end

-- This function is used to check the players bags for an item that matches quest.sourceItemId.
-- A good example for this edge case is [18] The Price of Shoes (118) where upon acceptance, Verner's Note (1283) is given
-- to the player and the Quest is immediately flagged as Complete. If the note is destroyed then a slightly modified version
-- of QuestieDB.IsComplete() that uses this function, returns zero allowing the quest updates to properly set the quests state.
---@param questId number @QuestID
---@param makeObjective boolean @If set to true, then this will create an incomplete objective for the missing quest item
---@return boolean @Returns true if quest.sourceItemId matches an item in a players bag
function QuestieQuest:CheckQuestSourceItem(questId, makeObjective)
    local quest = QuestieDB.GetQuest(questId)
    local sourceItem = true

    -- Ascension/custom quests may omit sourceItemId (nil). Normalize to 0.
    local sourceItemId = (quest and tonumber(quest.sourceItemId)) or 0

    if quest and sourceItemId > 0 then
        if GetItemCount(sourceItemId) > 0 then
            return true
        end

        sourceItem = false

        -- If we are missing the sourceItem for zero objective quests then make an objective for it so the
        -- player has a visual indication as to what item is missing and so the quest has a "tag" of some kind.
        -- Also double check the quests leaderboard and make sure an objective doesn't already exist.
        if (not sourceItem) and makeObjective and (not QuestieQuest:GetAllLeaderBoardDetails(quest.Id)[1]) then
            local itemName = QuestieDB.QueryItemSingle(sourceItemId, "name") or ("Item " .. tostring(sourceItemId))
            quest.Objectives = {
                [1] = {
                    Description = itemName,
                    Type = "item",
                    Needed = 1,
                    Collected = 0,
                    Completed = false,
                    Id = sourceItemId,
                    questId = quest.Id
                }
            }
        end
    else
        return true
    end

    return false
end

local function _GetIconScaleForAvailable()
    return Questie.db.profile.availableScale or 1.3
end

---@param quest Quest
function QuestieQuest:AddFinisher(quest)
    --We should never ever add the quest if IsQuestFlaggedComplete true.
    local questId = quest.Id
    Questie:Debug(Questie.DEBUG_INFO, "[QuestieQuest] Adding finisher for quest", questId)

    local complete = QuestieDB.IsComplete(questId)

    if (QuestiePlayer.currentQuestlog[questId] and (IsQuestFlaggedCompleted(questId) == false) and (complete == 1 or complete == 0) and (not Questie.db.char.complete[questId])) then
        local finisher, key

        if quest.Finisher ~= nil then
            if quest.Finisher.Type == "monster" then
                finisher = QuestieDB:GetNPC(quest.Finisher.Id)
                key = "m_" .. quest.Finisher.Id
            elseif quest.Finisher.Type == "object" then
                finisher = QuestieDB:GetObject(quest.Finisher.Id)
                key = "o_" .. quest.Finisher.Id
            else
                Questie:Debug(Questie.DEBUG_CRITICAL, "[QuestieQuest] Unhandled finisher type:", quest.Finisher.Type,
                    questId, quest.name)
            end
        else
            Questie:Debug(Questie.DEBUG_CRITICAL, "[QuestieQuest] Quest has no finisher:", questId, quest.name)
        end

        if finisher ~= nil then
            -- Certain race conditions can occur when the NPC/Objects are both the Quest Starter and Quest Finisher
            -- which can result in duplicate Quest Title tooltips appearing. DrawAvailableQuest() would have already
            -- registered this NPC/Object so, the appropriate tooltip lines are already present. This checks and clears
            -- any duplicate keys before registering the Quest Finisher.

            -- Clear duplicate keys if they exist
            if QuestieTooltips.lookupByKey[key] then
                local tooltip = QuestieTooltips:GetTooltip(key)
                if tooltip ~= nil and table.getn(tooltip) > 1 then
                    local ttline = 1
                    while ttline <= table.getn(tooltip) do
                        local index, line = next(tooltip)
                        while index do
                            if (ttline == index) then
                                Questie:Debug(Questie.DEBUG_DEVELOP,
                                    "[QuestieQuest] AddFinisher - Removing duplicate Quest Title!")

                                -- Remove duplicate Quest Title
                                QuestieTooltips.lookupByKey[key][tostring(questId) .. " " .. finisher.name] = nil

                                -- Now check to see if the dup has a Special Objective
                                local objText = string.match(line, ".*|cFFcbcbcb.*")

                                if objText then
                                    local objIndex

                                    -- Grab the Special Objective index
                                    if quest.SpecialObjectives[1] then
                                        objIndex = quest.SpecialObjectives[1].Index
                                    end

                                    if objIndex then
                                        Questie:Debug(Questie.DEBUG_DEVELOP,
                                            "[QuestieQuest] AddFinisher - Removing Special Objective!")

                                        -- Remove Special Objective Text
                                        QuestieTooltips.lookupByKey[key][tostring(questId) .. " " .. objIndex] = nil
                                    end
                                end
                            end
                            index, line = next(tooltip, index)
                        end
                        ttline = ttline + 1
                    end
                end
            end

            QuestieTooltips:RegisterQuestStartTooltip(questId, finisher.name, finisher.id, key)

            local finisherIcons = {}
            local finisherLocs = {}

            local finisherZone, spawns = next(finisher.spawns or {})
            while finisherZone do
                if (finisherZone ~= nil and spawns ~= nil) then
                    local _, coords = next(spawns)
                    while _ do
                        local data = {
                            Id = questId,
                            Icon = Questie.ICON_TYPE_COMPLETE,
                            GetIconScale = _GetIconScaleForAvailable,
                            IconScale = _GetIconScaleForAvailable(),
                            Type = "complete",
                            QuestData = quest,
                            Name = finisher.name,
                            IsObjectiveNote = false,
                        }

                        if QuestieDB.IsActiveEventQuest(quest.Id) then
                            data.Icon = Questie.ICON_TYPE_EVENTQUEST_COMPLETE
                        elseif QuestieDB.IsPvPQuest(quest.Id) then
                            data.Icon = Questie.ICON_TYPE_PVPQUEST_COMPLETE
                        elseif quest.IsRepeatable then
                            data.Icon = Questie.ICON_TYPE_REPEATABLE_COMPLETE
                        end

                        if (coords[1] == -1 or coords[2] == -1) then
                            local dungeonLocation = ZoneDB:GetDungeonLocation(finisherZone)
                            if dungeonLocation ~= nil then
                                local __, value = next(dungeonLocation)
                                while __ do
                                    local zone = value[1];
                                    local x = value[2];
                                    local y = value[3];

                                    QuestieMap:DrawWorldIcon(data, zone, x, y)
                                    __, value = next(dungeonLocation, __)
                                end
                            end
                        else
                            local x = coords[1];
                            local y = coords[2];

                            Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest] Adding world icon as finisher:",
                                finisherZone, x, y)
                            finisherIcons[finisherZone] = QuestieMap:DrawWorldIcon(data, finisherZone, x, y)

                            if not finisherLocs[finisherZone] then
                                finisherLocs[finisherZone] = { x, y }
                            end
                        end
                        _, coords = next(spawns, _)
                    end
                end
                finisherZone, spawns = next(finisher.spawns or {}, finisherZone)
            end

            if finisher.waypoints then
                local zone, waypoints = next(finisher.waypoints)
                while zone do
                    if (not ZoneDB.IsDungeonZone(zone)) then
                        if not finisherIcons[zone] and waypoints[1] and waypoints[1][1] and waypoints[1][1][1] then
                            local data = {
                                Id = questId,
                                Icon = Questie.ICON_TYPE_COMPLETE,
                                GetIconScale = _GetIconScaleForAvailable,
                                IconScale = _GetIconScaleForAvailable(),
                                Type = "complete",
                                QuestData = quest,
                                Name = finisher.name,
                                IsObjectiveNote = false,
                            }

                            if QuestieDB.IsActiveEventQuest(quest.Id) then
                                data.Icon = Questie.ICON_TYPE_EVENTQUEST_COMPLETE
                            elseif QuestieDB.IsPvPQuest(quest.Id) then
                                data.Icon = Questie.ICON_TYPE_PVPQUEST_COMPLETE
                            elseif quest.IsRepeatable then
                                data.Icon = Questie.ICON_TYPE_REPEATABLE_COMPLETE
                            end

                            finisherIcons[zone] = QuestieMap:DrawWorldIcon(data, zone, waypoints[1][1][1],
                                waypoints[1][1][2])
                            finisherLocs[zone] = { waypoints[1][1][1], waypoints[1][1][2] }
                        end

                        QuestieMap:DrawWaypoints(finisherIcons[zone], waypoints, zone)
                    end
                    zone, waypoints = next(finisher.waypoints, zone)
                end
            end
        else
            Questie:Debug(Questie.DEBUG_CRITICAL, "[QuestieQuest] finisher or finisher.spawns == nil for questId",
                questId)
        end
    end
end

---@param objective any
function QuestieQuest.ShouldHideObjective(objective)
    local hideCondition = objective.HideCondition
    if not hideCondition then
        return false
    end

    if hideCondition.hideIfQuestActive then
        local questId = hideCondition.hideIfQuestActive
        if QuestiePlayer.currentQuestlog[questId] or (Questie.db and Questie.db.char and Questie.db.char.complete and Questie.db.char.complete[questId]) then
            return true
        end
    end

    if hideCondition.hideIfQuestComplete then
        local questId = hideCondition.hideIfQuestComplete
        if Questie.db and Questie.db.char and Questie.db.char.complete and Questie.db.char.complete[questId] then
            return true
        end
    end

    return false
end

---@param quest Quest
---@param objectiveIndex ObjectiveIndex
---@param objective QuestObjective
---@param blockItemTooltips any
function QuestieQuest:PopulateObjective(quest, objectiveIndex, objective, blockItemTooltips) -- must be p-called
    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest:PopulateObjective] questId:", quest.Id,
        " objIdx:", objectiveIndex, " Desc:", objective.Description,
        " Completed:", tostring(objective.Completed),
        " quest.isComplete:", tostring(quest.isComplete))

    if (not objective.Update) then
        -- No Update function means static/pre-populated objective.
        -- Still check completion state so icons are removed if this objective was
        -- already marked complete from a previous update cycle.
        if objective.Completed or quest.isComplete then
            Questie:Debug(Questie.DEBUG_DEVELOP,
                "[QuestieQuest:PopulateObjective] - No Update fn but objective is complete, unloading icons.")
            _UnloadAlreadySpawnedIcons(objective)
        end
        return
    end

    objective:Update()

    -- Defensive: clear stale quest.isComplete if quest DB says the quest is NOT
    -- complete. The DB cache persists quest objects across acceptance cycles
    -- (complete → abandon → reaccept), and PopulateQuestLogInfo may not have
    -- run yet for this specific path (e.g., Learner invalidation).
    if quest.isComplete then
        local dbComplete = QuestieDB.IsComplete(quest.Id)
        if dbComplete ~= 1 then
            quest.isComplete = nil
            Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest:PopulateObjective] Cleared stale isComplete for quest:", quest.Id)
        end
    end

    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest:PopulateObjective] POST-Update questId:", quest.Id,
        " objIdx:", objectiveIndex, " Completed:", tostring(objective.Completed),
        " isComplete:", tostring(quest.isComplete), " HasUpdate:", tostring(objective.Update ~= nil))

    if QuestieQuest.ShouldHideObjective(objective) then
        Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest:PopulateObjective] HIDDEN by ShouldHideObjective, unloading icons for objIdx:", objectiveIndex)
        _UnloadAlreadySpawnedIcons(objective)
        return
    end

    local completed = objective.Completed
    local objectiveData = quest.ObjectiveData[objective.Index] or
    objective                                                               -- the reason for "or objective" is to handle "SpecialObjectives" aka non-listed objectives (demonic runestones for closing the portal)

    if (not objective.spawnList or (not next(objective.spawnList))) and _QuestieQuest.objectiveSpawnListCallTable[objectiveData.Type] then
        objective.spawnList = _QuestieQuest.objectiveSpawnListCallTable[objectiveData.Type](objective.Id, objective,
            objectiveData);
    end

    -- Tooltips should always show.
    -- For completed and uncompleted objectives
    _RegisterObjectiveTooltips(objective, quest.Id, blockItemTooltips)

    if completed or quest.isComplete then
        Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest:PopulateObjective] SKIPPING objective (completed):",
            objective.Description, "completed:", tostring(completed), "quest.isComplete:", tostring(quest.isComplete))
        _UnloadAlreadySpawnedIcons(objective)
        return
    end

    if (not objective.Color) then
        objective.Color = QuestieLib:ColorWheel()
    end

    if objective.spawnList and next(objective.spawnList) then
        Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest:PopulateObjective] spawnList present for quest:", quest.Id,
            "objIdx:", objectiveIndex, "spawnList entries:", (function() local n=0 for _ in pairs(objective.spawnList) do n=n+1 end return n end)())

        -- Clear stale AlreadySpawned entries before drawing. Frames may have been
        -- unloaded by UnloadQuestFrames but AlreadySpawned still references dead frames.
        _UnloadAlreadySpawnedIcons(objective)

        local maxPerType = 300

        if Questie.db.profile.enableIconLimit and Questie.db.profile.iconLimit < maxPerType then
            maxPerType = Questie.db.profile.iconLimit
        end

        local closestStarter = QuestieMap:FindClosestStarter()
        local objectiveCenter = closestStarter[quest.Id]

        local zoneCount = 0
        local zones = {}
        local objectiveZone

        local _id, spawnData = next(objective.spawnList)
        while _id do
            local zone, _ = next(spawnData.Spawns)
            while zone do
                zones[zone] = true
                zone, _ = next(spawnData.Spawns, zone)
            end
            _id, spawnData = next(objective.spawnList, _id)
        end

        local z, _ = next(zones)
        while z do
            objectiveZone = z
            zoneCount = zoneCount + 1
            z, _ = next(zones, z)
        end

        if zoneCount == 1 then -- this objective happens in 1 zone, clustering should be relative to that zone
            local x, y = HBD:GetWorldCoordinatesFromZone(0.5, 0.5, ZoneDB:GetUiMapIdByAreaId(objectiveZone))
            objectiveCenter = { x = x, y = y }
        end

        -- Filter static spawns if prioritizeMyData is enabled and we have high-confidence learned data
        if Questie.dbLearner and Questie.dbLearner.global and Questie.dbLearner.global.settings and Questie.dbLearner.global.settings.prioritizeMyData then
            local zone, _ = next(zones)
            while zone do
                local suppressed = (objectiveData.Type == "monster" and QuestieDB.GetSuppressedNPCs(zone)) or (objectiveData.Type == "object" and QuestieDB.GetSuppressedObjects(zone))
                if suppressed then
                    local id, spawnData = next(objective.spawnList)
                    while id do
                        if suppressed[id] and spawnData.Spawns and spawnData.Spawns[zone] then
                            -- Only suppress if this isn't a learned spawn (learned spawns have .isLearned)
                            if not spawnData.isLearned then
                                spawnData.Spawns[zone] = nil
                                if not next(spawnData.Spawns) then
                                    objective.spawnList[id] = nil
                                end
                            end
                        end
                        id, spawnData = next(objective.spawnList, id)
                    end
                end
                zone, _ = next(zones, zone)
            end
        end

        local iconsToDraw, _ = _DetermineIconsToDraw(quest, objective, objectiveIndex, objectiveCenter)
        local icon, iconPerZone = _DrawObjectiveIcons(quest.Id, iconsToDraw, objective, maxPerType)
        _DrawObjectiveWaypoints(objective, icon, iconPerZone)
    else
        Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest:PopulateObjective] NO spawnList for quest:", quest.Id,
            "objIdx:", objectiveIndex, "spawnList:", tostring(objective.spawnList))
    end
end

_RegisterObjectiveTooltips = function(objective, questId, blockItemTooltips)
    Questie:Debug(Questie.DEBUG_INFO, "Registering objective tooltips for", objective.Description)

    if objective.spawnList then
        if (not objective.hasRegisteredTooltips) then
            local id, spawnData = next(objective.spawnList)
            while id do
                if spawnData.TooltipKey and (not objective.AlreadySpawned[id]) then
                    QuestieTooltips:RegisterObjectiveTooltip(questId, spawnData.TooltipKey, objective)
                end
                id, spawnData = next(objective.spawnList, id)
            end

            objective.hasRegisteredTooltips = true
        end
    else
        -- No spawnList and no Id means there is nothing Questie can draw for this objective.
        -- This covers server-tracked trigger objectives (e.g. "complete N quests in zone" for
        -- quest 50150) which may have any objectiveType from the server, not just "event".
        if not objective.Id or objective.Id == 0 then
            objective.hasRegisteredTooltips = true
            return
        end
        Questie:Error("[QuestieQuest]: [Tooltips] " ..
        l10n("There was an error populating objectives for %s %s %s %s", objective.Description or "No objective text",
            questId or "No quest id", 0 or "No objective", "No error"))
    end

    if (not objective.registeredItemTooltips) and objective.Type == "item" and (not blockItemTooltips) and objective.Id then
        local itemName = QuestieDB.QueryItemSingle(objective.Id, "name")

        if itemName then
            QuestieTooltips:RegisterObjectiveTooltip(questId, "i_" .. objective.Id, objective)
        end

        objective.registeredItemTooltips = true
    end
end

_UnloadAlreadySpawnedIcons = function(objective)
    if objective.AlreadySpawned and next(objective.AlreadySpawned) then
        local id, spawn = next(objective.AlreadySpawned)
        while id do
            if spawn then
                local _, mapIcon = next(spawn.mapRefs)
                while _ do
                    mapIcon:Unload()
                    _, mapIcon = next(spawn.mapRefs, _)
                end
                local __, minimapIcon = next(spawn.minimapRefs)
                while __ do
                    minimapIcon:Unload()
                    __, minimapIcon = next(spawn.minimapRefs, __)
                end
                spawn.mapRefs = {}
                spawn.minimapRefs = {}
            end
            id, spawn = next(objective.AlreadySpawned, id)
        end
        objective.AlreadySpawned = {}
    end
end

---@param quest Quest
---@param objective QuestObjective
---@param objectiveIndex ObjectiveIndex
---@param objectiveCenter {x:X, y:Y}
_DetermineIconsToDraw = function(quest, objective, objectiveIndex, objectiveCenter)
    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest:_DetermineIconsToDraw] quest:", quest.Id,
        "objective:", objective.Description, "spawnList:", objective.spawnList and next(objective.spawnList) and "has entries" or "nil/empty",
        "AlreadySpawned:", objective.AlreadySpawned and next(objective.AlreadySpawned) and "has entries" or "empty",
        "Completed:", tostring(objective.Completed), "enableObjectives:", tostring(Questie.db.profile.enableObjectives))

    local iconsToDraw = {}
    local spawnItemId

    local id, spawnData = next(objective.spawnList)
    while id do
        if spawnData.ItemId then
            spawnItemId = spawnData.ItemId
        end

        if (not objective.Icon) and spawnData.Icon then
            objective.Icon = spawnData.Icon
        end

        if (not objective.AlreadySpawned[id]) and (not objective.Completed) and Questie.db.profile.enableObjectives then
            Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest:_DetermineIconsToDraw] CREATING icon entry for id:", id, "quest:", quest.Id)
            local data = {
                Id = quest.Id,
                ObjectiveIndex = objectiveIndex,
                QuestData = quest,
                ObjectiveData = objective,
                Icon = spawnData.Icon,
                IconColor = quest.Color,
                GetIconScale = spawnData.GetIconScale,
                IconScale = spawnData.GetIconScale(),
                Name = spawnData.Name,
                Type = objective.Type,
                ObjectiveTargetId = spawnData.Id
            }

            objective.AlreadySpawned[id] = {
                data = data,
                minimapRefs = {},
                mapRefs = {},
            }

            local zone, spawns = next(spawnData.Spawns)
            while zone do
                local uiMapId = ZoneDB:GetUiMapIdByAreaId(zone)
                local _, spawn = next(spawns)
                while _ do
                    if (spawn[1] and spawn[2]) then
                        local drawIcon = {
                            AlreadySpawnedId = id,
                            data = data,
                            zone = zone,
                            AreaID = zone,
                            UiMapID = uiMapId,
                            x = spawn[1],
                            y = spawn[2],
                            worldX = 0,
                            worldY = 0,
                            distance = 0,
                            touched = nil, -- TODO change. This is meant to let lua reserve memory for all keys needed for sure.
                        }
                        local x, y, _ = HBD:GetWorldCoordinatesFromZone(drawIcon.x / 100, drawIcon.y / 100, uiMapId)
                        x = x or 0
                        y = y or 0
                        -- Cache world coordinates for clustering calculations
                        drawIcon.worldX = x
                        drawIcon.worldY = y
                        -- There are instances when X and Y are not in the same map such as in dungeons etc, we default to 0 if it is not set
                        -- This will create a distance of 0 but it doesn't matter.
                        local distance = QuestieLib:Euclid(objectiveCenter.x or 0, objectiveCenter.y or 0, x, y);
                        drawIcon.distance = distance or 0 -- cache for clustering
                        -- there can be multiple icons at same distance at different directions
                        --local distance = floor(distance)
                        local iconList = iconsToDraw[distance]
                        if iconList then
                            table.insert(iconList, drawIcon)
                        else
                            iconsToDraw[distance] = { drawIcon }
                        end
                    end
                    _, spawn = next(spawns, _)
                end
                zone = next(spawnData.Spawns, zone)
            end
        end
        id, spawnData = next(objective.spawnList, id)
    end

    return iconsToDraw, spawnItemId
end

_DrawObjectiveIcons = function(questId, iconsToDraw, objective, maxPerType)
    local iconCount = 0
    local _, _ = next(iconsToDraw)
    if _ then
        local n = 0
        for _ in pairs(iconsToDraw) do n = n + 1 end
        Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest:_DrawObjectiveIcons] Drawing", n, "icon groups for quest:", questId)
    else
        Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest:_DrawObjectiveIcons] NO icons to draw for quest:", questId)
    end

    local spawnedIconCount = 0
    local icon
    local iconPerZone = {}

    local range = Questie.db.profile.clusterLevelHotzone

    local iconCount, orderedList = _GetIconsSortedByDistance(iconsToDraw)

    if orderedList[1] and orderedList[1].Icon == Questie.ICON_TYPE_OBJECT then -- new clustering / limit code should prevent problems, always show all object notes
        range = range * 0.2;                                                   -- Only use 20% of the default range.
    end

    local hotzones = QuestieMap.utils:CalcHotzones(orderedList, range, iconCount);

    for i = 1, table.getn(hotzones) do
        local hotzone = hotzones[i]
        if (spawnedIconCount > maxPerType) then
            Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest] Too many icons for quest:", questId)
            break;
        end

        --Any icondata will do because they are all the same
        icon = hotzone[1];

        local spawnsMapRefs = objective.AlreadySpawned[icon.AlreadySpawnedId].mapRefs
        local spawnsMinimapRefs = objective.AlreadySpawned[icon.AlreadySpawnedId].minimapRefs

        local centerX, centerY = QuestieMap.utils.CenterPoint(hotzone)

        local dungeonLocation = ZoneDB:GetDungeonLocation(icon.zone)

        if dungeonLocation and centerX == -1 and centerY == -1 then
            if dungeonLocation[2] then -- We have more than 1 instance entrance (e.g. Blackrock dungeons)
                local secondDungeonLocation = dungeonLocation[2]

                icon.zone = secondDungeonLocation[1]
                centerX = secondDungeonLocation[2]
                centerY = secondDungeonLocation[3]

                local iconMap, iconMini = QuestieMap:DrawWorldIcon(icon.data, icon.zone, centerX, centerY) -- clustering code takes care of duplicates as long as min-dist is more than 0

                if iconMap and iconMini then
                    iconPerZone[icon.zone] = { iconMap, centerX, centerY }
                    table.insert(spawnsMapRefs, iconMap)
                    table.insert(spawnsMinimapRefs, iconMini)
                end

                spawnedIconCount = spawnedIconCount + 1;
            end

            local firstDungeonLocation = dungeonLocation[1]
            icon.zone = firstDungeonLocation[1]
            centerX = firstDungeonLocation[2]
            centerY = firstDungeonLocation[3]
        end

        local iconMap, iconMini = QuestieMap:DrawWorldIcon(icon.data, icon.zone, centerX, centerY) -- clustering code takes care of duplicates as long as min-dist is more than 0

        if iconMap and iconMini then
            iconPerZone[icon.zone] = { iconMap, centerX, centerY }
            table.insert(spawnsMapRefs, iconMap)
            table.insert(spawnsMinimapRefs, iconMini)
        end

        spawnedIconCount = spawnedIconCount + 1;
    end

    return icon, iconPerZone
end

_GetIconsSortedByDistance = function(icons)
    local iconCount = 0;
    local orderedList = {}
    local distances = {}

    local i = 0

    local distKey, _ = next(icons)
    while distKey do
        i = i + 1
        distances[i] = distKey
        distKey, _ = next(icons, distKey)
    end

    table.sort(distances)

    -- use the keys to retrieve the values in the sorted order
    for distIndex = 1, table.getn(distances) do
        local iconsAtDisntace = icons[distances[distIndex]]

        for iconIndex = 1, table.getn(iconsAtDisntace) do
            local icon = iconsAtDisntace[iconIndex]

            iconCount = iconCount + 1
            orderedList[iconCount] = icon
        end
    end

    return iconCount, orderedList
end

_DrawObjectiveWaypoints = function(objective, icon, iconPerZone)
    local _, spawnData = next(objective.spawnList)
    while _ do -- spawnData.Name, spawnData.Spawns
        if spawnData.Waypoints then
            local zone, waypoints = next(spawnData.Waypoints)
            while zone do
                local firstWaypoint = waypoints[1][1]

                if (not iconPerZone[zone]) and icon and firstWaypoint[1] ~= -1 and firstWaypoint[2] ~= -1 then              -- spawn an icon in this zone for the mob
                    local iconMap, iconMini = QuestieMap:DrawWorldIcon(icon.data, zone, firstWaypoint[1],
                        firstWaypoint[2])                                                                                   -- clustering code takes care of duplicates as long as min-dist is more than 0

                    if iconMap and iconMini then
                        iconPerZone[zone] = { iconMap, firstWaypoint[1], firstWaypoint[2] }
                        tinsert(objective.AlreadySpawned[icon.AlreadySpawnedId].mapRefs, iconMap);
                        tinsert(objective.AlreadySpawned[icon.AlreadySpawnedId].minimapRefs, iconMini);
                    end
                end

                local ipz = iconPerZone[zone]

                if ipz then
                    QuestieMap:DrawWaypoints(ipz[1], waypoints, zone, spawnData.Hostile and { 1, 0.2, 0, 0.7 } or nil)
                end
                zone, waypoints = next(spawnData.Waypoints, zone)
            end

            Questie:Debug(Questie.DEBUG_INFO, "[QuestieQuest:_DrawObjectiveWaypoints]")
        end
        _, spawnData = next(objective.spawnList, _)
    end
end

---@param quest Quest
function QuestieQuest:PopulateObjectiveNotes(quest) -- this should be renamed to PopulateNotes as it also handles finishers now
    if (not quest) then
        return
    end

    local dbComplete = QuestieDB.IsComplete(quest.Id)

    -- DEBUG: Log PopulateObjectiveNotes state
    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest] PopulateObjectiveNotes - questId:", quest.Id,
        " quest.isComplete:", tostring(quest.isComplete),
        " dbComplete:", tostring(dbComplete),
        " Objectives count:", quest.Objectives and next(quest.Objectives) and "has entries" or "empty")

    -- Defensive: clear stale quest.isComplete flag if the quest log doesn't confirm
    -- completion. Without this, a re-accepted quest that was previously completed can
    -- have isComplete=true while the quest log shows it as incomplete.
    if quest.isComplete and dbComplete ~= 1 then
        Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest] PopulateObjectiveNotes - clearing stale isComplete for questId:", quest.Id)
        quest.isComplete = nil
    end

    if dbComplete == 1 then
        Questie:Debug(Questie.DEBUG_INFO, "[QuestieQuest:PopulateObjectiveNotes] Quest Complete! Adding Finisher for:",
            quest.Id)

        QuestieQuest:UpdateQuest(quest.Id)
        _AddSourceItemObjective(quest)
        _AddRequiredSourceItemObjective(quest)
        _AddSpellItemObjective(quest)

        return
    end

    if (not quest.Color) then
        quest.Color = QuestieLib:ColorWheel()
    end

    Questie:Debug(Questie.DEBUG_INFO, "[QuestieQuest:PopulateObjectiveNotes] Populating objectives for:", quest.Id)

    QuestieQuest:UpdateObjectiveNotes(quest)
    _AddSourceItemObjective(quest)
    _AddRequiredSourceItemObjective(quest)
    _AddSpellItemObjective(quest)
end

---@param quest Quest
---@return true?
function QuestieQuest:PopulateQuestLogInfo(quest)
    if (not quest) then
        return nil
    end

    Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest] PopulateQuestLogInfo - questId:", quest.Id,
        " Objectives:", quest.Objectives and next(quest.Objectives) and "has entries" or "empty",
        " isComplete:", tostring(quest.isComplete),
        " WasComplete:", tostring(quest.WasComplete))

    local questLogEngtry = QuestLogCache.GetQuest(quest.Id) -- DO NOT MODIFY THE RETURNED TABLE

    if (not questLogEngtry) then
        Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest] PopulateQuestLogInfo - CACHE MISS for questId:", quest.Id, "- returning early!")
        return
    end

    -- Sync quest.isComplete with quest log state. The cache in QuestieDB persists
    -- quest objects across acceptance cycles (complete → abandon → reaccept), so
    -- stale isComplete/WasComplete flags from a previous acceptance must be cleared
    -- when the quest log says the quest is no longer complete.
    if questLogEngtry.isComplete ~= nil and questLogEngtry.isComplete == 1 then
        quest.isComplete = true
    else
        quest.isComplete = nil
        -- Also clear WasComplete when quest log confirms the quest is NOT complete.
        -- Without this, the isComplete==0 branch in UpdateQuest sees stale
        -- WasComplete=true and triggers an unnecessary reset sequence.
        if quest.WasComplete then
            quest.WasComplete = nil
            Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest:PopulateQuestLogInfo] Cleared stale WasComplete for quest:", quest.Id)
        end
    end

    -- Live fallback quests (no static DB entry) manage their own Objectives.
    -- Their per-objective Update() functions read directly from QuestLogCache.
    if quest._isLogFallback then
        -- Seed objectives from QuestLogCache on first call
        if not next(quest.Objectives) then
            local cachedObjectives = QuestLogCache.GetQuestObjectives(quest.Id)
            if cachedObjectives then
                local index, obj = next(cachedObjectives)
                while index do
                    quest.Objectives[index] = {
                        questId     = quest.Id,
                        Index       = index,
                        Description = obj.text or "",
                        Type        = obj.type or "monster",
                        Collected   = obj.numFulfilled or 0,
                        Needed      = obj.numRequired or 0,
                        Completed   = obj.finished or false,
                        isUpdated   = false,
                        Update      = _QuestieQuest.ObjectiveUpdate,
                    }
                    index, obj = next(cachedObjectives, index)
                end
            end
        end
        local _, obj = next(quest.Objectives)
        while _ do
            obj.isUpdated = false
            obj:Update()
            _, obj = next(quest.Objectives, _)
        end
        return true
    end

    --Uses the category order to draw the quests and trusts the database order.

    local questObjectives = QuestieQuest:GetAllLeaderBoardDetails(quest.Id) or {} -- DO NOT MODIFY THE RETURNED TABLE


    local objectiveIndex, objective = next(questObjectives)
    while objectiveIndex do
        if objective.type and string.len(objective.type) > 1 then
            if (not quest.ObjectiveData) or (not quest.ObjectiveData[objectiveIndex]) or (not quest.ObjectiveData[objectiveIndex].Id) then
                Questie:Debug(Questie.DEBUG_DEVELOP, "[QuestieQuest] Missing objective data for quest", quest.Id, objective.text, "creating fallback objective")
                if not quest.Objectives[objectiveIndex] then
                    local fallbackSpawnList = {}
                    local objType = objective.type or "monster"

                    if objType == "monster" then
                        local l10n = QuestieLoader:ImportModule("l10n")
                        local zoneId = quest.zoneOrSort and quest.zoneOrSort > 0 and quest.zoneOrSort or nil
                        if zoneId and l10n and l10n.raresByZone and l10n.raresByZone[zoneId] then
                            local function _GetIconScaleForMonster()
                                return Questie.db.profile.monsterScale or 1
                            end
                            local _, npcId = next(l10n.raresByZone[zoneId])
                            while _ do
                                local npcName = QuestieDB.QueryNPCSingle(npcId, "name")
                                local npcSpawns = QuestieDB.QueryNPCSingle(npcId, "spawns")
                                if npcName and npcSpawns and npcSpawns[zoneId] then
                                    fallbackSpawnList[npcId] = {
                                        Id = npcId,
                                        Name = npcName,
                                        Spawns = { [zoneId] = npcSpawns[zoneId] },
                                        Waypoints = {},
                                        Hostile = true,
                                        Icon = Questie.ICON_TYPE_SLAY,
                                        GetIconScale = _GetIconScaleForMonster,
                                        IconScale = _GetIconScaleForMonster(),
                                        TooltipKey = "m_" .. npcId,
                                    }
                                end
                                _, npcId = next(l10n.raresByZone[zoneId], _)
                            end
                        end
                    end

                    quest.Objectives[objectiveIndex] = {
                        Id = 0, -- Dynamic fallback, no static DB ID known
                        Index = objectiveIndex,
                        questId = quest.Id,
                        _lastUpdate = 0,
                        Description = objective.text,
                        spawnList = fallbackSpawnList,
                        AlreadySpawned = {},
                        Update = _QuestieQuest.ObjectiveUpdate,
                        Type = objType,
                    }
                end
                quest.Objectives[objectiveIndex]:Update()
            else
                if not quest.Objectives[objectiveIndex] then
                    quest.Objectives[objectiveIndex] = {
                        Id = quest.ObjectiveData[objectiveIndex].Id,
                        Index = objectiveIndex,
                        questId = quest.Id,
                        _lastUpdate = 0,
                        Description = (objective.text and objective.text ~= "") and objective.text or (quest.ObjectiveData and quest.ObjectiveData[objectiveIndex] and quest.ObjectiveData[objectiveIndex].Text) or "",
                        spawnList = {},
                        AlreadySpawned = {},
                        Update = _QuestieQuest.ObjectiveUpdate,
                        Coordinates = quest.ObjectiveData[objectiveIndex].Coordinates, -- Only for type "event"
                        RequiredRepValue = quest.ObjectiveData[objectiveIndex].RequiredRepValue,
                        HideCondition = quest.ObjectiveData[objectiveIndex].HideCondition
                    }
                end

                quest.Objectives[objectiveIndex]:Update()
            end
        end

        if (not quest.Objectives[objectiveIndex]) or (not quest.Objectives[objectiveIndex].Id) then
            Questie:Debug(Questie.DEBUG_DEVELOP,
                "[QuestieQuest:PopulateQuestLogInfo] Error finding entry ID for objective", objectiveIndex,
                objective.type, objective.text, "of questId:", quest.Id)
        end
        objectiveIndex, objective = next(questObjectives, objectiveIndex)
    end

    -- find special unlisted objectives
    if next(quest.SpecialObjectives) then
        local index, specialObjective = next(quest.SpecialObjectives)
        while index do
            if (not specialObjective.Description) then
                specialObjective.Description = "Special objective"
            end

            specialObjective.questId = quest.Id

            if specialObjective.RealObjectiveIndex and quest.Objectives[specialObjective.RealObjectiveIndex] then
                -- This specialObjective is an extraObjective and has a RealObjectiveIndex set
                specialObjective.Completed = quest.Objectives[specialObjective.RealObjectiveIndex].Completed
                specialObjective.Update = function(self)
                    self.Completed = quest.Objectives[self.RealObjectiveIndex].Completed
                end
            elseif specialObjective.Type == "item" and specialObjective.Id then
                specialObjective.Completed = GetItemCount(specialObjective.Id) > 0
                specialObjective.Update = function(self)
                    self.Completed = GetItemCount(self.Id) > 0
                end
            else
                specialObjective.Update = NOP_FUNCTION
            end

            specialObjective.Index = 64 + index -- offset to not conflict with real objectives
            specialObjective.AlreadySpawned = specialObjective.AlreadySpawned or {}
            index, specialObjective = next(quest.SpecialObjectives, index)
        end
    end

    if table.getn(quest.Objectives) == 0 and table.getn(quest.SpecialObjectives) == 0 and (not quest.ObjectiveData or table.getn(quest.ObjectiveData) == 0) and ((quest.triggerEnd and table.getn(quest.triggerEnd) > 0) or (quest.Finisher and quest.Finisher.Id ~= nil)) then
        -- Some quests when picked up will be flagged isComplete == 0 but the quest.Objective table or quest.SpecialObjectives table is nil. This
        -- check assumes the Quest should have been flagged questLogEngtry.isComplete == 1. We're specifically looking for a quest.triggerEnd or
        -- a quest.Finisher.Id because this might throw an error if there is nothing to populate when we call QuestieQuest:AddFinisher().
        -- We added a check for quest.ObjectiveData to ensure we don't prematurely complete quests that are just waiting for the server to sync their objectives.
        QuestieMap:UnloadQuestFrames(quest.Id)
        QuestieQuest:AddFinisher(quest)
        quest.isComplete = true
    end

    return true
end

---@param self QuestObjective @quest.Objectives[] entry
function _QuestieQuest.ObjectiveUpdate(self)
    if self.isUpdated then
        return
    end

    local questObjectives = QuestieQuest:GetAllLeaderBoardDetails(self.questId) -- DO NOT MODIFY THE RETURNED TABLE

    if questObjectives and questObjectives[self.Index] then
        local obj = questObjectives[self.Index] -- DO NOT EDIT THE TABLE
        if (obj.type) then
            -- fixes for api bug
            local numFulfilled = obj.numFulfilled or 0
            local numRequired = obj.numRequired or 0
            local finished = obj.finished or false -- ensure its boolean false and not nil (hack)

            self.Type = obj.type;
            local quest = QuestieDB.GetQuest(self.questId)
            local fallbackText = quest and quest.ObjectiveData and quest.ObjectiveData[self.Index] and quest.ObjectiveData[self.Index].Text or ""
            self.Description = (obj.text and obj.text ~= "") and obj.text or fallbackText
            self.Collected = tonumber(numFulfilled);
            self.Needed = tonumber(numRequired);
            self.Completed = (self.Needed == self.Collected and self.Needed > 0) or
            (finished and (self.Needed == 0 or (not self.Needed)))                                                                         -- some objectives get removed on PLAYER_LOGIN because isComplete is set to true at random????
            -- Mark objective updated
            self.isUpdated = true
        end
    end
end

--- Lazily build an objective's spawnList from the spawn call table (includes
--- QuestieLearner-injected data). Used by QuestieArrow to resolve targets when
--- the spawnList hasn't been populated yet (e.g. after a quest re-accept cycle).
---@param objective table @An objective entry from quest.Objectives or quest.SpecialObjectives
---@param objectiveData table? @Corresponding ObjectiveData entry (falls back to the objective itself for SpecialObjectives)
---@return table|nil @The built spawnList, or nil if no handler matched
function QuestieQuest:BuildObjectiveSpawnList(objective, objectiveData)
    if not objective then return nil end
    -- Already populated — nothing to do
    if objective.spawnList and next(objective.spawnList) then
        return objective.spawnList
    end
    -- Try the explicit ObjectiveData first (normal objectives)
    if objectiveData and objectiveData.Type and _QuestieQuest.objectiveSpawnListCallTable[objectiveData.Type] then
        objective.spawnList = _QuestieQuest.objectiveSpawnListCallTable[objectiveData.Type](objective.Id, objective, objectiveData)
        return objective.spawnList
    end
    -- SpecialObjectives and fallback: use the objective's own Type
    if objective.Type and _QuestieQuest.objectiveSpawnListCallTable[objective.Type] then
        objective.spawnList = _QuestieQuest.objectiveSpawnListCallTable[objective.Type](objective.Id, objective, objective)
        return objective.spawnList
    end
    return nil
end

---@param questId number
---@return table<ObjectiveIndex, QuestLogCacheObjectiveData>|nil @DO NOT EDIT RETURNED TABLE
function QuestieQuest:GetAllLeaderBoardDetails(questId)
    Questie:Debug(Questie.DEBUG_INFO, "[QuestieQuest:GetAllLeaderBoardDetails] for questId", questId)

    local questObjectives = QuestLogCache.GetQuestObjectives(questId) -- DO NOT MODIFY THE RETURNED TABLE
    if (not questObjectives) then return end

    local _, objective = next(questObjectives)
    while _ do -- DO NOT MODIFY THE RETURNED TABLE
        -- TODO Move this to QuestEventHandler module or QuestieQuest:AcceptQuest( ) + QuestieQuest:UpdateQuest( ) (accept quest one required to register objectives without progress)
        -- TODO After ^^^ moving remove this function and use "QuestLogCache.GetQuest(questId).objectives -- DO NOT MODIFY THE RETURNED TABLE" in place of it.
        QuestieAnnounce:ObjectiveChanged(questId, objective.text, objective.numFulfilled, objective.numRequired)
        _, objective = next(questObjectives, _)
    end

    return questObjectives
end

function QuestieQuest.DrawDailyQuest(questId)
    if QuestieDB.IsDoable(questId) then
        local quest = QuestieDB.GetQuest(questId)
        AvailableQuests.DrawAvailableQuest(quest)
    end
end

return QuestieQuest
