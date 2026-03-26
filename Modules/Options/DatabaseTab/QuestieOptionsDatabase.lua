---@type QuestieOptions
local QuestieOptions = QuestieLoader:ImportModule("QuestieOptions")
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

QuestieOptions.tabs.database = {}

local AceGUI = LibStub("AceGUI-3.0")

-- Forward declarations for dialog functions
local _OpenExportDialog, _OpenImportDialog

-----------------------------------------------------------------------
-- Dialog helpers
-----------------------------------------------------------------------

local function GetExportModule()
    return QuestieLoader:ImportModule("QuestieLearnerExport")
end

local function GetServer()
    if Questie.IsAscension  then return "Ascension" end
    if Questie.IsTurtle     then return "Turtle"    end
    if Questie.IsEbonhold   then return "Ebonhold"  end
    if Questie.IsEra        then return "Era"       end
    if Questie.Is335        then return "WotLK"     end
    return GetRealmName and GetRealmName() or "unknown"
end

local function GetLearnedCounts()
    local ld   = Questie.dbLearner and Questie.dbLearner.global
    local none = { npcs = 0, quests = 0, items = 0, objects = 0, total = 0 }
    if not ld then return none end
    local bucket = ld[GetServer()] or (ld.npcs and ld) or nil
    if not bucket then return none end
    local function Count(t)
        if not t then return 0 end
        local n = 0; local k, _ = next(t); while k do n = n + 1; k, _ = next(t, k) end; return n
    end
    local s = {
        npcs    = Count(bucket.npcs),
        quests  = Count(bucket.quests),
        items   = Count(bucket.items),
        objects = Count(bucket.objects),
    }
    s.total = s.npcs + s.quests + s.items + s.objects
    return s
end

-----------------------------------------------------------------------
-- Export Dialog
-----------------------------------------------------------------------

_OpenExportDialog = function(exportStr, stats)
    local f = AceGUI:Create("Frame")
    f:SetTitle("Questie-X — Export Learned Data")
    f:SetWidth(620)
    f:SetHeight(420)
    f:SetLayout("Flow")
    f:SetCallback("OnClose", function(w) AceGUI:Release(w) end)

    local info = AceGUI:Create("Label")
    info:SetFullWidth(true)
    info:SetText(string.format(
        "|cFFFFD700Server:|r %s    |cFFFFD700NPCs:|r %d    |cFFFFD700Quests:|r %d    |cFFFFD700Items:|r %d    |cFFFFD700Objects:|r %d    |cFFFFD700Total:|r %d entries",
        GetServer(), stats.npcs or 0, stats.quests or 0, stats.items or 0, stats.objects or 0, stats.total or 0
    ))
    f:AddChild(info)

    local spacer = AceGUI:Create("Label")
    spacer:SetFullWidth(true)
    spacer:SetText(" ")
    f:AddChild(spacer)

    local box = AceGUI:Create("MultiLineEditBox")
    box:SetFullWidth(true)
    box:SetNumLines(14)
    box:SetLabel("Select all and copy (Ctrl+A, Ctrl+C):")
    box:SetText(exportStr)
    box:DisableButton(true)
    f:AddChild(box)

    local hint = AceGUI:Create("Label")
    hint:SetFullWidth(true)
    hint:SetText("|cFF888888To share your data: copy this string and submit it on the Questie-X GitHub or Discord. Contributors help grow the quest database for everyone.|r")
    f:AddChild(hint)
end

-----------------------------------------------------------------------
-- Import Dialog
-----------------------------------------------------------------------

