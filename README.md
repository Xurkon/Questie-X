<div align="center">

<img src="docs/QuestieXlogo.png" alt="Questie-X Logo" width="320" />

![Version](https://img.shields.io/badge/version-v1.1.4-blue.svg?style=for-the-badge)
![Downloads](https://img.shields.io/github/downloads/Xurkon/Questie-X/total?style=for-the-badge&color=e67e22)
[![Documentation](https://img.shields.io/badge/Documentation-View%20Docs-58a6ff?style=for-the-badge)](https://xurkon.github.io/Questie-X/)
[![Patreon](https://img.shields.io/badge/Patreon-F96854?style=for-the-badge&logo=patreon&logoColor=white)](https://www.patreon.com/Xurkon)
[![PayPal](https://img.shields.io/badge/PayPal-00457C?style=for-the-badge&logo=paypal&logoColor=white)](https://www.paypal.me/Xurkon)
![License](https://img.shields.io/github/license/Xurkon/Questie-X?style=for-the-badge&color=2980b9)
![WoW](https://img.shields.io/badge/WoW-Classic-blue?style=for-the-badge&logo=world-of-warcraft&logoColor=white)

<br/>

**A universal WoW quest-helper with a plugin architecture for any private server.**

[Download Latest](https://github.com/Xurkon/Questie-X/releases/latest) &nbsp;&bull;&nbsp; [View Source](https://github.com/Xurkon/Questie-X) &nbsp;&bull;&nbsp; [Documentation](https://xurkon.github.io/Questie-X/)

</div>

---

## About

Questie-X is a fork of the original [Questie](https://github.com/Questie/Questie) addon, rebuilt to run reliably on any WoW 3.3.5a private server — not just Blizzard-like realms. It fixes longstanding Lua errors, corrects API incompatibilities introduced by custom server emulators, and introduces a plugin system so server-specific quest databases can be distributed and maintained separately from the core addon.

---

## Installation

1. [Download](https://github.com/Xurkon/Questie-X/releases) the latest release.
2. Extract the archive into your `Interface/AddOns/` directory.
3. Rename the folder to match the dataset you want to load:
   - `Questie-X` — WotLK 3.3.5a (default)
   - `Questie-X-Classic` — Vanilla / Classic era content
   - `Questie-X-TBC` — The Burning Crusade content
4. Log in. If your server does not use standard map data, enable `Options -> Advanced -> Use WotLK map data`.

### Installing a Plugin

Plugins are standalone addons that inject custom quest, NPC, object, and item data into Questie-X at runtime. They are installed identically to the core addon.

1. Download the plugin archive from its repository's Releases page.
2. Extract it into `Interface/AddOns/` alongside `Questie-X`.
3. The folder name must match the plugin's `.toc` title exactly.
4. Log in — Questie-X detects and loads all present plugins automatically on startup.

> A plugin will not load unless `Questie-X` is also installed. The dependency is declared in the plugin's `.toc` file and enforced by the WoW client.

---

## Plugin System

Questie-X exposes a public `QuestiePluginAPI` that any addon can use to register custom server data without touching core files. This makes it possible to maintain server-specific databases as independent repositories that update on their own release schedule.

### How It Works

A plugin calls `QuestiePluginAPI:RegisterPlugin` during addon load and passes its database tables. Questie-X merges these into its runtime database before the first quest scan, so all features — map pins, tooltips, tracker, arrow — work transparently for custom content.

### Writing a Plugin

A minimal plugin needs only a `.toc` file declaring `Questie-X` as a dependency and a loader script:

```lua
-- MyServerLoader.lua
local plugin = QuestiePluginAPI:RegisterPlugin("MyServer")
plugin:RegisterQuestDB(MyServerQuestDB)
plugin:RegisterNpcDB(MyServerNpcDB)
plugin:RegisterObjectDB(MyServerObjectDB)
plugin:RegisterItemDB(MyServerItemDB)
plugin:RegisterZoneData(MyServerUiMapData, MyServerZoneTables)
```

The database tables follow the same schema as Questie's built-in databases. See `Modules/Libs/QuestiePluginAPI.lua` for the full API reference and `Database/Wotlk/wotlkQuestDB.lua` for table format examples.

---

## Fixes & Compatibility

### Quest Log & Tracker

- Corrected `GetQuestLogTitle` return value indices for the 3.3.5a client. The client returns `suggestedGroup` at index 4, shifting `isHeader` to index 5 and `questId` to index 9. Previously, modules were using indices 4/8, causing quest headers to be misidentified and `isDaily` to be assigned the wrong value.
- Removed premature `break` on `nil` title in quest log iteration loops. Quest log slots on private servers can be non-contiguous; the loop now uses a nil guard instead of aborting, preventing silently skipped quests.
- Quest objective counters now update correctly when items are deposited by automated systems that bypass the standard loot frame, using a multi-stage `BAG_UPDATE_DELAYED` strategy.
- Fixed `QuestEventHandler` crash on auto-completing quests caused by a missing `QuestiePlayer` module import.
- Fixed re-accepted repeatable quests not showing objective icons after the second acceptance.

### Map & Minimap

- Fixed `WorldMapFrame` compatibility for servers that render the world map in minimized mode.
- Fixed "ghost icon" bug where completed quest icons remained on the map after turn-in.
- Fixed `RequestMapUpdate` logic that caused completed quest icons to persist across zone transitions.
- Downgraded spurious `[CRITICAL] No AreaId found for UiMapId` log spam to debug level. On some servers, `C_Map.GetBestMapForUnit` returns a continent-level UiMapId for capital cities; the nil return was already handled gracefully but was incorrectly logged as critical.
- Fixed map pins for `killCredit`-type objectives not resolving spawn locations correctly.

### Tooltips

- Fixed `attempt to concatenate nil` error when a quest starter or finisher has no name in the database.
- Added support for `killcredit` and `spell` objective types in `MapIconTooltip`.
- Tooltip now displays if an NPC drops an item that starts a quest.

### Quest Arrow

- Refactored distance calculations and target prioritisation; arrow now correctly filters targets by zone and instance.
- Fixed arrow pointing to previously completed objective locations instead of the current finisher.
- Fixed nil error in `_CollectObjective` when processing incomplete quests.
- Fixed arrow direction for quests that require speaking to an NPC as a prerequisite step.

### Nameplates

- Questie nameplate hooks are skipped when a conflicting nameplate addon is detected, preventing taint and UI errors.

### Databases & Custom IDs

- Full support for large integer NPC, quest, object, and item IDs used by custom server emulators.
- Fixed `ZoneDB` crash when encountering maps with no AreaId mapping (e.g. continent-level maps on Kalimdor).
- Fixed `GetObject` returning nil for Item Finishers misidentified as GameObject Finishers on custom servers.
- Fixed `NPC 30514` (Thorim listen bunny) missing fallback spawn data for Sibling Rivalry turn-in.

---

## Features

### Visual Map Objectives

Quest starters, turn-ins, and all objective types are drawn as icons directly on the minimap and world map.

<div align="center">
  <img src="https://i.imgur.com/4abi5yu.png" height="200" alt="Quest Givers" />
  <img src="https://i.imgur.com/DgvBHyh.png" height="200" alt="Quest Complete" />
  <img src="https://i.imgur.com/uPykHKC.png" height="200" alt="Quest Tooltip" />
</div>

### Quest Tracker

- Tracks quests automatically on acceptance.
- Displays up to 20 quests simultaneously (original limit: 5).
- Left-click opens the quest log; right-click provides focus mode and TomTom arrow integration.
- Headers persist correctly across all session events.

<div align="center">
  <img src="https://user-images.githubusercontent.com/8838573/67285596-24dbab00-f4d8-11e9-9ae1-7dd6206b5e48.png" width="400" alt="Tracker" />
</div>

### Quest Arrow

Directional arrow pointing toward the nearest active objective or quest finisher, with zone and instance awareness.

### My Journey & Quests by Zone

- **Journey Log** — records every quest accepted, completed, and abandoned during a session.
- **Quests by Zone** — lists all available and completed quests in a given zone for completionists.

<div align="center">
  <img src="https://user-images.githubusercontent.com/8838573/67285651-3cb32f00-f4d8-11e9-95d8-e8ceb2a8d871.png" height="200" alt="Journey" />
  <img src="https://user-images.githubusercontent.com/8838573/67285665-450b6a00-f4d8-11e9-9283-325d26c7c70d.png" height="200" alt="Zone Quests" />
</div>

### Database Search & Configuration

- Search the full Questie database for any NPC, object, or quest by name or ID.
- Extensive options: icon scale, tracking behaviour, nameplate display, tracker layout, and more.

<div align="center">
  <img src="https://user-images.githubusercontent.com/8838573/67285691-4f2d6880-f4d8-11e9-8656-b3e37dce2f05.png" height="200" alt="Search" />
  <img src="https://user-images.githubusercontent.com/8838573/67285731-61a7a200-f4d8-11e9-9026-b1eeaad0d721.png" height="200" alt="Config" />
</div>

---

## Credits

- **Questie Team** — Original addon developers.
- **Xurkon** — Questie-X fork and ongoing maintenance.

## License

MIT License — see [LICENSE](LICENSE) for details.
