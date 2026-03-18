---@class QuestieLearnerExport
local QuestieLearnerExport = QuestieLoader:CreateModule("QuestieLearnerExport")

---@type QuestieLearner
local QuestieLearner = QuestieLoader:ImportModule("QuestieLearner")
---@type QuestieServer
local QuestieServer = QuestieLoader:ImportModule("QuestieServer")

local LibDeflate    = LibStub("LibDeflate")
local AceSerializer = LibStub("AceSerializer-3.0")

local FORMAT_PREFIX  = "QxLD"
local FORMAT_VERSION = 1
local FORMAT_SEP     = "!"
local MAX_IMPORT_LEN = 524288  -- 512 KB hard cap on raw decoded payload

local _Export = QuestieLearnerExport.private or {}
QuestieLearnerExport.private = _Export

-- Cached last export string and stats for the UI to read without re-computing
QuestieLearnerExport.lastExportString = nil
QuestieLearnerExport.lastExportStats  = nil

-- Cached last import validation result
QuestieLearnerExport.lastImportStats  = nil
QuestieLearnerExport.lastImportData   = nil

-----------------------------------------------------------------------
-- Internal helpers
-----------------------------------------------------------------------

local function CountTable(t)
    if not t then return 0 end
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function GetServerKey()
    if QuestieServer then
        if Questie.IsAscension  then return "Ascension" end
        if Questie.IsTurtle     then return "Turtle"    end
        if Questie.IsEbonhold   then return "Ebonhold"  end
        if Questie.IsEra        then return "Era"       end
        if Questie.Is335        then return "WotLK"     end
    end
    local realm = GetRealmName and GetRealmName() or "unknown"
    return realm ~= "" and realm or "unknown"
end

-- Returns the learnedData sub-table for the current server, or nil
local function GetServerBucket(serverKey)
    local ld = Questie.db and Questie.db.global and Questie.db.global.learnedData
    if not ld then return nil end
    if ld[serverKey] then return ld[serverKey] end
    -- Fallback: flat (pre-bucket) layout still in use
    if ld.npcs or ld.quests then return ld end
    return nil
end

-- Builds a lightweight stats summary table from a bucket
local function BuildStats(bucket)
    if not bucket then return { npcs = 0, quests = 0, items = 0, objects = 0, total = 0 } end
    local s = {
        npcs    = CountTable(bucket.npcs),
        quests  = CountTable(bucket.quests),
        items   = CountTable(bucket.items),
        objects = CountTable(bucket.objects),
    }
    s.total = s.npcs + s.quests + s.items + s.objects
    return s
end

-----------------------------------------------------------------------
-- Export
-----------------------------------------------------------------------

--- Serializes + deflates + encodes the learned data for the given server key.
--- Returns the export string and a stats table, or nil + error message.
---@param serverKey string|nil  defaults to current server
---@return string|nil, table|string
function QuestieLearnerExport:Export(serverKey)
    serverKey = serverKey or GetServerKey()
    local bucket = GetServerBucket(serverKey)
    if not bucket then
        return nil, "No learned data found for server: " .. tostring(serverKey)
    end

    local stats = BuildStats(bucket)
    if stats.total == 0 then
        return nil, "Nothing to export — learned data is empty."
    end

    local payload = {
        v      = FORMAT_VERSION,
        server = serverKey,
        ts     = time and time() or 0,
        data   = bucket,
    }

    local ok, serialized = pcall(AceSerializer.Serialize, AceSerializer, payload)
    if not ok or not serialized then
        return nil, "Serialization failed: " .. tostring(serialized)
    end

    local compressed = LibDeflate:CompressDeflate(serialized, { level = 9 })
    if not compressed then
        return nil, "Compression failed."
    end

    local encoded = LibDeflate:EncodeForPrint(compressed)
    if not encoded then
        return nil, "Encoding failed."
    end

    local result = FORMAT_PREFIX .. ":" .. FORMAT_VERSION .. FORMAT_SEP .. encoded

    self.lastExportString = result
    self.lastExportStats  = stats

    Questie:Debug(Questie.DEBUG_DEVELOP, "[LearnerExport] Exported", stats.total,
        "entries for", serverKey, "len:", string.len(result))

    return result, stats
end

