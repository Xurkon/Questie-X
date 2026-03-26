---
paths:
  - "**/*.lua"
---
# Lua Coding Style

> This file extends [common/coding-style.md](../common/coding-style.md) with Lua specific content.

## Version Compatibility Matrix

These rules target **universal Lua coverage** across 5.0, 5.1, 5.2, 5.3, and 5.4. When a feature differs between versions, use the portable pattern or guard with a version check.

| Feature | 5.0 | 5.1 | 5.2 | 5.3 | 5.4 | Portable Pattern |
|---------|-----|-----|-----|-----|-----|------------------|
| Length operator `#` | ❌ `table.getn` | ✅ | ✅ | ✅ | ✅ | `table.getn(t)` or `#t` with guard |
| Varargs `...` as expr | ❌ `arg` table | ✅ | ✅ | ✅ | ✅ | See Varargs section |
| `select()` | ❌ | ✅ | ✅ | ✅ | ✅ | Guard: `if select then ... else arg[i]` |
| `math.mod` / `math.fmod` | ✅ `math.mod` | ✅ `math.fmod` | ✅ `math.fmod` | ✅ | ✅ | `math.fmod or math.mod` |
| `string.gmatch` | ❌ `string.gfind` | ✅ | ✅ | ✅ | ✅ | `string.gmatch or string.gfind` |
| `setfenv`/`getfenv` | ✅ | ✅ | ❌ `_ENV` | ❌ | ❌ | Version-gated sandbox |
| `unpack()` global | ✅ | ✅ | ❌ `table.unpack` | ❌ | ❌ | `unpack or table.unpack` |
| `xpcall` extra args | ❌ | ❌ | ✅ | ✅ | ✅ | Wrap in closure for 5.0/5.1 |
| `goto` statement | ❌ | ❌ | ✅ | ✅ | ✅ | Avoid; use early return |
| Integer subtype | ❌ | ❌ | ❌ | ✅ | ✅ | All numbers are doubles in 5.0–5.2 |
| Bitwise operators | ❌ | ❌ | ✅ `bit32` lib | ✅ native (`bit32` deprecated) | ✅ native | `bit32` lib on 5.2; native ops on 5.3+ |
| `__gc` for tables | ❌ | ❌ | ✅ | ✅ | ✅ | Only for userdata in 5.0/5.1 |
| `__len` for tables | ❌ | ❌ (userdata only) | ✅ | ✅ | ✅ | `rawlen` or custom function; 5.1 `__len` only for userdata |
| `table.move` | ❌ | ❌ | ❌ | ✅ | ✅ | Manual loop |
| `table.foreach`/`foreachi` | ✅ | ✅ (deprecated) | ❌ removed | ❌ | ❌ | Use `pairs`/`ipairs` (5.0+) |
| `table.setn` | ✅ | ✅ (deprecated) | ❌ removed | ❌ | ❌ | Track length manually |
| `table.maxn` | ❌ | ✅ | ✅ (deprecated) | ❌ removed | ❌ | Manual loop over keys |
| `package` table | ❌ `loadlib` | ✅ | ✅ | ✅ | ✅ | Guard `package and package.path` |
| `pcall` extra args | ✅ | ✅ | ✅ | ✅ | ✅ | Universal |
| `coroutine.status` | ✅ | ✅ | ✅ | ✅ | ✅ | Universal |
| `table.pack` | ❌ | ❌ | ✅ | ✅ | ✅ | `{n = select("#", ...), ...}` |
| `rawlen()` | ❌ | ❌ | ✅ | ✅ | ✅ | `rawlen or function(t) return #t end` |
| `loadstring` | ✅ | ✅ | ❌ (deprecated→`load`) | ❌ | ❌ | `loadstring or load` |
| `string.pack/unpack` | ❌ | ❌ | ❌ | ✅ | ✅ | External `struct` lib for older versions |
| `utf8` library | ❌ | ❌ | ❌ | ✅ | ✅ | External `lua-utf8` lib for older |
| `package.loaders` | ❌ | ✅ | ❌→`.searchers` | ❌ | ❌ | `package.loaders or package.searchers` |
| `coroutine.isyieldable` | ❌ | ❌ | ❌ | ✅ | ✅ | Guard: `coroutine.isyieldable and ...` |
| `math.atan2` | ✅ | ✅ | ✅ | ✅ | ✅ | `math.atan(y, x)` — note argument order is (y, x), not (x, y) |
| `math.log10` | ❌ | ✅ | ✅ | ❌ removed | ❌ | `math.log(x, 10)` or `math.log(x) / math.log(10)` |
| `math.pow` | ✅ | ✅ | ✅ | ✅ | ✅ | `x ^ y` (native operator) or `math.pow(x, y)` |
| `math.log(x, base)` | ❌ | ❌ | ✅ | ✅ | ✅ | `math.log(x) / math.log(base)` for portable base |
| Floor division `//` | ❌ | ❌ | ❌ | ✅ | ✅ | `math.floor(a / b)` for 5.0–5.2 |
| `math.cosh/sinh/tanh` | ❌ | ✅ | ✅ | ❌ deprecated | ❌ | Implement manually or use external lib |
| `math.frexp`/`math.ldexp` | ❌ | ✅ | ✅ | ❌ deprecated | ❌ | `x * 2.0^exp` for ldexp; external lib for frexp |
| `coroutine.close` | ❌ | ❌ | ❌ | ❌ | ✅ | Guard: `coroutine.close and coroutine.close(co)` |
| `warn()` function | ❌ | ❌ | ❌ | ❌ | ✅ | Guard: `if warn then warn(msg) end` |
| `<const>`/`<close>` attrs | ❌ | ❌ | ❌ | ❌ | ✅ | Use `local` without attrs on 5.0–5.3 |
| `__le` metamethod required | ❌ (derived from `__lt`) | ❌ | ❌ | ❌ | ✅ (must define explicitly) | Always define both `__lt` and `__le` |
| String→number coercion | ✅ auto | ✅ auto | ✅ auto | ✅ auto | ❌ removed from core | Use explicit `tonumber()` for portability |
| Long string nesting `[[]]` | ✅ (nestable) | ❌ (no nesting) | ❌ | ❌ | ❌ | Use `[=[...]=]` for nested long strings |
| `%z` pattern class | ✅ | ✅ | ❌ deprecated | ❌ | ❌ | Use literal `\0` to match the null character (ASCII 0) in patterns (5.2+) |
| `__ipairs` metamethod | ❌ | ❌ | ✅ | ❌ deprecated | ❌ | Avoid; `ipairs` uses raw integer keys |
| Float→string `.0` suffix | ❌ `2.0`→`"2"` | ❌ | ❌ | ✅ `2.0`→`"2.0"` | ✅ | Use `string.format` for consistent formatting |
| `print` calls `tostring` | ✅ | ✅ | ✅ | ✅ | ❌ (hardwired) | Use `__tostring` metamethod for custom output |
| `math.random` auto-seeded | ❌ | ❌ | ❌ | ❌ | ✅ (new PRNG) | Call `math.randomseed` explicitly on 5.0–5.3 |
| `math.log(x, base)` | ❌ | ❌ | ✅ | ✅ | ✅ | `math.log(x) / math.log(base)` for base argument |
| Floor division `//` | ❌ | ❌ | ❌ | ✅ | ✅ | `math.floor(a / b)` for 5.0–5.2 |
| `io.lines` return count | 1 | 1 | 1 | 1 | 4 (line, extra, line number, error) | Wrap in `(io.lines(...))` to get 1 value |
| `collectgarbage("count")` | N/A | 2 values | 2 values | 1 value | 1 value | Use `math.floor(collectgarbage("count"))` |

