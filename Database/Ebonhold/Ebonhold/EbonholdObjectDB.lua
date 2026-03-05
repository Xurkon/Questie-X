if not Questie.IsEbonhold then return end
---@type table
local EbonholdDB = QuestieLoader:CreateModule("EbonholdDB")

EbonholdDB.objectData = EbonholdDB.objectData or {
    -- Object 600600: Elemental Shrine (starts quest 50026)
    [600600] = {
        [1] = "Elemental Shrine",                -- Name
        [2] = nil,                               -- Type
        [3] = nil,                               -- Zones
        [4] = { [3703] = { { 54.29, 45.69 } } }, -- Spawns: Shattrath City
        [5] = 12,                                -- Faction
        [6] = nil,                               -- Unknown
    },
}

EbonholdObjectDB = EbonholdObjectDB or {}
EbonholdObjectDB.objectData = EbonholdDB.objectData
