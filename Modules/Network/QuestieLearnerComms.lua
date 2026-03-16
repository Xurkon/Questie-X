---@class QuestieLearnerComms
local QuestieLearnerComms = QuestieLoader:CreateModule("QuestieLearnerComms")
local _QuestieLearnerComms = QuestieLearnerComms.private

---@type QuestieLearner
local QuestieLearner = QuestieLoader:ImportModule("QuestieLearner")

local LibDeflate = LibStub("LibDeflate")
local AceSerializer = LibStub("AceSerializer-3.0")
local AceComm = LibStub("AceComm-3.0")

local addonPrefix = "QuestieLearner"
local hiddenChannelName = "questiecomm"
local ProtocolVersion = 1

-- Dev Logging Flags — defined first so all functions below can call DebugLog
local LOG_CRITICAL = true
local LOG_DEVELOP = false

local function DebugLog(tier, msg)
    if tier == "CRITICAL" and LOG_CRITICAL then
        Questie:Print("|cFF00FF00[QL-CRITICAL]|r " .. msg)
    elseif tier == "DEVELOP" and LOG_DEVELOP then
        Questie:Debug(Questie.DEBUG_DEVELOP, "|cFF00FFFF[QL-DEV]|r " .. msg)
    end
end

-- Throttling (Token Bucket)
local bucketCapacity = 9
local bucketWindow = 60
local tokenRefillRate = bucketCapacity / bucketWindow
local currentTokens = bucketCapacity
local lastTokenUpdate = GetTime()
local minChatInterval = 3.5
local lastChatMessageTime = 0
local rateLimitQueue = {}

-- Deduplication & Quarantine
local messageCache = {}
local incomingMessageQueue = {}

-- Sender Trust System
local senderTrust = {}
local bannedSenders = {}
local mutedUntil = {}
local XXH = LibStub("XXH_Lua_Lib", true)

local function RecordStrike(sender, reason)
    if not senderTrust[sender] then senderTrust[sender] = { strikes = 0, lastMsg = 0, count = 0 } end
    senderTrust[sender].strikes = senderTrust[sender].strikes + 1
    DebugLog("DEVELOP", sender .. " gained a strike (" .. reason .. "). Total: " .. senderTrust[sender].strikes)

    if senderTrust[sender].strikes >= 7 then
        bannedSenders[sender] = true
        DebugLog("CRITICAL", "Sender " .. sender .. " permanently banned (7 strikes).")
    elseif senderTrust[sender].strikes >= 3 then
        mutedUntil[sender] = GetTime() + 300 -- 5-minute mute
        DebugLog("CRITICAL", "Sender " .. sender .. " muted for 5 minutes (3 strikes).")
    end
end

local function IsSenderTrusted(sender)
    if bannedSenders[sender] then return false end
    if mutedUntil[sender] then
        if GetTime() < mutedUntil[sender] then return false end
        mutedUntil[sender] = nil -- mute expired
    end
    if not senderTrust[sender] then senderTrust[sender] = { strikes = 0, lastMsg = 0, count = 0 } end

    local now = GetTime()
    if now - senderTrust[sender].lastMsg < 1.0 then
        senderTrust[sender].count = senderTrust[sender].count + 1
        if senderTrust[sender].count > 10 then
            RecordStrike(sender, "Spamming")
            senderTrust[sender].count = 0
            return false
        end
    else
        senderTrust[sender].count = 1
    end
    senderTrust[sender].lastMsg = now

    return true
end

local function IsDuplicateMessage(serializedData)
    local hash
    if XXH then
        hash = XXH.xxh32(serializedData, 0)
    else
        hash = 0
        for i = 1, string.len(serializedData) do
            hash = math.mod(hash + string.byte(serializedData, i), 4294967296)
        end
    end

    if messageCache[hash] then return true end

    local count = 0
    for _ in pairs(messageCache) do count = count + 1 end
    if count > 500 then
        messageCache = {}
    end

    messageCache[hash] = true
    return false
end

function QuestieLearnerComms:Initialize()
    DebugLog("DEVELOP", "Initializing QuestieLearnerComms")

    -- Register AceComm
    AceComm:RegisterComm(addonPrefix, function(prefix, message, distribution, sender)
        QuestieLearnerComms:OnCommReceived(prefix, message, distribution, sender)
    end)
    
    -- Setup Hidden Channel
    local channelId, channelName = GetChannelName(hiddenChannelName)
    if channelId == 0 then
        JoinPermanentChannel(hiddenChannelName, nil, DEFAULT_CHAT_FRAME:GetID(), 1)
        ChatFrame_RemoveChannel(DEFAULT_CHAT_FRAME, hiddenChannelName)
        DebugLog("DEVELOP", "Joined hidden channel: " .. hiddenChannelName)
    end

    -- Process incoming/outgoing queues 
    C_Timer.NewTicker(0.2, function() _QuestieLearnerComms:ProcessQueues() end)

    -- Start Reinforcement Loop (every 60 seconds)
    C_Timer.NewTicker(60, function() _QuestieLearnerComms:ProcessReinforcement() end)
end