### Cross-Version Compatibility Shim

Place at the top of your entry point file to normalize APIs across versions:

```lua
-- compat.lua: Universal Lua 5.0–5.4 shim
-- Place at top of your entry point; all other files use these locals.

-- Core builtins that moved between versions
local unpack       = unpack or table.unpack               -- 5.2 moved to table
local getn         = table.getn or function(t) return #t end  -- 5.0 has no #
local setn         = table.setn or function() end          -- 5.0 tracks length via setn
local maxn         = table.maxn or function(t)             -- removed in 5.3
    local n = 0
    for k in pairs(t) do
        if type(k) == "number" and k > n then n = k end
    end
    return n
end

-- String library renames
local gmatch       = string.gmatch or string.gfind        -- 5.0 uses gfind

-- Math library renames
local fmod         = math.fmod or math.mod                -- 5.0 uses math.mod

-- Module system: 5.0 has no package table
local loadlib      = package and package.loadlib or loadlib

-- Vararg helpers
local getVarargCount = select                              -- nil in 5.0
    and function(...) return select("#", ...) end          -- 5.1+: use select
    or  function() return arg and arg.n or 0 end           -- 5.0: use arg.n

-- Code loading: loadstring renamed to load in 5.2
local loadstring    = loadstring or load                   -- 5.2+ removed loadstring

-- Raw operations: rawlen added in 5.2 (bypasses __len)
local rawlen        = rawlen or function(v) return #v end  -- fallback uses #

-- table.pack: added in 5.2; polyfill for 5.0/5.1
local table_pack    = table.pack or function(...)
    return { n = select and select("#", ...) or (arg and arg.n or 0), ... }
end
```

