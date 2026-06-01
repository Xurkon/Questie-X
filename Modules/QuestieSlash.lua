---@class QuestieSlash
local QuestieSlash = QuestieLoader:CreateModule("QuestieSlash")

---@type QuestieOptions
local QuestieOptions = QuestieLoader:ImportModule("QuestieOptions")
---@type QuestieJourney
local QuestieJourney = QuestieLoader:ImportModule("QuestieJourney")
---@type QuestieQuest
local QuestieQuest = QuestieLoader:ImportModule("QuestieQuest")
---@type QuestieTracker
local QuestieTracker = QuestieLoader:ImportModule("QuestieTracker")
---@type QuestieSearch
local QuestieSearch = QuestieLoader:ImportModule("QuestieSearch")
---@type QuestieMap
local QuestieMap = QuestieLoader:ImportModule("QuestieMap")
---@type QuestieLib
local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")
---@type QuestieCombatQueue
local QuestieCombatQueue = QuestieLoader:ImportModule("QuestieCombatQueue")

local function _fmt(v)
    if v == nil then return "nil" end
    if type(v) == "number" then return string.format("%.4f", v) end
    return tostring(v)
end

local function _dumpFrame(name, frame)
    if not frame then
        print(string.format("%s: nil", name))
        return
    end

    local p1, r1, p2, x, y = frame:GetPoint()
    print(string.format(
        "%s: %s size=%.1fx%.1f scale=%.4f eff=%.4f visible=%s strata=%s level=%s point=(%s,%s,%s,%.1f,%.1f)",
        name,
        frame:GetName() or tostring(frame),
        frame:GetWidth() or 0,
        frame:GetHeight() or 0,
        frame.GetScale and frame:GetScale() or 0,
        frame.GetEffectiveScale and frame:GetEffectiveScale() or 0,
        tostring(frame:IsShown()),
        tostring(frame.GetFrameStrata and frame:GetFrameStrata() or "?"),
        tostring(frame.GetFrameLevel and frame:GetFrameLevel() or "?"),
        tostring(p1), tostring(r1 and r1.GetName and r1:GetName() or r1), tostring(p2), x or 0, y or 0
    ))
end

local function _dumpMaskState(frame)
    if not frame then
        return
    end

    local mask = nil
    if frame.GetMaskTexture then
        pcall(function()
            mask = frame:GetMaskTexture()
        end)
    end

    local tex = nil
    if frame.GetTexture then
        pcall(function()
            tex = frame:GetTexture()
        end)
    end

    local shape = GetMinimapShape and GetMinimapShape() or "UNKNOWN"
    local isSquare = tostring(shape) == "SQUARE"
    print(string.format(
        "Minimap mask/texture: mask=%s texture=%s shape=%s square=%s",
        tostring(mask),
        tostring(tex),
        tostring(shape),
        tostring(isSquare)
    ))
end

local function QuestieTerrainDebug()
    print("=== MINIMAP TERRAIN DEBUG ===")
    _dumpFrame("Minimap", Minimap)
    _dumpFrame("MinimapCluster", MinimapCluster)
    _dumpFrame("MinimapZoomIn", MinimapZoomIn)
    _dumpFrame("MinimapZoomOut", MinimapZoomOut)
    _dumpFrame("MinimapBorderTop", MinimapBorderTop)
    _dumpFrame("MinimapBackdrop", MinimapBackdrop)
    _dumpFrame("MinimapNorthTag", MinimapNorthTag)
    _dumpFrame("MinimapCompassTexture", MinimapCompassTexture)
    _dumpMaskState(Minimap)

    local mmHolder = _G.MMHolder
    _dumpFrame("MMHolder", mmHolder)

    local parent = Minimap and Minimap:GetParent()
    local depth = 0
    while parent and depth < 5 do
        _dumpFrame(string.format("Parent[%d]", depth + 1), parent)
        parent = parent:GetParent()
        depth = depth + 1
    end

    local elvUIEnabled = _G.ElvUI ~= nil or _G.ElvDB ~= nil
    print("")
    print("Interpretation:")
    print(string.format("- ElvUI detected: %s", tostring(elvUIEnabled)))
    print("- If Minimap uses MMHolder plus a square mask/shape, ElvUI's minimap module is active.")
    print("- If anchors are stock but the terrain still misaligns, the likely bug is ElvUI's mask/texture path, not Questie pin math.")
end

