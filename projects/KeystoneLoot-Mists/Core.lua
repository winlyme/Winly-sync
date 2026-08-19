local ADDON_NAME, Addon = ...

_G.KeystoneLootMists = Addon

Addon.name = ADDON_NAME
Addon.displayName = "决战奥格瑞玛掉落"
Addon.version = "0.3.0"

Addon.TIERS = {
    [1] = { name = "可选", short = "选", color = { 0.20, 0.95, 0.35 }, hex = "33f259" },
    [2] = { name = "必需", short = "需", color = { 0.20, 0.60, 1.00 }, hex = "3399ff" },
    [3] = { name = "BIS", short = "B", color = { 1.00, 0.50, 0.10 }, hex = "ff8019" },
    [4] = { name = "幻化", short = "幻", color = { 0.75, 0.35, 1.00 }, hex = "bf59ff" },
}

local DEFAULTS = {
    version = 1,
    settings = {
        minimap = true,
        minimapAngle = 205,
        reminders = true,
    },
    filters = {
        classID = 0,
        specID = 0,
        slot = "ALL",
        difficulty = 14,
        favoritesOnly = false,
    },
    favorites = {},
}

local function CopyDefaults(source, target)
    if type(target) ~= "table" then
        target = {}
    end

    for key, value in pairs(source) do
        if type(value) == "table" then
            target[key] = CopyDefaults(value, target[key])
        elseif target[key] == nil then
            target[key] = value
        end
    end

    return target
end

function Addon:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff9d5db8KSL Mists:|r " .. tostring(message))
end

function Addon:GetCurrentClassID()
    local _, _, classID = UnitClass("player")
    return classID or 1
end

function Addon:GetCurrentSpecID()
    local specIndex
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        specIndex = C_SpecializationInfo.GetSpecialization()
    elseif _G.GetSpecialization then
        specIndex = _G.GetSpecialization()
    end

    if not specIndex then
        return 0
    end

    if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
        return C_SpecializationInfo.GetSpecializationInfo(specIndex) or 0
    elseif _G.GetSpecializationInfo then
        return _G.GetSpecializationInfo(specIndex) or 0
    end

    return 0
end

function Addon:GetClassInfo(classID)
    if C_CreatureInfo and C_CreatureInfo.GetClassInfo then
        local info = C_CreatureInfo.GetClassInfo(classID)
        if info then
            return info.className, info.classFile
        end
    end

    if _G.GetClassInfo then
        local name, file = _G.GetClassInfo(classID)
        return name, file
    end
end

function Addon:GetNumSpecsForClass(classID)
    if C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID then
        return C_SpecializationInfo.GetNumSpecializationsForClassID(classID) or 0
    elseif _G.GetNumSpecializationsForClassID then
        return _G.GetNumSpecializationsForClassID(classID) or 0
    end

    return 0
end

function Addon:GetSpecInfoForClass(classID, index)
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoForClassID then
        return C_SpecializationInfo.GetSpecializationInfoForClassID(classID, index)
    elseif _G.GetSpecializationInfoForClassID then
        return _G.GetSpecializationInfoForClassID(classID, index)
    end
end

function Addon:GetSpecName(specID)
    if specID == 0 then
        return "全部专精"
    end

    if _G.GetSpecializationInfoByID then
        local _, name = _G.GetSpecializationInfoByID(specID)
        if name then
            return name
        end
    end

    return tostring(specID)
end

function Addon:GetItemInfo(itemID)
    if C_Item and C_Item.GetItemInfo then
        return C_Item.GetItemInfo(itemID)
    elseif _G.GetItemInfo then
        return _G.GetItemInfo(itemID)
    end
end

function Addon:GetItemInfoInstant(itemID)
    if C_Item and C_Item.GetItemInfoInstant then
        return C_Item.GetItemInfoInstant(itemID)
    elseif _G.GetItemInfoInstant then
        return _G.GetItemInfoInstant(itemID)
    end