function _QuestieLearnerComms:ProcessReinforcement()
    if not QuestieLearner.data then return end
    
    local categories = {"npcs", "quests", "items", "objects"}
    local category = categories[math.random(table.getn(categories))]
    
    if QuestieLearner.data[category] then
        -- We loop randomly until we find an unconfirmed entry. Just take the first few options to save CPU.
        local keys = {}
        for k, v in pairs(QuestieLearner.data[category]) do
            if type(v) == "table" and (v.mc or 0) < 7 then
                table.insert(keys, k)
                if table.getn(keys) >= 10 then break end -- Sample size 10
            end
        end

        if table.getn(keys) > 0 then
            local randomId = keys[math.random(table.getn(keys))]
            local data = QuestieLearner.data[category][randomId]
            local typ = string.upper(category)
            typ = string.sub(typ, 1, string.len(typ) - 1) -- Remove trailing 's' (NPC, QUEST, ITEM, OBJECT)
            
            DebugLog("DEVELOP", "[Reinforcement] Broadcasting " .. typ .. " " .. randomId)
            QuestieLearnerComms:BroadcastLearnedData("REINFORCE", typ, randomId, data)
        end
    end
end

function QuestieLearnerComms:BroadcastLearnedData(op, entityType, entityId, data)
    -- 1. Create Payload
    local payload = {
        _ver = ProtocolVersion,
        op = op, -- "NEW", "UPDATE", "CONFIRM"
        typ = entityType,
        id = entityId,
        d = data,
        ts = time()
    }

    -- 2. Serialize and Compress
    local serialized = AceSerializer:Serialize(payload)
    local compressed = LibDeflate:CompressDeflate(serialized, {level = 9})
    local encoded = LibDeflate:EncodeForPrint(compressed)

    -- 3. Broadcast (Token Bucket logic handled in QueueMessage)
    _QuestieLearnerComms:QueueMessage(encoded)
end

function _QuestieLearnerComms:QueueMessage(encodedMessage)
    table.insert(rateLimitQueue, encodedMessage)
end

function _QuestieLearnerComms:ProcessQueues()
    -- 1. Refill Tokens
    local now = GetTime()
    local elapsed = now - lastTokenUpdate
    currentTokens = math.min(bucketCapacity, currentTokens + (elapsed * tokenRefillRate))
    lastTokenUpdate = now

    -- 2. Drain Outgoing Queue
    if table.getn(rateLimitQueue) > 0 and currentTokens >= 1 and (now - lastChatMessageTime) >= minChatInterval then
        local msg = table.remove(rateLimitQueue, 1)
        currentTokens = currentTokens - 1
        lastChatMessageTime = now
        
        -- Send via AceComm to Guild (Fast/Reliable)
        if IsInGuild() then
            AceComm:SendCommMessage(addonPrefix, msg, "GUILD")
        end
        
        -- Send via Hidden Channel (Global reach)
        local channelId = GetChannelName(hiddenChannelName)
        if channelId > 0 then
            SendChatMessage(msg, "CHANNEL", nil, channelId)
        end
        DebugLog("DEVELOP", "Broadcasted message. Tokens left: " .. math.floor(currentTokens))
    end

    -- 3. Process Incoming Queue (Combat Aware)
    local processCount = InCombatLockdown() and 2 or 6
    for i = 1, processCount do
        if table.getn(incomingMessageQueue) == 0 then break end
        local rawMsg = table.remove(incomingMessageQueue, 1)
        _QuestieLearnerComms:ProcessRawMessage(rawMsg.text, rawMsg.sender)
    end
end

-- Hook for Chat Message Event (Hidden Channel)
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_CHANNEL")
frame:SetScript("OnEvent", function(self, event, msg, sender, _, _, _, _, _, channelId, channelName)
    if channelName == hiddenChannelName and sender ~= UnitName("player") then
        table.insert(incomingMessageQueue, {text = msg, sender = sender})
    end
end)

function QuestieLearnerComms:OnCommReceived(prefix, message, distribution, sender)
    if prefix == addonPrefix and sender ~= UnitName("player") then
        table.insert(incomingMessageQueue, {text = message, sender = sender})
    end
end

function _QuestieLearnerComms:ProcessRawMessage(encodedMsg, sender)
    if not IsSenderTrusted(sender) then return end

    -- 1. Decode & Decompress
    local compressed = LibDeflate:DecodeForPrint(encodedMsg)
    if not compressed then
        RecordStrike(sender, "Invalid Base64 Encoding")
        return 
    end

    local serialized = LibDeflate:DecompressDeflate(compressed)
    if not serialized then 
        RecordStrike(sender, "Decompression Failed")
        return 
    end

    -- Deduplication Check
    if IsDuplicateMessage(serialized) then return end

    -- 2. Deserialize
    local success, payload = AceSerializer:Deserialize(serialized)
    if not success or type(payload) ~= "table" then
        RecordStrike(sender, "Deserialization Failed")
        return
    end

    -- 3. Version Check
    if payload._ver ~= ProtocolVersion then return end

    -- 4. Pass to Learner Processing Logic
    local op = payload.op
    local typ = payload.typ
    local id = payload.id
    local d = payload.d

    if not typ or not id or not d then return end

    DebugLog("DEVELOP", "Received " .. tostring(op) .. " " .. tostring(typ) .. " " .. tostring(id) .. " from " .. tostring(sender))

    QuestieLearner:HandleNetworkData(typ, id, d)
end
