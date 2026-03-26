---
paths:
  - "**/*.lua"
---
# Lua Hooks

> This file extends [common/hooks.md](../common/hooks.md) with Lua specific content.

## Tool Chain Summary

| Tool | Purpose | Install | Run |
|------|---------|---------|-----|
| **Luacheck** | Static analysis (undefined globals, unused vars, shadowed locals) | `luarocks install luacheck` | `luacheck .` |
| **StyLua** | Opinionated code formatter (Rust-based, fast) | `cargo install stylua` | `stylua .` |
| **Luacov** | Line coverage reporting | `luarocks install luacov` | `busted --coverage && luacov` |
| **lua-language-server** | IDE diagnostics, type checking, completion | VS Code extension | Automatic |

## Static Analysis: Luacheck

Luacheck detects:
- Undefined global variables (critical for preventing taint)
- Unused local variables and function arguments
- Shadowed local variables
- Unreachable code after `return`
- Unused values assigned to variables

### Configuration (`.luacheckrc`)

Place at project root. Be exhaustive with known globals to eliminate false positives.

**Version targeting**: Set `std` based on your runtime. Use `"lua50"` for 5.0, `"lua51"` for 5.1, or `"none"` for maximum strictness (recommended for WoW addons where you must declare every global):

```lua
-- .luacheckrc
-- For Lua 5.0 projects: use "lua50" to allow table.getn, table.setn, etc.
-- For Lua 5.1 projects: use "lua51"
-- For WoW addons:       use "none" (strictest; manually declare all globals)
std = "none"
max_line_length = 120
cache = true          -- Speed up repeated runs

-- Allowed globals — explicitly list every WoW API function used
globals = {
    -- Core addon system
    "QuestieLoader", "Questie", "QuestieDB",
}

read_globals = {
    -- Lua builtins (read-only)
    "select", "unpack", "pcall", "xpcall", "error", "assert",
    "type", "tostring", "tonumber", "rawget", "rawset",
    "setmetatable", "getmetatable", "next", "pairs", "ipairs",
    "coroutine", "string", "table", "math", "bit",

    -- WoW Frame API
    "CreateFrame", "UIParent",

    -- WoW Timer API
    "C_Timer",

    -- WoW Map API
    "C_Map", "C_QuestLog",

    -- WoW Unit API
    "UnitGUID", "UnitName", "UnitLevel", "UnitFactionGroup",
    "UnitClass", "UnitRace", "GetRealmName",

    -- WoW Addon API
    "IsAddOnLoaded", "GetAddOnInfo", "GetNumAddOns",
    "GetAddOnMetadata",

    -- WoW Combat API
    "InCombatLockdown",

    -- WoW Misc
    "Enum", "GetTime", "GetLocale", "GetBuildInfo",
    "SlashCmdList", "SLASH_QUESTIE1",
    "hooksecurefunc", "debugstack", "geterrorhandler",
    "print", "format", "wipe", "strsplit", "strtrim",
    "tinsert", "tremove",

    -- Lua 5.0-specific globals (add if targeting 5.0)
    -- "loadlib",         -- 5.0 global; moved to package.loadlib in 5.1+
    -- Note: table.getn, table.setn, table.foreach, table.foreachi,
    -- math.mod, and string.gfind are methods on their parent tables.
    -- Luacheck already allows them via the "table", "math", and "string"
    -- entries above. Use std = "lua50" if you need full 5.0 stdlib.

    -- SavedVariables (read-only access is acceptable)
    "QuestieSV",
}

-- Per-directory overrides
files["Database/Data/**"] = {
    max_line_length = false,    -- Data files have long lines
    ignore = { "631" },         -- Allow line length variance
}

files["tests/**"] = {
    std = "+busted",            -- Add Busted globals (describe, it, assert, etc.)
    globals = {
        "_G",                   -- Tests may manipulate _G for mocking
    },
}

files["Localization/**"] = {
    max_line_length = false,    -- Translation strings can be long
}

-- Warnings to suppress project-wide
ignore = {
    "212",   -- Unused argument (common in callbacks: function(self, event, ...))
    "213",   -- Unused loop variable (for _ in pairs)
}
```

### Running Luacheck

```bash
# Full project lint
luacheck .

# Single file with column info
luacheck Database/QuestieDB.lua --codes --ranges

# CI mode: no color, non-zero exit on warnings
luacheck . --no-color --formatter plain

# Show only errors (ignore warnings)
luacheck . --only 0

# List all globals used (audit for taint)
luacheck . --globals --no-unused --no-redefined
```

### Common Warning Codes

| Code | Meaning | Fix |
|------|---------|-----|
| 111 | Setting undefined global | Add `local` or add to `globals` list |
| 112 | Mutating undefined global | Same as 111 |
| 113 | Accessing undefined global | Add to `read_globals` or add `local` |
| 211 | Unused local variable | Remove or prefix with `_` |
| 212 | Unused argument | Prefix with `_` or add to `ignore` |
| 311 | Unused value | Remove the assignment |
| 411 | Redefining local variable | Rename or restructure |
| 421 | Shadowing local variable | Rename inner variable |
| 542 | Empty if branch | Add logic or use guard pattern |

## Formatting: StyLua

### Configuration (`stylua.toml`)

