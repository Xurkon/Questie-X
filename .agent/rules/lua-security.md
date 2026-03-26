---
paths:
  - "**/*.lua"
---
# Lua Security

> This file extends [common/security.md](../common/security.md) with Lua specific content.

## Mandatory Security Checks (Lua)

Before ANY commit of Lua code:
- [ ] No hardcoded secrets (API keys, passwords, tokens, webhook URLs)
- [ ] All user/external inputs validated before processing
- [ ] No `loadstring` / `load` with untrusted input
- [ ] No `os.execute` / `io.popen` with user-controlled strings
- [ ] No unintentional global variables (verified by `luacheck` with `std = "none"`)
- [ ] Error messages don't leak file paths, stack traces, or internal state
- [ ] SavedVariables don't store sensitive data in plaintext
- [ ] Plugin sandbox restricts access to dangerous libraries

## Secrets Management

- NEVER hardcode API keys, tokens, or credentials in Lua source files
- Use environment variables (`os.getenv("API_KEY")`) for CLI/server Lua
- Use secure SavedVariables with obfuscation for addon credentials (if absolutely necessary)
- Fail fast if required secrets are missing at startup
- Keep `.env` files and SavedVariables files in `.gitignore`

```lua
-- BAD: Hardcoded secret
local API_KEY = "sk-abc123secretkey"

-- GOOD: Environment variable with early validation
local function loadApiKey()
    local key = os.getenv("API_KEY")
    if not key or key == "" then
        error("API_KEY environment variable must be set")
    end
    return key
end
```

## `loadstring` and Dynamic Code Execution

`loadstring` (Lua 5.0/5.1) / `load` (Lua 5.2+) execute arbitrary strings as code. This is the **single most critical attack surface** in Lua.

**Version note**: `loadstring` exists in Lua 5.0 and 5.1. In Lua 5.2+, `loadstring` was removed and its functionality was merged into `load`. In Lua 5.0, `loadlib` (not `loadstring`) is also available for loading C libraries — it was moved to `package.loadlib` in 5.1 and later.

### Never Do This

```lua
-- CRITICAL RISK: Arbitrary code execution from user input
local fn = loadstring(userInput)
if fn then fn() end

-- CRITICAL RISK: Loading from untrusted file path
local fn = loadfile(userSuppliedPath)
if fn then fn() end

-- CRITICAL RISK: Dynamic code from network data
local fn = loadstring(httpResponse.body)
```

### When It Is Acceptable

- Deserializing data from a **trusted, internal source** (e.g., `AceSerializer` output from your own SavedVariables written by your own addon)
- Compile-time / build tooling code that never runs in production
- MUST have a `-- SECURITY: loadstring used here because ...` comment

### Alternatives to loadstring

| Problem | Use Instead |
|---------|-------------|
| Dynamic function dispatch | Function lookup tables |
| Computed field access | `rawget(table, key)` |
| Data deserialization | `AceSerializer`, JSON parser, custom binary format |
| Template expansion | `string.format` or `gsub` with controlled patterns |

```lua
-- BAD: Dynamic dispatch via loadstring
local fn = loadstring("return " .. actionName .. "()")

-- GOOD: Function dispatch table
local actions = {
    attack = function() return doAttack() end,
    defend = function() return doDefend() end,
    heal   = function() return doHeal() end,
}
local fn = actions[actionName]
if fn then fn() end
```

### Bytecode Loading (5.2+ Security Risk)

Starting in Lua 5.2, bytecode verification was removed. Loading untrusted binary data via `load()` or `loadfile()` can execute arbitrary code even without `loadstring`. **Always restrict to text-only mode when loading untrusted input:**

```lua
-- CRITICAL: restrict to text mode when source is untrusted
-- The 4th arg 't' = text only, 'b' = binary only, 'bt' = both (default, unsafe)
-- In 5.2: mode is 3rd arg; in 5.3+: mode is 4th arg (after chunk name)
local fn, err = load(untrusted_source, "=(untrusted)", nil, "t")

-- Safe alternative: explicit source validation before loading
if not isKnownTrustedSource(source) then
    return nil, "Refused to load untrusted source"
end

-- In Lua 5.1 and earlier, load() does not accept a mode parameter.
-- loadstring() only accepts text, so binary injection is not a risk via loadstring.
-- However, loadfile() can load binary chunks in all versions — validate files first.
```

