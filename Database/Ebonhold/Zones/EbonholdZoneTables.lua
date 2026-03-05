if not Questie.IsEbonhold then return end
---@class EbonholdZoneTables
EbonholdZoneTables = EbonholdZoneTables or {}

EbonholdZoneTables.uiMapIdToAreaId = EbonholdZoneTables.uiMapIdToAreaId or {
    -- Example mappings:
    -- [1238] = 12, -- Custom Northshire Valley Map -> Elwynn Forest AreaID
}

-- Register zone sort names for custom zones so they can be used in quest zoneOrSort field
EbonholdZoneTables.zoneSort = EbonholdZoneTables.zoneSort or {
    -- [1238] = "Northshire Valley",
}

-- Optional: custom dungeon registration (merged into ZoneDB by EbonholdLoader).
EbonholdZoneTables.dungeons = EbonholdZoneTables.dungeons or {}
EbonholdZoneTables.dungeonLocations = EbonholdZoneTables.dungeonLocations or {}
EbonholdZoneTables.dungeonParentZones = EbonholdZoneTables.dungeonParentZones or {}
