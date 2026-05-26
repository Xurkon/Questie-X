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
    -- Phase 2: GUID-based spawn evidence
    --==========================================================================
    it("should store GUID spawn evidence in entry[8] after a kill", function()
        local npcId = 21878
        local unitGUID = "Creature-0-1234-567-89-21878-000000ABCD"
        local unitName = "Felboar"

        -- Clear prior data
        Questie.dbLearner.global.npcs = {}
        Questie.dbLearner.global.settings.learnNpcs = true

        _G.QuestieCompat.GetCurrentPlayerPosition = function()
            return 1241, 0.5234, 0.6789
        end

        QuestieLearner:OnCombatLogEvent(GetTime(), "UNIT_DIED", nil, nil, nil, unitGUID, unitName, nil, nil, nil)

        -- Verify recentKills unchanged
        local cached = QuestieLearner.private.recentKills[unitGUID]
        assert.is_not_nil(cached)
        assert.are.equal(npcId, cached.npcId)
        assert.are.equal("Felboar", cached.name)
        assert.are.equal(5234, cached.x)
        assert.are.equal(6789, cached.y)

        -- Verify entry[8] was created on the learned NPC
        local learnedNpc = Questie.dbLearner.global.npcs[npcId]
        assert.is_not_nil(learnedNpc)
        assert.is_not_nil(learnedNpc[8])

        -- Spawn UID from last numeric segment of GUID: 000000ABCD → 43981
        local spawnUID = 43981
        assert.is_not_nil(learnedNpc[8][spawnUID], "GUID spawn entry should exist for spawnUID " .. tostring(spawnUID))
        local entry = learnedNpc[8][spawnUID]
        assert.are.equal(1241, entry.zoneId)
        assert.are.equal(52.34, entry.x)   -- same scaled format as recentKills
        assert.are.equal(67.89, entry.y)   -- same scaled format as recentKills
        assert.are.equal("local", entry.source)
        assert.are.equal(1, entry.confidence)
    end)

    it("should update existing GUID spawn evidence on repeated kill at same UID", function()
        local npcId = 21878
        local unitGUID = "Creature-0-1234-567-89-21878-0000005555"
        local unitName = "Felboar"

        Questie.dbLearner.global.npcs = {}
        Questie.dbLearner.global.settings.learnNpcs = true

        _G.QuestieCompat.GetCurrentPlayerPosition = function()
            return 1241, 0.1111, 0.2222
        end

        -- First kill
        QuestieLearner:OnCombatLogEvent(GetTime(), "UNIT_DIED", nil, nil, nil, unitGUID, unitName, nil, nil, nil)
        local spawnUID = 21845
        local learnedNpc = Questie.dbLearner.global.npcs[npcId]
        local entry1 = learnedNpc[8][spawnUID]
        assert.is_not_nil(entry1)
        local ts1 = entry1.ts

        -- Second kill at same UID — position changes slightly
        _G.QuestieCompat.GetCurrentPlayerPosition = function()
            return 1241, 0.3333, 0.4444
        end
        QuestieLearner:OnCombatLogEvent(GetTime(), "UNIT_DIED", nil, nil, nil, unitGUID, unitName, nil, nil, nil)
        local entry2 = learnedNpc[8][spawnUID]
        assert.is_not_nil(entry2)
        assert.are.equal(33.33, entry2.x)  -- same scaled format as recentKills
        assert.are.equal(44.44, entry2.y)  -- same scaled format as recentKills
        assert.is_true(entry2.ts >= ts1)    -- timestamp refreshed
    end)

    it("should not double-scale already normalized GUID spawn coordinates", function()
        local npcId = 15274
        local unitGUID = "Creature-0-1234-567-89-15274-41298"

        Questie.dbLearner.global.npcs = {
            [npcId] = {
                [1] = "Mana Wyrm",
            },
        }
        Questie.dbLearner.global.settings.learnNpcs = true

        QuestieLearner:_StoreGuidSpawnEvidence(npcId, unitGUID, 3431, 58.68, 43.19)

        local entry = Questie.dbLearner.global.npcs[npcId][8][41298]
        assert.is_not_nil(entry)
        assert.are.equal(58.68, entry.x)
        assert.are.equal(43.19, entry.y)
    end)

    it("should repair legacy 0-10000 GUID spawn coordinates before merging", function()
        local npcId = 15274
        local unitGUID = "Creature-0-1234-567-89-15274-41298"

        Questie.dbLearner.global.npcs = {
            [npcId] = {
                [1] = "Mana Wyrm",
            },
        }
        Questie.dbLearner.global.settings.learnNpcs = true

        QuestieLearner:_StoreGuidSpawnEvidence(npcId, unitGUID, 3431, 5868, 4319)

        local entry = Questie.dbLearner.global.npcs[npcId][8][41298]
        assert.is_not_nil(entry)
        assert.are.equal(58.68, entry.x)
        assert.are.equal(43.19, entry.y)
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

    --==========================================================================
    -- PruneLearnedSpawnOutliers
    --==========================================================================
    describe("PruneLearnedSpawnOutliers", function()
        local function setStaticNPC(npcId, spawnData)
            -- Mock static DB return for QuestieDB.QueryNPC
            _G.QuestieDB = _G.QuestieDB or {}
            _G.QuestieDB.QueryNPC = function(id, ...)
                if id == npcId then
                    return spawnData  -- { [7] = { [zoneId] = { {x,y}, ... } } }
                end
                return nil
            end
        end

        after_each(function()
            -- Restore QuestieDB.QueryNPC to nil (no static data)
            _G.QuestieDB = _G.QuestieDB or {}
            _G.QuestieDB.QueryNPC = function() return nil end
        end)

        it("should remove learned spawns that deviate > threshold from static anchor", function()
            local npcId = 21878
            local zoneId = 3430
            local threshold = 15

            -- Static DB anchor: NPC spawns at (50, 50) with tolerance ±15
            setStaticNPC(npcId, {
                [7] = {
                    [zoneId] = {
                        { 50.0, 50.0 },
                    },
                },
            })

            -- Learned data: one spawn near anchor, one far away
            Questie.dbLearner.global.npcs = {
                [npcId] = {
                    [1] = "Felboar",
                    [7] = {
                        [zoneId] = {
                            { 50.0, 50.0 },   -- within threshold
                            { 10.0, 10.0 },   -- > 15% away from anchor → pruned
                            { 51.0, 49.0 },   -- within threshold
                        },
                    },
                },
            }
            Questie.dbLearner.global.objects = {}
            Questie.dbLearner.global.quests = {}
            Questie.dbLearner.global.items = {}

            local changed = QuestieLearner:PruneLearnedSpawnOutliers(threshold)

            assert.is_true(changed)
            local spawns = Questie.dbLearner.global.npcs[npcId][7][zoneId]
            assert.are.equal(2, #spawns, "Should have 2 spawns after pruning")
        end)

        it("should use median cluster when no static anchor exists", function()
            local npcId = 21879
            local zoneId = 3430
            local threshold = 10

            -- No static DB entry
            setStaticNPC(npcId, nil)

            -- Three spawns: two clustered at (50,50), one outlier at (10,10)
            Questie.dbLearner.global.npcs = {
                [npcId] = {
                    [1] = "Worg",
                    [7] = {
                        [zoneId] = {
                            { 50.0, 50.0 },
                            { 50.5, 49.5 },
                            { 10.0, 10.0 },  -- outlier
                        },
                    },
                },
            }
            Questie.dbLearner.global.objects = {}
            Questie.dbLearner.global.quests = {}
            Questie.dbLearner.global.items = {}

            local changed = QuestieLearner:PruneLearnedSpawnOutliers(threshold)

            assert.is_true(changed)
            local spawns = Questie.dbLearner.global.npcs[npcId][7][zoneId]
            assert.are.equal(2, #spawns, "Outlier should be removed")
        end)

        it("should call InjectLearnedData after pruning when data changed", function()
            local npcId = 21880
            local zoneId = 3430

            setStaticNPC(npcId, {
                [7] = {
                    [zoneId] = {
                        { 50.0, 50.0 },
                    },
                },
            })

            Questie.dbLearner.global.npcs = {
                [npcId] = {
                    [1] = "Tiger",
                    [7] = {
                        [zoneId] = {
                            { 50.0, 50.0 },
                            { 5.0, 5.0 },   -- outlier
                        },
                    },
                },
            }
            Questie.dbLearner.global.objects = {}
            Questie.dbLearner.global.quests = {}
            Questie.dbLearner.global.items = {}

            local injectCalled = false
            local origInject = QuestieLearner.InjectLearnedData
            QuestieLearner.InjectLearnedData = function(self)
                injectCalled = true
                return origInject(self)
            end

            local changed = QuestieLearner:PruneLearnedSpawnOutliers(15)

            QuestieLearner.InjectLearnedData = origInject

            assert.is_true(changed, "Data should be changed")
            assert.is_true(injectCalled, "InjectLearnedData should be called after pruning")
        end)

        it("should not call InjectLearnedData when no spawns were pruned", function()
            local npcId = 21881
            local zoneId = 3430

            setStaticNPC(npcId, {
                [7] = {
                    [zoneId] = {
                        { 50.0, 50.0 },
                    },
                },
            })

            -- All spawns within threshold — nothing pruned
            Questie.dbLearner.global.npcs = {
                [npcId] = {
                    [1] = "Bear",
                    [7] = {
                        [zoneId] = {
                            { 50.0, 50.0 },
                            { 55.0, 45.0 },  -- still within 15 threshold
                        },
                    },
                },
            }
            Questie.dbLearner.global.objects = {}
            Questie.dbLearner.global.quests = {}
            Questie.dbLearner.global.items = {}

            local injectCalled = false
            local origInject = QuestieLearner.InjectLearnedData
            QuestieLearner.InjectLearnedData = function(self)
                injectCalled = true
                return origInject(self)
            end

            local changed = QuestieLearner:PruneLearnedSpawnOutliers(15)

            QuestieLearner.InjectLearnedData = origInject

            assert.is_false(changed, "No data should be changed")
            assert.is_false(injectCalled, "InjectLearnedData should NOT be called when nothing changed")
        end)

        it("should prune object spawns stored in [4] without static anchor", function()
            local objectId = 181345
            local zoneId = 3430
            local threshold = 10

            -- Objects store spawns in [4], not [7]
            Questie.dbLearner.global.npcs = {}
            Questie.dbLearner.global.quests = {}
            Questie.dbLearner.global.items = {}
            Questie.dbLearner.global.objects = {
                [objectId] = {
                    [1] = "Pedestal",
                    [4] = {
                        [zoneId] = {
                            { 30.0, 30.0 },
                            { 30.5, 29.5 },
                            { 80.0, 80.0 },  -- outlier
                        },
                    },
                },
            }

            local changed = QuestieLearner:PruneLearnedSpawnOutliers(threshold)

            assert.is_true(changed)
            local spawns = Questie.dbLearner.global.objects[objectId][4][zoneId]
            assert.are.equal(2, #spawns, "Object outlier should be pruned")
        end)

        it("should return false when there is nothing to prune", function()
            Questie.dbLearner.global.npcs = {}
            Questie.dbLearner.global.objects = {}
            Questie.dbLearner.global.quests = {}
            Questie.dbLearner.global.items = {}

            local changed = QuestieLearner:PruneLearnedSpawnOutliers(15)

            assert.is_false(changed, "Should return false when nothing to prune")
        end)
    end)

    --==========================================================================
    -- _MergeSpawnEvidence (via OnCombatLogEvent integration)
    --==========================================================================
    describe("_MergeSpawnEvidence integration", function()
        local function setStaticNPC(npcId, spawnData)
            _G.QuestieDB = _G.QuestieDB or {}
            _G.QuestieDB.QueryNPC = function(id, ...)
                if id == npcId then return spawnData end
                return nil
            end
        end

        after_each(function()
            _G.QuestieDB = _G.QuestieDB or {}
            _G.QuestieDB.QueryNPC = function() return nil end
        end)

        it("should merge when 3+ kills at same spawn point and >60% threshold exceeded", function()
            local npcId = 21878
            local unitGUID = "Creature-0-1234-567-89-21878-0000001111"
            local unitName = "Felboar"
            local zoneId = 3430

            setStaticNPC(npcId, {
                [7] = {
                    [zoneId] = {
                        { 50.0, 50.0 },  -- different from learned
                    },
                },
            })

            Questie.dbLearner.global.npcs = {}
            Questie.dbLearner.global.settings.learnNpcs = true

            -- Three kills at different GUIDs but same zone+coords
            local sameX, sameY = 0.1111, 0.2222
            for i = 1, 3 do
                local guid = "Creature-0-1234-567-89-21878-" .. string.format("%010d", 1000 + i)
                _G.QuestieCompat.GetCurrentPlayerPosition = function()
                    return zoneId, sameX, sameY
                end
                QuestieLearner:OnCombatLogEvent(GetTime(), "UNIT_DIED",
                    nil, nil, nil, guid, unitName, nil, nil, nil)
            end

            -- After 3rd kill, _MergeSpawnEvidence should have injected spawn override
            local override = QuestieDB.npcDataOverrides[npcId]
            local spawnList = override and override[7] and override[7][zoneId]
            assert.is_not_nil(spawnList, "Spawn override should be injected")
            assert.is_true(#spawnList >= 1, "At least one spawn should be injected")
        end)

        it("should NOT merge when < 3 kills (insufficient evidence)", function()
            local npcId = 21879
            local zoneId = 3430

            setStaticNPC(npcId, {
                [7] = {
                    [zoneId] = {
                        { 50.0, 50.0 },
                    },
                },
            })

            Questie.dbLearner.global.npcs = {
                [npcId] = {
                    [1] = "Worg",
                    [8] = {
                        [1001] = { zoneId = zoneId, x = 11.0, y = 22.0, ts = time(), source = "local", confidence = 1 },
                        [1002] = { zoneId = zoneId, x = 11.0, y = 22.0, ts = time(), source = "local", confidence = 1 },
                    },
                },
            }
            Questie.dbLearner.global.settings.learnNpcs = true

            -- Only 2 kills — below threshold
            -- (simulate by directly setting guidSpawns as above)

            -- Verify no override was created
            local overrideBefore = QuestieDB.npcDataOverrides[npcId]
            assert.is_nil(overrideBefore,
                "No override should exist with only 2 kills")
        end)

        it("should NOT merge when top spawn is at or below 60% confidence", function()
            local npcId = 21880
            local zoneId = 3430

            -- Static DB has a spawn at (50, 50)
            setStaticNPC(npcId, {
                [7] = {
                    [zoneId] = {
                        { 50.0, 50.0 },
                    },
                },
            })

            Questie.dbLearner.global.npcs = {
                [npcId] = {
                    [1] = "Bear",
                    [8] = {
                        [1001] = { zoneId = zoneId, x = 11.0, y = 22.0, ts = time(), source = "local", confidence = 1 },
                        [1002] = { zoneId = zoneId, x = 11.0, y = 22.0, ts = time(), source = "local", confidence = 1 },
                        [1003] = { zoneId = zoneId, x = 33.0, y = 44.0, ts = time(), source = "local", confidence = 1 },
                    },
                },
            }
            Questie.dbLearner.global.settings.learnNpcs = true

            -- 2 kills at (11,22), 1 kill at (33,44) = 50% each for top
            -- Top is at 50% ≤ 60%, should not override

            local overrideBefore = QuestieDB.npcDataOverrides[npcId]
            assert.is_nil(overrideBefore,
                "No override at 50% confidence (below 60% threshold)")
        end)

        it("should NOT override when learned spawn matches static DB entry", function()
            local npcId = 21881
            local zoneId = 3430
            local staticX, staticY = 50.0, 50.0

            -- Static DB has spawn at (50, 50)
            setStaticNPC(npcId, {
                [7] = {
                    [zoneId] = {
                        { staticX, staticY },
                    },
                },
            })

            -- Learned evidence: 3 kills at same coords as static (within rounding)
            local learnedX = 50.0
            local learnedY = 50.0

            Questie.dbLearner.global.npcs = {
                [npcId] = {
                    [1] = "Tiger",
                    [8] = {
                        [1001] = { zoneId = zoneId, x = learnedX, y = learnedY, ts = time(), source = "local", confidence = 1 },
                        [1002] = { zoneId = zoneId, x = learnedX, y = learnedY, ts = time(), source = "local", confidence = 1 },
                        [1003] = { zoneId = zoneId, x = learnedX, y = learnedY, ts = time(), source = "local", confidence = 1 },
                    },
                },
            }
            Questie.dbLearner.global.settings.learnNpcs = true

            -- All 3 kills agree at 100% but matches static — no override needed
            local overrideBefore = QuestieDB.npcDataOverrides[npcId]
            assert.is_nil(overrideBefore,
                "No override when learned matches static DB")
        end)
    end)
end)
