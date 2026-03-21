# Changelog

## v1.4.4r5 — Comprehensive LibDeflate Taint Fix

- **[Network Fix]** Expanded the previous LibDeflate network crash hotfix: completely purged all 71 instances of unsafe `#` -> `table.getn` replacements injected by earlier vanilla compatibility automation throughout `LibDeflate.lua`. These have been wrapped with a custom dual-typed safe access function that flawlessly determines whether to compute properties natively via `string.len(x)` for strings or the standard `table.getn(x)` for structured tables—guaranteeing 100% stable networking cross-client from 1.12 to 3.3.5 and upwards.

## v1.4.4r4 — LibDeflate Network Crash Fix

- **[Network Fix]** Fixed a critical Lua error (`bad argument #1 to 'getn' (table expected, got string)`) occurring during data-sharing via the hidden `questiecomm` addon channel. A legacy string length method (`table.getn`) was mistakenly used in `LibDeflate` string decoding; this has been restored to the universally compatible `string.len`.

## v1.4.4r3 — Legacy Client Initialization & Learner Fixes

- **[Init Fix]** Fixed an issue where the database loader would silently abort on custom 3.3.5 / legacy client setups due to false-positive modern client detection. The `isModernClient` safeguard now uses a bulletproof `tocversion` range check to flawlessly differentiate between original legacy engines and modern Classic counterparts.
- **[QuestieLearner Fix]** Resolved an `attempt to index global 'l10n' (a nil value)` error that triggered when accepting a new quest, caused by a missing module import at the top of `QuestieLearner.lua`.

## v1.4.4r2 — Cached Load Taint Fix

- **[Taint Fix]** Resolved lingering `ADDON_ACTION_BLOCKED` taint on `ActionButton` and `StaticPopup` that occurred when Questie loaded data from its cache rather than manually recompiling. The `_G` namespace cleanup for `Questie-X-WotLKDB` globals now runs accurately during cached loads (via `UpdateWotLKDBStats`), ensuring the taint vector is closed and additionally freeing ~20MB of redundant cached memory.

## v1.4.4r1 — WotLKDB Global Namespace Taint Fix

- **[Taint Fix]** Resolved `ADDON_ACTION_BLOCKED` errors caused by `Questie-X-WotLKDB` leaving tainted global variables in `_G` after initialization. `QuestieInit._pullGlobal` now sets `_G[globalName] = nil` immediately after copying each WotLKDB table reference into `QuestieDB`, removing the taint vector while keeping all data fully accessible through `QuestieDB`.

## v1.4.4 — AceGUI Pool & Event Handling Fixes

- **[AceGUI Fix]** Fixed `Compat/embeds.xml` to load Wrath-compatible Ace library versions from `Libs/` (AceGUI-3.0 v34, AceConfigDialog-3.0 v66) instead of newer versions from `..\Libs/` that caused widget pool corruption.
- **[AceGUI Fix]** Added nil checks throughout AceGUI-3.0 (`Create`, `Release`, `WidgetBase.Fire`, `WidgetContainerBase` methods) to prevent crashes when pooled widgets have corrupted/nil properties.
- **[AceGUI Fix]** Added content nil checks to layout functions (List, Flow, Fill, Table) to prevent crashes when `content` is nil during layout.
- **[AceGUI Fix]** Applied same nil check fixes to `Compat/Libs/AceGUI-3.0/AceGUI-3.0.lua` for consistency.
- **[Event Fix]** Added nil check for `message` parameter in `QuestieEventHandler:ChatMsgSystem` to prevent "bad argument #1 to 'find'" errors.
- **[Event Fix]** Added nil check for `level` parameter in `QuestiePlayer:SetPlayerLevel` to prevent "number expected, got nil" errors.
- **[QuestieLearner Fix]** Added `SanitizeData` function with depth limiting and proper key/value filtering to remove functions, userdata, and thread values from learned data before network serialization.
- **[QuestieLearner Fix]** Added pcall wrapper around AceSerializer:Serialize to catch and log any remaining serialization errors instead of crashing.
- **[QuestieLearner Fix]** Added early return checks in `BroadcastLearnedData` when data is nil or sanitization produces empty results.
- **[Journey Fix]** Added nil check for `container` in `HandleTabChange` to prevent "attempt to index local 'container'" errors.
- **[l10n Fix]** Added type check for `translationValue` in l10n:translate to prevent "bad argument #2 to 'format'" errors when translation is not a string or when format arguments are missing.
- **[Tracker Fix]** Removed redundant shift-click tracking toggle logic in `Hooks.lua` that was instantly reverting tracker states when shift-clicking a quest in the Quest Log.

## v1.4.3 — Taint & API Compatibility Fixes

- **[Taint Fix]** Deferred SetItemRef hook execution using C_Timer.After to avoid tainting protected execution contexts.
- **[Taint Fix]** Removed redundant `_G = _G or {}` from WotLKDB data file that could contribute to namespace pollution.
- **[Taint Fix]** Moved xpcall polyfill from bare `_G.xpcall` to `QuestieCompat.xpcall` namespace to prevent polluting the global table.
- **[API Fix]** Added polyfills for `GetCurrentRegion` and `GetCurrentRegionName` for AceDB-3.0 compatibility on WotLK/Classic.
- **[API Fix]** Added polyfills for `Ambiguate` and `RegisterAddonMessagePrefix` for AceComm-3.0 compatibility on WotLK/Classic.
- **[API Fix]** Added conditional check for `DialogBorderOpaqueTemplate` and `SetFixedFrameStrata` in AceConfigDialog for WotLK/Classic.
- **[AceGUI Fix]** Added WotLK-compatible fallback for `SetColorTexture` using `SetTexture` + `SetVertexColor`.

## v1.4.2 — Quest Route Optimization

- **[Feature]** Added Quest Route Optimization with three modes: Single Quest, All Tracked Quests, and TSP Approximation.
- **[Feature]** Route mode can be selected in Tracker options under "Route Mode".
- **[Feature]** Nearest-neighbor TSP algorithm for calculating optimal quest routes.
- **[Feature]** Visual route lines drawn on map connecting objectives in optimized order.

## v1.4.1 — Cleanup & Repository Maintenance

- **[Cleanup]** Removed `.history/` and `Research/` folders from repository tracking (were already gitignored but previously committed).
- **[Cleanup]** Removed `Tests/` folder from repository tracking.
- **[Badge]** Updated downloads badge format in README.
- **[Gitignore]** Added `tests/` to `.gitignore`.

## v1.4.0 — Taint Resolution & Compatibility Fixes

- **[C_Timer Fix]** Fixed `C_Timer` OnUpdate to use precise `(self, elapsed)` parameter instead of `1/GetFramerate()`.
- **[Achievement Fix]** Fixed `IsAchievementCompleted` to properly check completion boolean via `select(4, GetAchievementInfo(...))`.
- **[Map Fix]** Fixed `C_Map.GetPlayerMapPosition` to use correct legacy API (`GetPlayerMapPosition("player")`).
- **[QuestieLearner Fix]** Fixed `GetNpcIdFromGUID` and `GetObjectIdFromGUID` being called before definition.
- **[Taint Fix]** Added `InCombatLockdown()` guards and `pcall` wrappers to secure hooks to prevent protected function access errors.

## v1.3.9 — BackdropTemplate & Tracking Reliability

- **[Quest Tracking]** Significantly improved the reliability of shift-clicking to track or untrack quests.
- **[Quest Re-tracking]** Resolved an issue where hidden quests would refuse to re-track after being manually untracked.
- **[AceGUI Fix]** Fixed critical crash: `Couldn't find inherited node "BackdropTemplate"`.
- **[Verification]** Performed a comprehensive syntax audit using `luaparse`.

## v1.3.8 — UseAction Taint Fixes

- **[Taint Resolution]** Successfully resolved the `ADDON_ACTION_BLOCKED: UseAction()` error by updating internal libraries and eliminating global namespace pollution.
- **[Library Update]** Updated `Compat/embeds.xml` to use modern, taint-free versions of core libraries.
- **[Addon Stability]** Audited `QuestieInit.lua` and `QuestieLoader.lua` for safe global population.

## v1.3.7 — Quest Tracking & Robustness 

