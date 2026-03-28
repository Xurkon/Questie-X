## Questie-X v1.5.0 (2026-03-27)

### Critical Fixes

- **[Fix — Custom Server Compilation]** Fixed database compilation not running on custom servers (Ascension, Ebonhold, Turtle WoW, etc.) where plugins inject data after initial load. Modified Stage1 to defer compilation to Stage3 for custom servers, ensuring plugins finish injecting data before compilation runs. Added l10n:Initialize() and QuestieCorrections:MinimalInit() calls when deferring to Stage3, as Stage2 (QuestieJourney:Initialize()) requires hiddenQuests to be populated.

- **[Fix — Zone Mapping Bug]** Fixed incorrect key assignment in QuestiePluginAPI:InjectZoneTables(). Changed areaIdToUiMapId[uiMapId] = uiMapId to areaIdToUiMapId[areaId] = uiMapId at line 138. This caused zone lookups to fail, resulting in "No UiMapID or fitting parentAreaId" errors for custom zone IDs.

- **[Fix — Realm Detection]** Added "Bronzebeard" and "Warcraft Reborn" to Ascension realm detection patterns in Modules/QuestieServer.lua.

### Stability & Error Handling

- **[Fix — Quest Cache]** Resolved "GetQuest: The quest doesn't exist in QuestLogCache" fatal error during initialization on Ascension WoW client. Implemented retry mechanism in _QuestEventHandler:InitQuestLog to wait for game's quest log data.

- **[Fix — Validation Crash]** Fixed crash in DecodePointerMap when compiled database pointer map was empty or corrupted. Added defensive check to return empty table instead of crashing.

- **[Fix — Database Compiler]** Added skip logic in ValidateObjects and ValidateQuests when compiled binary data is missing, preventing validation failures on cached databases.

- **[Fix — Initialization]** Modified QuestieInit to skip validation in Stage 1 when plugins are pending, since plugins inject data after compilation and validation would compare stale pre-plugin data.

- **[Fix — Quest Links]** Fixed duplicate quest links when shift-clicking quests in the quest log. Removed redundant ChatEdit_InsertLink call from QuestLogTitleButton_OnClick hook.

- **[Fix — Profiler]** Fixed "memory allocation error: block too big" crash in QuestieProfiler. Added early-exit logic in HookTable to skip large pure-data tables.

- **[Fix — Quest Validation]** Fixed QuestieValidateGameCache to silently skip "ghost quests" (removed from database but still in quest log) instead of failing validation.

### Map & Zone Improvements

- **[Fix — Zone Mapping]** Added UiMapId overrides for 1415 (Eastern Kingdoms) and 947 (Azeroth) in zoneDB.lua to resolve "No AreaId found" warnings on Ascension servers.

- **[Fix — MapIconTooltip]** Fixed syntax error in MapIconTooltip.lua at line 239. Malformed if statement was preventing tooltips from updating when hovering over Quest objectives on World Map.

- **[Fix — DrawWorldIcon]** Fixed graceful return when parent map lookup returns nil.

### Plugin Architecture

- **[Plugin Synchronization]** Overhauled plugin loading architecture. Introduced QuestiePluginAPI:FinishLoading() and registration handshake to resolve race conditions during addon initialization.

- **[Universal Lua 5.0 Refactor]** Executed codebase-wide transition from pairs() and ipairs() to next() and numeric loops for Lua 5.0 engine compatibility with legacy clients.

### Files Changed

- Database/Corrections/QuestieEvent.lua
- Database/QuestieDB.lua
- Database/Zones/zoneDB.lua
- Database/compiler.lua
- Localization/l10n.lua
- Modules/Journey/QuestieJourneyUtils.lua
- Modules/Libs/MessageHandler.lua
- Modules/Libs/QuestiePluginAPI.lua
- Modules/Map/QuestieMap.lua
- Modules/QuestieInit.lua
- Modules/QuestieLearner.lua
- Modules/QuestiePlayer.lua
- Modules/QuestieServer.lua
- Modules/Tracker/TrackerUtils.lua
- Questie-X-Classic.toc
- Questie-X-TBC.toc
- Questie-X-Turtle.toc
- Questie-X.toc
- Questie.toc
- CHANGELOG.md
- RELEASE_NOTES.md

See CHANGELOG.md for full details.