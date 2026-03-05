if not Questie.IsEbonhold then return end
---@type table
local EbonholdDB = QuestieLoader:CreateModule("EbonholdDB")

EbonholdDB.itemData = EbonholdDB.itemData or {
    -- Ebonhold Custom Items would go here
    -- [ItemID] = {Name, ...}
}

EbonholdItemDB = EbonholdItemDB or {}
EbonholdItemDB.itemData = EbonholdDB.itemData