*Source: Lua 5.2 Manual §8.2 — "Lua does not have bytecode verification anymore. So, all functions that load code (load and loadfile) are potentially insecure when loading untrusted binary data."*

## Global Namespace Leakage

Every variable written without `local` is an implicit global in Lua. This has severe consequences:

1. **Cross-addon contamination**: Any addon can read or overwrite your globals
2. **Information leak**: Internal data structures become publicly visible
3. **Taint**: In WoW, global writes from a tainted call stack propagate taint to the written variable, which then propagates to anything that reads it
4. **Silent bugs**: Typos in variable names silently create new globals instead of erroring

### Prevention

```lua
-- Use luacheck with std = "none" to catch ALL undeclared globals
-- See hooks.md for .luacheckrc configuration

-- BAD: Leaks NPC data into the global namespace
QuestieX_WotLKDB_npc = addonTable.npcData  -- Visible to every addon!

-- GOOD: Share via Plugin API (private channel)
local plugin = QuestiePluginAPI:RegisterPlugin("WotLKDB")
plugin.data = addonTable  -- Only accessible through the registry
```

### Runtime Global Access Monitoring (Development)

For debugging, use a `__newindex` hook on `_G` to detect unexpected global writes:

```lua
-- WARNING: Development only — remove before release
if DEBUG_MODE then
    setmetatable(_G, {
        __newindex = function(t, k, v)
            local info = debug.getinfo(2, "Sl")
            print(string.format(
                "WARNING: Global write: %s = %s at %s:%d",
                tostring(k), tostring(v),
                info.short_src, info.currentline
            ))
            rawset(t, k, v)
        end
    })
end
```

## Input Validation at System Boundaries

Validate all external input — user text, network data, saved variable files, addon communication — before processing:

```lua
-- GOOD: Validate before use, return nil + error for invalid input
local function safeGetNPC(npcId)
    if type(npcId) ~= "number" then
        return nil, "npcId must be a number, got: " .. type(npcId)
    end
    if npcId <= 0 or npcId ~= math.floor(npcId) then
        return nil, "npcId must be a positive integer, got: " .. tostring(npcId)
    end
    return QuestieDB:GetNPC(npcId)
end

-- GOOD: Validate deserialized data structure
local function validateConfig(config)
    if type(config) ~= "table" then return nil, "config must be a table" end
    if type(config.version) ~= "string" then return nil, "config.version must be a string" end
    if type(config.maxLevel) ~= "number" then return nil, "config.maxLevel must be a number" end
    if config.maxLevel < 1 or config.maxLevel > 100 then
        return nil, "config.maxLevel out of range: " .. config.maxLevel
    end
    return config
end
```

### SavedVariables Validation

Always validate SavedVariables on load — they can be manually edited by users or corrupted:

```lua
function Questie:LoadSavedVariables()
    local sv = QuestieSV
    if type(sv) ~= "table" then
        -- Corrupted or missing — reset to defaults
        QuestieSV = self:GetDefaults()
        return
    end

    -- Validate schema version
    if type(sv.version) ~= "number" or sv.version < MIN_SV_VERSION then
        -- Schema too old — migrate or reset
        QuestieSV = self:MigrateSV(sv)
    end
end
```

## File I/O (Standalone Lua)

In sandboxed environments (WoW), `io` is not available. In standalone scripts:

### Path Traversal Prevention

```lua
-- BAD: User-controlled path — allows directory traversal
local f = io.open(userPath, "r")

-- GOOD: Validate path is within allowed directory
local function safeOpen(filename, mode)
    -- Strip path traversal attempts
    if filename:find("%.%.") or filename:find("[/\\]") then
        return nil, "Invalid filename: path traversal detected"
    end
    local fullPath = SAFE_DIRECTORY .. "/" .. filename
    return io.open(fullPath, mode)
end
```

