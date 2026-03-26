---
paths:
  - "**/*.lua"
---
# Lua Patterns

> This file extends [common/patterns.md](../common/patterns.md) with Lua specific content.

## Module Pattern

The standard Lua module returns a table as its public API. All internal state and helpers are file-local. This is the foundation of all Lua architecture.

```lua
-- mymodule.lua
local M = {}

-- Private state — invisible outside this file
local _cache = {}
local _initialized = false

-- Private helper — underscore prefix signals internal use
local function _buildCacheKey(id)
    return "key_" .. tostring(id)
end

-- Public API — the only things callers can access
function M.get(id)
    return _cache[_buildCacheKey(id)]
end

function M.init()
    if _initialized then return end
    _initialized = true
    -- one-time setup
end

return M
```

### Legacy Module Styles (5.0 and 5.1)

In Lua 5.0, `setfenv` was used directly to create module environments (there was no `module()` function). In Lua 5.1, the `module()` built-in was introduced. Both are deprecated/removed in 5.2+:

```lua
-- LEGACY 5.0 style — setfenv only (no module() function exists in 5.0)
local M = {}
setfenv(1, M)  -- Sets the current function's environment to M

function get(id)    -- Automatically scoped to M
    return cache[id]
end
return M

-- LEGACY 5.1 style — module() function (introduced in 5.1, deprecated in 5.2)
module("mymodule")  -- Creates a global table, sets the function env

function get(id)    -- Automatically added to the module table
    return cache[id]
end

-- MODERN style (5.0+) — return-table pattern works on ALL versions
local M = {}
function M.get(id) return cache[id] end
return M
```

**Rule**: Always use the return-table pattern. It works on Lua 5.0–5.4, does not depend on `setfenv` or `module()`, and does not pollute the global namespace.

## Loader / ImportModule Pattern

In large addon systems, a central loader avoids circular `require()` chains by acting as a module registry with lazy resolution:

```lua
-- QuestieLoader.lua
local Loader = {}
local _modules = {}

function Loader:CreateModule(name)
    local mod = {}
    _modules[name] = mod
    return mod
end

function Loader:ImportModule(name)
    return _modules[name]
end

-- Usage in a module file:
local QuestieDB = QuestieLoader:CreateModule("QuestieDB")

-- Usage as a consumer:
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
```

This pattern breaks circular dependencies because modules register themselves at parse time but only call `ImportModule` at runtime (inside function bodies).

## OOP / "Class" Pattern

Simulate classes and inheritance with metatables. This is the most common OOP approach in Lua.

### Basic Class

```lua
local Animal = {}
Animal.__index = Animal

function Animal:New(name, sound)
    return setmetatable({
        name  = name,
        sound = sound,
    }, self)  -- 'self' is Animal here (or a subclass)
end

function Animal:Speak()
    return self.name .. " says " .. self.sound
end
```

### Inheritance

Chain `__index` through the class hierarchy. Call parent constructors with dot-notation (not colon) to avoid double-wrapping `self`:

```lua
-- Dog extends Animal
local Dog = setmetatable({}, { __index = Animal })
Dog.__index = Dog

function Dog:New(name)
    -- CORRECT: dot-notation passes 'self' (Dog) explicitly
    local instance = Animal.New(self, name, "Woof")
    return setmetatable(instance, Dog)
end

function Dog:Fetch(item)
    return self.name .. " fetches the " .. item
end

-- BAD: colon-notation would pass Dog as 'self' twice
-- local instance = Animal:New(name, "Woof")  -- WRONG
```

### Mixins

Add behavior from multiple sources without full multiple inheritance:

```lua
local Serializable = {}
function Serializable:Serialize()
    local parts = {}
    for k, v in pairs(self) do
        table.insert(parts, tostring(k) .. "=" .. tostring(v))
    end
    return table.concat(parts, ";")
end

-- Mixin application
local function applyMixin(class, mixin)
    for k, v in pairs(mixin) do
        if class[k] == nil then  -- Don't overwrite existing methods
            class[k] = v
        end
    end
end

applyMixin(Dog, Serializable)
-- Now Dog instances have :Serialize()
```

## Singleton Pattern

Wrap initialization in a one-time guard. Common for managers, registries, and services:

```lua
local ConfigManager = {}
local _config = nil

function ConfigManager:Get(key)
    if not _config then
        _config = self:_load()
    end
    return _config[key]
end

function ConfigManager:_load()
    -- expensive one-time load
    return { debug = false, maxLevel = 80 }
end
```

