-- Tests/wow_api_mock.lua
-- Minimal mock of World of Warcraft API for Busted unit tests

_G = _G or {}

-- Mock Globals
_G.Questie = {
    DEBUG_LEARNER = "LEARNER",
    DEBUG_DEVELOP = "DEVELOP",
    db = {
        global = {
            learnedData = {
                npcs = {},
                quests = {},
                items = {},
                objects = {},
                settings = {
                    learnQuests = true,
                    learnNPCs = true,
                    learnItems = true,
                    learnObjects = true,
                }
            }
        },
        profile = {
            learnedData = {
                settings = {
                    learnQuests = true,
                    learnNPCs = true,
                }
            }
        }
    },
    Debug = function(self, level, ...)
        -- print("[" .. tostring(level) .. "]", ...)
    end,
    Error = function(self, ...)
        -- print("[ERROR]", ...)
    end
}

_G.QuestieLoader = {
    ImportModule = function(self, name)
        if name == "QuestieDB" then return _G.QuestieDB end
        if name == "QuestieQuest" then return _G.QuestieQuest end
        if name == "QuestiePlayer" then return _G.QuestiePlayer end
        if name == "QuestLogCache" then return _G.QuestLogCache end
        if name == "QuestieLib" then return {} end
        if name == "QuestieCompat" then return _G.QuestieCompat end
        return {}
    end,
    CreateModule = function(self, name)
        _G[name] = {}
        return _G[name]
    end
}

_G.QuestieDB = {
    npcDataOverrides = {},
    QueryNPCSingle = function() return nil end,
    GetQuest = function() return nil end,
}

_G.QuestieCompat = {
    GetCurrentPlayerPosition = function() return 1, 0.5, 0.5 end,
}

_G.QuestiePlayer = {
    GetPlayerLevel = function() return 70 end,
}

_G.QuestLogCache = {
    GetQuestID = function() return 123 end,
}

-- WoW Functions
_G.GetTime = function() return os.time() end
_G.time = os.time
_G.floor = math.floor
_G.UnitName = function(unit) return "TestUnit" end
_G.UnitLevel = function(unit) return 70 end
_G.UnitGUID = function(unit) return "Creature-0-1234-567-89-1000-0000000000" end
_G.GetRealZoneText = function() return "Shadowmoon Valley" end
_G.GetInstanceInfo = function() return "Shadowmoon Valley", nil, nil, nil, nil, nil, nil, 530 end
_G.C_Timer = {
    After = function(duration, callback) callback() end,
}
_G.CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end

return _G
