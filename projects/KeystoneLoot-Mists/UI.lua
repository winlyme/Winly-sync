local _, Addon = ...

local UI = {}
Addon.UI = UI

local WINDOW_WIDTH = 500
local HEADER_HEIGHT = 82
local FOOTER_HEIGHT = 0
local ROW_WIDTH = 486
local ROW_HEIGHT = 44
local ITEMS_PER_PAGE = 6
local ITEM_STEP = 38
local TIER_PANEL_WIDTH = 58
local TIER_PANEL_HEIGHT = 230
local COMPETITION_PANEL_WIDTH = 350
local COMPETITION_ROW_HEIGHT = 42
local COMPETITION_SECTION_HEIGHT = 22
local COMPETITION_VISIBLE_ROWS = 8
local TEAM_TIER_WINDOW_WIDTH = 500
local TEAM_TIER_ROW_WIDTH = 486
local TEAM_TIER_ROW_HEIGHT = 48
local TEAM_TIER_HEADER_HEIGHT = 66
local TEAM_TIER_FOOTER_HEIGHT = 0
local TEAM_TIER_ITEM_STEP = 41
local TEAM_TIER_GUILD_HEADER_HEIGHT = 28
local ADDON_ICON = "Interface\\Icons\\INV_Misc_Map02"

local TEAM_TIER_BORDER_COLORS = {
    [16] = { 0.20, 0.95, 0.35 },
    [15] = { 1.00, 0.55, 0.10 },
    [14] = { 1.00, 0.55, 0.10 },
    other = { 0.95, 0.20, 0.20 },
    empty = { 0.32, 0.32, 0.36 },
}

local TEAM_TIER_STATUS_LABELS = {
    queued = "等待读取",
    loading = "正在读取……",
    combat = "战斗中暂停",
    inspect_busy = "观察界面占用",
    out_of_range = "超出观察距离",
    offline = "离线",
    timeout = "读取超时",
    unavailable = "暂不可读取",
}

local MENU_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local DROPDOWN_BACKDROP = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 10,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local FAVORITE_TEXTURES = {
    [1] = "Interface\\AddOns\\KeystoneLoot-Mists\\assets\\tier_nice.blp",
    [2] = "Interface\\AddOns\\KeystoneLoot-Mists\\assets\\tier_must.blp",
    [3] = "Interface\\AddOns\\KeystoneLoot-Mists\\assets\\tier_bis.blp",
    [4] = "Interface\\AddOns\\KeystoneLoot-Mists\\assets\\tier_transmog.blp",
}

local function CreateBackdropFrame(frameType, name, parent)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    return CreateFrame(frameType, name, parent, template)
end

local function ApplyBackdrop(frame, backdrop, r, g, b, a)
    if frame.SetBackdrop then
        frame:SetBackdrop(backdrop)
        frame:SetBackdropColor(r or 0.02, g or 0.02, b or 0.025, a or 0.98)
        frame:SetBackdropBorderColor(0.55, 0.55, 0.62, 0.9)
    end
end

local function GetClassColorText(name, classFile)
    local color = classFile and RAID_CLASS_COLORS[classFile]
    if color and color.colorStr then
        return "|c" .. color.colorStr .. name .. "|r"
    end
    return name
end

local function GetPortraitTexture(encounterID)
    if encounterID and EJ_GetCreatureInfo then
        local _, _, _, _, icon = EJ_GetCreatureInfo(1, encounterID)
        if icon then
            return icon
        end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function UI:SetFrameTitle(text)
    if self.frame.SetTitle then
        self.frame:SetTitle(text)
    elseif self.frame.TitleText then
        self.frame.TitleText:SetText(text)
    end
end

function UI:SetPortrait(texture)
    local frame = self.frame
    local portrait = frame.portrait or frame.Portrait
    if not portrait and frame.PortraitContainer then
        portrait = frame.PortraitContainer.portrait or frame.PortraitContainer.Portrait
    end
    portrait = portrait or _G[frame:GetName() .. "Portrait"]
    if portrait then
        portrait:SetTexture(texture)
        portrait:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        portrait:Show()
    end
end

function UI:Create()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", "KeystoneLootMistsFrame", UIParent, "ButtonFrameTemplate")
    self.frame = frame
    frame:SetSize(WINDOW_WIDTH, 650)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    if ButtonFrameTemplate_HideButtonBar then
        ButtonFrameTemplate_HideButtonBar(frame)
    end

    self:SetFrameTitle("KeystoneLoot（熊猫人之谜）")
    self:SetPortrait(ADDON_ICON)

    local position = Addon.db.position
    if position then
        frame:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    else
        frame:SetPoint("CENTER")
    end

    frame:SetScript("OnDragStart", function(owner)
        self:CloseMenus()
        owner:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(owner)
        owner:StopMovingOrSizing()
        local point, _, relativePoint, x, y = owner:GetPoint(1)
        Addon.db.position = { point = point, relativePoint = relativePoint, x = x, y = y }
    end)
    frame:SetScript("OnHide", function()
        self:CloseMenus()
        if Addon.Competition then
            Addon.Competition:Cancel()
        end
        self:HideCompetitionTooltip()
    end)
    frame:SetScript("OnShow", function()
        Addon.db.filters.slot = "ALL"
        Addon.db.filters.difficulty = 5
        Addon.db.filters.favoritesOnly = false
        Addon.Journal:RefreshInstances()
        self:UpdateControls()
        self:QueueRefresh()
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_OPEN then
            PlaySound(SOUNDKIT.IG_QUEST_LIST_OPEN)
        end
    end)
    frame:Hide()
    table.insert(UISpecialFrames, frame:GetName())

    self.classDropdown = self:CreateDropdown(frame, 120)
    self.classDropdown:SetPoint("TOPLEFT", 58, -34)
    self.classDropdown.getOptions = function()
        return self:GetClassOptions()
    end

    self.slotDropdown = self:CreateDropdown(frame, 120)
    self.slotDropdown:SetPoint("LEFT", self.classDropdown, "RIGHT", 10, 0)
    self.slotDropdown.getOptions = function()
        return self:GetSlotOptions()
    end

    self.difficultyDropdown = self:CreateDropdown(frame, 120)
    self.difficultyDropdown:SetPoint("LEFT", self.slotDropdown, "RIGHT", 10, 0)
    self.difficultyDropdown.getOptions = function()
        return self:GetDifficultyOptions()
    end

    local settings = CreateFrame("Button", nil, frame)
    self.settingsButton = settings
    settings:SetSize(18, 18)
    settings:SetPoint("TOPRIGHT", -31, -4)
    settings.icon = settings:CreateTexture(nil, "ARTWORK")
    settings.icon:SetSize(14, 14)
    settings.icon:SetPoint("CENTER")
    settings.icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    settings:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    settings:SetScript("OnClick", function(owner)
        if self.menu.owner == owner and self.menu:IsShown() then
            self:CloseMenus()
        else
            self:OpenMenu(owner, self:GetSettingsOptions(), 205, "TOPRIGHT", "BOTTOMRIGHT")
        end
    end)
    settings:SetScript("OnEnter", function(owner)
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetText(SETTINGS or "设置")
        GameTooltip:Show()
    end)
    settings:SetScript("OnLeave", GameTooltip_Hide)

    local raidHeader = CreateFrame("Frame", nil, frame)
    self.raidHeader = raidHeader
    raidHeader:SetSize(220, 20)
    raidHeader:SetPoint("TOPLEFT", 11, -64)
    raidHeader.icon = raidHeader:CreateTexture(nil, "ARTWORK")
    raidHeader.icon:SetSize(20, 20)
    raidHeader.icon:SetPoint("LEFT", 1, 0)
    raidHeader.icon:SetTexture(ADDON_ICON)
    raidHeader.text = raidHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    raidHeader.text:SetPoint("LEFT", raidHeader.icon, "RIGHT", 2, -1)
    raidHeader.text:SetText("决战奥格瑞玛")

    if frame.Inset then
        frame.Inset:ClearAllPoints()
        frame.Inset:SetPoint("TOPLEFT", 3, -82)
        frame.Inset:SetPoint("BOTTOMRIGHT", -3, 3)
        if frame.Inset.Bg then
            frame.Inset.Bg:SetAlpha(0.75)
        end
    end

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame.Inset or frame)
    self.scrollFrame = scrollFrame
    scrollFrame:SetPoint("TOPLEFT", 4, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", -4, 5)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(owner, delta)
        local maximum = math.max(0, self.content:GetHeight() - owner:GetHeight())
        local nextValue = owner:GetVerticalScroll() - delta * ROW_HEIGHT * 2
        owner:SetVerticalScroll(math.max(0, math.min(maximum, nextValue)))
    end)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(ROW_WIDTH, 1)
    scrollFrame:SetScrollChild(content)
    self.content = content

    self.emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    self.emptyText:SetPoint("TOP", 0, -45)
    self.emptyText:SetWidth(430)
    self.emptyText:SetText("正在读取地下城手册……")

    self.rowPool = {}
    self:CreateCompetitionTooltip()
    self:CreateTierPanel(frame)
    self:CreateTeamTierFrame()
    self:CreateMenus()
    self:CreateMinimapButton()
    self:UpdateControls()
end

