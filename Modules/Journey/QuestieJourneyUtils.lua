---@class QuestieJourneyUtils
local QuestieJourneyUtils = QuestieLoader:CreateModule("QuestieJourneyUtils")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

local AceGUI = LibStub("AceGUI-3.0");

function QuestieJourneyUtils:GetSortedZoneKeys(zones)
    local function compare(a, b)
        return zones[a] < zones[b]
    end

    local zoneNames = {}
    for k, _ in pairs(zones) do
        table.insert(zoneNames, k)
    end
    table.sort(zoneNames, compare)
    return zoneNames
end

function QuestieJourneyUtils:Spacer(container, size)
    local spacer = AceGUI:Create("Label");
    spacer:SetFullWidth(true);
    spacer:SetText(" ");
    if size and size == "large" then
        spacer:SetFontObject(GameFontHighlightLarge);
    elseif size and size == "small" then
        spacer:SetFontObject(GameFontHighlightSmall);
    else
        spacer:SetFontObject(GameFontHighlight);
    end
    container:AddChild(spacer);
end

function QuestieJourneyUtils:AddLine(frame, text)
    local label = AceGUI:Create("Label")
    label:SetFullWidth(true);
    label:SetText(text)
    label:SetFontObject(GameFontNormal)
    frame:AddChild(label)
end

function QuestieJourneyUtils:GetZoneName(id)
    local name = l10n:GetLocalNameByAreaId(id)

    -- Ascension can use custom UiMapIds for zones/sub-zones (e.g. 1238 Northshire Valley).
    -- Those won't exist in l10n.zoneLookup (which is AreaId-based), so fallback to UiMapData / mapInfo.
    if name == l10n("Unknown Zone") then
        local uiMapData = QuestieCompat and QuestieCompat.UiMapData and QuestieCompat.UiMapData[id]
        if uiMapData and uiMapData.name then
            name = uiMapData.name
        elseif QuestieCompat and QuestieCompat.C_Map and QuestieCompat.C_Map.GetMapInfo then
            local mapInfo = QuestieCompat.C_Map.GetMapInfo(id)
            if mapInfo and mapInfo.name then
                name = mapInfo.name
            end
        end
    end

    return name
end
