-- Shim for Lua 5.2+ (Retail) where table.getn was removed.
-- We cannot use the '#' length operator directly because Lua 5.0 (Turtle WoW)
-- will trigger a compile-time syntax error parsing the file.
-- Using loadstring bypasses the 5.0 compiler and safely injects the # operator in 5.2+.
if not table.getn then
    local loadFunc = loadstring or load
    if loadFunc then
        table.getn = loadFunc("return function(t) return table.getn(t) end")()
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
if not select then
    select = function(index, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25)
        if index == "#" then
            return arg and arg.n or table.getn(arg or {})
        end
        index = tonumber(index) or 1
        if index < 1 then error("bad argument #1 to 'select' (index out of range)") end
        if index > (arg and arg.n or table.getn(arg or {})) then return end
        local result = {}
        for i = index, (arg and arg.n or table.getn(arg or {})) do
            table.insert(result, arg[i])
        end
        return unpack(result)
    end
end

-- The only public class except for Questie
---@class QuestieLoader
QuestieLoader = {}


local modules = {}

QuestieLoader._modules = modules -- store reference so modules can be iterated for profiling

---@generic T
---@param name `T` @Module name
---@return T|{ private: table } @Module reference
function QuestieLoader:CreateModule(name)
    if (not modules[name]) then
        modules[name] = { private = {} }
        return modules[name]
    else
        return modules[name]
    end
end

---@generic T
---@param name `T` @Module name
---@return T|{ private: table } @Module reference
function QuestieLoader:ImportModule(name)
    if (not modules[name]) then
        modules[name] = { private = {} }
        return modules[name]
    else
        return modules[name]
    end
end

function QuestieLoader:PopulateGlobals() -- called when debugging is enabled
    for name, module in pairs(modules) do
        _G[name] = module
    end
end