end

local function NormalizeItemName(name)
    if not name or name == "" or string.match(name, "^物品 %d+$") then
        return nil
    end
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")
    return string.lower(name)
end

function Addon:GetItemVariantKey(itemOrID)
    local itemID
    local name
    if type(itemOrID) == "table" then
        itemID = tonumber(itemOrID.itemID)
        name = itemOrID.name
    else
        itemID = tonumber(itemOrID)
    end

    if itemID and self.TierSets then
        local tierKey = self.TierSets:GetVariantKey(itemID)
        if tierKey then
            return tierKey, itemID
        end
    end

    if not name and itemID then
        name = self:GetItemInfo(itemID)
    end
    name = NormalizeItemName(name)
    if name then
        return "name:" .. name, itemID
    end
    return nil, itemID
end

function Addon:MigrateFavoriteVariants()
    for _, favorites in pairs(self.db.favorites) do
        if type(favorites) == "table" then
            local additions = {}
            local removals = {}
            for savedKey, favorite in pairs(favorites) do
                if type(favorite) == "table" then
                    local itemID = favorite.itemID or tonumber(savedKey)
                    local variantKey = favorite.variantKey
                    if not variantKey then
                        variantKey = self:GetItemVariantKey({ itemID = itemID, name = favorite.name })
                    end
                    if variantKey then
                        favorite.itemID = itemID
                        favorite.variantKey = variantKey
                        local existing = favorites[variantKey] or additions[variantKey]
                        if not existing or (favorite.tier or 0) > (existing.tier or 0) then
                            additions[variantKey] = favorite
                        end
                        if savedKey ~= variantKey then
                            table.insert(removals, savedKey)
                        end
                    end
                end
            end
            for _, savedKey in ipairs(removals) do
                favorites[savedKey] = nil
            end
            for variantKey, favorite in pairs(additions) do
                favorites[variantKey] = favorite
            end
        end
    end
end

function Addon:GetCharacterKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "Unknown"
    return realm .. "-" .. name
end

function Addon:InitializeDB()
    local previousDifficulty = KeystoneLootMistsDB
        and KeystoneLootMistsDB.filters
        and KeystoneLootMistsDB.filters.raidDifficulty
    KeystoneLootMistsDB = CopyDefaults(DEFAULTS, KeystoneLootMistsDB)
    self.db = KeystoneLootMistsDB

    -- 兼容首个开发版本留下的筛选字段。
    if previousDifficulty then
        self.db.filters.difficulty = previousDifficulty
    end

    -- 决战奥格瑞玛只保留弹性、普通和英雄；旧的 25 人选项合并到对应难度。
    local difficulty = tonumber(self.db.filters.difficulty)
    if difficulty == 4 then
        difficulty = 3
    elseif difficulty == 6 then
        difficulty = 5
    end
    if difficulty ~= 14 and difficulty ~= 3 and difficulty ~= 5 then
        difficulty = 14
    end
    self.db.filters.difficulty = difficulty

    if self.db.filters.classID == 0 then
        self.db.filters.classID = self:GetCurrentClassID()
        self.db.filters.specID = self:GetCurrentSpecID()
    end

    local key = self:GetCharacterKey()
    self.db.favorites[key] = self.db.favorites[key] or {}
    self:MigrateFavoriteVariants()
end

function Addon:GetFavorites()
    local key = self:GetCharacterKey()
    self.db.favorites[key] = self.db.favorites[key] or {}
    return self.db.favorites[key]
end

function Addon:GetFavorite(itemOrID)
    local favorites = self:GetFavorites()
    local variantKey, itemID = self:GetItemVariantKey(itemOrID)
    if variantKey and favorites[variantKey] then
        return favorites[variantKey]
    end
    return itemID and favorites[itemID] or nil
end

