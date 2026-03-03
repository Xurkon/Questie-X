---
description: Comprehensive reference for Questie development, including corrections, database structure, and debugging.
---

# Questie Development Reference

This workflow aggregates vital information from the [Questie Wiki](https://github.com/Questie/Questie/wiki) for developers.

## 1. Development Environment & Contributing

**Wiki Page:** [Contributing](https://github.com/Questie/Questie/wiki/Contributing)

### Setup

* **Fork & Clone:** Fork the repo and clone it *outside* your WoW directory.
* **Symlink:** Create a symlink from your Clone to `Interface/AddOns/Questie`.
  * **Windows:** `mklink /J "C:\Path\To\WoW\_classic_\Interface\AddOns\Questie" "C:\Dev\Questie"`
  * **MacOS:** `ln -s ~/Dev/Questie /Applications/World\ of\ Warcraft/_classic_/Interface/AddOns/Questie`
* **IDE:** Recommended: IntelliJ + EmmyLua or VSCode + Lua Extension (sumneko).

### Commit Messages (Changelog)

Prefix commits to auto-generate changelog entries:

* `[quest]` e.g., `[quest] Fix pre quest for "Warm Welcome"`
* `[db]` e.g., `[db] Fix location of "Lar'korwi"`
* `[fix]` e.g., `[fix] Fix DMF dates for Era`
* `[feature]` e.g., `[feature] Add gold reward`
* `[locale]` e.g., `[locale] Add translation for "Next in chain"`

### Research & Documentation

* **Export Path:** Always copy research files (task.md, walkthrough.md, implementation_plan.md, and transcript) to `C:\Users\kance\Documents\Research\Questie\[Task-Name]`.

---

## 2. Core Architecture & System Overview

**Wiki Page:** [Overview](https://github.com/Questie/Questie/wiki/Overview)

Questie employs a modular architecture where specialized systems handle different aspects of the addon.

### Core Modules

* **Initialization:** `Modules/QuestieInit.lua` - Manages the staged loading process.
* **Database:** `Database/QuestieDB.lua` - Central hub for quest, NPC, item, and object data.
* **Map Integration:** `Modules/Map/QuestieMap.lua` - Handles icon placement and world map/minimap logic.
* **Tracking:** `Modules/Tracker/QuestieTracker.lua` - Manages the on-screen quest objective tracker.
* **Journey:** `Modules/Journey/QuestieJourney.lua` - Handles the quest history and search UI.
* **Corrections:** `Database/Corrections/QuestieCorrections.lua` - Applies patches to the base game data.
* **Communication:** `Modules/Network/QuestieComms.lua` - Manages data sharing between party members.

### Addon Initialization Flow

Questie uses a coroutine-based staged initialization to minimize performance impact:

1. **Stage 1: Data & Validation** - Loads database, applies corrections, and runs validators.
2. **Stage 3 (Stage 2 is internal wait): UI & Hooks** - Initializes trackers, maps, event handlers, and UI elements.

**CRITICAL NOTE ON GLOBAL NAMESPACES:** Modules are injected into the global namespace via `QuestieCompat.PopulateGlobals()` during `ADDON_LOADED` or `PLAYER_LOGIN`. Event handlers (like `CHAT_MSG_SYSTEM` for auto-turn-in quests) can fire *before* global variables are injected depending on client load orders. **Always use localized module imports** (e.g., `local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")`) at the top of files to prevent `attempt to index global '<Module>' (a nil value)` exceptions.

---

## 3. Database System Architecture

**Wiki Page:** [Database](https://github.com/Questie/Questie/wiki/Database)

The database system is a central component that stores and manages all quest-related information.

### Database Categories

The database consists of four primary data types:

* **Quest Data:** Information about quest requirements, objectives, rewards, etc.
* **NPC Data:** Information about non-player characters, including spawn locations.
* **Item Data:** Information about items, including where they drop.
* **Object Data:** Information about world objects like chests, mining nodes, etc.

### Database Structure

* **Base Data:** Located in `Database/<Expansion>/` (e.g., `classicQuestDB.lua`). **DO NOT EDIT DIRECTLY.**
* **Corrections:** Located in `Database/Corrections/`. THIS is where you make changes.
* **Expansion NPC Database Fields (e.g., `wotlkNpcDB.lua`):**
  * Index 1: `name`
  * Index 7: `spawns` - Format: `{[zoneID] = { {x,y}, ... }}`
  * Index 9: `zoneID` (Primary zone)
  * Index 12: `factionID`

### Zone & Area Management

`Database/Zones/zoneDB.lua` manages geographic data:

* **UI Map Mapping:** Maps internal Area IDs to UI Map IDs.
* **Dungeon Locations:** Tracks entrance coordinates for instances.
* **Subzone Mapping:** Relates subzones to their parent zones for proper icon inheritance.

### NPC Data Verification Best Practices

When implementing custom quests that require NPC spawn data:

1. **Verify NPC vs Object Classification**
   * Always check both `wotlkNpcDB.lua` AND `wotlkObjectDB.lua`
   * Wowhead may list objects in NPC search results (e.g., "Dragonblight Mage Hunter" ID 32572)
   * Use grep search: `grep -r "^\[NPC_ID\]" Database/Wotlk/` to confirm classification

2. **Spawn Data Completeness Verification**
   * NPCs in database may have nil spawns or incomplete spawn coordinates
   * Always compare scraped spawn counts with existing database entries
   * Common issues:
     * NPCs with `nil` spawn data (no coordinates at all)
     * NPCs with sparse spawn data (DB has 5 spawns, Wowhead shows 19)
     * NPCs with single spawn when multiple exist

3. **Individual NPC Page Scraping**
   * Scrape each NPC's individual Wowhead page for spawn coordinates
   * Use JavaScript to extract from `g_mapperData[zoneId][0].coords`
   * Don't rely on aggregate list views - they may not show all spawns

4. **Database Comparison Process**

   ```bash
   # Search for NPC in database
   grep "^\[NPC_ID\]" Database/Wotlk/wotlkNpcDB.lua
   
   # Check spawn data format: {[zoneID] = {{x,y}, {x,y}, ...}}
   # Compare coordinate count with scraped data
   ```

5. **Common Spawn Data Issues Found**
   * **Infinite Dragonflight NPCs**: Often have nil spawns (dungeon/instance spawns not in overworld)
   * **Quest Givers/Vendors**: Usually have 1 spawn (correct)
   * **Patrol NPCs**: May have waypoint data instead of static spawns
   * **Rare Spawns**: May have fewer coordinates than common NPCs

6. **Example: Quest 50064 Findings**
   * 50 NPCs extracted from Wowhead
   * 1 was an object (excluded)
   * 6 NPCs had nil spawns in database
   * 3 NPCs had incomplete spawn data (11 in DB vs 42 scraped)
   * Result: 49 valid NPCs, spawn data inconsistencies documented

---

## 4. Corrections System

**Wiki Page:** [Corrections](https://github.com/Questie/Questie/wiki/Corrections)

Corrections patch the runtime database to fix incomplete or incorrect game data.

### Loading Order

1. **Base Data** for the running expansion is loaded (e.g., TBC).
2. **Corrections** are applied in order: Classic -> TBC -> WotLK.
    * TBC corrections apply to WotLK.
    * Classic corrections apply to TBC and WotLK.
    * *Note:* Corrections in later files can overwrite earlier ones.

### NPC Correction File Structure

**CRITICAL**: NPC correction files (e.g., `tbcNPCFixes.lua`) have TWO sections:

1. **Main `Load()` Function** (lines 9-1064): Returns a table of corrections that apply to **ALL players** (both factions)
   * **Use this for**: General NPC spawn data, quest fixes, waypoints that apply to everyone
   * **Example**: Adding missing spawn coordinates for dragonkin NPCs

2. **Faction-Specific `LoadFactionFixes()` Function** (lines 1068+): Returns faction-specific corrections
   * **Use this for**: NPCs that only appear for Horde or Alliance (e.g., starting zone NPCs)
   * **Structure**: Returns `npcFixesHorde` or `npcFixesAlliance` based on player faction

**When adding NPC spawn data**: Add it to the **main `Load()` function** unless the NPC is faction-specific.

### Syntax

```lua
-- Database/Corrections/tbcQuestFixes.lua
[8300] = {
    [questKeys.startedBy] = {nil,nil,{1234}}, -- Started by Item 1234
    [questKeys.preQuestSingle] = {},           -- Remove pre-quest requirement
},
```

### Critical Keys (QuestieDB.questKeys)

* `startedBy` / `finishedBy`: `{ {Creature_IDs}, {Object_IDs}, {Item_IDs} }`.
  * Use `nil` for empty slots. Example: `{{123}, nil, nil}`.
* `preQuestSingle`: List of required pre-quests.
* `exclusiveTo`: List of quests that hide this one.
* `nextQuestInChain`: ID of the next quest.
* `requiredLevel` (Index [4]): Minimum level required to accept the quest.
* `questLevel` (Index [5]): The actual level of the quest (determines XP/Colors).
* `requiredRaces` (Index [6]): Bitmask (use `QuestieDB.raceKeys`).
* **`zoneOrSort` (Index [17])**: **Zone ID** (positive for Area Table ID) or Quest Sort ID (negative). **This is the zone field for custom quests.**
  * **WARNING:** Do NOT use Index [6] (`requiredRaces`) for Zone ID. This is a common mistake that causes "Unknown Zone" errors.

---

## 5. Quest Tracking & Map Systems

### Quest Tracker Components

The tracker UI consists of several key components:

* **TrackerBaseFrame:** The main frame that contains the entire tracker.
* **TrackerHeaderFrame:** Contains the tracker's header with title and buttons.
* **TrackerQuestFrame:** Manages the display of individual quests.
* **TrackerLinePool:** A pool of line elements for quest objectives and text.

### Combat Queue System (`QuestieCombatQueue.lua`)

**CRITICAL:** Avoids UI "taint" and errors by queuing operations during combat:

* Queues operations requested during combat.
* Executes queued operations immediately upon leaving combat (`PLAYER_REGEN_ENABLED`).
* Essential for preventing interference with Blizzard's protected combat frames.

### Map Icon & Tooltip System

* **Frame Pooling:** Icons are managed via `QuestieFramePool` to reuse frames and reduce memory overhead.
* **Icon Frames:** `QuestieFrame` displays the actual markers.
* **HBD Integration:** Uses `HereBeDragons` (via `HBDHooks.lua`) for coordinate conversions.
* **Tooltip System:** `MapIconTooltip` and `TooltipHandler` provide hover info, including party member progress.

### QuestieArrow & Finisher Tracking (`QuestieArrow.lua`)

* **Finisher Waypoints:** The Questie Arrow (`QuestieArrow:UpdateNearestTargets`) relies on `quest.isComplete` and `QuestieDB.IsComplete` to switch from targeting objectives to targeting the quest turn-in (Finisher) NPC or Object.
* **Object Properties Limit:** When evaluating the exact finisher location, Questie quest objects contain limited attributes for the Finisher: only `.Id` and `.Type` (`"monster"` or `"object"`). Any attempt to index `quest.Finisher.Name` will fail and cause finisher logic to be skipped entirely.
* **Distance Checks:** `_CollectFinisherSpawns` evaluates `HBD:GetWorldDistance`. If the finisher is in another zone and the player has auto-tracking enabled (`usingAutoLogic and zone ~= playerZoneId`), QuestieArrow will intentionally hide distant finisher marks.

### Completion State Evaluation (`QuestieDB.IsComplete`)

* **Server vs Client State:** The `finished` flag on quest objectives is governed by server `GetQuestLogTitle` packets. Because quests consuming items (e.g. freeing prisoners with keys) update numeric counts instantly but delay the `finished` flag until turn-in time, Questie manually evaluates completeness.
* **Logical Evaluation Bug**: When implementing loops iterating numerical objectives, never use inline ternary operators like `(object[1] and 0)` right at the start, as Lua will evaluate existency strings as truthy and short-circuit return 0 regardless of actually finishing the `numFulfilled == numRequired` checks. Iterate the full list and verify `allDone` instead.

### Objective Priority & Hide Conditions

* **HideCondition Mechanism**: Allows hiding specific objectives (regular or extra) based on the player's quest log status.
  * `hideIfQuestActive`: Hides the objective if the specified Quest ID is in the player's log OR already completed.
  * `hideIfQuestComplete`: Hides the objective only if the specified Quest ID is already completed.
* **Implementation**:
  * **Regular Objectives** (Monsters, Objects, Items): The `HideCondition` is stored as the **3rd field** in the objective sub-table (e.g., `{{NPC_ID, nil, {["hideIfQuestActive"] = 12966}}}`).
  * **Extra Objectives** (Index 27): The `HideCondition` is stored as the **6th field** in the extra objective sub-table.
* **Immediate UI Feedback**: When a quest acceptance should immediately hide another objective or pivot the arrow, call `QuestieArrow:Refresh()` within the `AcceptQuest` TaskQueue in `QuestieQuest.lua`.

---

## 6. Additional Systems

### Journey System

* **My Journey:** A chronological record of the player's quest history.
* **Quests By Zone:** Browse quests by zone, filtering by availability and completion status.
* **Search:** Advanced search for quests, NPCs, items, and objects by name or ID.

### Network Communication

* **QuestieComms:** Manages data sharing between party members.
* **QuestieSerializer:** Converts complex tables to strings for transmission.
* **QuestieAnnounce:** Provides options for announcing quest progress to chat.

---

## 7. Localization

**Wiki Page:** [Localization](https://github.com/Questie/Questie/wiki/Localization-to-more-languages)

To test or add translations locally, use `QUESTIE_LOCALES_OVERRIDE` in a global scope (e.g. `Questie.lua` top):

```lua
QUESTIE_LOCALES_OVERRIDE = {
    locale = 'deDE',
    localeName = 'Deutsch',
    translations = {
        ["Objects"] = "Об'єкти", -- Key is original string
    },
    itemLookup = { [31] = "Alte Löwenstatue" }, -- ID -> Name
    npcNameLookup = { [3] = {"Fleischfresser", nil} }, -- ID -> {Name, Title}
    objectLookup = { [31] = "Alte Löwenstatue" },
    questLookup = { [2] = {"Title", {"Description"}, {"Objective"}} },
}
```

---

## 8. Debugging Tools

**Wiki Page:** [Debugging](https://github.com/Questie/Questie/wiki/Debugging)

* **Mocking Player State:** Add to top of `Questie.lua`:

    ```lua
    UnitLevel = function() return 10; end
    UnitRace = function() return "nightelf", "nightelf"; end
    ```

* **Module Access:**

    ```lua
    QuestieLoader:ImportModule("QuestieDB").GetQuest(123)
    ```

* **Verification:** Enable "Advanced Options" -> "Debug", open Journey, use Search tab to see the *final* data after corrections.

---

## 9. Extracting Spawns and NPCs

### Manual Spawn Extraction (Traditional Method)

**Page:** [Extracting Spawns](https://github.com/Questie/Questie/wiki/Extracting-spawn-locations-from-wowhead)

* Use the Javascript snippet on Wowhead maps to generate Lua table output `{{x,y},...}}`.

### Automated NPC Extraction (Browser Automation)

For quests requiring all NPCs of a specific type in a zone (e.g., "kill all beasts"), use browser automation to extract NPC IDs from Wowhead's database.

**Wowhead Filter URL Format:**

```
https://www.wowhead.com/wotlk/npcs/beasts?filter=6;ZONE_ID;0
```

- Replace `beasts` with the creature type (beasts, humanoids, dragonkin, etc.)
* Replace `ZONE_ID` with the zone ID (e.g., 3522 for Blade's Edge Mountains, 3523 for Netherstorm)

**Extraction Method:**

1. Navigate to the filtered Wowhead URL
2. Use JavaScript to access Wowhead's internal data:

   ```javascript
   const listview = Object.values(g_listviews).find(lv => lv.id === 'npcs');
   listview.data.map(npc => npc.id + ' - ' + npc.name).join('\n');
   ```

3. This returns all NPC IDs and names matching the filter

**Example Use Cases:**
* Quest 50085 (Savage Heights): Extracted 47 beast NPCs from Blade's Edge Mountains
* Quest 50086 (Unstable Fauna): Extracted 18 beast NPCs from Netherstorm

**Benefits:**
* Faster than manual lookup
* Ensures no NPCs are missed
* Provides complete list for `killCreditObjective` implementation

---

Custom server data should **NOT** use the Corrections system. Use separate database modules (e.g., `Database/Ebonhold/`).

* **Quests:** Added to `EbonholdDB.questData` (or `EbonholdQuestDB.questData`).
* **NPCs:** Added to `EbonholdDB.npcData`.

### Missing Base Data (Upstream Preservation)

If the original database files (standard Questie DB) are missing data (e.g. missing NPC spawns in TBC content), **DO NOT** add this data to the standard `Database/Corrections` folder.
Instead, add the missing data to the **specific server's database folder** (e.g., `Database/Ebonhold/`).

* **Reason:** Updating the main Questie database files (including standard corrections) will wipe local changes. Custom server database files are preserved during updates.

**CRITICAL OVERRIDE WARNING FOR CUSTOM DBs:**
When adding missing coordinate data to pre-existing base NPCs via `EbonholdNpcDB.lua`, the custom database engine **does not perform a deep merge**. If you inject an entry that only defines the `[npcKeys.spawns]` array, it will obliterate the entire base NPC node (wiping its name, health, rank, and other metrics). This results in `attempt to index nil` errors rendering the Map Tooltips.

To safely override base coordinates, you must:

1. Copy the **entire** data array for the NPC from the `classicNpcDB.lua` or `wotlkNpcDB.lua` into your custom `EbonholdNpcDB.lua` and enrich it there.
2. OR, if injecting massive coordinates is necessary without full transcribing, they can be injected into the base files (`Database/Corrections/wotlkNPCFixes.lua` deep-merges correctly), understanding that these edits are at risk of being wiped during a standard Questie version upgrade.

### Critical Rules for Custom Quests

#### 1. Never Duplicate Existing NPCs/Objects

NPCs/objects from base WotLK/TBC/Classic databases already exist with spawn data. Only add to custom DB if it's truly custom content.

#### 2. Object Data Structure - Use Indexed Fields

**✅ CORRECT:**

```lua
[600600] = {
    [1] = "Elemental Shrine",      -- Indexed fields
    [2] = nil,                      -- Type
    [3] = nil,                      -- Zones
    [4] = {[3518] = {{50, 70}}},   -- Spawns: {[zoneId] = {{x,y}}}
    [5] = 12,                       -- Faction
}
```

#### 3. Multi-NPC Objectives - Use killCreditObjective

**Problem:** When a quest requires killing multiple NPC types that should count toward the same objective (e.g., "Kill 30 Elementals" where multiple elemental types exist), using standard `creatureObjective` creates separate tracker entries for each NPC.

**Solution:** Use `killCreditObjective` (objectives[5]) to map multiple NPC IDs to a single counter while showing all NPC spawns on the map.

**Structure:**

```lua
[10] = { -- objectives
    nil, -- [1] creatureObjective (not used)
    nil, -- [2] objectObjective (not used)
    nil, -- [3] itemObjective (not used)
    nil, -- [4] reputationObjective (not used)
    {    -- [5] killCreditObjective
        {
            {17156, 17157, 22309, 22310}, -- IdList: all NPC IDs that grant credit
            17157,                          -- RootId: representative NPC ID
            "Shattered Rumbler slain"       -- Text shown in tracker
        }
    }
}
```

**How It Works:**

1. **Database Processing** (`QuestieDB.lua:1276-1293`): Creates a `killcredit` objective with `IdList` and `RootId`
2. **Spawn Handler** (`QuestieQuestPrivates.lua:65-73`): Iterates through `IdList` and creates map icons for each NPC
3. **Tracker**: Shows single entry (e.g., "Shattered Rumbler slain: 0/30")
4. **Map**: Displays icons for all NPCs in the `IdList`

**Example Use Case:**
Quest 50026 requires killing 30 elementals. Six different elemental NPC types exist (17156, 17157, 22309, 22310, 22311, 22313). Using `killCreditObjective` ensures:
* All six NPC types show on the map
* Single tracker counter increments for any kill
* No duplicate "0/30" entries in the tracker

#### 4. Server-Tracked Objectives ("Complete N Quests in Zone")

**Problem:** Some custom quests are completed by the server when a condition is met (e.g., completing 6 quests in a zone). The server sends one objective to the client, but if `quest.ObjectiveData` has no matching entry, `PopulateQuestLogInfo` throws:

```
Missing objective data for quest <ID> Complete 6 quests in <Zone>
```

**Root Cause:** `QuestieQuest:PopulateQuestLogInfo` (line 1578) requires a `quest.ObjectiveData[index]` entry for every objective the server reports. If the quest has no objectives defined (no `[10]` field) and no `triggerEnd` (`[9]`), `ObjectiveData` is empty and the error fires.

**Wrong Approach (do not do this):**

```lua
-- Adding an all-nil [10] table does NOT create ObjectiveData entries
[50111] = {
    ...
    [10] = { nil, nil, nil, nil, nil },  -- Still results in empty ObjectiveData
},
```

**Correct Fix:** Use the `[9]` (`triggerEnd`) field. `QuestieDB.GetQuest` maps `rawdata[9]` → `QO.triggerEnd` and appends `ObjectiveData[1] = {Type="event"}`. No map pins are drawn when coordinates are `nil`.

```lua
[50151] = {
    [1] = "Icecrown Advance",
    [2] = { nil, { 600600 } },
    [4] = 80,
    [5] = 73,
    [17] = 210,
    [8] = {
        "This quest requires completing any 6 quests in Icecrown. The quest will automatically complete once the objective is met.",
        "Complete 6 quests in Icecrown"
    },
    [9] = { "Complete 6 quests in Icecrown", nil },  -- triggerEnd: text, no coordinates
},
```

**How it works:**

1. `QuestieDB.GetQuest` reads `rawdata[9]` → sets `QO.triggerEnd`
2. At line 1312-1320: `ObjectiveData[#ObjectiveData+1] = {Type="event", Text=..., Coordinates=nil}`
3. `PopulateQuestLogInfo` finds `ObjectiveData[1]` → no error
4. `PopulateObjective` sees `Type="event"` with no coordinates → no map pins drawn

**Rule:** Any quest where the server tracks completion internally (zone quest counts, escort hand-off, etc.) with no kill/gather objective should use `[9]` with a text description and `nil` coordinates. Do **not** add a `[10]` objectives table for these quests.

---

#### 5. Auto-Complete Quests

**Problem:** Some custom server quests auto-complete when objectives are finished, without requiring the player to return to a quest giver or object.

**Solution:** Omit the `finishedBy` field (index 3) from the quest data. This prevents Questie from showing a turn-in icon or expecting a return trip.

**Structure:**

```lua
[50026] = {
    [1] = "Quest Name",
    [2] = {nil, {objectId}},        -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
    -- [3] finishedBy is omitted for auto-complete quests
    [4] = 60,                       -- Required level (Min level)
    [5] = 67,                       -- Quest level
    [17] = 3518,                    -- Zone ID
    [8] = {"Description", "Objective text"},
    [10] = { ... },                 -- Objectives
}
```

**Behavior:**
* Quest starter icon appears on the map
* No turn-in icon appears after objectives are complete
* Quest automatically completes on the server when objectives finish

#### 5. Quest Data Structure

```lua
[50026] = {
    [1] = "Quest Name",
    [2] = {nil, {objectId}},        -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
    [4] = 60,                       -- Required level (Min level)
    [5] = 67,                       -- Quest level
    [17] = 3518,                    -- Zone ID
    [8] = {"Description", "Objective text"},
    [10] = {{{npcId, count}}},      -- Objectives (kill X of npcId)
}
```

---

## 11. Common Solutions

### No Objectives Shown

* **Page:** [No Objectives](https://github.com/Questie/Questie/wiki/Example%3A-No-Objectives)
* **Cause:** Quest references an item/object/NPC that has no spawn data.
* **Fix:** Ensure the target NPC/Object exists and has `[4]` (spawns) filled. If it's an item, check `npcDrops`.

### Breadcrumb Quests

* **Page:** [Breadcrumb Quests](https://github.com/Questie/Questie/wiki/Example%3A-Breadcrumb-quests)
* **Fix:** Use `nextQuestInChain` or `exclusiveTo` to hide the breadcrumb when the main quest is taken.

---

## 13. Debugging Stuck Arrows

### Scenario: Arrow persists on an NPC after picking up a follow-up quest

1. **Check for Multiple Quests**: Verify if more than one active quest has an objective at that NPC. Use Journey search for the NPC ID.
2. **Verify NPC Coordinate Overlap**: Compare NPC coordinates in `wotlkNpcDB.lua`. NPCs in the same hub (like Dun Niffelem) often share base coordinates. If Questie switches targets to a different NPC at the same location, the arrow will appear "stuck."
    * **Fix**: Override the quest finisher in `wotlkQuestFixes.lua` to point to a distinct NPC or Object (e.g., moving the arrow from the King to the Anvil).
3. **Apply HideConditions**: If an objective is redundant once a breadcrumb quest is accepted, apply `hideIfQuestActive` to the correction data for that objective.
4. **Confirm Database Loading**: Ensure `QuestieDB.GetQuest` is correctly parsing the `HideCondition` field for the objective type.