--- Exports ALL server buckets merged into one payload.
---@return string|nil, table|string
function QuestieLearnerExport:ExportAll()
    local ld = Questie.db and Questie.db.global and Questie.db.global.learnedData
    if not ld then return nil, "No learned data." end

    local merged = { npcs = {}, quests = {}, items = {}, objects = {} }
    local function MergeBucket(b)
        if not b then return end
        for id, v in pairs(b.npcs    or {}) do merged.npcs[id]    = v end
        for id, v in pairs(b.quests  or {}) do merged.quests[id]  = v end
        for id, v in pairs(b.items   or {}) do merged.items[id]   = v end
        for id, v in pairs(b.objects or {}) do merged.objects[id] = v end
    end

    -- Flat layout
    if ld.npcs or ld.quests then
        MergeBucket(ld)
    else
        for _, bucket in pairs(ld) do
            if type(bucket) == "table" and bucket.npcs then
                MergeBucket(bucket)
            end
        end
    end

    local stats = BuildStats(merged)
    if stats.total == 0 then return nil, "Nothing to export." end

    local payload = {
        v      = FORMAT_VERSION,
        server = "all",
        ts     = time and time() or 0,
        data   = merged,
    }

    local ok, serialized = pcall(AceSerializer.Serialize, AceSerializer, payload)
    if not ok or not serialized then
        return nil, "Serialization failed."
    end

    local compressed = LibDeflate:CompressDeflate(serialized, { level = 9 })
    if not compressed then return nil, "Compression failed." end

    local encoded = LibDeflate:EncodeForPrint(compressed)
    if not encoded then return nil, "Encoding failed." end

    local result = FORMAT_PREFIX .. ":" .. FORMAT_VERSION .. FORMAT_SEP .. encoded
    self.lastExportString = result
    self.lastExportStats  = stats
    return result, stats
end

-----------------------------------------------------------------------
-- Import / Validate
-----------------------------------------------------------------------

