local _, Addon = ...

local Journal = {}
Addon.Journal = Journal

Journal.SOO_JOURNAL_INSTANCE_ID = 369
Journal.SOO_INSTANCE_ID = 1136
Journal.instance = nil

local MAX_UPGRADE_TYPE = "4"
local MAX_UPGRADE_ID = "531"
local MAX_UPGRADE_ITEM_LEVEL_BONUS = 8

Journal.RAID_DIFFICULTIES = {
    { id = 14, fallback = "弹性" },
    { id = 3, fallback = "普通" },
    { id = 5, fallback = "英雄" },
}

Journal.SLOT_OPTIONS = {
    { key = "ALL", name = "全部部位" },
    { key = "HEAD", name = "头部" },
    { key = "NECK", name = "颈部" },
    { key = "SHOULDER", name = "肩部" },
    { key = "BACK", name = "背部" },
    { key = "CHEST", name = "胸部" },
    { key = "WRIST", name = "手腕" },
    { key = "HANDS", name = "手部" },
    { key = "WAIST", name = "腰部" },
    { key = "LEGS", name = "腿部" },
    { key = "FEET", name = "脚部" },
    { key = "FINGER", name = "戒指" },
    { key = "TRINKET", name = "饰品" },
    { key = "WEAPON", name = "武器" },
    { key = "OFFHAND", name = "副手" },
}

local EQUIP_LOCATION_TO_SLOT = {
    INVTYPE_HEAD = "HEAD",
    INVTYPE_NECK = "NECK",
    INVTYPE_SHOULDER = "SHOULDER",
    INVTYPE_CLOAK = "BACK",
    INVTYPE_CHEST = "CHEST",
    INVTYPE_ROBE = "CHEST",
    INVTYPE_WRIST = "WRIST",
    INVTYPE_HAND = "HANDS",
    INVTYPE_WAIST = "WAIST",
    INVTYPE_LEGS = "LEGS",
    INVTYPE_FEET = "FEET",
    INVTYPE_FINGER = "FINGER",
    INVTYPE_TRINKET = "TRINKET",
    INVTYPE_WEAPON = "WEAPON",
    INVTYPE_2HWEAPON = "WEAPON",
    INVTYPE_WEAPONMAINHAND = "WEAPON",
    INVTYPE_RANGED = "WEAPON",
    INVTYPE_RANGEDRIGHT = "WEAPON",
    INVTYPE_THROWN = "WEAPON",
    INVTYPE_HOLDABLE = "OFFHAND",
    INVTYPE_SHIELD = "OFFHAND",
    INVTYPE_WEAPONOFFHAND = "OFFHAND",
}

function Journal:GetDifficultyName(difficulty)
    if difficulty.fallback then
        return difficulty.fallback
    end
    if _G.GetDifficultyInfo then
        local name = _G.GetDifficultyInfo(difficulty.id)
        if name and name ~= "" then
            return name
        end
    end
    return difficulty.fallback
end

function Journal:EnsureAvailable()
    if EJ_GetInstanceByIndex and EJ_SelectTier and EJ_GetNumLoot then
        return true
    end

    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal")
    elseif _G.LoadAddOn then
        pcall(_G.LoadAddOn, "Blizzard_EncounterJournal")
    end

    return EJ_GetInstanceByIndex and EJ_SelectTier and EJ_GetNumLoot
end

function Journal:FindPandariaTier()
    local tierCount = EJ_GetNumTiers and EJ_GetNumTiers() or 0
    local expansionName = _G.EXPANSION_NAME4

    for index = 1, tierCount do
        local name = EJ_GetTierInfo(index)
        if name and (name == expansionName or string.find(name, "熊猫") or string.find(string.lower(name), "pandaria")) then
            return index
        end
    end

    if EJ_GetCurrentTier then
        return EJ_GetCurrentTier()
    end

    return tierCount
end

function Journal:Initialize()
    self.available = self:EnsureAvailable()
    if not self.available then
        self.error = "无法加载地下城手册 API"
        return
    end

    self.pandariaTier = self:FindPandariaTier()
    self:RefreshInstances()
end

