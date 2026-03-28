-- verify_indices.lua
-- Diagnostic script to verify Questie-X Index-Aware Objective Tracking

local function VerifyQuest(questId)
    -- Robust lookup handle
    local quest = QuestieDB:GetQuest(questId)
    if not quest then
        print("|cFFFF0000[Questie-X]|r Quest " .. tostring(questId) .. " not found in DB.")
        print("  - Check if QuestieDB:Initialize() has completed successfully.")
        return
    end

    print("|cFF00FF00[Questie-X]|r Verifying Quest: " .. (quest.name or "Unknown") .. " (" .. questId .. ")")

    if not quest.Objectives or #quest.Objectives == 0 then
        print("  - No objectives found.")
        return
    end

    for i, obj in ipairs(quest.Objectives) do
        local objDesc = obj.Description or "Objective " .. i
        local objIndex = obj.objIndex
        print("  - [" .. i .. "] " .. objDesc .. " -> objIndex: " .. (objIndex or "|cFFFF0000MISSING|r"))
        
        if obj.Type == "monster" or obj.Type == "npc" then
            print("    Type: Monster, ID: " .. (obj.Id or "nil"))
        elseif obj.Type == "item" then
            print("    Type: Item, ID: " .. (obj.Id or "nil"))
        elseif obj.Type == "object" then
            print("    Type: Object, ID: " .. (obj.Id or "nil"))
        end
    end
end

-- Run verification for some known quests with multi-kill objectives
-- Example quest IDs (replace with relevant ones from your current log)
local testQuests = {
    183, -- Example: "A New Threat" (usually has multiple kill objectives)
    84,  -- Example: "The Jasperlode Mine"
}

print("|cFFFFFF00[Questie-X] Diagnostic Start|r")
for _, qId in ipairs(testQuests) do
    VerifyQuest(qId)
end
print("|cFFFFFF00[Questie-X] Diagnostic Complete|r")
