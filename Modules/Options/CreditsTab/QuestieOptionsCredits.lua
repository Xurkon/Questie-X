-------------------------
--Import modules.
-------------------------
---@type QuestieOptions
local QuestieOptions = QuestieLoader:ImportModule("QuestieOptions");
---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

QuestieOptions.tabs.credits = {}

function QuestieOptions.tabs.credits:Initialize()
    return {
        name = function() return l10n('Credits'); end,
        type = "group",
        order = 10,
        args = {
            logo = {
                type = "description",
                order = 0.5,
                name = "",
                image = "Interface\\AddOns\\Questie-X\\Icons\\QuestieXlogo.tga",
                imageWidth = 512,
                imageHeight = 128,
            },
            credits_header = {
                type = "header",
                order = 1,
                name = function() return l10n('Questie-X Credits'); end,
            },
            maintainer_group = {
                type = "group",
                order = 2,
                inline = true,
                name = function() return l10n('Project Maintainer'); end,
                args = {
                    maintainer = {
                        type = "description",
                        order = 1,
                        name = function() return Questie:Colorize('Xurkon', '87CEEB'); end,
                        fontSize = "large",
                    },
                },
            },
            original_dev_group = {
                type = "group",
                order = 3,
                inline = true,
                name = function() return l10n('Original Developers'); end,
                args = {
                    original_devs = {
                        type = "description",
                        order = 1,
                        name = function() return 'The Questie Team'; end,
                        fontSize = "medium",
                    },
                },
            },
            contributors_group = {
                type = "group",
                order = 4,
                inline = true,
                name = function() return l10n('Core Contributors'); end,
                args = {
                    contributors = {
                        type = "description",
                        order = 1,
                        name = function() return 'Aero-stier, Schaka, dy-sh (Questie 3.3.5 / PE-Questie)'; end,
                        fontSize = "medium",
                    },
                },
            },
            data_group = {
                type = "group",
                order = 5,
                inline = true,
                name = function() return l10n('Special Data Contributions'); end,
                args = {
                    ascension_data = {
                        type = "description",
                        order = 1,
                        name = function() return 'Majed (3majed) - Project Ascension Quest & NPC data'; end,
                        fontSize = "medium",
                    },
                },
            },
            thanks_group = {
                type = "group",
                order = 6,
                inline = true,
                name = function() return l10n('Special Thanks'); end,
                args = {
                    thanks = {
                        type = "description",
                        order = 1,
                        name = function() return 'The Turtle WoW, Project Ascension, and Project Ebonhold communities for their ongoing support and feedback.'; end,
                        fontSize = "medium",
                    },
                },
            },
        },
    }
end
