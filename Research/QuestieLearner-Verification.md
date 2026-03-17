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
[QuestieLearner] Learned Quest: <id> <QuestName>
[QuestieLearner] Learned NPC: <id> <GiverName>    ← or "Learned Object" if quest giver is a chest/object
```

Verify data was stored:
```
/script local q=Questie.db.global.learnedData.quests; local n=0; for _ in pairs(q) do n=n+1 end; print("Learned quests:", n)
```

Inspect a specific quest (replace `<questId>` with the ID you just accepted):
```
/script local q=Questie.db.global.learnedData.quests[<questId>]; if q then print("name:", q[1], "level:", q[5], "reqLvl:", q[4], "zone:", q[8]) end
```

Expected: `name: <quest name>  level: <number>  zone: <mapId>`

---

## Test 4 — Quest Turn-In

Complete and turn in a quest. Look for:
```
[QuestieLearner] Learned Quest: <id> <QuestName>
[QuestieLearner] Learned NPC: <id> <FinisherName>
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
[QuestieLearner] UNIT_DIED: recording kill NPC <id> <MobName>
[QuestieLearner] Learned NPC: <id> <MobName>
```

Verify coordinates were stored:
```
/script local n=Questie.db.global.learnedData.npcs[<npcId>]; if n and n[7] then for z,c in pairs(n[7]) do print("zone "..z.." has "..#c.." coord clusters") end end
```

Kill the same mob type multiple times in the same area. The cluster count should NOT increase for every single kill — only when you move to a meaningfully different location (>2% of zone width away).

### 5b — Non-Quest Mob (Should Be Ignored)

Kill a mob that is NOT a quest objective and is NOT in QuestieDB.

**Expected output:** Nothing. `[QuestieLearner] UNIT_DIED` should NOT appear.

---

## Test 6 — Item Loot Recording

Loot a mob or chest that drops a **quest item** (purple/green bag icon in loot window, or any item that appears in the loot frame).

**Expected output (immediate, if item was already cached):**
```
[QuestieLearner] Learned Item: <id> <ItemName>
```

**Expected output (delayed by ~1 second if item was never seen before):**
```
[QuestieLearner] Learned Item: <id> <ItemName>
```

This fires when `GET_ITEM_INFO_RECEIVED` resolves the async `GetItemInfo` call.

Verify:
```
/script local i=Questie.db.global.learnedData.items; local n=0; for _ in pairs(i) do n=n+1 end; print("Learned items:", n)
```

---

## Test 7 — Object Recording

Interact with a **clickable quest object** (a chest, a crate, a brazier, a scroll — any game object that starts or is part of a quest).

**Expected output:**
```
[QuestieLearner] Learned Object: <id> <ObjectName>
```

Verify:
```
/script local o=Questie.db.global.learnedData.objects; local n=0; for _ in pairs(o) do n=n+1 end; print("Learned objects:", n)
```

---

## Test 8 — Overall Stats Check

Run this anytime to see a full summary of what has been learned this session:
```
/script local QL=QuestieLoader:ImportModule("QuestieLearner"); local n,q,i,o=QL:GetStats(); print("NPCs:"..n.." Quests:"..q.." Items:"..i.." Objects:"..o)
```

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
2. Run `/script QuestieLoader:ImportModule("QuestieLearner"):ClearAllData()` to wipe learned data.
3. Open Questie Options → Database → paste the export string into the Import box → click Import.

Expected in chat:
```
Import complete: merged N entries, skipped 0 (already known).
[QuestieLearner] Injected learned data: N NPCs, N quests, N items, N objects
```

Verify stats match original count (Test 8).

---

## Test 11 — Plugin Panel Stats (WotLKDB)

Open **Questie Options → Advanced** and scroll to **Loaded Questie-X Plugins**.

Expected for WotLKDB:
```
[Questie-WotLKDB]   Quests: 9086   NPCs: XXXX   Objects: XXXX   Items: XXXX
```

If you see all zeros, the `QuestieX_WotLKDB_Counts` global was not set before the Loader.lua read it. Check that `QuestieInit:LoadBaseDB()` is running before `PLAYER_LOGIN` completes.

---

## Test 12 — Peer Sharing (Requires Two Clients)

On Client 1, learn a new NPC (walk up to a quest giver not previously recorded).

On Client 2, run:
```
/script print(type(Questie.db.global.learnedData.npcs[<npcId>]))
```

Expected: `table` (the NPC data arrived via the hidden `questiecomm` channel or AceComm guild broadcast).

> **Note:** Both clients must be in the same guild OR on the same server (for the hidden channel). Allow up to 10 seconds for the token-bucket throttle to release the message.

---

## Quick Diagnostic — All At Once

Paste this block into chat for a full snapshot:
```
/script local QL=QuestieLoader:ImportModule("QuestieLearner"); local n,q,i,o=QL:GetStats(); print("=== QuestieLearner Stats ==="); print("NPCs:"..n.."  Quests:"..q.."  Items:"..i.."  Objects:"..o); local ld=Questie.db.global.learnedData; print("Enabled:", tostring(ld.settings.enabled)); print("Learn NPCs:", tostring(ld.settings.learnNpcs)); print("Learn Quests:", tostring(ld.settings.learnQuests)); print("Learn Items:", tostring(ld.settings.learnItems)); print("Learn Objects:", tostring(ld.settings.learnObjects))
```

---

## Common Issues

| Symptom | Cause | Fix |
|---|---|---|
| Nothing prints at all | Debug level not set to DEVELOP | `/script Questie.db.profile.debugLevel = Questie.DEBUG_DEVELOP` |
| Random mobs being recorded | Old QuestieLearner.lua still loaded | Confirm v1.2.6+ is deployed, `/reload` |
| Kill coords not recording | NPC not in QuestieDB and not explicitly targeted/hovered before kill | Target the mob before killing it, or ensure your DB plugin is loaded |
| Export returns nil | `learnedData` is empty | Run Tests 2–7 first to accumulate data |
| WotLKDB shows 0s in plugin panel | `QuestieX_WotLKDB_Counts` not set | Verify `QuestieInit:LoadBaseDB()` has the count-before-pull logic |
| Item not recorded after loot | `GetItemInfo` async — item never seen before | Wait 1–2 seconds; if still missing, the item may not be a quest item |
