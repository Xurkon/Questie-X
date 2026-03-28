# Questie-X v1.5.0 — Universal Stability & Zone Mapping

This major update focuses on critical runtime stability, centralized localization logic, and improved development infrastructure for all supported private servers (Ascension, Ebonhold, Turtle WoW, etc.).

### Database & Performance
- **[Fix] Database Robustness**: Added strict guards against invalid or zero IDs in `QuestieDB` lookup functions (`GetNPC`, `GetObject`, `GetItem`). This prevents the "rawdata is nil" debug spam that occurred when custom plugins attempted to access uninitialized or malformed entity data.
- **[Refactor] Lookup Logic**: Refactored `QuestieDB` override handling to support both numeric and string keys simultaneously. This ensures that custom server data is correctly resolved regardless of how the third-party plugin formats its internal IDs.
- **[Refactor] Data Injection**: Updated `QuestieLearner:InjectLearnedData` to enforce numeric key normalization, preventing type-mismatch collisions during database merging.
- **[Fix] Custom Server Compilation**: Fixed database compilation not running on custom servers where plugins inject data after initial load.
- **[Performance] Taint Mitigation**: Resolved multiple `ADDON_ACTION_BLOCKED` taint vectors related to `Questie-X-WotLKDB` global namespace pollution.

### QuestieLearner & Localization
- **[Fix] Centralized Zone Lookup**: Refactored `l10n.lua` to include centralized zone-to-ID mapping functions. This resolves the `attempt to call method 'GetAreaIdByLocalName' (a nil value)` error that occurred on Project Ebonhold.
- **[Fix] Ascension Zone Mapping**: Fixed a regression in `QuestieCompat` where `uiMapData` for Ascension-specific zones was not correctly propagating to the global mapping table.
- **[Fix] Zone Mapping Bug**: Fixed incorrect key assignment in `QuestiePluginAPI:InjectZoneTables()`, resolving "No UiMapID or fitting parentAreaId" errors.

### Infrastructure & Development
- **[Feature] Session Export**: Added a standardized `session_export` skill for automated exports of developer documentation and session artifacts.
- **[Feature] Enhanced Logging**: Improved initialization logging to provide detailed reporting on custom data injection for NPC, Object, and Item entities.

### Files Changed
- Standardized version to `1.5.0` across all files.
- Consolidated all v1.5.x experimental changes into a stable v1.5.0 release.
- Updated documentation: `README.md`, `CHANGELOG.md`, `docs/changelog.html`, and `docs/index.html`.