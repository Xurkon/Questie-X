<div align="center">

# Questie (3.3.5a)

![Version](https://img.shields.io/badge/version-v9.9.2-blue.svg?style=for-the-badge)
![Downloads](https://img.shields.io/github/downloads/Xurkon/PE-Questie/total?style=for-the-badge&color=e67e22)
[![Documentation](https://img.shields.io/badge/Documentation-View%20Docs-58a6ff?style=for-the-badge)](https://xurkon.github.io/PE-Questie/)
[![Patreon](https://img.shields.io/badge/Patreon-F96854?style=for-the-badge&logo=patreon&logoColor=white)](https://www.patreon.com/Xurkon)
[![PayPal](https://img.shields.io/badge/PayPal-00457C?style=for-the-badge&logo=paypal&logoColor=white)](https://www.paypal.me/Xurkon)
![License](https://img.shields.io/github/license/Xurkon/PE-Questie?style=for-the-badge&color=2980b9)
![WoW](https://img.shields.io/badge/WoW-3.3.5a-blue?style=for-the-badge&logo=world-of-warcraft&logoColor=white)

<br/>
**A fork of the WoW Classic Questie addon aiming to provide compatibility with ANY private server.**

[⬇ **Download Latest**](https://github.com/Xurkon/PE-Questie/releases/latest) &nbsp;&nbsp;•&nbsp;&nbsp; [📂 **View Source**](https://github.com/Xurkon/PE-Questie) &nbsp;&nbsp;•&nbsp;&nbsp; [📖 **Read Documentation**](https://xurkon.github.io/PE-Questie/)

</div>

---

## 📥 Installation

1. [Download](https://github.com/Xurkon/PE-Questie/releases) the archive.
2. Extract it into the `Interface/AddOns/` directory. The folder name should be `Questie-X`.
3. **Custom Server Support**: If you are playing on a server emulating a previous expansion (Classic or TBC) using the 3.3.5 client, you can add `-Classic` or `-TBC` to the folder name to load specific datasets.
4. **Map Compatibility**: If your server lacks a world map patch, enable `Options → Advanced → Use WotLK map data`.

---

## 🔧 Fixes & Compatibility

### 🛡️ Nameplates

- Explicitly skips **Ascension Nameplates** to avoid conflicts, while maintaining compatibility with generic nameplate addons.

### 📊 Quest Tracker

- **Ascension API**: Fully compatible with custom quest APIs; no crashes on auto-turn-in quests.
- **Header Persistence**: Resolved issues where quest headers would disappear from the tracker.
- **Dynamic Updates**: Instant refresh when accepting, completing, or abandoning quests.
- **Combat Safety**: Protected with `pcall` to prevent UI lockups during intense combat updates.

### 💬 Tooltips

- Fixed all legacy Lua errors.
- **New Feature**: Displays if an NPC drops an item that starts a quest directly in the tooltip.

### 🗺️ Maps (Minimap & World Map)

- **Minimap**: Fixed zoom-related Lua errors.
- **World Map**: Full support for Ascension's `WorldMapFrame` (minimized mode), **Mapster**, and **Magnify-WotLK**.
- **Icon Cleanup**: Resolved "ghost icon" bug where completed quests remained visible on the map.

### 📦 Custom IDs

- Native support for large integer IDs common on custom private servers.

---

## ✨ Features

### ⚔️ Ascension Scaling

- Quests automatically scale to character level, perfectly matching the Ascension Scaling system.

### 📍 Visual Map Objectives

Notes for quest starters, turn-ins, and complex objectives are drawn directly on your maps.

<div align="center">
  <img src="https://i.imgur.com/4abi5yu.png" height="200" alt="Quest Givers" />
  <img src="https://i.imgur.com/DgvBHyh.png" height="200" alt="Quest Complete" />
  <img src="https://i.imgur.com/uPykHKC.png" height="200" alt="Quest Tooltip" />
</div>

### 📜 Advanced Quest Tracker

- **Smart Tracking**: Automatically tracks quests upon acceptance.
- **Expanded Capacity**: Displays up to 20 quests (original limit: 5).
- **Interactive**: Left-click to open the log; Right-click for focus modes or TomTom arrow integration.

<div align="center">
  <img src="https://user-images.githubusercontent.com/8838573/67285596-24dbab00-f4d8-11e9-9ae1-7dd6206b5e48.png" width="400" alt="Tracker" />
</div>

### 🗺️ My Journey & Quests by Zone

- **Journey Log**: Record every major step of your adventure.
- **Completionist View**: Lists all available and completed quests per zone to ensure nothing is missed.

<div align="center">
  <img src="https://user-images.githubusercontent.com/8838573/67285651-3cb32f00-f4d8-11e9-95d8-e8ceb2a8d871.png" height="200" alt="Journey" />
  <img src="https://user-images.githubusercontent.com/8838573/67285665-450b6a00-f4d8-11e9-9283-325d26c7c70d.png" height="200" alt="Zone Quests" />
</div>

### 🔍 Database Search & Config

- **Global Search**: Find any NPC, Object, or Quest in the massive Questie database.
- **Deep Customization**: Adjust everything from icon scale to tracking logic.

<div align="center">
  <img src="https://user-images.githubusercontent.com/8838573/67285691-4f2d6880-f4d8-11e9-8656-b3e37dce2f05.png" height="200" alt="Search" />
  <img src="https://user-images.githubusercontent.com/8838573/67285731-61a7a200-f4d8-11e9-9026-b1eeaad0d721.png" height="200" alt="Config" />
</div>

---

## 👥 Credits

- **Questie Team** - Original addon developers.
- **Xurkon** - Private Expansion fork and maintenance.
- **Project Ascension & Ebonhold Communities** - Testing and data feedback.

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.
