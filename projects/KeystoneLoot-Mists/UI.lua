local _, Addon = ...

local UI = {}
Addon.UI = UI

local WINDOW_WIDTH = 500
local HEADER_HEIGHT = 82
local FOOTER_HEIGHT = 26
local ROW_WIDTH = 486
local ROW_HEIGHT = 44
local ITEMS_PER_PAGE = 6
local ITEM_STEP = 38
local TIER_PANEL_WIDTH = 58
local TIER_PANEL_HEIGHT = 230
local ADDON_ICON = "Interface\\Icons\\INV_Misc_Map02"

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
    end)
    frame:SetScript("OnShow", function()
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
        frame.Inset:SetPoint("BOTTOMRIGHT", -3, 25)
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

    self.footerText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    self.footerText:SetPoint("BOTTOM", 0, 8)
    self.footerText:SetWidth(450)
    self.footerText:SetText("决战奥格瑞玛 · 左键物品设置收藏 · Shift+左键发送链接")

    self.rowPool = {}
    self:CreateTierPanel(frame)
    self:CreateMenus()
    self:CreateMinimapButton()
    self:UpdateControls()
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
    self.footerText:SetText(("决战奥格瑞玛 · %d 个首领 · %s"):format(#rows, self:GetDifficultyLabel()))
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
        self:ShowItemTooltip(owner)
        owner.isHovered = true
        self:UpdateFavoriteIcon(owner)
    end)
    button:SetScript("OnLeave", function(owner)
        GameTooltip_Hide()
        owner.isHovered = false
        self:UpdateFavoriteIcon(owner)
    end)
    button:SetScript("OnClick", function(owner)
        if not owner.item then
            return
        end
        if IsModifierKeyDown() and owner.item.link then
            HandleModifiedItemClick(owner.item.link)
            return
        end
        GameTooltip:Hide()
        self:OpenItemMenu(owner)
    end)
    return button
end

function UI:SetItemButton(button, item, source)
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

function UI:ShowItemTooltip(button)
    if button:GetCenter() and button:GetCenter() > GetScreenWidth() / 2 then
        GameTooltip:SetOwner(button, "ANCHOR_BOTTOMLEFT", 0, 12)
    else
        GameTooltip:SetOwner(button, "ANCHOR_BOTTOMRIGHT", 0, 12)
    end
    if button.item.link then
        GameTooltip:SetHyperlink(button.item.link)
    elseif GameTooltip.SetItemByID then
        GameTooltip:SetItemByID(button.item.itemID)
    else
        GameTooltip:SetText(button.item.name or ("物品 " .. button.item.itemID))
    end
    GameTooltip:Show()
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
            Addon.db.settings.reminders = not Addon.db.settings.reminders
            Addon:Print("副本收藏提醒已" .. (Addon.db.settings.reminders and "开启" or "关闭"))
        else
            self:Toggle()
        end
    end)
    button:SetScript("OnEnter", function(owner)
        GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
        GameTooltip:SetText("KeystoneLoot（熊猫人之谜）", 1, 0.82, 0)
        GameTooltip:AddLine("左键：打开掉落总览", 1, 1, 1)
        GameTooltip:AddLine("右键：切换进本提醒", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    UpdatePosition()
    button:SetShown(Addon.db.settings.minimap)
end

function UI:Toggle()
    if self.frame then
        self.frame:SetShown(not self.frame:IsShown())
    end
end
