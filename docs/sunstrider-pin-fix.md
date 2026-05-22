# Sunstrider Isle Pin Fix — Questie-X on Ascension

## Architecture (Current)

On Ascension, Sunstrider Isle (uiMapId 1241) shares Eversong Woods' (1941)
coordinate space. The fix ensures correct cross-map pin visibility.

### Coordinate Flow
```
NPC spawn data: zone 3430 (Eversong) → GetUiMapIdByAreaId(3430) → uiMapId 1941
  → pin rendered on Eversong map (1941) with Eversong coordinates
  → ZONE_REDIRECT makes pin visible on Sunstrider (1241) too
  → _ResolveMapUiMapId redirects 1241→1941 for consistency
```

### Key Mappings
| Lookup | From | To | Purpose |
|--------|------|----|---------|
| `GetUiMapIdByAreaId(3430)` | areaId 3430 | uiMapId 1941 | Pin placement on Eversong map |
| `GetUiMapIdByAreaId(3431)` | areaId 3431 | uiMapId 1941 | Pin placement on Eversong map (Sunstrider subzone) |
| `GetAreaIdByUiMapId(1241)` | uiMapId 1241 | areaId 3431 | Zone ID for spawn data keys (Sunstrider subzone) |
| `_ResolveMapUiMapId(1241)` | uiMapId 1241 | uiMapId 1941 | Normalize pin rendering |
| `_ResolveArrowUiMapId(1241)` | uiMapId 1241 | uiMapId 1941 | Arrow math normalization |
| `ZONE_REDIRECT[1241]` | uiMapId 1241 | uiMapId 1941 | Cross-visibility |
| `ZONE_REDIRECT[946]` | uiMapId 946 | uiMapId 1941 | Cross-visibility (ghost map) |
| HBD bounds `mapData[1241]` | — | Eversong's bounds | Player position tracking on Sunstrider |

### Why zone 3430 → uiMapId 1941 (not 1241)

Zone 3430 = Eversong Woods (the whole zone, not just Sunstrider).
In the WotLKDB, NPC spawn coordinates under zone 3430 are Eversong-wide
percentages (e.g., NPC 15278 at 38.02%, 21.01%). These render correctly on
the Eversong map (1941). Mapping 3430→1241 would place Eversong-wide
coordinates on the Sunstrider sub-map, producing wrong positions.

Pins from zones 3430 and 3431 render on uiMapId 1941 (Eversong) and appear on uiMapId
1241 (Sunstrider) via ZONE_REDIRECT visibility, which works because
`ResolveZone(1241) == ResolveZone(1941) == 1941`.

---

## Files Modified

### Database/Zones/zoneDB.lua
- `areaIdToUiMapId[3430] = 1941` (was 1241)
- `uiMapIdToAreaIdCache[1241] = 3430` (unchanged — Sunstrider map IS in Eversong zone)
- `UiMapIdOverrides[1241] = 3430` (unchanged — reverse lookup)

### Modules/Map/QuestieMap.lua
- `_ResolveMapUiMapId(1241, x, y)` → redirects to 1941
- `_ResolveMapUiMapId(946, x, y)` → redirects to 1941
- Pins from zone 3430 naturally go to uiMapId 1941 (no redirect needed for them)

### Modules/Arrow/QuestieArrow.lua
- `_ResolveArrowUiMapId(1241)` → 1941
- `_ResolveArrowUiMapId(946)` → 1941
- Comment updated to match new approach
- **Arrow rendering**: Replaced sprite sheet (108-frame) with single-frame texture + `SetRotation(-angle)` for infinite angular resolution and zero jitter. Arrow texture is now X-PLORE's `XPArrow4.tga` (256×256 RGBA, arrow pointing UP centered at 128,128). Removed all `ARROW_SHEET_*`, `ARROW_CELL_*`, UV math, and `SetTexCoord` cell selection logic. Arrow uses `ARROW_DISPLAY_SIZE=96` for on-screen pixel size and `SetPoint("CENTER")` anchor for clean rotation pivot. `SetVertexColor(1,1,1)` preserves original blue color.

### Modules/QuestieLearner.lua
- `GetZoneId()`: Returns areaId via `ZoneDB:GetAreaIdByUiMapId(uiMapId)` with fallback
- `MIN_CONFIDENCE_PINS = 1` (was 2) — Ascension needs every data point
- `InjectLearnedData()`: Migration converts uiMapId spawn keys to areaId (1241→3430)
- All `LearnNPC` call sites now pass zoneId:
  - `OnMouseoverUnit`: passes areaId from `l10n:GetAreaIdByLocalName()`
  - `OnQuestDetail`: passes zoneId from `GetZoneId()`
  - `OnQuestComplete`: passes zoneId from `GetZoneId()`
  - `OnQuestAccepted`: passes `GetZoneId()`
  - `OnQuestTurnedIn`: passes `GetZoneId()`
  - `GOSSIP_SHOW` handler: passes `GetZoneId()`
  - Kill handler: passes `bestKill.zoneId` (already correct)

