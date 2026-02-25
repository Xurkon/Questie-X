# Changelog

## v9.8.4

### Fixes
- **[Quest]** Fixed a Lua crash ("attempt to index global 'QuestiePlayer'") occurring during chat message processing for auto-completing quests, by explicitly requiring the `QuestiePlayer` module in `QuestEventHandler`.

## v9.8.3

### Fixes
- **[Quest]** Extended `HideCondition` support to regular monster, object, and item objectives in the database.
- **[Quest]** Added `hideIfQuestActive` conditions to quest 13010 objectives to resolve icon overlap at King Jokkum.
- **[Database]** Corrected the finisher for "You Can't Miss Him" (12966) to NPC 30127, properly moving the arrow to Fjorn's Anvil.
- **[Arrow]** Implemented immediate arrow refreshing upon quest acceptance to provide seamless transitions between objective phases.

## v9.8.2

### Fixes
- **[Quest]** Updated the objective tooltip for "Forging an Alliance" (12924) at King Jokkum to explicitly instruct players to pick up the breadcrumb quest "You Can't Miss Him" (12966).

## v9.8.1

### Fixes
- **[Quest]** Fixed QuestieArrow direction for "Forging an Alliance" (12924). Added an extra objective to speak with King Jokkum, ensuring the arrow points toward the breadcrumb quest start at the beginning of the quest.

## v9.8.0

### Fixes
- **[Quest]** Modified `BAG_UPDATE_DELAYED` to trigger a quest log update and instantly refresh the tracker when items are deposited directly into bags by autoloot bots that bypass standard item events.
- **[Map]** Fixed an issue where "Special Objectives" (e.g., source item drops) failed to check player bag contents upon completion, causing their map icons to linger indefinitely until the main quest was turned in.

## v9.7.12

### Fixes
- **[Quest]** Fixed an issue where tracking icons for dynamically updated custom quests like Peak Predators would prematurely disappear due to sync delays on WotLK servers.
- **[Map]** Resolved a frame pool leak that prevented the yellow Finisher icon from appearing immediately on the map after turning in or completing a quest.


- **[Database]** Corrected an error that improperly identified Item Finishers as GameObject Finishers on custom servers, causing map pinpointing errors (e.g. `[QuestieDB:GetObject] rawdata is nil for objectID:`).
- **[Database]** Appended correct fallback spawn data for the "Thorim" listen bunny (`NPC 30514`) so Sibling Rivalry's turn in/listen point functions correctly on WotLK clients.

## v9.7.11

### Fixes
- **[Quest]** Fixed an issue where quest objective icons and waypoints failed to clear from the map after a quest was completed or abandoned.
- **[Tracker]** Prevented quests from falsely flagging as complete and wiping tracking data when the World of Warcraft server drops its objective arrays. Fixes "Peak Predators" icons disappearing randomly.
- **[Database]** Corrected an error that improperly identified Item Finishers as GameObject Finishers on custom servers, causing map pinpointing errors (e.g. `[QuestieDB:GetObject] rawdata is nil for objectID:`).
- **[Database]** Appended correct fallback spawn data for the "Thorim" listen bunny (`NPC 30514`) so Sibling Rivalry's turn in/listen point functions correctly on WotLK clients.

## v9.7.10

### Fixes
- **[Arrow]** Refactored Arrow logic to drastically improve target distance calculations and prioritize targets correctly based on the player's current zone.
- **[Arrow]** Fixed a bug where the Arrow would mistakenly point to previously completed objective locations instead of the Quest Finisher's exact location.
- **[Tracker]** Fixed `QuestieDB.IsComplete` edge case returning incomplete incorrectly; now verifies `numFulfilled == numRequired` to immediately acknowledge completed quests while awaiting the server flag.
- **[Tracker]** Resolved false-positive "broken quest log" errors spamming chat on WotLK servers by correctly handling API responses for trackable objectives.
- **[Tracker]** Demoted harmless WotLK objective cache count mismatches from Error to Debug visibility level to eliminate chat spam on login.
- **[Quest]** Fixed quest arrow pointing to the key-drop NPC after using all consumable quest keys (e.g. Cold Iron Key for "They Took Our Men!" quest 12843). When a quest uses a key item that is consumed on interaction, it leaves the bag and `CheckQuestSourceItem` returns false, incorrectly triggering a quest reset that re-drew the key source NPC on the map. Now checks if all tracked objectives are already `Completed=true` before applying the reset, preventing the spurious icon.

