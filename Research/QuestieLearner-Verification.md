# QuestieLearner — In-Game Verification Guide

This guide walks you through verifying every subsystem of QuestieLearner is working correctly after the v1.2.6 rewrite. Run each test in order and check expected outputs.

---

## Prerequisites

### Enable Develop Debug Output

In chat before starting any test:
```
/script Questie.db.profile.debugLevel = Questie.DEBUG_DEVELOP
```

Or enable **Develop** in Questie Options → Advanced → Debug Level.

> You do NOT need Critical enabled separately — Develop includes Critical-tier output.

### Verify Settings Are Enabled

If you upgraded from an older version, `learnedData` in your SavedVariables may be missing the newer settings keys (fixed in v1.2.7). Confirm all are `true` before testing:
```
/script local s=Questie.db.global.learnedData.settings; print("enabled:", tostring(s.enabled), "npcs:", tostring(s.learnNpcs), "quests:", tostring(s.learnQuests), "items:", tostring(s.learnItems), "objects:", tostring(s.learnObjects))
```

All five should print `true`. If any print `nil`, do a `/reload` — v1.2.7's `EnsureLearnedData` backfill will fix it on next load.

---

## Test 1 — Initialization

After `/reload`, look for this in chat:
```
[QuestieLearner] Events registered
[QuestieLearner] Initialized
```

If you also had previously learned data, you should see:
```
[QuestieLearner] Injected learned data: N NPCs, N quests, N items, N objects
```

**Failure:** If you see nothing, check that `QuestieLearner.lua` and `QuestieLearnerComms.lua` are in the TOC and loading without errors.

---

## Test 2 — Mouseover Filter (Quest Giver ONLY)

> **Note:** Since v1.2.6, debug output only prints when an NPC is seen for the **first time ever**. If the NPC already exists in `learnedData` from a previous session, mouseover is silent — this is correct behavior. Use the steps below to force a visible test.

### 2a — Find the NPC ID

Target the quest giver NPC and run:
```
/script local guid = UnitGUID("target"); local id = tonumber(select(6, strsplit("-", guid))); print("NPC ID:", id)
```

> **Note:** This only works for dash-format GUIDs (e.g. `Creature-0-...`). If the GUID is in hex format (`0xF110...`), use the hex decode method in the GUID Reference section below.

### 2b — Clear it from learned data, then hover

```
/script local id = <npcId>; Questie.db.global.learnedData.npcs[id] = nil; print("Cleared NPC", id)
```

Now move your cursor off and back onto the quest giver.

**Expected output:**
```
[QuestieLearner] New NPC learned: <id> <NpcName>
```

### 2c — Verify the npcFlags filter directly

While mousing over the quest giver:
```
/script print("Flags:", UnitNPCFlags and UnitNPCFlags("mouseover") or "nil")
```
Expected: a number with bit 1 set (e.g. `2`, `3`, `35` — any value where `math.floor(value/2) % 2 == 1`).

While mousing over a random mob:
```
/script print("Flags:", UnitNPCFlags and UnitNPCFlags("mouseover") or "nil")
```
Expected: `0` or a value without the questgiver bit — and **no** `[QuestieLearner]` line should appear.

### 2d — Random Mob (Should Be Ignored)

Mouseover any wolf, enemy soldier, or non-quest creature.

**Expected:** Nothing printed. No `[QuestieLearner]` line.

---

## Test 3 — Quest Accept

Pick up any quest from an NPC. Look for:
```
[QuestieLearner] New quest learned: <id> <QuestName>
[QuestieLearner] New NPC learned: <id> <GiverName>
```

> Only prints on the **first time** each quest/NPC is learned. Subsequent accepts of the same quest are silent (data is updated internally).

Verify data was stored:
```
/script local q=Questie.db.global.learnedData.quests; local n=0; for _ in pairs(q) do n=n+1 end; print("Learned quests:", n)
```

Inspect a specific quest (replace `<questId>` with the ID you just accepted):
```
/script local q=Questie.db.global.learnedData.quests[<questId>]; if q then print("name:", q[1], "level:", q[5], "reqLvl:", q[4], "zone:", q[8]) else print("NOT captured") end
```

If it says `NOT captured`, check your settings (Prerequisites section) — `learnQuests` being `nil` silently blocks all quest recording.

Check if the quest is already in a DB plugin (if so, learner skips it):
```
/script local q = QuestieDB:GetQuest(<questId>); if q then print("In DB:", q[1]) else print("NOT in DB - learner should capture it") end
```

---

## Test 4 — Quest Turn-In

Complete and turn in a quest. Look for:
```
[QuestieLearner] New NPC learned: <id> <FinisherName>
```

