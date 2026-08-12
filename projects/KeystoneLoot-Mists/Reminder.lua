local _, Addon = ...

local Reminder = {}
Addon.Reminder = Reminder

local BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 24,
    insets = { left = 7, right = 7, top = 7, bottom = 7 },
}

function Reminder:Create()
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "KeystoneLootMistsReminderFrame", UIParent, template)
    self.frame = frame
    frame:SetSize(430, 122)
    frame:SetPoint("TOP", 0, -160)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    if frame.SetBackdrop then
        frame:SetBackdrop(BACKDROP)
        frame:SetBackdropColor(0.025, 0.02, 0.04, 0.98)
    end
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 18, -17)
    frame.title:SetText("收藏掉落提醒")
    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -4)
    frame.subtitle:SetWidth(385)
    frame.subtitle:SetJustifyH("LEFT")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    frame.icons = {}
end

function Reminder:GetFavoritesForInstance(instanceID)
    local results = {}
    for itemID, favorite in pairs(Addon:GetFavorites()) do
        if favorite.sourceInstanceID == instanceID or favorite.sourceMapID == instanceID then
            table.insert(results, {
                itemID = favorite.itemID or tonumber(itemID),
                name = favorite.name,
                link = favorite.link,
                icon = favorite.icon,
                tier = favorite.tier,
                encounterName = favorite.encounterName,
            })
        end
    end
    table.sort(results, function(a, b)
        if a.tier ~= b.tier then
            return a.tier > b.tier
        end
        return tostring(a.itemID or "") < tostring(b.itemID or "")
    end)
    return results
end

function Reminder:Show(instanceName, items)
    local frame = self.frame
    frame.subtitle:SetText(("%s：有 %d 件收藏物品"):format(instanceName, #items))

    for _, button in ipairs(frame.icons) do
        button:Hide()
    end

    for index = 1, math.min(#items, 9) do
        local item = items[index]
        local button = frame.icons[index]
        if not button then
            button = CreateFrame("Button", nil, frame)
            button:SetSize(38, 38)
            button.icon = button:CreateTexture(nil, "ARTWORK")
            button.icon:SetAllPoints()
            button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            button.border = button:CreateTexture(nil, "OVERLAY")
            button.border:SetAllPoints()
            button.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
            button.border:SetBlendMode("ADD")
            button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
            button:SetScript("OnEnter", function(owner)
                GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
                if owner.item.link then
                    GameTooltip:SetHyperlink(owner.item.link)
                elseif GameTooltip.SetItemByID then
                    GameTooltip:SetItemByID(owner.item.itemID)
                end
                GameTooltip:Show()
            end)
            button:SetScript("OnLeave", GameTooltip_Hide)
            button:SetScript("OnClick", function(owner)
                if owner.item.link then
                    HandleModifiedItemClick(owner.item.link)
                end
            end)
            frame.icons[index] = button
        end
        button:ClearAllPoints()
        button:SetPoint("BOTTOMLEFT", 18 + (index - 1) * 43, 15)
        button.item = item
        button.icon:SetTexture(item.icon or 134400)
        local tier = Addon.TIERS[item.tier] or Addon.TIERS[1]
        button.border:SetVertexColor(unpack(tier.color))
        button:Show()
    end

    frame:Show()
    if PlaySound and SOUNDKIT and SOUNDKIT.READY_CHECK then
        PlaySound(SOUNDKIT.READY_CHECK)
    end
end

function Reminder:OnEnteringWorld()
    C_Timer.After(2.5, function()
        if not Addon.db or not Addon.db.settings.reminders then
            return
        end

        local instanceName, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
        if instanceType == "none" or not instanceID or instanceID == 0 then
            self.lastInstanceID = nil
            return
        end
        if self.lastInstanceID == instanceID then
            return
        end
        self.lastInstanceID = instanceID

        local items = self:GetFavoritesForInstance(instanceID)
        if #items > 0 then
            self:Show(instanceName, items)
            Addon:Print(("进入 %s：有 %d 件收藏掉落"):format(instanceName, #items))
        end
    end)
end