## v9.7.9

### Fixes
- **[Quest]** Fixed tracker objective count staying stale (e.g. stuck at 14/16 when quest is complete) when an autoloot bot bypasses the standard loot frame. Registered `BAG_UPDATE_DELAYED` event to force a full quest log scan on bag changes, catching progress updates that `QUEST_WATCH_UPDATE` would normally fire for manual looting.

## v9.7.8

### Fixes
- **[Quest]** Fixed "There was an error populating objectives" error in chat for `triggerEnd` quests with no map coordinates (e.g., "complete N quests in zone"). `_RegisterObjectiveTooltips` now silently returns for `event`-type objectives with no `spawnList` — these have nothing to register a tooltip for.

## v9.7.7

### Fixes
- **[Quest]** Fixed "Missing event data for Objective" error appearing in chat for all `triggerEnd` quests with no map coordinates (e.g., "complete N quests in zone" types). Nil coordinates are valid for server-tracked objectives with no pin — the handler now returns silently instead of logging a visible error.

## v9.7.6

### Fixes
- **[Database]** Fixed "Missing objective data" error for all "complete N quests in zone" quest types (IDs 50151, 50145, 50098, 50100, 50149, 50099, 50108, 50111, 50150). Added `triggerEnd` (`[9]`) field so Questie correctly registers the server-tracked objective without drawing map pins.

## v9.7.5

### Fixes
- **[Quest]** Fixed objective pins/icons persisting on the map after a quest is completed or abandoned. Added `CleanupRemovedQuestsFallback` which diffs Questie's quest log against the game's actual quest log on every `QUEST_LOG_UPDATE` and correctly calls `CompleteQuest` or `AbandonedQuest` for any quest that silently disappeared, ensuring map icons are removed.
- **[Quest]** Fixed re-accepted repeatable custom quests (e.g., Stormforged Scales) not showing objective icons on the map after being accepted a second time.

### New Quests
- **[Database]** Added **Storm Peak Orders** (ID 50150) - *The Storm Peaks*
    - Objective: Complete any 6 quests in The Storm Peaks.
- **[Database]** Added **Wild Basin** (ID 50094) - *Sholazar Basin*
    - Objective: Kill 75 Beasts. Includes 29 Beast NPC types with full spawn coordinates.
    - NPCs: King Krush, Shardhorn Rhino, Aotona, Pitch, Serfex the Reaver, Dreadsaber, Hardknuckle Matriarch, Shango, Venomtip, Bushwhacker, Hardknuckle Charger, Ravenous Mangal Crocolisk, Farunn, Zeptek the Destroyer, Goretalon Matriarch, Sapphire Hive Wasp, Emperor Cobra, Sapphire Hive Drone, Shattertusk Bull, Siltslither Eel, Spirit of Atha, Stranded Thresher, Mangal Crocolisk, Spirit of Koosu, Longneck Grazer, Goretalon Roc, Sapphire Hive Queen, Spirit of Ha-Khalan, Bittertide Hydra

## v9.7.4

### Fixes
- **[Tooltips]** Fixed "attempt to concatenate local 'name' (a nil value)" error when quest starters/finishers have missing names in the database.
- **[Database]** Added missing spawn coordinates for Quest 50031 "Stormbound" elementals in Storm Peaks (zone 67).
- **[Database]** Fixed "Unknown Zone" issue for custom quests by correcting Zone ID index usage (swapped `[6]` RequiredRaces for `[17]` ZoneID).
- **[Database]** Corrected Dragonblight Zone ID in custom quest definitions.