Verify both starter and finisher are recorded:
```
/script local q=Questie.db.global.learnedData.quests[<questId>]; if q then print("starters:", tostring(q[2]), "finishers:", tostring(q[3])) end
```

Expected: Both `q[2]` and `q[3]` should be tables, not nil.
- `q[2][1]` = list of NPC IDs that start the quest
- `q[3][1]` = list of NPC IDs that finish the quest

---

## Test 5 — Kill Coordinate Recording

### 5a — Quest Objective Kill (Should Record)

Have an active kill quest in your quest log (e.g., "Kill 10 Wolves"). Kill one of the objective mobs.

**Expected output:**
```
[QuestieLearner] Kill recorded: NPC <id> <MobName>
[QuestieLearner] New NPC learned: <id> <MobName>
```

> "New NPC learned" only appears the first time. Subsequent kills of the same NPC type are silent but still update coordinates.

Verify coordinates were stored:
```
/script local n=Questie.db.global.learnedData.npcs[<npcId>]; if n and n[7] then for z,c in pairs(n[7]) do print("zone "..z.." has "..#c.." coord cluster(s)") end else print("no coords") end
```

Kill the same mob type multiple times in the same area. The cluster count should NOT increase for every kill — only when you move to a meaningfully different location (>2% of zone width apart).

### 5b — Non-Quest Mob (Should Be Ignored)

Kill a mob that is NOT a quest objective and is NOT in QuestieDB.

**Expected output:** Nothing. `[QuestieLearner] Kill recorded` should NOT appear.

---

## Test 6 — Item Loot Recording

Loot a mob or chest that drops a quest item.

**Expected output (immediate):**
```
[QuestieLearner] New item learned: <id> <ItemName>
```

**Expected output (delayed ~1 second if item never seen before):**

Same line, but fires when `GET_ITEM_INFO_RECEIVED` resolves the async `GetItemInfo` call.

Verify:
```
/script local i=Questie.db.global.learnedData.items; local n=0; for _ in pairs(i) do n=n+1 end; print("Learned items:", n)
```

---

## Test 7 — Object Recording

Interact with a clickable game object (chest, crate, brazier, scroll, etc.).

> **Important:** Some objects that look like interactable objects (e.g. Objectives Board) are actually implemented as **Creature NPCs** by the server. These will be recorded as NPCs, not objects — this is correct behavior.

### 7a — Identify what type an object/NPC is

With the gossip/interaction window open, run:
```
/script local g=UnitGUID("npc"); if g then local p=string.upper(string.sub(g,3,6)); print("GUID:", g, "Prefix:", p, "IsGameObject:", tostring(p=="F140")) end
```

| Prefix | Type | Recorded as |
|---|---|---|
| `F140` | GameObject | Object (`learnedData.objects`) |
| `F130` | Creature | NPC (`learnedData.npcs`) |
| `F110` | Creature/Pet | NPC (`learnedData.npcs`) |
| `F131` | Vehicle | NPC (`learnedData.npcs`) |

### 7b — Decode a hex GUID to get the ID

```
/script local g=UnitGUID("npc"); if g then local p=string.upper(string.sub(g,3,6)); local id=math.mod(tonumber(string.sub(g,11,18),16),8388608); print("Prefix:", p, "ID:", tostring(id)) end
```

> `strsplit("-", guid)` does **not** work on hex-format GUIDs — it returns the full string as the first value and nil for everything else. Always use the hex decode method above for `0x...` GUIDs.

### 7c — Print all learned objects

```
/script for id, data in pairs(Questie.db.global.learnedData.objects) do print("Object ID:", id, "Name:", tostring(data[1]), "Zone:", tostring(data[5])) end
```

With coordinates:
```
/script for id, data in pairs(Questie.db.global.learnedData.objects) do print("Object:", id, data[1]); if data[4] then for z, coords in pairs(data[4]) do print("  zone "..z.." - "..#coords.." coord(s)") end end end
```

---

## Test 8 — Overall Stats Check

Run this anytime to see a full summary:
```
/script local QL=QuestieLoader:ImportModule("QuestieLearner"); local n,q,i,o=QL:GetStats(); print("NPCs:"..n.." Quests:"..q.." Items:"..i.." Objects:"..o)
```

Expected counts increase as you play. `Quests:0` after accepting quests = settings backfill issue (see Prerequisites).

---

## Test 9 — Export

```
/script local E=QuestieLoader:ImportModule("QuestieLearnerExport"); local s,stats=E:Export(); if stats then print("Export OK | total:", stats.total, "| len:", string.len(s)) else print("Export FAILED:", tostring(stats)) end
```

