<div align="center">

<img src="docs/QuestieXlogo.png" alt="Questie-X Logo" width="320" />

# Questie-X

![Version](https://img.shields.io/badge/version-v1.1.4-blue.svg?style=for-the-badge)
![Downloads](https://img.shields.io/github/downloads/Xurkon/Questie-X/total?style=for-the-badge&color=e67e22)
[![Documentation](https://img.shields.io/badge/Documentation-View%20Docs-58a6ff?style=for-the-badge)](https://xurkon.github.io/Questie-X/)
[![Patreon](https://img.shields.io/badge/Patreon-F96854?style=for-the-badge&logo=patreon&logoColor=white)](https://www.patreon.com/Xurkon)
[![PayPal](https://img.shields.io/badge/PayPal-00457C?style=for-the-badge&logo=paypal&logoColor=white)](https://www.paypal.me/Xurkon)
![License](https://img.shields.io/github/license/Xurkon/Questie-X?style=for-the-badge&color=2980b9)
![WoW](https://img.shields.io/badge/WoW-3.3.5a-blue?style=for-the-badge&logo=world-of-warcraft&logoColor=white)

<br/>

**A universal WoW quest-helper addon with a plugin architecture for custom private servers.**

[Download Latest](https://github.com/Xurkon/Questie-X/releases/latest) &nbsp;&bull;&nbsp; [View Source](https://github.com/Xurkon/Questie-X) &nbsp;&bull;&nbsp; [Read Documentation](https://xurkon.github.io/Questie-X/)

</div>

---

## Installation

1. [Download](https://github.com/Xurkon/Questie-X/releases) the archive.
2. Extract it into your `Interface/AddOns/` directory.
3. The folder name determines which dataset loads:
   - `Questie-X` — WotLK (3.3.5a default)
   - `Questie-X-Classic` — Classic era dataset
   - `Questie-X-TBC` — The Burning Crusade dataset
4. If your server lacks a world map patch, enable `Options -> Advanced -> Use WotLK map data`.

### Plugin Example

To add custom server data (e.g. Project Ascension), install the matching plugin alongside the core:

1. Download [Questie-Ascension](https://github.com/Xurkon/Questie-X-AscensionDB/releases) and extract it into `Interface/AddOns/Questie-Ascension`.
2. Both `Questie-X` and `Questie-Ascension` must be present — the plugin declares `Questie-X` as a dependency and will not load without it.

---

## Plugin System

Questie-X ships with a **Plugin API** that lets separate addons inject custom server databases (quests, NPCs, objects, items, zones) without modifying core files. This is a new architecture replacing the old embedded `Database/Ascension` and `Database/Ebonhold` folders.

### Available Plugins

| Plugin | Server | Repository |
|--------|--------|------------|
| Questie-Ascension | Project Ascension | [Questie-X-AscensionDB](https://github.com/Xurkon/Questie-X-AscensionDB) |
| Questie-Ebonhold | Ebonhold | [Questie-X-EbonholdDB](https://github.com/Xurkon/Questie-X-EbonholdDB) |

### Installing a Plugin

Each plugin is a standalone addon. Install it the same way as the core addon:

1. Download the plugin archive from its repository's Releases page.
2. **Extract it into your `Interface/AddOns/` directory** alongside `Questie-X`.
3. The extracted folder name must match the plugin's `.toc` title (e.g., `Questie-Ascension`, `Questie-Ebonhold`).
4. Reload your UI or restart the game client — Questie-X will detect and load the plugin automatically.

> Plugins declare `Questie-X` as a dependency in their `.toc` file, so they only load when the core addon is present.

### Writing Your Own Plugin

Questie-X exposes a public API via `QuestiePluginAPI`. A minimal plugin registers itself and provides override tables:

```lua
local plugin = QuestiePluginAPI:RegisterPlugin("MyServer")
plugin:RegisterQuestDB(MyServerQuestDB)
plugin:RegisterNpcDB(MyServerNpcDB)
plugin:RegisterObjectDB(MyServerObjectDB)
plugin:RegisterItemDB(MyServerItemDB)
plugin:RegisterZoneData(MyServerUiMapData, MyServerZoneTables)
```

See `Modules/Libs/QuestiePluginAPI.lua` for the full API surface.

---

## Fixes & Compatibility

### Nameplates

- Explicitly skips Ascension Nameplates to avoid conflicts while maintaining compatibility with generic nameplate addons.

### Quest Tracker

- **Ascension API**: Fully compatible with custom quest APIs; no crashes on auto-turn-in quests.
- **Header Persistence**: Resolved issues where quest headers would disappear from the tracker.
- **Dynamic Updates**: Instant refresh when accepting, completing, or abandoning quests.
- **Combat Safety**: Protected with `pcall` to prevent UI lockups during intense combat updates.

### Tooltips

- Fixed all legacy Lua errors.
- Displays if an NPC drops an item that starts a quest directly in the tooltip.

### Maps (Minimap & World Map)

- **Minimap**: Fixed zoom-related Lua errors.
- **World Map**: Full support for Ascension's `WorldMapFrame` (minimized mode), Mapster, and Magnify-WotLK.
- **Icon Cleanup**: Resolved "ghost icon" bug where completed quests remained visible on the map.

### Custom IDs

- Native support for large integer IDs common on custom private servers.

---

## Features

### Ascension Scaling

Quests automatically scale to character level, perfectly matching the Ascension Scaling system.

### Visual Map Objectives

Notes for quest starters, turn-ins, and complex objectives are drawn directly on your maps.

<div align="center">
  <img src="https://i.imgur.com/4abi5yu.png" height="200" alt="Quest Givers" />
  <img src="https://i.imgur.com/DgvBHyh.png" height="200" alt="Quest Complete" />
  <img src="https://i.imgur.com/uPykHKC.png" height="200" alt="Quest Tooltip" />
</div>

### Advanced Quest Tracker

- **Smart Tracking**: Automatically tracks quests upon acceptance.
- **Expanded Capacity**: Displays up to 20 quests (original limit: 5).
- **Interactive**: Left-click to open the log; Right-click for focus modes or TomTom arrow integration.

<div align="center">
  <img src="https://user-images.githubusercontent.com/8838573/67285596-24dbab00-f4d8-11e9-9ae1-7dd6206b5e48.png" width="400" alt="Tracker" />
</div>

### My Journey & Quests by Zone

- **Journey Log**: Record every major step of your adventure.
- **Completionist View**: Lists all available and completed quests per zone to ensure nothing is missed.

<div align="center">
  <img src="https://user-images.githubusercontent.com/8838573/67285651-3cb32f00-f4d8-11e9-95d8-e8ceb2a8d871.png" height="200" alt="Journey" />
  <img src="https://user-images.githubusercontent.com/8838573/67285665-450b6a00-f4d8-11e9-9283-325d26c7c70d.png" height="200" alt="Zone Quests" />
</div>

### Database Search & Config

- **Global Search**: Find any NPC, Object, or Quest in the massive Questie database.
- **Deep Customization**: Adjust everything from icon scale to tracking logic.

<div align="center">
  <img src="https://user-images.githubusercontent.com/8838573/67285691-4f2d6880-f4d8-11e9-8656-b3e37dce2f05.png" height="200" alt="Search" />
  <img src="https://user-images.githubusercontent.com/8838573/67285731-61a7a200-f4d8-11e9-9026-b1eeaad0d721.png" height="200" alt="Config" />
</div>

---

## Credits

- **Questie Team** - Original addon developers.
- **Xurkon** - Questie-X fork and maintenance.
- **Project Ascension & Ebonhold Communities** - Testing and data feedback.

## License

MIT License - See [LICENSE](LICENSE) for details.
