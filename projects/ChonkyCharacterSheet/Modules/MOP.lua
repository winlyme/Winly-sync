local addonName, ns = ...
local CCS = ns.CCS
if CCS.CurrentVersion ~= CCS.MOP then
    return
end

local option = function(key) return CCS:GetOptionValue(key) end
local L = ns.L  -- grab the localization table

local module = {
    Name = "Mop Module",
    CompatibleVersions = { CCS.MOP },
    OnInitialize = function(self)
        print(self.Name .. " initialized for MoP")
    end,
}

CCS.Modules[module.Name] = module

-- MoP uses Blizzard's native stat rows, so the Retail row handlers are not
-- available here.  Map the native labels to the four useful MoP stat groups
-- and feed them into the shared equipment-highlight renderer.
local MOP_STAT_HIGHLIGHT_GROUPS = {
    {
        key = "secondary_crit",
        statKeys = { "CRIT_RATING" },
        icon = "Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\crit.png",
        aliases = {},
    },
    {
        key = "secondary_haste",
        statKeys = { "HASTE_RATING" },
        icon = "Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\haste.png",
        aliases = {},
    },
    {
        key = "secondary_mastery",
        statKeys = { "MASTERY_RATING" },
        icon = "Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\mastery.png",
        aliases = {},
    },
    {
        key = "secondary_spirit_hit",
        statKeys = { "SPIRIT", "HIT_RATING" },
        icon = "Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\versatility.png",
        aliases = {},
    },
}

-- Read the final values shown by the equipped-item tooltip.  Unlike
-- GetItemStats on MoP Classic, these lines already include the current item
-- level, reforging, gems and enchants.
local MOP_TOOLTIP_STAT_ALIASES = {
    CRIT_RATING = {
        "暴击", "爆击", "Critical Strike", ITEM_MOD_CRIT_RATING_SHORT, STAT_CRITICAL_STRIKE,
    },
    HASTE_RATING = {
        "急速", "Haste", ITEM_MOD_HASTE_RATING_SHORT, STAT_HASTE,
    },
    MASTERY_RATING = {
        "精通", "Mastery", ITEM_MOD_MASTERY_RATING_SHORT, STAT_MASTERY,
    },
    SPIRIT = {
        "精神", "Spirit", ITEM_MOD_SPIRIT_SHORT, STAT_SPIRIT, SPELL_STAT5_NAME,
    },
    HIT_RATING = {
        "命中", "Hit Rating", "Hit", ITEM_MOD_HIT_RATING_SHORT, STAT_HIT_CHANCE,
    },
}