```toml
column_width = 120
line_endings = "Unix"
indent_type = "Spaces"
indent_width = 4
quote_style = "AutoPreferDouble"
call_parentheses = "Always"
collapse_simple_statement = "Never"

[sort_requires]
enabled = false  # Lua module loading order matters
```

### Commands

```bash
# Check formatting without modifying (CI)
stylua --check .

# Auto-format all Lua files
stylua .

# Format a single file
stylua Database/QuestieDB.lua

# Preview changes (diff mode)
stylua --check --output-format=diff .
```

## Language Server: lua-language-server (Sumneko)

### VS Code Configuration

```json
// .vscode/settings.json
{
    // Set to "Lua 5.0" for 5.0 projects, "Lua 5.1" for WoW, etc.
    "Lua.runtime.version": "Lua 5.1",
    "Lua.diagnostics.globals": [
        "Questie", "QuestieLoader", "QuestieDB",
        "CreateFrame", "C_Timer", "C_Map", "Enum",
        "GetTime", "IsAddOnLoaded", "InCombatLockdown",
        "hooksecurefunc", "debugstack", "wipe",
        "print", "format", "strsplit"
    ],
    "Lua.workspace.library": [
        // Path to WoW API type definitions if available
    ],
    "Lua.workspace.ignoreDir": [
        "Database/Data",
        ".release"
    ],
    "Lua.diagnostics.disable": [
        "lowercase-global"
    ],
    "Lua.completion.callSnippet": "Replace",
    "Lua.hint.enable": true
}
```

### Type Annotations (EmmyLua / lua-language-server)

Use `---@` annotations to add type safety in supported IDEs:

```lua
---@class QuestieDB
---@field npcData table<number, table>
---@field questData table<number, table>
local QuestieDB = {}

---@param npcId number
---@return table|nil npcData
---@return string|nil errorMessage
function QuestieDB:GetNPC(npcId)
    -- ...
end
```

## Pre-Commit Hook

```bash
#!/bin/sh
# .git/hooks/pre-commit
set -e

echo "=== Luacheck ==="
luacheck . --no-color

echo "=== StyLua ==="
stylua --check .

echo "=== All checks passed ==="
```

## Makefile Targets

```makefile
.PHONY: lint format test coverage ci

lint:
	luacheck . --no-color
	stylua --check .

format:
	stylua .

test:
	busted --verbose

coverage:
	busted --coverage
	luacov
	@awk '/^Total/ { if ($$4+0 < 80) { print "FAIL: Coverage " $$4 "% < 80%"; exit 1 } else { print "PASS: Coverage " $$4 "%"; } }' luacov.report.out

ci: lint test coverage
```

## CI Pipeline (GitHub Actions)

```yaml
# .github/workflows/lua-ci.yml
name: Lua CI
on: [push, pull_request]

jobs:
  lint-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Lua
        uses: leafo/gh-actions-lua@v10
        with:
          luaVersion: "5.1"

      - name: Setup LuaRocks
        uses: leafo/gh-actions-luarocks@v4

      - name: Install Dependencies
        run: |
          luarocks install luacheck
          luarocks install busted
          luarocks install luacov

      - name: Install StyLua
        run: |
          curl -L -o stylua.zip https://github.com/JohnnyMorganz/StyLua/releases/latest/download/stylua-linux-x86_64.zip
          unzip stylua.zip -d /usr/local/bin/
          chmod +x /usr/local/bin/stylua

      - name: Lint (Luacheck)
        run: luacheck . --no-color

      - name: Format Check (StyLua)
        run: stylua --check .

      - name: Test
        run: busted --output=TAP --coverage

      - name: Coverage
        run: |
          luacov
          awk '/^Total/ { if ($4+0 < 80) { print "FAIL: " $4 "%"; exit 1 } }' luacov.report.out
```

## PostToolUse Hook Behavior

After every Lua file edit or creation, the agent SHOULD:

1. Run `luacheck <file>` on the modified file
2. Run `stylua --check <file>` on the modified file
3. Report any issues **before** proceeding to the next edit

This catches errors immediately rather than accumulating them across a multi-file change.

## WoW-Specific: Taint Detection

Monitor for these errors in the WoW error log — they indicate your addon is touching protected state:

| Error | Cause | Fix |
|-------|-------|-----|
| `ADDON_ACTION_BLOCKED` | Tainted code called a protected API | Remove the taint source (`loadstring`, `_G` writes) |
| `ADDON_ACTION_FORBIDDEN` | Addon tried to call a hardware event API | Guard with `InCombatLockdown()` |
| `Couldn't find frame` | Invalid secure template reference | Check template names in `CreateFrame` |

Common taint sources and their fixes:

| Taint Source | Fix |
|-------------|-----|
| `loadstring()` in addon code | Replace with function dispatch tables |
| `_G.MyAddon_Data = data` | Use `addonTable` from the TOC vararg |
| Writing globals from `OnUpdate` | Move writes to `ADDON_LOADED` or `PLAYER_LOGIN` |
| `rawset(_G, name, value)` | Use local module tables instead |
| Hooking with function replacement | Use `hooksecurefunc()` (post-hook only, never overwrite) |
| Calling restricted APIs after taint | Isolate tainted code from secure code paths |