### Resource Management

Always close file handles to prevent resource exhaustion:

```lua
-- BAD: Handle leak on error
local f = io.open("data.txt", "r")
local content = f:read("*a")  -- If this errors, f is never closed
f:close()

-- GOOD: Protected read with guaranteed close
local function readFile(path)
    local f, err = io.open(path, "r")
    if not f then return nil, err end

    local ok, content = pcall(f.read, f, "*a")
    f:close()  -- Always close, even if read failed

    if not ok then return nil, content end
    return content
end
```

## Shell Injection (`os.execute` / `io.popen`)

NEVER pass user-controlled strings to shell commands:

```lua
-- CRITICAL RISK: Shell injection
os.execute("grep " .. userInput .. " /var/log/app.log")
-- An attacker sends: "; rm -rf / #" as userInput

-- CRITICAL RISK: Same with io.popen
local handle = io.popen("curl " .. userUrl)

-- SAFE: Use validated, sanitized inputs or avoid shell entirely
local function safeLookup(word)
    -- Validate: alphanumeric only
    if not word:match("^%w+$") then
        return nil, "Invalid input: must be alphanumeric"
    end
    -- Now safe to use in a controlled command
    return os.execute("grep -w " .. word .. " dictionary.txt")
end
```

## Sandbox Design for Plugin Systems

When building systems that run third-party plugin code, restrict the execution environment:

### Environment Restriction

```lua
-- Create a restricted environment for plugin execution
local function createSandbox()
    return {
        -- Safe builtins
        print    = print,
        pairs    = pairs,
        ipairs   = ipairs,
        next     = next,
        type     = type,
        tostring = tostring,
        tonumber = tonumber,
        select   = select,
        unpack   = unpack,
        error    = error,
        pcall    = pcall,

        -- Safe libraries (read-only subsets)
        string = {
            format = string.format,
            find   = string.find,
            sub    = string.sub,
            len    = string.len,
            lower  = string.lower,
            upper  = string.upper,
        },
        table = {
            insert = table.insert,
            remove = table.remove,
            sort   = table.sort,
            concat = table.concat,
        },
        math = {
            floor = math.floor,
            ceil  = math.ceil,
            min   = math.min,
            max   = math.max,
            abs   = math.abs,
        },

        -- EXPLICITLY EXCLUDED:
        -- os           (shell access, file system)
        -- io           (file system access)
        -- debug        (CRITICAL: debug.getupvalue/setupvalue can read/modify
        --              any upvalue in any function, bypassing sandbox entirely.
        --              debug.getlocal/setlocal can read/modify locals on the
        --              call stack. debug.setmetatable bypasses __metatable guards.
        --              Never expose ANY debug library function to untrusted code.)
        -- load         (arbitrary code execution)
        -- loadstring   (arbitrary code execution)
        -- loadfile     (arbitrary code execution)
        -- dofile       (arbitrary code execution)
        -- rawget       (bypass metamethod guards)
        -- rawset       (bypass metamethod guards)
        -- setmetatable (override protections)
        -- getmetatable (inspect protected tables)
    }
end

-- Execute plugin code in sandbox
-- Version-gated: setfenv for 5.0/5.1, _ENV wrapper for 5.2+
local function runInSandbox(code, sandbox)
    if setfenv then
        -- Lua 5.0 / 5.1: setfenv directly restricts the environment
        local fn, err = loadstring(code)
        if not fn then return nil, "Compile error: " .. err end
        setfenv(fn, sandbox)
        return pcall(fn)
    else
        -- Lua 5.2+: use load() with custom _ENV
        -- The 4th arg to load() sets the environment
        local fn, err = load(code, "=(sandbox)", "t", sandbox)
        if not fn then return nil, "Compile error: " .. err end
        return pcall(fn)
    end
end
```

**Why this matters**: `setfenv`/`getfenv` were removed in Lua 5.2. Code that relies on `setfenv` for sandboxing will silently fail or error on 5.2+. Always use the version-gated pattern above.

### Resource Limiting

For untrusted code, add execution timeout via `debug.sethook` (available in Lua 5.0+):