function Addon:SetFavorite(item, source, tier)
    if not item or not item.itemID then
        return
    end

    local favorites = self:GetFavorites()
    local itemID = tonumber(item.itemID)
    local variantKey = self:GetItemVariantKey(item)
    local savedKey = variantKey or itemID

    if not tier then
        favorites[itemID] = nil
        if variantKey then
            favorites[variantKey] = nil
        end
        return
    end

    if savedKey ~= itemID then
        favorites[itemID] = nil
    end
    favorites[savedKey] = {
        itemID = itemID,
        variantKey = variantKey,
        tier = tier,
        name = item.name,
        link = item.link,
        icon = item.icon,
        sourceInstanceID = source and source.instanceID,
        sourceMapID = source and source.mapID,
        sourceName = source and source.instanceName,
        encounterName = source and source.encounterName,
    }
end

function Addon:ToggleFavorite(item, source)
    local favorite = self:GetFavorite(item)
    self:SetFavorite(item, source, favorite and nil or 2)
end

function Addon:CycleFavorite(item, source)
    local favorite = self:GetFavorite(item)
    local tier = favorite and favorite.tier or 0
    tier = tier + 1
    if tier > 4 then
        tier = nil
    end
    self:SetFavorite(item, source, tier)
end

function Addon:ResetPosition()
    self.db.position = nil
    if self.UI and self.UI.frame then
        self.UI.frame:ClearAllPoints()
        self.UI.frame:SetPoint("CENTER")
    end
end

function Addon:HandleSlash(message)
    local command = string.lower(strtrim(message or ""))

    if command == "" or command == "show" then
        self.UI:Toggle()
    elseif command == "reminder" or command == "reminders" then
        self.db.settings.reminders = not self.db.settings.reminders
        self:Print("副本收藏提醒已" .. (self.db.settings.reminders and "开启" or "关闭"))
        self.UI:UpdateControls()
    elseif command == "minimap" then
        self.db.settings.minimap = not self.db.settings.minimap
        self.UI.minimapButton:SetShown(self.db.settings.minimap)
        self:Print("小地图按钮已" .. (self.db.settings.minimap and "显示" or "隐藏"))
    elseif command == "test" or command == "demo" then
        local shown = self.UI:ToggleCompetitionDemo()
        self:Print(shown and "队伍需求测试预览已打开；再次输入 /ksl test 可关闭"
            or "队伍需求测试预览已关闭")
    elseif command == "reset" then
        self:ResetPosition()
        self:Print("窗口位置已重置")
    else
        self:Print("命令：/ksl（打开界面）、/ksl test、/ksl reminder、/ksl minimap、/ksl reset")
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedName = ...
        if loadedName ~= ADDON_NAME then
            return
        end
        Addon:InitializeDB()
    elseif event == "PLAYER_LOGIN" then
        Addon.Journal:Initialize()
        Addon.UI:Create()
        Addon.Reminder:Create()
    elseif event == "PLAYER_ENTERING_WORLD" then
        if Addon.Reminder and Addon.Reminder.OnEnteringWorld then
            Addon.Reminder:OnEnteringWorld()
        end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        local unit = ...
        if unit == "player" and Addon.db and Addon.db.filters.classID == Addon:GetCurrentClassID() then
            Addon.db.filters.specID = Addon:GetCurrentSpecID()
            if Addon.UI and Addon.UI.frame and Addon.UI.frame:IsShown() then
                Addon.UI:UpdateControls()
                Addon.UI:QueueRefresh()
            end
        end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if Addon.UI and Addon.UI.frame and Addon.UI.frame:IsShown() then
            Addon.UI:QueueRefresh(0.15)
        end
    end
end)

SLASH_KEYSTONELOOTMISTS1 = "/ksl"
SLASH_KEYSTONELOOTMISTS2 = "/keyloot"
SLASH_KEYSTONELOOTMISTS3 = "/pandarialoot"
SlashCmdList.KEYSTONELOOTMISTS = function(message)
    Addon:HandleSlash(message)
end