## Registry / Plugin Architecture

Use a central registry for runtime plugin discovery without hard coupling. This is the pattern used by `QuestiePluginAPI`:

```lua
local PluginRegistry = { _plugins = {} }

function PluginRegistry:Register(name, pluginData)
    assert(type(name) == "string", "Plugin name must be a string")
    assert(not self._plugins[name], "Plugin already registered: " .. name)

    local plugin = {
        name  = name,
        data  = pluginData or {},
        stats = { QUEST = 0, NPC = 0, OBJECT = 0, ITEM = 0 },
    }
    self._plugins[name] = plugin
    return plugin
end

function PluginRegistry:Get(name)
    return self._plugins[name]
end

function PluginRegistry:IsAnyLoaded()
    return next(self._plugins) ~= nil
end
```

### Plugin-Side Registration

Plugins register at parse time (top of file, outside any event handler) so the core can discover them immediately:

```lua
-- In plugin Loader.lua (top level, not inside PLAYER_LOGIN)
local plugin = PluginRegistry:Register("WotLKDB", addonTable)
```

## Observer / Event Bus Pattern

Decouple producers from consumers. Essential for addon systems where modules load in unpredictable order:

```lua
local EventBus = { _listeners = {} }

function EventBus:On(event, fn)
    self._listeners[event] = self._listeners[event] or {}
    -- Use table.insert for 5.0 compat (no # operator)
    table.insert(self._listeners[event], fn)
end

function EventBus:Off(event, fn)
    local listeners = self._listeners[event]
    if not listeners then return end
    -- Reverse iterate; table.getn for 5.0, # for 5.1+
    local n = table.getn and table.getn(listeners) or #listeners
    for i = n, 1, -1 do
        if listeners[i] == fn then
            table.remove(listeners, i)
            return
        end
    end
end

function EventBus:Emit(event, ...)
    local listeners = self._listeners[event]
    if not listeners then return end
    -- ipairs works on all versions (5.0+)
    for _, fn in ipairs(listeners) do
        fn(...)  -- 5.1+: ... is an expression; 5.0: use unpack(arg) instead
    end
end
```

## Coroutine-Based Lazy Iterator

Turn expensive database scans into resumable, lazy iterations without building the full result set in memory:

```lua
local function filteredNPCs(npcData, predicate)
    return coroutine.wrap(function()
        for id, data in pairs(npcData) do
            if data and predicate(id, data) then
                coroutine.yield(id, data)
            end
        end
    end)
end

-- Usage: processes NPCs one at a time, no intermediate table
for npcId, npcData in filteredNPCs(QuestieDB.npcData, function(id, d)
    return d[2] and d[2] >= 70  -- level >= 70
end) do
    processNPC(npcId, npcData)
end
```

**Version note**: `coroutine.wrap` is available in Lua 5.0+. However, in 5.0 you cannot yield from inside an iterator used in a generic `for` loop as part of a C boundary. The wrap-based pattern above works because the `for` loop drives `resume` directly.

## Chunked Processing (Frame-Budgeted Work)

For operations that must not freeze the game client, split work across frames:

```lua
local function createChunkedProcessor(items, processFunc, chunkSize)
    chunkSize = chunkSize or 100
    local keys = {}
    -- Use table.insert for 5.0 compat
    for k in pairs(items) do table.insert(keys, k) end

    local index = 1
    local total = table.getn and table.getn(keys) or #keys

    return function()  -- Call this each frame/tick
        local budget = math.min(index + chunkSize - 1, total)
        for i = index, budget do
            processFunc(keys[i], items[keys[i]])
        end
        index = budget + 1
        return index > total  -- Returns true when done
    end
end

-- Usage with WoW C_Timer
local processor = createChunkedProcessor(rawData, compileRecord, 200)
local ticker
ticker = C_Timer.NewTicker(0.01, function()
    if processor() then
        ticker:Cancel()
        print("Compilation complete!")
    end
end)
```

## Memoization / Caching

Cache expensive computations. Support cache invalidation:

```lua
local _zoneCache = {}
local _zoneCacheDirty = false

function ZoneDB:GetZoneAreaId(uiMapId)
    if not _zoneCacheDirty and _zoneCache[uiMapId] ~= nil then
        return _zoneCache[uiMapId]
    end
    local result = self:_computeZoneAreaId(uiMapId)
    _zoneCache[uiMapId] = result
    return result
end

function ZoneDB:InvalidateCache()
    wipe(_zoneCache)
    _zoneCacheDirty = false
end
```

