---
paths:
  - "**/tests/**/*.lua"
  - "**/*_spec.lua"
  - "**/*_test.lua"
---
# Lua Testing

> This file extends [common/testing.md](../common/testing.md) with Lua specific content.

## Test Frameworks

| Framework | Best for | Install |
|-----------|---------|---------|
| **Busted** | BDD-style unit/integration testing (most popular) | `luarocks install busted` |
| **LuaUnit** | xUnit-style, zero dependencies, minimal footprint | `luarocks install luaunit` |
| **Telescope** | Flexible, extensible, custom reporters | `luarocks install telescope` |
| **WoW mocks** | Game addon testing with C_API stubs | Custom `tests/mocks/` |

**Default choice**: Use **Busted** unless the project has an existing convention.

## Test Organization

```text
project/
├── src/                     # Production code
│   ├── Database/
│   │   └── QuestieDB.lua
│   └── Modules/
│       └── QuestieInit.lua
├── tests/
│   ├── mocks/               # Environment stubs
│   │   ├── wow_api.lua      # CreateFrame, C_Timer, GetTime stubs
│   │   ├── questie_env.lua  # QuestieLoader, Questie object stubs
│   │   └── saved_vars.lua   # SavedVariables mock
│   ├── unit/                # Unit tests (one per module)
│   │   ├── QuestieDB_spec.lua
│   │   ├── ZoneDB_spec.lua
│   │   └── compiler_spec.lua
│   ├── integration/         # Multi-module interaction tests
│   │   └── init_flow_spec.lua
│   └── helpers/             # Shared test utilities
│       ├── assertions.lua   # Custom assert functions
│       └── fixtures.lua     # Reusable test data
├── .busted                  # Busted configuration
└── .luacov                  # Coverage configuration
```

- Name spec files with `_spec.lua` suffix (Busted convention) or `_test.lua`
- Mirror the source directory structure in `tests/unit/`
- One spec file per production module

## Busted Configuration (`.busted`)

```lua
return {
    _all = {
        coverage = false,
        lpath = "src/?.lua;src/?/init.lua",
    },
    default = {
        verbose = true,
        output = "utfTerminal",
        ROOT = { "tests/" },
    },
    ci = {
        ROOT = { "tests/" },
        output = "TAP",
        coverage = true,
    },
}
```

## Unit Test Patterns

### Basic describe / it / before / after

```lua
describe("QuestieDB", function()
    local QuestieDB

    before_each(function()
        -- Fresh module instance per test (isolation)
        package.loaded["Database.QuestieDB"] = nil
        QuestieDB = require("Database.QuestieDB")
        QuestieDB.npcData = {
            [1]     = { "Hogger", 11, 0 },
            [26680] = { "Grizzly Hills NPC", 74, 1 },
        }
    end)

    after_each(function()
        package.loaded["Database.QuestieDB"] = nil
    end)

    describe(":GetNPC", function()
        it("returns NPC data for a valid id", function()
            local data = QuestieDB:GetNPC(1)
            assert.is_not_nil(data)
            assert.are.equal("Hogger", data.name)
        end)

        it("returns nil for an unknown id", function()
            assert.is_nil(QuestieDB:GetNPC(99999))
        end)

        it("returns nil for nil input", function()
            assert.is_nil(QuestieDB:GetNPC(nil))
        end)

        it("returns nil for non-numeric input", function()
            assert.is_nil(QuestieDB:GetNPC("abc"))
        end)
    end)
end)
```

### Pending Tests (Work-in-Progress)

Mark incomplete tests with `pending` — they appear in reports but do not fail:

```lua
pending("respects NPC blacklist during query")
pending("handles WotLK-only NPCs when plugin is absent")
```

### Test Naming Conventions

Use descriptive names that explain the scenario and expected outcome:

```lua
-- GOOD: Explains what + when + expected outcome
it("returns nil when NPC id does not exist in the database", ...)
it("triggers recompile when WotLK plugin is newly installed", ...)
it("skips cleanup when database has not been compiled yet", ...)

-- BAD: Vague
it("works", ...)
it("test 1", ...)
```

## Assertions Reference (Busted)

| Assertion | Meaning |
|-----------|---------|
| `assert.are.equal(expected, actual)` | Strict equality (`==`) |
| `assert.are.same(t1, t2)` | Deep table value equality |
| `assert.is_nil(v)` | `v == nil` |
| `assert.is_not_nil(v)` | `v ~= nil` |
| `assert.is_true(v)` | `v == true` (strict, not truthy) |
| `assert.is_false(v)` | `v == false` (strict, not falsy) |
| `assert.truthy(v)` | `v` is truthy (not `nil`/`false`) |
| `assert.falsy(v)` | `v` is falsy (`nil` or `false`) |
| `assert.has_error(fn)` | `fn()` throws any error |
| `assert.has_error(fn, "msg")` | `fn()` throws with specific message |
| `assert.has_no_error(fn)` | `fn()` does not throw |
| `assert.are.near(expected, actual, tolerance)` | Float comparison within epsilon |

## Mocking and Spies

### spy.on — Observe without replacing

```lua
local s = spy.on(Questie, "Debug")
QuestieDB:GetNPC(0)
assert.spy(s).was.called()
assert.spy(s).was.called_with(
    match._,                  -- self (Questie)
    Questie.DEBUG_CRITICAL,   -- severity
    match._                   -- message string
)
s:revert()  -- Restore original (automatic in after_each)
```

### stub — Replace with controlled implementation

```lua
stub(QuestieDB, "QueryNPCSingle").returns(nil)

-- Verify it was called with specific args
assert.stub(QuestieDB.QueryNPCSingle).was.called_with(
    match._, 26680, match._
)

QuestieDB.QueryNPCSingle:revert()
```

### mock — Full module replacement

```lua
local mockDB = mock({
    GetNPC = function(_, id) return { name = "Mock NPC " .. id } end,
    GetQuest = function() return nil end,
})
```

**Rule**: Always restore stubs and spies. Busted auto-reverts stubs created with `stub()` at the end of each `it()` block, but manually-created stubs need explicit `:revert()`.

## WoW API Mock Environment

Create a `tests/mocks/wow_api.lua` that defines the WoW protected API surface. Require it BEFORE any addon file:

```lua
-- tests/mocks/wow_api.lua

-- Frame system
_G.CreateFrame = function(frameType, name, parent, template)
    local frame = {
        _events = {},
        _scripts = {},
        RegisterEvent = function(self, event) self._events[event] = true end,
        UnregisterEvent = function(self, event) self._events[event] = nil end,
        SetScript = function(self, handler, fn) self._scripts[handler] = fn end,
        GetScript = function(self, handler) return self._scripts[handler] end,
        Show = function() end,
        Hide = function() end,
        IsShown = function() return true end,
    }
    return frame
end

-- Timer system
_G.C_Timer = {
    After = function(delay, fn) fn() end,  -- Execute immediately in tests
    NewTicker = function(interval, fn, iterations)
        for i = 1, (iterations or 1) do fn() end
        return { Cancel = function() end }
    end,
}

-- Time
_G.GetTime = function() return os.clock() end
_G.time = os.time

-- Unit info
_G.UnitGUID = function(unit) return "Player-1234-ABCDEF" end
_G.UnitName = function(unit) return "TestPlayer" end
_G.UnitLevel = function(unit) return 80 end
_G.UnitFactionGroup = function(unit) return "Alliance", "Alliance" end

-- Map API
_G.C_Map = {
    GetMapInfo = function(mapID) return { mapID = mapID, name = "Test Zone" } end,
    GetBestMapForUnit = function(unit) return 1 end,
}

-- Enum system
_G.Enum = {
    UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4 },
}

-- Misc
_G.IsAddOnLoaded = function(name) return true end
_G.GetAddOnInfo = function(name) return name, "Test Addon", "", true, "INSECURE" end
_G.InCombatLockdown = function() return false end
_G.debugstack = function(level) return "mock stack trace" end
_G.geterrorhandler = function() return print end
_G.hooksecurefunc = function(table, name, fn) end
_G.print = print
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.select = select
_G.format = string.format
_G.strsplit = function(sep, str)
    local parts = {}
    local pattern = "([^" .. sep .. "]+)"
    for match in str:gmatch(pattern) do
        table.insert(parts, match)
    end
    return unpack(parts)
end

-- SavedVariables
_G.QuestieSV = {}
```