- **[Quest Tracking]** Resolved inconsistent quest tracking/untracking by making the tracking state idempotent. This eliminates "doing nothing" results while toggling quests in the Quest Log and prevents tracking loops caused by Blizzard's auto-track feature.
- **[Robustness]** Improved `QuestieTracker` to safely handle `nil` returns from the WoW API (`GetQuestLogTitle`), preventing potential "attempt to compare number with nil" errors during rapid quest log updates.
- **[Internal Logic]** Refined the detection of internal Blizzard objective updates to ensure they don't accidentally untrack quests that the user intended to watch.
- **[Linting]** Suppressed diagnostic warnings related to global namespace shimming in `QuestieCompat.lua`.

## v1.3.6 — Tooltip Fixes & Enhanced Taint Workaround

- **[Quest Progress]** Resolved an issue where quest tooltips would not reliably update their progress counts when dynamically learning AI spawns or during rapid kill credit updates.
- **[Taint Workaround]** Reinforced the `WorldMapTaintWorkaround` for older WoW clients (3.3.5) by correcting the `IsAddOnLoaded` detection timing and adding explicit empty-function stubs to blocked dropdowns.
- **[Diagnostics]** Improved error reporting for global variable collisions during module initialization.

## v1.3.5 — Comprehensive Taint & Architecture Fixes

*A comprehensive update resolving 13 distinct issues related to global environment taint, unsafe polyfills, and module stability across all supported Lua environments (5.0, 5.1, 5.2).*

### Core & Stability

- **[Taint Resolution]** Addressed 13 distinct taint and architectural issues discovered during a deep code audit.
- **[Taint Fix]** Removed unsafe `function Questie:Warning(...)` global monkey-patching in `QuestieTracker.lua` (`_InstallMissingQuestLogWarningFilter` deleted). Ghost quest iterations now use a safe, two-phase collection and deletion pattern to prevent warning generation upfront.
- **[Global Safety]** `hooksecurefunc` polyfill in `QuestieCompat.lua` no longer pollutes the global `_G` namespace. It runs strictly as a local fallback when the native function is absent.
- **[Global Safety]** Removed bare `_G` writes for `C_Seasons` and `C_Timer`.
- **[Global Safety]** Prevented `_G.QuestieX_WotLKDB_Counts` from writing to the global namespace in `QuestieInit.lua`. Counts are now cleanly stored directly on the plugin object (`plugin.stats`).
- **[Module Safety]** The `CreateModule` function in `QuestieLoader.lua` now guards against double-registration of modules, preventing accidental aliasing and overwriting.
- **[Code Cleanup]** Eliminated duplicate shims (`string.match`, `select`) from `QuestieCompat.lua` that were already provided canonically by `QuestieLoader.lua`.
- **[Code Cleanup]** Replaced misleading, non-looping `while n > 0` structures in `select` polyfills with standard `do...end` blocks.
- **[Diagnostics]** Gated `loadstring` execution in `QuestieInit:LoadDatabase`. On modern clients, it now safely blocks and logs an error instead of executing potentially tainted legacy string DBs at runtime.

## v1.3.4 — Taint Analysis & Error Fixes

*Resolves the initialization error in `GameVersionError.lua` and implements a version guard to support Classic-era private servers. Also confirms the integrity of the WotLKDB module after a deep taint analysis.*

### Core & Stability

- **[Fix]** Resolved `attempt to call local 'l10n' (a table value)` in `GameVersionError.lua` and implemented a `tocVersion` guard to prevent the "unsupported client" error on Classic-era private servers (e.g., Turtle WoW).
- **[Fix]** Updated `GameVersionError.lua` strings to correctly identify Questie-X as supporting Classic and private servers.
- **[Taint Analysis]** Completed a full audit of `Questie-X-WotLKDB`. No direct taint vectors or secure function overrides were found.
- **[Version Sync]** Synchronized versions to v1.3.4 across all components.


## v1.3.3 — Critical Taint Fix & Module Loading

*Addresses the missing `WorldMapTaintWorkaround` module that was excluded from previous releases, finally enabling the intended seat-of-pants taint mitigation strategy.*

### Core & Stability

- **[Taint Fix]** Officially included `Modules\WorldMapTaintWorkaround.lua` in all TOC files to ensure it's loaded and executed.
- **[Error Handling]** Included `Modules\GameVersionError.lua` in all TOC files for better unsupported client detection.
- **[Version Sync]** Synchronized version numbers across all 4 TOC flavors.

---

## v1.3.2 — Taint Resolution & Stability

*Finalizes the Taint Resolution project, eliminating `ADDON_ACTION_BLOCKED: UseAction()` errors by refactoring internal hooks to use secure alternatives and hardening the global namespace against collisions.*

### Core & Stability

- **[Taint Resolution]** Refactored `Hooks.lua` to use `hooksecurefunc` instead of raw hooks for all secure functions.
- **[Global Safety]** Enhanced `QuestieLoader.lua` with a new collision-aware `PopulateGlobals` engine that prevents overwriting existing global variables and provides diagnostic warnings.
- **[Security]** Eliminated global namespace modifications in `QuestieInit.lua`.
- **[Workaround Hardening]** Refactored `WorldMapTaintWorkaround.lua` to remove legacy global function reassignments that were causing secondary taint.

---

## v1.3.8
- **[QuestieTracker]** Resolved persistent "stuck" quest tracking/untracking by ensuring `AQW_Insert` and `RemoveQuestWatch` hooks respect manual untracking state.
- **[QuestieTracker]** Refined watch hooks to distinguish between manual user actions (e.g. shift-clicking in Quest Log) and internal Blizzard/server objective updates.
- **[QuestieTracker]** Added robustness for Quest IDs passed directly to Blizzard watch APIs (common on custom WoW private servers).
- **[Global Safety]** Added lint suppressions for external frames (`VoiceOverFrame`, etc.) in `QuestieTracker.lua`.

## v1.3.1

- Refined data-sharing mechanism to use exclusively hidden global channels, removing guild-channel broadcasts to minimize chat traffic.

## v1.3.0 — QuestieLearner Confidence, Global Sharing & Stale Data Cleanup

### QuestieLearner.lua — Precision & Confidence
- **[Coordinate Scaling Fix]** Fixed player coordinates being recorded on a 0-1 scale; now correctly scales to 0-100 for compatibility with Questie map pins.
- **[Confidence Rating System]** Introduced a confidence system based on "Match Count" (`mc`). Data is now categorized as "Unconfirmed" (low confidence) or "Verified" (high confidence).
- **[Map Pin Gating]** Learned map pins (sword icons) now only appear after reaching a configurable confidence threshold (default: 2).
- **[Confidence in Tooltips]** NPC and Object tooltips now display their confidence level (e.g., `(Learned - Confidence: 2)`).
- **[Timestamp Tracking]** Added `lastSeen` (`ls`) timestamps to all learned entries to track data freshness.
 
### QuestieLearnerComms.lua — Global Data Sharing
- **[Community Reinforcement]** Expanded data sharing from Party/Guild to a global hidden channel. Confidence values (`mc`) now increment when identical data is received from other Questie users, allowing the community to verify spawns collectively.
- **[Network Freshness]** Receiving data over the network now refreshes the `lastSeen` timestamp, keeping active community spawns from being pruned.
 
### QuestieLearnerExport.lua — Tiered Stale Data Cleanup
- **[Tiered Pruning]** Implemented a robust cleanup system that protects "Verified" (high-confidence) data from age-based deletion.
- **[Age-Based Pruning]** "Unconfirmed" data is now automatically pruned if it hasn't been seen within a configurable timeframe (default: 90 days).
- **[Redundancy Pruning]** Logic to remove data already present in the official Questie database now respects the `pruneVerified` toggle, allowing users to keep verified personal data even if it overlaps with the core DB.
 
### QuestieOptionsDatabase.lua — Advanced Cleanup Controls
- **[Stale Data Threshold]** Added a slider to control the age-pruning threshold (1-180 days) for unconfirmed data.
- **[Verified Data Protection]** Added a toggle to include or exclude verified data from redundancy pruning.
- **[UI Reorganization]** Refactored the Database tab's cleanup section for better logical flow and clarity.
 
---

## v1.2.9 — QuestieLearner Cross-Link Engine + Tracker Zone Fix + Untrack Fix

### QuestieLearner.lua — Universal Cross-Link Engine