### New Quests
- **[Database]** Added **Morogh Missions** (ID 50098) - *Dun Morogh*
    - Objective: Complete any 6 quests in Dun Morogh. Auto-completes upon reaching the objective.
- **[Database]** Added **Azuremyst Aid** (ID 50100) - *Azuremyst Isle*
    - Objective: Complete any 6 quests in Azuremyst Isle. Auto-completes upon reaching the objective.
- **[Database]** Added **Stormforged Scales** (ID 50066) - *The Storm Peaks*
    - Objective: Kill 30 Dragonkin. Includes 8 Dragonkin NPC types with full spawn coordinates.
- **[Database]** Added **Peak Predators** (ID 50095) - *The Storm Peaks*
    - Objective: Kill 75 Beasts. Includes 24 Beast NPC types with full spawn coordinates.
- **[Database]** Added **Peak Predators** (ID 50096) - *Icecrown*
    - Objective: Kill 75 Beasts. Includes 12 Beast NPC types with full spawn coordinates.
- **[Database]** Added **Icecrown Advance** (ID 50151) - *Icecrown*
    - Objective: Complete any 6 quests in Icecrown. Auto-completes upon reaching the objective.
- **[Database]** Added **Storm Peaks Trophy** (ID 50205) - *The Storm Peaks*
    - Objective: Kill 1 Rare in The Storm Peaks. Includes 4 Rare NPC types (Skoll, Time-Lost Proto-Drake, Vyragosa, Dirkee) with full spawn coordinates.

## v9.7.3

### New Features
- **[Database]** Implemented **Ebonhold Database Module**.
    - Created dedicated `Database/Ebonhold/` structure for custom server data.
    - Added `EbonholdLoader` to inject custom Quests, NPCs, Objects, and Items as overrides.
    - **Note:** This structure preserves custom data during upstream Questie updates.
- **[Objectives]** Implemented **Automated Text Retrieval**.
    - Questie now attempts to fetch quest text from the server at runtime for custom quests that are missing from the database.
    - Added "Objectives Board" (ID 600600) as a global quest starter.

### Quests (Custom Content)
- **[New]** Added **Heart of the Dragonflights** (ID 50064) - *Dragonblight*
    - Objective: Kill 30 Dragonkin. Includes 49 Dragonkin NPC types.
- **[New]** Added **Skies of Blade's Edge** (ID 50060) - *Blade's Edge Mountains*
    - Objective: Kill 75 Dragonkin. Includes 17 Dragonkin NPC types.
- **[New]** Added **Shadowed Beasts** (ID 50087) - *Shadowmoon Valley*
    - Objective: Kill 75 Beasts. Includes 25 Beast NPC types.
- **[New]** Added **Forest Stalkers** (ID 50083) - *Terokkar Forest*
    - Objective: Kill 75 Beasts. Includes 53 Beast NPC types.
- **[New]** Added **Savage Heights** (ID 50085) - *Blade's Edge Mountains*
    - Objective: Kill 75 Beasts. Includes 47 Beast NPC types.
- **[New]** Added **Unstable Fauna** (ID 50086) - *Netherstorm*
    - Objective: Kill 75 Beasts. Includes 18 Beast NPC types.
- **[New]** Added **Elemental Balance** (ID 50026) - *Nagrand*
    - Objective: Kill 30 Elementals. Includes 12 Elemental NPC types.
- **[New]** Added **Redridge Trophy** (ID 50160) and **Zangarmarsh Trophy** (ID 50192).

