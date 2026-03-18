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
            local n = 25
            while n > 0 do
                if n == 25 and a25 ~= nil then return 25 end
                if n == 24 and a24 ~= nil then return 24 end
                if n == 23 and a23 ~= nil then return 23 end
                if n == 22 and a22 ~= nil then return 22 end
                if n == 21 and a21 ~= nil then return 21 end
                if n == 20 and a20 ~= nil then return 20 end
                if n == 19 and a19 ~= nil then return 19 end
                if n == 18 and a18 ~= nil then return 18 end
                if n == 17 and a17 ~= nil then return 17 end
                if n == 16 and a16 ~= nil then return 16 end
                if n == 15 and a15 ~= nil then return 15 end
                if n == 14 and a14 ~= nil then return 14 end
                if n == 13 and a13 ~= nil then return 13 end
                if n == 12 and a12 ~= nil then return 12 end
                if n == 11 and a11 ~= nil then return 11 end
                if n == 10 and a10 ~= nil then return 10 end
                if n == 9 and a9 ~= nil then return 9 end
                if n == 8 and a8 ~= nil then return 8 end
                if n == 7 and a7 ~= nil then return 7 end
                if n == 6 and a6 ~= nil then return 6 end
                if n == 5 and a5 ~= nil then return 5 end
                if n == 4 and a4 ~= nil then return 4 end
                if n == 3 and a3 ~= nil then return 3 end
                if n == 2 and a2 ~= nil then return 2 end
                if n == 1 and a1 ~= nil then return 1 end
                return 0
            end
            return 0
        end
        if index == 1 then return a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 2 then return a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 3 then return a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 4 then return a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 5 then return a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 6 then return a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 7 then return a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 8 then return a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 9 then return a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 10 then return a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 11 then return a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 12 then return a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 13 then return a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 14 then return a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 15 then return a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 16 then return a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 17 then return a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 18 then return a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 19 then return a19, a20, a21, a22, a23, a24, a25 end
        if index == 20 then return a20, a21, a22, a23, a24, a25 end
        if index == 21 then return a21, a22, a23, a24, a25 end
        if index == 22 then return a22, a23, a24, a25 end
        if index == 23 then return a23, a24, a25 end
        if index == 24 then return a24, a25 end
        if index == 25 then return a25 end
        return nil
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
        if _G[name] == nil then
            _G[name] = module
        elseif _G[name] ~= module then
            Questie:Debug(Questie.DEBUG_CRITICAL, "[QuestieLoader] GLOBAL COLLISION: '" .. tostring(name) .. "' already exists in _G! Skipping population to avoid Taint.")
        end
    end
end

