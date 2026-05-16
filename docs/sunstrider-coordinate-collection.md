# Sunstrider Isle Pin Fix — Coordinate Collection Guide

## Architecture

On Ascension, Sunstrider Isle (uiMapId 1241) shares Eversong Woods' (1941)
coordinate space — it's a child map within Eversong. Pins for zone 3430
(Eversong Woods) render on the Eversong map (uiMapId 1941) and appear on the
Sunstrider sub-map (1241) via ZONE_REDIRECT visibility in HBD.lua.

### Key mappings
- **areaId 3430** (Eversong Woods) → uiMapId 1941 (Eversong map)
- **uiMapId 1241** (Sunstrider Isle) → areaId 3430 → pins redirected to 1941 via `_ResolveMapUiMapId`
- **ZONE_REDIRECT**: 1241→1941, 946→1941 (cross-visibility)
- **HBD bounds**: mapData[1241] uses Eversong's calibrated bounds for player position tracking
- **QuestieLearner**: GetZoneId() returns areaId 3430; HighConfidity set to 1 kill

### Files modified
- `Database/Zones/zoneDB.lua` — areaIdToUiMapId[3430] = 1941 (was 1241)
- `Modules/Map/QuestieMap.lua` — _ResolveMapUiMapId redirects 1241→1941
- `Modules/Arrow/QuestieArrow.lua` — _ResolveArrowUiMapId redirects 1241/946→1941
- `Modules/QuestieLearner.lua` — GetZoneId() returns areaId via ZoneDB; InjectLearnedData migrates uiMapId keys; MIN_CONFIDENCE_PINS = 1
- `Compat/HBD.lua` — ZONE_REDIRECT[1241]=1941, ASCENSION_ZONE_BOUNDS for mapData[1241]

## Diagnostic /run Commands

These must be run **in-game** after Questie has fully loaded (wait 5+ seconds
after login). If output is empty, the DB may not be initialized yet.

### Check ZoneDB mappings
```lua
/run print("3430→uiMapId:", QuestieLoader:ImportModule("ZoneDB"):GetUiMapIdByAreaId(3430), "  1241→areaId:", QuestieLoader:ImportModule("ZoneDB"):GetAreaIdByUiMapId(1241))
```
Expected: `3430→uiMapId: 1941  1241→areaId: 3430`

### Check known NPC spawns for Sunstrider (zone 3430)
```lua
/run local ZoneDB=QuestieLoader:ImportModule("ZoneDB"); local ids={15271,15273,15274,15278,15279,15280,15281,15283,15284,15285,15287,15289,15291,15292,15294,15295,15297,15298,15301,15366,15367,15371,15372}; for _,id in ipairs(ids) do local n=QuestieDB:GetNPC(id); if n and n.spawns then for z,c in pairs(n.spawns) do if z==3430 or z=="3430" then for i,pt in ipairs(c) do print(id..":"..(n.name or "?").." zone="..z.." ["..i.."]="..string.format("%.2f,%.2f",pt[1],pt[2])) end end end end end
```

### Check QuestieLearner overrides for zone 3430
```lua
/run local ov=QuestieDB and QuestieDB.npcDataOverrides; if ov then for id,d in pairs(ov) do if d[7] then for z,c in pairs(d[7]) do if z==3430 or z=="3430" then for i,pt in ipairs(c) do print("override npc="..id.." zone="..z.." ["..i.."]="..string.format("%.2f,%.2f",pt[1],pt[2])) end end end end end else print("npcDataOverrides not loaded") end
```

### Check HBD ZONE_REDIRECT
```lua
/run local HBD=LibStub("HereBeDragonsQuestie-2.0"); print("ResolveZone(1241)=", HBD.ResolveZone and HBD.ResolveZone(1241) or "N/A", "ResolveZone(946)=", HBD.ResolveZone and HBD.ResolveZone(946) or "N/A")
```
Expected: `ResolveZone(1241)= 1941  ResolveZone(946)= 1941`

### Check HBD bounds for map 1241
```lua
/run local HBD=LibStub("HereBeDragonsQuestie-2.0"); local d=HBD.mapData[1241]; if d then print("1241 bounds: left="..d.left.." right="..d.right.." top="..d.top.." bottom="..d.bottom.." parentMapID="..(d.parentMapID or "nil")) else print("No mapData for 1241") end
```
Expected: `left=-2721.0066 right=-1120.9934 top=8433.9360 bottom=7367.2693 parentMapID=1941`

### Check LearnNPC zone tracking (run after killing a mob on Sunstrider)
```lua
/run local ld=Questie.dbLearner; if ld and ld.global and ld.global.npcs then local count=0; for id,d in pairs(ld.global.npcs) do if d[7] and (d[7][3430] or d[7]["3430"]) then count=count+1; print("learned npc="..id.." mc="..(d.mc or 0).." zone=3430") end end; if count==0 then print("No learned NPCs in zone 3430 yet") end else print("Learner data not available") end
```

### Verify pin rendering pipeline
```lua
/run local ZoneDB=QuestieLoader:ImportModule("ZoneDB"); local uiMapId=ZoneDB:GetUiMapIdByAreaId(3430); print("Zone 3430 → uiMapId "..tostring(uiMapId).." (expected 1941)"); local HBD=LibStub("HereBeDragonsQuestie-2.0"); local wx,wy=HBD:GetWorldCoordinatesFromZone(0.38,0.21,uiMapId); print("World coords for (38%,21%) on map "..uiMapId..": "..string.format("%.1f, %.1f",wx or 0,wy or 0))
```
Expected: uiMapId 1941, world coords around (-2156, 8209)