### Firing Events in Tests

```lua
-- Helper to fire a WoW event on a frame mock
local function fireEvent(frame, event, ...)
    if frame._events[event] then
        local onEvent = frame._scripts["OnEvent"]
        if onEvent then
            onEvent(frame, event, ...)
        end
    end
end

-- Usage in test
it("handles PLAYER_LOGIN event", function()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:SetScript("OnEvent", myHandler)
    fireEvent(frame, "PLAYER_LOGIN")
    -- assert expected side effects
end)
```

## Error Path Testing

**Always test error paths, not just happy paths:**

```lua
describe("error handling", function()
    it("handles nil rawdata gracefully", function()
        QuestieDB.npcData = {}
        local result = QuestieDB:GetNPC(99999)
        assert.is_nil(result)
    end)

    it("logs critical error for nil rawdata", function()
        local s = spy.on(Questie, "Debug")
        QuestieDB.npcData = {}
        QuestieDB:GetNPC(99999)
        assert.spy(s).was.called_with(
            match._, Questie.DEBUG_CRITICAL, match.is_string()
        )
    end)

    it("survives pcall on corrupted data", function()
        QuestieDB.npcData = { [1] = "not a table" }
        assert.has_no_error(function()
            QuestieDB:GetNPC(1)
        end)
    end)
end)
```

## Coverage

Use **Luacov** for line coverage. Target ≥ 80%.

### Configuration (`.luacov`)

```lua
return {
    statsfile = "luacov.stats.out",
    reportfile = "luacov.report.out",
    exclude = {
        "tests/",                     -- Exclude test files from coverage
        "Database/Data/.*Data",       -- Exclude large static data tables
        "Localization/Translations/", -- Exclude translation strings
    },
    include = {
        "Database/",
        "Modules/",
    },
}
```

### Commands

```bash
# Run tests with coverage
busted --coverage

# Generate report
luacov
cat luacov.report.out

# Fail CI if below threshold
awk '/^Total/ { if ($4+0 < 80) { print "Coverage below 80%: " $4 "%"; exit 1 } }' luacov.report.out
```

## Test-Driven Development Workflow (Lua)

1. **RED** — Write the test first. It must FAIL.
2. **GREEN** — Write the minimum production code to make it pass.
3. **REFACTOR** — Clean up while keeping tests green.
4. **COVERAGE** — Verify ≥ 80% with `busted --coverage && luacov`.

```bash
# TDD cycle
busted tests/unit/QuestieDB_spec.lua          # RED:   expect failures
# ... write implementation ...
busted tests/unit/QuestieDB_spec.lua          # GREEN: expect passes
# ... refactor ...
busted --coverage && luacov                    # COVERAGE: verify 80%+
```

## Testing Commands

```bash
busted                                  # Run all tests
busted --verbose                        # Verbose output
busted tests/unit/                      # Run only unit tests
busted --filter="GetNPC"                # Run tests matching pattern
busted --tags="wotlk"                   # Run tagged tests only
busted --coverage                       # With coverage collection
busted --output=TAP                     # TAP format for CI
busted --shuffle                        # Randomize test order (detect coupling)
```

## Agent Support

- **tdd-guide** — Use proactively for new features; enforces write-tests-first workflow
- **code-reviewer** — Review test quality after writing tests