## Formatting

- **StyLua** for code formatting — always run `stylua .` before committing
- **Luacheck** for lints — `luacheck . --no-color` (treat warnings as CI failures)
- 4-space indent (StyLua default)
- Max line width: 120 characters
- Trailing commas in multi-line table constructors (prevents noisy diffs)

## Naming

Follow standard Lua conventions:
- `camelCase` for local variables, functions, method names
- `PascalCase` for modules, "classes" (tables used as classes via metatables)
- `UPPER_SNAKE_CASE` for constants and enum-like values
- `_camelCase` (leading underscore) for private/internal helpers
- `UPPER_SNAKE_CASE` for WoW event strings (`"PLAYER_LOGIN"`, `"QUEST_ACCEPTED"`)

```lua
-- GOOD
local QuestieDB = {}           -- PascalCase module
local MAX_RETRIES = 3          -- UPPER_SNAKE constant
local questId = 10141          -- camelCase local
local function _countTable(t)  -- _camelCase private helper
```

## Scoping: local Is Non-Negotiable

Every variable MUST be `local` unless explicitly required as a global. Globals leak into `_G`, pollute the namespace, introduce untraceable coupling between files, and cause **ADDON_ACTION_BLOCKED** taint in WoW sandboxes.

```lua
-- BAD: Implicit global — leaks into _G, causes taint
myValue = 10

-- GOOD: Explicit local
local myValue = 10
```

**Global caching**: Cache frequently-called global functions into module-level locals. This provides measurable performance improvement in tight loops (Lua resolves locals via stack slot, globals via hash lookup into `_G`).

```lua
-- Cache at file / module top — BEFORE any function definitions
local type       = type
local pairs      = pairs
local ipairs     = ipairs
local next       = next
local tostring   = tostring
local tinsert    = table.insert
local tremove    = table.remove
local tconcat    = table.concat
local format     = string.format
local floor      = math.floor
local max        = math.max
local min        = math.min
local coroutine  = coroutine
local setmetatable = setmetatable
local getmetatable = getmetatable
```

## Immutability

> **Language note**: This rule overrides [common/coding-style.md](../common/coding-style.md)'s strict immutability. Lua tables are mutable by design and creating fresh copies on every update is prohibitively expensive for large data sets (e.g., 40,000+ NPC records). Use immutability where practical; use controlled mutation with clear ownership semantics where performance demands it.

When immutability is practical (configuration, options, small payloads):

```lua
-- GOOD — returns a new table with the field updated
local function withField(original, key, value)
    local copy = {}
    for k, v in pairs(original) do copy[k] = v end
    copy[key] = value
    return copy
end
```

When mutation is necessary (hot paths, large tables, WoW frame pools), document ownership:

```lua
-- ACCEPTABLE — mutation of owned table, clearly documented
--- Compiles NPC data into the binary cache. Mutates QuestieDB.npcData in place
--- because copying 40k records per compile is prohibitively expensive.
function QuestieDBCompiler:CompileNPCData(sourceData, targetTable)
    for id, data in pairs(sourceData) do
        targetTable[id] = self:EncodeRow(data)
    end
end
```

Use **read-only proxies** for tables that must not be modified after initialization:

```lua
local function readOnly(t)
    return setmetatable({}, {
        __index = t,
        __newindex = function(_, k, _)
            error(format("Attempt to modify read-only table at key: %s", tostring(k)), 2)
        end,
        -- table.getn for 5.0 compat; # for 5.1+
        __len = function() return (table.getn or rawlen or function(x) return #x end)(t) end,
    })
end

local QUEST_FLAGS = readOnly({ SHARABLE = 0x0008, DAILY = 0x1000 })
```

## Tables

### Construction

Prefer table literals over sequential assignment. The compiler generates fewer instructions and programmer intent is clearer:

```lua
-- GOOD: Single allocation, clear structure
local config = {
    maxRetries  = 3,
    timeout     = 5,
    version     = "1.4.7",
    pluginNames = { "WotLKDB", "TurtleDB" },
}

-- BAD: Multiple allocations, fragmented intent
local config = {}
config.maxRetries = 3
config.timeout = 5
config.version = "1.4.7"
config.pluginNames = {}
config.pluginNames[1] = "WotLKDB"
config.pluginNames[2] = "TurtleDB"
```

### Array Building in Loops

Use `t[#t + 1]` (fastest in Lua 5.1+) or `tinsert`. In Lua 5.0, use `tinsert` or track an index manually since `#` does not exist:

```lua
-- GOOD: Fastest array append (Lua 5.1+)
local results = {}
for id, data in pairs(sourceData) do
    results[#results + 1] = data
end

-- GOOD: Works on ALL versions (5.0–5.4)
local results = {}
for id, data in pairs(sourceData) do
    tinsert(results, data)
end

-- GOOD: Manual index tracking (universal, fastest in 5.0)
local results = {}
local n = 0
for id, data in pairs(sourceData) do
    n = n + 1
    results[n] = data
end
```

### Iteration Patterns

| Use case | Pattern | Lua versions | Notes |
|----------|---------|-------------|-------|
| Sequential array (no holes) | `for i = 1, #t do` | 5.1+ | Fastest; no function call overhead |
| Sequential array (universal) | `for i = 1, table.getn(t) do` | 5.0+ | Use `getn` shim for 5.0 compat |
| Array with value | `for i, v in ipairs(t) do` | 5.0+ | Stops at first `nil` hole |
| Dictionary / sparse table | `for k, v in pairs(t) do` | 5.0+ | Unordered; processes every key |
| Universal / taint-free | `for k, v in next, t do` | 5.0+ | Equivalent to `pairs` but avoids metamethod |
| Empty-check | `if next(t) == nil then` | 5.0+ | Only reliable way |
| Counting elements | Custom `_countTable` function | 5.0+ | `#t`/`table.getn` only counts array part |

```lua
-- Empty-check: ONLY correct way
if next(myTable) == nil then
    -- Table is truly empty (no array or hash keys)
end

-- WRONG: Unreliable for dictionaries and sparse arrays
if #myTable == 0 then -- BROKEN on { a = 1, b = 2 }
```

### Holes in Arrays

The `#` operator is **undefined** on sparse arrays (arrays with `nil` gaps). If holes are possible, track length with a counter field or use a dedicated array class.

```lua
-- WRONG: Undefined behavior with holes
local t = { 1, nil, 3 }
print(#t)  -- Could be 1 or 3 (implementation-dependent)

-- CORRECT: Track length explicitly
local t = { n = 3; 1, nil, 3 }
for i = 1, t.n do print(t[i]) end
```

### Table Recycling and Wipe

Reuse tables to reduce GC pressure in hot paths. Use `wipe()` (WoW) or manual niling:

```lua
-- WoW environment: wipe() clears all keys
wipe(myTable)

-- Standard Lua: manual clear
for k in pairs(myTable) do myTable[k] = nil end
```

## Functions

- Keep functions under 50 lines. Extract helpers prefixed with `_`.
- **Return early** to flatten nesting. Lua has no guard clauses, so explicit early returns are the idiomatic substitute.
- Avoid deep nesting (> 4 levels). Refactor into helper functions.

```lua
-- BAD: Deep nesting
function processQuest(questId)
    if questId then
        local data = QuestieDB.questData[questId]
        if data then
            local name = data[1]
            if name then
                -- 4 levels deep...
            end
        end
    end
end

-- GOOD: Early returns flatten the code
function processQuest(questId)
    if not questId then return end
    local data = QuestieDB.questData[questId]
    if not data then return end
    local name = data[1]
    if not name then return end
    -- Proceed at 1 level of nesting
end
```

### Default Arguments

Lua has no native defaults. Use the `or` idiom for simple cases, explicit `nil` checks for values where `false` or `0` are valid:

```lua
-- Simple default (WRONG if false/0 are valid values)
local function greet(name, greeting)
    name     = name     or "Adventurer"
    greeting = greeting or "Hello"
    return format("%s, %s!", greeting, name)
end

-- Precise default (handles false/0 correctly)
local function setEnabled(flag)
    if flag == nil then flag = true end  -- Default to true; false is a valid input
end
```

