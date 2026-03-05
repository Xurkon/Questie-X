---@class Tutorial
---@field Initialize function
local Tutorial = QuestieLoader:CreateModule("Tutorial")

--Ascension

Tutorial.chooseObjectiveFrame = Tutorial.chooseObjectiveFrame or nil
Tutorial.ascensionScalingFrame = Tutorial.ascensionScalingFrame or nil

---@type AvailableQuests
local AvailableQuests = QuestieLoader:ImportModule("AvailableQuests")

---@type QuestieQuest
local QuestieQuest = QuestieLoader:ImportModule("QuestieQuest")

---@type QuestieTracker
local QuestieTracker = QuestieLoader:ImportModule("QuestieTracker")

function Tutorial.CreateAscensionScalingFrame()
    if Tutorial.ascensionScalingFrame then
        Tutorial.ascensionScalingFrame:Show()
        return
    end
    local baseFrame = CreateFrame("Frame", "QuestieTutorialAscensionScaling", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    baseFrame:SetSize(780, 470)
    baseFrame:SetPoint("CENTER", 0, 0)
    baseFrame:SetFrameStrata("HIGH")
    baseFrame:EnableMouse(true)

    baseFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    baseFrame:SetBackdropColor(0, 0, 0, 0.95)
    baseFrame:SetBackdropBorderColor(1, 1, 1, 1)

    -- Title
    local title = baseFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetText("Ascension Level Scaling")
    title:SetPoint("TOP", 0, -16)

    ----------------------------------------------------------------
    -- Helper: Create Card
    ----------------------------------------------------------------
    local function CreateCard(parent, xOffset, config)
        local card = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate")
        card:SetSize(288, 396)
        card:SetPoint("TOP", parent, "TOP", xOffset, -48)
        card:EnableMouse(true)


		-- Card background (Skill style)
		local bg = card:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(card)
		bg:SetAtlas("SkillCardNormalQuality3", true)
		card.bg = bg
		
		card:SetScript("OnEnter", function()
			card.bg:SetAtlas("SkillCardGoldQuality3", true)
		end)

		card:SetScript("OnLeave", function()
			card.bg:SetAtlas("SkillCardNormalQuality3", true)
		end)

        -- Icon
        local icon = card:CreateTexture(nil, "ARTWORK")
        if config.atlas then
            icon:SetAtlas(config.atlas, true)
        else
            icon:SetTexture(config.texture)
        end
        icon:SetSize(192, 192)
        icon:SetPoint("TOP", 0, -80)

        -- Title text
        local titleText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        titleText:SetText(config.title)
        titleText:SetPoint("TOP", icon, "BOTTOM", 0, -6)

        -- Description
        local desc = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        desc:SetText(config.desc)
        desc:SetWidth(260)
        desc:SetJustifyH("CENTER")
        desc:SetPoint("TOP", titleText, "BOTTOM", 0, -4)

        -- Small quest icon
        local questIcon = card:CreateTexture(nil, "OVERLAY")
        questIcon:SetTexture(config.questIcon)
        questIcon:SetSize(32, 32)
        questIcon:SetPoint("BOTTOM", desc, "TOP", 0, 34)

        -- Make whole card clickable
		card:SetScript("OnMouseUp", function()
		Questie.db.profile.enableAscensionScaling = config.enable
		Questie.db.profile.ascensionScalingAsked = true

		-- Force options & map refresh
		Questie.db.profileChanged = true
		
		AvailableQuests.CalculateAndDrawAll()
		QuestieTracker:Update()
		baseFrame:Hide()
		end)
		
		-- Setting change later
		local footerText = baseFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		footerText:SetText("You can change this later from Questie settings.")
		footerText:SetTextColor(1, 0.82, 0, 1)
		footerText:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
		footerText:SetPoint("BOTTOM", 0, 12)
    end

    ----------------------------------------------------------------
    -- ENABLE CARD
    ----------------------------------------------------------------
    CreateCard(baseFrame, -180, {
        atlas = "ExperienceIconLevelScaling",
        title = "Scale Quest Levels",
        desc = "Low-level quests scale to your level\nand remain relevant.",
        questIcon = "Interface\\AddOns\\Questie-X\\Icons\\available.blp",
        enable = true,
    })

    ----------------------------------------------------------------
    -- DISABLE CARD
    ----------------------------------------------------------------
    CreateCard(baseFrame, 180, {
        atlas = "ExperienceIconNoLevelScaling",
        title = "Original Quest Levels",
        desc = "Quests keep their original levels.\nLow-level quests turn gray.",
        questIcon = "Interface\\AddOns\\Questie-X\\Icons\\available_gray.blp",
        enable = false,
    })
end


function Tutorial.Initialize()
    -- 1) Objective Type
    if (Questie.IsWotlk or QuestieCompat.Is335)
        and GetCVar("questPOI") ~= nil
        and not Questie.db.global.tutorialObjectiveTypeChosen
    then
        Tutorial.CreateChooseObjectiveTypeFrame()
        return
    end

    -- 2) Ascension Scaling (after objective chosen)
    if type(SetLevelScaling) == "function"
        and Questie.db.global.tutorialObjectiveTypeChosen
        and not Questie.db.profile.ascensionScalingAsked
    then
        Tutorial.CreateAscensionScalingFrame()
        return
    end

    -- 3) SoD Runes
    if Questie.IsSoD and not Questie.db.profile.tutorialShowRunesDone then
        Tutorial.ShowRunes()
    end
end
