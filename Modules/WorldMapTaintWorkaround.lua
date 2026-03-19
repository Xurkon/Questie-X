-- This must run as early as possible.
-- This should be independednt of Questie and all libraries.

local function doWorkaround()
    -- Blizzard's bugs
    -- https://github.com/Stanzilla/WoWUIBugs/issues/114 and https://github.com/Stanzilla/WoWUIBugs/issues/165
    -- HDB (and Questie fork of it) uses WorldMapFrame:AddDataProvider().
    -- Reassigning the _Update functions (e.g. WorldMapContinentDropDown_Update = function() end) 
    -- BEFORE any calls are made is often more reliable than only Hiding the frame.
    
    if WorldMapZoneMinimapDropDown then
        WorldMapZoneMinimapDropDown:Hide()
        WorldMapZoneMinimapDropDown.Update = function() end
    end
    if WorldMapContinentDropDown then
        WorldMapContinentDropDown:Hide()
        WorldMapContinentDropDown.Update = function() end
    end
    if WorldMapZoneDropDown then
        WorldMapZoneDropDown:Hide()
        WorldMapZoneDropDown.Update = function() end
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