### Compat/HBD.lua
- `ASCENSION_ZONE_BOUNDS[1241]` = Eversong's calibrated bounds for player position tracking
- `ASCENSION_ZONE_BOUNDS[946]` = same
- `ZONE_REDIRECT[1241]=1941`, `ZONE_REDIRECT[946]=1941` (visibility)
- `ResolveZone()` for `isSameZoneSpace` checks

### Database/QuestieDB.lua
- `_MergeOverride(data, key, override)`: Fixed numeric-vs-string key mismatch
  - **Bug**: Override sources (wotlkNPCFixes, AscensionDB, QuestieLearner) could store spawn
    zone keys as either numbers (`3430`) or strings (`"3430"`). When `_MergeOverride` merged
    spawns into the base NPC data, a string key like `"3430"` would create a *new* table entry
    alongside the existing numeric `3430` key, producing duplicate spawn entries that rendered
    pins twice or confused zone lookups.
  - **Fix**: `_MergeOverride` now normalises all zone keys to numeric before merging. Any
    string-keyed spawn entry (e.g. `{["3430"] = {{0.38,0.21}}}`) is converted to its numeric
    equivalent (`{3430 = {{0.38,0.21}}}`) before the merge loop runs, so both formats resolve
    to the same table slot.
  - This fix is applied **once** inside `_MergeOverride` — no changes needed in individual
    override sources.

### Modules/QuestieLearner.lua (zone tracking additions)
- `OnQuestComplete`: Now captures `zoneId` via `GetZoneId()` and passes it as `spawnZoneId`
  to every `LearnNPC` call inside this handler.
- All `LearnNPC` call sites now pass `spawnZoneId` — the area ID of the zone the player
  was in when the event fired. Previously only some handlers included zone data; now every
  path supplies it, giving `npcDataOverrides` consistent spawn-zone keys for learned NPCs.

---

## NPC Data Format & Override Pipeline

### Override Sources
Three systems feed into `QuestieDB.npcDataOverrides`, each producing spawn data that
Questie merges at load time:

| Source | When it runs | Key format | Typical content |
|--------|-------------|------------|-----------------|
| `wotlkNPCFixes` (Database/NPCs) | Addon load | numeric | Corrections for vanilla→WotLK data changes |
| AscensionDB plugin | Addon load | numeric | Ascension-specific NPC additions & tweaks |
| QuestieLearner | Runtime events | **was string** (now numeric via `_MergeOverride`) | Player-observed NPC spawns |

### Numeric-vs-String Key Issue
Lua tables can have both `3430` (number) and `"3430"` (string) as separate keys.
The base NPC data in `QuestieDB.npcs` uses **numeric** zone keys exclusively.
If an override source stored spawns under `"3430"`, the merge would produce:

```lua
spawns = {
    [3430]  = {{0.38, 0.21}},   -- original
    ["3430"]= {{0.38, 0.21}},   -- duplicate from string key
}
```

This caused double pins and zone-lookup failures. The `_MergeOverride` fix normalises
all keys to numeric *before* merging, collapsing both entries into one.

### How _MergeOverride Resolves Both Formats
```lua
-- Inside _MergeOverride, before merging spawns (field index 7):
if override[7] then
    local normalised = {}
    for zoneKey, coords in pairs(override[7]) do
        normalised[tonumber(zoneKey) or zoneKey] = coords
    end
    override[7] = normalised
end
-- Then proceed with the standard deep-merge loop
```

This ensures every string key like `"3430"` is converted to `3430`, matching the
numeric keys in the base data. The fix is centralised — each override source can
store keys in whatever format is convenient.

### Adding Townsfolk Data to AscensionDB Plugin
To add a townsfolk (non-combat NPC) to the AscensionDB plugin's override data:

```lua
-- In AscensionDB/NPCs.lua (or equivalent), npcDataOverrides section:
npcDataOverrides[<npcId>] = {
    -- Field layout follows QuestieDB NPC format:
    -- [1] name, [2] minLevel, [3] maxLevel, [4] friendly (0=hostile, 1=friendly)
    -- [5] spawnByZone or nil, [6] waypoints or nil,
    -- [7] spawns keyed by areaId
    [7] = {
        [3430] = {          -- areaId for Eversong Woods (covers Sunstrider Isle)
            {0.38, 0.21},   -- {x%, y%} on the Eversong map
        },
    },
}
```

Key points:
- Use **numeric** areaId keys (`3430`, not `"3430"`). Even though `_MergeOverride`
  now handles both formats, numeric is canonical and avoids ambiguity.