local function NormalizeMOPTooltipStatText(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("|A.-|a", "")
               :gsub("|c%x%x%x%x%x%x%x%x", "")
               :gsub("|r", "")
               :gsub(",", "")
               :gsub("，", "")
               :gsub("＋", "+")
               :gsub("%s+", " ")
               :gsub("^%s+", "")
               :gsub("%s+$", "")
               :lower()
    return text ~= "" and text or nil
end

local function ExtractMOPTooltipStatValue(text, alias)
    alias = NormalizeMOPTooltipStatText(alias)
    if not text or not alias then return nil end

    local aliasStart, aliasEnd = text:find(alias, 1, true)
    if not aliasStart then return nil end

    -- In both "+527 Haste" and "+320 Haste / +160 Spirit", the closest
    -- signed number before the stat name belongs to that stat.
    local valueBefore, separator = text:sub(1, aliasStart - 1):match("%+%s*(%d+)([^%+]*)$")
    if valueBefore and separator and separator:match("^[%s%p]*$") then
        return tonumber(valueBefore)
    end

    -- Some locales render the name first: "Haste: +527".
    local valueAfter = text:sub(aliasEnd + 1):match("^%s*[:：]?%s*%+%s*(%d+)")
    return tonumber(valueAfter)
end

local function NewMOPTooltipStatTotals()
    return {
        CRIT_RATING = 0,
        HASTE_RATING = 0,
        MASTERY_RATING = 0,
        SPIRIT = 0,
        HIT_RATING = 0,
    }
end

local function AddMOPTooltipStatLine(totals, rawText)
    local text = NormalizeMOPTooltipStatText(rawText)
    if not text then return end

    for statKey, aliases in pairs(MOP_TOOLTIP_STAT_ALIASES) do
        for _, alias in ipairs(aliases) do
            local value = ExtractMOPTooltipStatValue(text, alias)
            if value then
                totals[statKey] = totals[statKey] + value
                break
            end
        end
    end
end

local function GetMOPStatScanTooltip()
    local tooltip = _G.CCS_MOPStatScanTooltip
    if tooltip then return tooltip end
    if type(CreateFrame) ~= "function" then return nil end

    tooltip = CreateFrame(
        "GameTooltip",
        "CCS_MOPStatScanTooltip",
        UIParent,
        "GameTooltipTemplate"
    )
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    return tooltip
end

function CCS:GetMOPTooltipStatTotalsBySlot()
    -- MoP Classic does not consistently expose C_TooltipInfo.  Scan the
    -- native equipped-item tooltip instead so upgraded and reforged values
    -- are read exactly as the game displays them.
    local tooltip = GetMOPStatScanTooltip()
    if not tooltip then return nil end

    local tooltipName = tooltip:GetName()
    local totalsBySlot = {}

    for slot = 1, 17 do
        if GetInventoryItemLink("player", slot) then
            tooltip:Hide()
            tooltip:SetOwner(UIParent, "ANCHOR_NONE")
            tooltip:ClearLines()

            local ok = pcall(tooltip.SetInventoryItem, tooltip, "player", slot)
            if ok and tooltip:NumLines() > 0 then
                local totals = NewMOPTooltipStatTotals()

                for lineIndex = 1, tooltip:NumLines() do
                    local left = _G[tooltipName .. "TextLeft" .. lineIndex]
                    local right = _G[tooltipName .. "TextRight" .. lineIndex]
                    AddMOPTooltipStatLine(totals, left and left:GetText())
                    AddMOPTooltipStatLine(totals, right and right:GetText())
                end

                totalsBySlot[slot] = totals
            end
        end
    end

    tooltip:Hide()
    return next(totalsBySlot) and totalsBySlot or nil
end

local function NormalizeMOPStatLabel(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("|A.-|a", "")
               :gsub("|c%x%x%x%x%x%x%x%x", "")
               :gsub("|r", "")
               :gsub("：", ":")
               :gsub("（", "(")
               :gsub("）", ")")
               :gsub("%s+", " ")
               :gsub("^%s+", "")
               :gsub("%s+$", "")
               :gsub(":$", "")
               :lower()
    return text ~= "" and text or nil
end

local function AddMOPStatAliases(groupIndex, ...)
    local group = MOP_STAT_HIGHLIGHT_GROUPS[groupIndex]
    for index = 1, select("#", ...) do
        local alias = NormalizeMOPStatLabel(select(index, ...))
        if alias then
            group.aliases[alias] = true
        end
    end
end

AddMOPStatAliases(1,
    ITEM_MOD_CRIT_RATING_SHORT, STAT_CRITICAL_STRIKE,
    MELEE_CRIT_CHANCE, RANGED_CRIT_CHANCE, SPELL_CRIT_CHANCE,
    COMBAT_RATING_NAME9, COMBAT_RATING_NAME10, COMBAT_RATING_NAME11,
    "暴击", "爆击", "近战暴击", "远程暴击", "法术暴击",
    "Critical Strike", "Melee Critical Strike", "Ranged Critical Strike", "Spell Critical Strike")

AddMOPStatAliases(2,
    ITEM_MOD_HASTE_RATING_SHORT, STAT_HASTE, MELEE_HASTE, RANGED_HASTE, SPELL_HASTE,
    COMBAT_RATING_NAME18, COMBAT_RATING_NAME19, COMBAT_RATING_NAME20,
    "急速", "近战急速", "远程急速", "法术急速",
    "Haste", "Melee Haste", "Ranged Haste", "Spell Haste")

AddMOPStatAliases(3,
    ITEM_MOD_MASTERY_RATING_SHORT, STAT_MASTERY, COMBAT_RATING_NAME26,
    "精通", "Mastery")

AddMOPStatAliases(4,
    ITEM_MOD_SPIRIT_SHORT, STAT_SPIRIT, SPELL_STAT5_NAME,
    ITEM_MOD_HIT_RATING_SHORT, STAT_HIT_CHANCE,
    MELEE_HIT_CHANCE, RANGED_HIT_CHANCE, SPELL_HIT_CHANCE,
    COMBAT_RATING_NAME6, COMBAT_RATING_NAME7, COMBAT_RATING_NAME8,
    "精神", "命中", "近战命中", "远程命中", "法术命中",
    "Spirit", "Hit", "Hit Chance", "Melee Hit", "Ranged Hit", "Spell Hit")

local function MOPStatHighlightsEnabled()
    return option("show_stathighlights") ~= false
end

local function MOPStatLabelMatches(label, alias)
    if label == alias then return true end
    if label:sub(1, #alias) == alias then
        local nextCharacter = label:sub(#alias + 1, #alias + 1)
        return nextCharacter == " " or nextCharacter == ":" or nextCharacter == "("
    end
    return false
end

local function GetMOPStatGroupForText(text)
    local label = NormalizeMOPStatLabel(text)
    if not label then return nil end

    for _, group in ipairs(MOP_STAT_HIGHLIGHT_GROUPS) do
        for alias in pairs(group.aliases) do
            if MOPStatLabelMatches(label, alias) then
                return group
            end
        end
    end
end

local function GetMOPStatGroupForFrame(frame)
    if not frame then return nil end

    if type(frame.GetText) == "function" then
        local group = GetMOPStatGroupForText(frame:GetText())
        if group then return group end
    end

    if type(frame.GetRegions) == "function" then
        for _, region in ipairs({ frame:GetRegions() }) do
            if type(region.GetText) == "function" then
                local group = GetMOPStatGroupForText(region:GetText())
                if group then return group end
            end
        end
    end
end

local function ClearMOPStatHighlightSelection()
    CCS.activeClickedRow = nil
    CCS.mopActiveStatGroup = nil
    CCS.mopHoveredStatRow = nil
    CCS.mopHoveredStatGroup = nil
    CCS:HideAllStatHighlights()
end

local function FrameSupportsScript(frame, scriptName)
    if not frame or type(frame.HookScript) ~= "function" then return false end
    if type(frame.HasScript) == "function" then
        return frame:HasScript(scriptName)
    end
    return true
end

local function HookMOPStatFrame(frame)
    if frame.CCSMOPStatHighlightHooked or type(frame.GetRegions) ~= "function" then return end

    local hasTextRegion = false
    for _, region in ipairs({ frame:GetRegions() }) do
        if type(region.GetText) == "function" then
            hasTextRegion = true
            break
        end
    end
    if not hasTextRegion or not FrameSupportsScript(frame, "OnEnter") then return end

    frame:HookScript("OnEnter", function(self)
        if not MOPStatHighlightsEnabled() then return end
        local group = GetMOPStatGroupForFrame(self)
        if not group then return end

        CCS.mopHoveredStatRow = self
        CCS.mopHoveredStatGroup = group
        if not CCS.activeClickedRow then
            CCS:ShowStatHighlights(group)
        end
    end)

    if FrameSupportsScript(frame, "OnLeave") then
        frame:HookScript("OnLeave", function(self)
            if CCS.mopHoveredStatRow == self then
                CCS.mopHoveredStatRow = nil
                CCS.mopHoveredStatGroup = nil
            end
            if not CCS.activeClickedRow then
                CCS:HideAllStatHighlights()
            end
        end)
    end

    if FrameSupportsScript(frame, "OnMouseDown") then
        frame:HookScript("OnMouseDown", function(self)
            if not MOPStatHighlightsEnabled() then return end
            local group = GetMOPStatGroupForFrame(self)
            if not group then return end

            if CCS.activeClickedRow == self and CCS.mopActiveStatGroup == group then
                CCS.activeClickedRow = nil
                CCS.mopActiveStatGroup = nil
                CCS:HideAllStatHighlights()
                return
            end

            CCS.activeClickedRow = self
            CCS.mopActiveStatGroup = group
            CCS:ShowStatHighlights(group)
        end)
    end

    frame.CCSMOPStatHighlightHooked = true
end

local function HookMOPStatRows()
    if not CharacterStatsPane then return end
    local visited = {}

    local function WalkFrameTree(frame)
        if not frame or visited[frame] then return end
        visited[frame] = true
        HookMOPStatFrame(frame)
        if type(frame.GetChildren) == "function" then
            for _, child in ipairs({ frame:GetChildren() }) do
                WalkFrameTree(child)
            end
        end
    end

    for categoryIndex = 1, 7 do
        WalkFrameTree(_G["CharacterStatsPaneCategory" .. categoryIndex])
    end

    local scrollBox = CharacterStatsPane.ScrollBox
    if scrollBox and type(scrollBox.GetFrames) == "function" then
        for _, frame in ipairs(scrollBox:GetFrames()) do
            WalkFrameTree(frame)
        end
    end
end

local function ScheduleMOPStatRowHooks()
    if CCS.mopStatHookPending then return end
    CCS.mopStatHookPending = true
    C_Timer.After(0, function()
        CCS.mopStatHookPending = false
        HookMOPStatRows()
    end)
    C_Timer.After(0.2, HookMOPStatRows)
end

local function GetMOPMouseFocus()
    if type(GetMouseFoci) == "function" then
        local foci = GetMouseFoci()
        return foci and foci[1]
    end
    if type(GetMouseFocus) == "function" then
        return GetMouseFocus()
    end
end

local function FindMOPStatGroupNearFrame(frame)
    local ancestor = frame
    local insideStatsPane = false
    for _ = 1, 12 do
        if not ancestor then break end
        if ancestor == CharacterStatsPane then
            insideStatsPane = true
            break
        end
        ancestor = type(ancestor.GetParent) == "function" and ancestor:GetParent() or nil
    end
    if not insideStatsPane then return nil end

    local current = frame
    for _ = 1, 8 do
        if not current then break end

        local group = GetMOPStatGroupForFrame(current)
        if group then return group, current end

        if type(current.GetChildren) == "function" then
            for _, child in ipairs({current:GetChildren()}) do
                group = GetMOPStatGroupForFrame(child)
                if group then return group, current end
            end
        end

        if current == CharacterStatsPane then break end
        current = type(current.GetParent) == "function" and current:GetParent() or nil
    end
end

local function EnableMOPStatHoverTracker()
    if not CharacterStatsPane or CharacterStatsPane.CCSMOPHoverTracker then return end

    local elapsedTotal = 0
    CharacterStatsPane:HookScript("OnUpdate", function(self, elapsed)
        if not self:IsVisible() or not MOPStatHighlightsEnabled() then return end

        elapsedTotal = elapsedTotal + elapsed
        if elapsedTotal < .05 then return end
        elapsedTotal = 0

        if CCS.activeClickedRow then return end

        local focus = GetMOPMouseFocus()
        local group, row = FindMOPStatGroupNearFrame(focus)
        if group then
            if CCS.mopHoveredStatGroup ~= group then
                CCS.mopHoveredStatGroup = group
                CCS.mopHoveredStatRow = row
                CCS:ShowStatHighlights(group)
            end
        elseif CCS.mopHoveredStatGroup then
            CCS.mopHoveredStatGroup = nil
            CCS.mopHoveredStatRow = nil
            CCS:HideAllStatHighlights()
        end
    end)

    CharacterStatsPane:HookScript("OnHide", function()
        if not CCS.activeClickedRow then
            CCS.mopHoveredStatGroup = nil
            CCS.mopHoveredStatRow = nil
            CCS:HideAllStatHighlights()
        end
    end)

    CharacterStatsPane.CCSMOPHoverTracker = true
end

local modbg = _G["CharacterModelFramebg"] or CreateFrame("Frame", "CharacterModelFramebg", CharacterModelScene)
local modtex = _G["CharacterModelFramebgtex"] or modbg:CreateTexture("CharacterModelFramebgtex", "BACKGROUND")    
local modtex2 = _G["CharacterModelFramebgtex2"] or modbg:CreateTexture("CharacterModelFramebgtex2", "ARTWORK")    

local inspectmodbg = _G["InspectModelFramebg"] or CreateFrame("Frame", "InspectModelFramebg")
local inspectmodtex = _G["InspectModelFramebgtex"] or inspectmodbg:CreateTexture("InspectModelFramebgtex", "BACKGROUND")    
local inspectmodtex2 = _G["InspectModelFramebgtex2"] or inspectmodbg:CreateTexture("InspectModelFramebgtex2", "ARTWORK")    

local modelbtn = _G["CCS_clk_Btn"] or CreateFrame("Button", "CCS_clk_Btn", PaperDollFrame, "UIPanelButtonTemplate")
local modelbtnfont1 = _G["CCS_clk_Btnfs1"] or modelbtn:CreateFontString("CCS_clk_Btnfs1")

function module:OnInitialize()
 --print (module.Name, " Test")
end

local function MoveModelLeft() 
    local Height = 359+(7*option("vpad"))  -- Hard code it for now
    
    if CharacterModelScene:GetHeight() == Height then
    return end
    
    CharacterModelScene:ClearAllPoints();
    CharacterModelScene:SetHeight(Height)
    CharacterModelScene:SetWidth(Height/CCS.ModelAspect)
    CharacterModelScene:SetPoint("CENTER", CharacterFrameInset.Bg, "CENTER", 0, 0);
    CharacterModelScene:SetFrameLevel(2)
    
    CharacterModelFrameBackgroundTopLeft:Hide();
    CharacterModelFrameBackgroundBotLeft:Hide();
    CharacterModelFrameBackgroundTopRight:Hide();
    CharacterModelFrameBackgroundBotRight:Hide();
    CharacterModelFrameBackgroundOverlay:ClearAllPoints()
    CharacterModelFrameBackgroundOverlay:SetPoint("TOPLEFT", CharacterModelFrameBackgroundTopLeft, "TOPLEFT", 0, 0)
    CharacterModelFrameBackgroundOverlay:SetPoint("BOTTOMRIGHT", CharacterModelFrameBackgroundBotRight, "BOTTOMRIGHT", 0, 70)
    CharacterModelFrameBackgroundOverlay:Hide()
    
    modbg:ClearAllPoints()
    modbg:SetPoint("TOPLEFT", CharacterHeadSlot, "TOPLEFT", 0, 0)
    modbg:SetPoint("RIGHT", CharacterHandsSlot, "RIGHT", 0, 0)    
    modbg:SetPoint("BOTTOM", CharacterMainHandSlot, "BOTTOM", 0, 0)            
    
end

local function MoveModelRight() 
    CharacterModelScene:ClearAllPoints();
    CharacterModelScene:SetHeight(CharacterFrame:GetHeight());
    CharacterModelScene:SetWidth(CharacterFrame:GetHeight()/CCS.ModelAspect);
    CharacterModelScene:SetPoint("LEFT", CharacterFrameBg, "RIGHT", 0, 0);
    CharacterModelScene:Show();
    
    _G["CharacterModelFramebg"]:ClearAllPoints()
    _G["CharacterModelFramebg"]:SetAllPoints(CharacterModelScene)    
end

local function Clicky(endstate)
   
    if CharacterModelScene:GetHeight() > 600 then -- This is to move model under the character equipment
        MoveModelLeft()
    else -- This is to move the model to the right of the character frame.
        MoveModelRight()
    end

    CCS.ChangeModelBg(false)
    PlaySound(SOUNDKIT.GS_LOGIN_CHANGE_REALM_OK);
end

local function ccs_cshow()
    MoveModelLeft()
    CCS.ChangeModelBg(false)
    CharacterModelScene.ControlFrame:Hide()
end

local function UpdateMOPItemLevelSummary()
    local btn = _G["CSPilvl"]
    local btnfont1 = _G["CSPilvlfs1"]
    if not btn or not btnfont1 then return end

    CCS.MOPItemLevelUpdateToken = (CCS.MOPItemLevelUpdateToken or 0) + 1
    local updateToken = CCS.MOPItemLevelUpdateToken

    -- The first GetAverageItemLevel() result includes usable items in the
    -- bags. Prime those items before asking the client for that value.
    local getNumSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    local getItemLink = C_Container and C_Container.GetContainerItemLink or GetContainerItemLink
    if getNumSlots and getItemLink then
        for bag = 0, (NUM_BAG_SLOTS or 4) do
            for slot = 1, (getNumSlots(bag) or 0) do
                local link = getItemLink(bag, slot)
                if link then
                    local itemID, _, _, equipLoc
                    if GetItemInfoInstant then
                        itemID, _, _, equipLoc = GetItemInfoInstant(link)
                    end
                    if equipLoc and equipLoc ~= "" then
                        GetItemInfo(link)
                    end
                    if equipLoc and equipLoc ~= ""
                        and C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
                        if itemID then
                            C_Item.RequestLoadItemDataByID(itemID)
                        end
                    end
                end
            end
        end
    end

    CCS.PreloadEquippedItemInfo("player")
    CCS.WaitForItemInfoReady("player", function()
        if updateToken ~= CCS.MOPItemLevelUpdateToken then return end

        -- Read these values only after the newly equipped item's data is
        -- available. The old code captured them before the asynchronous wait,
        -- leaving the summary one equipment change behind.
        local overallAverage, equippedAverage = GetAverageItemLevel()
        overallAverage = tonumber(overallAverage) or 0
        equippedAverage = tonumber(equippedAverage) or overallAverage

        local color = CCS:GetAverageEquippedRarityHex("player") or "ffffff"
        btnfont1:SetText(format(
            "|cFF%s%.2f / %.2f|r",
            color,
            equippedAverage,
            overallAverage
        ))
    end)
end

local function InitStats()
    if not CharacterStatsPane then return end

    EnableMOPStatHoverTracker()

    CharacterStatsPane.ScrollBox:ClearAllPoints()
    CharacterStatsPane.ScrollBox:SetPoint("TOPLEFT", CharacterStatsPane, "TOPLEFT", 14, -25)
    CharacterStatsPane.ScrollBox:SetPoint("BOTTOMRIGHT", CharacterStatsPane, "BOTTOMRIGHT", -4, 0)


    for i = 1, 7 do
        local category = _G["CharacterStatsPaneCategory"..i]
        if category then
            category:SetPoint("RIGHT", CharacterStatsPane.ScrollBox, "RIGHT", -4, 0)
            for _, suffix in ipairs({"BgBottom","BgTop","BgMiddle","BgMinimized"}) do
                local bg = _G["CharacterStatsPaneCategory"..i..suffix]
                if bg then
                    bg:SetPoint("RIGHT", category, "RIGHT", 0, 0)
                end
            end
        end
    end

        -- Ilvl Frame
        
        local btn = _G["CSPilvl"] or CreateFrame("Button", "CSPilvl", CharacterStatsPane)
        local btnfont1 = _G["CSPilvlfs1"] or btn:CreateFontString("CSPilvlfs1")
        --local btnfont2 = _G["CSPilvlfs2"] or btn:CreateFontString("CSPilvlfs2")
        local btntex = _G["CSPilvltex"] or btn:CreateTexture("CSPilvltex", "BACKGROUND", nil, 1)
        btn:SetParent(CharacterStatsPane)
        btn:ClearAllPoints()
        btn:SetSize(230, 23*(option("fontsize_cilvl") or 20) /20)
        btn:SetPoint("TOP", PaperDollSidebarTabs, "BOTTOM", -30, -7)
        btn:SetFrameStrata("HIGH")
        btn.throttle = 0;
        btn:Show()       
        
        btntex:ClearAllPoints()
        btntex:SetAllPoints()
        btntex:SetTexture("Interface\\Masks\\SquareMask.BLP")
        btntex:SetGradient("Vertical", CreateColor(0, 0, 0, .2), CreateColor(.1, .1, .1, .4)) -- Dark Gray
        btnfont1:SetPoint("CENTER", btn, "CENTER", 0 ,0)
        btnfont1:SetFont(option("fontname_cilvl") or CCS.fontname, (option("fontsize_cilvl") or 20))

        UpdateMOPItemLevelSummary()

        local scrollBox = CharacterStatsPane.ScrollBox
        if scrollBox and type(scrollBox.RegisterCallback) == "function"
            and BaseScrollBoxEvents and BaseScrollBoxEvents.OnLayout
            and not scrollBox.CCSMOPStatHighlightCallback then
            scrollBox:RegisterCallback(BaseScrollBoxEvents.OnLayout, ScheduleMOPStatRowHooks)
            scrollBox.CCSMOPStatHighlightCallback = true
        end

        if CharacterFrame and not CharacterFrame.CCSMOPStatHighlightHideHook then
            CharacterFrame:HookScript("OnHide", ClearMOPStatHighlightSelection)
            CharacterFrame.CCSMOPStatHighlightHideHook = true
        end

        if MOPStatHighlightsEnabled() then
            ScheduleMOPStatRowHooks()
        else
            ClearMOPStatHighlightSelection()
        end
    
    
end

local function hookfix() 
    CharacterLevelText:ClearAllPoints()
    CharacterLevelText:SetPoint("TOP", CharacterFrameTitleText, "BOTTOM", 0, 0)
    CharacterLevelText:SetFont(option("fontname_levelclass") or CCS.fontname, (option("fontsize_levelclass") or 12) , CCS.textoutline)
    
    CharacterFrameExpandButton:ClearAllPoints()
    CharacterFrameExpandButton:SetPoint("BOTTOMRIGHT", CharacterFrameInset, "BOTTOMRIGHT",270,4)
    
    PetLevelText:ClearAllPoints()
    PetLevelText:SetPoint("TOP", CharacterFrameTitleText, "BOTTOM", 0, -4)
    PetLevelText:SetFont(option("fontname_levelclass") or CCS.fontname, (option("fontsize_levelclass") or 12) , CCS.textoutline)
    PetModelFrame:SetPoint("BOTTOMRIGHT", CharacterFrameInset, "BOTTOMRIGHT", 270, 4)
    PetPaperDollPetModelBg:ClearAllPoints()
    PetPaperDollPetModelBg:SetPoint("TOPLEFT", PetModelFrame, "TOPLEFT", 4, -4)
    PetPaperDollPetModelBg:SetPoint("BOTTOMRIGHT", PetModelFrame, "BOTTOMRIGHT", 350, -250)
    InitStats()
    
end

local function StyleMOPCharacterTab(tab)
    do return end -- Use Blizzard's native MoP tab template.
    if not tab then return end

    local tabName = tab.GetName and tab:GetName()
    local text = tab.Text or (tabName and _G[tabName.."Text"])

    local originalTextureNames = {
        "Left", "Middle", "Right",
        "LeftActive", "MiddleActive", "RightActive",
        "LeftDisabled", "MiddleDisabled", "RightDisabled",
        "LeftHighlight", "MiddleHighlight", "RightHighlight",
    }
    for _, textureName in ipairs(originalTextureNames) do
        local texture = tab[textureName] or (tabName and _G[tabName..textureName])
        if texture and texture.SetAlpha and texture.Hide
            and texture ~= tab.CCSBackground and texture ~= tab.CCSHighlight then
            texture:SetAlpha(0)
            texture:Hide()
        end
    end

    if not tab.CCSMOPArtHidden then
        -- MoP's selected tab is the button's disabled state and uses another
        -- set of textures. Hide every original texture instead of trying to
        -- guess which state Blizzard currently has visible.
        for _, region in ipairs({tab:GetRegions()}) do
            if region.IsObjectType and region:IsObjectType("Texture") then
                region:SetAlpha(0)
            end
        end

        tab.CCSBackground = tab:CreateTexture(nil, "ARTWORK", nil, 7)
        tab.CCSBackground:SetAllPoints(tab)
        tab.CCSBackground:SetTexture("Interface\\Masks\\SquareMask.BLP")

        tab.CCSHighlight = tab:CreateTexture(nil, "HIGHLIGHT", nil, 1)
        tab.CCSHighlight:SetAllPoints(tab)
        tab.CCSHighlight:SetColorTexture(.28, .28, .28, .55)
        tab:SetHighlightTexture(tab.CCSHighlight, "ADD")

        tab.CCSMOPArtHidden = true
    end

    tab.CCSBackground:SetDrawLayer("ARTWORK", 7)

    local selected = tab.IsEnabled and not tab:IsEnabled()
    if tab.CCSBackground then
        if selected then
            tab.CCSBackground:SetGradient("Vertical",
                CreateColor(.25, .25, .25, 1), CreateColor(.04, .04, .04, 1))
        else
            tab.CCSBackground:SetGradient("Vertical",
                CreateColor(.06, .06, .06, .96), CreateColor(0, 0, 0, .96))
        end
    end

    if text then
        text:SetAlpha(1)
        text:ClearAllPoints()
        text:SetPoint("CENTER", tab, "CENTER", 0, 0)
        if text.SetDrawLayer then
            text:SetDrawLayer("OVERLAY", 7)
        end
        text:SetTextColor(1, 1, 1, 1)
    end
end

local function StyleMOPCharacterTabs()
    do return end -- Do not resize or re-anchor legacy character tabs.
    local tab1 = _G.CharacterFrameTab1
    local tab2 = _G.CharacterFrameTab2
    local tab3 = _G.CharacterFrameTab3

    StyleMOPCharacterTab(tab1)
    StyleMOPCharacterTab(tab2)
    StyleMOPCharacterTab(tab3)

    for _, tab in ipairs({tab1, tab2, tab3}) do
        if tab then
            tab:SetWidth(80)
            tab:SetHeight(32)
            if not tab.CCSMOPClickHooked then
                tab:HookScript("OnClick", function()
                    C_Timer.After(0, StyleMOPCharacterTabs)
                    C_Timer.After(.05, StyleMOPCharacterTabs)
                end)
                tab.CCSMOPClickHooked = true
            end
        end
    end

    if tab1 and CharacterFrame then
        tab1:ClearAllPoints()
        tab1:SetPoint("TOPLEFT", CharacterFrame, "BOTTOMLEFT", 11, 2)
    end
    if tab2 and tab1 then
        tab2:ClearAllPoints()
        tab2:SetPoint("TOPLEFT", tab1, "TOPRIGHT", 3, 0)
    end
    if tab3 and tab2 then
        tab3:ClearAllPoints()
        tab3:SetPoint("TOPLEFT", tab2, "TOPRIGHT", 3, 0)
    end
end

local function GetMOPCurrencyScrollFrame()
    if TokenFrame and TokenFrame.ScrollBox then
        return TokenFrame.ScrollBox
    end
    return _G.TokenFrameContainer or (TokenFrame and TokenFrame.Container)
end

local function GetMOPCurrencyScrollTarget(scrollFrame)
    if not scrollFrame then return nil end
    return scrollFrame.ScrollTarget
        or scrollFrame.scrollChild
        or scrollFrame.ScrollChild
        or _G.TokenFrameContainerScrollChild
end

local function InitializeFrameUpdates()
    if ReputationFrame and CharacterFrameBg then
        ReputationFrame:ClearAllPoints()
        ReputationFrame:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 0, 0)
        ReputationFrame:SetPoint("BOTTOMRIGHT", CharacterFrameBg, "BOTTOMRIGHT", 0, 7)
    end

    if ReputationListScrollFrame and CharacterFrameInset and CharacterFrameBg then
        ReputationListScrollFrame:ClearAllPoints()
        ReputationListScrollFrame:SetPoint("TOPLEFT", CharacterFrameInset, "TOPLEFT", 12, -4)
        ReputationListScrollFrame:SetPoint("BOTTOMRIGHT", CharacterFrameBg, "BOTTOMRIGHT", -40, 7)
    end

    local currencyScrollFrame = GetMOPCurrencyScrollFrame()
    if TokenFrame and currencyScrollFrame and CharacterFrameBg and not InCombatLockdown() then
        TokenFrame:ClearAllPoints()
        TokenFrame:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 0, 0)
        TokenFrame:SetPoint("BOTTOMRIGHT", CharacterFrameBg, "BOTTOMRIGHT", 0, 0)
        currencyScrollFrame:ClearAllPoints()
        currencyScrollFrame:SetPoint("TOPLEFT", CharacterFrameInset, "TOPLEFT", 12, -4)
        currencyScrollFrame:SetPoint("BOTTOMRIGHT", CharacterFrameBg, "BOTTOMRIGHT", -30, 26)
    end

    StyleMOPCharacterTabs()
end

local function ScheduleMOPFrameUpdates()
    C_Timer.After(0, InitializeFrameUpdates)
    C_Timer.After(.05, InitializeFrameUpdates)
end


local function MOPupdateLocationInfo(unit, slotIndex, framename)
    if slotIndex == 18 then return end -- skip ranged slot

    local isPlayer = (unit == "player")
    local isInspect = not isPlayer

    if isInspect and not option("show_inspect") then return end

    local suffix = isPlayer and "" or "_inspect"
    local slotFrameName = CCS.getSlotFrameName(slotIndex, framename)
    if not slotFrameName then return end

    -- Determine display direction
	local displaytoleft = CCS.displaytowardleft(slotIndex)
    
	if framename == "CompCharacter" then
		displaytoleft = true
	elseif framename == "CompInspect" then
		displaytoleft = false
	end
	
    local SubElementSetPoint = "LEFT"
    local SubElementSetPoint2 = "RIGHT"
    local neg = 1
    
    if displaytoleft then 
        SubElementSetPoint = "RIGHT" 
        SubElementSetPoint2 = "LEFT" 
        neg = -1
    end
	
    -- Get item link and info
    local link = GetInventoryItemLink(unit, slotIndex)
    local itemLoc = isPlayer and ItemLocation:CreateFromEquipmentSlot(slotIndex) or nil

    -- Create or reuse UI elements
    _G[slotFrameName]:SetFrameStrata("HIGH")
    local nameTxt = _G[slotFrameName.."namefs"] or _G[slotFrameName]:CreateFontString(slotFrameName.."namefs")
    local ilvlTxt = _G[slotFrameName.."ilvlfs"] or _G[slotFrameName]:CreateFontString(slotFrameName.."ilvlfs")
    local enchantTxt = _G[slotFrameName.."enchantfs"] or _G[slotFrameName]:CreateFontString(slotFrameName.."enchantfs")
    local bgfader = _G[slotFrameName.."bgfader"] or CreateFrame("Frame", slotFrameName.."bgfader", _G[slotFrameName])
    local bgfadertex = _G[bgfader:GetName().."tex"] or bgfader:CreateTexture(bgfader:GetName().."tex", "BACKGROUND", nil, 1)

    local ccsStat, ccsStaticon, ccsStattext
    if isPlayer and framename == "Character" then
        ccsStat = _G[slotFrameName].ccsStat or CreateFrame("Frame", nil, _G[slotFrameName], BackdropTemplateMixin and "BackdropTemplate")
        ccsStaticon = ccsStat.icon or ccsStat:CreateTexture(nil, "ARTWORK", nil, 1)
        ccsStattext = ccsStat.text or ccsStat:CreateFontString()

        _G[slotFrameName].ccsStat = ccsStat
        ccsStat.icon = ccsStaticon
        ccsStat.text = ccsStattext

        if type(ccsStat.SetBackdrop) == "function" then
            ccsStat:SetBackdrop({
                bgFile = "Interface\\Masks\\SquareMask.BLP",
                edgeFile = "Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\UI-Tooltip-SquareBorder.blp",
                edgeSize = 16,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            })
            ccsStat:SetBackdropColor(0, 0, 0, .85)
            ccsStat:SetBackdropBorderColor(.7, .7, .7, .9)
        end
    end

    -- Optional: durability for player only
    local durabilityTxt, durbar, durbartex
    if isPlayer then
        durabilityTxt = _G[slotFrameName.."durabilityfs"] or _G[slotFrameName]:CreateFontString(slotFrameName.."durabilityfs")
        durbar = _G[slotFrameName.."durbar"] or CreateFrame("Frame", slotFrameName.."durbar", _G[slotFrameName])
        durbartex = _G[durbar:GetName().."tex"] or durbar:CreateTexture(durbar:GetName().."tex", "BACKGROUND", nil, 2)
        durbar:SetSize(4, 34)
        durbar:SetPoint("BOTTOM"..SubElementSetPoint, slotFrameName, "BOTTOM"..SubElementSetPoint2, 1 * neg, 0)
        durbar:SetFrameLevel(2)
        durbartex:SetAllPoints()
        durbartex:SetTexture("Interface\\Masks\\SquareMask.BLP")        
    end

    -- Gem frames
    local gemIconframe1 = _G[slotFrameName.."gemtex1"] or CreateFrame("Button", slotFrameName.."gemtex1", _G[slotFrameName], "UIPanelButtonTemplate")
    local gemIconframe2 = _G[slotFrameName.."gemtex2"] or CreateFrame("Button", slotFrameName.."gemtex2", _G[slotFrameName], "UIPanelButtonTemplate")
    local gemIconframe3 = _G[slotFrameName.."gemtex3"] or CreateFrame("Button", slotFrameName.."gemtex3", _G[slotFrameName], "UIPanelButtonTemplate")

    local socketTextureByKind = {
        BLUE = 136256,
        META = 136257,
        RED = 136258,
        YELLOW = 136259,
        PRISMATIC = 458977,
        COGWHEEL = 407324,
    }

    local socketKindByTexture = {
        [136256] = "BLUE",
        [136257] = "META",
        [136258] = "RED",
        [136259] = "YELLOW",
        [458977] = "PRISMATIC",
        [407324] = "COGWHEEL",
    }

    local function getSocketKindFromTexture(socketTexture)
        local fileID = tonumber(socketTexture)
        if fileID and socketKindByTexture[fileID] then
            return socketKindByTexture[fileID]
        end

        if type(socketTexture) == "string" then
            local path = socketTexture:lower()
            if path:find("red", 1, true) then return "RED" end
            if path:find("yellow", 1, true) then return "YELLOW" end
            if path:find("blue", 1, true) then return "BLUE" end
            if path:find("meta", 1, true) then return "META" end
            if path:find("prismatic", 1, true) then return "PRISMATIC" end
            if path:find("cogwheel", 1, true) then return "COGWHEEL" end
        end
    end

    local function getSocketKindFromText(text)
        if type(text) ~= "string" then return nil end
        local labels = {
            { EMPTY_SOCKET_RED, "RED" },
            { EMPTY_SOCKET_YELLOW, "YELLOW" },
            { EMPTY_SOCKET_BLUE, "BLUE" },
            { EMPTY_SOCKET_META, "META" },
            { EMPTY_SOCKET_PRISMATIC, "PRISMATIC" },
            { EMPTY_SOCKET_COGWHEEL, "COGWHEEL" },
        }
        for _, socketData in ipairs(labels) do
            local label, kind = socketData[1], socketData[2]
            if type(label) == "string" and text:find(label, 1, true) then
                return kind
            end
        end
    end

    local function getSocketRing(gemFrame)
        local ring = gemFrame.ccsSocketRing
        if not ring then
            -- Draw a complete socket icon above the button and put the gem
            -- inside it.  The native empty-socket texture supplies both the
            -- socket colour and the four inward-facing corner clasps.
            ring = CreateFrame("Frame", nil, gemFrame)
            ring:SetPoint("CENTER", gemFrame, "CENTER", 0, 0)
            ring:SetSize(22, 22)
            ring:SetFrameLevel(gemFrame:GetFrameLevel() + 20)
            ring:EnableMouse(false)

            ring.border = ring:CreateTexture(nil, "ARTWORK", nil, 1)
            ring.border:SetAllPoints()

            ring.gem = ring:CreateTexture(nil, "OVERLAY", nil, 7)
            ring.gem:SetPoint("CENTER", ring, "CENTER", 0, 0)
            ring.gem:SetSize(13, 13)
            gemFrame.ccsSocketRing = ring
        end
        return ring
    end

    local function showSocketRing(ring, socketTexture, socketKind, gemTexture)
        socketKind = socketKind or getSocketKindFromTexture(socketTexture)
        local nativeSocketTexture = socketTexture
            or socketTextureByKind[socketKind]
            or socketTextureByKind.PRISMATIC

        ring.border:SetTexture(nativeSocketTexture)
        ring.border:SetVertexColor(1, 1, 1, 1)
        ring.gem:SetTexture(gemTexture)
        ring:Show()
    end

    local gemSocketRing1 = getSocketRing(gemIconframe1)
    local gemSocketRing2 = getSocketRing(gemIconframe2)
    local gemSocketRing3 = getSocketRing(gemIconframe3)

    -- Positioning and font setup
    nameTxt:SetPoint(SubElementSetPoint, _G[slotFrameName], SubElementSetPoint2, 10 * neg, 13)
    nameTxt:SetFont(option("fontname_iname"..suffix) or CCS.fontname, option("fontsize_iname"..suffix) or 12, "OUTLINE")

    ilvlTxt:SetPoint(SubElementSetPoint, _G[slotFrameName], SubElementSetPoint2, 10 * neg, 0)
    ilvlTxt:SetFont(option("fontname_iilvl"..suffix) or CCS.fontname, option("fontsize_iilvl"..suffix) or 10, "OUTLINE")
    ilvlTxt:SetTextColor(
        option("fontcolor_iilvl"..suffix)[1] or 1,
        option("fontcolor_iilvl"..suffix)[2] or 1,
        option("fontcolor_iilvl"..suffix)[3] or 1,
        option("fontcolor_iilvl"..suffix)[4] or 1
    )

    enchantTxt:SetPoint(SubElementSetPoint, _G[slotFrameName], SubElementSetPoint2, 10 * neg, -13)
    enchantTxt:SetFont(option("fontname_enchant"..suffix) or CCS.fontname, option("fontsize_enchant"..suffix) or 10, "OUTLINE")
    enchantTxt:SetTextColor(
        option("fontcolor_enchant"..suffix)[1] or 1,
        option("fontcolor_enchant"..suffix)[2] or 1,
        option("fontcolor_enchant"..suffix)[3] or 1,
        option("fontcolor_enchant"..suffix)[4] or 1
    )

    -- Optional: durability positioning
    if isPlayer and durabilityTxt then
        durabilityTxt:SetPoint("CENTER", _G[slotFrameName], "CENTER", 0, 0)
        durabilityTxt:SetFont(option("fontname_durability") or CCS.fontname, option("fontsize_durability") or 10, CCS.textoutline)
    end

    bgfader:SetSize(240, 39) -- fader size (scales with the character frame)
    bgfader:SetPoint(SubElementSetPoint, slotFrameName, SubElementSetPoint2, -38 * neg, 0)        
    bgfader:SetFrameLevel(1)
    bgfadertex:SetAllPoints()
    bgfadertex:SetTexture("Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\Square_AlphaGradient.tga") -- last remnant from WeakAuras.

    if ccsStat then
        ccsStat:ClearAllPoints()
        ccsStat:SetSize(100, 39)
        ccsStat:SetPoint(SubElementSetPoint, slotFrameName, SubElementSetPoint2, 3 * neg, 0)
        ccsStat:SetFrameLevel(_G[slotFrameName]:GetFrameLevel() + 20)

        ccsStaticon:ClearAllPoints()
        ccsStaticon:SetSize(24, 24)
        ccsStaticon:SetPoint(SubElementSetPoint, ccsStat, SubElementSetPoint, 7 * neg, 0)

        ccsStattext:ClearAllPoints()
        ccsStattext:SetPoint(SubElementSetPoint, ccsStaticon, SubElementSetPoint2, 3 * neg, 0)
        ccsStattext:SetFont(CCS.fontname, 12, CCS.textoutline)
        ccsStattext:SetTextColor(1, 1, 1, 1)
    end
    
    gemIconframe1:SetSize(15, 15)
    gemIconframe1:SetPoint("TOP"..SubElementSetPoint2, slotFrameName, "TOP"..SubElementSetPoint, -8 * neg, 6)
    gemIconframe1:SetFrameStrata("HIGH")
    
    gemIconframe2:SetSize(15, 15)
    gemIconframe2:SetPoint(SubElementSetPoint2, slotFrameName, SubElementSetPoint, -8 * neg, 0)
    gemIconframe2:SetFrameStrata("HIGH")
    
    gemIconframe3:SetSize(15, 15)
    gemIconframe3:SetPoint("BOTTOM"..SubElementSetPoint2, slotFrameName, "BOTTOM"..SubElementSetPoint, -8 * neg, -6)
    gemIconframe3:SetFrameStrata("HIGH")


    -- Hide all elements by default
    nameTxt:Hide()
    ilvlTxt:Hide()
    enchantTxt:Hide()
    if durabilityTxt then durabilityTxt:Hide() end
    gemIconframe1:Hide()
    gemIconframe2:Hide()
    gemIconframe3:Hide()
    gemSocketRing1:Hide()
    gemSocketRing2:Hide()
    gemSocketRing3:Hide()
    bgfader:Hide()
    if durbar then durbar:Hide() end
    if ccsStat then ccsStat:Hide() end

    -- Bail early if no item
    if link == nil then
        nameTxt:SetText("")
        ilvlTxt:SetText("")
        enchantTxt:SetText("")
        if durabilityTxt then durabilityTxt:SetText("") end
        return
	else 
        local durCur, durMax = GetInventoryItemDurability(slotIndex)
        local _, _, _, _, _, _, Gem1, Gem2, Gem3, _, _, _, _, _, _ = string.find(link, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?")
        local itemName, _, itemRarity, itemiLevel, _, itemType, _, _, _, _, _, _, _, _, expacID, setID, _ = C_Item.GetItemInfo(link)
        local itemInfoLevel = itemiLevel
        local detailedItemLevel
        if C_Item and type(C_Item.GetDetailedItemLevelInfo) == "function" then
            detailedItemLevel = C_Item.GetDetailedItemLevelInfo(link)
        end
        local Color = "ffffffff"
        itemiLevel = nil
        local itemID = tonumber(link:match("item:(%d+)"))
        if not C_Item.IsItemDataCachedByID(itemID) then
            C_Item.RequestLoadItemDataByID(itemID)
        end

        if itemRarity and itemRarity >= 1 and itemRarity <= 7 then
            Color = select(4, C_Item.GetItemQualityColor(itemRarity))
        end
        
        local ItemTip = _G["CCS_Scanningtooltip"] or CreateFrame('GameTooltip', 'CCS_Scanningtooltip', WorldFrame, 'GameTooltipTemplate')
        local EmptySocket = false
        local SocketCount = 0;
        local Enchant = ""
        local EngineeringEnchant = ""
        local permanentEnchantID = tonumber(link:match("item:%d+:(%d+)")) or 0
        local hasPermanentEnchant = permanentEnchantID > 0
        local ItemUpgradeLevel = ""
        
        ItemTip:SetOwner(WorldFrame, 'ANCHOR_NONE');
        ItemTip:ClearLines()
        _G["CCS_ScanningtooltipTexture1"]:SetTexture(nil) -- Gem1
        _G["CCS_ScanningtooltipTexture2"]:SetTexture(nil) -- Gem2
        _G["CCS_ScanningtooltipTexture3"]:SetTexture(nil) -- Gem3
        ItemTip:SetHyperlink(link) 

-------------------
-- Enchant/Upgrade line tooltip detection
-------------------
-- Create isolated tooltip
if not CCS_ScanTooltip then
    CCS_ScanTooltip = CreateFrame("GameTooltip", "CCS_ScanTooltip", nil, "GameTooltipTemplate")
    CCS_ScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
end

-- Normalize helper
local function norm(t)
    return t and t:gsub("\194\160"," ")
                 :gsub("\226\128\139"," ")
                 :gsub("\239\187\191"," ")
                 :gsub("%s+"," ")
                 :gsub("^%s+","")
                 :gsub("%s+$","") or nil
end

-- Escape helper for safe Lua patterns
local function escapePattern(s)
    return s:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
end

-- Build pattern from format string
local function buildFormatPattern(fmt)
    local pat = escapePattern(fmt)
    pat = pat:gsub("%%d", "%s*%%d+%s*")
    pat = pat:gsub("%%s", "%%S+")
    pat = pat:gsub("%s+", "%%s+")
    return pat
end

-- Localized patterns (always needed)
local CREATED_BY = _G.ITEM_CREATED_BY or "<Made by %s>"
local CREATED_BY_PATTERN = buildFormatPattern(CREATED_BY)

local SOULBOUND = _G.ITEM_SOULBOUND or "Soulbound"

local UPGRADE_FORMAT = _G.ITEM_UPGRADE_FRAME_CURRENT_UPGRADE_FORMAT or "Upgrade Level: %d / %d"
local UPGRADE_PATTERN = buildFormatPattern(UPGRADE_FORMAT)
local UPGRADE_FALLBACK_PATTERN = "^Upgrade%s+Level%s*:%s*%d+%s*/%s*%d+$"

local DURABILITY_FORMAT = _G.DURABILITY_TEMPLATE or "Durability %d / %d"
local DURABILITY_PATTERN = buildFormatPattern(DURABILITY_FORMAT)
local DURABILITY_FALLBACK_PATTERN = "^Durability%s+%d+%s*/%s*%d+$"

local REQUIRES_LEVEL_FORMAT = _G.ITEM_MIN_LEVEL or "Requires Level %d"
local REQUIRES_LEVEL_PATTERN = buildFormatPattern(REQUIRES_LEVEL_FORMAT)

local ITEM_LEVEL_FORMAT = _G.ITEM_LEVEL or "Item Level %d"
local ITEM_LEVEL_PATTERN = buildFormatPattern(ITEM_LEVEL_FORMAT)
local ITEM_LEVEL_FALLBACK_PATTERN = "^Item%s+Level%s*%d+$"

local TRANSMOG_HEADER = _G.TRANSMOGRIFIED_HEADER or "Transmogrified to:"
--local TRANSMOG_FORMAT = _G.TRANSMOGRIFIED or "Transmogrified to:\n%s"

-- Build patterns
local TRANSMOG_HEADER_PATTERN = escapePattern(TRANSMOG_HEADER)
--local TRANSMOG_FORMAT_PATTERN = buildFormatPattern(TRANSMOG_FORMAT)

-- Tooltip comparison works independently of the client language.  The old
-- English-only guard prevented enchants from being detected on zhCN/zhTW.
local locale = GetLocale()
local enchantDetectionEnabled = true
local REFORGE_FORMAT = _G.ITEM_REFORGE_DESCRIPTION or "Reforged from %s"
local REFORGE_PATTERN = buildFormatPattern(REFORGE_FORMAT)
local REFORGED_LINE = "Reforged"

-- Socket strings vary; a simple contains check is safest
local function isSocketLine(t)
    return t and (
        t:find("Socket", 1, true) or
        t:find("Prismatic Socket", 1, true) or
        t:find("Meta Socket", 1, true) or
        t:find("插槽", 1, true) or
        t:find("插孔", 1, true) or
        t:find("宝石", 1, true) or
        t:find("寶石", 1, true) or
        t:find("Gem", 1, true) or
        t:find("Sockel", 1, true) or
        t:find("Châsse", 1, true) or
        t:find("Ranura", 1, true) or
        t:find("гнезд", 1, true) or
        t:find("보석", 1, true)
    )
end

-- Reforged-from stat tracking
local reforgedFromStats = {}

-- Robust stat name extractor
local function extractStatName(t)
    if not t then return nil end

    -- The old pattern only accepted Latin letters, so Chinese stat lines
    -- could be mistaken for an enchantment during tooltip comparison.
    local statName = t:match("^%+?%d[%d%,%.]*%s+(.+)$")
    if statName then
        return statName:gsub("%s+$", "")
    end

    return t:match("^(.+)%s+%+?%d[%d%,%.]*$")
end

local function isReforgeOrArmorLine(t)
    return t and (
        t:find("重铸", 1, true) or
        t:find("重鑄", 1, true) or
        t:find("Reforg", 1, true) or
        t:find("护甲", 1, true) or
        t:find("護甲", 1, true) or
        t:find("Armor", 1, true)
    )
end

local function isReforgedSourceLine(t)
    if not enchantDetectionEnabled then return false end
    local statName = extractStatName(t)
    return statName and reforgedFromStats[statName] or false
end

-- Parse upgrade line into "track current/max"
local function parseUpgradeLine(t)
    if not t then return nil end

    -- A durability line has the same numeric shape as an upgrade line
    -- (for example, "Durability 100/100"), so it must be excluded first.
    if (DURABILITY_PATTERN and t:match(DURABILITY_PATTERN))
        or (DURABILITY_FALLBACK_PATTERN and t:match(DURABILITY_FALLBACK_PATTERN))
        or t:find("耐久度", 1, true)
        or t:find("耐久", 1, true)
        or t:find("Durability", 1, true) then
        return nil
    end

    local track, current, max = t:match("^(.-)%s*:%s*(%d+)%s*/%s*(%d+)%s*$")
    if not track then
        track, current, max = t:match("^(.-)%s*：%s*(%d+)%s*/%s*(%d+)%s*$")
    end
    if not track then
        track, current, max = t:match("^(.-)%s+(%d+)%s*/%s*(%d+)%s*$")
    end
    if not track then
        current, max = t:match("^(%d+)%s*/%s*(%d+)%s*$")
        track = ""
    end
    if track and current and max then
        track = track:gsub("^%s+", ""):gsub("%s+$", "")
        if track == "" then
            return current .. "/" .. max
        end
        return track .. " " .. current .. "/" .. max
    end
    return nil
end

local function parseFormattedNumber(text, format)
    if not text or not format then return nil end
    local pattern = escapePattern(format)
    pattern = pattern:gsub("%%d", "(%%d+)")
    pattern = pattern:gsub("%%s", ".-")
    return tonumber(text:match("^" .. pattern .. "$"))
end

local function parseItemLevelLine(text)
    local itemLevel = parseFormattedNumber(text, ITEM_LEVEL_FORMAT)
    if itemLevel then
        return itemLevel
    end

    -- Keep a fallback for clients whose global item-level format differs
    -- from the text returned by the tooltip API.
    local labels = {
        "Item Level", "物品等级", "物品等級", "アイテムレベル", "아이템 레벨",
        "Niveau d’objet", "Nivel de objeto", "Gegenstandsstufe", "Уровень предмета",
    }
    for _, label in ipairs(labels) do
        if text:find(label, 1, true) then
            return tonumber(text:match("(%d+)%s*$"))
        end
    end
end

local function extractEnchantLine(text)
    if not text then return nil end

    if ENCHANTED_TOOLTIP_LINE then
        local pattern = escapePattern(ENCHANTED_TOOLTIP_LINE):gsub("%%s", "(.+)")
        local enchant = text:match("^" .. pattern .. "$")
        if enchant and enchant ~= "" then
            return enchant
        end
    end

    local localizedPrefix = (L["Enchanted:"] or "")
        :gsub(":%s*$", "")
        :gsub("：%s*$", "")
    if localizedPrefix ~= "" then
        local enchant = text:match("^" .. escapePattern(localizedPrefix) .. "%s*:%s*(.+)$")
        if not enchant then
            enchant = text:match("^" .. escapePattern(localizedPrefix) .. "%s*：%s*(.+)$")
        end
        if enchant and enchant ~= "" then
            return enchant
        end
    end

    local prefixes = {
        "Enchanted", "Enchant", "附魔", "附魔效果", "마법부여", "Verzaubert",
        "Enchanté", "Encantado", "Чары",
    }
    for _, prefix in ipairs(prefixes) do
        local enchant = text:match("^" .. escapePattern(prefix) .. "%s*:%s*(.+)$")
        if not enchant then
            enchant = text:match("^" .. escapePattern(prefix) .. "%s*：%s*(.+)$")
        end
        if enchant and enchant ~= "" then
            return enchant
        end
    end
end

local function isEnchantableSlot(slotIndex, itemType, itemLink)
    if slotIndex == 17 then
        if itemType == "Weapon" then
            return true
        end

        if C_Item and type(C_Item.GetItemInfoInstant) == "function" then
            local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemLink)
            return equipLoc == "INVTYPE_WEAPON"
                or equipLoc == "INVTYPE_2HWEAPON"
                or equipLoc == "INVTYPE_WEAPONMAINHAND"
                or equipLoc == "INVTYPE_WEAPONOFFHAND"
                or equipLoc == "INVTYPE_SHIELD"
                or equipLoc == "INVTYPE_HOLDABLE"
        end

        return false
    end

    return slotIndex == 5 or slotIndex == 7 or slotIndex == 8 or slotIndex == 9
        or slotIndex == 10 or slotIndex == 15
        or slotIndex == 16
end

local function getMissingEnchantText()
    local label = (L["Enchanted:"] or "Enchanted:")
        :gsub(":%s*$", "")
        :gsub("：%s*$", "")
    local missing = ADDON_MISSING or ((locale == "zhCN" or locale == "zhTW") and "缺失" or "Missing")
    return "<" .. label .. ": " .. missing .. ">"
end

local function getLocalizedSpellName(spellID, fallback)
    local name
    if C_Spell and type(C_Spell.GetSpellName) == "function" then
        name = C_Spell.GetSpellName(spellID)
    end
    if not name and type(GetSpellInfo) == "function" then
        name = GetSpellInfo(spellID)
    end
    return name or fallback
end

local function stripEnchantSpellPrefix(name)
    if not name then return nil end
    local stripped = name:match("^.-%s+[-–—－]%s+(.+)$")
        or name:match("^.-%s*[:：]%s*(.+)$")
    return stripped or name
end

local MOP_WEAPON_ENCHANT_SPELLS = {
    [4441] = 104430, -- Elemental Force
    [4442] = 104427, -- Jade Spirit
    [4443] = 104434, -- Dancing Steel
    [4444] = 104425, -- Windsong
    [4445] = 104440, -- Colossus
    [4446] = 104442, -- River's Song
}

local function getGeneratedEnchantText(enchantID)
    if not enchantID or enchantID <= 0 then return nil end

    local tooltip = _G.CCS_MOPEnchantNameTooltip
    if not tooltip then
        tooltip = CreateFrame(
            "GameTooltip",
            "CCS_MOPEnchantNameTooltip",
            UIParent,
            "GameTooltipTemplate"
        )
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end

    local function collectLines(itemString)
        local lines = {}
        tooltip:Hide()
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
        tooltip:ClearLines()
        tooltip:SetHyperlink(itemString)

        for lineIndex = 2, tooltip:NumLines() do
            local left = _G[tooltip:GetName() .. "TextLeft" .. lineIndex]
            local text = norm(left and left:GetText())
            if text then lines[text] = true end
        end
        return lines
    end

    if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
        C_Item.RequestLoadItemDataByID(9333)
    end

    local baseLines = collectLines("item:9333:0")
    local enchantedLines = collectLines("item:9333:" .. enchantID)
    tooltip:Hide()

    for text in pairs(enchantedLines) do
        if not baseLines[text] then
            return text
        end
    end
end

local function getPermanentWeaponEnchantName(enchantID)
    local spellID = MOP_WEAPON_ENCHANT_SPELLS[enchantID]
    if spellID then
        local spellName = getLocalizedSpellName(spellID)
        if spellName then
            return stripEnchantSpellPrefix(spellName)
        end
    end
    return getGeneratedEnchantText(enchantID)
end

local function playerHasEngineering()
    if type(IsSpellKnown) == "function" and IsSpellKnown(4036) then
        return true
    end
    if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then
        return false
    end

    local profession1, profession2 = GetProfessions()
    for _, professionIndex in pairs({ profession1, profession2 }) do
        if professionIndex then
            local professionName, _, _, _, _, _, skillLine = GetProfessionInfo(professionIndex)
            if tonumber(skillLine) == 202 then
                return true
            end

            local engineeringName = getLocalizedSpellName(4036, "Engineering")
            if professionName == engineeringName
                or professionName == "工程学"
                or professionName == "工程學"
                or professionName == "Engineering" then
                return true
            end
        end
    end
    return false
end

local MOP_ENGINEERING_TINKERS = {
    [6] = {
        spellID = 55016,
        zhCN = "氮气推进器",
        zhTW = "硝化甘油推進器",
        enUS = "Nitro Boosts",
    },
    [10] = {
        spellID = 126731,
        zhCN = "神经元弹簧",
        zhTW = "神經突觸彈簧",
        enUS = "Synapse Springs",
    },
    [15] = {
        spellID = 126392,
        zhCN = "地精滑翔器",
        zhTW = "哥布林滑翔翼",
        enUS = "Goblin Glider",
    },
}

local function isOnUseTooltipLine(text)
    if not text then return false end
    local localizedTrigger = _G.ITEM_SPELL_TRIGGER_ONUSE
    return (localizedTrigger and text:find(localizedTrigger, 1, true) ~= nil)
        or text:find("使用", 1, true) ~= nil
        or text:find("Use:", 1, true) ~= nil
end

local function getEngineeringTinkerName(unitID, slotID, equippedItemLink)
    local tinker = MOP_ENGINEERING_TINKERS[slotID]
    if not tinker or not equippedItemLink then return nil end

    local tooltip = _G.CCS_MOPEngineeringScanTooltip
    if not tooltip then
        tooltip = CreateFrame(
            "GameTooltip",
            "CCS_MOPEngineeringScanTooltip",
            UIParent,
            "GameTooltipTemplate"
        )
        tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end

    local baseLines = {}
    tooltip:Hide()
    tooltip:SetOwner(UIParent, "ANCHOR_NONE")
    tooltip:ClearLines()
    tooltip:SetHyperlink(equippedItemLink)
    for lineIndex = 2, tooltip:NumLines() do
        local left = _G[tooltip:GetName() .. "TextLeft" .. lineIndex]
        local right = _G[tooltip:GetName() .. "TextRight" .. lineIndex]
        local leftText = norm(left and left:GetText())
        local rightText = norm(right and right:GetText())
        if leftText then baseLines[leftText] = true end
        if rightText then baseLines[rightText] = true end
    end

    tooltip:ClearLines()
    local ok = pcall(tooltip.SetInventoryItem, tooltip, unitID, slotID)
    if not ok then
        tooltip:Hide()
        return nil
    end

    for lineIndex = 2, tooltip:NumLines() do
        local left = _G[tooltip:GetName() .. "TextLeft" .. lineIndex]
        local right = _G[tooltip:GetName() .. "TextRight" .. lineIndex]
        local texts = {
            norm(left and left:GetText()),
            norm(right and right:GetText()),
        }

        for _, text in pairs(texts) do
            if text and isOnUseTooltipLine(text) then
                local isExpectedTinker = not baseLines[text]

                -- Gloves have several engineering tinkers.  Only Synapse
                -- Springs has the MoP 1,920 primary-stat use effect.
                if slotID == 10 then
                    local digits = text:gsub("[^%d]", "")
                    isExpectedTinker = isExpectedTinker and digits:find("1920", 1, true) ~= nil
                end

                if isExpectedTinker then
                    tooltip:Hide()
                    local fallback = tinker[locale] or tinker.enUS
                    return getLocalizedSpellName(tinker.spellID, fallback)
                end
            end
        end
    end

    tooltip:Hide()
    return nil
end

local function getEngineeringEnchantLabel()
    if locale == "zhCN" or locale == "zhTW" then
        return "工程附魔"
    end
    return "Engineering"
end

local function getEngineeringMissingText()
    local missing = ADDON_MISSING or ((locale == "zhCN" or locale == "zhTW") and "缺失" or "Missing")
    return "<" .. getEngineeringEnchantLabel() .. ": " .. missing .. ">"
end

-- Line filter: ignore all non-enchant differences
local function isIgnorableLine(t)
    return not t
        or isSocketLine(t)
        or t:match(CREATED_BY_PATTERN)
        or t:match("^<.->$")
        or t == SOULBOUND
        or t:match(UPGRADE_PATTERN)
        or t:match(UPGRADE_FALLBACK_PATTERN)
        or parseUpgradeLine(t) ~= nil
        or t:match(DURABILITY_PATTERN)
        or t:match(DURABILITY_FALLBACK_PATTERN)
        or t:match(REQUIRES_LEVEL_PATTERN)
        or t:match(ITEM_LEVEL_PATTERN)
        or t:match(ITEM_LEVEL_FALLBACK_PATTERN)
        or t:match(TRANSMOG_HEADER_PATTERN)         -- NEW
        or isReforgeOrArmorLine(t)
        or (enchantDetectionEnabled and (
            t:match(REFORGE_PATTERN) or
            t == REFORGED_LINE or
            isReforgedSourceLine(t)
        ))
end

-- Get item link
local itemLink = GetInventoryItemLink(unit, slotIndex)
if itemLink then
    --------------------------------------------------------------------
    -- 1. Always check for upgrade line and item level
    --------------------------------------------------------------------
    local lastLineWasTransmogHeader = false
    CCS_ScanTooltip:ClearLines()
    CCS_ScanTooltip:SetInventoryItem(unit, slotIndex)

    -- Prefer the structured tooltip API when available.  It is more reliable
    -- than the legacy GameTooltip font-string globals on MoP Classic.
    if C_TooltipInfo and type(C_TooltipInfo.GetInventoryItem) == "function" then
        local tooltipInfo = C_TooltipInfo.GetInventoryItem(unit, slotIndex)
        if tooltipInfo and tooltipInfo.lines then
            for _, line in ipairs(tooltipInfo.lines) do
                local text = norm(line.leftText)
                if text then
                    local tooltipItemLevel = parseItemLevelLine(text)
                    if tooltipItemLevel then
                        itemiLevel = tooltipItemLevel
                    end

                    local tooltipEnchant = extractEnchantLine(text)
                    if tooltipEnchant and Enchant == "" then
                        Enchant = tooltipEnchant
                    end

                    local upgradeLine = parseUpgradeLine(text)
                    if upgradeLine then
                        ItemUpgradeLevel = upgradeLine
                    end
                end
            end
        end
    end

    for i = 2, CCS_ScanTooltip:NumLines() do
        local L = _G["CCS_ScanTooltipTextLeft"..i]
        local text = norm(L and L:GetText() or nil)

        if text then
            local tooltipItemLevel = parseItemLevelLine(text)
            if tooltipItemLevel then
                itemiLevel = tooltipItemLevel
            end

            local tooltipEnchant = extractEnchantLine(text)
            if tooltipEnchant and Enchant == "" then
                Enchant = tooltipEnchant
            end

            -- Transmog skip (header + next line)
            if text:match(TRANSMOG_HEADER_PATTERN) then
                lastLineWasTransmogHeader = true
            elseif lastLineWasTransmogHeader then
                lastLineWasTransmogHeader = false
            else
                -- Normal processing
                local upgradeLine = parseUpgradeLine(text)
                if upgradeLine then
                    ItemUpgradeLevel = upgradeLine
                end

               --[[ local ilvl = text:match(ITEM_LEVEL:gsub("%%d", "(%%d+)"))
                if ilvl then
                    itemiLevel = tonumber(ilvl)
                end--]]
            end
        end
    end

    -- Tooltip data is authoritative for the displayed item.  The item API
    -- values are only fallbacks because they can be stale or unspecific.
    if not itemiLevel then
        itemiLevel = tonumber(itemInfoLevel)
        if not itemiLevel or itemiLevel <= 0 then
            itemiLevel = tonumber(detailedItemLevel)
        end
    end

    --------------------------------------------------------------------
    -- 2. Enchant detection
    --------------------------------------------------------------------
    if enchantDetectionEnabled then
        if hasPermanentEnchant and Enchant == "" then

            ----------------------------------------------------------------
            -- 2a. Build base tooltip lines (unenchanted version)
            ----------------------------------------------------------------
            local baseLines = {}
            local baseStatsSeen = {}
            local baseLink = itemLink:gsub("item:(%d+):%d+", "item:%1:0")

            local lastLineWasTransmogHeader = false

            CCS_ScanTooltip:ClearLines()
            CCS_ScanTooltip:SetHyperlink(baseLink)

            for i = 2, CCS_ScanTooltip:NumLines() do
                local L = _G["CCS_ScanTooltipTextLeft"..i]
                local t = norm(L and L:GetText() or nil)

                if t then
                    -- Transmog skip
                    if t:match(TRANSMOG_HEADER_PATTERN) then
                        lastLineWasTransmogHeader = true
                    elseif lastLineWasTransmogHeader then
                        lastLineWasTransmogHeader = false
                    else
                        -- Normal processing
                        local src = t:match("Reforged from%s+([%a%s]+)")
                        if src and src ~= "" then
                            reforgedFromStats[src] = true
                        end

                        local statName = extractStatName(t)
                        if statName then
                            baseStatsSeen[statName] = true
                        end

                        if not isIgnorableLine(t) then
                            baseLines[t] = true
                        end
                    end
                end
            end

            ----------------------------------------------------------------
            -- 2b. Compare equipped tooltip to base tooltip
            ----------------------------------------------------------------
            local equippedStatsConsumed = {}
            local lastLineWasTransmogHeader = false

            CCS_ScanTooltip:ClearLines()
            CCS_ScanTooltip:SetInventoryItem(unit, slotIndex)

            for i = 2, CCS_ScanTooltip:NumLines() do
                local L = _G["CCS_ScanTooltipTextLeft"..i]
                local t = norm(L and L:GetText() or nil)

                if t then
                    -- Transmog skip
                    if t:match(TRANSMOG_HEADER_PATTERN) then
                        lastLineWasTransmogHeader = true
                    elseif lastLineWasTransmogHeader then
                        lastLineWasTransmogHeader = false
                    else
                        -- Normal processing
                        local src = t:match("Reforged from%s+([%a%s]+)")
                        if src and src ~= "" then
                            reforgedFromStats[src] = true
                        end

                        local statName = extractStatName(t)
                        if statName and baseStatsSeen[statName] and not equippedStatsConsumed[statName] then
                            equippedStatsConsumed[statName] = true

                        elseif not isIgnorableLine(t) and not baseLines[t] then
                            Enchant = t
                            break
                        end
                    end
                end
            end
        end
    end
end

if slotIndex == 16 and hasPermanentEnchant then
    local weaponEnchantName = getPermanentWeaponEnchantName(permanentEnchantID)
    if weaponEnchantName and weaponEnchantName ~= "" then
        Enchant = weaponEnchantName
    end
end

local engineeringTinkerName = getEngineeringTinkerName(unit, slotIndex, link)
if engineeringTinkerName then
    EngineeringEnchant = engineeringTinkerName
elseif isPlayer and MOP_ENGINEERING_TINKERS[slotIndex]
    and playerHasEngineering()
    and option("showenchantgemerrors"..suffix) == true then
    EngineeringEnchant = "|cffff0000" .. getEngineeringMissingText() .. "|r"
end


--[[
if itemLink then
    -- Always check for upgrade line and item level
    CCS_ScanTooltip:ClearLines()
    CCS_ScanTooltip:SetInventoryItem(unit, slotIndex)
    for i = 2, CCS_ScanTooltip:NumLines() do
        local L = _G["CCS_ScanTooltipTextLeft"..i]
        local text = norm(L and L:GetText() or nil)
        
        if text then
            local upgradeLine = parseUpgradeLine(text)
            if upgradeLine then
                ItemUpgradeLevel = upgradeLine
            end
            local ilvl = text:match(ITEM_LEVEL:gsub("%%d", "(%%d+)"))
            if ilvl then
                itemiLevel = tonumber(ilvl)
            end
        end
    end

    -- Only run enchant detection if enabled and enchantId is non-zero
    if enchantDetectionEnabled then
        local enchantId = itemLink:match("item:%d+:(%d+)")
        if enchantId and enchantId ~= "0" then
            local baseLines = {}
            local baseStatsSeen = {}
            local baseLink = itemLink:gsub("item:(%d+):%d+", "item:%1:0")

            CCS_ScanTooltip:ClearLines()
            CCS_ScanTooltip:SetHyperlink(baseLink)
            for i = 2, CCS_ScanTooltip:NumLines() do
                local L = _G["CCS_ScanTooltipTextLeft"..i]
                local t = norm(L and L:GetText() or nil)
                if t then
                    local src = t:match("Reforged from%s+([%a%s]+)")
                    if src and src ~= "" then
                        reforgedFromStats[src] = true
                    end
                    local statName = extractStatName(t)
                    if statName then
                        baseStatsSeen[statName] = true
                    end
                    if not isIgnorableLine(t) then
                        baseLines[t] = true
                    end
                end
            end

            local equippedStatsConsumed = {}
            CCS_ScanTooltip:ClearLines()
            CCS_ScanTooltip:SetInventoryItem(unit, slotIndex)
            for i = 2, CCS_ScanTooltip:NumLines() do
                local L = _G["CCS_ScanTooltipTextLeft"..i]
                local t = norm(L and L:GetText() or nil)
                if t then
                    local src = t:match("Reforged from%s+([%a%s]+)")
                    if src and src ~= "" then
                        reforgedFromStats[src] = true
                    end
                    local statName = extractStatName(t)
                    if statName and baseStatsSeen[statName] and not equippedStatsConsumed[statName] then
                        equippedStatsConsumed[statName] = true
                    elseif not isIgnorableLine(t) and not baseLines[t] then
                        Enchant = t
                        break
                    end
                end
            end
        end
    end
end
--]]
-------------------
-- End of the crazy tooltip detection (mostly since blizzard didn't use the enchant line in MOP)
-------------------
        local _, gem1Link = C_Item.GetItemGem(link, 1); 
        local _, gem2Link = C_Item.GetItemGem(link, 2); 
        local _, gem3Link = C_Item.GetItemGem(link, 3); 

        -- Read gem icons from the actual gem links instead of relying on the
        -- legacy item-link field positions, which changed across expansions.
        local function getGemIcon(gemLink)
            if not gemLink then return nil end

            local gemID
            if type(gemLink) == "string" then
                gemID = tonumber(gemLink:match("item:(%d+)"))
            else
                gemID = tonumber(gemLink)
            end
            local icon = gemID and C_Item.GetItemIconByID(gemID) or nil
            local gemQuery = gemID or gemLink
            if not icon and gemQuery and type(C_Item.GetItemInfoInstant) == "function" then
                icon = select(5, C_Item.GetItemInfoInstant(gemQuery))
            end
            if not icon and gemQuery and (type(gemQuery) == "string" or type(gemQuery) == "number") then
                icon = select(10, C_Item.GetItemInfo(gemQuery))
            end
            return icon
        end

        local function getEmptySocketTextures(itemLink)
            if type(itemLink) ~= "string" then return nil, nil, nil, nil, nil, nil end

            local itemString = itemLink:match("(item:[^|]+)")
            if not itemString then return nil, nil, nil, nil, nil, nil end

            local itemID, enchantID, _, _, _, _, tail = itemString:match(
                "^item:([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):(.*)$"
            )
            if not itemID then return nil, nil, nil, nil, nil, nil end

            -- Preserve reforge, upgrade and all later item-instance fields,
            -- but clear the four gem fields so the tooltip exposes the
            -- original socket textures in their actual order.
            local emptyGemItemString = table.concat({
                "item", itemID, enchantID, "0", "0", "0", "0", tail,
            }, ":")

            local tooltip = _G.CCS_MOPSocketScanTooltip
            if not tooltip then
                tooltip = CreateFrame(
                    "GameTooltip",
                    "CCS_MOPSocketScanTooltip",
                    UIParent,
                    "GameTooltipTemplate"
                )
                tooltip:SetOwner(UIParent, "ANCHOR_NONE")
            end

            tooltip:Hide()
            tooltip:SetOwner(UIParent, "ANCHOR_NONE")
            tooltip:ClearLines()

            for socketIndex = 1, 3 do
                local socketTexture = _G[tooltip:GetName() .. "Texture" .. socketIndex]
                if socketTexture then socketTexture:SetTexture(nil) end
            end

            local ok = pcall(tooltip.SetHyperlink, tooltip, emptyGemItemString)
            if not ok then
                tooltip:Hide()
                return nil, nil, nil, nil, nil, nil
            end

            local socketTextures = {}
            local socketKinds = {}
            for socketIndex = 1, 3 do
                local socketTexture = _G[tooltip:GetName() .. "Texture" .. socketIndex]
                socketTextures[socketIndex] = socketTexture and socketTexture:GetTexture() or nil
                socketKinds[socketIndex] = getSocketKindFromTexture(socketTextures[socketIndex])
            end

            -- Some MoP clients populate the localized empty-socket lines but
            -- leave the GameTooltip texture regions blank.  Read those lines
            -- in order as the first fallback.
            local textSocketIndex = 0
            for lineIndex = 2, tooltip:NumLines() do
                local left = _G[tooltip:GetName() .. "TextLeft" .. lineIndex]
                local right = _G[tooltip:GetName() .. "TextRight" .. lineIndex]
                local socketKind = getSocketKindFromText(left and left:GetText())
                    or getSocketKindFromText(right and right:GetText())
                if socketKind then
                    textSocketIndex = textSocketIndex + 1
                    if textSocketIndex <= 3 then
                        socketKinds[textSocketIndex] = socketKinds[textSocketIndex] or socketKind
                    end
                end
            end
            tooltip:Hide()

            -- Last fallback: GetItemStats provides socket counts even when
            -- the legacy tooltip exposes neither textures nor socket lines.
            local hasSocket = socketTextures[1] or socketTextures[2] or socketTextures[3]
                or socketKinds[1] or socketKinds[2] or socketKinds[3]
            if not hasSocket then
                local stats
                if C_Item and type(C_Item.GetItemStats) == "function" then
                    local statsOK, result = pcall(C_Item.GetItemStats, emptyGemItemString)
                    if statsOK and type(result) == "table" then stats = result end
                elseif type(GetItemStats) == "function" then
                    local statsOK, result = pcall(GetItemStats, emptyGemItemString)
                    if statsOK and type(result) == "table" then stats = result end
                end

                if stats then
                    local fallbackOrder = { "META", "RED", "YELLOW", "BLUE", "PRISMATIC", "COGWHEEL" }
                    local fallbackIndex = 0
                    for _, socketKind in ipairs(fallbackOrder) do
                        local count = tonumber(stats["EMPTY_SOCKET_" .. socketKind]) or 0
                        for _ = 1, count do
                            fallbackIndex = fallbackIndex + 1
                            if fallbackIndex <= 3 then
                                socketKinds[fallbackIndex] = socketKind
                            end
                        end
                    end
                end
            end

            for socketIndex = 1, 3 do
                if not socketTextures[socketIndex] and socketKinds[socketIndex] then
                    socketTextures[socketIndex] = socketTextureByKind[socketKinds[socketIndex]]
                end
            end

            return socketTextures[1], socketTextures[2], socketTextures[3],
                socketKinds[1], socketKinds[2], socketKinds[3]
        end

        local Gem1Icon = getGemIcon(gem1Link)
        local Gem2Icon = getGemIcon(gem2Link)
        local Gem3Icon = getGemIcon(gem3Link)

        local Sockettex1, Sockettex2, Sockettex3, SocketKind1, SocketKind2, SocketKind3 =
            getEmptySocketTextures(link)

        local Gemtex1 = _G["CCS_ScanningtooltipTexture1"]:GetTexture() or nil
        local Gemtex2 = _G["CCS_ScanningtooltipTexture2"]:GetTexture() or nil
        local Gemtex3 = _G["CCS_ScanningtooltipTexture3"]:GetTexture() or nil
        local MISSING_SOCKET = "Interface\\AddOns\\ChonkyCharacterSheet\\Media\\Textures\\missing-socket.png"

        -- Show Missing sockets
        -- Keep the legacy missing-socket placeholder disabled here.  The MoP
        -- code does not reliably know how many sockets an item has, and can
        -- otherwise interrupt updates for the following equipment slots.
        if option("showenchantgemerrors"..suffix) == true and false then
            if slotIndex == INVSLOT_HEAD or slotIndex == INVSLOT_WRIST or slotIndex == INVSLOT_WAIST then
                Gemtex1 = Gemtex1 or MISSING_SOCKET
            elseif slotIndex == INVSLOT_NECK or slotIndex == INVSLOT_FINGER1 or slotIndex == INVSLOT_FINGER2 then
                Gemtex1 = Gemtex1 or MISSING_SOCKET
                Gemtex2 = Gemtex2 or MISSING_SOCKET
            end
        end
 
        -- Item name info (item name in white as well) [White or Rarity Color, 12]
        if option("showitemname"..suffix) == true then
            if option("itemcolorwhite"..suffix) then Color = "ffffffff" end
            if itemName ~= nil then
                if (string.len(Color) < 8) then Color = "FF"..Color end
                if strlen(itemName) > option("itemnamelength"..suffix) then itemName = format("%." .. option("itemnamelength"..suffix) .. "s", itemName) .. "..." end                
                nameTxt:SetText("|c".. Color .. itemName .. "|r") 
            end
            nameTxt:Show()
        end
        
        -- iLvl information [White] 
        if option("showilvl"..suffix) == true then
            if option("showitemupgrade"..suffix) then 
                if string.len(ItemUpgradeLevel) > 0 then
                    local upgradeCurrent, upgradeMax = ItemUpgradeLevel:match("(%d+)%s*/%s*(%d+)%s*$")
                    local upgradeColor

                    if upgradeCurrent and upgradeMax
                        and tonumber(upgradeCurrent) < tonumber(upgradeMax) then
                        -- Incomplete upgrade tracks are highlighted like
                        -- missing enchants.
                        upgradeColor = CreateColor(1, 0, 0, 1)
                    else
                        local upr, upg, upb, upalpha = option("itemupgradecolor"..suffix)[1], option("itemupgradecolor"..suffix)[2], option("itemupgradecolor"..suffix)[3], option("itemupgradecolor"..suffix)[4]
                        upgradeColor = CreateColor(upr, upg, upb, upalpha)
                    end

                    ItemUpgradeLevel = WrapTextInColor("(" .. ItemUpgradeLevel .. ")", upgradeColor)
                end
            else
                ItemUpgradeLevel = ""
            end
            
            if displaytoleft and itemiLevel ~= nil then
                ilvlTxt:SetText(ItemUpgradeLevel .." ".. itemiLevel) 
                --ilvlTxt:SetText(ItemUpgradeLevel .. " |cFFffffff" .. itemiLevel .. "|r") 
            elseif itemiLevel ~= nil then
                --ilvlTxt:SetText("|cFFffffff" .. itemiLevel .. " " .. ItemUpgradeLevel .. "|r")
                ilvlTxt:SetText(itemiLevel .." ".. ItemUpgradeLevel) 
            end
            ilvlTxt:Show()
        end
        
        -- Enchant Info [Mint/Red, 10]  (Mint #2afab5)
        if option("showenchants"..suffix) == true then
            -- An enchant ID in the item link confirms an enchant even when
            -- the client does not expose a separate enchant tooltip line.
            if Enchant == "" and hasPermanentEnchant then
                Enchant = (L["Enchanted:"] or "Enchanted:")
                    :gsub(":%s*$", "")
                    :gsub("：%s*$", "")
            end

            if Enchant == "" and option("showenchantgemerrors"..suffix) == true
                and isEnchantableSlot(slotIndex, itemType, link) then
                Enchant = "|cffff0000" .. getMissingEnchantText() .. "|r"
            end

            local enchantParts = {}
            if Enchant ~= "" then
                enchantParts[#enchantParts + 1] = Enchant
            end
            if EngineeringEnchant ~= "" then
                enchantParts[#enchantParts + 1] = EngineeringEnchant
            end

            enchantTxt:SetText(table.concat(enchantParts, " / "))
            enchantTxt:Show()
        end
        
        -- Display Durability text (white)
        if isPlayer and option("showdurability") == true and durMax ~= nil and durCur ~= nil and durMax > 0 and durCur ~= durMax then
            local DurPercent = string.format("%.f", durCur/durMax*100)
            durabilityTxt:SetText(DurPercent.."%")
            durabilityTxt:Show()
        end
        
        if isPlayer and option("showdurabilitybar") == true and durMax ~= nil and durCur ~= nil and durMax > 0 and durCur ~= durMax then
            local DurPercent = durCur/durMax
            
            if DurPercent > 0.66 then durbartex:SetColorTexture(0, 1, 0) -- green
            elseif DurPercent > 0.33 then durbartex:SetColorTexture(1, 1, 0) -- yellow
            elseif DurPercent > 0.10 then durbartex:SetColorTexture(1, 0, 0) -- red
            else durbartex:SetColorTexture(1, 0, 0, 0.10) 
            end
            
            durbar:SetHeight(30*DurPercent)
            durbar:Show()
        end
        
        if option("showgems"..suffix) == true then
            local tooltip, tooltip2, tooltip3 = "", "", ""
            local gemCount = 0
            
            if Gem1Icon or Gemtex1 or Sockettex1 or SocketKind1 then gemCount= gemCount+1 end
            if Gem2Icon or Gemtex2 or Sockettex2 or SocketKind2 then gemCount= gemCount+1 end
            if Gem3Icon or Gemtex3 or Sockettex3 or SocketKind3 then gemCount= gemCount+1 end
            
            if slotIndex == 2 and expacID == LE_EXPANSION_DRAGONFLIGHT then
                gemCount = 3
            end
            
            if gemCount == 1 then
                gemIconframe1:ClearAllPoints()
                gemIconframe1:SetPoint(SubElementSetPoint2, slotFrameName, SubElementSetPoint, -8 * neg, 0)
            elseif gemCount == 2 then
                gemIconframe1:ClearAllPoints()
                gemIconframe2:ClearAllPoints()
                gemIconframe1:SetPoint("TOP"..SubElementSetPoint2, slotFrameName, "TOP"..SubElementSetPoint, -8 * neg, -2)
                gemIconframe2:SetPoint("BOTTOM"..SubElementSetPoint2, slotFrameName, "BOTTOM"..SubElementSetPoint, -8 * neg, 2)
            elseif gemCount == 3 then
                gemIconframe1:ClearAllPoints()
                gemIconframe2:ClearAllPoints()
                gemIconframe3:ClearAllPoints()
                gemIconframe2:ClearAllPoints()
                gemIconframe1:SetPoint("TOP"..SubElementSetPoint2, slotFrameName, "TOP"..SubElementSetPoint, -8 * neg, 4)
                gemIconframe2:SetPoint(SubElementSetPoint2, slotFrameName, SubElementSetPoint, -8 * neg, 0)
                gemIconframe3:SetPoint("BOTTOM"..SubElementSetPoint2, slotFrameName, "BOTTOM"..SubElementSetPoint, -8 * neg, -4)
            end
            
            local Gem1type, Gem2type, Gem3type = 0,0,0
            
            if Gem1Icon then
                gemIconframe1:SetNormalTexture(Gem1Icon)
                showSocketRing(gemSocketRing1, Sockettex1, SocketKind1, Gem1Icon)
                gemIconframe1:Show()
            elseif Gemtex1 or Sockettex1 then
                local emptySocketTexture = Gemtex1 or Sockettex1
                gemIconframe1:SetNormalTexture(emptySocketTexture)
                if CCS.GemInfo[emptySocketTexture] then tooltip = CCS.GemInfo[emptySocketTexture].text else tooltip = ADDON_MISSING end
                gemIconframe1:Show()
            elseif slotIndex == 2 and expacID == LE_EXPANSION_DRAGONFLIGHT and option("showenchants"..suffix) then
                gemIconframe1:SetNormalTexture("Interface\\COMMON\\Indicator-Red.blp")
                tooltip = EMPTY_SOCKET_PRISMATIC .. ": " .. ADDON_MISSING
                gemIconframe1:Show()
            end
            
            if Gem2Icon then
                gemIconframe2:SetNormalTexture(Gem2Icon)
                showSocketRing(gemSocketRing2, Sockettex2, SocketKind2, Gem2Icon)
                gemIconframe2:Show()
            elseif Gemtex2 or Sockettex2 then
                local emptySocketTexture = Gemtex2 or Sockettex2
                gemIconframe2:SetNormalTexture(emptySocketTexture)
                if CCS.GemInfo[emptySocketTexture] then tooltip2 = CCS.GemInfo[emptySocketTexture].text else tooltip2 = ADDON_MISSING end
                gemIconframe2:Show()
            elseif slotIndex == 2 and expacID == LE_EXPANSION_DRAGONFLIGHT and option("showenchants"..suffix) then
                gemIconframe2:SetNormalTexture("Interface\\COMMON\\Indicator-Red.blp")
                tooltip2 = EMPTY_SOCKET_PRISMATIC .. ": " .. ADDON_MISSING
                gemIconframe2:Show()
            end
            
            if Gem3Icon then
                gemIconframe3:SetNormalTexture(Gem3Icon)
                showSocketRing(gemSocketRing3, Sockettex3, SocketKind3, Gem3Icon)
                gemIconframe3:Show()
            elseif Gemtex3 or Sockettex3 then
                local emptySocketTexture = Gemtex3 or Sockettex3
                gemIconframe3:SetNormalTexture(emptySocketTexture)
                if CCS.GemInfo[emptySocketTexture] then tooltip3 = CCS.GemInfo[emptySocketTexture].text else tooltip3 = ADDON_MISSING end
                gemIconframe3:Show()
            elseif slotIndex == 2 and expacID == LE_EXPANSION_DRAGONFLIGHT and option("showenchants"..suffix) then
                gemIconframe3:SetNormalTexture("Interface\\COMMON\\Indicator-Red.blp")
                tooltip3 = EMPTY_SOCKET_PRISMATIC .. ": " .. ADDON_MISSING
                gemIconframe3:Show()
            end
            local GemToolTip = CCS:CreateTooltip("CCSGemTooltip")
            gemIconframe1:SetScript("OnEnter", function() 
                    if gem1Link then
                         CCS.RenderSafeTooltip(GemToolTip, gem1Link, "player")
                    end
            end)
            gemIconframe1:SetScript("OnLeave", function() GemToolTip:Hide() end)
            gemIconframe2:SetScript("OnEnter", function() 
                    if gem2Link then
                         CCS.RenderSafeTooltip(GemToolTip, gem2Link, "player")
                    end
            end)
            gemIconframe2:SetScript("OnLeave", function()  GemToolTip:Hide() end)
            gemIconframe2:SetScript("OnClick", function()  end)
            
            gemIconframe3:SetScript("OnEnter", function() 
                    if gem3Link then
                         CCS.RenderSafeTooltip(GemToolTip, gem3Link, "player")
                    end

            end)
            gemIconframe3:SetScript("OnLeave", function() GemToolTip:Hide() end)
            gemIconframe3:SetScript("OnClick", function()  end) 
        end
        
        if option("showitemcolor"..suffix) then
            local setr, setg, setb, setalpha = option("setitemcolor"..suffix)[1], option("setitemcolor"..suffix)[2], option("setitemcolor"..suffix)[3], option("setitemcolor"..suffix)[4];
            
            if displaytoleft then 
                bgfadertex:SetTexCoord(1,0,0,1)
                
                if itemRarity == 1 then bgfadertex:SetGradient("Horizontal", CreateColor(.5, .5, .5, .4), CreateColor(1, 1, 1, 1))  -- white (Common)
                elseif itemRarity == 2 then bgfadertex:SetGradient("Horizontal", CreateColor(.06, .5, 0, .4), CreateColor(0.12, 1, 0, 1))  -- green (Uncommon)
                elseif itemRarity == 3 then bgfadertex:SetGradient("Horizontal", CreateColor(0, .22, .435, .4), CreateColor(0, 0.44, 0.87, 1)) -- Blue (Rare)
                elseif itemRarity == 4 then bgfadertex:SetGradient("Horizontal", CreateColor(.32, .105, .465, .4), CreateColor(0.64, 0.21, 0.93, 1)) -- Purple (Epic)
                elseif itemRarity == 5 then bgfadertex:SetGradient("Horizontal", CreateColor(.5, .25, 0, .4), CreateColor(1, 0.5, 0, 1)) -- Orange (Legendary)
                elseif itemRarity == 6 then bgfadertex:SetGradient("Horizontal", CreateColor(.45, .4, .25, .4), CreateColor(0.9, 0.8, 0.5, 1)) -- Tan (Artifact)
                elseif itemRarity == 7 then bgfadertex:SetGradient("Horizontal", CreateColor(0, .4, .5, .4), CreateColor(0, 0.8, 1, 1)) -- Light Blue (Heirloom)   
                else bgfadertex:SetGradient("Horizontal", CreateColor(.31, .31, .31, .4), CreateColor(0.62, 0.62, 0.62, 1)) -- gray / poor    
                end
                
                if option("showsetitems"..suffix) and setID then 
                    if option("showsetclasscolor"..suffix) then
                        setr, setg, setb = GetClassColor(select(2, UnitClass(unit)))
                        setalpha = .8
                    end
                    bgfadertex:SetGradient("Horizontal", CreateColor(setr/2, setg/2, setb/2, .4), CreateColor(setr, setg, setb, setalpha)) -- Set Item Color Left Display
                end
                
            else
                if itemRarity == 1 then bgfadertex:SetGradient("Horizontal", CreateColor(1, 1, 1, 1), CreateColor(.5, .5, .5, .4))  -- white (Common)
                elseif itemRarity == 2 then bgfadertex:SetGradient("Horizontal", CreateColor(0.12, 1, 0, 1), CreateColor(.06, .5, 0, .4))  -- green (Uncommon)
                elseif itemRarity == 3 then bgfadertex:SetGradient("Horizontal", CreateColor(0, 0.44, 0.87, 1), CreateColor(0, .22, .435, .4)) -- Blue (Rare)
                elseif itemRarity == 4 then bgfadertex:SetGradient("Horizontal", CreateColor(0.64, 0.21, 0.93, 1), CreateColor(.32, .105, .465, .4)) -- Purple (Epic)
                elseif itemRarity == 5 then bgfadertex:SetGradient("Horizontal", CreateColor(1, 0.5, 0, 1), CreateColor(.5, .25, 0, .4)) -- Orange (Legendary)
                elseif itemRarity == 6 then bgfadertex:SetGradient("Horizontal", CreateColor(0.9, 0.8, 0.5, 1), CreateColor(.45, .4, .25, .4)) -- Tan (Artifact)
                elseif itemRarity == 7 then bgfadertex:SetGradient("Horizontal", CreateColor(0, 0.8, 1, 1), CreateColor(0, .4, .5, .4)) -- Light Blue (Heirloom)   
                else bgfadertex:SetGradient("Horizontal", CreateColor(0.62, 0.62, 0.62, 1), CreateColor(0.62, 0.62, 0.62, .4)) -- gray / poor    
                end
                
                if option("showsetitems"..suffix) and setID then 
                    if option("showsetclasscolor"..suffix) then
                        setr, setg, setb = GetClassColor(select(2, UnitClass(unit)))
                        setalpha = .8
                    end
                    bgfadertex:SetGradient("Horizontal", CreateColor(setr, setg, setb, setalpha), CreateColor(0, 0, 0, .4)) -- Set Item Color Right Display
                end
            end
            bgfader:Show()
        end 
    end

end


local function loopitems()

    for slotIndex = 1,19 do 
        local ok, err = pcall(MOPupdateLocationInfo, "player", slotIndex, "Character")
        if not ok then
            print("|cffff0000ChonkyCharacterSheet|r slot " .. slotIndex .. " update failed: " .. tostring(err))
        end
    end 

    local activeGroup = CCS.mopActiveStatGroup or CCS.mopHoveredStatGroup
    if activeGroup and MOPStatHighlightsEnabled() then
        CCS:ShowStatHighlights(activeGroup)
    end
end

---
--- This just allows us to ensure we have all items cached before we loop.
---
local function TryLoopItems()
    local allReady = true
    for slot = 1, 19 do
        local link = GetInventoryItemLink("player", slot)
        if link and not GetItemInfo(link) then
            allReady = false
            break
        end
    end

    if allReady then
        CCS.characterUpdatePending = false
        loopitems()
    else
        -- Retry after short delay
        C_Timer.After(0.1, TryLoopItems)
    end
            --loopitems()
end

local function CCS_DetectReputationRowStructure()
    local row = ReputationBar1
    if not row then return end

    local name = row:GetName()

    CCS.RepRow = {
        Background      = _G[name.."Background"],
        Bar             = _G[name.."ReputationBar"],
        LeftTexture     = _G[name.."ReputationBarLeftTexture"],
        RightTexture    = _G[name.."ReputationBarRightTexture"],
        StandingText    = _G[name.."ReputationBarFactionStanding"],
        FactionName     = _G[name.."FactionName"],
        Button          = _G[name.."ExpandOrCollapseButton"],
        Height          = row:GetHeight(),
    }

    CCS.RepRowDetected = true
end

local function CCS_DetectFillRegionForRow(row)
    local bar = _G[row:GetName().."ReputationBar"]
    if not bar then return end

    local bg      = _G[row:GetName().."Background"]
    local left    = _G[bar:GetName().."LeftTexture"]
    local right   = _G[bar:GetName().."RightTexture"]

    for i, region in ipairs({ bar:GetRegions() }) do
        if region:IsObjectType("Texture") then
            if region:GetName() == nil then
                -- This is very likely the fill
                row.CCS_FillTexture = region
                return
            end
        end
    end
end

function CCS.CacheReputationRows()
    if CCS.RepRows then return end
    if not ReputationFrame or not ReputationFrame:IsShown() then
        return
    end

    CCS.RepRows = {}
    CCS.SubBars = {}

    for i = 1, NUM_FACTIONS_DISPLAYED do
        local row = _G["ReputationBar"..i]
        if row then
            table.insert(CCS.RepRows, row)

            -- Cache sub-bars once
            CCS.SubBars[row] = { row:GetChildren() }
        end
    end
end

function CCS.StyleReputationRow(row)
    if not CCS.RepRowDetected then
        CCS_DetectReputationRowStructure()
    end

    local name = row:GetName()

    -- Background recolor only
    local bg = _G[name.."Background"]
    if bg then
        bg:SetTexture("Interface\\Masks\\SquareMask.BLP")
        bg:SetColorTexture(.15, .15, .15, 0.90)
        bg:ClearAllPoints()
        bg:SetAllPoints(row)
    end

    -- Only style the actual reputation status bar. The old code treated the
    -- expand/collapse button as a bar too, which widened that button to 200px
    -- and pushed some faction names into the middle of the panel.
    row.CCS_SubBars = {}
    local mainBar = _G[name.."ReputationBar"]
    if mainBar then
        table.insert(row.CCS_SubBars, mainBar)
    else
        for _, child in ipairs({row:GetChildren()}) do
            if child.IsObjectType and child:IsObjectType("StatusBar") then
                table.insert(row.CCS_SubBars, child)
            end
        end
    end

    if not row.CCS_FillTexture then
        CCS_DetectFillRegionForRow(row)
    end

    botline = _G[name.."BottomLine"]
    leftline = _G[name.."LeftLine"]

    if botline then botline:Hide() end
    if leftline then leftline:Hide() end

    -- This is the old bar texture.  We will reuse this later
    local fill = row.CCS_FillTexture
    if fill then
        --fill:SetTexture("Interface\\Masks\\SquareMask.BLP") -- Future
        --fill:SetVertexColor(0.2, 0.6, 1.0, 0.9) -- Future
        fill:Hide()
    end

    for _, bar in ipairs(row.CCS_SubBars) do
        local barName = bar:GetName()

        -- Background recolor only
        bar.Background = bar.Background or bar:CreateTexture(nil, "BACKGROUND", nil, 2)
        bar.Background:SetTexture("Interface\\Masks\\SquareMask.BLP")
        bar.Background:SetColorTexture(.05, .05, .05, 1)
        bar.Background:SetAllPoints()

        bar:SetWidth(200)
        bar:SetHeight(20)
        -- LeftTexture recolor only
        local left = _G[barName.."LeftTexture"]
        if left then
            left:SetTexture("Interface\\Masks\\SquareMask.BLP")
            left:SetAlpha(1)
            left:SetWidth(200)
            left:SetDrawLayer("ARTWORK", 2)
        end

        -- RightTexture hide only
        local right = _G[barName.."RightTexture"]
        if right then
            right:Hide()
        end

        -- Recolors the main row. Set it to the reputation bar.
        local atwar1 = _G[barName.."AtWarHighlight1"]
        if atwar1 then
            atwar1:SetPoint("RIGHT", bar, "LEFT",0,0)
        end
        
        -- Hide the right portion of the at war bar.
        local atwar2 = _G[barName.."AtWarHighlight2"]
        if atwar2 then
            atwar2:Hide()
        end
    end
end

local function CreateExtraReputationRows(numExtra)
    -- Find the last existing row
    local lastRow = _G["ReputationBar"..NUM_FACTIONS_DISPLAYED]
    if not lastRow then return end

    for i = NUM_FACTIONS_DISPLAYED+1, NUM_FACTIONS_DISPLAYED+numExtra do
        -- Only create if it doesn't already exist
        if not _G["ReputationBar"..i] then
            local row = CreateFrame("Button", "ReputationBar"..i, ReputationFrame, "ReputationBarTemplate")

            -- Anchor it directly below the previous row (no extra offset)
            local prevRow = _G["ReputationBar"..(i-1)]
            if prevRow then
                row:SetPoint("TOPLEFT", prevRow, "BOTTOMLEFT", 0, -3)
                row:SetPoint("RIGHT", prevRow, "RIGHT", 0, 0)                
            else
                -- Fallback: anchor to lastRow if prevRow is missing
                row:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, -3)
                row:SetPoint("RIGHT", lastRow, "RIGHT", 0, 0)                                
            end

            -- Set ID/index so GetFactionInfo works
            row:SetID(i)
        end
    end

    -- Update the constant so FauxScrollFrame_Update knows about the new rows
    NUM_FACTIONS_DISPLAYED = NUM_FACTIONS_DISPLAYED + numExtra
end

function CCSReputationFrame_Update()
    if not CCS.RepRowDetected then
        CCS_DetectReputationRowStructure()
    end
    
    local gender = UnitSex("player")

    for i = 1, NUM_FACTIONS_DISPLAYED do
        local row = _G["ReputationBar"..i]
        if not row then break end

        if not row.CCS_Styled then
            CCS.StyleReputationRow(row)
            row.CCS_Styled = true
        end

        botline = _G["ReputationBar"..i.."BottomLine"]
        leftline = _G["ReputationBar"..i.."LeftLine"]

        if botline then botline:Hide() end
        if leftline then leftline:Hide() end

        if row.index then
            local name, _, standingID, barMin, barMax, barValue =
                GetFactionInfo(row.index)
            if name ~= "Inactive" and name ~= "Other" then
                local isCapped = (standingID == MAX_REPUTATION_REACTION)
                local barColor = FACTION_BAR_COLORS[standingID]
                local standingText = GetText("FACTION_STANDING_LABEL"..standingID, gender)

                if isCapped then
                    barMin, barMax, barValue = 0, 21000, 21000
                else
                    barValue = barValue - barMin
                    barMax = barMax - barMin
                end

                local text = format(
                    "  %-20.20s %-30.30s",
                    standingText,
                    format(REPUTATION_PROGRESS_FORMAT,
                        BreakUpLargeNumbers(barValue),
                        BreakUpLargeNumbers(barMax))
                )
               
                for _, bar in ipairs(row.CCS_SubBars) do
                    local barName = bar:GetName()
                    local left = _G[barName.."LeftTexture"]
                    local FactionStanding = _G[barName.."FactionStanding"]
                    
                    if row.hasRep == true then
                        bar:SetWidth(200)
                    else
                        bar:SetWidth(25)
                    end
                    
                    if not bar.setatwar then -- Only process this once since SetPoint creates a ton of frame lag.
                        local atwar1 = _G[barName.."AtWarHighlight1"]
                        if atwar1 then
                            atwar1:SetPoint("RIGHT", bar, "LEFT",0,0)
                        end

                        local atwar2 = _G[barName.."AtWarHighlight2"]
                        if atwar2 then
                            atwar2:SetTexture("")
                        end
                        bar.setatwar = true
                    end

                    if left then
                        left:SetWidth(200)  -- base width

                        left:SetGradient(
                            "Vertical",
                            CreateColor(0, 0, 0, .4),
                            CreateColor(barColor.r, barColor.g, barColor.b, .8)
                        )

                        -- Only adjust fill width
                        local baseWidth = 200
                        if barMax > 0 then
                            left:SetWidth(math.max(1, baseWidth * barValue / barMax))
                        end
                    end

                    if FactionStanding then
                        FactionStanding:SetText(text)
                    end
                    if bar.StandingText then
                        bar.StandingText:SetText(text)
                        bar.tooltip:SetText(text)
                    end
                end
            end
        end

    end
end

local function CurrencyFrame_Update()
    local scrollFrame = GetMOPCurrencyScrollFrame()
    if not scrollFrame then return end

    local scrollTarget = GetMOPCurrencyScrollTarget(scrollFrame)

    local fontName = option("fontname_currency") or CCS.fontname
    local fontSize = option("fontsize_currency") or 11
    local fontColor = option("fontcolor_currency") or {1, 1, 1, 1}
    local scrollWidth = scrollFrame:GetWidth() or 0
    local contentWidth = math.max(300, math.floor(scrollWidth - 8))

    local function SetCurrencyWidth(frame)
        if not frame or not frame.SetWidth then return end
        local currentWidth = frame.GetWidth and frame:GetWidth() or 0
        if math.abs(currentWidth - contentWidth) > .5 then
            frame:SetWidth(contentWidth)
        end
    end

    if scrollTarget then
        SetCurrencyWidth(scrollTarget)
    end

    local function StyleFontString(fontString)
        if not fontString or not fontString.GetFont or not fontString.SetFont then return end
        local currentFont = fontString:GetFont()
        fontString:SetFont(fontName or currentFont, fontSize, CCS.textoutline or "")
        if fontString.SetTextColor then
            fontString:SetTextColor(
                fontColor[1] or 1,
                fontColor[2] or 1,
                fontColor[3] or 1,
                fontColor[4] or 1
            )
        end
    end

    local function StyleCurrencyRow(row, forceHeader)
        if not row or not row.CreateTexture then return end

        SetCurrencyWidth(row)

        local rowName = row.GetName and row:GetName()
        local nameText = row.Name or row.name or row.Text or row.text
        local countText = row.Count or row.count
        local icon = row.Icon or row.icon or row.IconTexture
        local categoryMiddle = row.CategoryMiddle or row.categoryMiddle
            or (rowName and _G[rowName.."CategoryMiddle"])
        local isHeader = forceHeader or row.isHeader
            or (categoryMiddle and categoryMiddle.IsShown and categoryMiddle:IsShown())

        row.CCSBackground = row.CCSBackground or row:CreateTexture(nil, "BACKGROUND", nil, 2)
        row.CCSBackground:SetTexture("Interface\\Masks\\SquareMask.BLP")
        row.CCSBackground:ClearAllPoints()
        row.CCSBackground:SetAllPoints(row)
        row.CCSBackground:Show()

        if isHeader then
            row.CCSBackground:SetGradient("Vertical",
                CreateColor(.16, .16, .16, .96), CreateColor(.03, .03, .03, .96))
        else
            row.CCSBackground:SetColorTexture(.15, .15, .15, .90)
        end

        StyleFontString(nameText)
        StyleFontString(countText)

        local canAnchorIcon = icon and icon.ClearAllPoints and icon.SetPoint
        if canAnchorIcon then
            icon:ClearAllPoints()
            icon:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        end

        if countText and countText.ClearAllPoints and countText.SetPoint then
            countText:ClearAllPoints()
            if canAnchorIcon then
                countText:SetPoint("RIGHT", icon, "LEFT", -8, 0)
            else
                countText:SetPoint("RIGHT", row, "RIGHT", -12, 0)
            end
            if countText.SetJustifyH then
                countText:SetJustifyH("RIGHT")
            end
        end

        local expandIcon = row.ExpandIcon or row.expandIcon
            or (rowName and _G[rowName.."ExpandIcon"])
        local canAnchorExpand = isHeader and expandIcon
            and expandIcon.ClearAllPoints and expandIcon.SetPoint
        if canAnchorExpand then
            expandIcon:ClearAllPoints()
            expandIcon:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        end

        if nameText and nameText.ClearAllPoints and nameText.SetPoint then
            nameText:ClearAllPoints()
            nameText:SetPoint("LEFT", row, "LEFT", 12, 0)
            if canAnchorExpand then
                nameText:SetPoint("RIGHT", expandIcon, "LEFT", -8, 0)
            elseif countText then
                nameText:SetPoint("RIGHT", countText, "LEFT", -12, 0)
            else
                nameText:SetPoint("RIGHT", row, "RIGHT", -12, 0)
            end
            if nameText.SetJustifyH then
                nameText:SetJustifyH("LEFT")
            end
        end

        if isHeader then
            local categoryPieces = {}
            local function AddCategoryPiece(texture)
                if texture then
                    categoryPieces[#categoryPieces + 1] = texture
                end
            end
            AddCategoryPiece(row.CategoryLeft or row.categoryLeft)
            AddCategoryPiece(row.CategoryMiddle or row.categoryMiddle)
            AddCategoryPiece(row.CategoryRight or row.categoryRight)
            if rowName then
                AddCategoryPiece(_G[rowName.."CategoryLeft"])
                AddCategoryPiece(_G[rowName.."CategoryMiddle"])
                AddCategoryPiece(_G[rowName.."CategoryRight"])
            end
            for _, texture in ipairs(categoryPieces) do
                if texture and texture.SetAlpha and texture.Hide then
                    texture:SetAlpha(0)
                    texture:Hide()
                end
            end
        end
    end

    local function StyleCurrencyHeader(header)
        if not header or not header.Text then return end

        if not header.CCSMOPHeaderArtHidden then
            for _, region in ipairs({header:GetRegions()}) do
                if region.IsObjectType and region:IsObjectType("Texture") then
                    local width = region:GetWidth() or 0
                    local height = region:GetHeight() or 0
                    if width > 24 or height > 18 then
                        region:SetAlpha(0)
                    end
                end
            end
            header.CCSMOPHeaderArtHidden = true
        end

        header.CCSHeaderBackground = header.CCSHeaderBackground
            or header:CreateTexture(nil, "BACKGROUND", nil, 3)
        header.CCSHeaderBackground:ClearAllPoints()
        header.CCSHeaderBackground:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
        header.CCSHeaderBackground:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, 0)
        header.CCSHeaderBackground:SetHeight(22)
        header.CCSHeaderBackground:SetTexture("Interface\\Masks\\SquareMask.BLP")
        header.CCSHeaderBackground:SetGradient("Vertical",
            CreateColor(.16, .16, .16, .96), CreateColor(.03, .03, .03, .96))
    end

    local legacyButtons = scrollFrame.buttons
        or (_G.TokenFrameContainer and _G.TokenFrameContainer.buttons)
    if legacyButtons and #legacyButtons > 0 then
        for _, row in ipairs(legacyButtons) do
            StyleCurrencyRow(row)
        end
        return
    end

    local namedLegacyButtons = {}
    for i = 1, 50 do
        local row = _G["TokenFrameContainerButton"..i]
        if not row then break end
        namedLegacyButtons[#namedLegacyButtons + 1] = row
    end
    if #namedLegacyButtons > 0 then
        for _, row in ipairs(namedLegacyButtons) do
            StyleCurrencyRow(row)
        end
        return
    end

    if not scrollTarget then return end

    local containers = {scrollTarget:GetChildren()}
    for _, container in ipairs(containers) do
        SetCurrencyWidth(container)

        if container.Name or container.Count then
            StyleCurrencyRow(container)
        else
            StyleFontString(container.Text)
            StyleCurrencyHeader(container)
        end

        local rows = {container:GetChildren()}
        for _, row in ipairs(rows) do
            if row.Name or row.Count or row.Text then
                StyleCurrencyRow(row)
            end
        end
    end
end

local function RestoreMOPCurrencyLayout()
    if InCombatLockdown() then return end
    InitializeFrameUpdates()
    CurrencyFrame_Update()
end

function CCS.FixReputationBarWidth(row)
    local bar = _G[row:GetName().."ReputationBar"]
    if not bar then return end

    -- Force the bar frame to 300px
    bar:SetWidth(300)

    -- Force the left fill texture to 300px base width
    local left = _G[bar:GetName().."LeftTexture"]
    if left then
        left:SetWidth(300)
    end

    -- Hide the right texture (Blizzard’s cap)
    local right = _G[bar:GetName().."RightTexture"]
    if right then
        right:Hide()
    end
end


function CCS.HookSetup()

    if CCS.Hooked then return end
        --== Frame Hooks
    CreateExtraReputationRows(10)

    ReputationFrame:HookScript("OnHide", function() ReputationDetailFrame:Hide(); end )
    hooksecurefunc("ReputationFrame_Update", CCSReputationFrame_Update)

    ReputationFrame:HookScript("OnShow", function()
        hookfix();
        InitializeFrameUpdates();
        ScheduleMOPFrameUpdates()

        local upperTex, lowerTex = ReputationListScrollFrame:GetRegions()
        if upperTex then
            upperTex:SetTexture("Interface\\Masks\\SquareMask.BLP")
            upperTex:SetColorTexture(.1, .1, .1, 0.90)
            upperTex:ClearAllPoints()
            upperTex:SetPoint("TOPLEFT", ReputationListScrollFrame, "TOPRIGHT", 4,0)
            upperTex:SetWidth(20)
            
        end
        if lowerTex then
            lowerTex:SetTexture("Interface\\Masks\\SquareMask.BLP")
            lowerTex:SetColorTexture(.1, .1, .1, 0.90)
            lowerTex:ClearAllPoints()
            lowerTex:SetPoint("BOTTOMLEFT", ReputationListScrollFrame, "BOTTOMRIGHT", 4,0)
            lowerTex:SetPoint("TOP", upperTex, "BOTTOM")
            lowerTex:SetWidth(20)
        end

        if ReputationFrameStandingLabel then
            ReputationFrameStandingLabel:ClearAllPoints()
            ReputationFrameStandingLabel:SetPoint("TOPLEFT", ReputationFrame, "TOPLEFT", 545, -42)
        end
        
    end)

    if TokenFrame then
        TokenFrame:HookScript("OnShow", function()
            InitializeFrameUpdates()
            ScheduleMOPFrameUpdates()
            C_Timer.After(.1, RestoreMOPCurrencyLayout)
        end)

        if TokenFrame.ScrollBox then
            hooksecurefunc(TokenFrame.ScrollBox, "Update", CurrencyFrame_Update)
        elseif type(TokenFrame_Update) == "function" then
            hooksecurefunc("TokenFrame_Update", function()
                C_Timer.After(0, RestoreMOPCurrencyLayout)
                C_Timer.After(.05, RestoreMOPCurrencyLayout)
            end)
        end

        local currencyScrollFrame = GetMOPCurrencyScrollFrame()
        if currencyScrollFrame and not currencyScrollFrame.CCSMOPSizeHooked then
            currencyScrollFrame:HookScript("OnSizeChanged", function()
                if currencyScrollFrame.CCSMOPRestorePending then return end
                currencyScrollFrame.CCSMOPRestorePending = true
                C_Timer.After(0, function()
                    RestoreMOPCurrencyLayout()
                    currencyScrollFrame.CCSMOPRestorePending = false
                end)
            end)
            currencyScrollFrame.CCSMOPSizeHooked = true
        end

        if TokenFramePopup and not TokenFramePopup.CCSMOPLayoutHooked then
            TokenFramePopup:HookScript("OnShow", function()
                C_Timer.After(0, RestoreMOPCurrencyLayout)
                C_Timer.After(.05, RestoreMOPCurrencyLayout)
                C_Timer.After(.1, RestoreMOPCurrencyLayout)
            end)
            TokenFramePopup.CCSMOPLayoutHooked = true
        end
    end

    hooksecurefunc("ReputationFrame_SetRowType", function(row)
        if not row.CCS_WidthFixed then
            CCS.FixReputationBarWidth(row)
            row.CCS_WidthFixed = true
        end
    end)


    local ks = {ReputationFrame:GetChildren()}
    for _, k in ipairs(ks) do -- Individual Row
        k:SetScript("OnEnter", function() end)
        k:SetScript("OnLeave", function() end)
    end

    CharacterFrameExpandButton:HookScript("OnClick", function(self, button, down)
        hookfix()
    end)

    CharacterStatsPaneCategory1ToolbarSortDownArrow:HookScript("OnClick", function(self, button, down) hookfix() end)
    CharacterStatsPaneCategory1ToolbarSortUpArrow:HookScript("OnClick", function(self, button, down) hookfix() end)
    CharacterStatsPaneCategory2ToolbarSortDownArrow:HookScript("OnClick", function(self, button, down) hookfix() end)
    CharacterStatsPaneCategory2ToolbarSortUpArrow:HookScript("OnClick", function(self, button, down) hookfix() end)
    CharacterStatsPaneCategory3ToolbarSortDownArrow:HookScript("OnClick", function(self, button, down) hookfix() end)
    CharacterStatsPaneCategory3ToolbarSortUpArrow:HookScript("OnClick", function(self, button, down) hookfix() end)
    CharacterStatsPaneCategory4ToolbarSortDownArrow:HookScript("OnClick", function(self, button, down) hookfix() end)
    CharacterStatsPaneCategory4ToolbarSortUpArrow:HookScript("OnClick", function(self, button, down) hookfix() end)
    CharacterStatsPaneCategory5ToolbarSortDownArrow:HookScript("OnClick", function(self, button, down) hookfix() end)
    CharacterStatsPaneCategory5ToolbarSortUpArrow:HookScript("OnClick", function(self, button, down) hookfix() end)
    CharacterStatsPaneCategory6ToolbarSortDownArrow:HookScript("OnClick", function(self, button, down) hookfix() end)
    CharacterStatsPaneCategory6ToolbarSortUpArrow:HookScript("OnClick", function(self, button, down) hookfix() end)
    CharacterStatsPaneCategory7ToolbarSortDownArrow:HookScript("OnClick", function(self, button, down) hookfix() end)
    CharacterStatsPaneCategory7ToolbarSortUpArrow:HookScript("OnClick", function(self, button, down) hookfix() end)
    
   
    PaperDollFrame:HookScript("OnShow", function()
        hookfix()
        StyleMOPCharacterTabs()
        ScheduleMOPFrameUpdates()
    end)
    CharacterFrame:HookScript("OnShow", function() 
            InitializeFrameUpdates()
            ScheduleMOPFrameUpdates()
            CCS:FireEvent("CCS_EVENT_CSHOW")
            GameTooltip:Hide()
            hookfix()
            CharacterModelScene.ControlFrame:Hide()            
            if C_AddOns.IsAddOnLoaded("NDui") then
                CharacterFrameCloseButton:Hide()
            end
    end )

    CharacterFrame:HookScript("OnHide", function() GameTooltip:Hide(); end )
    CCS.Hooked = true
end

-- Module Inspect Init
function MOPinitializeinspectframe()
    if not InspectFrame or not option("show_inspect") then return end

    InspectFrame:SetScale(option("sheetscale_inspect") or 1)
    InspectFrame:SetHeight(479+(7*option("vpad_inspect"))) -- Do not allow the frame to get any smaller than the default bliz frame
    InspectFrame:SetWidth(617)
    
    local Bgoffset = 209 + (610 - 540)
    
    InspectFrameInset:ClearAllPoints();
    InspectFrameInset:SetPoint("TOPLEFT", InspectFrame, "TOPLEFT", 4, -60)
    InspectFrameInset:SetPoint("BOTTOMRIGHT", InspectFrame, "BOTTOMLEFT", 610, 0)
    InspectFrameInset:Hide();
    
    InspectTalentFrame.InspectTalents:SetPoint("BOTTOMRIGHT", InspectTalentFrame, "BOTTOMRIGHT", -12, 4)
    InspectTalentFrameTalentRow1:SetPoint("TOPLEFT", InspectTalentFrame.InspectTalents, "TOPLEFT",150, -142)

    for i, region in ipairs({ InspectTalentFrame:GetRegions() }) do
        if region:IsObjectType("Texture") and not region:GetName() then
             region:SetPoint("TOPRIGHT", InspectTalentFrame, "TOPRIGHT", -9, -130)
        end
    end
    InspectTalentFrame.InspectGlyphs:SetPoint("TOPLEFT", InspectTalentFrame.InspectTalents, "TOP",40, -142)

    InspectGuildFrameBG:SetPoint("BOTTOMRIGHT", InspectTalentFrame, "BOTTOMRIGHT", -12, 4)
    InspectGuildFrameBanner:ClearAllPoints()
    InspectGuildFrameBanner:SetPoint("TOP", InspectFrameInset, "TOP", 0,-4)
    
    InspectFrameBg:SetVertexColor(0,0,0,0);
    InspectFrameBg:ClearAllPoints()
    InspectFrameBg:SetPoint("TOPLEFT", InspectFrame, "TOPLEFT", 0, 0);
    InspectFrameBg:SetPoint("BOTTOMRIGHT", InspectFrame, "BOTTOMRIGHT", 0, 0); --275  .449

    InspectFrameTopTileStreaks:Hide()
    InspectFrameTopRightCorner:Hide()
    InspectFrameBotRightCorner:Hide()
    InspectFrameTopLeftCorner:Hide()
    InspectFrameBotLeftCorner:Hide()
    InspectFrameRightBorder:Hide()    
    InspectFrameLeftBorder:Hide()        
    InspectFrameTopBorder:Hide()        
    InspectFrameBottomBorder:Hide()        

    InspectFramePortraitFrame:Hide()            
    InspectFrame.PortraitContainer:Hide()            
	
    CCS:SkinBlizzardButton(InspectFrameCloseButton, "x", 26)
    InspectFrameCloseButton:ClearAllPoints();
    InspectFrameCloseButton:SetPoint("TOPRIGHT", InspectFrameBg, "TOPRIGHT", -10, -10)
    InspectFrameCloseButton:SetSize(32, 32)
    InspectFrameCloseButton:SetScale(.5)
    
    if InspectPVPFrame then
        InspectPVPFrame.BG:SetPoint("BOTTOMRIGHT", InspectFrameBg, "BOTTOMRIGHT", -5, 30)
    end
    
    local charbg = _G["InspectFrameBgbg"] or CreateFrame("Frame", "InspectFrameBgbg", InspectFrame)
    local charbgtex = _G["InspectFrameBgbgtex"] or charbg:CreateTexture("InspectFrameBgbgtex", "BACKGROUND", nil, 1)    
    local ccsbg = option("bgcolor_inspect")
        
    charbg:ClearAllPoints()
    charbg:SetAllPoints(InspectFrameBg)
    charbg:SetFrameStrata("BACKGROUND")
    charbgtex:ClearAllPoints()
    charbgtex:SetAllPoints()
    charbgtex:SetTexture("Interface\\Masks\\SquareMask.BLP")
    charbgtex:SetVertexColor(ccsbg[1], ccsbg[2], ccsbg[3], ccsbg[4]);
    
    InspectNameFrame:ClearAllPoints()
    InspectNameFrame:SetPoint("TOP", InspectFrame, "TOP", 0, -4)
    
    InspectFrameTitleBg:Hide()
    InspectFrameTitleText:ClearAllPoints();
    InspectFrameTitleText:SetPoint("TOP", InspectFrame, "TOP", 0, 0)
    InspectFrameTitleText:SetPoint("LEFT", InspectFrame, "LEFT", 50, 0)
    InspectFrameTitleText:SetPoint("RIGHT", InspectFrameInset, "RIGHT", -40, 0)
    
    InspectFrameTitleText:SetFont(option("fontname_nametitle_inspect") or CCS.fontname, option("fontsize_nametitle_inspect") or 12, "OUTLINE")
    InspectFrameTitleText:SetTextColor(
        option("fontcolor_nametitle_inspect")[1] or 1,
        option("fontcolor_nametitle_inspect")[2] or 1,
        option("fontcolor_nametitle_inspect")[3] or 1,
        option("fontcolor_nametitle_inspect")[4] or 1
    )

    
    InspectLevelText:ClearAllPoints()
    InspectLevelText:SetPoint("TOP", InspectNameFrame, "BOTTOM", 0, -5)
    
    InspectLevelText:SetFont(option("fontname_levelclass_inspect") or CCS.fontname, option("fontsize_levelclass_inspect") or 11, "OUTLINE")
    
    InspectFrame.NineSlice:ClearAllPoints()
    InspectFrame.NineSlice:SetPoint("TOPLEFT", InspectFrame, "TOPLEFT", 0, 0)
    InspectFrame.NineSlice:SetPoint("BOTTOMRIGHT", InspectFrame, "BOTTOMLEFT", 579, 0)
    InspectFrame.NineSlice:Hide()
    InspectFramePortrait:Hide()
        
    InspectModelFrameBorderBottom:Hide()
    InspectModelFrameBorderBottomLeft:Hide()
    InspectModelFrameBorderBottomRight:Hide()
    InspectModelFrameBorderLeft:Hide()
    InspectModelFrameBorderRight:Hide()
    InspectModelFrameBorderTop:Hide()
    InspectModelFrameBorderTopLeft:Hide()
    InspectModelFrameBorderTopRight:Hide()

    InspectBackSlotFrame:Hide()
    InspectChestSlotFrame:Hide()
    InspectFeetSlotFrame:Hide()
    InspectFinger0SlotFrame:Hide()
    InspectFinger1SlotFrame:Hide()
    InspectHandsSlotFrame:Hide()
    InspectHeadSlotFrame:Hide()
    InspectLegsSlotFrame:Hide()
    InspectMainHandSlotFrame:Hide()
    InspectNeckSlotFrame:Hide()
    InspectSecondaryHandSlotFrame:Hide()
    InspectShirtSlotFrame:Hide()
    InspectShoulderSlotFrame:Hide()
    InspectTabardSlotFrame:Hide()
    InspectTrinket0SlotFrame:Hide()
    InspectTrinket1SlotFrame:Hide()
    InspectWaistSlotFrame:Hide()
    InspectWristSlotFrame:Hide()
    -- All slots on the left (under head) are tied back to this slot
    InspectHeadSlot:ClearAllPoints()
    InspectHeadSlot:SetPoint("TOPLEFT", InspectFrameBg, "TOPLEFT", 30, -60)
    -- Now we change the spacing of the slots on the left
    InspectNeckSlot:ClearAllPoints()
    InspectNeckSlot:SetPoint("TOPLEFT", InspectHeadSlot, "BOTTOMLEFT", 0, -option("vpad_inspect"))
    InspectShoulderSlot:ClearAllPoints()
    InspectShoulderSlot:SetPoint("TOPLEFT", InspectNeckSlot, "BOTTOMLEFT", 0, -option("vpad_inspect"))
    InspectBackSlot:ClearAllPoints()
    InspectBackSlot:SetPoint("TOPLEFT", InspectShoulderSlot, "BOTTOMLEFT", 0, -option("vpad_inspect"))
    InspectChestSlot:ClearAllPoints()
    InspectChestSlot:SetPoint("TOPLEFT", InspectBackSlot, "BOTTOMLEFT", 0, -option("vpad_inspect"))
    InspectShirtSlot:ClearAllPoints()
    InspectShirtSlot:SetPoint("TOPLEFT", InspectChestSlot, "BOTTOMLEFT", 0, -option("vpad_inspect"))
    InspectTabardSlot:ClearAllPoints()
    InspectTabardSlot:SetPoint("TOPLEFT", InspectShirtSlot, "BOTTOMLEFT", 0, -option("vpad_inspect"))
    InspectWristSlot:ClearAllPoints()
    InspectWristSlot:SetPoint("TOPLEFT", InspectTabardSlot, "BOTTOMLEFT", 0, -option("vpad_inspect"))
    
    -- All slots on the right (under hands) are tied back to this slot
    InspectHandsSlot:ClearAllPoints()
    InspectHandsSlot:SetPoint("TOPLEFT", InspectFrameBg, "TOPLEFT", 545, -60)
    -- Now we change the spacing of the slots on the right
    InspectWaistSlot:ClearAllPoints()
    InspectWaistSlot:SetPoint("TOPLEFT", InspectHandsSlot, "BOTTOMLEFT", 0, -option("vpad_inspect"))
    InspectLegsSlot:ClearAllPoints()
    InspectLegsSlot:SetPoint("TOPLEFT", InspectWaistSlot, "BOTTOMLEFT", 0, -option("vpad_inspect"))
    InspectFeetSlot:ClearAllPoints()
    InspectFeetSlot:SetPoint("TOPLEFT", InspectLegsSlot, "BOTTOMLEFT", 0, -option("vpad_inspect"))
    InspectFinger0Slot:ClearAllPoints()
    InspectFinger0Slot:SetPoint("TOPLEFT", InspectFeetSlot, "BOTTOMLEFT", 0, -option("vpad_inspect"))
    InspectFinger1Slot:ClearAllPoints()
    InspectFinger1Slot:SetPoint("TOPLEFT", InspectFinger0Slot, "BOTTOMLEFT", 0, -option("vpad_inspect"))
    InspectTrinket0Slot:ClearAllPoints()
    InspectTrinket0Slot:SetPoint("TOPLEFT", InspectFinger1Slot, "BOTTOMLEFT", 0, -option("vpad_inspect"))
    InspectTrinket1Slot:ClearAllPoints()
    InspectTrinket1Slot:SetPoint("TOPLEFT", InspectTrinket0Slot, "BOTTOMLEFT", 0, -option("vpad_inspect"))
    
    InspectMainHandSlot:ClearAllPoints()
    InspectMainHandSlot:SetPoint("BOTTOMLEFT", InspectFrameBg, "BOTTOMLEFT", 235, 60)
    InspectSecondaryHandSlot:ClearAllPoints()
    InspectSecondaryHandSlot:SetPoint("TOPLEFT", InspectMainHandSlot, "TOPRIGHT", 60, 0)
    local mh_region = select(13, InspectMainHandSlot:GetRegions())
    if mh_region and mh_region.GetObjectType and mh_region:GetObjectType() == "Texture" then
        mh_region:Hide()
    end    
    local oh_region = select(13, InspectSecondaryHandSlot:GetRegions())
    if oh_region and oh_region.GetObjectType and oh_region:GetObjectType() == "Texture" then
        oh_region:Hide()
    end    
    
    local Height = 359+(7*option("vpad_inspect"))  -- Hard code it for now
    InspectModelFrame:ClearAllPoints();
    InspectModelFrame:SetHeight(Height)
    InspectModelFrame:SetWidth(Height/CCS.ModelAspect)
    InspectModelFrame:SetPoint("CENTER", InspectFrameBg, "CENTER", 0, 0);
    InspectModelFrame:SetFrameLevel(2)
    InspectModelFrame:Show();
    InspectModelFrameBackgroundTopLeft:Hide();
    InspectModelFrameBackgroundBotLeft:Hide();
    InspectModelFrameBackgroundTopRight:Hide();
    InspectModelFrameBackgroundBotRight:Hide();
    
    InspectModelFrameBackgroundOverlay:ClearAllPoints()
    InspectModelFrameBackgroundOverlay:SetPoint("TOPLEFT", InspectModelFrameBackgroundTopLeft, "TOPLEFT", 0, 0)
    InspectModelFrameBackgroundOverlay:SetPoint("BOTTOMRIGHT", InspectModelFrameBackgroundBotRight, "BOTTOMRIGHT", 0, 70)
    InspectModelFrameBackgroundOverlay:Hide()

    inspectmodbg:ClearAllPoints()
    if inspectmodbg:GetParent() == nil then
        inspectmodbg:SetParent(InspectModelFrame)
    end
    inspectmodbg:SetPoint("TOPLEFT", InspectHeadSlot, "TOPLEFT", 0, 0)
    inspectmodbg:SetPoint("RIGHT", InspectHandsSlot, "RIGHT", 0, 0)    
    inspectmodbg:SetPoint("BOTTOM", InspectMainHandSlot, "BOTTOM", 0, 0)        
    inspectmodbg:SetFrameStrata("BACKGROUND")
    inspectmodbg:SetFrameLevel(100)
    CCS.ChangeModelBg(true)
end

function module:SetupBlizzardFrameOverrides()
	--------------------------------
	-- Only process these events once
	--------------------------------
    CharacterFrameInset.Bg:ClearAllPoints();
    CharacterFrameInset.Bg:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 4, -60)
    CharacterFrameInset:Hide();
    
    CharacterFrameBg:SetVertexColor(0,0,0,0);
    CharacterFrameBg:ClearAllPoints()
    CharacterFrameBg:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 0, 0);
   
    CharacterFrame.TopTileStreaks:Hide()

    local charbg = _G["CharacterFrameBgbg"] or CreateFrame("Frame", "CharacterFrameBgbg", CharacterFrame)
    local charbgtex = _G["CharacterFrameBgbgtex"] or charbg:CreateTexture("CharacterFrameBgbgtex", "BACKGROUND", nil, 1)    

    GearManagerPopupFrame:SetFrameStrata("DIALOG")
    GearManagerPopupFrame.IconSelector:SetFrameStrata("FULLSCREEN")

    charbg:ClearAllPoints()
    charbg:SetAllPoints(CharacterFrameBg)
    charbg:SetFrameStrata("BACKGROUND")
    charbgtex:ClearAllPoints()
    charbgtex:SetAllPoints()
    charbgtex:SetTexture("Interface\\Masks\\SquareMask.BLP")

    local CCSsetbtn = _G["CCSsetbtn"] or CreateFrame("Button", "CCSsetbtn", CharacterFrame)
    CCSsetbtn:SetSize(32, 32)
    CCSsetbtn:SetPoint("TOPRIGHT", CharacterFrameCloseButton, "TOPLEFT", -5, 0)
    CCSsetbtn:SetScale(.5)
    CCSsetbtn:Show()

    local optionsFrame = _G["CCS_Options"]
    CCSsetbtn:SetScript("OnClick", function()
        if InCombatLockdown() then
            PlaySound(8959)
            RaidNotice_AddMessage(RaidBossEmoteFrame, format("CCS %s", ERR_AFFECTING_COMBAT), ChatTypeInfo["SYSTEM"])
            return
        end
        if optionsFrame then
            if optionsFrame:IsShown() then
                optionsFrame:Hide()
            else
                optionsFrame:Show()
                optionsFrame:SetPropagateKeyboardInput(true)
            end
        end
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
    end)

    CharacterFrameTitleText:ClearAllPoints();
    CharacterFrameTitleText:SetPoint("TOP", CharacterFrame, "TOP", 0, -5)
    CharacterFrameTitleText:SetPoint("LEFT", CharacterFrame, "LEFT", 50, 0)
    CharacterFrameTitleText:SetPoint("RIGHT", CharacterFrameInset.Bg, "RIGHT", -40, 0)

    CharacterLevelText:ClearAllPoints()
    CharacterLevelText:SetPoint("TOP", CharacterFrameTitleText, "BOTTOM", 0, 0)
    
    CharacterFrame.NineSlice:Hide()
    CharacterFramePortrait:Hide()
    
    CharacterFrameExpandButton:Hide()
    CharacterFrameBotLeftCorner:Hide()
    CharacterFrameBotRightCorner:Hide()
    CharacterFrameBottomBorder:Hide()
    CharacterFrameLeftBorder:Hide()
    CharacterFrameRightBorder:Hide()    
    CharacterFrameTopBorder:Hide()        
    CharacterFrameTopLeftCorner:Hide()        
    CharacterFrameTopRightCorner:Hide()            
    CharacterFrameTopTileStreaks:Hide()                
    CharacterFramePortraitFrame:Hide()        
    CharacterFrameTitleBg:Hide()
    
    CharacterFrameInsetRight.Bg:Hide();
    CharacterFrameInsetRight:ClearAllPoints();
    CharacterFrameInsetRight:SetPoint("TOPLEFT", CharacterFrameInset.Bg, "TOPRIGHT", 4, 0)
    CharacterFrameInsetRight:SetPoint("BOTTOMRIGHT", CharacterFrameInset.Bg, "BOTTOMRIGHT", 250, 0)
    CharacterStatsPane.ClassBackground:Hide()
    
    PaperDollFrame:UnregisterAllEvents()
    PaperDollInnerBorderBottom:Hide()
    PaperDollInnerBorderBottom2:Hide()
    PaperDollInnerBorderBottomLeft:Hide()
    PaperDollInnerBorderBottomRight:Hide()
    PaperDollInnerBorderLeft:Hide()
    PaperDollInnerBorderRight:Hide()
    PaperDollInnerBorderTop:Hide()
    PaperDollInnerBorderTopLeft:Hide()
    PaperDollInnerBorderTopRight:Hide()
    CharacterFrameInsetRight.NineSlice:Hide()
    
    CharacterBackSlotFrame:Hide()
    CharacterChestSlotFrame:Hide()
    CharacterFeetSlotFrame:Hide()
    CharacterFinger0SlotFrame:Hide()
    CharacterFinger1SlotFrame:Hide()
    CharacterHandsSlotFrame:Hide()
    CharacterHeadSlotFrame:Hide()
    CharacterLegsSlotFrame:Hide()
    CharacterMainHandSlotFrame:Hide()
    CharacterNeckSlotFrame:Hide()
    CharacterSecondaryHandSlotFrame:Hide()
    CharacterShirtSlotFrame:Hide()
    CharacterShoulderSlotFrame:Hide()
    CharacterTabardSlotFrame:Hide()
    CharacterTrinket0SlotFrame:Hide()
    CharacterTrinket1SlotFrame:Hide()
    CharacterWaistSlotFrame:Hide()
    CharacterWristSlotFrame:Hide()

    if CharacterSecondaryHandSlot.BottomRightSlotTexture then
        CharacterSecondaryHandSlot.BottomRightSlotTexture:Hide()
    end
    local mh_region = select(14, CharacterMainHandSlot:GetRegions())
    if mh_region and mh_region.GetObjectType and mh_region:GetObjectType() == "Texture" then
        mh_region:Hide()
    end

    -- Create the character model button
    modelbtn:SetSize(23, 23)
    modelbtn:SetPoint("BOTTOMLEFT", PaperDollItemsFrame, "BOTTOMLEFT", 60, 7)
    modelbtn:SetFrameStrata("HIGH")
    modelbtnfont1:SetFont(option("fontname_showchar") or CCS.fontname, (option("fontsize_showchar") or 10), CCS.textoutline)
    modelbtnfont1:SetPoint("BOTTOM", modelbtn, "TOP", -3 , 2)
    modelbtnfont1:SetText(MOUNT_JOURNAL_PLAYER)
    modelbtnfont1:SetWordWrap(true)
    modelbtn:SetNormalTexture("Interface\\Calendar\\MeetingIcon.blp")
    modelbtn:SetScript("OnEnter", function() GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
            GameTooltip:AddDoubleLine("", nil, 1, 1, 1, 1, 1, 1) 
            GameTooltip:Show()
    end)
    modelbtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    modelbtn:SetScript("OnClick", function()
            if not InCombatLockdown() then 
                Clicky() 
            else
                PlaySound(8959)
                RaidNotice_AddMessage(RaidBossEmoteFrame, format("%s", ERR_AFFECTING_COMBAT), ChatTypeInfo["SYSTEM"])
            end 
    end)

    modbg:ClearAllPoints()
    modbg:SetPoint("TOPLEFT", CharacterHeadSlot, "TOPLEFT", 0, 0)
    modbg:SetPoint("RIGHT", CharacterHandsSlot, "RIGHT", 0, 0)    
    modbg:SetPoint("BOTTOM", CharacterMainHandSlot, "BOTTOM", 0, 0)        
    modbg:SetFrameStrata("LOW")
    modbg:SetFrameLevel(5000)

    local Height = 520  -- Hard code it for now
    local Left = 120  -- Hard code it for now

    CharacterModelScene:ClearAllPoints();
    CharacterModelScene:SetHeight(Height)
    CharacterModelScene:SetWidth(Height/CCS.ModelAspect)
    CharacterModelScene:SetPoint("LEFT", CharacterFrameBg, "LEFT", Left, -20);
    CharacterModelScene:SetFrameLevel(2)
    CharacterModelScene:Show();
    CharacterModelFrameBackgroundTopLeft:Hide();
    CharacterModelFrameBackgroundBotLeft:Hide();
    CharacterModelFrameBackgroundTopRight:Hide();
    CharacterModelFrameBackgroundBotRight:Hide();
    CharacterModelFrameBackgroundOverlay:ClearAllPoints()
    CharacterModelFrameBackgroundOverlay:SetPoint("TOPLEFT", CharacterModelFrameBackgroundTopLeft, "TOPLEFT", 0, 0)
    CharacterModelFrameBackgroundOverlay:SetPoint("BOTTOMRIGHT", CharacterModelFrameBackgroundBotRight, "BOTTOMRIGHT", 0, 70)
    CharacterModelFrameBackgroundOverlay:Hide()

    InitializeFrameUpdates()

end

function module:UpdateStyle()
    local charbg = _G["CharacterFrameBgbg"] or CreateFrame("Frame", "CharacterFrameBgbg", CharacterFrame)
    local charbgtex = _G["CharacterFrameBgbgtex"] or charbg:CreateTexture("CharacterFrameBgbgtex", "BACKGROUND", nil, 1)    
    local bgr, bgg, bgb, bgalpha = option("bgcolor")[1], option("bgcolor")[2], option("bgcolor")[3], option("bgcolor")[4];

    charbgtex:SetVertexColor(bgr,bgg,bgb,bgalpha);

    CCS:SkinBlizzardButton(CharacterFrameCloseButton, "x", 26)
    CCS:ApplyIconStyle(CCSsetbtn, "gear", 32)    
   
    CharacterFrameTitleText:SetFont( option("fontname_nametitle") or CCS.fontname, (option("fontsize_nametitle") or 12) , CCS.textoutline)
    CharacterFrameTitleText:SetTextColor(
        option("fontcolor_nametitle")[1] or 1,
        option("fontcolor_nametitle")[2] or 1,
        option("fontcolor_nametitle")[3] or 1,
        option("fontcolor_nametitle")[4] or 1
    )
    CharacterLevelText:SetFont(option("fontname_levelclass") or CCS.fontname, (option("fontsize_levelclass") or 12) , CCS.textoutline)
    
    modelbtnfont1:SetFont(option("fontname_showchar") or CCS.fontname, (option("fontsize_showchar") or 10), "OUTLINE")
    modelbtnfont1:SetTextColor(
        option("fontcolor_showchar")[1] or 1,
        option("fontcolor_showchar")[2] or 1,
        option("fontcolor_showchar")[3] or 1,
        option("fontcolor_showchar")[4] or 1
    )

    if option("hidemodelbg") then modbg:Hide() else modbg:Show() end

    StyleMOPCharacterTabs()

end

function module:ApplyDynamicLayout()
    local scaling = option("sheetscale") or 1
    local Bgoffset = option("hpad")
	--------------------------------
	-- Only process hpad/vpad
	--------------------------------
	if CCS.lastChangedOption == nil or CCS.lastChangedOption == "vpad" or CCS.lastChangedOption == "hpad" then
        CharacterFrame:SetHeight(479+(7*option("vpad"))) -- Do not allow the frame to get any smaller than the default bliz frame
        
        CharacterFrameCloseButton:ClearAllPoints();
        CharacterFrameCloseButton:SetPoint("TOPRIGHT", CharacterFrameBg, "TOPRIGHT", -10, -10)
        CharacterFrameCloseButton:SetSize(32, 32)
        CharacterFrameCloseButton:SetScale(.5)
        
        CharacterFrameInset.Bg:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMLEFT", 330+option("hpad"), 30)
        CharacterFrameBg:SetPoint("BOTTOMRIGHT", CharacterFrame, "BOTTOMRIGHT", Bgoffset+65, 0); --279  .449
        
		---------------
		-- All slots on the left (under head) are tied back to this slot
		---------------
        CharacterHeadSlot:ClearAllPoints()
        CharacterHeadSlot:SetPoint("TOPLEFT", CharacterFrameBg, "TOPLEFT", 30, -60)
        CharacterNeckSlot:ClearAllPoints()
        CharacterNeckSlot:SetPoint("TOPLEFT", CharacterHeadSlot, "BOTTOMLEFT", 0, -option("vpad"))
        CharacterShoulderSlot:ClearAllPoints()
        CharacterShoulderSlot:SetPoint("TOPLEFT", CharacterNeckSlot, "BOTTOMLEFT", 0, -option("vpad"))
        CharacterBackSlot:ClearAllPoints()
        CharacterBackSlot:SetPoint("TOPLEFT", CharacterShoulderSlot, "BOTTOMLEFT", 0, -option("vpad"))
        CharacterChestSlot:ClearAllPoints()
        CharacterChestSlot:SetPoint("TOPLEFT", CharacterBackSlot, "BOTTOMLEFT", 0, -option("vpad"))
        CharacterShirtSlot:ClearAllPoints()
        CharacterShirtSlot:SetPoint("TOPLEFT", CharacterChestSlot, "BOTTOMLEFT", 0, -option("vpad"))
        CharacterTabardSlot:ClearAllPoints()
        CharacterTabardSlot:SetPoint("TOPLEFT", CharacterShirtSlot, "BOTTOMLEFT", 0, -option("vpad"))
        CharacterWristSlot:ClearAllPoints()
        CharacterWristSlot:SetPoint("TOPLEFT", CharacterTabardSlot, "BOTTOMLEFT", 0, -option("vpad"))
        -- All slots on the right (under hands) are tied back to this slot
        CharacterHandsSlot:ClearAllPoints()
        CharacterHandsSlot:SetPoint("TOPLEFT", CharacterFrameBg, "TOPLEFT", 283 + option("hpad"), -60)
        CharacterWaistSlot:ClearAllPoints()
        CharacterWaistSlot:SetPoint("TOPLEFT", CharacterHandsSlot, "BOTTOMLEFT", 0, -option("vpad"))
        CharacterLegsSlot:ClearAllPoints()
        CharacterLegsSlot:SetPoint("TOPLEFT", CharacterWaistSlot, "BOTTOMLEFT", 0, -option("vpad"))
        CharacterFeetSlot:ClearAllPoints()
        CharacterFeetSlot:SetPoint("TOPLEFT", CharacterLegsSlot, "BOTTOMLEFT", 0, -option("vpad"))
        CharacterFinger0Slot:ClearAllPoints()
        CharacterFinger0Slot:SetPoint("TOPLEFT", CharacterFeetSlot, "BOTTOMLEFT", 0, -option("vpad"))
        CharacterFinger1Slot:ClearAllPoints()
        CharacterFinger1Slot:SetPoint("TOPLEFT", CharacterFinger0Slot, "BOTTOMLEFT", 0, -option("vpad"))
        CharacterTrinket0Slot:ClearAllPoints()
        CharacterTrinket0Slot:SetPoint("TOPLEFT", CharacterFinger1Slot, "BOTTOMLEFT", 0, -option("vpad"))
        CharacterTrinket1Slot:ClearAllPoints()
        CharacterTrinket1Slot:SetPoint("TOPLEFT", CharacterTrinket0Slot, "BOTTOMLEFT", 0, -option("vpad"))
        CharacterMainHandSlot:ClearAllPoints()
        CharacterMainHandSlot:SetPoint("BOTTOMLEFT", CharacterFrameBg, "BOTTOMLEFT", 146 + 89*option("hpad")/262, 60)
        CharacterSecondaryHandSlot:ClearAllPoints()
        CharacterSecondaryHandSlot:SetPoint("TOPLEFT", CharacterMainHandSlot, "TOPRIGHT", 60*option("hpad")/262, 0)
    
    end

	--------------------------------
	-- Only process character sheet scale
	--------------------------------
    if CCS.lastChangedOption == nil or CCS.lastChangedOption == "sheetscale" then
		if scaling ~= 1 or (scaling == 1 and CharacterFrame:GetScale() ~= 1) then
			CharacterFrame:SetScale(scaling); 
		end
	end    

    if option("hideshowchbtn") == true then modelbtn:Hide() else modelbtn:Show() end

	--------------------------------
	-- Only process hide icon borders
	--------------------------------
    if CCS.lastChangedOption == nil or CCS.lastChangedOption == "hideiconborders" then
        if (option("hideiconborders")) then
            CharacterBackSlot.IconBorder:SetTexCoord(.8,.8,.8,.8,.8,.8,.8,.8)
            CharacterChestSlot.IconBorder:SetTexCoord(.8,.8,.8,.8,.8,.8,.8,.8)
            CharacterFeetSlot.IconBorder:SetTexCoord(.8,.8,.8,.8,.8,.8,.8,.8)
            CharacterFinger0Slot.IconBorder:SetTexCoord(.8,.8,.8,.8,.8,.8,.8,.8)
            CharacterFinger1Slot.IconBorder:SetTexCoord(.8,.8,.8,.8,.8,.8,.8,.8)
            CharacterHandsSlot.IconBorder:SetTexCoord(.8,.8,.8,.8,.8,.8,.8,.8)
            CharacterHeadSlot.IconBorder:SetTexCoord(.8,.8,.8,.8,.8,.8,.8,.8)
            CharacterLegsSlot.IconBorder:SetTexCoord(.8,.8,.8,.8,.8,.8,.8,.8)
            CharacterMainHandSlot.IconBorder:SetTexCoord(.8,.8,.8,.8,.8,.8,.8,.8)
            CharacterNeckSlot.IconBorder:SetTexCoord(.8,.8,.8,.8,.8,.8,.8,.8)
            CharacterSecondaryHandSlot.IconBorder:SetTexCoord(.8,.8,.8,.8,.8,.8,.8,.8)
            CharacterShirtSlot.IconBorder:SetTexCoord(.8,.8,.8,.8,.8,.8,.8,.8)
            CharacterShoulderSlot.IconBorder:SetTexCoord(.8,.8,.8,.8,.8,.8,.8,.8)
            CharacterTabardSlot.IconBorder:SetTexCoord(.8,.8,.8,.8,.8,.8,.8,.8)
            CharacterTrinket0Slot.IconBorder:SetTexCoord(.8,.8,.8,.8,.8,.8,.8,.8)
            CharacterTrinket1Slot.IconBorder:SetTexCoord(.8,.8,.8,.8,.8,.8,.8,.8)
            CharacterWaistSlot.IconBorder:SetTexCoord(.8,.8,.8,.8,.8,.8,.8,.8)
            CharacterWristSlot.IconBorder:SetTexCoord(.8,.8,.8,.8,.8,.8,.8,.8)
            
            CharacterBackSlotIconTexture:SetTexCoord(.07,.07,.07,.93,.93,.07,.93,.93)
            CharacterChestSlotIconTexture:SetTexCoord(.07,.07,.07,.93,.93,.07,.93,.93)
            CharacterFeetSlotIconTexture:SetTexCoord(.07,.07,.07,.93,.93,.07,.93,.93)
            CharacterFinger0SlotIconTexture:SetTexCoord(.07,.07,.07,.93,.93,.07,.93,.93)
            CharacterFinger1SlotIconTexture:SetTexCoord(.07,.07,.07,.93,.93,.07,.93,.93)
            CharacterHandsSlotIconTexture:SetTexCoord(.07,.07,.07,.93,.93,.07,.93,.93)
            CharacterHeadSlotIconTexture:SetTexCoord(.07,.07,.07,.93,.93,.07,.93,.93)
            CharacterLegsSlotIconTexture:SetTexCoord(.07,.07,.07,.93,.93,.07,.93,.93)
            CharacterMainHandSlotIconTexture:SetTexCoord(.07,.07,.07,.93,.93,.07,.93,.93)
            CharacterNeckSlotIconTexture:SetTexCoord(.07,.07,.07,.93,.93,.07,.93,.93)
            CharacterSecondaryHandSlotIconTexture:SetTexCoord(.07,.07,.07,.93,.93,.07,.93,.93)
            CharacterShirtSlotIconTexture:SetTexCoord(.07,.07,.07,.93,.93,.07,.93,.93)
            CharacterShoulderSlotIconTexture:SetTexCoord(.07,.07,.07,.93,.93,.07,.93,.93)
            CharacterTabardSlotIconTexture:SetTexCoord(.07,.07,.07,.93,.93,.07,.93,.93)
            CharacterTrinket0SlotIconTexture:SetTexCoord(.07,.07,.07,.93,.93,.07,.93,.93)
            CharacterTrinket1SlotIconTexture:SetTexCoord(.07,.07,.07,.93,.93,.07,.93,.93)
            CharacterWaistSlotIconTexture:SetTexCoord(.07,.07,.07,.93,.93,.07,.93,.93)
            CharacterWristSlotIconTexture:SetTexCoord(.07,.07,.07,.93,.93,.07,.93,.93)
            
            CharacterBackSlotNormalTexture:Hide()
            CharacterChestSlotNormalTexture:Hide()
            CharacterFeetSlotNormalTexture:Hide()
            CharacterFinger0SlotNormalTexture:Hide()
            CharacterFinger1SlotNormalTexture:Hide()
            CharacterHandsSlotNormalTexture:Hide()
            CharacterHeadSlotNormalTexture:Hide()
            CharacterLegsSlotNormalTexture:Hide()
            CharacterMainHandSlotNormalTexture:Hide()
            CharacterNeckSlotNormalTexture:Hide()
            CharacterSecondaryHandSlotNormalTexture:Hide()
            CharacterShirtSlotNormalTexture:Hide()
            CharacterShoulderSlotNormalTexture:Hide()
            CharacterTabardSlotNormalTexture:Hide()
            CharacterTrinket0SlotNormalTexture:Hide()
            CharacterTrinket1SlotNormalTexture:Hide()
            CharacterWaistSlotNormalTexture:Hide()
            CharacterWristSlotNormalTexture:Hide()
            
        else
            CharacterBackSlot.IconBorder:SetTexCoord(1,1,1,1,1,1,1,1)
            CharacterChestSlot.IconBorder:SetTexCoord(1,1,1,1,1,1,1,1)
            CharacterFeetSlot.IconBorder:SetTexCoord(1,1,1,1,1,1,1,1)
            CharacterFinger0Slot.IconBorder:SetTexCoord(1,1,1,1,1,1,1,1)
            CharacterFinger1Slot.IconBorder:SetTexCoord(1,1,1,1,1,1,1,1)
            CharacterHandsSlot.IconBorder:SetTexCoord(1,1,1,1,1,1,1,1)
            CharacterHeadSlot.IconBorder:SetTexCoord(1,1,1,1,1,1,1,1)
            CharacterLegsSlot.IconBorder:SetTexCoord(1,1,1,1,1,1,1,1)
            CharacterMainHandSlot.IconBorder:SetTexCoord(1,1,1,1,1,1,1,1)
            CharacterNeckSlot.IconBorder:SetTexCoord(1,1,1,1,1,1,1,1)
            CharacterSecondaryHandSlot.IconBorder:SetTexCoord(1,1,1,1,1,1,1,1)
            CharacterShirtSlot.IconBorder:SetTexCoord(1,1,1,1,1,1,1,1)
            CharacterShoulderSlot.IconBorder:SetTexCoord(1,1,1,1,1,1,1,1)
            CharacterTabardSlot.IconBorder:SetTexCoord(1,1,1,1,1,1,1,1)
            CharacterTrinket0Slot.IconBorder:SetTexCoord(1,1,1,1,1,1,1,1)
            CharacterTrinket1Slot.IconBorder:SetTexCoord(1,1,1,1,1,1,1,1)
            CharacterWaistSlot.IconBorder:SetTexCoord(1,1,1,1,1,1,1,1)
            CharacterWristSlot.IconBorder:SetTexCoord(1,1,1,1,1,1,1,1)
            
            CharacterBackSlotIconTexture:SetTexCoord(0,0,0,1,1,0,1,1)
            CharacterChestSlotIconTexture:SetTexCoord(0,0,0,1,1,0,1,1)
            CharacterFeetSlotIconTexture:SetTexCoord(0,0,0,1,1,0,1,1)
            CharacterFinger0SlotIconTexture:SetTexCoord(0,0,0,1,1,0,1,1)
            CharacterFinger1SlotIconTexture:SetTexCoord(0,0,0,1,1,0,1,1)
            CharacterHandsSlotIconTexture:SetTexCoord(0,0,0,1,1,0,1,1)
            CharacterHeadSlotIconTexture:SetTexCoord(0,0,0,1,1,0,1,1)
            CharacterLegsSlotIconTexture:SetTexCoord(0,0,0,1,1,0,1,1)
            CharacterMainHandSlotIconTexture:SetTexCoord(0,0,0,1,1,0,1,1)
            CharacterNeckSlotIconTexture:SetTexCoord(0,0,0,1,1,0,1,1)
            CharacterSecondaryHandSlotIconTexture:SetTexCoord(0,0,0,1,1,0,1,1)
            CharacterShirtSlotIconTexture:SetTexCoord(0,0,0,1,1,0,1,1)
            CharacterShoulderSlotIconTexture:SetTexCoord(0,0,0,1,1,0,1,1)
            CharacterTabardSlotIconTexture:SetTexCoord(0,0,0,1,1,0,1,1)
            CharacterTrinket0SlotIconTexture:SetTexCoord(0,0,0,1,1,0,1,1)
            CharacterTrinket1SlotIconTexture:SetTexCoord(0,0,0,1,1,0,1,1)
            CharacterWaistSlotIconTexture:SetTexCoord(0,0,0,1,1,0,1,1)
            CharacterWristSlotIconTexture:SetTexCoord(0,0,0,1,1,0,1,1)
            
            CharacterBackSlotNormalTexture:Show()
            CharacterChestSlotNormalTexture:Show()
            CharacterFeetSlotNormalTexture:Show()
            CharacterFinger0SlotNormalTexture:Show()
            CharacterFinger1SlotNormalTexture:Show()
            CharacterHandsSlotNormalTexture:Show()
            CharacterHeadSlotNormalTexture:Show()
            CharacterLegsSlotNormalTexture:Show()
            CharacterMainHandSlotNormalTexture:Show()
            CharacterNeckSlotNormalTexture:Show()
            CharacterSecondaryHandSlotNormalTexture:Show()
            CharacterShirtSlotNormalTexture:Show()
            CharacterShoulderSlotNormalTexture:Show()
            CharacterTabardSlotNormalTexture:Show()
            CharacterTrinket0SlotNormalTexture:Show()
            CharacterTrinket1SlotNormalTexture:Show()
            CharacterWaistSlotNormalTexture:Show()
            CharacterWristSlotNormalTexture:Show()
              
        end
    
    end

end

-- Module Initialization
function module:Initialize(onlyStyle)
    -- Set up the character sheet for the current player

    if onlyStyle and self.BlizzardCleanup then
        self:ApplyDynamicLayout()
        self:UpdateStyle()
        ScheduleMOPFrameUpdates()
        C_Timer.After(.1, CurrencyFrame_Update)
        if InspectFrame ~= nil and InspectFrame.unit ~= nil and InspectFrame:IsVisible() == true then
            MOPinitializeinspectframe()
        end
        return
    end

    ----------------------------------
    -- Bliz cleanup, Layout setup, & Styles
    ----------------------------------
    if not self.BlizzardCleanup then
        self:SetupBlizzardFrameOverrides()
        CCS.HookSetup()
        self.BlizzardCleanup = true
    end

    if not self.LayoutSetup then
        self:ApplyDynamicLayout()
        self.LayoutSetup = true
    end

    if not self.StyleSetup then
        self:UpdateStyle()
        self.StyleSetup = true
    end

    ScheduleMOPFrameUpdates()
    C_Timer.After(.1, CurrencyFrame_Update)
    
end
-- Show the Paragon Toast if a Paragon Reward Quest is accepted.
local function ShowToast(name, text)
    local toast = _G["CCS_TOAST"]

    PlaySound(44295, "master", true)

    -- Reset frame state
    toast:Hide()
    toast:SetAlpha(0)
    toast.title:SetAlpha(0)
    toast.description:SetAlpha(0)

    toast:EnableMouse(false)
    toast.title:SetText(name)
    toast.description:SetText(text)

    -- Animate toast and text
    C_Timer.After(1, function() UIFrameFadeIn(toast, .5, 0, 1) end)
    C_Timer.After(2, function() UIFrameFadeIn(toast.title, .5, 0, 1) end)
    C_Timer.After(2, function() UIFrameFadeIn(toast.description, .5, 0, 1) end)
    C_Timer.After(5, function() UIFrameFadeOut(toast, 1, 1, 0) end)
end


-- Loop through the Paperdoll Items and create/display information
local function MOPloopinspectitems()
                
    if not option("show_inspect") or InspectFrame.unit == nil then return end
      
    local unit = InspectFrame.unit

    for slotIndex = 1,17 do 
        if slotIndex ~= 4 then
            local itemLink = GetInventoryItemLink(unit, slotIndex)
            local itemID = itemLink and tonumber(itemLink:match("item:(%d+)"))

            if itemID then
                local texture = select(10, C_Item.GetItemInfo(itemID))
                if texture then
                    MOPupdateLocationInfo(unit, slotIndex, "Inspect")
                else
                    local slotFrameName = CCS.getSlotFrameName(slotIndex, "Inspect")
                    _G[slotFrameName]:RegisterEvent("GET_ITEM_INFO_RECEIVED")
                    _G[slotFrameName]:SetScript("OnEvent", function(self, event, arg)
                        if event == "GET_ITEM_INFO_RECEIVED" and arg == itemID then
                            MOPupdateLocationInfo(unit, slotIndex, "Inspect")
                            self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
                        end
                    end)
                end
            end
        end
    end 

    --Create Ilvl Frame and populate
    local iLvl = CCS.GetInspectItemLevel(unit) 
    local ilvlTxt = _G["InspectFrameilvlfs"] or _G["InspectPaperDollFrame"]:CreateFontString("InspectFrameilvlfs")
    local color = "ffffff"
    
    if iLvl == nil then return true end
    
    color = CCS:GetAverageEquippedRarityHex(unit) or "ffffff"
    
    ilvlTxt:SetPoint("TOP", _G["InspectLevelText"], "BOTTOM", 0, -7) 
    ilvlTxt:SetFont(option("fontname_inspect_ilvl") or CCS.fontname, option("fontsize_inspect_ilvl") or 20, "OUTLINE")
    
    ilvlTxt:SetText("|cFF".. color .. format("%.2f", iLvl or "") .. "|r")
    ilvlTxt:SetShown(option("showilvlinspect"))

end 

-- Define the event handler function for this module
function CCS.MOPCharacterSheetEventHandler(event, ...)
    local arg1 = ...

    if CCS.CurrentVersion ~= CCS.MOP then return end
    
    if event == "PLAYER_ENTERING_WORLD" then
        for slot = 1, 19 do
            local link = GetInventoryItemLink("player", slot)
            if link then
                GetItemInfo(link) -- queues item for caching
                local itemID = GetInventoryItemID("player", slot)
                if itemID then
                    C_Item.RequestLoadItemDataByID(itemID) -- nudges client to fetch item data
                end
            end
        end
        TryLoopItems()
        if not CCS.characterUpdatePending then
            CCS.characterUpdatePending = true
            C_Timer.After(0.2, function()
                CCS.characterUpdatePending = false
                TryLoopItems()
            end)
        end
        return true
    end

    if event == "CCS_EVENT_OPTIONS" then
        if MOPStatHighlightsEnabled() then
            ScheduleMOPStatRowHooks()
        else
            ClearMOPStatHighlightSelection()
        end
        TryLoopItems()
        CCS.ChangeModelBg(false)
        CCSReputationFrame_Update()
        CurrencyFrame_Update()

        if InspectFrame ~= nil and InspectFrame:IsVisible() == true then
            MOPloopinspectitems()
        end
        
        return true
    end

    if (not CharacterFrame or not CharacterFrame:IsVisible()) and event ~= "INSPECT_READY" then return end

    if event == "PLAYER_EQUIPMENT_CHANGED" then
        TryLoopItems()
        UpdateMOPItemLevelSummary()
        if not CCS.characterUpdatePending then
            CCS.characterUpdatePending = true
            C_Timer.After(0.2, function()
                CCS.characterUpdatePending = false
                TryLoopItems()
                UpdateMOPItemLevelSummary()
            end)
        end
        return true
    elseif event == "PLAYER_AVG_ITEM_LEVEL_UPDATE"
        or event == "BAG_UPDATE_DELAYED"
        or event == "ACTIVE_TALENT_GROUP_CHANGED"
        or event == "PLAYER_SPECIALIZATION_CHANGED" then
        UpdateMOPItemLevelSummary()
        C_Timer.After(0.2, UpdateMOPItemLevelSummary)
        return true
    elseif event == "CCS_EVENT_CSHOW" then

        if not CCS.characterUpdatePending then
            CCS.characterUpdatePending = true
            C_Timer.After(0.2, function()
                CCS.characterUpdatePending = false
                TryLoopItems()
                UpdateMOPItemLevelSummary()
                ccs_cshow()
            end)
        end
        
        return true
    elseif event == "INSPECT_READY" and InspectFrame ~= nil and InspectFrame.unit ~= nil then
        if not CCS.inspectUpdatePending then
            CCS.inspectUpdatePending = true
            InspectFrame:SetAlpha(0)
            InspectModelFrame:SetAlpha(0)
            C_Timer.After(0.1, function()
                CCS.inspectUpdatePending = false
                MOPinitializeinspectframe()
                MOPloopinspectitems()
                InspectFrame:SetAlpha(1)
                InspectModelFrame:SetAlpha(1)
            end)
        end
        return true
    else 
        if not CCS.characterUpdatePending then
            CCS.characterUpdatePending = true
            loopitems()
            C_Timer.After(0.2, function()
                CCS.characterUpdatePending = false
                loopitems()
            end)
        end
        return true
    end
end