local function QuestieRadiusDebug()
    local m = Minimap
    if not m then
        print("=== MINIMAP RADIUS DEBUG ===")
        print("Minimap frame not available")
        return
    end

    local function fmt(v)
        if v == nil then return "nil" end
        if type(v) == "number" then return string.format("%.4f", v) end
        return tostring(v)
    end

    local zoom = m:GetZoom() or -1
    local width = m:GetWidth() or 0
    local height = m:GetHeight() or 0
    local scale = m:GetScale() or 0
    local effScale = m.GetEffectiveScale and m:GetEffectiveScale() or 0
    local shape = GetMinimapShape and GetMinimapShape() or "UNKNOWN"

    print("=== MINIMAP RADIUS DEBUG ===")
    print(string.format("Zoom level: %d", zoom))
    print(string.format("Shape: %s", tostring(shape)))
    print(string.format("Minimap size: %.1f x %.1f", width, height))
    print(string.format("Minimap scale: %.4f (effective %.4f)", scale, effScale))
    print(string.format("Visible: %s", tostring(m:IsVisible())))

    local function getFallbackRadius(isOutdoor)
        local outdoor = {[0]=466 + 2/3, [1]=400, [2]=333 + 1/3, [3]=266 + 2/3, [4]=200, [5]=133 + 1/3}
        local indoor  = {[0]=300, [1]=240, [2]=180, [3]=120, [4]=80,  [5]=50}
        local tableRef = isOutdoor and outdoor or indoor
        return (tableRef[zoom] or 0) / 2
    end

    if m.GetViewRadius then
        print(string.format("Minimap:GetViewRadius() = %s", fmt(m:GetViewRadius())))
    else
        print("Minimap:GetViewRadius() = NOT AVAILABLE")
    end

    if C_Minimap and C_Minimap.GetViewRadius then
        print(string.format("C_Minimap.GetViewRadius() = %s", fmt(C_Minimap.GetViewRadius())))
    else
        print("C_Minimap.GetViewRadius() = NOT AVAILABLE")
    end

    local zoomCVar = tonumber(GetCVar("minimapZoom") or "0") or 0
    local insideZoomCVar = tonumber(GetCVar("minimapInsideZoom") or "0") or 0
    local indoors = zoomCVar == zoom and "outdoor" or "indoor"
    print(string.format("CVar minimapZoom=%d minimapInsideZoom=%d => addon fallback treats current state as %s", zoomCVar, insideZoomCVar, indoors))
    print(string.format("Fallback outdoor radius[%d] = %.2f", zoom, getFallbackRadius(true)))
    print(string.format("Fallback indoor  radius[%d] = %.2f", zoom, getFallbackRadius(false)))

    local HBDPins = QuestieCompat and QuestieCompat.HBDPins
    if HBDPins then
        local activeCount = 0
        for _ in pairs(HBDPins.activeMinimapPins or {}) do
            activeCount = activeCount + 1
        end
        print(string.format("Questie HBDPins activeMinimapPins: %d", activeCount))

        local printed = 0
        print("--- SAMPLE PIN METRICS ---")
        for pin, data in pairs(HBDPins.activeMinimapPins or {}) do
            printed = printed + 1
            if printed > 8 then break end

            local _, _, _, xOff, yOff = pin:GetPoint()
            local px = xOff or 0
            local py = yOff or 0
            local screenDist = math.sqrt(px * px + py * py)
            local radiusPx = math.min(width, height) * 0.5
            local radiusNorm = radiusPx > 0 and (screenDist / radiusPx) or 0
            local edgePx = radiusPx * 0.9
            local edgeErr = screenDist - edgePx
            local onEdge = data.onEdge and true or false
            local shown = pin.IsShown and pin:IsShown() or false
            local iconData = pin.data or {}
            local label = iconData.Name or iconData.name or iconData.Title or "unknown"
            local questId = iconData.Id or iconData.id or iconData.questId or "?"

            print(string.format(
                "[%d] %s q=%s shown=%s edge=%s world=%.2f,%.2f dist=%.3f screen=%.1f,%.1f |px|=%.1f norm=%.3f edgePx=%.1f edgeErr=%.1f",
                printed, label, questId, tostring(shown), tostring(onEdge),
                data.x or 0, data.y or 0, data.distanceFromMinimapCenter or 0,
                px, py, screenDist, radiusNorm, edgePx, edgeErr
            ))
        end
    else
        print("QuestieCompat.HBDPins = NOT AVAILABLE")
    end

    local parent = m:GetParent()
    print(string.format("Minimap parent: %s (size %.0fx%.0f scale %.2f)",
        parent and parent:GetName() or "nil",
        parent and parent:GetWidth() or 0,
        parent and parent:GetHeight() or 0,
        parent and parent:GetScale() or 0))

    print("")
    print("Interpretation:")
    print("- If Minimap:GetViewRadius() and C_Minimap.GetViewRadius() match the fallback, radius is not the drift source.")
    print("- If the sample pin screen error stays near 0.0, Questie's projection math is internally consistent.")
    print("- If radius is correct but the terrain still looks offset, the remaining issue is texture/layout alignment, not pin math.")