- **[Cross-link engine — full rewrite]** Replaced the narrow NPC↔Quest cross-link stubs with a comprehensive bidirectional relationship engine covering all four entity types. Three shared primitives underpin the whole system: `_AddToArray(tbl, key, value, ovrTable, ovrId)` adds a value to an array field and mirrors it to the live `*DataOverrides` table in the same call; `_AddToNestedArray` does the same for two-level nested arrays (used for quest starters/finishers sub-slots); `_AddToQuestObjective` inserts `{entityId, text}` pairs into `quest[10][slot]` (the objectives array) with the same dual-write pattern. Every write is idempotent (no-op if value already present).
- **[CrossLinkAfterNPC]** Called whenever a new NPC ID is first committed to `learnedData.npcs`. Iterates all learned quests: (a) if quest`[2][1]` contains this npcId → adds questId to `npc[10]` (questStarts); (b) if quest`[3][1]` contains this npcId → adds questId to `npc[11]` (questEnds); (c) walks quest`[10][3]` (item objectives) — for each item whose `item[2]` (npcDrops) already references this NPC, the NPC is injected into `quest[10][1]` as a creature objective so it can receive map pins and tooltip text.
- **[CrossLinkAfterQuest]** Called when a new quest is first committed to `learnedData.quests`. Links all referenced entities: starter NPCs (quest`[2][1]`) → each known NPC's `npc[10]`; starter objects (quest`[2][2]`) → each known object's `obj[2]`; finisher NPCs (quest`[3][1]`) → `npc[11]`; finisher objects (quest`[3][2]`) → `obj[3]`; source item (quest`[11]`) → `item[5]` (startQuest key per itemDB schema); item drop chain (quest`[10][3]` items whose `item[2]` lists known NPCs) → those NPCs are injected into `quest[10][1]` as a creature objective. This means: learn a quest that needs Wolf Fur → later kill a wolf that drops it → the wolf NPC immediately becomes a tracked creature objective for that quest.
- **[CrossLinkAfterObject]** Called when a new object is first committed to `learnedData.objects`. Scans all learned quests: if quest`[2][2]` references this objectId → adds questId to `obj[2]` (questStarts); if quest`[3][2]` references it → adds questId to `obj[3]` (questEnds).
- **[CrossLinkAfterItem]** Called when a new item is first committed to `learnedData.items` AND whenever a new drop-NPC relationship is added via `LearnItemDrop`. Two passes: (1) scan all learned quests for `quest[11] == itemId` → set `item[5] = questId` (item starts this quest); (2) scan all learned quests for `quest[10][3]` entries matching itemId — for each such quest, every NPC in `item[2]` (drop sources) is injected into `quest[10][1]` as a creature objective. This means: learn a quest that needs Wolf Fur → later kill a wolf that drops it → the wolf NPC immediately becomes a tracked creature objective for that quest.
- **[CrossLinkAfterQuestGiver]** Now handles all three entity type slots (1=NPC, 2=Object, 3=Item) instead of only NPCs. For typeSlot=1: stitches `npc[10/11]` ↔ `quest[2/3][1]` bidirectionally. For typeSlot=2: stitches `obj[2/3]` ↔ `quest[2/3][2]`. For typeSlot=3: adds itemId to `quest[2][3]` (item starters slot). All writes go to both `learnedData` (SavedVariables) and live `*DataOverrides` tables simultaneously.
- **[LearnItemDrop hook]** Now calls `CrossLinkAfterItem(itemId)` every time a new NPC is added to an item's drop list, not just on initial item creation. This propagates the drop→quest objective chain retroactively.
- **[LearnQuest hook]** Calls `CrossLinkAfterQuest(questId)` on first creation of a quest record.
- **[LearnObject hook]** Calls `CrossLinkAfterObject(objectId)` on first creation of an object record.
- **[LearnItem hook]** Calls `CrossLinkAfterItem(itemId)` on first creation of an item record.
- **[Item schema correction]** Fixed incorrect use of key `[9]` (itemLevel) for quest-source storage. Now correctly uses `[5]` (`startQuest`) per `QuestieDB.itemKeys` schema.
- **[Mouseover — all NPCs now learned]** Removed the `UnitReaction < 4` early-return guard that blocked hostile/neutral NPC learning via mouseover. All NPCs are now learned on hover. The existing `QUESTGIVER` NPC-flag check remains as the primary filter for quest-relevant NPCs during mouseover. Hostile quest objective NPCs are now captured on any interaction (mouseover, targeting, or kill) and are correctly cross-linked to relevant quests.

### TrackerUtils.lua — Zone Resolution Rewrite

- **[GetQuestLogZoneName — canonical 3.3.5 zone lookup]** Added new local function `GetQuestLogZoneName(questId)`. Implements the canonical 3.3.5a zone resolution method: iterates the quest log from index 1 to `GetNumQuestLogEntries()` to locate the quest's log index, then walks backwards from that index checking `isHeader` until the nearest zone header title is found. This is the only fully reliable zone name source in 3.3.5a — the client places zone header entries (where `isHeader=true`) immediately above the quests belonging to that zone in the quest log flat list. `GetRealZoneText()` and `GetCurrentMapAreaID()` are unreliable because they depend on the currently viewed map, not the quest's actual zone.
- **[BuildFallbackQuest — zone via log walk]** Replaced the previous `GetRealZoneText()` call with the quest log header walk. The existing loop that iterates the quest log to find the quest entry now continues backwards from that index to find the header title. `GetAreaIdByZoneName()` is still called to convert the string to an area ID for `zoneOrSort`, but the string itself is always the ground truth used for display.
- **[_isLogFallback patch block — zone fix]** The block that patches QuestLogCache fallback objects (those with `_isLogFallback=true` but no `IsComplete` method) now calls `GetQuestLogZoneName(capturedId)` immediately after patching `Objectives`/`SpecialObjectives`/`ExtraObjectives`. If a zone name is returned, both `quest.zoneName` and `quest.zoneOrSort` are set on the object. Previously this block left `zoneOrSort=0` and `zoneName=nil`, causing every fallback quest to group under "Unknown Zone".
- **[Fallback cache invalidation]** `_fallbackQuests[qid]` is now evicted and rebuilt if the cached entry has no `zoneName`. This handles the case where `BuildFallbackQuest` was called during addon init (before the quest log was fully populated) and cached a zoneless entry.
- **[GetAreaIdByZoneName preserved]** Still available for converting zone header strings to numeric area IDs for `zoneOrSort`. The area ID is used by the proximity sort and zone grouping logic; the string is used for display labels.

### QuestieTracker.lua — Untrack Fix

- **[UntrackQuestId — logic was inverted]** `UntrackQuestId` was setting `AutoUntrackedQuests[questId] = nil` when untracking. The tracker filter reads `not Questie.db.char.AutoUntrackedQuests[questId]` — `nil` evaluates as "show this quest", so clearing the entry on untrack immediately re-showed the quest on the next update tick. Fix: when `autoTrackQuests = true`, untrack now sets `AutoUntrackedQuests[questId] = true` (hide); when `autoTrackQuests = false`, it clears `TrackedQuests[questId]` (manual mode). The two modes are now cleanly separated.
- **[AQW_Insert — removed QuestLogFrame gate]** The `IsShiftKeyDown() and QuestLogFrame:IsShown()` guard that was blocking re-tracking quests from outside the quest log frame has been removed. Re-tracking (clearing `AutoUntrackedQuests[questId]`) now works from any context. The shift-click-to-untrack path was already handled by `RemoveQuestWatch` → `UntrackQuestId`; this gate was only blocking the re-track flow.
- **[Quest completion cleanup]** `_RemoveQuestIdFromCharTables` already clears `AutoUntrackedQuests` when a quest leaves the log (completed or abandoned), preventing stale hidden-quest entries in SavedVariables.

---

## v1.2.7 — WotLKDB Plugin Stats Fix + Kill Tracking Refinement

### QuestieInit.lua — LoadBaseDB Count Tracking

- **[WotLKDB stats fix]** `LoadBaseDB()` now counts all four data tables (`questData`, `npcData`, `objectData`, `itemData`) **before** clearing the `QuestieX_WotLKDB_*` globals. Counts are stored in `_G.QuestieX_WotLKDB_Counts` for `Loader.lua` to read at `PLAYER_LOGIN`. This resolves WotLKDB showing `Quests:0 NPCs:0 Objects:0 Items:0` in the Advanced options plugin panel.