- Spawn coordinates are percentages (0–1 range) relative to the Eversong Woods map
  (uiMapId 1941), **not** the Sunstrider sub-map.
- Townsfolk typically set field `[4] = 1` (friendly).
- areaId `3430` covers both Eversong Woods and Sunstrider Isle — no separate entry
  for the sub-zone is needed because `ZONE_REDIRECT` handles cross-visibility.

---

## Diagnostic /run Commands

Must be run **in-game** after Questie has fully loaded (5+ seconds after login).

### Check ZoneDB mappings
```lua
/run print("3430→uiMapId:", QuestieLoader:ImportModule("ZoneDB"):GetUiMapIdByAreaId(3430), "  1241→areaId:", QuestieLoader:ImportModule("ZoneDB"):GetAreaIdByUiMapId(1241))
```
Expected: `3430→uiMapId: 1941  1241→areaId: 3430`

### Check HBD ZONE_REDIRECT
```lua
/run local HBD=LibStub("HereBeDragonsQuestie-2.0"); print("ResolveZone(1241)=", HBD.ResolveZone and HBD.ResolveZone(1241) or "N/A", "ResolveZone(946)=", HBD.ResolveZone and HBD.ResolveZone(946) or "N/A")
```
Expected: `ResolveZone(1241)= 1941  ResolveZone(946)= 1941`

### Check known NPC spawns for Sunstrider zone (3430)
```lua
/run local ZoneDB=QuestieLoader:ImportModule("ZoneDB"); local ids={15271,15273,15274,15278,15279,15280,15281,15283,15284,15285,15287,15289,15291,15292,15294,15295,15297,15298,15301,15366,15367,15371,15372}; for _,id in ipairs(ids) do local n=QuestieDB:GetNPC(id); if n and n.spawns then for z,c in pairs(n.spawns) do if z==3430 or z=="3430" then for i,pt in ipairs(c) do print(id..":"..(n.name or "?").." zone="..z.." ["..i.."]="..string.format("%.2f,%.2f",pt[1],pt[2])) end end end end end
```

### Check QuestieLearner overrides for zone 3430
```lua
/run local ov=QuestieDB and QuestieDB.npcDataOverrides; if ov then for id,d in pairs(ov) do if d[7] then for z,c in pairs(d[7]) do if z==3430 or z=="3430" then for i,pt in ipairs(c) do print("override npc="..id.." zone="..z.." ["..i.."]="..string.format("%.2f,%.2f",pt[1],pt[2])) end end end end end else print("npcDataOverrides not loaded") end
```

### Check HBD bounds for map 1241
```lua
/run local HBD=LibStub("HereBeDragonsQuestie-2.0"); local d=HBD.mapData[1241]; if d then print("1241: left="..d.left.." right="..d.right.." top="..d.top.." bottom="..d.bottom.." parentMapID="..(d.parentMapID or "nil")) else print("No mapData for 1241") end
```

### Check learned data (after visiting Sunstrider)
```lua
/run local ld=Questie.dbLearner; if ld and ld.global and ld.global.npcs then local count=0; for id,d in pairs(ld.global.npcs) do if d[7] and (d[7][3430] or d[7]["3430"]) then count=count+1; print("learned npc="..id.." mc="..(d.mc or 0).." zone=3430") end end; if count==0 then print("No learned NPCs in zone 3430 yet") end else print("Learner data not available") end
```

### Verify pin rendering
```lua
/run local ZoneDB=QuestieLoader:ImportModule("ZoneDB"); local uiMapId=ZoneDB:GetUiMapIdByAreaId(3430); print("Zone 3430 → uiMapId "..tostring(uiMapId).." (expected 1941)"); local HBD=LibStub("HereBeDragonsQuestie-2.0"); local wx,wy=HBD:GetWorldCoordinatesFromZone(0.38,0.21,uiMapId); print("World coords for (38%,21%) on map "..uiMapId..": "..string.format("%.1f, %.1f",wx or 0,wy or 0))
```

### Verify MIN_CONFIDENCE_PINS
```lua
/run print("minConfidencePins:", Questie.dbLearner.global.settings.minConfidencePins or "default(1)")
```

### Reset all learned data (WARNING: deletes everything!)
```lua
/run Questie.dbLearner.global.npcs = {}; Questie.dbLearner.global.quests = {}; Questie.dbLearner.global.items = {}; Questie.dbLearner.global.objects = {}; ReloadUI()
```

---