_OpenImportDialog = function()
    local f = AceGUI:Create("Frame")
    f:SetTitle("Questie-X — Import Learned Data")
    f:SetWidth(620)
    f:SetHeight(420)
    f:SetLayout("Flow")
    f:SetCallback("OnClose", function(w) AceGUI:Release(w) end)

    local statusLabel = AceGUI:Create("Label")
    statusLabel:SetFullWidth(true)
    statusLabel:SetText("|cFF888888Paste a QxLD export string below, then click Validate.|r")
    f:AddChild(statusLabel)

    local spacer = AceGUI:Create("Label")
    spacer:SetFullWidth(true)
    spacer:SetText(" ")
    f:AddChild(spacer)

    local box = AceGUI:Create("MultiLineEditBox")
    box:SetFullWidth(true)
    box:SetNumLines(12)
    box:SetLabel("Paste export string here:")
    box:SetText("")
    box:DisableButton(true)
    f:AddChild(box)

    local validateBtn = AceGUI:Create("Button")
    validateBtn:SetText("Validate")
    validateBtn:SetWidth(120)
    f:AddChild(validateBtn)

    local importBtn = AceGUI:Create("Button")
    importBtn:SetText("Import")
    importBtn:SetWidth(120)
    importBtn:SetDisabled(true)
    f:AddChild(importBtn)

    validateBtn:SetCallback("OnClick", function()
        local Exp = GetExportModule()
        if not Exp then
            statusLabel:SetText("|cFFFF0000Export module not loaded.|r")
            return
        end
        local input = box:GetText()
        local payload, statsOrErr = Exp:ValidateImport(input)
        if not payload then
            statusLabel:SetText("|cFFFF0000Validation failed: " .. tostring(statsOrErr) .. "|r")
            importBtn:SetDisabled(true)
        else
            statusLabel:SetText(string.format(
                "|cFF00FF00Valid! Server: %s  NPCs: %d  Quests: %d  Items: %d  Objects: %d  Total: %d|r",
                statsOrErr.server or "?",
                statsOrErr.npcs or 0, statsOrErr.quests or 0,
                statsOrErr.items or 0, statsOrErr.objects or 0,
                statsOrErr.total or 0
            ))
            importBtn:SetDisabled(false)
        end
    end)

    importBtn:SetCallback("OnClick", function()
        local Exp = GetExportModule()
        if not Exp then return end
        local ok, msg = Exp:MergeImport()
        if ok then
            statusLabel:SetText("|cFF00FF00" .. msg .. "|r")
            importBtn:SetDisabled(true)
        else
            statusLabel:SetText("|cFFFF0000" .. msg .. "|r")
        end
    end)
end

-----------------------------------------------------------------------
-- Tab Definition
-----------------------------------------------------------------------