**Caution**: Use `~= nil` for the cache check, not truthiness. Cached `false` or `0` values are valid and must not trigger recomputation.

## AddonTable Pattern (WoW-Specific)

The WoW client passes a private shared table to every file listed in the addon's `.toc`:

```lua
-- File 1: data.lua
local addonName, addonTable = ...
addonTable.npcData = { [1] = { "Ragnaros", 63, 1 } }

-- File 2: init.lua — same addonTable reference
local addonName, addonTable = ...
local npc = addonTable.npcData[1]
print(npc[1])  -- "Ragnaros"
```

**Critical rule**: Use `addonTable` as the **sole** inter-file communication channel. Never use `_G` for data sharing between files — it pollutes the namespace, causes taint, and is visible to every addon in the client.

**Lua 5.0 note**: The vararg `...` syntax to capture `addonName, addonTable` works differently in 5.0. In 5.0, you must use the implicit `arg` table:

```lua
-- Lua 5.1+:
local addonName, addonTable = ...

-- Lua 5.0:
local addonName = arg[1]
local addonTable = arg[2]

-- Universal (works on 5.0–5.4):
local addonName  = select and select(1, ...) or (arg and arg[1])
local addonTable = select and select(2, ...) or (arg and arg[2])
```

## Proxy / Facade Pattern

Wrap a complex subsystem behind a simplified interface:

```lua
local QuestieAPI = {}

function QuestieAPI:GetQuestName(questId)
    local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
    local data = QuestieDB and QuestieDB:GetQuest(questId)
    return data and data.name or "Unknown Quest"
end
```

## Functional Patterns

Lua supports higher-order functions. Use them for data transformations:

```lua
-- map: Transform each element (uses ipairs for 5.0 compat)
local function map(t, fn)
    local result = {}
    for i, v in ipairs(t) do result[i] = fn(v, i) end
    return result
end

-- filter: Keep elements matching predicate
local function filter(t, predicate)
    local result = {}
    for i, v in ipairs(t) do
        if predicate(v, i) then table.insert(result, v) end
    end
    return result
end

-- reduce: Fold elements into a single value
local function reduce(t, fn, initial)
    local acc = initial
    for i, v in ipairs(t) do acc = fn(acc, v, i) end
    return acc
end

-- Compose: Right-to-left function composition
-- Note: Uses arg.n in 5.0 since select() doesn't exist
local function compose(...)
    local fns = select and { ... } or arg
    local n = select and select("#", ...) or fns.n
    return function(x)
        for i = n, 1, -1 do x = fns[i](x) end
        return x
    end
end
```

## Enumerations

Lua has no native enums. Simulate with constant tables. Optionally freeze with `readOnly()` (see coding-style.md):

```lua
local DebugLevel = {
    CRITICAL = 1,
    INFO     = 2,
    DEVELOP  = 3,
}

local QuestFlags = {
    SHARABLE    = 0x0008,
    DAILY       = 0x1000,
    WEEKLY      = 0x8000,
    AUTO_ACCEPT = 0x80000,
}
```

## Weak Tables

Use weak references for caches that should not prevent garbage collection:

```lua
-- Values are weak: GC can collect them when no other references exist
local textureCache = setmetatable({}, { __mode = "v" })

function getTexture(path)
    local cached = textureCache[path]
    if cached then return cached end
    local tex = loadTexture(path)
    textureCache[path] = tex
    return tex
end
```

| Mode | Meaning |
|------|---------|
| `__mode = "v"` | Weak values — GC collects values with no other refs |
| `__mode = "k"` | Weak keys — GC collects keys with no other refs |
| `__mode = "kv"` | Both weak — GC collects either direction |

**Ephemeron tables (5.2+)**: In Lua 5.2, weak tables with weak keys behave as **ephemeron tables**. In an ephemeron table, a value is considered reachable only if its key is reachable. If the only reference to a key comes through its value (e.g., a table used as both key and value), the entry is removed. This prevents reference cycles from keeping entries alive and is the correct behavior for cache patterns. In 5.0/5.1, a strong value could keep a weak-keyed entry alive even if the key was unreachable.

**Mode reference**:
| Mode | When entry is removed |
|------|----------------------|
| `"v"` | Value is garbage-collectable and no other references exist |
| `"k"` | Key is garbage-collectable and no other references exist |
| `"kv"` | Either key or value is independently collectable |