## Testing Checklist
- [ ] Load addon on Ascension server
- [ ] Create a Blood Elf character on Sunstrider Isle
- [ ] Verify diagnostic: `GetUiMapIdByAreaId(3430)` returns 1941
- [ ] Verify quest giver pins appear on BOTH Sunstrider minimap AND Eversong world map
- [ ] Verify pins do NOT appear in mountains or off-map
- [ ] Verify arrow (distance/direction) points correctly to quest targets
- [ ] Kill 1 NPC on Sunstrider, check learned data shows zone=3430 (not 1241)
- [ ] After 1+ kill, verify learned pin auto-appears at correct position
- [ ] Verify Eversong Woods NPCs NOT on Sunstrider show correctly on Eversong map
- [ ] Check no regressions on other zones
- [ ] **Complete-abandon-reaccept cycle**: Complete a quest's objectives → abandon → re-accept → verify pins appear for fresh 0/X objectives
- [ ] **Arrow rendering**: Verify arrow shows a single blue arrow (not sprite sheet), smooth rotation with no visible frame transitions, correct direction toward quest objectives, and correct display size
- [ ] **Learner data in arrow**: Verify arrow targets point to QuestieLearner-injected NPC spawn locations correctly
- [ ] **QUEST_TURNED_IN auto-complete**: Verify quests that auto-complete on turn-in clean up state properly (no orphan pins)

## Complete-Abandon-Reaccept Pin Lifecycle Fix (Session 2026-05-17)

### Bug Chain

Four interacting bugs prevented map pins and GPS arrow from reappearing after
completing quest objectives, abandoning the quest, and re-accepting it:

1. **MarkQuestAsAbandoned `objectivesWereComplete` path** — called `CompleteQuest`
   without clearing `quest.Objectives`, `quest.WasComplete`, or `quest.isComplete`.
   Stale `Completed=true` + `isUpdated=true` flags caused `PopulateObjectiveNotes`
   to skip drawing pins on re-accept.

2. **CompleteQuest** — did not clear `quest.Objectives` (unlike `AbandonedQuest`
   which does). Now adds `quest.Objectives = {}` with type guard as defense-in-depth.

3. **QUEST_TURNED_IN dead code** — `questLog[questId] = {}` wiped state before the
   QUEST_TURNED_IN state check could read it, making auto-complete cleanup unreachable.
   Moved the check before the wipe.

4. **AcceptQuest reset** — added `SetObjectivesDirty(questId)` in the re-accept block
   to ensure `isUpdated` flags are reset even if stale objectives survive.

5. **Arrow spawnList gap** — `_CollectObjective` silently skipped objectives with
   nil/empty `spawnList`. After quest re-accept, `PopulateQuestLogInfo` creates
   objectives without `spawnList`; `PopulateObjectiveNotes` builds it later in the
   TaskQueue. Added `QuestieQuest:BuildObjectiveSpawnList(objective, objectiveData)`
   public API that lazily builds `spawnList` from `objectiveSpawnListCallTable` handlers.
   The arrow now calls this when `spawnList` is missing.

### Files Changed

- **QuestEventHandler.lua** (~line 443-461): MarkQuestAsAbandoned — clear stale
  objectives/flags + SetObjectivesDirty before CompleteQuest
- **QuestEventHandler.lua** (~line 233): QUEST_TURNED_IN — moved state check before
  questLog[questId] = {} wipe
- **QuestieQuest.lua** (~line 492): AcceptQuest reset — added SetObjectivesDirty(questId)
- **QuestieQuest.lua** (~line 583): CompleteQuest — added `quest.Objectives = {}`
- **QuestieQuest.lua** (~line 1996-2018): New `BuildObjectiveSpawnList` public API
- **QuestieArrow.lua** (~line 726-760): _CollectObjective — lazy spawnList building
  via `QuestieQuest:BuildObjectiveSpawnList()`
## UpdateQuest Pin Refresher Fallback (Session 2026-05-17)

### Problem
After reload or abandon-reaccept, incomplete quests sometimes have no objective pins
on the map even though they are in the quest log. This happens when:
1. `PopulateQuestLogInfo` hits a cache miss and leaves `quest.Objectives` empty.
2. `UnloadQuestFrames` removes map frames but `AlreadySpawned` is not cleared,
   so `_DetermineIconsToDraw` skips recreating icons on the next refresh.

### Fix
Added a robustness fallback in `QuestieQuest:UpdateQuest()` (incomplete branch):
- If `quest.Objectives` is empty → re-call `PopulateQuestLogInfo()`, then
  `PopulateObjectiveNotes()` if objectives were created.
- If objectives exist but `QuestieMap.questIdFrames[questId]` is nil → clear
  `objective.AlreadySpawned = {}` for all objectives, then re-call
  `PopulateObjectiveNotes()` to force icon recreation.

This ensures that ANY incomplete quest in the log gets its pins re-added on the
next periodic refresh (30s) or `QUEST_LOG_UPDATE` if they were lost.

### Files Changed
- **QuestieQuest.lua** (~line 833): Added `hasObjectives` / `hasFrames` fallback
  in the `isComplete == 0` branch of `UpdateQuest`.