function UI:CreateCompetitionTooltip()
    local panel = CreateBackdropFrame("Frame", "KeystoneLootMistsCompetitionTooltip", UIParent)
    self.competitionTooltip = panel
    panel:SetSize(COMPETITION_PANEL_WIDTH, 100)
    panel:SetFrameStrata("TOOLTIP")
    panel:SetFrameLevel(100)
    panel:SetClampedToScreen(true)
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function(_, delta)
        self:ScrollCompetitionTooltip(delta)
    end)
    ApplyBackdrop(panel, MENU_BACKDROP, 0.018, 0.018, 0.026, 0.98)
    panel:SetBackdropBorderColor(0.52, 0.42, 0.68, 0.98)
    panel:Hide()

    panel.target = CreateFrame("Frame", nil, panel)
    panel.target:SetPoint("TOPLEFT", 8, -8)
    panel.target:SetPoint("TOPRIGHT", -8, -8)
    panel.target:SetHeight(44)
    panel.target.background = panel.target:CreateTexture(nil, "BACKGROUND")
    panel.target.background:SetAllPoints()
    panel.target.background:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    panel.target.background:SetVertexColor(0.12, 0.09, 0.16, 0.72)
    panel.target.icon = panel.target:CreateTexture(nil, "ARTWORK")
    panel.target.icon:SetSize(36, 36)
    panel.target.icon:SetPoint("LEFT", 5, 0)
    panel.target.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    panel.target.borders = {}
    local targetBorderPoints = {
        { "TOPLEFT", -1, 1, "TOPRIGHT", 1, 1, 2 },
        { "BOTTOMLEFT", -1, -1, "BOTTOMRIGHT", 1, -1, 2 },
        { "TOPLEFT", -1, 1, "BOTTOMLEFT", -1, -1, 2, true },
        { "TOPRIGHT", 1, 1, "BOTTOMRIGHT", 1, -1, 2, true },
    }
    for _, points in ipairs(targetBorderPoints) do
        local border = panel.target:CreateTexture(nil, "OVERLAY")
        border:SetTexture("Interface\\Buttons\\WHITE8X8")
        border:SetPoint(points[1], panel.target.icon, points[1], points[2], points[3])
        border:SetPoint(points[4], panel.target.icon, points[4], points[5], points[6])
        if points[8] then
            border:SetWidth(points[7])
        else
            border:SetHeight(points[7])
        end
        border:SetVertexColor(0.52, 0.42, 0.68, 1)
        table.insert(panel.target.borders, border)
    end
    panel.target.itemLevel = panel.target:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.target.itemLevel:SetPoint("BOTTOMRIGHT", panel.target.icon, "BOTTOMRIGHT", -1, 1)
    panel.target.itemLevel:SetJustifyH("RIGHT")
    local targetItemLevelFont = panel.target.itemLevel:GetFont()
    if targetItemLevelFont then
        panel.target.itemLevel:SetFont(targetItemLevelFont, 9, "OUTLINE")
    end
    panel.target.name = panel.target:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.target.name:SetPoint("LEFT", panel.target.icon, "RIGHT", 8, 0)
    panel.target.name:SetPoint("RIGHT", -8, 0)
    panel.target.name:SetJustifyH("LEFT")
    panel.target.name:SetWordWrap(false)

    panel.scrollFrame = CreateFrame("ScrollFrame", nil, panel)
    panel.scrollFrame:SetPoint("TOPLEFT", 8, -60)
    panel.scrollFrame:SetPoint("BOTTOMRIGHT", -8, 8)

    panel.content = CreateFrame("Frame", nil, panel.scrollFrame)
    panel.content:SetSize(COMPETITION_PANEL_WIDTH - 16, 1)
    panel.scrollFrame:SetScrollChild(panel.content)

    local targetTooltip = CreateFrame("GameTooltip", "KeystoneLootMistsCompetitionTargetTooltip", UIParent, "GameTooltipTemplate")
    self.competitionTargetTooltip = targetTooltip
    targetTooltip:SetFrameStrata("TOOLTIP")
    targetTooltip:SetFrameLevel(panel:GetFrameLevel() + 10)
    targetTooltip:Hide()
    panel:SetScript("OnHide", function()
        targetTooltip:Hide()
    end)

    panel.rowPool = {}
    panel.sectionPool = {}
end

function UI:SetCompetitionTargetItem(item, meta)
    local panel = self.competitionTooltip
    local target = panel and panel.target
    if not target then
        return
    end
    panel.targetItem = item
    local name, link, _, itemLevel, _, _, _, _, _, icon
    if item then
        name, link, _, itemLevel, _, _, _, _, _, icon = Addon:GetItemInfo(item.link or item.itemID)
    end
    target.icon:SetTexture(item and (item.icon or icon) or "Interface\\Icons\\INV_Misc_QuestionMark")
    target.name:SetText(item and (item.link or link or item.name or name or "未知装备") or "未知装备")
    local actualItemLevel = meta and meta.targetItemLevel or item and item.itemLevel or itemLevel
    target.itemLevel:SetText(actualItemLevel and tostring(actualItemLevel) or "?")
end

function UI:ShowCompetitionTargetTooltip(item)
    local panel = self.competitionTooltip
    local tooltip = self.competitionTargetTooltip
    if not panel or not panel:IsShown() or not tooltip or not item then
        return
    end
    tooltip:SetOwner(panel, "ANCHOR_NONE")
    tooltip:ClearLines()
    tooltip:ClearAllPoints()
    tooltip:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", 0, 0)
    if item.link and string.find(item.link, "|Hitem:") then
        tooltip:SetHyperlink(item.link)
    elseif tooltip.SetItemByID and item.itemID then
        tooltip:SetItemByID(item.itemID)
    elseif item.itemID then
        tooltip:SetHyperlink("item:" .. item.itemID)
    else
        tooltip:SetText(item.name or "未知装备")
    end
    tooltip:Show()
    self:ApplyMaxUpgradePreview(tooltip, item)
end

function UI:GetCompetitionSection(key)
    local panel = self.competitionTooltip
    local section = panel.sectionPool[key]
    if section then
        return section
    end

    section = CreateFrame("Frame", nil, panel.content)
    section:SetSize(COMPETITION_PANEL_WIDTH - 16, COMPETITION_SECTION_HEIGHT)
    section.background = section:CreateTexture(nil, "BACKGROUND")
    section.background:SetAllPoints()
    section.background:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    section.label = section:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    section.label:SetPoint("LEFT", 7, 0)
    section.count = section:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    section.count:SetPoint("RIGHT", -7, 0)
    panel.sectionPool[key] = section
    return section
end

function UI:GetCompetitionRow(index)
    local panel = self.competitionTooltip
    local row = panel.rowPool[index]
    if row then
        return row
    end

    row = CreateFrame("Frame", nil, panel.content)
    row:SetSize(COMPETITION_PANEL_WIDTH - 16, COMPETITION_ROW_HEIGHT)
    row.background = row:CreateTexture(nil, "BACKGROUND")
    row.background:SetAllPoints()
    row.background:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    row.background:SetVertexColor(0.1, 0.08, 0.14, index % 2 == 0 and 0.30 or 0.12)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("TOPLEFT", 7, -7)
    row.name:SetWidth(225)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.state = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.state:SetPoint("BOTTOMLEFT", 7, 6)
    row.state:SetWidth(225)
    row.state:SetJustifyH("LEFT")
    row.state:SetWordWrap(false)

    row.itemButtons = {}
    for slotIndex = 1, 2 do
        local itemButton = self:CreateTeamTierItemButton(row)
        itemButton:SetPoint("RIGHT", -4 - (2 - slotIndex) * 40, 0)
        row.itemButtons[slotIndex] = itemButton
    end

    panel.rowPool[index] = row
    return row
end

function UI:GetCompetitionStatusText(row, meta)
    if row.status == "ready" or row.hasCachedData then
        local text
        if row.needState == "need" then
            text = "|cffffc857有需求|r"
        elseif row.needState == "no_need" then
            text = "|cffaaaaaa无需求|r"
        elseif row.needState == "equipped" then
            text = "|cff45e66e已装备|r"
        elseif row.needState == "same_level" then
            text = "|cff7fbfff同等级|r"
        elseif row.targetEquipped then
            text = "|cff45e66e已装备|r"
        else
            text = "|cffaaaaaa装等未知|r"
        end
        if row.status ~= "ready" then
            text = text .. " · |cffaaaaaa缓存|r"
        end
        return text
    end

    local labels = {
        queued = "|cff7fbfff等待观察|r",
        loading = "|cff7fbfff正在读取……|r",
        combat = "|cffffa64d战斗中不可观察|r",
        inspect_busy = "|cffffd36a观察界面占用中|r",
        out_of_range = "|cffaaaaaa超出观察距离|r",
        offline = "|cff888888离线|r",
        timeout = "|cffff7070观察超时|r",
        unavailable = "|cffaaaaaa暂不可读取|r",
    }
    return labels[row.status] or labels.unavailable
end

function UI:AnchorCompetitionTooltip()
    local panel = self.competitionTooltip
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", self.tierPanel, "BOTTOMLEFT", 0, 0)
end

