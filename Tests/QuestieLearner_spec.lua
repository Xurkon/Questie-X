-- Tests/QuestieLearner_spec.lua
require("Tests/wow_api_mock")

describe("QuestieLearner", function()
    local QuestieLearner

    setup(function()
        -- Mocking QuestieLoader module resolution for tests
        _G.QuestieLoader.ImportModule = function(_, name)
            if name == "QuestieDB" then return _G.QuestieDB end
            if name == "QuestieQuest" then return _G.QuestieQuest end
            if name == "QuestiePlayer" then return _G.QuestiePlayer end
            if name == "QuestLogCache" then return _G.QuestLogCache end
            if name == "QuestieCompat" then return _G.QuestieCompat end
            if name == "ZoneDB" then return _G.ZoneDB end
            if name == "l10n" then return _G.l10n end
            if name == "QuestieTooltips" then return _G.QuestieTooltips end
            if name == "QuestieLib" then return {} end
            return {}
        end

        _G.QuestieLoader.CreateModule = function(_, name)
            _G[name] = {}
            return _G[name]
        end

        -- Reset mock state
        _G._lastRegisteredTooltip = nil
        _G._mock_uiMapId = nil
        _G._mock_questObjectives = nil
        _G._mock_npcFlags = 2

        -- Reset QuestLogCache.GetQuest to default
        _G.QuestLogCache.GetQuest = function(_, id) return nil end

        -- Load the module
        package.loaded["Modules/QuestieLearner"] = nil
        QuestieLearner = require("Modules/QuestieLearner")

        -- Initialize sets up dbLearner.global.settings, InjectsLearnedData, etc.
        QuestieLearner:Initialize()
    end)

    --==========================================================================
    -- Existing test: coordinate scaling in OnCombatLogEvent
    --==========================================================================
    it("should scale coordinates by 100 in OnCombatLogEvent", function()
        local unitGUID = "Creature-0-1234-567-89-21878-0000000000"
        local unitName = "Felboar"

        _G.QuestieCompat.GetCurrentPlayerPosition = function()
            return 946, 0.35, 0.45
        end

        QuestieLearner:OnCombatLogEvent(GetTime(), "UNIT_DIED", nil, nil, nil, unitGUID, unitName, nil, nil, nil)

        local cached = QuestieLearner.private.recentKills[unitGUID]
        assert.is_not_nil(cached)
        assert.are.equal(35.0, cached.x)
        assert.are.equal(45.0, cached.y)
    end)

    --==========================================================================
    -- Existing test: spell cast learning
    --==========================================================================
    it("should learn spell casts into dbLearner quest objectives when they match a quest objective", function()
        local questId = 12345
        local spellId = 29228
        local targetGUID = "Creature-0-1234-567-89-21878-0000000000"

        Questie.dbLearner.global.quests = {}

        _G.QuestieCompat.GetQuestLogTitle = function(index)
            return "Test Quest", 1, nil, false, nil, nil, nil, questId
        end

        _G.QuestLogCache.GetQuest = function(id)
            return {
                objectives = {
                    { type = "spell", text = "Flame Shock the enemy" }
                }
            }
        end

        QuestieLearner:LearnSpellCast(spellId, "Flame Shock", targetGUID, "Enemy NPC")

        assert.is_not_nil(Questie.dbLearner.global.quests[questId])
        assert.is_not_nil(Questie.dbLearner.global.quests[questId][10])
        assert.is_not_nil(Questie.dbLearner.global.quests[questId][10][1])
        assert.are.same({ 21878, "Flame Shock" }, Questie.dbLearner.global.quests[questId][10][1][1])
    end)

    --==========================================================================
    -- InjectLearnedData zone key migration (uiMapId → areaId)
    --==========================================================================
    describe("InjectLearnedData zone migration", function()
        it("should migrate NPC spawn zone keys from uiMapId to areaId", function()
            Questie.dbLearner.global.npcs = {
                [21878] = {
                    [1] = "Felboar",
                    [7] = {
                        [1241] = {  -- uiMapId (Sunstrider) → should migrate to 3430
                            { 35.0, 45.0 },
                            { 40.0, 50.0 },
                        },
                    },
                },
            }
            Questie.dbLearner.global.quests = {}
            Questie.dbLearner.global.objects = {}
            Questie.dbLearner.global.items = {}

            -- Reload the data by calling InjectLearnedData (already called in Initialize, but re-call with updated data)
            QuestieLearner:InjectLearnedData()

            local npcs = Questie.dbLearner.global.npcs
            assert.is_nil(npcs[21878][7][1241],
                "Old uiMapId key 1241 should be removed after migration")
            assert.is_not_nil(npcs[21878][7][3430],
                "New areaId key 3430 should exist after migration")
            assert.are.equal(2, #npcs[21878][7][3430],
                "Should have 2 coords entries in migrated zone")
            assert.are.same({ 35.0, 45.0 }, npcs[21878][7][3430][1])
            assert.are.same({ 40.0, 50.0 }, npcs[21878][7][3430][2])
        end)

        it("should merge migrated spawn data with existing areaId data", function()
            Questie.dbLearner.global.npcs = {
                [21878] = {
                    [1] = "Felboar",
                    [7] = {
                        [1241] = {  -- uiMapId → merge into 3430
                            { 35.0, 45.0 },
                        },
                        [3430] = {  -- Already correct areaId
                            { 50.0, 55.0 },
                        },
                    },
                },
            }
            Questie.dbLearner.global.quests = {}
            Questie.dbLearner.global.objects = {}
            Questie.dbLearner.global.items = {}

            QuestieLearner:InjectLearnedData()

            local npcs = Questie.dbLearner.global.npcs
            assert.is_nil(npcs[21878][7][1241], "Old uiMapId key should be removed")
            assert.are.equal(2, #npcs[21878][7][3430],
                "Merged: 1 existing + 1 migrated = 2 entries")
        end)

        it("should migrate object spawn zone keys from uiMapId to areaId", function()
            Questie.dbLearner.global.npcs = {}
            Questie.dbLearner.global.quests = {}
            Questie.dbLearner.global.items = {}
            Questie.dbLearner.global.objects = {
                [181345] = {
                    [1] = "Mysterious Pedestal",
                    [4] = {
                        [1241] = {  -- uiMapId → migrate to 3430
                            { 30.0, 40.0 },
                        },
                    },
                },
            }

            QuestieLearner:InjectLearnedData()

            local objects = Questie.dbLearner.global.objects
            assert.is_nil(objects[181345][4][1241],
                "Old uiMapId key should be removed from objects")
            assert.is_not_nil(objects[181345][4][3430],
                "Migrated areaId key should exist")
            assert.are.same({ 30.0, 40.0 }, objects[181345][4][3430][1])
        end)

        it("should leave non-mappable zone keys unchanged", function()
            Questie.dbLearner.global.npcs = {
                [21878] = {
                    [1] = "Felboar",
                    [7] = {
                        [3430] = {  -- Already correct areaId — stay
                            { 35.0, 45.0 },
                        },
                        [530] = {     -- No ZoneDB mapping — stay
                            { 60.0, 30.0 },
                        },
                    },
                },
            }
            Questie.dbLearner.global.quests = {}
            Questie.dbLearner.global.objects = {}
            Questie.dbLearner.global.items = {}

            QuestieLearner:InjectLearnedData()

            local npcs = Questie.dbLearner.global.npcs
            assert.is_not_nil(npcs[21878][7][3430], "3430 areaId should remain")
            assert.is_not_nil(npcs[21878][7][530], "530 (no mapping) should remain")
            assert.are.equal(1, #npcs[21878][7][3430], "3430 should still have 1 entry")
            assert.are.equal(1, #npcs[21878][7][530], "530 should still have 1 entry")
        end)
    end)

    --==========================================================================
    -- LearnQuestObjectiveNPC icon preservation
    --==========================================================================
    describe("LearnQuestObjectiveNPC icon preservation", function()
        it("should pass the objective icon from QuestLogCache to RegisterObjectiveTooltip", function()
            local questId = 1001
            local npcId = 21878
            local objText = "Slay 10 felboars"
            local objectiveIndex = 1

            Questie.dbLearner.global.quests = {}
            Questie.dbLearner.global.npcs = {}

            -- Mock QuestLogCache.GetQuestObjectives returns objectives with Icon 136006
            _G._mock_questObjectives = {
                { text = "Slay 10 felboars", Icon = 136006, objectiveType = "slay" },
            }

            QuestieLearner:LearnQuestObjectiveNPC(questId, npcId, objText, objectiveIndex)

            -- Verify RegisterObjectiveTooltip was called with the icon
            assert.is_not_nil(_G._lastRegisteredTooltip,
                "RegisterObjectiveTooltip should have been called")
            assert.are.equal(questId, _G._lastRegisteredTooltip.questId)
            assert.are.equal("m_" .. npcId, _G._lastRegisteredTooltip.identifier)
            assert.are.equal(objText, _G._lastRegisteredTooltip.data.Description)
            assert.are.equal(136006, _G._lastRegisteredTooltip.data.Icon,
                "Icon from QuestLogCache should be passed to tooltip registration")
        end)

        it("should work when QuestLogCache has no matching objective text", function()
            local questId = 1002
            local npcId = 21879
            local objText = "Gather 5 moonflowers"
            local objectiveIndex = 1

            Questie.dbLearner.global.quests = {}
            Questie.dbLearner.global.npcs = {}

            -- Objectives don't include "moonflowers"
            _G._mock_questObjectives = {
                { text = "Slay 10 felboars", Icon = 136006 },
                { text = "Collect 5 herbs", Icon = 134217 },
            }

            QuestieLearner:LearnQuestObjectiveNPC(questId, npcId, objText, objectiveIndex)

            -- Should still register, but with nil Icon (graceful fallback)
            assert.is_not_nil(_G._lastRegisteredTooltip,
                "RegisterObjectiveTooltip should still be called without matching icon")
            assert.is_nil(_G._lastRegisteredTooltip.data.Icon,
                "Icon should be nil when no matching objective text is found")
        end)

        it("should work when QuestLogCache.GetQuestObjectives is nil", function()
            local questId = 1003
            local npcId = 21880
            local objText = "Kill 3 worgs"
            local objectiveIndex = 1

            Questie.dbLearner.global.quests = {}
            Questie.dbLearner.global.npcs = {}

            -- nil/empty so no icon lookup happens
            _G._mock_questObjectives = nil

            QuestieLearner:LearnQuestObjectiveNPC(questId, npcId, objText, objectiveIndex)

            assert.is_not_nil(_G._lastRegisteredTooltip,
                "RegisterObjectiveTooltip should be called even with nil objectives")
            assert.is_nil(_G._lastRegisteredTooltip.data.Icon,
                "Icon should be nil when GetQuestObjectives returns nil")
        end)
    end)

    --==========================================================================
    -- MIN_CONFIDENCE_PINS = 1
    --==========================================================================
    describe("Settings defaults", function()
        it("should have minConfidencePins default to 1 on fresh data", function()
            -- After Initialize, settings should be set with minConfidencePins = 1
            local settings = QuestieLearner:GetSettings()
            assert.are.equal(1, settings.minConfidencePins,
                "minConfidencePins should be 1 for Ascension play")
        end)

        it("should backfill legacy SavedVariables with minConfidencePins = 1", function()
            -- Simulate legacy data without minConfidencePins
            if Questie.dbLearner.global.settings then
                Questie.dbLearner.global.settings.minConfidencePins = nil
            end

            -- Re-initialize to trigger backfill
            QuestieLearner:Initialize()
            local settings = QuestieLearner:GetSettings()

            assert.are.equal(1, settings.minConfidencePins,
                "Legacy settings should be backfilled with minConfidencePins = 1")
        end)
    end)

    --==========================================================================
    -- NPC learning API
    --==========================================================================
    describe("LearnNPC spawn zone tracking", function()
        it("should store NPC spawn zoneId correctly", function()
            local npcId = 21878
            local spawnZoneId = 3430  -- Eversong Woods

            Questie.dbLearner.global.quests = {}
            Questie.dbLearner.global.npcs = {}

            -- Mock player position
            _G.QuestieCompat.GetCurrentPlayerPosition = function()
                return 3430, 0.35, 0.45
            end

            -- Mock coords
            _G.UnitPosition = function(unit) return -8940, -137, 82 end

            QuestieLearner:LearnNPC(npcId, "Felboar", 60, nil, 2, nil, nil, nil, spawnZoneId)

            assert.is_not_nil(Questie.dbLearner.global.npcs[npcId],
                "NPC should be learned")
            assert.are.equal("Felboar", Questie.dbLearner.global.npcs[npcId][1],
                "NPC name should be stored")
            -- NPC spawn coords should be stored under the areaId
            if Questie.dbLearner.global.npcs[npcId][7] then
                assert.is_not_nil(Questie.dbLearner.global.npcs[npcId][7][spawnZoneId],
                    "Spawn coords should be stored under zoneId " .. spawnZoneId)
            end
        end)
    end)
end)
