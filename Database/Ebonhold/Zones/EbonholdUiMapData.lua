if not Questie.IsEbonhold then return end
---@class EbonholdUiMapData
EbonholdUiMapData = EbonholdUiMapData or {}

EbonholdUiMapData.uiMapData = {
    -- Ebonhold custom dungeon maps
    -- Example from Ascension (Reference only for structure):
    -- [691] = {
    --     [1] = 375.0,
    --     [2] = 251.0,
    --     [3] = 189.0,
    --     [4] = 220.0,
    --     instance = 34,
    --     mapID = 691.1,
    --     name = "The Stockade",
    --     mapType = 3,
    --     parentMapID = 717,
    -- },
}

local function ApplyUiMapData()
    if not QuestieCompat then return end
    if not EbonholdUiMapData or not EbonholdUiMapData.uiMapData then return end

    QuestieCompat.UiMapData = QuestieCompat.UiMapData or {}

    for uiMapId, data in pairs(EbonholdUiMapData.uiMapData) do
        if QuestieCompat.UiMapData[uiMapId] == nil then
            QuestieCompat.UiMapData[uiMapId] = data
        end
    end
end

if QuestieCompat and QuestieCompat.LoadUiMapData then
    hooksecurefunc(QuestieCompat, "LoadUiMapData", ApplyUiMapData)
end
ApplyUiMapData()
