-- This must run as early as possible.
-- This should be independednt of Questie and all libraries.

local function doWorkaround()
    -- On 3.3.5, the WorldMap has several dropdowns that are prone to tainting UIDropDownMenu.
    -- We hide them and replace their global update functions with no-ops.
    -- This prevents Blizzard code from calling tainted logic when opening the map.
    
    local dropdowns = {
        "WorldMapContinentDropDown",
        "WorldMapZoneDropDown",
        "WorldMapZoneMinimapDropDown",
        "WorldMapMagnifyingGlassButton"
    }
    
    for _, name in ipairs(dropdowns) do
        local frame = _G[name]
        if frame then
            if frame.Hide then frame:Hide() end
            -- Replacing the global update function is the standard workaround.
            -- Do NOT assign to frame.Update as that taints the frame object itself.
            local updateFuncName = name .. "_Update"
            if _G[updateFuncName] then
                _G[updateFuncName] = function() end
            end
        end
    end
end

-- IsAddOnLoaded on 3.3.5 returns 1 or nil, not two values.
-- If loaded, run immediately, else wait for ADDON_LOADED.
if IsAddOnLoaded("Blizzard_WorldMap") then
    doWorkaround()
else
    local f = CreateFrame("Frame")
    f:SetScript("OnEvent", function(_, _, addOnName)
        if addOnName == "Blizzard_WorldMap" then
            doWorkaround()
        end
    end)
    f:RegisterEvent("ADDON_LOADED")
end