--- Validates an import string and returns the decoded payload table,
--- or nil + error string. Does NOT merge — call MergeImport() after confirming.
---@param importStr string
---@return table|nil, string|table
function QuestieLearnerExport:ValidateImport(importStr)
    self.lastImportData  = nil
    self.lastImportStats = nil

    if not importStr or importStr == "" then
        return nil, "Empty import string."
    end

    -- Strip whitespace
    importStr = importStr:gsub("%s+", "")

    -- Check prefix
    if not importStr:sub(1, #FORMAT_PREFIX + 2) == FORMAT_PREFIX .. ":" then
        return nil, "Not a Questie-X export string (missing QxLD prefix)."
    end

    local sepPos = importStr:find(FORMAT_SEP, 1, true)
    if not sepPos then
        return nil, "Malformed string — missing separator."
    end

    local encoded = importStr:sub(sepPos + 1)
    if string.len(encoded) > MAX_IMPORT_LEN then
        return nil, "Import string too large (max 512 KB)."
    end

    local compressed = LibDeflate:DecodeForPrint(encoded)
    if not compressed then
        return nil, "Decode failed — string may be corrupted."
    end

    local serialized = LibDeflate:DecompressDeflate(compressed)
    if not serialized then
        return nil, "Decompression failed — string may be corrupted."
    end

    local ok, payload = AceSerializer:Deserialize(serialized)
    if not ok or type(payload) ~= "table" then
        return nil, "Deserialization failed — data is malformed."
    end

    if payload.v ~= FORMAT_VERSION then
        return nil, "Unsupported format version: " .. tostring(payload.v)
    end

    local bucket = payload.data
    if type(bucket) ~= "table" then
        return nil, "Payload missing data table."
    end
    if type(bucket.npcs)    ~= "table" or
       type(bucket.quests)  ~= "table" or
       type(bucket.items)   ~= "table" or
       type(bucket.objects) ~= "table" then
        return nil, "Payload data is missing required sub-tables (npcs/quests/items/objects)."
    end

    local stats = BuildStats(bucket)
    stats.server = payload.server or "unknown"
    stats.ts     = payload.ts or 0

    self.lastImportData  = payload
    self.lastImportStats = stats

    Questie:Debug(Questie.DEBUG_DEVELOP, "[LearnerExport] ValidateImport OK:",
        stats.total, "entries from", stats.server)

    return payload, stats
end

--- Merges previously validated import data into learnedData.
--- Must call ValidateImport() first.
---@return boolean, string
function QuestieLearnerExport:MergeImport()
    if not self.lastImportData then
        return false, "No validated import data. Run ValidateImport() first."
    end

    local payload = self.lastImportData
    local bucket  = payload.data
    local merged  = 0
    local skipped = 0

    local function MergeType(typ, src)
        for id, d in pairs(src) do
            local prevData = QuestieLearner.data
            QuestieLearner:HandleNetworkData(typ, id, d)
            if QuestieLearner.data ~= prevData then
                merged = merged + 1
            else
                skipped = skipped + 1
            end
            merged = merged + 1
        end
    end

    MergeType("NPC",    bucket.npcs)
    MergeType("QUEST",  bucket.quests)
    MergeType("ITEM",   bucket.items)
    MergeType("OBJECT", bucket.objects)

    self.lastImportData  = nil
    self.lastImportStats = nil

    -- Push merged data into QuestieDB overrides immediately (no reload required for override data)
    local QuestieLearner = QuestieLoader:ImportModule("QuestieLearner")
    if QuestieLearner and QuestieLearner.InjectLearnedData then
        QuestieLearner:InjectLearnedData()
    end

    local msg = "Import complete: merged " .. merged .. " entries, skipped " .. skipped .. " (already known)."
    Questie:Debug(Questie.DEBUG_DEVELOP, "[LearnerExport]", msg)
    return true, msg
end

-----------------------------------------------------------------------
-- Cleanup / Prune
-----------------------------------------------------------------------

--- Returns a count of entries that would be pruned (dry run).
---@return table  { npcs=N, quests=N, items=N, objects=N, total=N, reasons={} }
function QuestieLearnerExport:DryRunPrune()
    return _Export:RunPrune(true)
end

--- Runs the actual prune and returns counts of removed entries.
---@return table
function QuestieLearnerExport:Prune()
    return _Export:RunPrune(false)
end

local QuestieDB  -- lazily imported to avoid circular dep

function _Export:RunPrune(dryRun)
    if not QuestieDB then QuestieDB = QuestieLoader:ImportModule("QuestieDB") end
 
    local serverKey = GetServerKey()
    local bucket    = GetServerBucket(serverKey)
 
    local result = { npcs = 0, quests = 0, items = 0, objects = 0, total = 0, reasons = {} }
    if not bucket then return result end
 
    local settings = (Questie.db.global.learnedData and Questie.db.global.learnedData.settings) or {}
    local thresholdDays = settings.staleThreshold or 90
    local thresholdSeconds = thresholdDays * 86400
    local minConfidence = settings.minConfidencePins or 2
    local pruneVerified = settings.pruneVerified
    local now = time()
 
    local function ShouldPruneNPC(id, entry)
        if CountTable(entry) == 0 then return "empty entry" end
        local isVerified = (entry.mc or 0) >= minConfidence
        if (not isVerified) and (now - (entry.ls or 0)) > thresholdSeconds then
            return "unconfirmed and stale (> " .. thresholdDays .. " days)"
        end
        if pruneVerified or not isVerified then
            if (entry.mc or 0) < 2 and not entry[7] then return "unverified with no coords" end
        end
        return nil
    end
 
    local function ShouldPruneQuest(id, entry)
        if CountTable(entry) == 0 then return "empty entry" end
        local isVerified = (entry.mc or 0) >= minConfidence
        if (not isVerified) and (now - (entry.ls or 0)) > thresholdSeconds then
            return "unconfirmed and stale (> " .. thresholdDays .. " days)"
        end
        if pruneVerified or not isVerified then
            if QuestieDB and QuestieDB.GetQuest then
                local dbEntry = QuestieDB.GetQuest(id)
                if dbEntry and (entry.mc or 0) < 2 then
                    return "fully covered by official DB, mc < 2"
                end
            end
        end
        return nil
    end
 
    local function ShouldPruneItem(id, entry)
        if CountTable(entry) == 0 then return "empty entry" end
        local isVerified = (entry.mc or 0) >= minConfidence
        if (not isVerified) and (now - (entry.ls or 0)) > thresholdSeconds then
            return "unconfirmed and stale (> " .. thresholdDays .. " days)"
        end
        if pruneVerified or not isVerified then
            if (entry.mc or 0) < 1 then return "zero match count" end
        end
        return nil
    end
 
    local function ShouldPruneObject(id, entry)
        if CountTable(entry) == 0 then return "empty entry" end
        local isVerified = (entry.mc or 0) >= minConfidence
        if (not isVerified) and (now - (entry.ls or 0)) > thresholdSeconds then
            return "unconfirmed and stale (> " .. thresholdDays .. " days)"
        end
        if pruneVerified or not isVerified then
            if (entry.mc or 0) < 2 and not entry[4] then return "unverified with no coords" end
        end
        return nil
    end
 
    local function PruneStore(store, checkFn, typeName)
        if not store then return end
        for id, entry in pairs(store) do
            local reason = checkFn(id, entry)
            if reason then
                result[typeName] = result[typeName] + 1
                result.total     = result.total + 1
                table.insert(result.reasons, typeName .. ":" .. tostring(id) .. " — " .. reason)
                if not dryRun then
                    store[id] = nil
                end
                Questie:Debug(Questie.DEBUG_DEVELOP, "[LearnerExport] Prune",
                    dryRun and "(dry)" or "", typeName, id, reason)
            end
        end
    end
 
    PruneStore(bucket.npcs,    ShouldPruneNPC,    "npcs")
    PruneStore(bucket.quests,  ShouldPruneQuest,  "quests")
    PruneStore(bucket.items,   ShouldPruneItem,   "items")
    PruneStore(bucket.objects, ShouldPruneObject, "objects")
 
    return result
end