## Testing checklist
- [ ] Load addon on Ascension server
- [ ] Create a Blood Elf character on Sunstrider Isle
- [ ] Verify quest giver pins appear on both the Sunstrider minimap AND the Eversong world map
- [ ] Verify clicking a quest giver pin shows quest info
- [ ] Verify arrow (distance/direction) points correctly to quest targets
- [ ] After visiting/killing NPCs, verify QuestieLearner creates pin overrides (mc≥1)
- [ ] Verify pins do NOT appear in mountains or off-map
- [ ] Verify Eversong Woods (zone 1941) quest givers NOT on Sunstrider show correctly on Eversong map

## Adding Townsfolk / NPC Data

There are three ways to add NPC spawn data so that pins appear for
Sunstrider Isle NPCs. Choose the one that matches your data source.

### 1. AscensionDB plugin (numeric-key array)

The AscensionDB companion addon ships NPC data as a numeric-key array.
Each entry is keyed by NPC ID and uses numeric indices matching
`QuestieDB.npcKeys`. The spawns field is index **7** (see `npcKeys.spawns = 7`)
and is itself a dict keyed by **areaId**.

```lua
-- AscensionDB.npcData example for a Sunstrider NPC
A.npcData = {
    -- [npcId] = { [1]=name, [4]=minLevel, [5]=maxLevel, [6]=rank, [7]=spawns, ... }
    [15273] = {
        "Arcane Wraith",   -- [1] name
        nil, nil,           -- [2] minLevelHealth, [3] maxLevelHealth
        1, 2,               -- [4] minLevel, [5] maxLevel
        0,                  -- [6] rank
        {                   -- [7] spawns  ← keyed by areaId, NOT uiMapId
            [3430] = {      -- 3430 = Eversong Woods areaId
                {38.4, 21.6},
                {39.2, 20.8},
                {40.0, 22.4},
            },
        },
    },
}
```

This data is loaded by `QuestieDB:LoadAscensionNpcData()` which calls
`_Asc_MergeInto(QuestieDB.npcDataOverrides, data)` — it writes each NPC
entry directly into `npcDataOverrides[npcId]`.

### 2. WotLKDB / TBC corrections (string-key dict)

The built-in correction files (`wotlkNPCFixes.lua`, `tbcNPCFixes.lua`,
`classicNPCFixes.lua`) use the **named-key** format via the `npcKeys`
constants. This is the format you should use for patches submitted to
Questie-X itself.

```lua
-- In Database/Corrections/wotlkNPCFixes.lua or tbcNPCFixes.lua
local npcKeys = QuestieDB.npcKeys

return {
    -- [npcId] = { [npcKeys.field] = value, ... }
    [15273] = {
        [npcKeys.spawns] = {
            [3430] = {          -- areaId 3430 (Eversong Woods), NOT uiMapId 1241
                {38.4, 21.6},
                {39.2, 20.8},
                {40.0, 22.4},
            },
        },
    },
}
```

These corrections are merged into `QuestieDB.npcDataOverrides` by the
correction loader before overrides are applied.

### 3. QuestieLearner runtime (automatic)

QuestieLearner learns NPC positions automatically as you play. When you
kill or interact with an NPC on Sunstrider Isle, `LearnNPC` stores the
spawn under **areaId 3430** (the return value of `GetZoneId()`, which
uses `ZoneDB:GetAreaIdByUiMapId(1241) → 3430`). Learned data is written
to `Questie.dbLearner.global.npcs[npcId]` as a numeric-key array
(identical structure to AscensionDB) and injected into
`npcDataOverrides` once the confidence threshold (`mc >= MIN_CONFIDENCE_PINS`)
is met.

### CRITICAL RULE: spawns are keyed by areaId, NOT uiMapId

This bears repeating because it is the #1 source of Sunstrider bugs:

- **CORRECT**: `[3430] = { {38.4, 21.6}, ... }` — areaId for Eversong Woods
- **WRONG**:   `[1241] = { {38.4, 21.6}, ... }` — uiMapId for Sunstrider Isle

Questie's internal spawn tables use `areaId` as the key. The ZoneDB
redirect (`uiMapId 1241 → areaId 3430`) ensures that even when the
player is on the Sunstrider sub-map, the correct areaId is used. If you
accidentally key spawns by uiMapId (1241), they will never be found by
`GetNPC` and no pins will render.

### _MergeOverride fix (historical note)

Prior to the `_MergeOverride` helper (added as part of the Sunstrider
pin fix), the `GetNPC` function only checked **string-keyed** override
entries (`override["spawns"]`). AscensionDB and QuestieLearner store
overrides with **numeric keys** (`override[7]`), so their spawn data
was silently ignored. The `_MergeOverride` function now checks both
formats:

```lua
-- _MergeOverride checks both override formats:
--   1. override[stringKey]   (string-keyed, e.g. from wotlkNPCFixes)
--   2. override[intKey]      (numeric-keyed, e.g. from QuestieLearner / AscensionDB)
--   3. rawdata[intKey]        (fallback to compiled DB)
```

This means override data from **all three sources** is now visible to
`GetNPC` for the first time. If you are debugging and overrides seem
ignored, confirm `_MergeOverride` is being called (line 1923 in
QuestieDB.lua as of this writing).