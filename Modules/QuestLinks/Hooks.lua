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
        -- NOTE: On WotLK/Era/Ascension, Blizzard's original function already handles
        -- shift-click quest linking. We removed the duplicate ChatEdit_InsertLink call
        -- that was causing "[Quest Name] [Quest Name]" duplicates.
        if (IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow()) then
            QuestLog_SetSelection(questLogLineIndex)
        end


    end)
end
