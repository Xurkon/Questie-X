local WatchFrame_Update = QuestWatch_Update or WatchFrame_Update

---@class Hooks
local Hooks = QuestieLoader:CreateModule("Hooks")

---@type QuestieTracker
local QuestieTracker = QuestieLoader:ImportModule("QuestieTracker")
---@type QuestieLink
local QuestieLink = QuestieLoader:ImportModule("QuestieLink")

--- COMPATIBILITY ---
local GetQuestLogTitle = QuestieCompat.GetQuestLogTitle
local GetQuestIDFromLogIndex = QuestieCompat.GetQuestIDFromLogIndex

function Hooks:HookQuestLogTitle()
    Questie:Debug(Questie.DEBUG_DEVELOP, "[Hooks] Hooking Quest Log Title")

    hooksecurefunc("QuestLogTitleButton_OnClick", function(self, button)
        -- FIX: Added InCombatLockdown guard to prevent tainting secure execution paths.
        -- This hook can be called during combat if the player interacts with the quest log
        -- while in combat, which may cause taint that propagates to protected functions.
        if InCombatLockdown() then return end
        if (not self) or self.isHeader then
            return
        end

        local questLogLineIndex
        if Questie.IsWotlk or QuestieCompat.Is335 then
            questLogLineIndex = self:GetID()
        else
            questLogLineIndex = self:GetID() + FauxScrollFrame_GetOffset(QuestLogListScrollFrame)
        end

        -- Handle Shift+Click quest linking
        if (IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow()) then
            -- Follow Ascension's exact native pattern
            local questLink = GetQuestLink(questLogLineIndex)
            if questLink then
                ChatEdit_InsertLink(questLink)
            end
            QuestLog_SetSelection(questLogLineIndex)
            -- We can't return here to stop the execution of the original function in hooksecurefunc,
            -- but for chat links the original function usually just selects the quest anyway.
        end

        -- For shift-click tracking toggle, only handle if tracker is enabled
        if Questie.db.profile.trackerEnabled and IsShiftKeyDown() then
            local _, _, _, isHeader, _, _, _, questId = GetQuestLogTitle(questLogLineIndex)
            if questId and questId > 0 and not isHeader then
                -- Toggle tracking: if tracked, untrack; if untracked, track
                if Questie.db.char.TrackedQuests[questId] or (Questie.db.profile.autoTrackQuests and not Questie.db.char.AutoUntrackedQuests[questId]) then
                    -- Quest is currently tracked — untrack it
                    pcall(QuestieTracker.UntrackQuestId, QuestieTracker, questId)
                else
                    -- Quest is currently untracked — track it
                    pcall(QuestieTracker.AQW_Insert, QuestieTracker, questLogLineIndex, QUEST_WATCH_NO_EXPIRE)
                end
            end
            if WatchFrame_Update then
                WatchFrame_Update()
            end
            QuestLog_SetSelection(questLogLineIndex)
            QuestLog_Update()
        end
    end)
end