function Journal:RefreshInstances()
    if not self.available or not self.pandariaTier then
        return
    end

    EJ_SelectTier(self.pandariaTier)
    self.instance = nil

    local index = 1
    while index <= 40 do
        local journalInstanceID, name, description, background, buttonImage, loreImage,
            dungeonButtonImage, mapID, link, shouldDisplayDifficulty, instanceID = EJ_GetInstanceByIndex(index, true)

        if not journalInstanceID then
            break
        end

        if journalInstanceID == self.SOO_JOURNAL_INSTANCE_ID
            or instanceID == self.SOO_INSTANCE_ID
            or (name and (string.find(name, "奥格瑞玛") or string.find(string.lower(name), "orgrimmar"))) then
            self.instance = {
                journalInstanceID = journalInstanceID,
                instanceID = instanceID,
                mapID = mapID,
                name = name,
                description = description,
                background = background,
                icon = buttonImage or dungeonButtonImage,
                link = link,
                isRaid = true,
            }
            break
        end
        index = index + 1
    end

    if not self.instance then
        self.error = "地下城手册中未找到决战奥格瑞玛（Journal ID 369）"
    else
        self.error = nil
    end
end

function Journal:GetInstance()
    return self.instance
end

function Journal:SetContext(difficultyID, classID, specID)
    if EJ_SelectTier and self.pandariaTier then
        EJ_SelectTier(self.pandariaTier)
    end
    if EJ_SetDifficulty then
        EJ_SetDifficulty(difficultyID)
    end
    if EJ_SetLootFilter then
        EJ_SetLootFilter(classID or 0, specID or 0)
    end
end

function Journal:GetEncounters(instance)
    local encounters = {}
    if not instance or not EJ_GetEncounterInfoByIndex then
        return encounters
    end

    EJ_SelectInstance(instance.journalInstanceID)
    for index = 1, 30 do
        local name, description, encounterID, rootSectionID, link, journalInstanceID,
            dungeonEncounterID, instanceID = EJ_GetEncounterInfoByIndex(index, instance.journalInstanceID)
        if not name then
            break
        end

        table.insert(encounters, {
            name = name,
            description = description,
            encounterID = encounterID,
            dungeonEncounterID = dungeonEncounterID,
            journalInstanceID = journalInstanceID,
            instanceID = instanceID,
            link = link,
        })
    end
    return encounters
end

local function NormalizeModernLoot(info)
    if not info then
        return nil
    end

    return {
        itemID = info.itemID or info.itemId,
        name = info.name,
        icon = info.icon or info.iconFileID,
        slotName = info.slot,
        armorType = info.armorType,
        link = info.link,
        encounterID = info.encounterID or info.encounterId,
    }
end

local function SplitItemString(itemString)
    local fields = {}
    for value in string.gmatch(itemString .. ":", "(.-):") do
        table.insert(fields, value)
    end
    return fields
end

local function BuildMaxUpgradeLink(link)
    if type(link) ~= "string" then
        return nil
    end
    local itemString = string.match(link, "|H(item:[^|]+)|h")
        or string.match(link, "^(item:[^|]+)$")
    if not itemString then
        return nil
    end

    local fields = SplitItemString(itemString)
    if fields[1] ~= "item" or not tonumber(fields[2]) then
        return nil
    end
    for index = 3, 14 do
        if fields[index] == nil or fields[index] == "" then
            fields[index] = "0"
        end
    end

    local bonusCount = math.max(0, tonumber(fields[14]) or 0)
    local upgradeIndex = 15 + bonusCount
    for index = 15, upgradeIndex do
        if fields[index] == nil or fields[index] == "" then
            fields[index] = "0"
        end
    end
    fields[12] = MAX_UPGRADE_TYPE
    fields[upgradeIndex] = MAX_UPGRADE_ID

    local upgradedItemString = table.concat(fields, ":")
    return string.gsub(link, itemString, upgradedItemString, 1)
end