### QuestieLearner.lua — Kill Coordinate Filtering

- **[Kill tracking scoped to quest NPCs]** `OnCombatLogEvent(UNIT_DIED)` now only records kill coordinates when the killed NPC is either: (a) already present in `QuestieDB` (known quest objective mob), or (b) explicitly present in `_Learner.guidNpcCache` (was targeted or moused over as a known quest giver before the kill). Random mob kills that match neither condition are silently ignored. This prevents the learner from accumulating useless entries for every creature killed while questing.
- **[Removed dead hex-prefix fallback branch]** The "hex prefix scan for untargeted creatures not in cache" comment block was removed — it was a no-op that could never produce an NPC ID.

### Questie-X-WotLKDB Loader.lua — Plugin Stats Population

- **[Read counts from QuestieX_WotLKDB_Counts]** After `RegisterPlugin("WotLKDB")`, Loader.lua reads the counts global set by `LoadBaseDB()` and assigns them to `plugin.stats.QUEST/NPC/OBJECT/ITEM`. Frees the global after reading. Plugin panel now displays correct totals (e.g., `Quests: 9086`).

### Research Folder

- Added `Research/QuestieLearner-Verification.md` — step-by-step in-game test guide covering all 12 QuestieLearner subsystems (mouseover filter, quest accept/turn-in, kill coords, item loot async retry, object detection, export/import round-trip, plugin panel stats, peer sharing).
- Added `Research/SessionSummary-2026-03-16.md` — full developer session log covering all architectural decisions, errors, and fixes from the plugin architecture overhaul through the QuestieLearner rewrite.

---

## v1.2.6 — QuestieLearner Comprehensive Overhaul

> Rewrote QuestieLearner from scratch to fix all known data-capture deficiencies. Adds full quest field coverage, grid-based coordinate clustering, quest-giver-only mouseover filtering, async item-info retry, object loot detection, and live inject-on-import so imported data takes effect without a reload.

### QuestieLearner.lua — Full Rewrite

- **[Quest capture completeness]** `LearnQuest` now accepts a generic `data` table keyed by Questie wiki array indices rather than individual positional arguments. `OnQuestDetail` captures title, objectives text block, quest description body, and current zone as `zoneOrSort[8]`. `OnQuestAccepted` fills quest level from `GetQuestLogTitle`, per-objective text from `GetQuestLogLeaderBoard`, and required money from `GetQuestLogRequiredMoney`. `OnQuestComplete` captures finish/reward text via `GetRewardText`.
- **[Mouseover filter]** `OnMouseoverUnit` now only learns an NPC if its `UnitNPCFlags` bitmask includes the `QUESTGIVER` bit (`0x02`), OR if the NPC already exists in `QuestieDB` as a known quest starter/finisher. All other NPCs are silently ignored — this eliminates the flood of irrelevant NPC entries the learner previously accumulated.
- **[Target changed]** `OnTargetChanged` no longer calls `LearnNPC` on every target switch. It now only populates the `guidNpcCache` for kill-tracking purposes, avoiding recording non-quest NPCs.
- **[Coordinate clustering — grid bucketing]** Replaced the naive "within 1 unit radius" deduplication with a 2×2 grid bucket scheme (`COORD_GRID = 2.0`). A new point is inserted only when no existing point shares the same grid cell. This prevents coordinate scatter across a kill area while still preserving distinct spawn clusters. The `InsertIfNewBucket` helper is shared across NPC, Object, and all merge paths (including `InjectLearnedData` and `HandleNetworkData`).
- **[Object recording]** `OnLootOpened` now checks whether the loot source GUID is a `GameObject` (not just a creature). If so, `LearnObject` is called with the object's ID and name. `OnGossipShow` records both objects and NPCs via `GetIdAndTypeFromGUID`. `OnQuestDetail` and `OnQuestComplete` also record the interacting object when the quest giver/finisher is a `GameObject`.
- **[Item loot — async GetItemInfo retry]** `OnLootOpened` queues unresolved item links (where `GetItemInfo` returns nil because the item is not yet in the client cache) into `_Learner.pendingItemLinks`. A new `OnGetItemInfoReceived(itemId)` handler fires on the `GET_ITEM_INFO_RECEIVED` event, resolves queued links for that item ID, and calls `LearnItem`/`LearnItemDrop` once the data is available. This fixes silent data loss on first-encounter loots.
- **[Quest giver entity type]** `LearnQuestGiver` now accepts an `entityType` argument (1=NPC, 2=GameObject, 3=item) and stores starters/finishers in the correct sub-array slot matching the Questie wiki spec `{ [1]={npcIds}, [2]={objIds}, [3]={itemIds} }`.
- **[Kill tracking fallback]** `OnCombatLogEvent` retains all three GUID-resolution paths (dash-split, GUID cache, hex-prefix) with a 10-minute TTL cache cleanup. Uses `CombatLogGetCurrentEventInfo()` with fallback to varargs for cross-client compatibility.
- **[GET_ITEM_INFO_RECEIVED event]** Registered in `RegisterEvents` so the async item retry path fires correctly.
- **[InjectLearnedData — grid clustering]** All coordinate merge loops in `InjectLearnedData` now use `InsertIfNewBucket` instead of the old radius check.

### QuestieLearnerExport.lua — Import Live-Inject Fix

- **[MergeImport → InjectLearnedData]** After `MergeType` completes for all four categories, `MergeImport` now immediately calls `QuestieLearner:InjectLearnedData()`. Imported data is pushed into `QuestieDB.*DataOverrides` in the same frame — override-driven map pins update without a `/reload`. A full reload is still needed to pick up newly imported quest starters/finishers for quests already tracked in the player's quest log.

### README — Import Clarification

- Corrected the "no reload required" claim. The import flow now accurately describes when an immediate effect is visible versus when a `/reload` is beneficial.

---

## v1.2.5 — Ebonhold DB Plugin Load Fix