function UI:RenderCompetitionTooltip(button, rows, meta, isDemo, targetItem)
    local panel = self.competitionTooltip
    if not panel or not button or panel.owner ~= button then
        return
    end

    panel.isDemo = isDemo or nil
    self:SetCompetitionTargetItem(targetItem or button.item, meta)

    for _, row in ipairs(panel.rowPool) do
        row:Hide()
    end
    for _, section in pairs(panel.sectionPool) do
        section:Hide()
    end

    local rowCount = #rows
    local groups = {
        need = {},
        noNeed = {},
        unread = {},
    }
    for _, data in ipairs(rows) do
        if (data.status == "ready" or data.hasCachedData) and data.needState == "need" then
            table.insert(groups.need, data)
        elseif (data.status == "ready" or data.hasCachedData)
            and (data.needState == "no_need" or data.needState == "equipped"
                or data.needState == "same_level" or data.targetEquipped) then
            table.insert(groups.noNeed, data)
        else
            table.insert(groups.unread, data)
        end
    end

    local sections = {
        { key = "need", label = "有需求", rows = groups.need, color = { 0.52, 0.32, 0.08, 0.62 } },
        { key = "noNeed", label = "无需求", rows = groups.noNeed, color = { 0.12, 0.24, 0.14, 0.58 } },
        { key = "unread", label = "未读取", rows = groups.unread, color = { 0.18, 0.18, 0.22, 0.58 } },
    }
    local contentOffset = 0
    local rowIndex = 0
    for _, sectionData in ipairs(sections) do
        local section = self:GetCompetitionSection(sectionData.key)
        section:ClearAllPoints()
        section:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 0, -contentOffset)
        section.background:SetVertexColor(sectionData.color[1], sectionData.color[2], sectionData.color[3], sectionData.color[4])
        section.label:SetText(sectionData.label)
        section.count:SetText(tostring(#sectionData.rows))
        section:Show()
        contentOffset = contentOffset + COMPETITION_SECTION_HEIGHT

        for _, data in ipairs(sectionData.rows) do
            rowIndex = rowIndex + 1
            local row = self:GetCompetitionRow(rowIndex)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 0, -contentOffset)
            row.name:SetText(GetClassColorText(data.name or "未知成员", data.classFile))
            row.state:SetText(self:GetCompetitionStatusText(data, meta))
            for slotIndex, itemButton in ipairs(row.itemButtons) do
                local equipped = (data.status == "ready" or data.hasCachedData)
                    and data.currentItems and data.currentItems[slotIndex]
                self:SetTeamTierItemButton(itemButton, equipped)
                itemButton:SetShown(equipped ~= nil)
            end
            row:Show()
            contentOffset = contentOffset + COMPETITION_ROW_HEIGHT
        end
    end

    local contentHeight = math.max(1, contentOffset)
    panel.content:SetHeight(contentHeight)
    local visibleRows = math.min(math.max(1, rowCount), COMPETITION_VISIBLE_ROWS)
    local visibleContentHeight = COMPETITION_SECTION_HEIGHT * #sections
        + visibleRows * COMPETITION_ROW_HEIGHT
    visibleContentHeight = math.min(contentHeight, visibleContentHeight)
    panel:SetHeight(68 + visibleContentHeight)
    local maximumScroll = math.max(0, contentHeight - visibleContentHeight)
    panel.scrollFrame:SetVerticalScroll(math.min(panel.scrollFrame:GetVerticalScroll(), maximumScroll))
    self:AnchorCompetitionTooltip()
    panel:Show()
    self:ShowCompetitionTargetTooltip(panel.targetItem)
end

function UI:ToggleCompetitionDemo()
    local panel = self.competitionTooltip
    if not panel or not self.frame then
        return false
    end

    if panel:IsShown() and panel.isDemo then
        self:HideCompetitionTooltip()
        return false
    end

    if Addon.Competition then
        Addon.Competition:Cancel()
    end

    if panel.owner then
        panel.owner.competitionSelected = nil
    end
    if self.teamTierFrame and self.teamTierFrame:IsShown() then
        self.teamTierFrame:Hide()
    end
    self.frame:Show()
    panel.owner = self.frame
    panel.scrollFrame:SetVerticalScroll(0)

    local rows = {
        {
            name = "影刃",
            classFile = "ROGUE",
            specID = 259,
            status = "ready",
            targetEquipped = false,
            needState = "need",
            comparisonItemLevel = 540,
            targetItemLevel = 553,
            currentItems = {
                { name = "影踪派刺客兜帽", link = "|cffa335ee[影踪派刺客兜帽]|r", itemLevel = 540 },
            },
        },
        {
            name = "星霜",
            classFile = "MAGE",
            specID = 62,
            status = "ready",
            targetEquipped = true,
            needState = "equipped",
            comparisonItemLevel = 553,
            targetItemLevel = 553,
            currentItems = {
                { name = "时光领主兜帽", link = "|cffa335ee[时光领主兜帽]|r", itemLevel = 553 },
            },
        },
        {
            name = "月桂",
            classFile = "DRUID",
            specID = 102,
            status = "ready",
            targetEquipped = false,
            needState = "same_level",
            comparisonItemLevel = 553,
            targetItemLevel = 553,
            currentItems = {
                { name = "林地守望者头冠", link = "|cffa335ee[林地守望者头冠]|r", itemLevel = 553 },
            },
        },
        {
            name = "北境",
            classFile = "DEATHKNIGHT",
            specID = 251,
            status = "ready",
            targetEquipped = false,
            needState = "no_need",
            comparisonItemLevel = 566,
            targetItemLevel = 553,
            currentItems = {
                { name = "冰封征服者战盔", link = "|cffa335ee[冰封征服者战盔]|r", itemLevel = 566 },
            },
        },
        {
            name = "夜行",
            classFile = "ROGUE",
            specID = 260,
            status = "loading",
            targetEquipped = false,
            currentItems = {},
        },
        {
            name = "枯叶",
            classFile = "DRUID",
            specID = 103,
            status = "out_of_range",
            targetEquipped = false,
            currentItems = {},
        },
    }
    local meta = {
        total = #rows,
        ready = 4,
        reliable = true,
        isTier = true,
        targetItemLevel = 553,
    }

    local targetItem = Addon.Journal:CompleteItemInfo({ itemID = 99327 })
    self:RenderCompetitionTooltip(self.frame, rows, meta, true, targetItem)
    return true
end

function UI:ShowCompetitionTooltip(button)
    local panel = self.competitionTooltip
    if not panel or not Addon.Competition then
        return
    end

    if panel.owner and panel.owner ~= button then
        panel.owner.competitionSelected = nil
    end
    panel.isDemo = nil
    button.competitionSelected = true
    panel.owner = button
    panel.scrollFrame:SetVerticalScroll(0)
    local expectedItemID = button.item and button.item.itemID

    -- Open the panel before starting the inspect request.  This keeps the
    -- selected item's details visible for solo players and for items whose
    -- comparison slots cannot be resolved yet.
    self:RenderCompetitionTooltip(button, {}, {
        total = 0,
        ready = 0,
        reliable = false,
        targetItemLevel = button.item and button.item.itemLevel,
    })

    Addon.Competition:Request(button.item, button.source, button, function(rows, meta)
        if panel.owner == button and button.competitionSelected
            and button.item and button.item.itemID == expectedItemID then
            self:RenderCompetitionTooltip(button, rows, meta)
        end
    end)
    -- A failed request means there is currently no comparable equipment data;
    -- the target card and the empty competition sections should remain open.
end

function UI:HideCompetitionTooltip(button)
    local panel = self.competitionTooltip
    if not panel or (button and panel.owner ~= button) then
        return
    end
    if panel.owner then
        panel.owner.competitionSelected = nil
    end
    panel.owner = nil
    panel.isDemo = nil
    panel.targetItem = nil
    panel:Hide()
end

function UI:ScrollCompetitionTooltip(delta)
    local panel = self.competitionTooltip
    if not panel or not panel:IsShown() then
        return
    end
    local maximum = math.max(0, panel.content:GetHeight() - panel.scrollFrame:GetHeight())
    local nextValue = panel.scrollFrame:GetVerticalScroll() - delta * COMPETITION_ROW_HEIGHT * 2
    panel.scrollFrame:SetVerticalScroll(math.max(0, math.min(maximum, nextValue)))
end

function UI:CreateTeamTierItemButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(36, 36)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(30, 30)
    button.icon:SetPoint("CENTER")
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.borders = {}
    local top = button:CreateTexture(nil, "OVERLAY")
    top:SetTexture("Interface\\Buttons\\WHITE8X8")
    top:SetPoint("TOPLEFT", button.icon, "TOPLEFT", -2, 2)
    top:SetPoint("TOPRIGHT", button.icon, "TOPRIGHT", 2, 2)
    top:SetHeight(2)
    table.insert(button.borders, top)
    local bottom = button:CreateTexture(nil, "OVERLAY")
    bottom:SetTexture("Interface\\Buttons\\WHITE8X8")
    bottom:SetPoint("BOTTOMLEFT", button.icon, "BOTTOMLEFT", -2, -2)
    bottom:SetPoint("BOTTOMRIGHT", button.icon, "BOTTOMRIGHT", 2, -2)
    bottom:SetHeight(2)
    table.insert(button.borders, bottom)
    local left = button:CreateTexture(nil, "OVERLAY")
    left:SetTexture("Interface\\Buttons\\WHITE8X8")
    left:SetPoint("TOPLEFT", button.icon, "TOPLEFT", -2, 2)
    left:SetPoint("BOTTOMLEFT", button.icon, "BOTTOMLEFT", -2, -2)
    left:SetWidth(2)
    table.insert(button.borders, left)
    local right = button:CreateTexture(nil, "OVERLAY")
    right:SetTexture("Interface\\Buttons\\WHITE8X8")
    right:SetPoint("TOPRIGHT", button.icon, "TOPRIGHT", 2, 2)
    right:SetPoint("BOTTOMRIGHT", button.icon, "BOTTOMRIGHT", 2, -2)
    right:SetWidth(2)
    table.insert(button.borders, right)

    button.itemLevel = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.itemLevel:SetPoint("BOTTOMRIGHT", button.icon, "BOTTOMRIGHT", -1, 1)
    button.itemLevel:SetJustifyH("RIGHT")
    button.itemLevel:SetTextColor(1, 1, 1)
    local fontPath = button.itemLevel:GetFont()
    if fontPath then
        button.itemLevel:SetFont(fontPath, 9, "OUTLINE")
    end

    button.upgradeLevel = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.upgradeLevel:SetPoint("TOPLEFT", button.icon, "TOPLEFT", 1, -1)
    button.upgradeLevel:SetTextColor(0.35, 1, 0.45)
    local upgradeFontPath = button.upgradeLevel:GetFont()
    if upgradeFontPath then
        button.upgradeLevel:SetFont(upgradeFontPath, 8, "OUTLINE")
    end

    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("OnEnter", function(owner)
        self:ShowPlainItemTooltip(owner, owner.item, "ANCHOR_RIGHT")
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    return button
end

function UI:SetTeamTierItemButton(button, item)
    button.item = item
    local raidTier = item and (item.raidTier
        or Addon.TierSets and Addon.TierSets:GetRaidTierForItem(item.itemID, item.setID))
    local color = item and (TEAM_TIER_BORDER_COLORS[raidTier] or TEAM_TIER_BORDER_COLORS.other)
        or TEAM_TIER_BORDER_COLORS.empty
    for _, border in ipairs(button.borders) do
        border:SetVertexColor(color[1], color[2], color[3], 1)
    end
    if item then
        button.icon:SetTexture(item.icon or 134400)
        button.icon:SetDesaturated(false)
        button.icon:SetAlpha(1)
        button.itemLevel:SetText(item.itemLevel and tostring(item.itemLevel) or "?")
        button.upgradeLevel:SetText(item.upgradeText or "")
    else
        button.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        button.icon:SetDesaturated(true)
        button.icon:SetAlpha(0.25)
        button.itemLevel:SetText("")
        button.upgradeLevel:SetText("")
    end
end

function UI:GetTeamTierSummary(cache)
    if not cache then
        return nil
    end
    local counts = { [16] = 0, [15] = 0, [14] = 0 }
    for _, inventorySlot in ipairs(Addon.TierSets.TIER_INVENTORY_SLOTS) do
        local item = cache.slots[inventorySlot]
        local raidTier = item and (item.raidTier
            or Addon.TierSets:GetRaidTierForItem(item.itemID, item.setID))
        if counts[raidTier] then
            counts[raidTier] = counts[raidTier] + 1
        end
    end
    local parts = {}
    for _, raidTier in ipairs({ 16, 15, 14 }) do
        if counts[raidTier] > 0 then
            table.insert(parts, ("%dT%d"):format(counts[raidTier], raidTier))
        end
    end
    return #parts > 0 and table.concat(parts, "+") or "散件"
end

function UI:FormatTeamTierUpdateTime(cache)
    local updatedAt = tonumber(cache and cache.updatedAt)
    if not updatedAt or updatedAt <= 0 or not date then
        return cache and "更新：未知" or ""
    end
    local now = GetServerTime and GetServerTime() or (time and time()) or updatedAt
    if date("%Y%m%d", now) == date("%Y%m%d", updatedAt) then
        return "更新 " .. date("%H:%M", updatedAt)
    end
    return "更新 " .. date("%m/%d %H:%M", updatedAt)
end

function UI:CreateTeamTierRow(index)
    local frame = self.teamTierFrame
    local row = CreateFrame("Frame", nil, frame.content)
    row:SetSize(TEAM_TIER_ROW_WIDTH, TEAM_TIER_ROW_HEIGHT)
    row.background = row:CreateTexture(nil, "BACKGROUND")
    row.background:SetAllPoints()
    row.background:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    row.background:SetVertexColor(0.08, 0.06, 0.11, index % 2 == 0 and 0.42 or 0.18)

    row.portrait = row:CreateTexture(nil, "ARTWORK")
    row.portrait:SetSize(30, 30)
    row.portrait:SetPoint("LEFT", 8, 0)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", row.portrait, "RIGHT", 6, 7)
    row.name:SetWidth(102)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.updatedAt = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.updatedAt:SetPoint("LEFT", row.portrait, "RIGHT", 6, -9)
    row.updatedAt:SetWidth(102)
    row.updatedAt:SetJustifyH("LEFT")
    row.updatedAt:SetWordWrap(false)
    local updatedFontPath = row.updatedAt:GetFont()
    if updatedFontPath then
        row.updatedAt:SetFont(updatedFontPath, 9)
    end

    row.itemButtons = {}
    for slotIndex = 1, 5 do
        local button = self:CreateTeamTierItemButton(row)
        button:SetPoint("LEFT", 150 + (slotIndex - 1) * TEAM_TIER_ITEM_STEP, 0)
        row.itemButtons[slotIndex] = button
    end

    row.summary = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.summary:SetPoint("RIGHT", -8, 0)
    row.summary:SetWidth(120)
    row.summary:SetJustifyH("RIGHT")
    row.summary:SetWordWrap(false)

    row.divider = row:CreateTexture(nil, "OVERLAY")
    row.divider:SetHeight(1)
    row.divider:SetPoint("BOTTOMLEFT", 8, 0)
    row.divider:SetPoint("BOTTOMRIGHT", -8, 0)
    row.divider:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.divider:SetVertexColor(0.45, 0.38, 0.55, 0.28)
    return row
end

function UI:SetTeamTierRow(row, data, index)
    row.name:SetText(GetClassColorText(data.name or "未知成员", data.classFile))
    row.updatedAt:SetText(self:FormatTeamTierUpdateTime(data.cache))
    local coords = CLASS_ICON_TCOORDS and data.classFile and CLASS_ICON_TCOORDS[data.classFile]
    if coords then
        row.portrait:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        row.portrait:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
        row.portrait:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        row.portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    for slotIndex, inventorySlot in ipairs(Addon.TierSets.TIER_INVENTORY_SLOTS) do
        self:SetTeamTierItemButton(row.itemButtons[slotIndex], data.cache and data.cache.slots[inventorySlot])
    end
    local summary = self:GetTeamTierSummary(data.cache)
        or TEAM_TIER_STATUS_LABELS[data.status]
        or "等待读取"
    row.summary:SetText(summary)
    row.summary:SetTextColor(data.cache and 1 or 0.62, data.cache and 0.82 or 0.62, data.cache and 0.20 or 0.62)
    row.background:SetAlpha(index % 2 == 0 and 1 or 0.65)
end

function UI:CreateTeamTierFrame()
    local frame = CreateFrame("Frame", "KeystoneLootMistsTeamTierFrame", UIParent, "ButtonFrameTemplate")
    self.teamTierFrame = frame
    frame:SetSize(TEAM_TIER_WINDOW_WIDTH, 560)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    if ButtonFrameTemplate_HideButtonBar then
        ButtonFrameTemplate_HideButtonBar(frame)
    end
    if frame.SetTitle then
        frame:SetTitle("队伍套装情况")
    elseif frame.TitleText then
        frame.TitleText:SetText("队伍套装情况")
    end
    local portrait = frame.portrait or frame.Portrait
    if portrait then
        portrait:SetTexture(ADDON_ICON)
        portrait:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end
    frame:SetScript("OnDragStart", function(owner)
        owner:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(owner)
        owner:StopMovingOrSizing()
    end)
    frame:SetScript("OnShow", function()
        if Addon.Competition then
            Addon.Competition:RefreshTeamTierEquipment()
        end
        frame.scrollFrame:SetVerticalScroll(0)
        self:RefreshTeamTierFrame()
    end)
    frame:SetScript("OnHide", GameTooltip_Hide)
    frame:Hide()
    table.insert(UISpecialFrames, frame:GetName())

    if frame.Inset then
        frame.Inset:ClearAllPoints()
        frame.Inset:SetPoint("TOPLEFT", 3, -TEAM_TIER_HEADER_HEIGHT)
        frame.Inset:SetPoint("BOTTOMRIGHT", -3, 3)
    end

    frame.headerName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.headerName:SetPoint("TOPLEFT", 15, -42)
    frame.headerName:SetText("成员")
    local slotLabels = { "头", "肩", "胸", "手", "腿" }
    frame.headerSlots = {}
    for slotIndex, label in ipairs(slotLabels) do
        local textLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        textLabel:SetPoint("TOPLEFT", 164 + (slotIndex - 1) * TEAM_TIER_ITEM_STEP, -42)
        textLabel:SetText(label)
        frame.headerSlots[slotIndex] = textLabel
    end
    frame.headerSummary = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.headerSummary:SetPoint("TOPRIGHT", -17, -42)
    frame.headerSummary:SetText("套装情况")

    frame.scrollFrame = CreateFrame("ScrollFrame", nil, frame.Inset or frame)
    frame.scrollFrame:SetPoint("TOPLEFT", 4, -5)
    frame.scrollFrame:SetPoint("BOTTOMRIGHT", -4, 5)
    frame.scrollFrame:EnableMouseWheel(true)
    frame.scrollFrame:SetScript("OnMouseWheel", function(owner, delta)
        local maximum = math.max(0, frame.content:GetHeight() - owner:GetHeight())
        local nextValue = owner:GetVerticalScroll() - delta * TEAM_TIER_ROW_HEIGHT * 2
        owner:SetVerticalScroll(math.max(0, math.min(maximum, nextValue)))
    end)
    frame.content = CreateFrame("Frame", nil, frame.scrollFrame)
    frame.content:SetSize(TEAM_TIER_ROW_WIDTH, 1)
    frame.scrollFrame:SetScrollChild(frame.content)
    frame.emptyText = frame.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.emptyText:SetPoint("TOP", 0, -40)
    frame.emptyText:SetText("暂无可显示角色")

    frame.guildHeader = CreateFrame("Frame", nil, frame.content)
    frame.guildHeader:SetSize(TEAM_TIER_ROW_WIDTH, TEAM_TIER_GUILD_HEADER_HEIGHT)
    frame.guildHeader.background = frame.guildHeader:CreateTexture(nil, "BACKGROUND")
    frame.guildHeader.background:SetAllPoints()
    frame.guildHeader.background:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    frame.guildHeader.background:SetVertexColor(0.24, 0.16, 0.30, 0.72)
    frame.guildHeader.label = frame.guildHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.guildHeader.label:SetPoint("LEFT", 10, 0)
    frame.guildHeader.label:SetText("曾组队的同公会成员")
    frame.guildHeader:Hide()

    frame.rowPool = {}
end

function UI:RefreshTeamTierFrame()
    local frame = self.teamTierFrame
    if not frame or not frame:IsShown() or not Addon.Competition then
        return
    end
    local rows, guildRows = Addon.Competition:GetGroupEquipmentRows()
    guildRows = guildRows or {}
    for _, row in ipairs(frame.rowPool) do
        row:Hide()
    end
    frame.guildHeader:Hide()

    local rowPoolIndex = 0
    local contentOffset = 0
    local function ShowRow(data, showDivider)
        rowPoolIndex = rowPoolIndex + 1
        local row = frame.rowPool[rowPoolIndex]
        if not row then
            row = self:CreateTeamTierRow(rowPoolIndex)
            frame.rowPool[rowPoolIndex] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, -contentOffset)
        self:SetTeamTierRow(row, data, rowPoolIndex)
        row.divider:SetShown(showDivider)
        row:Show()
        contentOffset = contentOffset + TEAM_TIER_ROW_HEIGHT
    end

    for index, data in ipairs(rows) do
        ShowRow(data, index < #rows)
    end

    if #guildRows > 0 then
        contentOffset = contentOffset + 6
        frame.guildHeader:ClearAllPoints()
        frame.guildHeader:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, -contentOffset)
        frame.guildHeader:Show()
        contentOffset = contentOffset + TEAM_TIER_GUILD_HEADER_HEIGHT
        for index, data in ipairs(guildRows) do
            ShowRow(data, index < #guildRows)
        end
    end

    local totalCount = #rows + #guildRows
    local contentHeight = math.max(1, contentOffset)
    frame.content:SetHeight(contentHeight)
    frame.emptyText:SetShown(totalCount == 0)
    local desiredHeight = TEAM_TIER_HEADER_HEIGHT + TEAM_TIER_FOOTER_HEIGHT + contentHeight + 14
    local maximumHeight = math.max(340, UIParent:GetHeight() - 40)
    frame:SetHeight(math.max(260, math.min(desiredHeight, maximumHeight)))
end

function UI:ToggleTeamTierFrame()
    local frame = self.teamTierFrame
    if not frame then
        return
    end
    if frame:IsShown() then
        frame:Hide()
    else
        if self.frame then
            self.frame:Hide()
        end
        frame:Show()
    end
end

function UI:CreateTierPanel(parent)
    local panel = CreateBackdropFrame("Frame", "KeystoneLootMistsTierPanel", parent)
    self.tierPanel = panel
    panel:SetSize(TIER_PANEL_WIDTH, TIER_PANEL_HEIGHT)
    panel:SetPoint("TOPLEFT", parent, "TOPRIGHT", -4, -82)
    panel:SetFrameLevel(parent:GetFrameLevel() + 5)
    ApplyBackdrop(panel, MENU_BACKDROP, 0.025, 0.025, 0.035, 0.98)
    panel:SetBackdropBorderColor(0.55, 0.48, 0.67, 0.95)

    panel.itemButtons = {}
    for index = 1, 5 do
        local button = self:CreateItemButton(panel)
        button:SetPoint("TOP", 0, -14 - (index - 1) * 42)
        button:SetFrameLevel(panel:GetFrameLevel() + 2)
        panel.itemButtons[index] = button
    end
end

function UI:GetTierPanelSpecID()
    local specID = tonumber(Addon.db.filters.specID) or 0
    if specID ~= 0 then
        return specID
    end
    if Addon.db.filters.classID == Addon:GetCurrentClassID() then
        local currentSpecID = Addon:GetCurrentSpecID()
        if currentSpecID ~= 0 then
            return currentSpecID
        end
    end
    return 0
end

function UI:RefreshTierPanel()
    local panel = self.tierPanel
    if not panel then
        return
    end

    local specID = self:GetTierPanelSpecID()
    local set = Addon.TierSets and Addon.TierSets:GetSet(specID, Addon.db.filters.difficulty)
    local hasSet = set ~= nil
    panel:SetShown(hasSet)

    if not hasSet then
        for _, button in ipairs(panel.itemButtons) do
            self:SetItemButton(button, nil, nil)
            button:Hide()
        end
        return
    end

    local instance = Addon.Journal:GetInstance()
    local source = {
        instanceID = instance and instance.instanceID or Addon.Journal.SOO_INSTANCE_ID,
        mapID = instance and instance.mapID,
        difficultyID = Addon.db.filters.difficulty,
        instanceName = instance and instance.name or "决战奥格瑞玛",
        encounterName = "T16 套装兑换",
        journalInstanceID = instance and instance.journalInstanceID,
    }

    for index, itemID in ipairs(set.items) do
        local item = Addon.Journal:CompleteItemInfo({ itemID = itemID })
        local button = panel.itemButtons[index]
        self:SetItemButton(button, item, source)
        button:Show()
    end
end

function UI:CreateDropdown(parent, width)
    local dropdown = CreateBackdropFrame("Button", nil, parent)
    dropdown:SetSize(width, 25)
    ApplyBackdrop(dropdown, DROPDOWN_BACKDROP, 0.035, 0.035, 0.045, 0.96)
    dropdown:SetBackdropBorderColor(0.38, 0.38, 0.46, 0.95)
    dropdown.text = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dropdown.text:SetPoint("LEFT", 8, -1)
    dropdown.text:SetPoint("RIGHT", -20, -1)
    dropdown.text:SetJustifyH("LEFT")
    dropdown.text:SetWordWrap(false)
    dropdown.arrow = dropdown:CreateTexture(nil, "OVERLAY")
    dropdown.arrow:SetSize(14, 14)
    dropdown.arrow:SetPoint("RIGHT", -4, -1)
    dropdown.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    dropdown:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    dropdown:SetScript("OnClick", function(owner)
        if self.menu.owner == owner and self.menu:IsShown() then
            self:CloseMenus()
        else
            self:OpenMenu(owner, owner.getOptions and owner.getOptions() or {}, math.max(width, 150))
        end
    end)
    return dropdown
end

function UI:CreateMenus()
    self.menu = self:CreateMenuFrame("KeystoneLootMistsDropdownMenu")
    self.submenu = self:CreateMenuFrame("KeystoneLootMistsDropdownSubmenu")

    self.menuDismissFrame = CreateFrame("Frame")
    self.menuDismissFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")
    self.menuDismissFrame:SetScript("OnEvent", function()
        if not self.menu:IsShown() then
            return
        end

        local foci = {}
        if GetMouseFoci then
            foci = GetMouseFoci() or foci
        elseif GetMouseFocus then
            local focus = GetMouseFocus()
            if focus then
                foci[1] = focus
            end
        end

        for _, focus in ipairs(foci) do
            if self:IsMenuRelatedFrame(focus) then
                return
            end
        end
        self:CloseMenus()
    end)
end

function UI:IsMenuRelatedFrame(frame)
    while frame do
        if frame == self.menu or frame == self.submenu or frame == self.menu.owner then
            return true
        end
        if not frame.GetParent then
            break
        end
        frame = frame:GetParent()
    end
    return false
end

function UI:CreateMenuFrame(name)
    local menu = CreateBackdropFrame("Frame", name, UIParent)
    menu:SetFrameStrata("TOOLTIP")
    ApplyBackdrop(menu, MENU_BACKDROP, 0.015, 0.015, 0.02, 0.99)
    menu.buttons = {}
    menu:Hide()
    return menu
end

function UI:FillMenu(menu, options, width)
    menu:SetSize(width, #options * 22 + 8)
    for index, option in ipairs(options) do
        local currentOption = option
        local button = menu.buttons[index]
        if not button then
            button = CreateFrame("Button", nil, menu)
            button:SetHeight(22)
            button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            button.check = button:CreateTexture(nil, "OVERLAY")
            button.check:SetSize(18, 18)
            button.check:SetPoint("LEFT", 1, 0)
            button.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            button.check:SetVertexColor(0.45, 1, 0.45)
            button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            button.text:SetPoint("LEFT", 21, 0)
            button.text:SetPoint("RIGHT", -18, 0)
            button.text:SetJustifyH("LEFT")
            button.arrow = button:CreateTexture(nil, "OVERLAY")
            button.arrow:SetSize(12, 12)
            button.arrow:SetPoint("RIGHT", -4, 0)
            button.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
            menu.buttons[index] = button
        end
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", 4, -4 - (index - 1) * 22)
        button:SetPoint("TOPRIGHT", -4, -4 - (index - 1) * 22)
        button.check:SetShown(currentOption.checked)
        button.text:SetText(currentOption.text)
        button.arrow:SetShown(currentOption.children ~= nil)
        button:SetEnabled(not currentOption.disabled)
        button:SetAlpha(currentOption.disabled and 0.45 or 1)
        button:SetScript("OnEnter", function(owner)
            if currentOption.children then
                self:OpenSubmenu(owner, currentOption.children, currentOption.childWidth or 150)
            elseif menu == self.menu then
                self.submenu:Hide()
            end
        end)
        button:SetScript("OnClick", function()
            if currentOption.children then
                self:OpenSubmenu(button, currentOption.children, currentOption.childWidth or 150)
                return
            end
            self:CloseMenus()
            if currentOption.onSelect then
                currentOption.onSelect(currentOption.value)
            end
        end)
        button:Show()
    end
    for index = #options + 1, #menu.buttons do
        menu.buttons[index]:Hide()
    end
end

function UI:OpenMenu(owner, options, width, point, relativePoint)
    self:CloseMenus()
    local menu = self.menu
    menu.owner = owner
    menu:ClearAllPoints()
    menu:SetPoint(point or "TOPLEFT", owner, relativePoint or "BOTTOMLEFT", 0, -2)
    self:FillMenu(menu, options, width)
    menu:Show()
end

function UI:OpenSubmenu(owner, options, width)
    local submenu = self.submenu
    submenu:ClearAllPoints()
    submenu:SetPoint("TOPLEFT", owner, "TOPRIGHT", 2, 0)
    self:FillMenu(submenu, options, width)
    submenu:Show()
end

function UI:CloseMenus()
    if self.menu then
        self.menu:Hide()
        self.menu.owner = nil
    end
    if self.submenu then
        self.submenu:Hide()
    end
end

function UI:GetClassOptions()
    local options = {}
    for classID = 1, 11 do
        local currentClassID = classID
        local name, classFile = Addon:GetClassInfo(currentClassID)
        if name then
            local children = {
                {
                    text = ALL_SPECS or "全部专精",
                    value = 0,
                    checked = Addon.db.filters.classID == currentClassID and Addon.db.filters.specID == 0,
                    onSelect = function(value)
                        Addon.db.filters.classID = currentClassID
                        Addon.db.filters.specID = value
                        self:UpdateControls()
                        self:QueueRefresh()
                    end,
                },
            }
            for index = 1, Addon:GetNumSpecsForClass(currentClassID) do
                local specID, specName = Addon:GetSpecInfoForClass(currentClassID, index)
                if specID then
                    local currentSpecID = specID
                    table.insert(children, {
                        text = specName or tostring(currentSpecID),
                        value = currentSpecID,
                        checked = Addon.db.filters.classID == currentClassID
                            and Addon.db.filters.specID == currentSpecID,
                        onSelect = function(value)
                            Addon.db.filters.classID = currentClassID
                            Addon.db.filters.specID = value
                            self:UpdateControls()
                            self:QueueRefresh()
                        end,
                    })
                end
            end
            table.insert(options, {
                text = GetClassColorText(name, classFile),
                children = children,
                childWidth = 155,
            })
        end
    end
    return options
end

function UI:GetSlotOptions()
    local options = {
        {
            text = FAVORITES or "收藏",
            value = "FAVORITES",
            checked = Addon.db.filters.favoritesOnly,
            onSelect = function()
                Addon.db.filters.favoritesOnly = true
                Addon.db.filters.slot = "ALL"
                self:UpdateControls()
                self:QueueRefresh()
            end,
        },
    }
    for _, slot in ipairs(Addon.Journal.SLOT_OPTIONS) do
        local currentSlot = slot
        table.insert(options, {
            text = currentSlot.name,
            value = currentSlot.key,
            checked = not Addon.db.filters.favoritesOnly and Addon.db.filters.slot == currentSlot.key,
            onSelect = function(value)
                Addon.db.filters.favoritesOnly = false
                Addon.db.filters.slot = value
                self:UpdateControls()
                self:QueueRefresh()
            end,
        })
    end
    return options
end

function UI:GetDifficultyOptions()
    local options = {}
    for _, difficulty in ipairs(Addon.Journal.RAID_DIFFICULTIES) do
        local currentDifficulty = difficulty
        table.insert(options, {
            text = Addon.Journal:GetDifficultyName(currentDifficulty),
            value = currentDifficulty.id,
            checked = Addon.db.filters.difficulty == currentDifficulty.id,
            onSelect = function(value)
                Addon.db.filters.difficulty = value
                self:UpdateControls()
                self:QueueRefresh()
            end,
        })
    end
    return options
end

function UI:GetSettingsOptions()
    return {
        {
            text = "进本收藏提醒",
            checked = Addon.db.settings.reminders,
            onSelect = function()
                Addon.db.settings.reminders = not Addon.db.settings.reminders
                Addon:Print("副本收藏提醒已" .. (Addon.db.settings.reminders and "开启" or "关闭"))
            end,
        },
        {
            text = "显示小地图按钮",
            checked = Addon.db.settings.minimap,
            onSelect = function()
                Addon.db.settings.minimap = not Addon.db.settings.minimap
                self.minimapButton:SetShown(Addon.db.settings.minimap)
            end,
        },
        {
            text = "重置窗口位置",
            onSelect = function()
                Addon:ResetPosition()
            end,
        },
        {
            text = "刷新掉落数据",
            onSelect = function()
                Addon.Journal:RefreshInstances()
                self:QueueRefresh()
            end,
        },
    }
end

function UI:GetClassLabel()
    local classID = Addon.db.filters.classID
    local className, classFile = Addon:GetClassInfo(classID)
    if not className then
        return CLASS or "职业"
    end
    local label = GetClassColorText(className, classFile)
    if Addon.db.filters.specID ~= 0 then
        label = label .. "（" .. Addon:GetSpecName(Addon.db.filters.specID) .. "）"
    end
    return label
end

function UI:GetSlotLabel()
    if Addon.db.filters.favoritesOnly then
        return FAVORITES or "收藏"
    end
    for _, slot in ipairs(Addon.Journal.SLOT_OPTIONS) do
        if slot.key == Addon.db.filters.slot then
            return slot.name
        end
    end
    return ALL_INVENTORY_SLOTS or "全部装备部位"
end

function UI:GetDifficultyLabel()
    for _, difficulty in ipairs(Addon.Journal.RAID_DIFFICULTIES) do
        if difficulty.id == Addon.db.filters.difficulty then
            return Addon.Journal:GetDifficultyName(difficulty)
        end
    end
    return "难度"
end

function UI:UpdateControls()
    if not self.frame then
        return
    end
    self.classDropdown.text:SetText(self:GetClassLabel())
    self.slotDropdown.text:SetText(self:GetSlotLabel())
    self.difficultyDropdown.text:SetText(self:GetDifficultyLabel())
end

function UI:QueueRefresh(delay)
    self.refreshSerial = (self.refreshSerial or 0) + 1
    local serial = self.refreshSerial
    C_Timer.After(delay or 0, function()
        if serial == self.refreshSerial and self.frame and self.frame:IsShown() then
            self:Refresh()
        end
    end)
end

function UI:FilterLoot(items)
    local results = {}
    local filters = Addon.db.filters
    for _, item in ipairs(items) do
        local favorite = Addon:GetFavorite(item)
        if Addon.Journal:IsDisplayableLoot(item)
            and Addon.Journal:ItemMatchesSlot(item, filters.slot)
            and (not filters.favoritesOnly or favorite) then
            table.insert(results, item)
        end
    end
    table.sort(results, function(a, b)
        local aFavorite = Addon:GetFavorite(a)
        local bFavorite = Addon:GetFavorite(b)
        local aTier = aFavorite and aFavorite.tier or 0
        local bTier = bFavorite and bFavorite.tier or 0
        if aTier ~= bTier then
            return aTier > bTier
        end
        return a.itemID < b.itemID
    end)
    return results
end

function UI:BuildRows()
    local filters = Addon.db.filters
    Addon.Journal:SetContext(filters.difficulty, filters.classID, filters.specID)
    local rows = {}
    local instance = Addon.Journal:GetInstance()
    if not instance then
        return rows
    end

    for _, encounter in ipairs(Addon.Journal:GetEncounters(instance)) do
        Addon.Journal:SetContext(filters.difficulty, filters.classID, filters.specID)
        local items = self:FilterLoot(Addon.Journal:GetEncounterLoot(instance, encounter))
        table.insert(rows, {
            name = encounter.name,
            icon = GetPortraitTexture(encounter.encounterID),
            items = items,
            source = {
                instanceID = instance.instanceID,
                mapID = instance.mapID,
                difficultyID = filters.difficulty,
                instanceName = instance.name,
                encounterID = encounter.encounterID,
                encounterName = encounter.name,
                journalInstanceID = instance.journalInstanceID,
            },
        })
    end
    return rows
end

function UI:Refresh()
    self:CloseMenus()
    self:RefreshTierPanel()
    for _, row in ipairs(self.rowPool) do
        row:Hide()
    end

    if not Addon.Journal.available or not Addon.Journal:GetInstance() then
        self.emptyText:SetText(Addon.Journal.error or "地下城手册不可用")
        self.emptyText:Show()
        return
    end

    local rows = self:BuildRows()
    for index, data in ipairs(rows) do
        local row = self:GetRow(index)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
        self:SetRow(row, data, index)
        row.divider:SetShown(index < #rows)
        row:Show()
    end

    local contentHeight = math.max(1, #rows * ROW_HEIGHT)
    self.content:SetHeight(contentHeight)
    self.scrollFrame:SetVerticalScroll(0)
    self.emptyText:SetShown(#rows == 0)
    if #rows == 0 then
        self.emptyText:SetText(Addon.db.filters.favoritesOnly
            and "当前筛选条件下没有收藏物品"
            or "当前筛选条件下没有掉落数据")
    end

    local desiredHeight = HEADER_HEIGHT + FOOTER_HEIGHT + contentHeight + 14
    local maximumHeight = math.max(430, UIParent:GetHeight() - 40)
    self.frame:SetHeight(math.min(desiredHeight, maximumHeight))
end

function UI:GetRow(index)
    local row = self.rowPool[index]
    if row then
        return row
    end

    row = CreateFrame("Frame", nil, self.content)
    row:SetSize(ROW_WIDTH, ROW_HEIGHT)
    row.background = row:CreateTexture(nil, "BACKGROUND")
    row.background:SetAllPoints()
    row.background:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    row.background:SetVertexColor(0, 0, 0, 0.16)

    row.portraitButton = CreateFrame("Button", nil, row)
    row.portraitButton:SetSize(34, 34)
    row.portraitButton:SetPoint("LEFT", 7, 0)
    row.portraitButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    row.portrait = row.portraitButton:CreateTexture(nil, "ARTWORK")
    row.portrait:SetSize(24, 24)
    row.portrait:SetPoint("CENTER")
    row.portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.portraitBorder = row.portraitButton:CreateTexture(nil, "OVERLAY")
    row.portraitBorder:SetSize(42, 42)
    row.portraitBorder:SetPoint("CENTER", row.portrait)
    row.portraitBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    row.portraitButton:SetScript("OnClick", function()
        local source = row.source
        if source and EncounterJournal_OpenJournal then
            EncounterJournal_OpenJournal(Addon.db.filters.difficulty, source.journalInstanceID, source.encounterID)
        end
    end)
    row.portraitButton:SetScript("OnEnter", function(owner)
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetText(row.name:GetText(), 1, 0.82, 0)
        GameTooltip:AddLine("点击打开地下城手册", 0.65, 0.8, 1)
        GameTooltip:Show()
    end)
    row.portraitButton:SetScript("OnLeave", GameTooltip_Hide)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    row.name:SetPoint("LEFT", row.portrait, "RIGHT", 8, 0)
    row.name:SetWidth(178)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.divider = row:CreateTexture(nil, "OVERLAY")
    row.divider:SetHeight(1)
    row.divider:SetPoint("BOTTOMLEFT", 12, 0)
    row.divider:SetPoint("BOTTOMRIGHT", -12, 0)
    row.divider:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.divider:SetVertexColor(0.45, 0.38, 0.55, 0.38)

    row.back = CreateFrame("Button", nil, row)
    row.back:SetSize(20, 24)
    row.back:SetPoint("LEFT", 224, 0)
    row.back:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    row.back:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    row.back:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    row.back:SetScript("OnClick", function()
        row.offset = math.max(1, row.offset - ITEMS_PER_PAGE)
        self:RefreshRowItems(row)
    end)

    row.next = CreateFrame("Button", nil, row)
    row.next:SetSize(20, 24)
    row.next:SetPoint("RIGHT", -1, 0)
    row.next:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    row.next:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    row.next:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    row.next:SetScript("OnClick", function()
        row.offset = math.min(math.max(1, #row.items - ITEMS_PER_PAGE + 1), row.offset + ITEMS_PER_PAGE)
        self:RefreshRowItems(row)
    end)

    row.itemButtons = {}
    for slot = 1, ITEMS_PER_PAGE do
        local itemButton = self:CreateItemButton(row)
        itemButton:SetPoint("LEFT", 248 + (slot - 1) * ITEM_STEP, 0)
        row.itemButtons[slot] = itemButton
    end

    self.rowPool[index] = row
    return row
end

function UI:SetRow(row, data, index)
    row.name:SetText(data.name)
    row.portrait:SetTexture(data.icon)
    row.background:SetAlpha(index % 2 == 0 and 1 or 0)
    row.items = data.items
    row.source = data.source
    row.offset = 1

    local hasLoot = #data.items > 0
    row.name:SetTextColor(hasLoot and 1 or 0.5, hasLoot and 1 or 0.5, hasLoot and 1 or 0.5)
    row.portrait:SetDesaturated(not hasLoot)
    row:SetAlpha(hasLoot and 1 or 0.72)
    self:RefreshRowItems(row)
end

function UI:RefreshRowItems(row)
    local hasLoot = #row.items > 0
    for slot, button in ipairs(row.itemButtons) do
        local item = row.items[row.offset + slot - 1]
        self:SetItemButton(button, item, row.source)
        button:SetShown(hasLoot)
    end
    row.back:SetShown(row.offset > 1)
    row.next:SetShown(row.offset + ITEMS_PER_PAGE - 1 < #row.items)
end

function UI:CreateItemButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(34, 34)
    button:EnableMouseWheel(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button.empty = button:CreateTexture(nil, "BACKGROUND")
    button.empty:SetSize(28, 28)
    button.empty:SetPoint("CENTER")
    button.empty:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    button.empty:SetVertexColor(0.08, 0.08, 0.10, 0.7)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(28, 28)
    button.icon:SetPoint("CENTER")
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.border = button:CreateTexture(nil, "ARTWORK")
    button.border:SetDrawLayer("ARTWORK", 3)
    button.border:SetSize(52, 52)
    button.border:SetPoint("CENTER", button.icon)
    button.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    button.favoriteFrame = CreateFrame("Frame", nil, button)
    button.favoriteFrame:SetAllPoints(button)
    button.favoriteFrame:SetFrameLevel(button:GetFrameLevel() + 10)
    button.favorite = button.favoriteFrame:CreateTexture(nil, "OVERLAY")
    button.favorite:SetDrawLayer("OVERLAY", 7)
    button.favorite:SetSize(18, 18)
    button.favorite:SetPoint("TOPRIGHT", button.icon, "TOPRIGHT", 5, 6)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    button:SetScript("OnEnter", function(owner)
        if not owner.item then
            return
        end
        owner.isHovered = true
        self:ShowItemTooltip(owner)
        self:UpdateFavoriteIcon(owner)
    end)
    button:SetScript("OnLeave", function(owner)
        GameTooltip_Hide()
        owner.isHovered = false
        self:UpdateFavoriteIcon(owner)
    end)
    button:SetScript("OnMouseWheel", function(_, delta)
        self:ScrollCompetitionTooltip(delta)
    end)
    button:SetScript("OnClick", function(owner, mouseButton)
        if not owner.item then
            return
        end
        if mouseButton == "LeftButton" and IsModifierKeyDown() and owner.item.link then
            HandleModifiedItemClick(owner.item.link)
            return
        end
        GameTooltip:Hide()
        if mouseButton == "LeftButton" then
            self:CloseMenus()
            self:ShowCompetitionTooltip(owner)
        else
            self:OpenItemMenu(owner)
        end
    end)
    return button
end

function UI:SetItemButton(button, item, source)
    local previousItemID = button.item and button.item.itemID
    local nextItemID = item and item.itemID
    if self.competitionTooltip and self.competitionTooltip.owner == button
        and previousItemID ~= nextItemID then
        if Addon.Competition then
            Addon.Competition:Cancel(button)
        end
        self:HideCompetitionTooltip(button)
    end

    button.favoriteFrame:SetFrameLevel(button:GetFrameLevel() + 10)
    button.item = item
    button.source = source
    button:SetEnabled(item ~= nil)
    button.icon:SetShown(item ~= nil)
    button.empty:Show()
    if item then
        button.icon:SetTexture(item.icon or 134400)
        button:SetAlpha(1)
    else
        button.icon:SetTexture(nil)
        button.favorite:Hide()
        button:SetAlpha(0.55)
    end
    self:UpdateFavoriteIcon(button)
end

function UI:UpdateFavoriteIcon(button)
    if not button.item then
        button.favorite:Hide()
        return
    end
    local favorite = Addon:GetFavorite(button.item)
    if favorite then
        button.favorite:SetTexture(FAVORITE_TEXTURES[favorite.tier] or FAVORITE_TEXTURES[2])
        button.favorite:SetDesaturated(false)
        button.favorite:Show()
    elseif button.isHovered then
        button.favorite:SetTexture(FAVORITE_TEXTURES[2])
        button.favorite:SetDesaturated(true)
        button.favorite:Show()
    else
        button.favorite:Hide()
    end
end

function UI:OpenItemMenu(button)
    local favorite = Addon:GetFavorite(button.item)
    local options = {}
    for tierID = 1, 4 do
        local currentTierID = tierID
        local tier = Addon.TIERS[currentTierID]
        table.insert(options, {
            text = tier.name,
            checked = favorite and favorite.tier == currentTierID,
            onSelect = function()
                Addon:SetFavorite(button.item, button.source, currentTierID)
                self:UpdateFavoriteIcon(button)
                if Addon.db.filters.favoritesOnly then
                    self:QueueRefresh()
                end
            end,
        })
    end
    if favorite then
        table.insert(options, {
            text = REMOVE or "移除",
            onSelect = function()
                Addon:SetFavorite(button.item, button.source, nil)
                self:UpdateFavoriteIcon(button)
                if Addon.db.filters.favoritesOnly then
                    self:QueueRefresh()
                end
            end,
        })
    end
    self:OpenMenu(button, options, 145, "TOPLEFT", "BOTTOMRIGHT")
end

function UI:ShowPlainItemTooltip(owner, item, anchor)
    if not owner or not item then
        return
    end
    GameTooltip:SetFrameStrata("TOOLTIP")
    if GameTooltip.SetFrameLevel then
        local panelLevel = self.competitionTooltip and self.competitionTooltip:GetFrameLevel() or 0
        local ownerLevel = owner.GetFrameLevel and owner:GetFrameLevel() or 0
        GameTooltip:SetFrameLevel(math.max(200, panelLevel + 20, ownerLevel + 20))
    end
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    if item.link and string.find(item.link, "|Hitem:") then
        GameTooltip:SetHyperlink(item.link)
    elseif GameTooltip.SetItemByID and item.itemID then
        GameTooltip:SetItemByID(item.itemID)
    else
        GameTooltip:SetText(item.name or "未知装备")
    end
    GameTooltip:Show()
    if GameTooltip_HideShoppingTooltips then
        GameTooltip_HideShoppingTooltips(GameTooltip)
    end
end

local function GetCurrentEquippedItemLevel(slot)
    if ItemLocation and ItemLocation.CreateFromEquipmentSlot and C_Item and C_Item.GetCurrentItemLevel then
        local location = ItemLocation:CreateFromEquipmentSlot(slot)
        if location then
            local ok, itemLevel = pcall(C_Item.GetCurrentItemLevel, location)
            if ok and itemLevel then
                return tonumber(itemLevel)
            end
        end
    end
    if Item and Item.CreateFromEquipmentSlot then
        local ok, item = pcall(Item.CreateFromEquipmentSlot, Item, slot)
        if ok and item and item.GetCurrentItemLevel then
            local levelOK, itemLevel = pcall(item.GetCurrentItemLevel, item)
            if levelOK and itemLevel then
                return tonumber(itemLevel)
            end
        end
    end
    return nil
end

local function FindExactEquippedUpgradeSlot(item)
    if not item or not item.itemID or not item.itemLevel or not GetInventoryItemID then
        return nil
    end
    local targetItemLevel = tonumber(item.itemLevel)
    for slot = 1, 19 do
        if GetInventoryItemID("player", slot) == item.itemID then
            local currentItemLevel = GetCurrentEquippedItemLevel(slot)
            if currentItemLevel and targetItemLevel and currentItemLevel == targetItemLevel then
                return slot
            end
        end
    end
    return nil
end

local function FormatTooltipNumber(value)
    value = math.floor((tonumber(value) or 0) + 0.5)
    if BreakUpLargeNumbers then
        return BreakUpLargeNumbers(value)
    end
    return tostring(value)
end

local function EscapeLuaPattern(value)
    return (string.gsub(value, "([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

local function ReplaceTooltipNumber(text, oldValue, newValue)
    local formattedOld = FormatTooltipNumber(oldValue)
    local formattedNew = FormatTooltipNumber(newValue)
    local pattern = "%f[%d]" .. EscapeLuaPattern(formattedOld) .. "%f[%D]"
    local replaced, count = string.gsub(text, pattern, formattedNew)
    if count == 0 and formattedOld ~= tostring(oldValue) then
        pattern = "%f[%d]" .. EscapeLuaPattern(tostring(oldValue)) .. "%f[%D]"
        replaced = string.gsub(text, pattern, formattedNew)
    end
    return replaced
end

local function GetBaseItemStats(link)
    if C_Item and C_Item.GetItemStats then
        local ok, stats = pcall(C_Item.GetItemStats, link)
        if ok then
            return stats
        end
    end
    if _G.GetItemStats then
        local ok, stats = pcall(_G.GetItemStats, link)
        if ok then
            return stats
        end
    end
    return nil
end

local function CopyTooltipFontString(source, target, copyWrapping)
    if not source or not target then
        return
    end
    if copyWrapping then
        local sourceWidth = source:GetWidth()
        if target.SetWordWrap then
            target:SetWordWrap(true)
        end
        if target.SetNonSpaceWrap then
            target:SetNonSpaceWrap(true)
        end
        if sourceWidth and sourceWidth > 0 then
            target:SetWidth(sourceWidth)
        end
    end
    target:SetText(source:GetText())
    local red, green, blue, alpha = source:GetTextColor()
    if red then
        target:SetTextColor(red, green, blue, alpha)
    end
end

local function MoveTooltipTexturesAfterLine(tooltip, lineIndex)
    local tooltipName = tooltip:GetName()
    local escapedTooltipName = EscapeLuaPattern(tooltipName)
    for textureIndex = 1, 20 do
        local texture = _G[tooltipName .. "Texture" .. textureIndex]
        if texture then
            local points = {}
            local shouldMove = false
            for pointIndex = 1, texture:GetNumPoints() do
                local point, relativeTo, relativePoint, offsetX, offsetY = texture:GetPoint(pointIndex)
                local relativeName = relativeTo and relativeTo.GetName and relativeTo:GetName()
                local side, relativeLine = relativeName and string.match(
                    relativeName,
                    "^" .. escapedTooltipName .. "Text(Left)(%d+)$"
                )
                if not side then
                    side, relativeLine = relativeName and string.match(
                        relativeName,
                        "^" .. escapedTooltipName .. "Text(Right)(%d+)$"
                    )
                end
                relativeLine = tonumber(relativeLine)
                if relativeLine and relativeLine > lineIndex then
                    relativeTo = _G[tooltipName .. "Text" .. side .. (relativeLine + 1)] or relativeTo
                    shouldMove = true
                end
                table.insert(points, { point, relativeTo, relativePoint, offsetX, offsetY })
            end
            if shouldMove then
                texture:ClearAllPoints()
                for _, pointData in ipairs(points) do
                    texture:SetPoint(unpack(pointData))
                end
            end
        end
    end
end

local function InsertUpgradeLineAfter(tooltip, lineIndex)
    if not lineIndex then
        tooltip:AddLine("升级：2/2", 1, 0.82, 0)
        return
    end

    local tooltipName = tooltip:GetName()
    local originalLineCount = tooltip:NumLines()
    -- The added row can receive the original tooltip's final description
    -- while rows are shifted down.  It must be a wrapping row or long equip
    -- effects will be laid out as one line and widen the whole tooltip.
    tooltip:AddLine(" ", 1, 1, 1, true)
    MoveTooltipTexturesAfterLine(tooltip, lineIndex)

    for sourceIndex = originalLineCount, lineIndex + 1, -1 do
        CopyTooltipFontString(
            _G[tooltipName .. "TextLeft" .. sourceIndex],
            _G[tooltipName .. "TextLeft" .. (sourceIndex + 1)],
            true
        )
        CopyTooltipFontString(
            _G[tooltipName .. "TextRight" .. sourceIndex],
            _G[tooltipName .. "TextRight" .. (sourceIndex + 1)]
        )
    end

    local upgradeLeft = _G[tooltipName .. "TextLeft" .. (lineIndex + 1)]
    local upgradeRight = _G[tooltipName .. "TextRight" .. (lineIndex + 1)]
    if upgradeLeft then
        upgradeLeft:SetText("升级：2/2")
        upgradeLeft:SetTextColor(1, 0.82, 0)
    end
    if upgradeRight then
        upgradeRight:SetText(nil)
    end
end

function UI:ApplyMaxUpgradePreview(tooltip, item)
    if not tooltip or not item or item.upgradeLevel ~= 2 or not item.baseItemLevel or not item.itemLevel then
        return
    end

    local tooltipName = tooltip:GetName()
    local itemLevelPrefix = ITEM_LEVEL and string.match(ITEM_LEVEL, "^(.-)%%d")
    local itemLevelLineIndex
    local statReplacements = {}
    local stats = GetBaseItemStats(item.link)
    local itemLevelGain = math.max(0, tonumber(item.itemLevel) - tonumber(item.baseItemLevel))
    local scale = math.pow(1.15, itemLevelGain / 15)
    for _, baseValue in pairs(stats or {}) do
        baseValue = tonumber(baseValue)
        if baseValue and baseValue > 0 then
            local upgradedValue = math.floor(baseValue * scale + 0.5)
            if upgradedValue ~= baseValue then
                table.insert(statReplacements, { base = baseValue, upgraded = upgradedValue })
            end
        end
    end
    table.sort(statReplacements, function(left, right)
        return left.base > right.base
    end)

    for lineIndex = 1, tooltip:NumLines() do
        local left = _G[tooltipName .. "TextLeft" .. lineIndex]
        local text = left and left:GetText()
        if text and itemLevelPrefix and string.find(text, itemLevelPrefix, 1, true) then
            left:SetText(string.format(ITEM_LEVEL, item.itemLevel))
            itemLevelLineIndex = lineIndex
        elseif text then
            local red, green, blue = left:GetTextColor()
            if red and red > 0.75 and green > 0.75 and blue > 0.75 then
                for _, replacement in ipairs(statReplacements) do
                    text = ReplaceTooltipNumber(text, replacement.base, replacement.upgraded)
                end
                left:SetText(text)
            end
        end
    end

    InsertUpgradeLineAfter(tooltip, itemLevelLineIndex)
    tooltip:Show()
end

function UI:ShowItemTooltip(button)
    if button:GetCenter() and button:GetCenter() > GetScreenWidth() / 2 then
        GameTooltip:SetOwner(button, "ANCHOR_BOTTOMLEFT", 0, 12)
    else
        GameTooltip:SetOwner(button, "ANCHOR_BOTTOMRIGHT", 0, 12)
    end
    local exactEquippedSlot = FindExactEquippedUpgradeSlot(button.item)
    local usedEquippedTooltip = false
    if exactEquippedSlot and GameTooltip.SetInventoryItem then
        local ok = pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", exactEquippedSlot)
        usedEquippedTooltip = ok and GameTooltip:NumLines() > 0
    end
    if not usedEquippedTooltip and button.item.link and string.find(button.item.link, "|Hitem:") then
        GameTooltip:SetHyperlink(button.item.link)
    elseif not usedEquippedTooltip and GameTooltip.SetItemByID then
        GameTooltip:SetItemByID(button.item.itemID)
    elseif not usedEquippedTooltip then
        GameTooltip:SetText(button.item.name or ("物品 " .. button.item.itemID))
    end
    GameTooltip:Show()
    if GameTooltip_ShowCompareItem then
        GameTooltip_ShowCompareItem(GameTooltip)
    end
    if not usedEquippedTooltip then
        self:ApplyMaxUpgradePreview(GameTooltip, button.item)
    end
end

function UI:CreateMinimapButton()
    local button = CreateFrame("Button", "KeystoneLootMistsMinimapButton", Minimap)
    self.minimapButton = button
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(24, 24)
    background:SetPoint("CENTER")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER")
    icon:SetTexture(ADDON_ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local function UpdatePosition()
        local angle = math.rad(Addon.db.settings.minimapAngle or 205)
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
    end

    button:SetScript("OnDragStart", function()
        button:SetScript("OnUpdate", function()
            local scale = UIParent:GetEffectiveScale()
            local cursorX, cursorY = GetCursorPosition()
            local centerX, centerY = Minimap:GetCenter()
            cursorX, cursorY = cursorX / scale, cursorY / scale
            Addon.db.settings.minimapAngle = math.deg(math.atan2(cursorY - centerY, cursorX - centerX))
            UpdatePosition()
        end)
    end)
    button:SetScript("OnDragStop", function()
        button:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            self:ToggleTeamTierFrame()
        else
            self:Toggle()
        end
    end)
    button:SetScript("OnEnter", function(owner)
        GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
        GameTooltip:SetText("KeystoneLoot（熊猫人之谜）", 1, 0.82, 0)
        GameTooltip:AddLine("左键：打开掉落总览", 1, 1, 1)
        GameTooltip:AddLine("右键：查看队伍套装", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    UpdatePosition()
    button:SetShown(Addon.db.settings.minimap)
end

function UI:Toggle()
    if self.frame then
        if self.teamTierFrame and self.teamTierFrame:IsShown() then
            self.teamTierFrame:Hide()
        end
        self.frame:SetShown(not self.frame:IsShown())
    end
end