### New Ascension Quests
- **Westfall**: Agria's Medicine, Seven Years of Bad Luck, Worm-Eaten Apple, Goldshire's Generosity, Bookworm, Knowledge Corrupts, The Ruins of Northshire, Accursed Sisterhood, Words That Shepherd Madness, Oracular Idol, A Betrayal Within, The Maid I Left Behind, The Saddest Among Us, The Threat Swept Downstream, Stay a While, Defias Disruption.
- **Dun Morogh**: A Small Mistake, We Found Her!, The Scout's Favor, Old Mirsinth, Smoke on the Wind, A Promising Path, A Fitting Disguise, His Radiant Majesty, Deciphering Radiation, Soaking the Masses, Sever the Right Hand, A Growing Business, Thunderbrew's Hop, Stay a While, Live-Fire Demo, Bots on Strike, A Brother's Betrayal, The True Story, Timber for the Coldhewn, Icehide the Unbroken.
- **Teldrassil**: The Carrion Road, The Sister Who Never Returned, Finding the Good Meat, Transsubstantiating the Flesh, Communion Banquet, A Trail of Petals, Restless entrails, A Dark Warning, The Aid of Theren-Dion, No Place for Scavengers, Termites in Teldrassil, Stay a While, Elydna's Heirloom.
- **Durotar**: To Find a Cure, A Dangerous Sample, Knowledge of the Centaurs, Those Who Fell, The Way is Shut, The Sinister Triad, So That He May Hear Again, A Sinister Ritual, Innocents for Sinners, Unease Makes Tongues Wag, A Door Left Ajar, Esgramor's Master, Shinies!, Echoes of Hirsutta, Auction the Past, Stay a While, Durotar's Dire Drought, The Queen's Decree, Avianna's Rose, The Last Piece, Reversion.
- **Tirisfal Glades**: Rude Awakening, Marla's Last Wish, Monsters With Noble Intentions, Restless Family Members, An Unspeakable Secret, A Noble Heritage, The True Heir of the Cains, The Friends We Make Along the Way, I'm Home, Apothecary Flemer, The Nature of Freedom, Spotless Standing, Stay a While, More Than the Sum of its Parts, Scarlet Correspondence, A Humble Duty, The Balnirs' Rest, Brewing Disarray, This Is Justice.
- **Mulgore**: Death and Tribute, Death and Exile, Death and Dishonor, Death and Justice, Death by Laughter, To Whom I Devote, Fighting Over Carrion, Smoke on the Horizon, Amphora of Sacred Water, Stay a While, Exile of Embers, The Smoke that Remembers, The Circle’s Rite.

### New Ebonhold Quests
- **Outland**: Elemental Balance, Savage Heights, Unstable Fauna, Forest Stalkers, Marsh Predators, Skies of Blade's Edge, Shadowed Beasts, Zangarmarsh Trophy.
- **Northrend**: Tundra Turbulence, Stormbound, Dragonblight Trophy, Heart of the Dragonflights, Peak Predators, Icecrown Advance, Storm Peaks Trophy, Stormforged Scales, Fjord Front, Wild Basin, Grizzly Trophy, Zul'Drak Trophy, Basin Expeditions.
- **Azeroth**: Redridge Trophy, Morogh Missions, Azuremyst Aid, Shadow of Teldrassil, Trials of Durotar, Song of the Woods, Morogh Trophy, Tirisfal Trophy.

### Fixes
- **[Tracker]** **Combat Update Fix**: Tracker now updates objectives immediately during combat without causing Lua errors or taint.
- **[Tracker]** **Bag Update Fix**: Quest progress now updates immediately when looting items (fixes delay with loot bots).
- **[Arrow]** **Refined Visibility Logic**:
    - **Auto Nearby**: Arrow correctly defaults to showing the nearest quest when no quests are tracked.
    - **Zone Filter**: In "Auto Mode", the arrow hides if the nearest quest is in a different zone.
    - **Instance Filter**: Arrow explicitly hides if the target is in a different instance.
- **[Map]** Fixed an issue where completed quest icons would persist on the map (`RequestMapUpdate` logic).
- **[Database]** Updated `wotlkNpcDB.lua` with scraped spawn data for 12 key beast NPCs in Terokkar Forest to ensure accuracy.
- **[Arrow]** Fixed a nil function error for `_CollectObjective` when processing incomplete quests.
- **[Arrow]** Fixed syntax issues that prevented `QuestieArrow` module from initializing correctly.
- **[Database]** Fixed a runtime crash in `ZoneDB` when encountering maps with no AreaId mapping (e.g., Kalimdor).