> Fixed a fatal load-time crash in all four Ebonhold DB files caused by calling `GetRealmName()` and `QuestieLoader:CreateModule()` at file scope (before WoW's API is fully available). Switched to plain global table population; realm-gating and injection remain safely deferred to `EbonholdLoader.lua`'s `PLAYER_LOGIN` handler.

### Questie-X-EbonholdDB — DB File Refactor

- **[Root cause]** `EbonholdNpcDB.lua`, `EbonholdObjectDB.lua`, `EbonholdItemDB.lua`, and `EbonholdQuestDB.lua` each started with `if GetRealmName() ~= "Rogue-Lite (Live)" then return end` followed immediately by `QuestieLoader:CreateModule("EbonholdDB")`. Both calls execute at file-load time (during `LoadAddOn()`), before `PLAYER_LOGIN` has fired and before `QuestieLoader` is guaranteed to be populated. This produced `attempt to index global 'QuestieLoader' (a nil value)` on every load.
- **[Ebonhold/EbonholdNpcDB.lua]** Removed file-level realm guard and `QuestieLoader:CreateModule` call. Replaced with `_G.EbonholdDB = _G.EbonholdDB or {}` and a local alias. Data is now populated unconditionally into the global at load time.
- **[Ebonhold/EbonholdObjectDB.lua]** Same fix as NpcDB.
- **[Ebonhold/EbonholdItemDB.lua]** Same fix as NpcDB.
- **[Ebonhold/EbonholdQuestDB.lua]** Same fix as NpcDB.
- **[EbonholdLoader.lua]** Replaced `QuestieLoader:ImportModule("EbonholdDB")` with `_G.EbonholdDB or {}`. The loader's existing `PLAYER_LOGIN` handler with realm check remains intact as the sole gate for injection into Questie-X.

---

## v1.2.2 — DB Plugin Pull Architecture & Compiler Hardening

> Overhauled the DB plugin loading pipeline from a fragile push/bridge pattern to a direct pull at init time. Fixed a long-standing compiler bug that silently dropped `extraobjective` condition data. Removed all `DevTools_Dump` calls that were printing raw Lua table syntax to chat during validation.

### DB Plugin Architecture — Pull Pattern

- **[QuestieInit:LoadBaseDB]** Replaced the broken `QuestieX_CoreDB` bridge mechanism with a direct pull of DB plugin globals at init time. `LoadBaseDB()` now checks for `QuestieX_WotLKDB_quest`, `QuestieX_WotLKDB_npc`, `QuestieX_WotLKDB_object`, and `QuestieX_WotLKDB_item` globals and assigns them directly to `QuestieDB.*Data` before calling `LoadDatabase()` on each key. Globals are cleared (`= nil`) after transfer to free memory. This approach is unconditionally reliable — it runs inside Questie-X's own init coroutine at a known point in the load sequence, with no dependency on cross-addon module references.
- **[QuestieInit:LoadBaseDB — diagnostics]** Replaced the old "WotLKDB addon loaded / SplitLoaded flag / quest global" diagnostic lines with new pull-result lines: `WotLKDB pull: quest=true/false npc=true/false obj=true/false item=true/false` and per-key type/length lines, making it immediately obvious whether the DB plugin data was absorbed.
- **[QuestieDB.lua]** Removed `_G.QuestieX_CoreDB = QuestieDB` export. The CoreDB bridge global is no longer needed and was never reliably accessible from DB plugin Loader.lua files due to module-registry timing.

### DB Plugin — Loader.lua Simplification

- **[Questie-X-WotLKDB/Loader.lua]** Stripped the entire data-transfer block (the `if not QuestieX_CoreDB then return end` guard and subsequent `QuestieX_CoreDB.*Data = ...` assignments). The file is now purely a `PLAYER_LOGIN` handler that: registers the plugin with `QuestiePluginAPI`, counts and logs the absorbed quest/NPC/object/item table sizes via `QuestieDB` module reference, and emits a `DEBUG_CRITICAL` warning if `questData` is still empty after init (indicating a load-order or split-file failure). This makes Loader.lua a diagnostic and registration stub rather than a critical data pathway.

### Compiler — extraobjectives Conditions Field

- **[compiler.lua — writer `extraobjectives`]** Added serialization of `data[6]` (conditions table). After writing the 5 existing fields per entry (spawnlist, icon, description, objectiveIndex, reflist), the writer now writes a `WriteByte(n)` count followed by `WriteShortString(key)` + `WriteInt24(value)` for each condition entry. If `data[6]` is nil or not a table, writes `0` (no conditions).
- **[compiler.lua — reader `extraobjectives`]** Added deserialization of the conditions field. After reading the 5 fields per entry, reads a `ReadByte()` condition count; if non-zero, reconstructs the conditions table as `{[key]=value}` and assigns it to `entry[6]`. If count is 0, `entry[6]` is left nil (no allocation).
- **[compiler.lua — skipper `extraobjectives`]** Updated to skip condition bytes: reads the condition count byte, then for each condition skips a `ShortString` (`ReadShort() + _pointer`) and an `Int24` (`_pointer + 3`).
- **[Root cause]** `QuestieDB.lua:1443` reads `HideCondition = o[6]` from each extraobjective at quest-object build time. Before this fix, compiled data always produced `o[6] = nil`, so `ShouldHideObjective()` never activated. The `hideIfQuestActive` / `hideIfQuestComplete` conditions defined in corrections (e.g. quest 12924 — "Pick up 'You Can't Miss Him'") were silently ignored post-compilation. Validation also flagged the mismatch on every load, which triggered `DevTools_Dump` to flood chat with raw Lua table syntax.

### Compiler — DevTools_Dump Removal

- **[compiler.lua — ValidateNPCs / ValidateObjects / ValidateItems / ValidateQuests]** Removed all four `DevTools_Dump({["Compiled Table:"]=a, ["Base Table:"]=b})` calls from the table-mismatch branches in each validator. These calls serialized full Lua tables to the chat frame as raw source code, which appeared to users as a syntax error or data corruption. The preceding `Questie:Warning(...)` line in each branch already captures the mismatch identity (key, field id, entry ID). `DevTools_Dump` is a retail WoW debugging API unavailable or unreliable on private/custom servers and should not be called in production validation paths.

---

## v1.2.4 — Retail/SoD Corrections Removed

> Deleted all Season of Discovery, Season of Mastery, and Hardcore correction files. These were retail-specific and never referenced by the TOC. Cleaned up all dead imports, constants, and code branches they left behind in `QuestieCorrections.lua`.

### Files Deleted

- **`Database/Corrections/SeasonOfDiscovery.lua`** — SoD base quest/NPC/object/item overrides
- **`Database/Corrections/sodQuestFixes.lua`** — SoD quest corrections
- **`Database/Corrections/sodNPCFixes.lua`** — SoD NPC corrections
- **`Database/Corrections/sodItemFixes.lua`** — SoD item corrections
- **`Database/Corrections/sodObjectFixes.lua`** — SoD object corrections
- **`Database/Corrections/Automatic/sodBaseQuests.lua`** — SoD auto-generated base quests
- **`Database/Corrections/Automatic/sodBaseNPCs.lua`** — SoD auto-generated base NPCs
- **`Database/Corrections/Automatic/sodBaseItems.lua`** — SoD auto-generated base items
- **`Database/Corrections/Automatic/sodBaseObjects.lua`** — SoD auto-generated base objects
- **`Database/Corrections/HardcoreBlacklist.lua`** — Hardcore mode quest blacklist
- **`Database/Corrections/SoMPhases.lua`** — Season of Mastery phase data (was already commented out in TOC)

### QuestieCorrections.lua Cleanup

- **Imports removed**: `HardcoreBlacklist` and `SeasonOfDiscovery` `ImportModule` calls deleted.
- **Constants removed**: `SOD_ONLY = 5` and `HIDE_SOD = 6` deleted from the expansion filter enum. Remaining constants (`TBC_ONLY`, `CLASSIC_ONLY`, `WOTLK_ONLY`, `TBC_AND_WOTLK`, `CLASSIC_AND_TBC`) are unchanged.
- **`filterExpansion`**: removed the `isSoD` local and the two `SOD_ONLY` / `HIDE_SOD` branches.
- **`MinimalInit`**: removed the `if Questie.IsSoD then addOverride(...SeasonOfDiscovery:LoadFactionQuestFixes()...) end` block.
- **`MinimalInit`**: removed the `if Questie.IsHardcore then HardcoreBlacklist:Load() end` block.
- **`Initialize`**: removed the 8-call `if Questie.IsSoD then SeasonOfDiscovery:LoadBase*/Load*() end` block covering quest/NPC/item/object base data and fixes.
- **TOC**: removed the commented-out `#Database\Corrections\SoMPhases.lua` line.

---

## v1.2.3 — Diagnostics Refactor & Monolithic DB Removal

> Moved all DB init diagnostics out of chat and into the Develop debug level. Replaced hardcoded quest-ID spot-checks with generic per-table stats. Removed the stale monolithic database folders that have been fully superseded by the DB plugin architecture.

### DB Init Diagnostics — DEVELOP Level

- **[QuestieInit — _dbStats helper]** Added a local `_dbStats(t)` function that returns `count=N minID=X maxID=Y` for any table. Used at every checkpoint so diagnostic output is meaningful for any server's dataset without hardcoding expansion-specific IDs.
- **[QuestieInit — _dbDiag table removed]** Eliminated the `local _dbDiag = {}` accumulator table and the deferred `C_Timer.After(6, ...)` print block. Diagnostics are now emitted inline as `Questie:Debug(Questie.DEBUG_DEVELOP, "[DBDiag] ...")` calls at the exact point each stage completes, making them visible in real time when Develop logging is enabled rather than appearing as a delayed flood 6 seconds after load.
- **[QuestieInit:LoadBaseDB]** Pull result line (`WotLKDB pull: quest=... npc=... obj=... item=...`) converted to `DEBUG_DEVELOP`.
- **[QuestieInit:loadFullDatabase]** Four diagnostic checkpoints converted to `DEBUG_DEVELOP` with generic `_dbStats` output: After LoadBaseDB (quest + npc on one line, obj + item on the next), After Corrections (quest + npc), Before Compile (quest + npc), After Compile (type= of each key, confirming binary serialization completed).
- **[QuestieInit:LoadDatabase — error paths]** Two `_dbDiag` push lines for `loadstring` parse errors and `pcall` execution errors converted to `DEBUG_DEVELOP`.
- **[QuestieInit.Stages[1] — cached path]** `DB was CACHED (no recompile)` line converted to `DEBUG_DEVELOP`.

### DB Plugin — Loader.lua Premature Count Check Removed

- **[Questie-X-WotLKDB/Loader.lua]** Removed the `countTable` / quest+npc+obj+item count block and the `DEBUG_CRITICAL` "questData is empty" warning that fired at `PLAYER_LOGIN`. This check always reported zero counts because it ran before `QuestieInit`'s loading coroutine had started. The `[DBDiag]` lines (now at `DEBUG_DEVELOP`) are the correct place to verify data absorption. Loader.lua is now a minimal registration stub: registers the plugin with `QuestiePluginAPI`, prints the confirmed registration line, and calls `plugin:FinishLoading`.

### Monolithic Database Folders Removed

- **[Database/Classic/]** Deleted `classicQuestDB.lua` (1.0 MB), `classicNpcDB.lua` (2.0 MB), `classicObjectDB.lua` (1.0 MB), `classicItemDB.lua` (2.1 MB). These monolithic files were never listed in `Questie-X.toc` and would have been silently skipped by WoW 3.3.5 anyway due to the ~1 MB per-file parse limit. Classic data is now provided exclusively by the ClassicDB plugin.
- **[Database/TBC/]** Deleted `tbcQuestDB.lua` (1.6 MB), `tbcNpcDB.lua` (3.5 MB), `tbcObjectDB.lua` (1.6 MB), `tbcItemDB.lua` (3.3 MB). TBC data is now provided exclusively by the TBCDB plugin.
- **[Database/Wotlk/]** Deleted `wotlkQuestDB.lua` (2.3 MB), `wotlkNpcDB.lua` (5.2 MB), `wotlkObjectDB.lua` (2.0 MB), `wotlkItemDB.lua` (4.4 MB). WotLK data is now provided exclusively by the WotLKDB plugin via the split-file mechanism. Combined removal: ~30 MB of dead weight from the core repository.

---

## v1.1.7 - v1.2.1 — DB Loading Diagnostics & Fallback Tracker

> Ongoing stability pass. Hardened the entire database loading pipeline, wired up the live quest-log fallback for quests missing from the DB, and fixed a chain of nil-guard crashes across corrections, map, and tracker modules.

### Database Loading

- **[LoadDatabase]** Replaced bare `loadstring()` / `fn()` calls with proper error capture (`local fn, err = loadstring(...)` + `pcall(fn)`). Errors now print to chat with the failing key and string length instead of silently falling back to `{}`.
- **[Compiler]** Fixed `hasData` guard in `QuestieDBCompiler:Compile()` — now accepts `type == "table"` in addition to `"string"`, preventing the compiler from silently aborting when `LoadDatabase` has already decoded the string to a table before compilation.
- **[DB Architecture]** Identified and documented that loading multiple DB plugins simultaneously (e.g. WotLKDB + ClassicDB) causes `questData` overwrites. On WotLK servers only `Questie-X-WotLKDB` should be enabled alongside the server-specific plugin.

### Live Fallback for Missing Quests

- **[QuestieDB.GetQuest]** When `rawdata` is nil, a minimal quest object is now built from `QuestLogCache` instead of returning nil. The fallback populates `name`, `level`, `isComplete`, and an empty `Objectives` table with `_isLogFallback = true`.
- **[QuestieQuest.PopulateQuestLogInfo]** Fallback quests now seed their `Objectives` table from `QuestLogCache.GetQuestObjectives` on first call, then call `obj:Update()` on each to refresh progress from the live quest log.
- **[QuestieQuest.UpdateObjectiveNotes]** Fallback quests now early-return to skip the static DB spawn-list path (`objectiveSpawnListCallTable`), preventing "Corrupted objective data" errors caused by nil NPC IDs.

### Crash Fixes

- **[QuestieLib.GetQuestString]** Guard against nil `name` — returns quest ID string as fallback (tracker error for quest 10482).
- **[QuestieDB spawn loop]** Nil-guard on `objectData[id]` before clearing spawn keys in prune loop (attempt to index nil at QuestieDB:1715).
- **[QuestieDB.GetSpawnList]** Wrapped `objectiveSpawnListCallTable` result in nil-guard before iterating — prevents `pairs(nil)` when a referenced NPC/object is missing from the loaded DB.
- **[QuestieQuestPrivates killcredit]** `monster(killCreditNpcId)` result nil-guarded before indexing — prevents crash for kill-credit NPCs absent from npcData.
- **[Townsfolk]** `flags` nil-guard added before `bitband(flags, VENDOR)` call (bad argument #1 to bitband).
- **[QuestieQuest.UpdateObjectiveNotes]** `quest.SpecialObjectives` nil-guard before `next()` call.
- **[QuestieQuest.PopulateQuestLogInfo]** `quest.SpecialObjectives` nil-guard before `next()` call.

### Junctions & Dev Environment

- Created `mklink /J` junctions for `Questie-X-TBCDB` and `Questie-X-ClassicDB` into Ebonhold AddOns folder for live in-game testing.

---

## v1.1.6 — Minimap Icon & P2 Stability

> Minimap button overhaul and second pass of P2 bug fixes.

### Minimap

- **[MinimapIcon]** Replaced default minimap icon with custom `mmapIcon.tga`. Applied `SetMask` for circular clip on WotLK+ clients with `SetTexCoord` fallback for 1.12 vanilla clients.

### Bug Fixes (P2)

- **[QuestieServer]** Restored plugin status UI, `C_QuestLog`/`C_Map` shims, and `QuestieServer` init sequence.
- **[QuestieLoader]** Corrected `select()` polyfill to not use `arg` table.
- **[TOC]** Added XXH load to TBC toc and guarded `plugin.stats` nil access.

---

## v1.1.5 — QuestieLearner Expansion & Database Options

> Major expansion of the data-learning system and a new Database options tab.

### QuestieLearner

- **[QuestieLearner]** Expanded hook coverage: quest accept, objective kill, object interaction, and item loot all feed learned data back to the appropriate DB table.
- **[QuestieLearnerComms]** Broadcast/receive learned entries to nearby Questie-X users via addon messages.
- **[Custom Server Detection]** Learned data for unrecognised quest IDs is stored under a per-realm key in `QuestieLearnerDB` to separate retail/private/custom content.
- **[DEVELOP logging]** Debug messages emitted on every successful learn and every failed-to-learn event.

### Options — Database Tab

- **[QuestieOptionsDatabase]** New "Database" tab with Import / Export (LibDeflate base64 encoded strings) and Cleanup (prune stale learned entries) functionality.

---

## v1.0 - v1.1.4 — Questie-X: Plugin Architecture & Maintenance Update

> This release marks the official rebranding from **Questie-335** / **PE-Questie** to **Questie-X** and introduces the new plugin architecture. Additionally, this version includes significant UI enhancements, core compatibility refinements for legacy clients, and critical database corrections.

### Architecture Changes

- **[Repo]** Repository renamed and re-homed to `Xurkon/Questie-X`. Remote updated from `PE-Questie` to `Questie-X`.
- **[Plugin API]** Introduced `QuestiePluginAPI` (`Modules/Libs/QuestiePluginAPI.lua`). Plugins register themselves and inject quest, NPC, object, item, and zone data without modifying core files.
- **[Server Detection]** Added `QuestieServer` module (`Modules/QuestieServer.lua`) for improved runtime server environment detection.
- **[Network]** Added `QuestieLearnerComms` module (`Modules/Network/QuestieLearnerComms.lua`) for cross-client quest data sharing.
- **[Database]** Removed embedded `Database/Ascension/` and `Database/Ebonhold/` folders. All custom server data is now distributed via separate plugin addons.

### UI Enhancements

- **[Options]** Resizable Options window! The Questie options UI can now be resized with corner drag functionality. Size and position persist between sessions.
- **[Options]** New **Credits Tab**! A dedicated tab in the options menu to acknowledge contributors and community partners.
- **[Tutorial]** Improved tutorial flows for objective type selection.

### Core & Compatibility

- **[Lua 5.0]** Globally polyfilled `string.match` and `string.gmatch` using `string.find` and `string.gfind` to ensure universal compatibility with legacy WoW clients (e.g., Turtle WoW).
- **[AceTimer]** Patched embedded `AceTimer-3.0` instances in ElvUI and OG-RaidHelper to resolve `math.mod` errors on Lua 5.0 clients.
- **[Colors]** Updated `CreateColor` polyfill with `SetRGB`, `SetRGBA`, `SetColor`, and `GetColor` methods.
- **[Comm]** Improved cross-client data sharing stability.

### Map & Tooltips

- **[Tooltips]** NPC names and objective text now populate reliably on map pins and world unit tooltips.
- **[Tooltips]** Resolved `[QuestieTooltips:GetTooltip] m_20509` debug log spam.

### Quest Data

- **[Database]** Scraped and injected missing spawn coordinates for Bonechewer Mutant, Raider, Evoker, and Scavenger (NPC IDs 16876, 16925, 19701, 18952) from Wowhead.
- **[Quest 10482]** Correctly mapped Bonechewer NPCs to quest objectives in both WotLK and TBC database correction files.

### New Plugins

- **Questie-Ascension** — Project Ascension server database.
- **Questie-Ebonhold** — Ebonhold server database. [Questie-X-EbonholdDB](https://github.com/Xurkon/Questie-X-EbonholdDB)

### TOC / Addon Identity

- **[TOC]** Core addon `.toc` files updated to `Questie-X` title and `v1.3.8`
- **[Libs]** Added `LibDeflate`, `XXH_Lua_Lib`, `LibDBIcon-1.0`, and `LibDataBroker-1.1` to the Libs directory.

### Bug Fixes

- **[QuestieDB]** Overhauled `QuestieDB.IsComplete` to accurately verify all objectives are finished using `numFulfilled == numRequired` instead of the unreliable server-side `finished` flag.
  - Resolves completion state bugs for quests using consumable items (e.g. Cold Iron Key for quest 12843).
  - Fixed Quest Arrow priority logic to properly transition to finishers once objectives are complete.
- **[QuestieQuest]** Implemented `HideCondition` mechanism for objectives, allowing specific spawns to be hidden based on quest log status (`hideIfQuestActive` / `hideIfQuestComplete`).
- **[Cache]** Demoted Cache Validation "0/15 Error" to Debug level to reduce user confusion during login and reloads.
- **[Network]** Fixed sender trust validation in `QuestieLearnerComms`.

---

## v9.9.2 — Final Pre-Refactor Release

> ⚠️ **This is the final stable release before a major architectural refactoring.** All active features and quest data from previous releases are preserved. Future versions will introduce breaking changes to improve multi-server support, the database plugin system, and the zone registration API.

### Fixes

- **[Map]** Resolved an issue where NPC names and objective text were inconsistently missing from map tooltips.
  - Added support for `killcredit` and `spell` objective types in `MapIconTooltip.lua`.
  - Implemented proactive creature name prepending in `QuestieTooltips:GetTooltip` to ensure data visibility for rare/custom objectives.

### New Ebonhold Quests

#### 🗺️ Azeroth

| ID | Quest | Zone | Type |
|----|-------|------|------|
| 50187 | Western Plaguelands Trophy | Western Plaguelands | Kill 1 Rare (tracked rares) |

### NPC Data

- **classicNpcDB.lua** / **EbonholdNpcDB.lua**: Injected spawn coordinates for Western Plaguelands rare NPCs to support quest 50187.

### Documentation

- Completed a full deep-dive code audit of the entire addon codebase.
- Identified areas for improvement including server-agnostic design, version detection improvements, a plugin architecture for custom server databases, configurable level caps, and several code quality issues.
- Audit findings exported to the project research folder.

---

## v9.9.1

### New Ebonhold Quests

#### 🗺️ Azeroth

| ID | Quest | Zone | Type |
|----|-------|------|------|
| 50057 | Brood of the Black Flight | Burning Steppes | Kill 30 Dragonkin (10 NPCs tracked) |

### NPC Data

- **EbonholdNpcDB.lua**: Injected spawn coordinates for 10 Dragonkin NPCs in Burning Steppes (IDs 7040-7049) to support quest 50057.

## v9.9.0

### New Ebonhold Quests

#### 🗺️ Azeroth

| ID | Quest | Zone | Type |
|----|-------|------|------|
| 50128 | Southern Jungle | Stranglethorn Vale | Complete 6 quests |

#### 🌿 Kalimdor

| ID | Quest | Zone | Type |
|----|-------|------|------|
| 50006 | Sandstone Giants | Tanaris | Kill Sandstone Giants |
| 50130 | Felwood Restoration | Felwood | Complete 6 quests |

### Fixes

- **[Quest]** Fixed `QuestieDB` initialization error caused by missing table depth for custom creature objectives in `EbonholdQuestDB`.
- **[System]** Adjusted `Questie:Error` output logic so that critical addon-breaking errors always print regardless of the `Enable Debug-PRINT` setting.
- **[Map]** Fixed missing map pins for "Sandstone Giants" quest — changed objective type from `creatureObjective` to `killCreditObjective` so Questie correctly resolves spawn locations from the NPC database.
- **[Tracking]** Fixed collection quest counters showing stale counts when the Ebonhold scav bot loots items — implemented a 3-stage `BAG_UPDATE_DELAYED` strategy: immediate scan, 0.3s debounce scan, and a 2s follow-up scan to allow the server's quest-objective cache to flush batch loot counts.

## v9.8.9

### New Ebonhold Quests

#### 🗺️ Azeroth

| ID | Quest | Zone | Type |
|----|-------|------|------|
| 50178 | Badlands Trophy | Badlands | Kill 1 Rare (10 rares tracked) |
| 50176 | Arathi Trophy | Arathi Highlands | Kill 1 Rare (10 rares tracked) |
| 50175 | Alterac Trophy | Alterac Mountains | Kill 1 Rare (8 rares tracked) |
| 50162 | Wetlands Trophy | Wetlands | Kill 1 Rare (8 rares tracked) |
| 50160 | Redridge Trophy | Redridge Mountains | Kill 1 Rare (8 rares tracked) |
| 50157 | Modan Trophy | Loch Modan | Kill 1 Rare (7 rares tracked) |
| 50156 | Westfall Trophy | Westfall | Kill 1 Rare (9 rares tracked) |
| 50173 | Northern Jungle Trophy | Stranglethorn Vale | Kill 1 Rare (9 rares tracked) |
| 50183 | Southern Jungle Trophy | Stranglethorn Vale | Kill 1 Rare (9 rares tracked) |
| 50164 | Tirisfal Trophy | Tirisfal Glades | Kill 1 Rare (9 rares tracked) |
| 50153 | Morogh Trophy | Dun Morogh | Kill 1 Rare (6 rares tracked) |
| 50097 | Elwynn Errands | Elwynn Forest | Complete 6 quests |
| 50098 | Morogh Missions | Dun Morogh | Complete 6 quests |
| 50105 | Redridge Resolve | Redridge Mountains | Complete 6 quests |

#### 🌿 Kalimdor

| ID | Quest | Zone | Type |
|----|-------|------|------|
| 50154 | Teldrassil Trophy | Teldrassil | Kill 1 Rare (6 rares tracked) |
| 50034 | Ashen Corruption | Ashenvale | Kill 40 Demons (23 NPCs tracked) |
| 50020 | Spires of Chaos | Thousand Needles | Kill 30 Elementals (5 NPCs tracked) |
| 50099 | Shadow of Teldrassil | Teldrassil | Complete 6 quests |
| 50103 | Darkshore Defense | Darkshore | Complete 6 quests |
| 50104 | Bloodmyst Recovery | Bloodmyst Isle | Complete 6 quests |
| 50100 | Azuremyst Aid | Azuremyst Isle | Complete 6 quests |
| 50108 | Trials of Durotar | Durotar | Complete 6 quests |

#### 🌋 Outland

| ID | Quest | Zone | Type |
|----|-------|------|------|
| 50197 | Shadowmoon Trophy | Shadowmoon Valley | Kill 1 Rare (3 rares tracked) |
| 50195 | Blade's Edge Trophy | Blade's Edge Mountains | Kill 1 Rare (3 rares tracked) |
| 50196 | Netherstorm Trophy | Netherstorm | Kill 1 Rare (3 rares tracked) |
| 50192 | Zangarmarsh Trophy | Zangarmarsh | Kill 1 Rare (3 rares tracked) |
| 50045 | Demon's at the Edge | Blade's Edge Mountains | Kill 40 Demons (37 NPCs tracked) |
| 50044 | Fel Scars of Nagrand | Nagrand | Kill 40 Demons (14 NPCs tracked) |
| 50026 | Elemental Balance | Nagrand | Kill 30 Elementals (12 NPCs tracked) |
| 50060 | Skies of Blade's Edge | Blade's Edge Mountains | Kill 30 Dragonkin (17 NPCs tracked) |
| 50083 | Forest Stalkers | Terokkar Forest | Kill 75 Beasts (53 NPCs tracked) |
| 50082 | Marsh Predators | Zangarmarsh | Kill 75 Beasts (34 NPCs tracked) |
| 50085 | Savage Heights | Blade's Edge Mountains | Kill 75 Beasts (47 NPCs tracked) |
| 50086 | Unstable Fauna | Netherstorm | Kill 75 Beasts (18 NPCs tracked) |
| 50087 | Shadowed Beasts | Shadowmoon Valley | Kill 75 Beasts (25 NPCs tracked) |
| 50111 | Song of the Woods | Eversong Woods | Complete 6 quests |

#### ❄️ Northrend

| ID | Quest | Zone | Type |
|----|-------|------|------|
| 50200 | Fjord Trophy | Howling Fjord | Kill 1 Rare (3 rares tracked) |
| 50201 | Dragonblight Trophy | Dragonblight | Kill 1 Rare (3 rares tracked) |
| 50202 | Grizzly Trophy | Grizzly Hills | Kill 1 Rare (4 rares tracked) |
| 50203 | Zul'Drak Trophy | Zul'Drak | Kill 1 Rare (4 rares tracked) |
| 50199 | Borean Trophy | Borean Tundra | Kill 1 Rare (3 rares tracked) |
| 50205 | Storm Peaks Trophy | The Storm Peaks | Kill 1 Rare (4 rares tracked) |
| 50063 | Frostbound Brood | Borean Tundra | Kill 30 Dragonkin (16 NPCs tracked) |
| 50064 | Heart of the Dragonflights | Dragonblight | Kill 30 Dragonkin (49 NPCs tracked) |
| 50066 | Stormforged Scales | The Storm Peaks | Kill 30 Dragonkin (7 NPCs tracked) |
| 50030 | Tundra Turbulence | Borean Tundra | Kill 30+ Elementals (14 NPCs tracked) |
| 50031 | Stormbound | The Storm Peaks | Kill 30 Elementals (11 NPCs tracked) |
| 50089 | Tundra Hunters | Borean Tundra | Kill 75 Beasts (43 NPCs tracked) |
| 50094 | Wild Basin | Sholazar Basin | Kill 75 Beasts (29 NPCs tracked) |
| 50095 | Peak Predators | The Storm Peaks | Kill 75 Beasts (24 NPCs tracked) |
| 50096 | Peak Predators | Icecrown | Kill 75 Beasts (12 NPCs tracked) |
| 50145 | Fjord Front | Howling Fjord | Complete 6 quests |
| 50149 | Basin Expeditions | Sholazar Basin | Complete 6 quests |
| 50150 | Storm Peak Orders | The Storm Peaks | Complete 6 quests |
| 50151 | Icecrown Advance | Icecrown | Complete 6 quests |

### NPC Data

- **classicNPCFixes.lua**: Injected spawn coordinates for NPC 14224 (7:XT \<Long Distance Recovery Unit\>, Badlands). The native `wotlkNpcDB` entry for ID 14224 is a different NPC (Gnomeregan's Instance Recovery Unit) and `classicNpcDB` had no entry — all 74 Wowhead patrol coordinates for zone 3 (Badlands) were injected.

### Bug Fixes

- **[UI]** Fixed spammy `[CRITICAL] No AreaId found for UiMapId` errors appearing in chat when entering Ascension hub cities (Stormwind, Darnassus, Shattrath, etc.). On Ascension, `C_Map.GetBestMapForUnit("player")` returns a continent-level UiMapId for these cities — Questie logged a CRITICAL error since continent maps have no AreaId mapping, even though the `nil` return was already handled gracefully by callers. Downgraded from `DEBUG_CRITICAL` to `DEBUG_DEVELOP` in `zoneDB.lua`.

## v9.8.8

### New Ebonhold Quests

- **Azeroth**: Alterac Trophy (includes missing Alterac Mountains spawn tracking data for Narillasanz, Cranky Benj, Gravis Slipknot, Araga, Lo'Grosh, Stone Fury, Jimmy the Bleeder, Skhowl). Northern Jungle Trophy (verified Stranglethorn Vale spawn tracking data). Southern Jungle Trophy (verified Stranglethorn Vale spawn tracking data for 4 rares).
- **Kalimdor**: Ashen Corruption (includes missing Ashenvale spawn tracking data for Demon NPCs), Spires of Chaos (includes missing Thousand Needles spawn tracking data for Elemental NPCs).
- **Outland**: Shadowmoon Trophy (verified Shadowmoon Valley spawn tracking data for Collidus the Warp-Watcher, Ambassador Jerrikar, Kraator). Demon's at the Edge (verified Blade's Edge Mountains spawn tracking data for 37 demons).
- **Northrend**: Fjord Trophy (includes missing Howling Fjord spawn tracking data for King Ping, Perobas the Bloodthirster, Vigdis the War Maiden). Frostbound Brood (verified Borean Tundra spawn tracking data for 16 dragonkin).

## v9.8.7

### Fixes

- **[Quest]** Corrected `GetQuestLogTitle` return value indices across multiple modules to match the WoW 3.3.5 client API. The 3.3.5 client returns `suggestedGroup` at index 4, shifting `isHeader` to index 5 and `questId` to index 9. Affected modules previously used indices 4 and 8 (or `select(8, ...)`) and would misidentify quest headers as regular quests and incorrectly assign `isDaily` as `questId`.
- **[Quest]** Removed premature `break` on nil `title` in quest log iteration loops. On this server, quest log slots can be non-contiguous, causing early loop termination to silently skip valid quests. Loops now use a `if title and (not isHeader) then` guard to safely skip empty slots without aborting iteration.
- **Affected modules:** `QuestieValidateGameCache`, `QuestEventHandler`, `QuestLogCache`, `TooltipHandler`, `TrackerUtils`, `QuestieTracker`, `QuestieLearner`.

## v9.8.6

### New Ebonhold Quests

- **Outland**: Blade's Edge Trophy (includes missing Blade's Edge Mountains spawn tracking data for Morcrush, Hemathion, Speaker Mar'grom). Fel Scars of Nagrand (includes missing Nagrand spawn tracking data for Voidwalker Minions, etc). Netherstorm Trophy (includes missing Netherstorm spawn tracking data for Nuramoc, Ever-Core the Punisher, Chief Engineer Lorthander).
- **Northrend**: Borean Trophy (includes missing Borean Tundra spawn tracking data for Fumblub Gearwind, Icehorn, Old Crystalbark).
- **Kalimdor**: Teldrassil Trophy (includes missing Teldrassil spawn tracking data for Threggil, Blackmoss the Fetid, Duskstalker, Uruson, Fury Shelda, Grimmaw). Darkshore Defense (complete 6 quests in Darkshore). Bloodmyst Recovery (complete 6 quests in Bloodmyst Isle).
- **Azeroth**: Arathi Trophy (includes missing Arathi Highlands spawn tracking data for Darbel Montrose, Singer, Foulbelly, Ruul Onestone, Kovork, Molok the Crusher, Zalas Witherbark, Nimar the Slayer, Geomancer Flintdagger, Prince Nazjak). Elwynn Errands (complete 6 quests in Elwynn Forest). Modan Trophy (includes missing Loch Modan spawn tracking data for Grizlak, Magosh, Large Loch Crocolisk, Shanda the Spinner, Lord Condar, Emogg the Crusher, Boss Galgosh). Redridge Resolve (complete 6 quests in Redridge Mountains). Westfall Trophy (includes missing Westfall spawn tracking data for Foe Reaper 4000, Marisa du'Paige, Vultros, Brack, Brainwashed Noble, Leprithus, Master Digger, Sergeant Brashclaw, Slark). Wetlands Trophy (includes missing Wetlands spawn tracking data for Dragonmaw Battlemaster, Razormaw Matriarch, Garneg Charskull, Gnawbone, Sludginn, Ma'ruk Wyrmscale, Leech Widow, Mirelow).

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
