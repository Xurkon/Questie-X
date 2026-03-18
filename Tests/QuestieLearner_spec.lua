-- Tests/QuestieLearner_spec.lua
require("Tests/wow_api_mock")

describe("QuestieLearner", function()
    local QuestieLearner

    setup(function()
        -- Mocking QuestieLoader for this test
        _G.QuestieLoader.ImportModule = function(_, name)
            if name == "QuestieDB" then return _G.QuestieDB end
            if name == "QuestieQuest" then return _G.QuestieQuest end
            if name == "QuestiePlayer" then return _G.QuestiePlayer end
            if name == "QuestLogCache" then return _G.QuestLogCache end
            if name == "QuestieCompat" then return _G.QuestieCompat end
            return {}
        end

        _G.QuestieLoader.CreateModule = function(_, name)
            _G[name] = {}
            return _G[name]
        end

        -- Load the module (this assumes busted is run from project root)
        package.loaded["Modules/QuestieLearner"] = nil
        QuestieLearner = require("Modules/QuestieLearner")
        
        -- Initialize
        QuestieLearner:Initialize()
    end)

    it("should scale coordinates by 100 in OnCombatLogEvent", function()
        -- Simulated combat log event info (npcId 21878)
        local unitGUID = "Creature-0-1234-567-89-21878-0000000000"
        local unitName = "Felboar"
        
        -- Mock the player position to return raw decimals 0.35, 0.45
        _G.QuestieCompat.GetCurrentPlayerPosition = function()
            return 946, 0.35, 0.45
        end
        
        -- Trigger event
        QuestieLearner:OnCombatLogEvent(GetTime(), "UNIT_DIED", false, unitGUID, unitName, 0, 0, unitGUID, unitName, 0, 0)
        
        -- The cache should store 35.0, 45.0
        local cached = QuestieLearner.private.recentKills[unitGUID]
        assert.is_not_nil(cached)
        assert.are.equal(35.0, cached.x)
        assert.are.equal(45.0, cached.y)
    end)

    it("should only learn spell casts that are quest objectives", function()
        -- Reset data
        Questie.db.global.learnedData.queries = {}
        
        -- Case 1: Matching objective
        local questId = 12345
        local spellId = 29228 -- Flame Shock
        
        _G.QuestieDB.GetQuest = function(_, id)
            return {
                Id = id,
                Objectives = {
                    { type = "spell", id = spellId }
                }
            }
        end
        
        _G.QuestLogCache.GetQuestID = function() return questId end
        
        QuestieLearner:LearnSpellCast(spellId, "Flame Shock", "Enemy NPC")
        
        -- Result: data should have a log for this quest/spell
        assert.is_not_nil(Questie.db.global.learnedData.quests[questId])
        assert.is_not_nil(Questie.db.global.learnedData.quests[questId][3]) -- spell node
        assert.are.equal(spellId, Questie.db.global.learnedData.quests[questId][3][1])
    end)
end)