local function GetDetailedItemLevel(link, fallback)
    if C_Item and C_Item.GetDetailedItemLevelInfo and link then
        local ok, itemLevel = pcall(C_Item.GetDetailedItemLevelInfo, link)
        if ok and itemLevel then
            return tonumber(itemLevel)
        end
    end
    if _G.GetDetailedItemLevelInfo and link then
        local ok, itemLevel = pcall(_G.GetDetailedItemLevelInfo, link)
        if ok and itemLevel then
            return tonumber(itemLevel)
        end
    end
    return tonumber(fallback)
end

function Journal:GetLootInfo(index)
    if C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex then
        local ok, info = pcall(C_EncounterJournal.GetLootInfoByIndex, index)
        if ok and info then
            return NormalizeModernLoot(info)
        end
    end

    if EJ_GetLootInfoByIndex then
        local name, icon, slotName, armorType, itemID, link, encounterID = EJ_GetLootInfoByIndex(index)
        if itemID then
            return {
                itemID = itemID,
                name = name,
                icon = icon,
                slotName = slotName,
                armorType = armorType,
                link = link,
                encounterID = encounterID,
            }
        end
    end
end

function Journal:CompleteItemInfo(item)
    if not item or not item.itemID then
        return item
    end

    local instantID, itemType, itemSubType, equipLoc, instantIcon, itemClassID, itemSubClassID =
        Addon:GetItemInfoInstant(item.itemID)
    item.itemID = instantID or item.itemID
    item.itemType = itemType
    item.itemSubType = itemSubType
    item.equipLoc = equipLoc
    item.itemClassID = itemClassID
    item.itemSubClassID = itemSubClassID
    item.slotKey = EQUIP_LOCATION_TO_SLOT[equipLoc]
    item.icon = item.icon or instantIcon or 134400

    local name, link, quality, itemLevel, _, _, _, _, _, icon = Addon:GetItemInfo(item.itemID)
    item.name = item.name or name or ("物品 " .. item.itemID)
    item.link = item.link or link
    item.quality = quality
    item.itemLevel = itemLevel
    item.icon = item.icon or icon or 134400

    if item.slotKey and item.link then
        local upgradedLink = BuildMaxUpgradeLink(item.link)
        if upgradedLink then
            local upgradedName, _, upgradedQuality, upgradedItemLevel, _, _, _, _, _, upgradedIcon =
                Addon:GetItemInfo(upgradedLink)
            local actualItemLevel = GetDetailedItemLevel(upgradedLink, upgradedItemLevel)
            local baseItemLevel = tonumber(itemLevel)
            if baseItemLevel and (not actualItemLevel or actualItemLevel <= baseItemLevel) then
                actualItemLevel = baseItemLevel + MAX_UPGRADE_ITEM_LEVEL_BONUS
            end
            item.name = upgradedName or item.name
            item.link = upgradedLink
            item.quality = upgradedQuality or item.quality
            item.baseItemLevel = baseItemLevel
            item.itemLevel = actualItemLevel or item.itemLevel
            item.icon = upgradedIcon or item.icon
            item.upgradeLevel = 2
            item.upgradeText = "2/2"
        end
    end
    return item
end

function Journal:GetSelectedLoot()
    local loot = {}
    local count = EJ_GetNumLoot and EJ_GetNumLoot() or 0
    for index = 1, count do
        local item = self:GetLootInfo(index)
        if item and item.itemID then
            table.insert(loot, self:CompleteItemInfo(item))
        end
    end
    return loot
end

function Journal:GetInstanceLoot(instance)
    if not instance then
        return {}
    end
    EJ_SelectInstance(instance.journalInstanceID)
    return self:GetSelectedLoot()
end

function Journal:GetEncounterLoot(instance, encounter)
    if not instance or not encounter then
        return {}
    end
    EJ_SelectInstance(instance.journalInstanceID)
    EJ_SelectEncounter(encounter.encounterID)
    return self:GetSelectedLoot()
end

function Journal:ItemMatchesSlot(item, slotKey)
    return slotKey == "ALL" or item.slotKey == slotKey
end

function Journal:IsDisplayableLoot(item)
    if not item then
        return false
    end
    if item.slotKey then
        return true
    end
    return Addon.TierSets and Addon.TierSets:IsTierToken(item.itemID) or false
end
