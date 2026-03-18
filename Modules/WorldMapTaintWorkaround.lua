-- This must run as early as possible.
-- This should be independednt of Questie and all libraries.

local function doWorkaround()
    -- Blizzard's bugs
    -- https://github.com/Stanzilla/WoWUIBugs/issues/114 and https://github.com/Stanzilla/WoWUIBugs/issues/165
    -- HDB (and Questie fork of it) uses WorldMapFrame:AddDataProvider(  ).
    -- print("|cff30fc96Questie|r: |cff00bc32Hiding drop-down menus on the World Map.|r This is currently necessary as a workaround for a bug in the default Blizzard UI related to drop-down menus.")
    if WorldMapZoneMinimapDropDown then
        WorldMapZoneMinimapDropDown:Hide()
    end
    if WorldMapContinentDropDown then
        -- We only Hide() these frames. 
        -- Reassigning the _Update functions (e.g. WorldMapContinentDropDown_Update = function() end) 
        -- would cause Taint, which results in ADDON_ACTION_BLOCKED: UseAction().
        WorldMapContinentDropDown:Hide()
    end
    if WorldMapZoneDropDown then
        WorldMapZoneDropDown:Hide()
    end
    --WorldMapMagnifyingGlassButton:Hide()
end

local _, finished = IsAddOnLoaded("Blizzard_WorldMap")

if finished then
    doWorkaround()
else
    local f = CreateFrame("Frame")
    local function addonLoaded(_, _, addOnName)
        if addOnName == "Blizzard_WorldMap" then
            doWorkaround()
        end
    end
    f:SetScript("OnEvent", addonLoaded)
    f:RegisterEvent("ADDON_LOADED")
end