end

_G.QuestieRadiusDebug = QuestieRadiusDebug
_G.QuestieTerrainDebug = QuestieTerrainDebug

function QuestieSlash.RegisterSlashCommands()
    Questie:RegisterChatCommand("questieclassic", QuestieSlash.HandleCommands)
    Questie:RegisterChatCommand("questie", QuestieSlash.HandleCommands)
    Questie:RegisterChatCommand("radiusdebug", function()
        if _G.QuestieRadiusDebug then
            _G.QuestieRadiusDebug()
        else
            print("[Questie] radius debug unavailable")
        end
    end)
    Questie:RegisterChatCommand("terraindebug", function()
        if _G.QuestieTerrainDebug then
            _G.QuestieTerrainDebug()
        else
            print("[Questie] terrain debug unavailable")
        end
    end)
end

function QuestieSlash.HandleCommands(input)
    input = string.trim(input, " ");

    local commands = {}
    for c in string.gmatch(input, "([^%s]+)") do
        table.insert(commands, c)
    end

    local mainCommand = commands[1]
    local subCommand = commands[2]

    -- /questie
    if mainCommand == "" or not mainCommand then
        QuestieCombatQueue:Queue(function()
            QuestieOptions:OpenConfigWindow();
        end)

        if QuestieJourney:IsShown() then
            QuestieJourney.ToggleJourneyWindow();
        end
        return ;
    end

    -- /questie help || /questie ?
    if mainCommand == "help" or mainCommand == "?" then
        print(Questie:Colorize(l10n("Questie Commands"), "yellow"));
        print(Questie:Colorize("/questie - " .. l10n("Toggles the Config window"), "yellow"));
        print(Questie:Colorize("/questie toggle - " .. l10n("Toggles showing questie on the map and minimap"), "yellow"));
        print(Questie:Colorize("/questie tomap [<npcId>/<npcName>/reset] - " .. l10n("Adds manual notes to the map for a given NPC ID or name. If the name is ambiguous multipe notes might be added. Without a second command the target will be added to the map. The 'reset' command removes all notes"), "yellow"));
        print(Questie:Colorize("/questie minimap - " .. l10n("Toggles the Minimap Button for Questie"), "yellow"));
        print(Questie:Colorize("/questie journey - " .. l10n("Toggles the My Journey window"), "yellow"));
        print(Questie:Colorize("/questie tracker [show/hide/reset] - " .. l10n("Toggles the Tracker. Add 'show', 'hide', 'reset' to explicit show/hide or reset the Tracker"), "yellow"));
        print(Questie:Colorize("/questie flex - " .. l10n("Flex the amount of quests you have completed so far"), "yellow"));
        print(Questie:Colorize("/questie doable [questID] - " .. l10n("Prints whether you are eligibile to do a quest"), "yellow"));
        print(Questie:Colorize("/questie version - " .. l10n("Prints Questie and client version info"), "yellow"));
        print(Questie:Colorize("/questie learn [toggle/stats/clear/export] - " .. l10n("Self-learning database: toggle on/off, view stats, clear data, or export"), "yellow"));
        return;
    end

    -- /questie toggle
    if mainCommand == "toggle" then
        Questie.db.profile.enabled = (not Questie.db.profile.enabled)
        QuestieQuest:ToggleNotes(Questie.db.profile.enabled);

        -- Close config window if it's open to avoid desyncing the Checkbox
        QuestieOptions:HideFrame();
        return;
    end

    if mainCommand == "reload" then
        QuestieQuest:SmoothReset()
        return
    end

    -- /questie minimap
    if mainCommand == "minimap" then
        Questie.db.profile.minimap.hide = not Questie.db.profile.minimap.hide;

        if Questie.db.profile.minimap.hide then
            Questie.minimapConfigIcon:Hide("Questie");
        else
            Questie.minimapConfigIcon:Show("Questie");
        end
        return;
    end

    -- /questie journey (or /questie journal, because of a typo)
    if mainCommand == "journey" or mainCommand == "journal" then
        QuestieJourney.ToggleJourneyWindow();
        QuestieOptions:HideFrame();
        return;
    end

    if mainCommand == "tracker" then
        if subCommand == "show" then
            QuestieTracker:Enable()
        elseif subCommand == "hide" then
            QuestieTracker:Disable()
        elseif subCommand == "reset" then
            QuestieTracker:ResetLocation()
        else
            QuestieTracker:Toggle()
        end
        return
    end

    if mainCommand == "tomap" then
        if not subCommand then
            subCommand = UnitName("target")
        end

        if subCommand ~= nil then
            if subCommand == "reset" then
                QuestieMap:ResetManualFrames()
                return
            end

            local conversionTry = tonumber(subCommand)
            if conversionTry then -- We've got an ID
                subCommand = conversionTry
                local result = QuestieSearch:Search(subCommand, "npc", "int")
                if result then
                    for npcId, _ in pairs(result) do
                        QuestieMap:ShowNPC(npcId)
                    end
                end
                return
            elseif type(subCommand) == "string" then
                local result = QuestieSearch:Search(subCommand, "npc")
                if result then
                    for npcId, _ in pairs(result) do
                        QuestieMap:ShowNPC(npcId)
                    end
                end
                return
            end
        end
    end

    if mainCommand == "flex" then
        local questCount = 0
        for _, _ in pairs(Questie.db.char.complete) do
            questCount = questCount + 1
        end
        if GetDailyQuestsCompleted then
            questCount = questCount - GetDailyQuestsCompleted() -- We don't care about daily quests
        end
        SendChatMessage(l10n("has completed a total of %d quests", questCount) .. "!", "EMOTE")
        return
    end

    if mainCommand == "version" then
        local gameType = ""
        if Questie.IsWotlk then
            gameType = "Wrath"
        elseif Questie.IsSoD then -- seasonal checks must be made before non-seasonal for that client, since IsEra resolves true in SoD
            gameType = "SoD"
        elseif Questie.IsEra then
            gameType = "Era"
        end

        Questie:Print("Questie " .. QuestieLib:GetAddonVersionString() .. ", Client " .. GetBuildInfo() .. " " .. gameType .. ", Locale " .. GetLocale())
        return
    end

    if mainCommand == "doable" or mainCommand == "eligible" or mainCommand == "eligibility" then
        if not subCommand then
            print(Questie:Colorize("[Questie] ", "yellow") .. "Usage: /questie " .. mainCommand .. " <questID>")
            do return end
        elseif QuestieDB.QueryQuestSingle(tonumber(subCommand), "name") == nil then
            print(Questie:Colorize("[Questie] ", "yellow") .. "Invalid quest ID")
            return
        end

        Questie:Print("[Eligibility] " .. tostring(QuestieDB.IsDoableVerbose(tonumber(subCommand), false, true, false)))

        return
    end

    -- /questie learn [toggle/stats/clear/export]
    if mainCommand == "learn" then
        local QuestieLearner = QuestieLoader:ImportModule("QuestieLearner")
        if not QuestieLearner then
            Questie:Print("QuestieLearner module not loaded")
            return
        end

        if subCommand == "toggle" or not subCommand then
            local settings = QuestieLearner:GetSettings()
            settings.enabled = not settings.enabled
            Questie:Print("Learning " .. (settings.enabled and "|cff00ff00enabled|r" or "|cffff0000disabled|r"))
        elseif subCommand == "stats" then
            local npcCount, questCount, itemCount, objectCount = QuestieLearner:GetStats()
            Questie:Print("Learned data: " .. npcCount .. " NPCs, " .. questCount .. " quests, " .. itemCount .. " items, " .. objectCount .. " objects")
        elseif subCommand == "clear" then
            QuestieLearner:ClearAllData()
        elseif subCommand == "export" then
            local exportText = QuestieLearner:ExportData()
            if exportText and #exportText > 0 then
                Questie:Print("Export data printed to chat. Copy from Lua errors or use /dump")
                print(exportText)
            else
                Questie:Print("No learned data to export")
            end
        else
            Questie:Print("Usage: /questie learn [toggle/stats/clear/export]")
        end
        return
    end

    print(Questie:Colorize("[Questie] ", "yellow") .. l10n("Invalid command. For a list of options please type: ") .. Questie:Colorize("/questie help", "yellow"));
end