### Varargs

Varargs behavior differs significantly across Lua versions:

| Version | Access pattern | Length |
|---------|---------------|--------|
| 5.0 | `arg` table (auto-created) | `arg.n` |
| 5.1+ | `...` as expression | `select("#", ...)` |

```lua
-- Lua 5.1+: Use select for length (handles trailing nil)
local function logAll(...)
    local n = select("#", ...)
    for i = 1, n do
        local v = select(i, ...)
        print(format("arg[%d] = %s", i, tostring(v)))
    end
end

-- Lua 5.0: Use the implicit 'arg' table
local function logAll(...)  -- 5.0 creates 'arg' automatically
    for i = 1, arg.n do
        print(format("arg[%d] = %s", i, tostring(arg[i])))
    end
end

-- UNIVERSAL: Works on 5.0–5.4
local function logAll(...)
    local args = select and { n = select("#", ...), ... } or arg
    for i = 1, args.n do
        print(format("arg[%d] = %s", i, tostring(args[i])))
    end
end
```

## Strings

- **Short concatenation**: `..` is fine for 2–3 pieces.
- **Loop-built strings**: Use `table.concat` to avoid O(n²) intermediate string allocations.
- **Structured output**: Prefer `string.format` over `..` chains for readability and localization.

```lua
-- BAD: O(n²) string growth in a loop
local result = ""
for _, v in ipairs(data) do
    result = result .. tostring(v) .. ", "
end

-- GOOD: O(n) via table.concat
local parts = {}
for i, v in ipairs(data) do
    parts[i] = tostring(v)
end
local result = tconcat(parts, ", ")
```

## Error Handling

Lua uses `pcall` / `xpcall` as its try/catch equivalent. Use them at system boundaries (event handlers, plugin entry points, data loading). NEVER silently swallow errors.

```lua
-- pcall: Returns ok, result_or_error
local ok, err = pcall(function()
    dangerousOperation()
end)
if not ok then
    Questie:Debug(Questie.DEBUG_CRITICAL,
        "[Module] Operation failed: " .. tostring(err))
end

-- xpcall: Adds a message handler for stack traces
local function errorHandler(msg)
    return tostring(msg) .. "\n" .. debugstack(2)
end

local ok, result = xpcall(dangerousOperation, errorHandler)
```

**Version note**: In Lua 5.0 and 5.1, `xpcall` does NOT support passing arguments to the called function. Wrap in a closure:

```lua
-- WRONG in 5.0/5.1: xpcall does not forward args
local ok, result = xpcall(dangerousOp, errorHandler, arg1, arg2)

-- CORRECT (universal): Wrap in closure
local ok, result = xpcall(function()
    return dangerousOp(arg1, arg2)
end, errorHandler)
```

### Error Propagation

Lua uses the `success, result` multi-return pattern (no exceptions). Propagate errors by returning `nil, errorMessage`:

```lua
local function loadConfig(path)
    local f, err = io.open(path, "r")
    if not f then return nil, "Cannot open: " .. tostring(err) end

    local content = f:read("*a")
    f:close()

    if not content or content == "" then
        return nil, "Empty config file: " .. path
    end

    return content
end

-- Caller
local config, err = loadConfig("settings.ini")
if not config then
    error("Config load failed: " .. err)
end
```

## Nil Guards and Defensive Access

Always check `nil` before indexing. Chain guards for deep access:

```lua
-- Safe deep access (short-circuit on nil)
local name = myData and myData.info and myData.info.name

-- Explicit nil check when 0, false, or "" are valid values
if myData.count ~= nil then
    processCount(myData.count)  -- count could be 0
end
```

## Metatables

Use metatables for `__index` delegation, operator overloads, `__tostring`, and read-only enforcement. **Never** expose raw metatables of security-sensitive tables publicly; use `__metatable` to guard them.

```lua
-- Guard metatable from external manipulation
local Secret = {}
Secret.__index = Secret
Secret.__metatable = "Access denied"  -- getmetatable() returns this string

function Secret:New(value)
    return setmetatable({ _value = value }, Secret)
end
```

### Common Metamethods

