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
    select = function(index, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25)
        if index == "#" then
            -- Count trailing non-nil values (up to 25 args).
            do
                if a25 ~= nil then return 25 end
                if a24 ~= nil then return 24 end
                if a23 ~= nil then return 23 end
                if a22 ~= nil then return 22 end
                if a21 ~= nil then return 21 end
                if a20 ~= nil then return 20 end
                if a19 ~= nil then return 19 end
                if a18 ~= nil then return 18 end
                if a17 ~= nil then return 17 end
                if a16 ~= nil then return 16 end
                if a15 ~= nil then return 15 end
                if a14 ~= nil then return 14 end
                if a13 ~= nil then return 13 end
                if a12 ~= nil then return 12 end
                if a11 ~= nil then return 11 end
                if a10 ~= nil then return 10 end
                if a9  ~= nil then return 9  end
                if a8  ~= nil then return 8  end
                if a7  ~= nil then return 7  end
                if a6  ~= nil then return 6  end
                if a5  ~= nil then return 5  end
                if a4  ~= nil then return 4  end
                if a3  ~= nil then return 3  end
                if a2  ~= nil then return 2  end
                if a1  ~= nil then return 1  end
                return 0
            end
        end
        if index == 1  then return a1,  a2,  a3,  a4,  a5,  a6,  a7,  a8,  a9,  a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 2  then return a2,  a3,  a4,  a5,  a6,  a7,  a8,  a9,  a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 3  then return a3,  a4,  a5,  a6,  a7,  a8,  a9,  a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 4  then return a4,  a5,  a6,  a7,  a8,  a9,  a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 5  then return a5,  a6,  a7,  a8,  a9,  a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 6  then return a6,  a7,  a8,  a9,  a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 7  then return a7,  a8,  a9,  a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 8  then return a8,  a9,  a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
        if index == 9  then return a9,  a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25 end
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