```lua
local function runWithTimeout(fn, maxInstructions)
    maxInstructions = maxInstructions or 1000000
    local count = 0
    debug.sethook(function()
        count = count + 1
        if count > maxInstructions then
            error("Execution limit exceeded: suspected infinite loop")
        end
    end, "", 1)  -- Hook every instruction

    local ok, result = pcall(fn)
    debug.sethook()  -- Remove hook
    return ok, result
end
```

**Version note**: `debug.sethook` is available in Lua 5.0+ and works identically across all versions. The `debug` library itself may be stripped in sandboxed environments (WoW does not expose the full `debug` library to addons).

## Dependency Security

- Audit third-party Lua libraries (LuaRocks packages) for known CVEs before vendoring
- Pin dependency versions in rockspec or lockfile — never use floating `latest`
- Prefer small, auditable libraries over large frameworks for security-sensitive code
- Vendor critical dependencies (copy into project) rather than relying on external resolution
- Review transitive dependencies: `luarocks show <package>` lists deps

```bash
# List all installed packages and versions
luarocks list

# Show package info including dependencies
luarocks show lpeg

# Install specific version (avoid floating latest)
luarocks install luacheck 1.1.2
```

## Error Message Security

Never expose internal details in user-facing error messages:

```lua
-- BAD: Leaks internal path and database schema
error("Failed to load NPC " .. npcId .. " from "
    .. dbPath .. ": column 'rawdata' is nil at index " .. idx)

-- GOOD: Generic user message, detailed internal log
Questie:Debug(Questie.DEBUG_CRITICAL,
    format("[QuestieDB] GetNPC failed: npcId=%d, rawdata=nil, source=%s",
        npcId, dbPath))
return nil  -- Return nil to caller, no internal details
```

## WoW-Specific: Taint and Secure Code

Taint is a security mechanism in the WoW client that prevents addon code from executing protected actions (opening bags during combat, using abilities, etc.). Understanding taint is CRITICAL for WoW addon development.

### Taint Propagation Rules

1. Any variable written from insecure (addon) code is **tainted**
2. Any variable read from tainted state becomes **tainted**
3. Taint propagates through function calls, table reads, and variable assignments
4. Protected API calls from a tainted call stack trigger `ADDON_ACTION_BLOCKED`

### Common Taint Sources and Fixes

| Taint Source | Why It Taints | Fix |
|-------------|---------------|-----|
| `_G.MyVar = value` | Global write from addon code | Use `addonTable` instead |
| `loadstring(code)()` | Compiled code is always tainted | Use function dispatch tables |
| Overwriting Blizzard functions | Replaces secure with insecure | Use `hooksecurefunc()` (post-hook) |
| Writing from `OnUpdate` | Frequent tainted writes | Move to `ADDON_LOADED` or `PLAYER_LOGIN` |
| `rawset(_G, k, v)` | Bypasses metamethods but still taints | Avoid; use local module tables |
| Reading a tainted global | Taint propagates to reader | Read during `ADDON_LOADED` or cache locally |

### Safe WoW API Patterns

```lua
-- GOOD: Post-hook (does not replace the original, does not taint)
hooksecurefunc("QuestLogFrame_Update", function()
    -- Your code runs AFTER the original — cannot taint it
end)

-- BAD: Function replacement (replaces secure with insecure = taint)
local original = QuestLogFrame_Update
QuestLogFrame_Update = function(...)  -- Now tainted!
    original(...)
    myCustomLogic()
end

-- GOOD: Combat guard for protected actions
local function safeAction()
    if InCombatLockdown() then
        -- Queue for after combat
        return
    end
    -- Safe to call protected APIs
end
```

## Security Response Protocol

If a security issue is found in Lua code:
1. **STOP** immediately — do not ship the code
2. Use **security-reviewer** agent
3. Fix CRITICAL issues before continuing
4. If secrets were exposed, rotate them immediately
5. Audit the entire codebase for similar patterns
6. Add `luacheck` rules to prevent recurrence
7. Add regression tests for the specific vulnerability

## References

See skill: `security-review` for general security checklists applicable across all languages.