Expected: `Export OK | total: N | len: XXXX`

The export string starts with `QxLD:1!`. Copy it from the Database tab → Export box in Questie Options.

---

## Test 10 — Import (Round-Trip)

1. Export your data (Test 9).
2. Wipe learned data: `/script QuestieLoader:ImportModule("QuestieLearner"):ClearAllData()`
3. Open Questie Options → Database → paste the export string → click Import.

Expected in chat:
```
Import complete: merged N entries, skipped 0 (already known).
[QuestieLearner] Injected learned data: N NPCs, N quests, N items, N objects
```

Verify stats match original count (Test 8). Data takes effect immediately — no `/reload` required for override-based map pins.

---

## Test 11 — Plugin Panel Stats (WotLKDB)

Open **Questie Options → Database** tab → scroll to **Loaded Questie-X Plugins**.

Expected for WotLKDB:
```
[Questie-WotLKDB]   Quests: 9086   NPCs: XXXX   Objects: XXXX   Items: XXXX
```

If you see all zeros: `QuestieX_WotLKDB_Counts` is not set yet. This global is written by `LoadBaseDB()` inside an async coroutine — open the options panel a few seconds after login rather than immediately.

---

## Test 12 — Peer Sharing (Requires Two Clients)

On Client 1, learn a new NPC (walk up to a quest giver not previously recorded).

On Client 2, run:
```
/script print(type(Questie.db.global.learnedData.npcs[<npcId>]))
```

Expected: `table` (arrived via hidden `questiecomm` channel or AceComm guild broadcast).

> Both clients must be in the same guild OR on the same server. Allow up to 10 seconds for the token-bucket throttle.

---

## GUID Reference

WoW uses two GUID formats. The learner handles both automatically.

### Dash-format (modern)
```
Creature-0-3726-0-189-5638296-000001ABCD
```
Parse with: `strsplit("-", guid)` → 6th element = ID, 1st = unit type string

### Hex-format (legacy, common on private servers)
```
0xF110092A18000718
```
Parse with position extraction:
- Characters 3–6 = unit type prefix (`F110`, `F130`, `F140`, etc.)
- Characters 11–18 = low 32 bits → `math.mod(tonumber(low32hex, 16), 8388608)` = entity ID

**Do NOT use `strsplit("-", ...)` on hex GUIDs** — it will return nil for all fields after the first.

Quick decode command for any hex GUID:
```
/script local g="0xF110092A18000718"; local p=string.upper(string.sub(g,3,6)); local id=math.mod(tonumber(string.sub(g,11,18),16),8388608); print("Prefix:",p,"ID:",id)
```

---

## Quick Diagnostic — All At Once

```
/script local QL=QuestieLoader:ImportModule("QuestieLearner"); local n,q,i,o=QL:GetStats(); print("=== QuestieLearner Stats ==="); print("NPCs:"..n.."  Quests:"..q.."  Items:"..i.."  Objects:"..o); local s=Questie.db.global.learnedData.settings; print("enabled:", tostring(s.enabled), "| npcs:", tostring(s.learnNpcs), "| quests:", tostring(s.learnQuests), "| items:", tostring(s.learnItems), "| objects:", tostring(s.learnObjects))
```

---

## Common Issues

| Symptom | Cause | Fix |
|---|---|---|
| Nothing prints at all | Debug level not set to DEVELOP | `/script Questie.db.profile.debugLevel = Questie.DEBUG_DEVELOP` |
| `Quests:0` despite accepting quests | `learnQuests = nil` in old SavedVariables | `/reload` — v1.2.7 backfill sets it to `true` |
| Random mobs being recorded | Old QuestieLearner.lua still loaded | Confirm v1.2.6+ deployed, `/reload` |
| Kill coords not recording | NPC not in QuestieDB and not targeted/hovered | Target the mob before killing it |
| Object recorded as NPC | Server implements it as a Creature (`F110`/`F130`) | Correct behavior — check prefix to confirm |
| `strsplit` returns nil | GUID is hex format, not dash-separated | Use hex decode method (see GUID Reference) |
| `UnitGUID("target")` returns nil | GameObjects can't be traditionally targeted | Use `UnitGUID("npc")` during gossip interaction instead |
| Export returns nil | `learnedData` is empty | Run Tests 2–7 first to accumulate data |
| WotLKDB shows 0s in plugin panel | Options opened before async init completed | Wait a few seconds after login then reopen options |
| Item not recorded after loot | `GetItemInfo` async on first encounter | Wait 1–2 seconds for `GET_ITEM_INFO_RECEIVED` |
