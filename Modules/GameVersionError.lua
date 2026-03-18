---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

local _, _, _, tocVersion = GetBuildInfo()
if tocVersion and tocVersion < 50000 then
    -- This is a Classic-era client (Turtle, Era, WotLK, etc.)
    return
end

-- No timeres or other fancy stuff as 1.12 client is very limited.

-- StaticPopup has very limited width, so text is split to many lines.
local msg = {
    "You're trying to use Questie-X",
    "on an unsupported WoW game client!",

    "WoW \"retail\" is NOT supported.",
    "Please use a Classic-era client.",

    "Questie-X only supports",
    "WoW Classic (Vanilla/TBC/Wrath)!",
}

StaticPopupDialogs["QUESTIE_VERSION_ERROR"] = {
    text = "|cffff0000ERROR|r\n" .. msg[1] .. "\n" .. msg[2] .. "\n\n" .. msg[3] .. "\n" .. msg[4] .. "\n\n" .. msg[5] .. " " .. msg[6],
    button2 = "OK",
    hasEditBox = false,
    whileDead = true
}

StaticPopup_Show("QUESTIE_VERSION_ERROR")

DEFAULT_CHAT_FRAME:AddMessage("---------------------------------")
DEFAULT_CHAT_FRAME:AddMessage("|cffff0000ERROR|r: |cff42f5ad" .. msg[1] .. " " .. msg[2] .. "|r")
DEFAULT_CHAT_FRAME:AddMessage("|cffff0000ERROR|r: |cff42f5ad" .. msg[3] .. " " .. msg[4] .. "|r")
DEFAULT_CHAT_FRAME:AddMessage("|cffff0000ERROR|r: |cff42f5ad" .. msg[5] .. " " .. msg[6] .. "|r")
DEFAULT_CHAT_FRAME:AddMessage("---------------------------------")