| Metamethod | Purpose | Example |
|-----------|---------|---------|
| `__index` | Delegation / inheritance | Class systems, proxy tables |
| `__newindex` | Intercept writes | Read-only guards, validation |
| `__tostring` | Custom `tostring()` output | Debug printing |
| `__call` | Make a table callable | Functor pattern |
| `__len` | Custom `#` operator | Tables: 5.2+ only; userdata: 5.1+; ignored for tables in 5.0/5.1 |
| `__eq`, `__lt`, `__le` | Comparison operators | 5.0+; **5.4**: `__le` must be explicit (no longer derived from `__lt`) |
| `__gc` | Garbage collection finalizer | Tables: 5.2+ only; userdata: 5.0+ |
| `__close` | To-be-closed variable cleanup | 5.4+ only; `local x <close> = resource` |
| `__metatable` | Protect from `getmetatable` | Security-sensitive objects (5.0+) |
| `__concat` | Custom `..` operator | String-like objects (5.0+) |

## Coroutines

Use coroutines for cooperative multitasking — chunked database compilation, lazy iteration over large datasets, and frame-budgeted work in game engines.

**Critical Lua 5.0/5.1 limitation**: You cannot `yield` from inside a `pcall`/`xpcall` call. This throws `"cannot resume dead coroutine"`. Structure your code so the yield happens outside the protected call. This was fixed in Lua 5.2+ (yield-across-pcall support).

**Lua 5.0 note**: The full `coroutine` library (`create`, `resume`, `yield`, `status`, `wrap`) is available in Lua 5.0. However, in 5.0, you cannot yield from inside a C function, a metamethod, or an iterator — only from the main coroutine body. This restriction was relaxed in 5.1 (yield from iterators became possible) and further in 5.2 (yield across `pcall`/`xpcall`).

```lua
local fmod = math.fmod or math.mod  -- 5.0 has math.mod, 5.1+ has math.fmod

local co = coroutine.create(function()
    for i = 1, 10000 do
        processRecord(i)
        if fmod(i, 100) == 0 then   -- 5.0: no % operator; use fmod shim
            coroutine.yield()  -- Pause every 100 records
        end
    end
end)

-- Resume from a frame ticker (WoW: C_Timer.After, OnUpdate)
local function tick()
    if coroutine.status(co) ~= "dead" then
        local ok, err = coroutine.resume(co)
        if not ok then
            error("Coroutine error: " .. tostring(err))
        end
    end
end
```

## Numeric Precision

Lua 5.0–5.2 use 64-bit IEEE doubles for **all** numbers (no integer subtype). Lua 5.3+ introduced a separate integer subtype. Integers above 2^53 lose precision in double-only versions. Be aware of floating-point edge cases:

```lua
-- WRONG: Float comparison
if result == 0.3 then  -- May fail due to IEEE 754

-- CORRECT: Epsilon comparison
local EPSILON = 1e-9
if math.abs(result - 0.3) < EPSILON then
```

## Debug Output

- **No `print()` in production code** — it bypasses logging levels, cannot be filtered, and causes taint in WoW.
- Gate debug output behind a severity level flag.
- Use structured debug helpers.

```lua
-- BAD
print("Loading quest " .. questId)

-- GOOD
Questie:Debug(Questie.DEBUG_DEVELOP,
    format("[QuestieDB] Loading quest %d", questId))
```

## File Organization

MANY SMALL FILES > FEW LARGE FILES:
- 200–400 lines typical, 800 lines absolute maximum
- One module / class per file
- Group by feature/domain, not by type
- Data files (large lookup tables) may exceed 800 lines — exclude them from line-count rules

```text
Database/
├── QuestieDB.lua          # Core query interface
├── compiler.lua           # Binary compilation
├── Corrections/
│   ├── QuestCorrections.lua
│   └── NPCCorrections.lua
├── Data/
│   ├── questData.lua      # Raw data (exempt from 800-line rule)
│   └── npcData.lua
└── Zones/
    └── zoneDB.lua
```

## Code Quality Checklist

Before marking work complete on any Lua file:
- [ ] All variables are `local` (zero undeclared globals)
- [ ] Functions are under 50 lines
- [ ] Files are under 800 lines (data files exempt)
- [ ] No nesting deeper than 4 levels
- [ ] Error paths return `nil, errMsg` or log explicitly — never silently swallowed
- [ ] No hardcoded magic numbers (use named constants)
- [ ] Table iteration uses the correct primitive (`ipairs`, `pairs`, `next`, numeric `for`)
- [ ] String building in loops uses `table.concat`, not `..`
- [ ] `luacheck` passes with zero warnings
- [ ] `stylua --check` passes
