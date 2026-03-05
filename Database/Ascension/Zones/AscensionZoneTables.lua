if not Questie.IsAscension then return end
---@class AscensionZoneTables
AscensionZoneTables = AscensionZoneTables or {}

AscensionZoneTables.uiMapIdToAreaId = AscensionZoneTables.uiMapIdToAreaId or {
	--Alliance
	[1238] = 12, -- Northshire Valley -> Elwynn Forest
	[2029] = 12, -- Secret Inquisitorial Dungeon -> Elwynn Forest
	[2028] = 12, -- Shadewell Spring -> Elwynn Forest
	[1226] = 12, -- Echo Ridge Mine -> Elwynn Forest
	[1222] = 12, -- Jasperlode mine -> Elwynn Forest
	[1239] = 1, -- Coldridge Valley -> Dun Morogh
	[1215] = 1, -- Coldridge Pass -> Dun Morogh
	[1216] = 1, -- The Grizzled Den -> Dun Morogh
	[1214] = 1, -- Gol'bolar Quarry -> Dun Morogh
	[1243] = 141, -- Shadowglen -> Teldrassil
	[1233] = 141, -- Shadowthread Cave -> Teldrassil
	[1232] = 141, -- Fel Rock -> Teldrassil
	[2031] = 141, -- Moonlit Ossuary -> Teldrassil
	[1230] = 141, -- Upper Ban'ethil Barrow Den -> Teldrassil
	[1231] = 141, -- Lower Ban'ethil Barrow Den -> Teldrassil
	--Horde
	[1244] = 14, -- Valley of Trials -> Durotar
	[1217] = 14, -- Burning Blade Coven -> Durotar
	[2030] = 14, -- Sinister Lair -> Durotar
	[1219] = 14, -- Skull Rock -> Durotar
	[1240] = 85, -- Deathknell -> Tirisfal Glades
	[1213] = 85, -- Night Web's Hollow -> Tirisfal Glades
	[1245] = 215, -- Camp Narache -> Mulgore
	[1225] = 215, -- The Venture Co. Mine -> Mulgore
	[1224] = 215, -- Palemane Rock -> Mulgore
	
}

-- Register zone sort names for custom zones so they can be used in quest zoneOrSort field
AscensionZoneTables.zoneSort = AscensionZoneTables.zoneSort or {
	[1238] = "Northshire Valley",
	[2029] = "Secret Inquisitorial Dungeon",
	[2028] = "Shadewell Spring",
	[1226] = "Echo Ridge Mine",
	[1222] = "Jasperlode Mine",
	[1239] = "Coldridge Valley",
	[1215] = "Coldridge Pass",
	[1243] = "Shadowglen",
	[1233] = "Shadowthread Cave",
	[1244] = "Valley of Trials",
	[1217] = "Burning Blade Coven",
	[2030] = "Sinister Lair",
	[1240] = "Deathknell",
	[1213] = "Night Web's Hollow",
	[1245] = "Camp Narache",
	[1232] = "Fel Rock",
	[2031] = "Moonlit Ossuary",
	[1230] = "Upper Ban'ethil Barrow Den",
	[1231] = "Lower Ban'ethil Barrow Den",
	[1225] = "The Venture Co. Mine",
	[1224] = "Palemane Rock",
	[1219] = "Skull Rock",
	[1216] = "The Grizzled Den",
	[1214] = "Gol'bolar Quarry",
}
