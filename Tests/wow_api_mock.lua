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
    dbLearner = {
        global = {
            npcs = {},
            quests = {},
            items = {},
            objects = {},
        }
    },
    Debug = function(self, level, ...)
        -- print("[" .. tostring(level) .. "]", ...)
    end,
    Print = function(self, ...)
        -- print(...)
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
        if name == "ZoneDB" then return _G.ZoneDB end
        if name == "l10n" then return _G.l10n end
        if name == "QuestieTooltips" then return _G.QuestieTooltips end
        return {}
    end,
    CreateModule = function(self, name)
        _G[name] = {}
        return _G[name]
    end
}

_G.QuestieDB = {
    npcDataOverrides = {},
    objectDataOverrides = {},
    questDataOverrides = {},
    itemDataOverrides = {},
    QueryNPCSingle = function() return nil end,
    GetQuest = function() return nil end,
}

_G.QuestieQuest = {}

_G.QuestieCompat = {
    GetCurrentPlayerPosition = function() return 1, 0.5, 0.5 end,
    GetQuestLogTitle = function(index)
        return "Test Quest", 1, nil, false, nil, nil, nil, 123
    end,
    C_Timer = {
        After = function(delay, fn) fn() end,
        NewTicker = function(delay, fn) return { Cancel = function() end } end,
    },
}

_G.QuestiePlayer = {
    GetPlayerLevel = function() return 70 end,
}

_G.QuestLogCache = {
    GetQuestID = function() return 123 end,
    GetQuest = function(_, questId)
        return nil
    end,
    GetQuestObjectives = function(self, questId)
        return _G._mock_questObjectives or {
            { text = "Slay 10 felboars", Icon = 136006, objectiveType = "slay" },
            { text = "Collect 5 herbs", Icon = 134217, objectiveType = "loot" },
        }
    end,
}

_G.ZoneDB = {
    GetAreaIdByUiMapId = function(self, uiMapId)
        -- Sunstrider Isle (1241) → Eversong Woods (3430)
        if uiMapId == 1241 then return 3430 end
        return nil
    end,
}

_G.l10n = {
    GetAreaId = function(self)
        return 3430
    end,
}

_G.QuestieTooltips = {
    RegisterObjectiveTooltip = function(self, questId, identifier, data)
        _G._lastRegisteredTooltip = { questId = questId, identifier = identifier, data = data }
    end,
}

_G.C_Map = {
    GetBestMapForUnit = function(unit)
        return _G._mock_uiMapId or 530
    end,
    GetPlayerMapPosition = function(uiMapId, unit)
        return 0.5, 0.5
    end,
}

-- string.trim is a WoW API extension
_G.string.trim = function(s)
    if s then return s:match("^%s*(.-)%s*$") or "" end
    return ""
end

_G.GetNumQuestLogEntries = function() return 1 end

_G.GetTime = function() return os.time() end
_G.time = os.time
_G.floor = math.floor
_G.UnitName = function(unit) return "TestUnit" end
_G.UnitLevel = function(unit) return 70 end
_G.UnitGUID = function(unit) return "Creature-0-1234-567-89-1000-0000000000" end
_G.GetRealZoneText = function() return "Shadowmoon Valley" end
_G.GetInstanceInfo = function() return "Shadowmoon Valley", nil, nil, nil, nil, nil, nil, 530 end
_G.CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end
_G.GetPlayerMapPosition = function(unit)
    return 0.5, 0.5
end

return _G
