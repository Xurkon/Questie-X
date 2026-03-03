---@type table
local EbonholdDB = QuestieLoader:CreateModule("EbonholdDB")

EbonholdDB.questData = EbonholdDB.questData or {
    -- Quest 50026: Elemental Balance
    -- Started by object 600600, kills of NPCs 17156 or 17157 count (both are elementals)
    [50026] = {
        [1] = "Elemental Balance", -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 67,                  -- Quest level
        [5] = 64,                  -- Min level
        [17] = 3518,               -- Zone (Nagrand)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 30 Elementals in Nagrand"
        },
        [10] = {
            nil,                                                                                            -- [1] creatureObjective (not used)
            nil,                                                                                            -- [2] objectObjective (not used)
            nil,                                                                                            -- [3] itemObjective (not used)
            nil,                                                                                            -- [4] reputationObjective (not used)
            {                                                                                               -- [5] killCreditObjective
                {
                    { 17153, 17154, 17155, 17156, 17157, 17159, 17160, 18062, 22309, 22310, 22311, 22313 }, -- IdList: all elemental types
                    17157,                                                                                  -- RootId: representative NPC
                    "Shattered Rumbler slain"                                                               -- Text
                }
            }
        },

        [30] = 60, -- Group size
    },

    -- Quest 50085: Savage Heights
    -- Kill 75 beasts in Blade's Edge Mountains
    [50085] = {
        [1] = "Savage Heights",    -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 70,                  -- Quest level
        [5] = 67,                  -- Min level
        [17] = 3522,               -- Zone (Blade's Edge Mountains)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 75 Beasts in Blade's Edge Mountains"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- All 47 beast-type NPCs in Blade's Edge Mountains
                    { 10204, 20058, 20109, 20327, 20330, 20714, 20728, 20729, 20747, 20748, 20749, 20751, 20924, 20925, 20987, 20998, 21022, 21033, 21042, 21123, 21124, 21373, 21423, 21470, 21796, 21839, 21952, 21956, 22044, 22052, 22110, 22114, 22123, 22132, 22135, 22136, 22141, 22142, 22181, 22268, 22490, 22492, 22498, 22987, 23036, 23343, 23380 },
                    20728, -- RootId: Bladespire Raptor (representative beast)
                    "Beast slain"
                }
            }
        },

        [30] = 75, -- Kill count
    },

    -- Quest 50086: Unstable Fauna
    -- Kill 75 beasts in Netherstorm
    [50086] = {
        [1] = "Unstable Fauna",    -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 70,                  -- Quest level
        [5] = 67,                  -- Min level
        [17] = 3523,               -- Zone (Netherstorm)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 75 Beasts in Netherstorm"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- All 18 beast-type NPCs in Netherstorm
                    { 18879, 18880, 18883, 18884, 20415, 20607, 20610, 20611, 20618, 20634, 20671, 20673, 20773, 20775, 20777, 20931, 20932, 21005 },
                    18879, -- RootId: Phase Hunter (representative beast)
                    "Beast slain"
                }
            }
        },

        [30] = 75, -- Kill count
    },

    -- Quest 50201: Dragonblight Trophy
    -- Kill 1 rare in Dragonblight
    [50201] = {
        [1] = "Dragonblight Trophy", -- Quest name
        [2] = { nil, { 600600 } },   -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 75,                    -- Quest level
        [5] = 71,                    -- Min level
        [17] = 65,                   -- Zone (Dragonblight)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 1 Rare in Dragonblight"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- 3 rare NPCs in Dragonblight (already in WotLK DB with spawns)
                    { 32417, 32409, 32400 }, -- Scarlet Highlord Daion, Crazed Indu'le Survivor, Tukemuth
                    32417,                   -- RootId: Scarlet Highlord Daion (representative rare)
                    "Rare slain"
                }
            }
        },

        [30] = 1, -- Kill count (only 1 rare needed)
    },

    -- Quest 50160: Redridge Trophy
    -- Kill 1 rare in Redridge Mountains
    [50160] = {
        [1] = "Redridge Trophy",   -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 17,                  -- Required level (Min level)
        [5] = 25,                  -- Quest level
        [17] = 44,                 -- Zone (Redridge Mountains)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 1 Rare in Redridge Mountains"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- Redridge Rares
                    { 14271, 616, 14270, 584, 14272, 14273, 947, 14269 },
                    14271, -- RootId: Ribchaser (representative rare)
                    "Rare slain"
                }
            }
        },

        [30] = 1, -- Kill count
    },

    -- Quest 50192: Zangarmarsh Trophy
    -- Kill 1 rare in Zangarmarsh
    [50192] = {
        [1] = "Zangarmarsh Trophy", -- Quest name
        [2] = { nil, { 600600 } },  -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 60,                   -- Required level (Min level)
        [5] = 63,                   -- Quest level
        [17] = 3521,                -- Zone (Zangarmarsh)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 1 Rare in Zangarmarsh"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- Zangarmarsh Rares
                    { 18682, 18680, 18681 }, -- Bog Lurker, Marticar, Coilfang Emissary
                    18682,                   -- RootId: Bog Lurker (representative rare)
                    "Rare slain"
                }
            }
        },

        [30] = 1, -- Kill count
    },

    -- Quest 50083: Forest Stalkers
    -- Kill 75 beasts in Terokkar Forest
    [50083] = {
        [1] = "Forest Stalkers",   -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 65,                  -- Quest level
        [5] = 62,                  -- Min level
        [17] = 3519,               -- Zone (Terokkar Forest)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 75 Beasts in Terokkar Forest"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- All 53 beast-type NPCs in Terokkar Forest
                    { 16932, 16933, 18467, 18464, 18466, 18670, 18465, 21723, 18461, 18648, 18750, 23219, 23051, 18463, 22424, 20682, 21515, 21854, 23163, 21816, 18476, 18477, 32956, 18437, 21634, 22337, 24922, 21804, 18470, 18438, 18647, 19607, 18468, 23338, 14866, 14868, 22100, 23206, 22972, 22105, 19659, 22326, 18707, 22807, 18469, 23167, 21635, 18492, 19616, 23162, 14869, 22339, 22987 },
                    16932, -- RootId: Razorfang Hatchling (representative beast)
                    "Beast slain"
                }
            }
        },

        [30] = 75, -- Kill count
    },

    -- Quest 50082: Marsh Predators
    -- Kill 75 beasts in Zangarmarsh
    [50082] = {
        [1] = "Marsh Predators",   -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 64,                  -- Quest level
        [5] = 62,                  -- Min level
        [17] = 3521,               -- Zone (Zangarmarsh)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 75 Beasts in Zangarmarsh"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- All beasts in Zangarmarsh
                    { 19349, 19730, 18285, 18281, 18135, 18286, 18283, 18680, 18280, 18132, 20197, 18133, 18212, 18214, 19706, 20196, 18129, 18213, 18128, 20279, 20198, 18130, 20283, 18134, 19729, 20290, 20324, 20280, 18138, 17953, 18332, 18201, 18131, 20387 },
                    19349, -- RootId: Thornfang Ravager (representative beast)
                    "Beast slain"
                }
            }
        },

        [30] = 75, -- Kill count
    },

    -- Quest 50060: Skies of Blade's Edge
    -- Kill Dragonkin in Blade's Edge Mountains
    [50060] = {
        [1] = "Skies of Blade's Edge", -- Quest name
        [2] = { nil, { 600600 } },     -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 67,                      -- Required level (Min level)
        [5] = 70,                      -- Quest level
        [17] = 3522,                   -- Zone (Blade's Edge Mountains)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Slay Dragonkin in Blade's Edge Mountains"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- All 17 dragonkin-type NPCs in Blade's Edge Mountains
                    { 18692, 21032, 20021, 20713, 21004, 23281, 23261, 21387, 22108, 21492, 23061, 21811, 21497, 23282, 21389, 22130, 23364 },
                    18692, -- RootId: Hemathion (representative dragonkin)
                    "Dragonkin slain"
                }
            }
        },
    },

    -- Quest 50030: Tundra Turbulence
    -- Kill Elementals in Borean Tundra
    [50030] = {
        [1] = "Tundra Turbulence", -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 68,                  -- Required level (Min level)
        [5] = 71,                  -- Quest level
        [17] = 3537,               -- Zone (Borean Tundra)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill Elementals in Borean Tundra"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- All 15 elemental-type NPCs in Borean Tundra
                    { 25417, 32357, 25715, 25514, 25419, 24601, 25415, 25226, 25707, 25709, 26045, 25376, 25418, 25416 },
                    25417, -- RootId: Raging Boiler (representative elemental)
                    "Elementals slain"
                }
            }
        },

        [30] = 75, -- Kill count (Assumed generic high count for zone farming quests, user said "amount varies", so we don't hardcode it in logic but usually DB needs a number. 75 puts it in line with others.)
    },

    -- Quest 50031: Stormbound
    -- Kill 30 Elementals in Storm Peaks
    [50031] = {
        [1] = "Stormbound",        -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 68,                  -- Required level (Min level)
        [5] = 73,                  -- Quest level
        [17] = 67,                 -- Zone (Storm Peaks)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill Elementals in Storm Peaks"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- All Storm Peaks elementals scraped from filter page
                    { 29504, 30450, 30184, 29844, 30387, 30160, 29624, 30001, 30474, 30120, 30053 },
                    30120, -- RootId: Seething Revenant (representative elemental)
                    "Elementals slain"
                }
            }
        },

        [30] = 30, -- Kill count (30 elementals as per quest name)
    },

    -- Quest 50087: Shadowed Beasts
    -- Kill 75 beasts in Shadowmoon Valley
    [50087] = {
        [1] = "Shadowed Beasts",   -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 67,                  -- Quest level
        [5] = 65,                  -- Min level
        [17] = 3520,               -- Zone (Shadowmoon Valley)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 75 Beasts in Shadowmoon Valley"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- All 25 beast-type NPCs in Shadowmoon Valley (excluding mounts)
                    { 19379, 19784, 20502, 20503, 21102, 21108, 21307, 21340, 21408, 21462, 21627, 21723, 21802, 21864, 21879, 21897, 21901, 22265, 23020, 23169, 23264, 23267, 23269, 23326, 23501 },
                    21723, -- RootId: Blackwind Sabercat (representative beast)
                    "Beast slain"
                }
            }
        },

        [30] = 75, -- Kill count
    },

    -- Quest 50064: Heart of the Dragonflights
    -- Kill 30 dragonkin in Dragonblight
    [50064] = {
        [1] = "Heart of the Dragonflights", -- Quest name
        [2] = { nil, { 600600 } },          -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 73,                           -- Quest level
        [5] = 71,                           -- Min level
        [17] = 3524,                        -- Zone (Dragonblight)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 30 Dragonkin in Dragonblight"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- All 49 dragonkin NPCs in Dragonblight (excluding 32572 which is an object)
                    { 26276, 26277, 26322, 26349, 26443, 26593, 26917, 26925, 26933, 26949, 26983, 27255, 27506, 27530, 27542, 27575, 27608, 27629, 27682, 27725, 27763, 27765, 27785, 27789, 27856, 27896, 27897, 27898, 27900, 27925, 27935, 27938, 27940, 27943, 27948, 27950, 27953, 27990, 27996, 30058, 31333, 31334, 31393, 32180, 32185, 32186, 32352, 32533, 38017 },
                    26322, -- RootId: Arcane Wyrm (representative dragonkin)
                    "Dragonkin slain"
                }
            }
        },

        [30] = 30, -- Kill count
    },

    -- Quest 50095: Peak Predators
    -- Kill 75 beasts in The Storm Peaks
    [50095] = {
        [1] = "Peak Predators",    -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 68,                  -- Required level (Min level)
        [5] = 73,                  -- Quest level
        [17] = 67,                 -- Zone (The Storm Peaks)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill Beasts in The Storm Peaks"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- All 24 beast NPCs in Storm Peaks (hostile to both factions)
                    { 29411, 29590, 30148, 32475, 29958, 30164, 29358, 29469, 30422, 30445, 30291, 29412, 30448, 29461, 29605, 30447, 29319, 29390, 29562, 30340, 30292, 29808, 30174, 34920 },
                    29319, -- RootId: Icepaw Bear (representative beast)
                    "Beasts slain"
                }
            }
        },

        [30] = 75, -- Kill count (75 beasts as per quest name)
    },

    -- Quest 50096: Peak Predators
    -- Kill 75 beasts in Icecrown
    [50096] = {
        [1] = "Peak Predators",    -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 73,                  -- Required level (Min level)
        [5] = 77,                  -- Quest level
        [17] = 210,                -- Zone (Icecrown)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill Beasts in Icecrown"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- All 12 beast NPCs in Icecrown (hostile to both factions)
                    { 29392, 30206, 30330, 30430, 31265, 31747, 32484, 35060, 35061, 35071, 35470, 35482 },
                    29392, -- RootId: Ravenous Jaws (representative beast)
                    "Beasts slain"
                }
            }
        },

        [30] = 75, -- Kill count (75 beasts as per quest name)
    },

    -- Quest 50151: Icecrown Advance
    -- Requires completing any 6 quests in Icecrown
    -- Auto-complete, no turn-in location
    [50151] = {
        [1] = "Icecrown Advance",  -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 80,                  -- Quest level
        [5] = 73,                  -- Min level
        [17] = 210,                -- Zone (Icecrown)
        [8] = {
            "This quest requires completing any 6 quests in Icecrown. The quest will automatically complete once the objective is met.",
            "Complete 6 quests in Icecrown"
        },
        [9] = { "Complete 6 quests in Icecrown", nil },
    },

    -- Quest 50205: Storm Peaks Trophy
    -- Kill 1 rare in The Storm Peaks
    [50205] = {
        [1] = "Storm Peaks Trophy", -- Quest name
        [2] = { nil, { 600600 } },  -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 68,                   -- Min level
        [5] = 80,                   -- Quest level
        [17] = 67,                  -- Zone (The Storm Peaks)
        [8] = {
            "Kill a rare NPC in The Storm Peaks to complete this quest.",
            "Kill a rare in The Storm Peaks"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- All 4 rare NPCs in The Storm Peaks
                    { 35189, 32491, 32630, 32500 },
                    35189, -- RootId: Skoll (representative rare)
                    "Rare slain"
                }
            }
        },

        [30] = 1, -- Kill count (1 rare)
    },

    -- Quest 50066: Stormforged Scales
    -- Kill 30 dragonkin in The Storm Peaks
    [50066] = {
        [1] = "Stormforged Scales", -- Quest name
        [2] = { nil, { 600600 } },  -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 68,                   -- Min level
        [5] = 80,                   -- Quest level
        [17] = 67,                  -- Zone (The Storm Peaks)
        [8] = {
            "The dragons of the Storm Peaks must be dealt with before we can proceed with our plans. Destroy 30 dragonkin in the Storm Peaks to show the Storm Peaks dragons that they are not welcome here.",
            "Slain: 0/30"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- All 8 dragonkin NPCs in The Storm Peaks (zone 67) with valid spawn data
                    { 32491, 32630, 29753, 29755, 29460, 30275, 30461 },
                    32491, -- RootId: Time-Lost Proto-Drake (representative dragonkin)
                    "Dragonkin slain"
                }
            }
        },

        [30] = 30, -- Kill count (30 dragonkin)
    },

    -- Quest 50145: Fjord Front
    -- Requires completing any 6 quests in Howling Fjord
    -- Auto-complete, no turn-in location
    [50145] = {
        [1] = "Fjord Front",       -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 74,                  -- Quest level
        [5] = 68,                  -- Min level
        [17] = 495,                -- Zone (Howling Fjord)
        [8] = {
            "This quest requires completing any 6 quests in Howling Fjord. The quest will automatically complete once the objective is met.",
            "Complete 6 quests in Howling Fjord"
        },
        [9] = { "Complete 6 quests in Howling Fjord", nil },
    },

    -- Quest 50098: Morogh Missions
    -- Requires completing any 6 quests in Dun Morogh
    -- Auto-complete, no turn-in location
    [50098] = {
        [1] = "Morogh Missions",   -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 1,                   -- Min level
        [5] = 60,                  -- Quest level
        [17] = 1,                  -- Zone (Dun Morogh)
        [8] = {
            "This quest requires completing any 6 quests in Dun Morogh. The quest will automatically complete once the objective is met.",
            "Complete 6 quests in Dun Morogh"
        },
        [9] = { "Complete 6 quests in Dun Morogh", nil },
    },

    -- Quest 50100: Azuremyst Aid
    -- Requires completing any 6 quests in Azuremyst Isle
    -- Auto-complete, no turn-in location
    [50100] = {
        [1] = "Azuremyst Aid",     -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 1,                   -- Min level
        [5] = 60,                  -- Quest level
        [17] = 3524,               -- Zone (Azuremyst Isle)
        [8] = {
            "This quest requires completing any 6 quests in Azuremyst Isle. The quest will automatically complete once the objective is met.",
            "Complete 6 quests in Azuremyst Isle"
        },
        [9] = { "Complete 6 quests in Azuremyst Isle", nil },
    },

    -- Quest 50094: Wild Basin
    -- Kill 75 beasts in Sholazar Basin
    [50094] = {
        [1] = "Wild Basin",        -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 68,                  -- Required level (Min level)
        [5] = 73,                  -- Quest level
        [17] = 3711,               -- Zone (Sholazar Basin)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill Beasts in Sholazar Basin"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- All 29 beast NPCs in Sholazar Basin (hostile to both factions)
                    { 32485, 28009, 32481, 28097, 28083, 28001, 28213, 28297, 28358, 28317, 28096, 28325, 28288, 28399, 29044, 28086, 28011, 28085, 28380, 28847, 29033, 28010, 28002, 29034, 28129, 28004, 28087, 29018, 28003 },
                    28001, -- RootId: Dreadsaber (representative beast)
                    "Beasts slain"
                }
            }
        },

        [30] = 75, -- Kill count (75 beasts as per quest name)
    },

    -- Quest 50202: Grizzly Trophy
    -- Kill 1 rare in Grizzly Hills
    [50202] = {
        [1] = "Grizzly Trophy",    -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 74,                  -- Quest level
        [5] = 71,                  -- Min level
        [17] = 394,                -- Zone (Grizzly Hills)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 1 Rare in Grizzly Hills"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- 4 rare NPCs in Grizzly Hills
                    { 38453, 32429, 32422, 32438 }, -- Arcturis, Seething Hate, Grocklar, Syreian the Bonecarver
                    38453,                          -- RootId: Arcturis (representative rare)
                    "Rare slain"
                }
            }
        },

        [30] = 1, -- Kill count (only 1 rare needed)
    },

    -- Quest 50203: Zul'Drak Trophy
    -- Kill 1 rare in Zul'Drak
    [50203] = {
        [1] = "Zul'Drak Trophy",   -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 77,                  -- Quest level
        [5] = 74,                  -- Min level
        [17] = 66,                 -- Zone (Zul'Drak)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 1 Rare in Zul'Drak"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- 4 rare NPCs in Zul'Drak
                    { 33776, 32471, 32475, 32447 }, -- Gondria, Griegen, Terror Spinner, Zul'drak Sentinel
                    33776,                          -- RootId: Gondria (representative rare)
                    "Rare slain"
                }
            }
        },

        [30] = 1, -- Kill count (only 1 rare needed)
    },

    -- Quest 50149: Basin Expeditions
    -- Complete 6 quests in Sholazar Basin (Any Quest)
    [50149] = {
        [1] = "Basin Expeditions", -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 76,                  -- Quest level
        [5] = 74,                  -- Min level
        [17] = 3711,               -- Zone (Sholazar Basin)
        [8] = {
            "This quest requires completing any 6 quests in Sholazar Basin. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Complete 6 quests in Sholazar Basin"
        },
        [9] = { "Complete 6 quests in Sholazar Basin", nil },
    },
    -- Quest 50154: Teldrassil Trophy
    -- Kill 1 rare in Teldrassil
    [50154] = {
        [1] = "Teldrassil Trophy", -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 1,                   -- Min level
        [5] = 10,                  -- Quest level
        [17] = 141,                -- Zone (Teldrassil)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 1 Rare in Teldrassil"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- 6 rare NPCs in Teldrassil
                    { 14432, 3535, 14430, 14428, 14431, 14429 },
                    3535, -- RootId: Blackmoss the Fetid (representative rare)
                    "Rare slain"
                }
            }
        },

        [30] = 1, -- Kill count
    },

    -- Quest 50099: Shadow of Teldrassil
    -- Complete 6 quests in Teldrassil (Any Quest)
    [50099] = {
        [1] = "Shadow of Teldrassil", -- Quest name
        [2] = { nil, { 600600 } },    -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 1,                      -- Min level
        [5] = 60,                     -- Quest level
        [17] = 141,                   -- Zone (Teldrassil)
        [8] = {
            "This quest requires completing any 6 quests in Teldrassil. The quest will automatically complete once the objective is met.",
            "Complete 6 quests in Teldrassil"
        },
        [9] = { "Complete 6 quests in Teldrassil", nil },
    },

    -- Quest 50103: Darkshore Defense
    -- Complete 6 quests in Darkshore (Any Quest)
    [50103] = {
        [1] = "Darkshore Defense", -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 10,                  -- Min level
        [5] = 1,                   -- Quest level
        [17] = 331,                -- Zone (Darkshore)
        [8] = {
            "This quest requires completing any 6 quests in Darkshore. The quest will automatically complete once the objective is met.",
            "Complete 6 quests in Darkshore"
        },
        [9] = { "Complete 6 quests in Darkshore", nil },
    },

    -- Quest 50104: Bloodmyst Recovery
    -- Complete 6 quests in Bloodmyst Isle (Any Quest)
    [50104] = {
        [1] = "Bloodmyst Recovery", -- Quest name
        [2] = { nil, { 600600 } },  -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 10,                   -- Min level
        [5] = 1,                    -- Quest level
        [17] = 3525,                -- Zone (Bloodmyst Isle)
        [8] = {
            "This quest requires completing any 6 quests in Bloodmyst Isle. The quest will automatically complete once the objective is met.",
            "Complete 6 quests in Bloodmyst Isle"
        },
        [9] = { "Complete 6 quests in Bloodmyst Isle", nil },
    },

    -- Quest 50108: Trials of Durotar
    -- Complete 6 quests in Durotar (Any Quest)
    [50108] = {
        [1] = "Trials of Durotar", -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 1,                   -- Min level
        [5] = 60,                  -- Quest level
        [17] = 14,                 -- Zone (Durotar)
        [8] = {
            "This quest requires completing any 6 quests in Durotar. The quest will automatically complete once the objective is met.",
            "Complete 6 quests in Durotar"
        },
        [9] = { "Complete 6 quests in Durotar", nil },
    },
    -- Quest 50097: Elwynn Errands
    -- Complete 6 quests in Elwynn Forest (Any Quest)
    [50097] = {
        [1] = "Elwynn Errands",    -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 1,                   -- Min level
        [5] = 1,                   -- Quest level
        [17] = 12,                 -- Zone (Elwynn Forest)
        [8] = {
            "This quest requires completing any 6 quests in Elwynn Forest. The quest will automatically complete once the objective is met.",
            "Complete 6 quests in Elwynn Forest"
        },
        [9] = { "Complete 6 quests in Elwynn Forest", nil },
    },

    -- Quest 50105: Redridge Resolve
    -- Complete 6 quests in Redridge Mountains (Any Quest)
    [50105] = {
        [1] = "Redridge Resolve",  -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 10,                  -- Min level
        [5] = 1,                   -- Quest level
        [17] = 44,                 -- Zone (Redridge Mountains)
        [8] = {
            "This quest requires completing any 6 quests in Redridge Mountains. The quest will automatically complete once the objective is met.",
            "Complete 6 quests in Redridge Mountains"
        },
        [9] = { "Complete 6 quests in Redridge Mountains", nil },
    },

    -- Quest 50111: Song of the Woods
    -- Complete 6 quests in Eversong Woods (Any Quest)
    [50111] = {
        [1] = "Song of the Woods", -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 1,                   -- Min level
        [5] = 60,                  -- Quest level
        [17] = 3430,               -- Zone (Eversong Woods)
        [8] = {
            "This quest requires completing any 6 quests in Eversong Woods. The quest will automatically complete once the objective is met.",
            "Complete 6 quests in Eversong Woods"
        },
        [9] = { "Complete 6 quests in Eversong Woods", nil },
    },

    -- Quest 50157: Modan Trophy
    -- Kill 1 rare in Loch Modan
    [50157] = {
        [1] = "Modan Trophy",      -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 10,                  -- Min level
        [5] = 10,                  -- Quest level
        [17] = 38,                 -- Zone (Loch Modan)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 1 Rare in Loch Modan"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- 7 rare NPCs in Loch Modan
                    { 1425, 1399, 2476, 14266, 14268, 14267, 1398 },
                    1425, -- RootId: Grizlak (representative rare)
                    "Rare slain"
                }
            }
        },

        [30] = 1, -- Kill count
    },

    -- Quest 50156: Westfall Trophy
    -- Kill 1 rare in Westfall
    [50156] = {
        [1] = "Westfall Trophy",   -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 10,                  -- Min level
        [5] = 10,                  -- Quest level
        [17] = 40,                 -- Zone (Westfall)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 1 Rare in Westfall"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- 9 rare NPCs in Westfall
                    { 573, 599, 462, 520, 596, 572, 1424, 506, 519 },
                    573, -- RootId: Foe Reaper 4000 (representative rare)
                    "Rare slain"
                }
            }
        },

        [30] = 1, -- Kill count
    },

    -- Quest 50162: Wetlands Trophy
    -- Kill 1 rare in Wetlands
    [50162] = {
        [1] = "Wetlands Trophy",   -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 10,                  -- Min level
        [5] = 10,                  -- Quest level
        [17] = 11,                 -- Zone (Wetlands)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 1 Rare in Wetlands"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- 8 rare NPCs in Wetlands
                    { 1037, 1140, 2108, 14425, 14433, 2090, 1112, 14424 },
                    1037, -- RootId: Dragonmaw Battlemaster (representative rare)
                    "Rare slain"
                }
            }
        },

        [30] = 1, -- Kill count
    },

    -- Quest 50153: Morogh Trophy
    -- Kill 1 rare in Dun Morogh
    [50153] = {
        [1] = "Morogh Trophy",     -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 10,                  -- Quest level
        [5] = 1,                   -- Min level
        [17] = 1,                  -- Zone (Dun Morogh)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 1 Rare in Dun Morogh"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- 6 rare NPCs in Dun Morogh
                    { 1132, 1130, 8503, 1260, 1137, 1119 }, -- Timber, Bjarn, Gibblewilt, Great Father Arctikus, Edan the Howler, Hammerspine
                    1132,                                   -- RootId: Timber (representative rare)
                    "Rare slain"
                }
            }
        },

        [30] = 1, -- Kill count (only 1 rare needed)
    },

    -- Quest 50164: Tirisfal Trophy
    -- Kill 1 rare in Tirisfal Glades
    [50164] = {
        [1] = "Tirisfal Trophy",   -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 10,                  -- Quest level
        [5] = 1,                   -- Min level
        [17] = 85,                 -- Zone (Tirisfal Glades)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 1 Rare in Tirisfal Glades"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- 9 rare NPCs in Tirisfal Glades
                    { 10357, 10359, 10356, 1936, 1531, 1911, 1910, 10358, 1533 }, -- Ressan the Needler, Sri'skulk, Bayne, Farmer Solliden, Lost Soul, Deeb, Muad, Fellicent's Shade, Tormented Spirit
                    10357,                                                        -- RootId: Ressan the Needler (representative rare)
                    "Rare slain"
                }
            }
        },

        [30] = 1, -- Kill count (only 1 rare needed)
    },

    -- Quest 50176: Arathi Trophy
    -- Kill 1 rare in Arathi Highlands
    [50176] = {
        [1] = "Arathi Trophy",     -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 25,                  -- Quest level
        [5] = 20,                  -- Min level
        [17] = 45,                 -- Zone (Arathi Highlands)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 1 Rare in Arathi Highlands"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- 10 rare NPCs in Arathi Highlands
                    { 2598, 2603, 2600, 2604, 2606, 2779, 2605, 2609, 2602, 2601 },
                    2606, -- RootId: Nimar the Slayer (representative rare)
                    "Rare slain"
                }
            }
        },

        [30] = 1, -- Kill count (only 1 rare needed)
    },
    [50150] = {
        [1] = "Storm Peak Orders",
        [2] = { nil, { 600600 } },
        [4] = 80,
        [5] = 77,
        [17] = 67,
        [8] = {
            "Complete any 6 quests in The Storm Peaks.",
            "Complete 6 Quests"
        },
        [9] = { "Complete 6 Quests", nil },
    },

    -- Quest 50195: Blade's Edge Trophy
    -- Kill 1 rare in Blade's Edge Mountains
    [50195] = {
        [1] = "Blade's Edge Trophy", -- Quest name
        [2] = { nil, { 600600 } },   -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 70,                    -- Quest level
        [5] = 67,                    -- Min level
        [17] = 3522,                 -- Zone (Blade's Edge Mountains)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 1 Rare in Blade's Edge Mountains"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- 3 rare NPCs in Blade's Edge Mountains
                    { 18690, 18692, 18693 },
                    18692, -- RootId: Hemathion (representative rare)
                    "Rare slain"
                }
            }
        },

        [30] = 1, -- Kill count (only 1 rare needed)
    },

    -- Quest 50044: Fel Scars of Nagrand
    -- Kill 40 demons in Nagrand
    [50044] = {
        [1] = "Fel Scars of Nagrand", -- Quest name
        [2] = { nil, { 600600 } },    -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 64,                     -- Min level
        [5] = 67,                     -- Quest level
        [17] = 3518,                  -- Zone (Nagrand)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 40 Demons in Nagrand"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- 14 demon NPCs in Nagrand
                    { 18683, 17151, 17981, 22357, 18567, 17152, 18535, 18661, 22362, 22394, 18536, 18401, 18660, 16945 },
                    18683, -- RootId: Voidwalker Minion (representative demon)
                    "Demon slain"
                }
            }
        },

        [30] = 40, -- Kill count
    },

    -- Quest 50196: Netherstorm Trophy
    -- Kill 1 rare in Netherstorm
    [50196] = {
        [1] = "Netherstorm Trophy", -- Quest name
        [2] = { nil, { 600600 } },  -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 67,                   -- Min level
        [5] = 70,                   -- Quest level
        [17] = 3523,                -- Zone (Netherstorm)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 1 Rare in Netherstorm"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- 3 rare NPCs in Netherstorm
                    { 20932, 18698, 18697 },
                    20932, -- RootId: Nuramoc (representative rare)
                    "Rare slain"
                }
            }
        },

        [30] = 1, -- Kill count
    },

    -- Quest 50199: Borean Trophy
    -- Kill 1 rare in Borean Tundra
    [50199] = {
        [1] = "Borean Trophy",     -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 68,                  -- Min level
        [5] = 71,                  -- Quest level
        [17] = 3537,               -- Zone (Borean Tundra)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 1 Rare in Borean Tundra"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- 3 rare NPCs in Borean Tundra
                    { 32358, 32361, 32357 },
                    32358, -- RootId: Fumblub Gearwind (representative rare)
                    "Rare slain"
                }
            }
        },

        [30] = 1, -- Kill count
    },

    -- Quest 50034: Ashen Corruption
    -- Kill 40 demons in Ashenvale
    [50034] = {
        [1] = "Ashen Corruption",  -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 20,                  -- Min level
        [5] = 25,                  -- Quest level
        [17] = 331,                -- Zone (Ashenvale)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 40 Demons in Ashenvale"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- 23 demon NPCs in Ashenvale
                    { 6072, 3772, 3758, 17300, 6073, 3762, 3774, 11697, 3765, 3771, 3767, 3763, 4619, 6071, 3757, 3770, 3755, 3752, 6115, 3759, 10928, 3754, 10647 },
                    6072, -- RootId: Diathorus the Seeker (representative demon)
                    "Demon slain"
                }
            }
        },

        [30] = 40, -- Kill count
    },
    -- Quest 50197: Shadowmoon Trophy
    -- Kill 1 rare in Shadowmoon Valley
    [50197] = {
        [1] = "Shadowmoon Trophy", -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 67,                  -- Min level
        [5] = 70,                  -- Quest level
        [17] = 3520,               -- Zone (Shadowmoon Valley)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 1 Rare in Shadowmoon Valley"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- 3 rare NPCs in Shadowmoon Valley
                    { 18694, 18695, 18696 }, -- Collidus the Warp-Watcher, Ambassador Jerrikar, Kraator
                    18694,                   -- RootId: Collidus the Warp-Watcher (representative rare)
                    "Rare slain"
                }
            }
        },

        [30] = 1, -- Kill count
    },

    -- Quest 50020: Spires of Chaos
    -- Kill 30 elementals in Thousand Needles
    [50020] = {
        [1] = "Spires of Chaos",   -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 25,                  -- Min level
        [5] = 30,                  -- Quest level
        [17] = 400,                -- Zone (Thousand Needles)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 30 Elementals in Thousand Needles"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- 5 elemental NPCs in Thousand Needles
                    { 4499, 4120, 10756, 9377, 10757 },
                    4120, -- RootId: Thundering Boulderkin (representative elemental)
                    "Elemental slain"
                }
            }
        },

        [30] = 30, -- Kill count
    },

    -- Quest 50173: Northern Jungle Trophy
    -- Kill 1 rare in Stranglethorn Vale (Northern)
    [50173] = {
        [1] = "Northern Jungle Trophy", -- Quest name
        [2] = { nil, { 600600 } },      -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 25,                       -- Min level
        [5] = 45,                       -- Quest level
        [17] = 33,                      -- Zone (Stranglethorn Vale)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 1 Rare in Stranglethorn Vale"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- 9 rare NPCs in Stranglethorn Vale
                    { 1552, 14488, 9046, 14492, 14487, 14491, 14490, 11383, 2541 },
                    1552, -- RootId: Scale Belly (representative rare)
                    "Rare slain"
                }
            }
        },

        [30] = 1, -- Kill count
    },

    -- Quest 50175: Alterac Trophy
    -- Kill 1 rare in Alterac Mountains
    [50175] = {
        [1] = "Alterac Trophy",    -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 25,                  -- Min level
        [5] = 40,                  -- Quest level
        [17] = 36,                 -- Zone (Alterac Mountains)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 1 Rare in Alterac Mountains"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- 8 rare NPCs in Alterac Mountains
                    { 2447, 14223, 14221, 14222, 2453, 2258, 14281, 2452 },
                    2447, -- RootId: Narillasanz (representative rare)
                    "Rare slain"
                }
            }
        },

        [30] = 1, -- Kill count
    },

    -- Quest 50089: Tundra Hunters
    -- Kill 75 beasts in Borean Tundra
    [50089] = {
        [1] = "Tundra Hunters",    -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 68,                  -- Min level
        [5] = 73,                  -- Quest level
        [17] = 68,                 -- Zone (Borean Tundra)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 75 Beasts in Borean Tundra"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- 43 Beasts in Borean Tundra
                    { 25454, 32361, 25488, 25968, 25675, 25487, 25203, 25829, 25680, 25489, 25481, 25791, 25482, 24614, 25295, 25774, 25743, 18375, 26174, 25498, 26160, 24637, 24613, 18379, 25862, 25850, 25204, 25596, 25750, 18378, 25464, 27074, 25881, 25817, 24765, 27365, 26047, 25606, 25988, 18376, 18380, 25362, 25990 },
                    25454, -- RootId: Tundra Crawler (representative)
                    "Beast slain"
                }
            }
        },

        [30] = 75, -- Kill count
    },

    -- Quest 50183: Southern Jungle Trophy
    -- Kill 1 rare in Stranglethorn Vale (Southern)
    [50183] = {
        [1] = "Southern Jungle Trophy", -- Quest name
        [2] = { nil, { 600600 } },      -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 25,                       -- Min level
        [5] = 45,                       -- Quest level
        [17] = 33,                      -- Zone (Stranglethorn Vale)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 1 Rare in Stranglethorn Vale"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- 9 rare NPCs in Stranglethorn Vale
                    { 1552, 14488, 9046, 14487, 14492, 14490, 14491, 2541, 11383 },
                    1552, -- RootId: Scale Belly (representative rare)
                    "Rare slain"
                }
            }
        },

        [30] = 1, -- Kill count
    },

    -- Quest 50200: Fjord Trophy
    -- Kill 1 rare in Howling Fjord
    [50200] = {
        [1] = "Fjord Trophy",      -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 68,                  -- Min level
        [5] = 72,                  -- Quest level
        [17] = 495,                -- Zone (Howling Fjord)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 1 Rare in Howling Fjord"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- 3 rare NPCs in Howling Fjord
                    { 32398, 32377, 32386 },
                    32398, -- RootId: King Ping (representative rare)
                    "Rare slain"
                }
            }
        },

        [30] = 1, -- Kill count
    },

    -- Quest 50045: Demon's at the Edge
    -- Kill 40 demons in Blade's Edge Mountains
    [50045] = {
        [1] = "Demon's at the Edge",
        [2] = { nil, { 600600 } },
        [4] = 65,    -- Min level
        [5] = 68,    -- Quest level
        [17] = 3522, -- Zone (Blade's Edge Mountains)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 40 Demons in Blade's Edge Mountains"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- 37 Demons in Blade's Edge Mountains
                    { 20557, 22180, 19973, 22195, 23355, 19960, 19979, 19963, 22291, 22304, 16952, 23353, 23174, 23173, 21021, 19747, 19978, 23078, 23055, 23212, 21837, 22500, 19980, 23199, 12922, 21519, 19961, 22204, 22499, 23220, 23113, 21516, 22281, 23230, 23354, 22474, 23275 },
                    20557, -- RootId: Wrath Hound (representative demon)
                    "Demon slain"
                }
            }
        },

        [30] = 40, -- Kill count
    },

    -- Quest 50063: Frostbound Brood
    -- Kill 30 dragonkin in Borean Tundra
    [50063] = {
        [1] = "Frostbound Brood",
        [2] = { nil, { 600600 } },
        [4] = 68,
        [5] = 71,
        [17] = 3537, -- Zone (Borean Tundra)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 30 Dragonkin in Borean Tundra"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- 16 Dragonkin in Borean Tundra
                    { 25728, 26127, 25711, 25721, 25448, 32534, 25585, 26232, 25712, 25717, 25722, 24770, 25716, 26231, 25713, 26310 },
                    25728, -- RootId: Coldarra Wyrmkin (representative dragonkin)
                    "Dragonkin slain"
                }
            }
        },

        [30] = 30, -- Kill count
    },


    -- Quest 50178: Badlands Trophy
    -- Kill 1 rare in Badlands
    [50178] = {
        [1] = "Badlands Trophy",   -- Quest name
        [2] = { nil, { 600600 } }, -- startedBy: {{npcIds}, {objectIds}, {itemIds}}
        [4] = 35,                  -- Min level
        [5] = 40,                  -- Quest level
        [17] = 3,                  -- Zone (Badlands)
        [8] = {
            "This is a custom objective. Upon completion, you will automatically receive the assigned reward. If you die, the quest will be removed from your quest log. This quest is automatically rewarded upon completion.",
            "Kill 1 Rare in Badlands"
        },
        [10] = {
            nil, -- [1] creatureObjective (not used)
            nil, -- [2] objectObjective (not used)
            nil, -- [3] itemObjective (not used)
            nil, -- [4] reputationObjective (not used)
            {    -- [5] killCreditObjective
                {
                    -- 10 rare NPCs in the Badlands
                    { 2850, 2931, 14224, 2754, 2753, 2752, 2749, 7057, 2744, 2751 },
                    2850, -- RootId: Broken Tooth (representative rare)
                    "Rare slain"
                }
            }
        },

        [30] = 1, -- Kill count
    },

}

-- Backward compatibility
EbonholdQuestDB = EbonholdQuestDB or {}
EbonholdQuestDB.questData = EbonholdDB.questData
