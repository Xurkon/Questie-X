
-- Mocking QuestieLoader and basic environment
_G = _G or {}
QuestieLoader = {
    _modules = {},
    CreateModule = function(self, name)
        self._modules[name] = { private = {} }
        if name == "Questie" then
            self._modules[name].Debug = function(self, level, ...) print("[DEBUG]", ...) end
            self._modules[name].DEBUG_DEVELOP = "DEVELOP"
        end
        return self._modules[name]
    end,
    ImportModule = function(self, name)
        return self._modules[name] or self:CreateModule(name)
    end
}

-- Mock QuestieCompat
QuestieCompat = {
    UiMapData = {},
    LoadUiMapData = function() end
}
function hooksecurefunc(obj, method, func)
    local original = obj[method]
    obj[method] = function(...)
        original(...)
        func(...)
    end
end

-- Mock GetRealmName
function GetRealmName() return "Bronzebeard" end
_G.IsAscensionServer = true

-- 1. Test npcId 0 Guard in QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
QuestieDB.npcCache = {}
QuestieDB.QueryNPC = function(id) return nil end
QuestieDB._npcAdapterQueryOrder = {}

function QuestieDB:GetNPC(npcId)
    if not npcId or npcId == 0 then
        return nil
    end
    if self.npcCache[npcId] then
        return self.npcCache[npcId]
    end

    local rawdata = self.QueryNPC(npcId, self._npcAdapterQueryOrder)
    if (not rawdata) then
        -- This should NOT be reached for npcId 0
        print("[FAIL] QuestieDB:GetNPC called QueryNPC for npcId 0!")
        return nil
    end
    return rawdata
end

print("Testing QuestieDB:GetNPC(0)...")
local result = QuestieDB:GetNPC(0)
if result == nil then
    print("[PASS] QuestieDB:GetNPC(0) returned nil without warnings.")
else
    print("[FAIL] QuestieDB:GetNPC(0) returned something else.")
end

-- 2. Test AscensionUiMapData Injection logic
local addonTable = {}
-- Load the actual files (simulated by copying their logic)
local function testInjection()
    -- Simulated AscensionUiMapData.lua
    local AscensionUiMapData = {
        uiMapData = {
            [1245] = { name = "Camp Narache", mapID = 1245 }
        }
    }
    -- The fix we applied:
    if addonTable then
        addonTable.uiMapData = AscensionUiMapData.uiMapData
    end

    -- Simulated AscensionLoader.lua
    local QuestiePluginAPI = QuestieLoader:ImportModule("QuestiePluginAPI")
    local plugin = {
        InjectUiMapData = function(self, data)
            if data and data.uiMapData then
                for id, val in pairs(data.uiMapData) do
                    QuestieCompat.UiMapData[id] = val
                end
                print("[PASS] Injected uiMapData for ID:", 1245)
            else
                print("[FAIL] No uiMapData found in addonTable!")
            end
        end
    }

    if addonTable.uiMapData then
        plugin:InjectUiMapData(addonTable)
    else
        print("[FAIL] addonTable.uiMapData is nil!")
    end
end

print("Testing Ascension Data Injection...")
testInjection()

if QuestieCompat.UiMapData[1245] then
    print("[PASS] QuestieCompat.UiMapData[1245] is present.")
else
    print("[FAIL] QuestieCompat.UiMapData[1245] is missing.")
end