function QuestieOptions.tabs.database:Initialize()
    return {
        name  = function() return l10n("Database") end,
        type  = "group",
        order = 9,
        args  = {

            ---- Header -----------------------------------------------
            db_header = {
                type  = "header",
                order = 1,
                name  = function() return l10n("Learned Data") end,
            },

            ---- Live stats description --------------------------------
            db_stats_desc = {
                type     = "description",
                order    = 1.1,
                fontSize = "medium",
                name     = function()
                    local s = GetLearnedCounts()
                    if s.total == 0 then
                        return "|cFF888888No learned data recorded yet. Play the game and Questie will learn as you go.|r"
                    end
                    return string.format(
                        "|cFFFFD700Server:|r %s\n|cFF5EBAF3NPCs:|r %d    |cFF5EBAF3Quests:|r %d    |cFF5EBAF3Items:|r %d    |cFF5EBAF3Objects:|r %d\n|cFFFFFFFFTotal entries:|r %d",
                        GetServer(), s.npcs, s.quests, s.items, s.objects, s.total
                    )
                end,
            },

            ---- Learner Toggles header --------------------------------
            learner_toggle_header = {
                type  = "header",
                order = 2,
                name  = function() return l10n("What To Learn") end,
            },

            learn_npcs = {
                type  = "toggle",
                order = 2.1,
                name  = function() return l10n("Learn NPCs") end,
                desc  = function() return l10n("Record quest-relevant NPC positions and data.") end,
                get   = function() return Questie.dbLearner.global and Questie.dbLearner.global.settings and Questie.dbLearner.global.settings.learnNpcs end,
                set   = function(_, v)
                    if Questie.dbLearner.global and Questie.dbLearner.global.settings then
                        Questie.dbLearner.global.settings.learnNpcs = v
                    end
                end,
            },

            learn_quests = {
                type  = "toggle",
                order = 2.2,
                name  = function() return l10n("Learn Quests") end,
                desc  = function() return l10n("Record quest metadata, objectives, and rewards.") end,
                get   = function() return Questie.dbLearner.global and Questie.dbLearner.global.settings and Questie.dbLearner.global.settings.learnQuests end,
                set   = function(_, v)
                    if Questie.dbLearner.global and Questie.dbLearner.global.settings then
                        Questie.dbLearner.global.settings.learnQuests = v
                    end
                end,
            },

            learn_objects = {
                type  = "toggle",
                order = 2.3,
                name  = function() return l10n("Learn Objects") end,
                desc  = function() return l10n("Record interactable quest object positions.") end,
                get   = function() return Questie.dbLearner.global and Questie.dbLearner.global.settings and Questie.dbLearner.global.settings.learnObjects end,
                set   = function(_, v)
                    if Questie.dbLearner.global and Questie.dbLearner.global.settings then
                        Questie.dbLearner.global.settings.learnObjects = v
                    end
                end,
            },

            learn_items = {
                type  = "toggle",
                order = 2.4,
                name  = function() return l10n("Learn Items") end,
                desc  = function() return l10n("Record quest item drop sources.") end,
                get   = function() return Questie.dbLearner.global and Questie.dbLearner.global.settings and Questie.dbLearner.global.settings.learnItems end,
                set   = function(_, v)
                    if Questie.dbLearner.global and Questie.dbLearner.global.settings then
                        Questie.dbLearner.global.settings.learnItems = v
                    end
                end,
            },

            learn_broadcast = {
                type  = "toggle",
                order = 2.5,
                name  = function() return l10n("Broadcast to Party") end,
                desc  = function() return l10n("Share newly learned data with nearby party/raid members who also have Questie-X.") end,
                get   = function() return Questie.db.profile.learnerBroadcast end,
                set   = function(_, v) Questie.db.profile.learnerBroadcast = v end,
            },

            ---- Export -----------------------------------------------
            export_header = {
                type  = "header",
                order = 3,
                name  = function() return l10n("Export") end,
            },

            export_desc = {
                type     = "description",
                order    = 3.1,
                fontSize = "medium",
                name     = function()
                    return "|cFF888888Export your learned data as a compressed string. You can paste this in a GitHub issue or Discord message to help improve the official Questie databases.|r"
                end,
            },

            export_current_btn = {
                type  = "execute",
                order = 3.2,
                name  = function() return l10n("Export Current Server") end,
                desc  = function()
                    local s = GetLearnedCounts()
                    return string.format("Export %d entries for %s", s.total, GetServer())
                end,
                func  = function()
                    local Exp = GetExportModule()
                    if not Exp then
                        Questie:Print("|cFFFF0000QuestieLearnerExport module not loaded.|r")
                        return
                    end
                    local str, statsOrErr = Exp:Export()
                    if not str then
                        Questie:Print("|cFFFF0000Export failed: " .. tostring(statsOrErr) .. "|r")
                    else
                        _OpenExportDialog(str, statsOrErr)
                    end
                end,
            },

            export_all_btn = {
                type  = "execute",
                order = 3.3,
                name  = function() return l10n("Export All Servers") end,
                desc  = function() return "Export merged data from all server profiles." end,
                func  = function()
                    local Exp = GetExportModule()
                    if not Exp then
                        Questie:Print("|cFFFF0000QuestieLearnerExport module not loaded.|r")
                        return
                    end
                    local str, statsOrErr = Exp:ExportAll()
                    if not str then
                        Questie:Print("|cFFFF0000Export failed: " .. tostring(statsOrErr) .. "|r")
                    else
                        _OpenExportDialog(str, statsOrErr)
                    end
                end,
            },

            ---- Import -----------------------------------------------
            import_header = {
                type  = "header",
                order = 4,
                name  = function() return l10n("Import") end,
            },

            import_desc = {
                type     = "description",
                order    = 4.1,
                fontSize = "medium",
                name     = function()
                    return "|cFF888888Import a QxLD string from another player or the Questie-X GitHub. Questie-X will validate the string before merging — existing data with higher confidence is never overwritten.|r"
                end,
            },

            import_btn = {
                type  = "execute",
                order = 4.2,
                name  = function() return l10n("Open Import Window") end,
                func  = function()
                    _OpenImportDialog()
                end,
            },

            ---- Cleanup ----------------------------------------------
            cleanup_header = {
                type  = "header",
                order = 5,
                name  = function() return l10n("Cleanup") end,
            },

            cleanup_desc = {
                type     = "description",
                order    = 5.1,
                fontSize = "medium",
                name     = function()
                    return "|cFF888888Remove stale, empty, or low-confidence entries from your learned data. Run a dry-run first to see what would be removed.|r"
                end,
            },

            stale_threshold = {
                type  = "range",
                order = 5.2,
                name  = function() return l10n("Stale Data Threshold (Days)") end,
                desc  = function() return l10n("Unconfirmed learned data (seen only once) will be pruned if it hasn't been seen in this many days. Verified data is permanent.") end,
                min   = 1,
                max   = 180,
                step  = 1,
                get   = function() return (Questie.dbLearner.global.settings and Questie.dbLearner.global.settings.staleThreshold) or 90 end,
                set   = function(_, val)
                    Questie.dbLearner.global.settings.staleThreshold = val
                end,
            },
 
            prune_verified = {
                type  = "toggle",
                order = 5.3,
                name  = function() return l10n("Include Verified Data in Pruning") end,
                desc  = function() return l10n("If enabled, even high-confidence (Verified) data will be subject to redundancy pruning (e.g., if it's already in the official DB). Time-based pruning still only affects unconfirmed data.") end,
                get   = function() return (Questie.dbLearner.global.settings and Questie.dbLearner.global.settings.pruneVerified) or false end,
                set   = function(_, val)
                    Questie.dbLearner.global.settings.pruneVerified = val
                end,
            },
 
            prune_dry_btn = {
                type  = "execute",
                order = 5.4,
                name  = function() return l10n("Dry Run (Preview)") end,
                desc  = function() return "Print a summary of entries that would be removed, without deleting anything." end,
                func  = function()
                    local Exp = GetExportModule()
                    if not Exp then return end
                    local r = Exp:DryRunPrune()
                    Questie:Print(string.format(
                        "|cFF00FF00[Learner Prune Preview]|r Would remove: NPCs %d, Quests %d, Items %d, Objects %d — Total %d",
                        r.npcs, r.quests, r.items, r.objects, r.total
                    ))
                    if r.total > 0 then
                        Questie:Print("|cFF888888Use /questie db prune to apply, or click Prune Now in the Database tab.|r")
                    end
                end,
            },
 
            prune_btn = {
                type  = "execute",
                order = 5.5,
                name  = function() return l10n("Prune Now") end,
                desc  = function() return "|cFFFF8800Removes stale entries. Cannot be undone. Export first if you want a backup.|r" end,
                func  = function()
                    local Exp = GetExportModule()
                    if not Exp then return end
                    local r = Exp:Prune()
                    Questie:Print(string.format(
                        "|cFF00FF00[Learner Prune]|r Removed: NPCs %d, Quests %d, Items %d, Objects %d — Total %d",
                        r.npcs, r.quests, r.items, r.objects, r.total
                    ))
                end,
            },
 
            prune_all_btn = {
                type  = "execute",
                order = 5.6,
                name  = function() return "|cFFFF4444" .. l10n("Reset All Learned Data") .. "|r" end,
                desc  = function() return "|cFFFF0000DANGER: Wipes ALL learned data for ALL servers. Export first.|r" end,
                confirm = true,
                confirmText = "Are you sure? This cannot be undone.",
                func  = function()
                    if Questie.db and Questie.db.global then
                        Questie.dbLearner.global = nil
                        Questie:Print("|cFFFF4444[Questie-X]|r All learned data has been reset.")
                    end
                end,
            },

            ---- Submit/Contribute ------------------------------------
            submit_header = {
                type  = "header",
                order = 6,
                name  = function() return l10n("Contribute") end,
            },


            submit_desc = {
                type     = "description",
                order    = 6.1,
                fontSize = "medium",
                name     = function()
                    return "|cFF888888Want to help grow the Questie-X database?\n\n" ..
                           "1. Click |r|cFFFFFFFFExport Current Server|r|cFF888888 above.\n" ..
                           "2. Copy the full export string (Ctrl+A then Ctrl+C in the dialog).\n" ..
                           "3. Open a new GitHub issue at |r|cFF5EBAF3github.com/Xurkon/Questie-X/issues|r|cFF888888 titled: |r|cFFFFFFFF[Data Submission] <Server Name>|r|cFF888888\n" ..
                           "4. Paste the string into the issue body and submit.\n\n" ..
                           "Submissions are reviewed and merged into the official database. Thank you for contributing!|r"
                end,
            },

            ---- Loaded Plugins ----------------------------------------
            plugins_header = {
                type  = "header",
                order = 7,
                name  = "|cFF5EBAF3Loaded Questie-X Plugins|r",
            },

            plugins_desc = {
                type     = "description",
                order    = 7.1,
                fontSize = "medium",
                name     = function()
                    local QuestiePluginAPI = QuestieLoader:ImportModule("QuestiePluginAPI")
                    if not QuestiePluginAPI or not QuestiePluginAPI.registeredPlugins then
                        return "|cFF888888No plugins loaded.|r"
                    end

                    -- Helper: count a table's entries
                    local function CountTable(t)
                        if type(t) ~= "table" then return 0 end
                        local n = 0
                        for _ in pairs(t) do n = n + 1 end
                        return n
                    end

                    -- Fix #11: _G.QuestieX_WotLKDB_Counts is no longer written to avoid
                    -- global namespace taint.  Stats are pushed directly onto plugin.stats
                    -- by LoadBaseDB() / UpdateWotLKDBStats(), so read from there.
                    local function GetPluginCounts(pluginName, stats)
                        local q = stats.QUEST  or 0
                        local n = stats.NPC    or 0
                        local o = stats.OBJECT or 0
                        local i = stats.ITEM   or 0
                        return q, n, o, i
                    end

                    local output = ""
                    local hasPlugins = false

                    local pluginName, plugin = next(QuestiePluginAPI.registeredPlugins)
                    while pluginName do
                        hasPlugins = true
                        local q, n, o, i = GetPluginCounts(pluginName, plugin.stats or {})
                        output = output .. "|cFF5EBAF3[Questie-" .. pluginName .. "]|r"
                        output = output .. "  Quests: |cFFFFD700" .. tostring(q) .. "|r"
                        output = output .. "  NPCs: |cFFFFD700"   .. tostring(n) .. "|r"
                        output = output .. "  Objects: |cFFFFD700" .. tostring(o) .. "|r"
                        output = output .. "  Items: |cFFFFD700"  .. tostring(i) .. "|r\n"
                        pluginName, plugin = next(QuestiePluginAPI.registeredPlugins, pluginName)
                    end

                    if not hasPlugins then
                        output = "|cFF888888No plugins loaded.|r"
                    end

                    return output
                end,
            },
        },
    }
end
