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
        -- FIX: Added InCombatLockdown guard to prevent taining secure execution paths.
        -- This hook can be called during combat if the player interacts with the quest log
        -- while in combat, which may cause taint that propagates to protected functions.
        print("[DEBUG] QuestLogTitleButton_OnClick hook! button=" .. tostring(button) .. " isLeft=" .. tostring(button == "LeftButton") .. " shift=" .. tostring(IsShiftKeyDown()))
        if InCombatLockdown() then return end
        if (not self) or self.isHeader then
            return
        end

        local questLogLineIndex
        if Questie.IsWotlk or QuestieCompat.Is335 then
            -- With Wotlk the offset is no longer required cause the API already hands the correct index
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

        -- For all other clicks (including tracking/untracking), use the original function
        -- only call Questie's tracker if we actually want to fix this quest (normal quests already call AQW_insert)
        -- Only handle tracking on shift-click for "Talk to" quests (no objectives)
        print("[DEBUG] questLogLineIndex=", questLogLineIndex, "numLeaderBoards=", GetNumQuestLeaderBoards(questLogLineIndex), "shift=", IsShiftKeyDown(), "autoTrack=", Questie.db.profile.autoTrackQuests)
        if Questie.db.profile.trackerEnabled and GetNumQuestLeaderBoards(questLogLineIndex) == 0 and IsShiftKeyDown() then
            local _, _, _, isHeader, _, _, _, questId = GetQuestLogTitle(questLogLineIndex)
            print("[DEBUG] After GetQuestLogTitle - isHeader=", isHeader, "questId=", questId, "Tracked=", Questie.db.char.TrackedQuests[questId], "AutoUntracked=", Questie.db.char.AutoUntrackedQuests[questId])
            if questId and questId > 0 then
                if Questie.db.char.TrackedQuests[questId] or (Questie.db.profile.autoTrackQuests and (not Questie.db.char.AutoUntrackedQuests[questId])) then
                    -- Quest is currently tracked — hidden it
                    pcall(QuestieTracker.UntrackQuestId, QuestieTracker, questId)
                else
                    -- Quest is currently hidden — show it
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
