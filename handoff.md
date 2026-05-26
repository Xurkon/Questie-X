## Questie-X Learner Module — Pin Collapse Handoff

**Session**: 2025-05-25
**Repo**: `C:\Users\kance\Documents\GitHub\Questie-X`
**File**: `Modules/QuestieLearner.lua`

---

## Problem Statement

Killing multiple Mana Wyrms (npcId ~15274) on Sunstrider Isle (zoneId 3431) at distinct map coordinates still results in only **2 map pins** rendering instead of 3+ distinct pins. The collapse is caused by the coordinate **bucketing** logic in `_MergeSpawnEvidence` and `InsertIfNewBucket`.

---

## Two Identified Bucketing Layers

### Layer 1 — `_MergeSpawnEvidence` lines ~1046–1048
Groups all per-GUID evidence into buckets by rounding `(x, y)` to 2 decimal places:

```lua
local rx = floor(evidenceX * 100 + 0.5) / 100
local ry = floor(evidenceY * -100 + 0.5) / 100
local key = entry.zoneId .. "|" .. rx .. "|" .. ry
```

Each unique 2-decimal `(rx, ry)` becomes one evidence group. If two distinct kill locations fall within the same 0.01×0.01 square, they merge into one evidence group here — **before** `InsertIfNewBucket` is even called.

### Layer 2 — `InsertIfNewBucket` lines 205–221
For Sunstrider, uses `grid = 0.5`. Checks if any existing spawn in the zone falls in the same `floor(x/0.5)*0.5` bucket:

```lua
local bx, by = floor(x / grid) * grid, floor(y / grid) * grid
```

Two kills at x=50.54 and x=50.55 both land in bucket 50.5 → first is inserted, second is rejected as duplicate. This is the **documented intentional collapse** — but it's killing genuinely distinct spawn points that a 0.5 grid rounds to the same bucket.

---

## Fixes Already Applied

1. **`GetCoordGridForZone` hoisted outside evidence loop (line ~1114)**  
   Grid is now computed once before the Sunstrider promotion loop. Previously it was computed inside `InsertIfNewBucket` via `customGrid` parameter.

2. **`NormalizeCoordPair` comment (line 958–959)**  
   Updated to document that it handles native 0–1, already-scaled 0–100, and buggy 0–10000 input formats.

3. **`QUESTIE_LEARNER_debug` log comment (line 963–964)**  
   Noted it is commented out — re-enable for live debugging if needed.

---

## Recommended Next Step: Remove Bucketing Entirely

**The fix in this session did not resolve the 2-pin collapse.** The next agent should:

1. In `_MergeSpawnEvidence` (~line 1046–1048): **comment out or replace** the 2-decimal rounding entirely. Instead of grouping by `(zoneId|rx|ry)`, use the raw normalized coordinates directly. This makes every distinct kill location a separate evidence group.

2. In the Sunstrider promotion block (~lines 1111–1121): **bypass `InsertIfNewBucket`** entirely for Sunstrider. Instead of bucketing, insert the raw coordinates of every evidence group into `zoneSpawns` directly.

### Exact Changes to Make

**`_MergeSpawnEvidence` (~line 1045–1048) — REMOVE 2-decimal rounding:**

Replace:
```lua
-- Round to 2 decimal places for grouping
local rx = floor(evidenceX * 100 + 0.5) / 100
local ry = floor(evidenceY * 100 + 0.5) / 100
local key = entry.zoneId .. "|" .. rx .. "|" .. ry
```

With:
```lua
-- Use raw normalized coordinates as group key (no bucket collapse)
local rx = evidenceX
local ry = evidenceY
local key = entry.zoneId .. "|" .. rx .. "|" .. ry
```

**Sunstrider loop (~lines 1114–1121) — DIRECT INSERT (bypass `InsertIfNewBucket`):**

Replace:
```lua
local grid = GetCoordGridForZone(topEvidence.zoneId)
for _, spawnEvidence in pairs(evidence) do
    if InsertIfNewBucket(zoneSpawns, spawnEvidence.x, spawnEvidence.y, grid) then
        promoted = promoted + 1
    else
        duplicates = duplicates + 1
    end
end
```

With:
```lua
-- Directly insert every distinct evidence coordinate without bucketing
for _, spawnEvidence in pairs(evidence) do
    tinsert(zoneSpawns, { spawnEvidence.x, spawnEvidence.y })
    promoted = promoted + 1
end
duplicates = 0
```

**Rationale**: Bucketing was designed to reduce noise from GPS drift — but on Sunstrider with a 0.5 grid, it collapses spawn points that are legitimately different. Removing bucketing entirely ensures every distinct kill location gets its own pin.

---

## Key Code Locations

| Function | Lines | Purpose |
|---|---|---|
| `NormalizeCoordPair` | ~168–197 | Scales coords to 0–100; handles buggy inputs |
| `CoordBucket` | ~200–201 | Bucket key for (x, y) using COORD_GRID |
| `InsertIfNewBucket` | ~205–224 | Inserts coord only if no existing in same bucket |
| `GetCoordGridForZone` | ~108–113 | Returns 0.5 for Sunstrider (zones 1241/3431), else 2.0 |
| `_StoreGuidSpawnEvidence` | ~942–1012 | Stores per-GUID kill evidence; calls NormalizeCoordPair |
| `_MergeSpawnEvidence` | ~1014–1140 | Groups evidence → promotes top groups to npcDataOverrides |

---

## Debug Log

Re-enable this block (`_StoreGuidSpawnEvidence`, lines ~963–964) to verify normalized coordinates during gameplay:

```lua
Questie:Debug(Questie.DEBUG_LEARNER,
    "[QuestieLearner] _StoreGuidSpawnEvidence: spawnUID=", spawnUID,
    "zoneId=", zoneId, "nx=", nx, "ny=", ny)
```

Expected log output after `/reload`:
```
entry.x=58.68 entry.y=43.19  (not "5868,4319")
```

---

## Files Modified

- `Modules/QuestieLearner.lua` — lines 958–959, 1114 (already patched prior to this handoff)
- `Tests/QuestieLearner_spec.lua` — (unchanged; legacy reference)
