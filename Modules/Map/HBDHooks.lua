---@class HBDHooks
local HBDHooks = QuestieLoader:CreateModule("HBDHooks");
local _HBDHooks = {}

---@type QuestieMap
local QuestieMap = QuestieLoader:ImportModule("QuestieMap");

local HBDPins = QuestieCompat.HBDPins or LibStub("HereBeDragonsQuestie-Pins-2.0")


function HBDHooks:Init()
    --Override OnMapChanged from MapCanvasDataProviderMixin
    -- (https://www.townlong-yak.com/framexml/27101/Blizzard_MapCanvas/MapCanvas_DataProviderBase.lua#74)
    --This could in theory be skipped by instead using our own MapCanvasDataProviderMixin
    --The reason i don't is because i want the scaling to happen AFTER HBD has processed all the icons.
    if HBDPins.worldmapProvider and HBDPins.worldmapProvider.OnMapChanged then
        _HBDHooks.ORG_OnMapChanged = HBDPins.worldmapProvider.OnMapChanged;
        HBDPins.worldmapProvider.OnMapChanged = _HBDHooks.OnMapChanged
    end
end

function _HBDHooks:OnMapChanged()
    --Call original one : https://www.townlong-yak.com/framexml/27101/Blizzard_MapCanvas/MapCanvas_DataProviderBase.lua#74
    if _HBDHooks.ORG_OnMapChanged then
        _HBDHooks.ORG_OnMapChanged(HBDPins.worldmapProvider)
    end

    local mapScale = QuestieMap.GetScaleValue()
    local map = HBDPins.worldmapProvider:GetMap()
    if map and map.EnumeratePinsByTemplate then
        for pin in map:EnumeratePinsByTemplate("HereBeDragonsPinsTemplateQuestie") do
            QuestieMap.utils:RescaleIcon(pin.icon, mapScale)
        end
    end
end
