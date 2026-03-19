-- Shim for Lua 5.2+ (Retail) where table.getn was removed.
-- We cannot use the '#' length operator directly because Lua 5.0 (Turtle WoW)
-- will trigger a compile-time syntax error parsing the file.
-- Using loadstring bypasses the 5.0 compiler and safely injects the # operator in 5.2+.
if not table.getn then
    local loadFunc = loadstring or load
    if loadFunc then
        table.getn = loadFunc("return function(t) return #t end")()
    end
end

-- Shim for Lua 5.1+ (Ascension/Ebonhold/Retail) where math.mod was renamed/removed.
-- We cannot use the '%' modulo operator directly because Lua 5.0
-- will trigger a compile-time syntax error parsing the file.
if not math.mod then
    local loadFunc = loadstring or load
    if loadFunc then
        math.mod = loadFunc("return function(a, b) return a % b end")()
    end
end

-- Shim for Lua 5.0 (Turtle WoW) where string.match is missing.
-- Supports up to 5 captures (sufficient for all Questie uses).
if not string.match then
    string.match = function(str, pattern, init)
        if not str then return nil end
        local start_idx, end_idx, capture1, capture2, capture3, capture4, capture5 = string.find(str, pattern, init)
        if start_idx then
            if capture1 then
                return capture1, capture2, capture3, capture4, capture5
            else
                return string.sub(str, start_idx, end_idx)
            end
        end
        return nil
    end
end

-- Shim for Lua 5.0 where string.gmatch is called string.gfind.
if not string.gmatch then
    string.gmatch = string.gfind
end

-- Shim for Lua 5.0 (Turtle WoW) where select() was not yet implemented.
-- Fix #7: The original used a `while n > 0` loop that never decremented n,
-- making the loop body run exactly once before returning.  Use a plain
-- sequential block instead so the intent is obvious.
if not select then
    select = function(index, ...)
        if arg then -- Lua 5.0 Native Variadic Table
            if index == "#" then
                return arg.n
            end
            index = tonumber(index) or 1
            return unpack(arg, index, arg.n)
        end
    end
end

-- The only public class except for Questie
---@class QuestieLoader
QuestieLoader = QuestieLoader or {}


local modules = (QuestieLoader._modules) or {}

QuestieLoader._modules = modules -- store reference so modules can be iterated for profiling

---@generic T
---@param name `T` @Module name
---@return T|{ private: table } @Module reference
function QuestieLoader:CreateModule(name)
    -- Fix #12: Error on double-registration so aliasing bugs are caught early.
    if modules[name] and modules[name]._defined then
        -- Print a debug message rather than hard-error so it doesn't break live servers
        -- even if another file accidentally calls CreateModule twice.
        if Questie and Questie.Debug then
            Questie:Debug(1, "[QuestieLoader] WARNING: CreateModule called twice for '" .. tostring(name) .. "'. Using existing module.")
        end
        return modules[name]
    end
    if not modules[name] then
        modules[name] = { private = {} }
    end
    modules[name]._defined = true
    return modules[name]
end

---@generic T
---@param name `T` @Module name
---@return T|{ private: table } @Module reference
function QuestieLoader:ImportModule(name)
    if not modules[name] then
        modules[name] = { private = {} }
    end
    return modules[name]
end

function QuestieLoader:PopulateGlobals() -- called when debugging is enabled
    for name, module in pairs(modules) do
        if _G[name] == nil then
            _G[name] = module
        elseif _G[name] ~= module then
            Questie:Debug(Questie.DEBUG_CRITICAL, "[QuestieLoader] GLOBAL COLLISION: '" .. tostring(name) .. "' already exists in _G! Skipping population to avoid Taint.")
        end
    end
end

