local _, Addon = ...

local Competition = {}
Addon.Competition = Competition

local CACHE_TTL = 120
local INSPECT_INTERVAL = 2
local INSPECT_TIMEOUT = 4
local MAX_MISTS_CLASS_ID = 11

local REFRESH_FAILURE_STATUS = {
    combat = true,
    inspect_busy = true,
    out_of_range = true,
    offline = true,
    timeout = true,
    unavailable = true,
}

local SLOT_KEY_TO_INVENTORY_SLOTS = {
    HEAD = { 1 },
    NECK = { 2 },
    SHOULDER = { 3 },
    BACK = { 15 },
    CHEST = { 5 },
    WRIST = { 9 },
    HANDS = { 10 },
    WAIST = { 6 },
    LEGS = { 7 },
    FEET = { 8 },
    FINGER = { 11, 12 },
    TRINKET = { 13, 14 },
    WEAPON = { 16, 17 },
    OFFHAND = { 17 },
}

local function WipeTable(tbl)
    if wipe then
        return wipe(tbl)
    end
    for key in pairs(tbl) do
        tbl[key] = nil
    end
    return tbl
end

local function IsGrouped()
    if IsInGroup then
        return IsInGroup()
    end
    return (GetNumGroupMembers and GetNumGroupMembers() or 0) > 1
end

local function IsPlayerInCombat()
    return (InCombatLockdown and InCombatLockdown())
        or (UnitAffectingCombat and UnitAffectingCombat("player"))
end

local function IsInspectFrameBusy()
    return InspectFrame and InspectFrame.IsShown and InspectFrame:IsShown()
end

local function GetFullUnitName(unit)
    if UnitFullName then
        local name, realm = UnitFullName(unit)
        if name and realm and realm ~= "" then
            return name .. "-" .. realm, name
        end
        if name then
            return name, name
        end
    end
    local name = UnitName(unit)
    return name, name
end

local function ParseItemID(link)
    if not link then
        return nil
    end
    return tonumber(string.match(link, "item:(%d+)"))
end

local function GetDetailedItemLevel(link, itemID)
    if C_Item and C_Item.GetDetailedItemLevelInfo and link then
        local ok, itemLevel = pcall(C_Item.GetDetailedItemLevelInfo, link)
        if ok and itemLevel then
            return itemLevel
        end
    end
    if _G.GetDetailedItemLevelInfo and link then
        local ok, itemLevel = pcall(_G.GetDetailedItemLevelInfo, link)
        if ok and itemLevel then
            return itemLevel
        end
    end
    local _, _, _, itemLevel = Addon:GetItemInfo(link or itemID)
    return itemLevel
end

local function GetTargetItemLevel(item)
    if not item then
        return nil
    end
    local itemLevel = tonumber(GetDetailedItemLevel(item.link, item.itemID))
    if not itemLevel or itemLevel <= 0 then
        itemLevel = tonumber(item.itemLevel)
    end
    if itemLevel and itemLevel > 0 then
        return itemLevel
    end
    return nil
end

local function GetGroupUnits()
    local units = {}
    local count = GetNumGroupMembers and GetNumGroupMembers() or 0
    if IsInRaid and IsInRaid() then
        for index = 1, count do
            table.insert(units, "raid" .. index)
        end
    elseif IsGrouped() then
        for index = 1, math.max(0, count - 1) do
            table.insert(units, "party" .. index)
        end
    end
    return units
end

function Competition:GetFreshCache(guid)
    local cached = guid and self.unitCache[guid]
    if cached and GetTime() - cached.timestamp <= CACHE_TTL then
        return cached
    end
    return nil
end

function Competition:CreateCandidate(unit)
    if not UnitExists(unit) or UnitIsUnit(unit, "player") then
        return nil
    end
    local className, classFile, classID = UnitClass(unit)
    local guid = UnitGUID(unit)
    if not guid or not classID then
        return nil
    end
    local fullName, shortName = GetFullUnitName(unit)
    return {
        unit = unit,
        guid = guid,
        name = shortName or className or "未知成员",
        fullName = fullName,
        classID = classID,
        classFile = classFile,
        status = UnitIsConnected(unit) and "queued" or "offline",
    }
end

function Competition:RefreshGroupMembers()
    local membersByGUID = {}
    for _, unit in ipairs(GetGroupUnits()) do
        local candidate = self:CreateCandidate(unit)
        if candidate then
            membersByGUID[candidate.guid] = candidate
        end
    end
    self.membersByGUID = membersByGUID

    for guid in pairs(self.unitCache) do
        if not membersByGUID[guid] then
            self.unitCache[guid] = nil
        end
    end

    WipeTable(self.backgroundQueue)
    WipeTable(self.backgroundQueued)
    for guid in pairs(membersByGUID) do
        if not self:GetFreshCache(guid) and (not self.active or self.active.guid ~= guid) then
            table.insert(self.backgroundQueue, guid)
            self.backgroundQueued[guid] = true
        end
    end
    self:NotifyUpdated()
    self:ProcessQueue()
end

function Competition:QueueBackgroundCandidate(guid)
    if not guid or not self.membersByGUID[guid] or self.backgroundQueued[guid]
        or (self.active and self.active.guid == guid) then
        return
    end
    table.insert(self.backgroundQueue, guid)
    self.backgroundQueued[guid] = true
end

function Competition:GetTargetSlots(item, tierInfo)
    if tierInfo and tierInfo.inventorySlot then
        return { tierInfo.inventorySlot }
    end
    return item and SLOT_KEY_TO_INVENTORY_SLOTS[item.slotKey] or nil
end

function Competition:GetEligibilityCacheKey(item, source)
    local difficultyID = source and source.difficultyID
        or (Addon.db and Addon.db.filters and Addon.db.filters.difficulty)
        or 0
    return table.concat({
        tostring(difficultyID),
        tostring(source and source.journalInstanceID or 0),
        tostring(source and source.encounterID or 0),
        tostring(item and item.itemID or 0),
    }, ":")
end

function Competition:BuildFallbackEligibility(tierInfo)
    local result = {
        classes = {},
        specsByClass = {},
        reliable = tierInfo ~= nil,
        tierInfo = tierInfo,
    }

    if tierInfo and tierInfo.groupKey then
        local group = Addon.TierSets.TOKEN_GROUPS[tierInfo.groupKey]
        if group then
            for _, classID in ipairs(group.classIDs) do
                result.classes[classID] = true
            end
        end
        return result
    end

    for classID = 1, MAX_MISTS_CLASS_ID do
        result.classes[classID] = true
    end
    return result
end

function Competition:BuildJournalEligibility(item, source)
    local fallback = self:BuildFallbackEligibility(nil)
    if not item or not item.itemID or not source or not source.journalInstanceID or not source.encounterID then
        return fallback
    end
    if not Addon.Journal or not Addon.Journal.available or not EJ_SelectInstance or not EJ_SelectEncounter then
        return fallback
    end

    local difficultyID = source.difficultyID
        or (Addon.db and Addon.db.filters and Addon.db.filters.difficulty)
        or 14
    local result = {
        classes = {},
        specsByClass = {},
        reliable = false,
    }
    local foundCount = 0

    local ok = pcall(function()
        for classID = 1, MAX_MISTS_CLASS_ID do
            local numSpecs = Addon:GetNumSpecsForClass(classID)
            for specIndex = 1, numSpecs do
                local specID = Addon:GetSpecInfoForClass(classID, specIndex)
                if specID then
                    Addon.Journal:SetContext(difficultyID, classID, specID)
                    EJ_SelectInstance(source.journalInstanceID)
                    EJ_SelectEncounter(source.encounterID)

                    local lootCount = EJ_GetNumLoot and EJ_GetNumLoot() or 0
                    local matches = false
                    for lootIndex = 1, lootCount do
                        local loot = Addon.Journal:GetLootInfo(lootIndex)
                        if loot and tonumber(loot.itemID) == tonumber(item.itemID) then
                            matches = true
                            break
                        end
                    end

                    if matches then
                        result.classes[classID] = true
                        result.specsByClass[classID] = result.specsByClass[classID] or {}
                        result.specsByClass[classID][specID] = true
                        foundCount = foundCount + 1
                    end
                end
            end
        end
    end)

    if Addon.db and Addon.db.filters then
        pcall(Addon.Journal.SetContext, Addon.Journal,
            Addon.db.filters.difficulty, Addon.db.filters.classID, Addon.db.filters.specID)
    end

    if not ok or foundCount == 0 then
        return fallback
    end
    result.reliable = true
    return result
end

function Competition:GetEligibility(item, source)
    local tierInfo = Addon.TierSets and Addon.TierSets:GetCompetitionInfo(item and item.itemID)
    if tierInfo then
        return self:BuildFallbackEligibility(tierInfo)
    end

    local cacheKey = self:GetEligibilityCacheKey(item, source)
    if self.eligibilityCache[cacheKey] then
        return self.eligibilityCache[cacheKey]
    end

    local eligibility = self:BuildJournalEligibility(item, source)
    if eligibility.reliable then
        self.eligibilityCache[cacheKey] = eligibility
    end
    return eligibility
end

function Competition:IsCandidateEligible(candidate, cached, eligibility)
    if not candidate or not eligibility.classes[candidate.classID] then
        return false
    end
    if not eligibility.reliable or eligibility.tierInfo or not cached or not cached.specID or cached.specID == 0 then
        return true
    end
    local classSpecs = eligibility.specsByClass[candidate.classID]
    return classSpecs and classSpecs[cached.specID] or false
end

function Competition:GetEquippedItem(unit, slot)
    local link = GetInventoryItemLink(unit, slot)
    local itemID = GetInventoryItemID and GetInventoryItemID(unit, slot) or ParseItemID(link)
    if not link and not itemID then
        return nil
    end

    local itemInfo = { Addon:GetItemInfo(link or itemID) }
    local name = itemInfo[1]
    local quality = itemInfo[3]
    local equipLoc = itemInfo[9]
    local icon = itemInfo[10]
    local setID = tonumber(itemInfo[16])
    return {
        slot = slot,
        itemID = itemID,
        link = link,
        name = name,
        quality = quality,
        equipLoc = equipLoc,
        icon = icon,
        itemLevel = GetDetailedItemLevel(link, itemID),
        setID = setID,
        raidTier = Addon.TierSets and Addon.TierSets:GetRaidTierForItem(itemID, setID),
        variantKey = Addon:GetItemVariantKey({ itemID = itemID, name = name }),
        tierInfo = Addon.TierSets and Addon.TierSets:GetTierItemInfo(itemID),
    }
end

function Competition:ScanUnit(unit, guid)
    local specID = 0
    if GetInspectSpecialization then
        local ok, inspectedSpecID = pcall(GetInspectSpecialization, unit)
        if ok then
            specID = tonumber(inspectedSpecID) or 0
        end
    end

    local slots = {}
    for slot = 1, 17 do
        if slot ~= 4 then
            slots[slot] = self:GetEquippedItem(unit, slot)
        end
    end

    local cached = {
        guid = guid,
        specID = specID,
        slots = slots,
        timestamp = GetTime(),
    }
    self.unitCache[guid] = cached
    return cached
end

function Competition:RefreshCachedItemInfo(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return
    end
    for _, cached in pairs(self.unitCache) do
        for _, equipped in pairs(cached.slots) do
            if equipped and equipped.itemID == itemID then
                local itemInfo = { Addon:GetItemInfo(equipped.link or itemID) }
                local name = itemInfo[1]
                local quality = itemInfo[3]
                local equipLoc = itemInfo[9]
                local icon = itemInfo[10]
                local setID = tonumber(itemInfo[16])
                equipped.name = name or equipped.name
                equipped.quality = quality or equipped.quality
                equipped.equipLoc = equipLoc or equipped.equipLoc
                equipped.icon = icon or equipped.icon
                equipped.itemLevel = GetDetailedItemLevel(equipped.link, itemID) or equipped.itemLevel
                equipped.setID = setID or equipped.setID
                equipped.raidTier = Addon.TierSets
                    and Addon.TierSets:GetRaidTierForItem(itemID, equipped.setID)
                equipped.variantKey = Addon:GetItemVariantKey({ itemID = itemID, name = equipped.name })
                equipped.tierInfo = Addon.TierSets and Addon.TierSets:GetTierItemInfo(itemID)
            end
        end
    end
end

function Competition:CompareEquipment(item, eligibility, cached, targetItemLevel)
    local tierInfo = eligibility.tierInfo
    local inventorySlots = self:GetTargetSlots(item, tierInfo) or {}
    local currentItems = {}
    local targetEquipped = false
    local targetVariantKey = not tierInfo and Addon:GetItemVariantKey(item) or nil
    local comparisonItemLevel
    local comparisonReliable = true
    local targetEquippedItemLevel

    for _, slot in ipairs(inventorySlots) do
        local equipped = cached.slots[slot]
        if equipped then
            table.insert(currentItems, equipped)
            local equippedItemLevel = tonumber(equipped.itemLevel)
            if equippedItemLevel then
                comparisonItemLevel = comparisonItemLevel
                    and math.min(comparisonItemLevel, equippedItemLevel)
                    or equippedItemLevel
            else
                comparisonReliable = false
            end
            if tierInfo then
                local equippedTier = equipped.tierInfo
                if equippedTier
                    and equippedTier.groupKey == tierInfo.groupKey
                    and equippedTier.slotIndex == tierInfo.slotIndex then
                    targetEquipped = true
                    if equippedItemLevel then
                        targetEquippedItemLevel = targetEquippedItemLevel
                            and math.max(targetEquippedItemLevel, equippedItemLevel)
                            or equippedItemLevel
                    end
                end
            elseif equipped.itemID == tonumber(item.itemID)
                or (targetVariantKey and equipped.variantKey == targetVariantKey) then
                targetEquipped = true
                if equippedItemLevel then
                    targetEquippedItemLevel = targetEquippedItemLevel
                        and math.max(targetEquippedItemLevel, equippedItemLevel)
                        or equippedItemLevel
                end
            end
        else
            comparisonItemLevel = 0
        end
    end

    if not comparisonReliable then
        comparisonItemLevel = nil
    end
    if targetEquippedItemLevel then
        comparisonItemLevel = targetEquippedItemLevel
    end

    local needState = "unknown"
    targetItemLevel = tonumber(targetItemLevel)
    if targetItemLevel and targetItemLevel > 0 and comparisonItemLevel then
        if comparisonItemLevel < targetItemLevel then
            needState = "need"
        elseif comparisonItemLevel > targetItemLevel then
            needState = "no_need"
        elseif targetEquipped then
            needState = "equipped"
        else
            needState = "same_level"
        end
    elseif targetEquipped then
        needState = "equipped"
    end

    return targetEquipped, currentItems, needState, comparisonItemLevel
end

function Competition:NotifyUpdated()
    local request = self.request
    if request and request.onUpdate then
        request.onUpdate(self:GetRows())
    end
    if Addon.UI and Addon.UI.RefreshTeamTierFrame then
        Addon.UI:RefreshTeamTierFrame()
    end
end

function Competition:ScheduleProcess(delay)
    self.processSerial = self.processSerial + 1
    local serial = self.processSerial
    C_Timer.After(math.max(0, delay or 0), function()
        if serial == self.processSerial then
            self:ProcessQueue()
        end
    end)
end

function Competition:QueueMissingCandidates(forceRefresh)
    WipeTable(self.queue)
    WipeTable(self.queued)
    local request = self.request
    if not request then
        return
    end
    request.forceRefresh = forceRefresh or request.forceRefresh
    request.attemptedByGUID = request.attemptedByGUID or {}

    for _, candidate in ipairs(request.candidates) do
        local cached = self:GetFreshCache(candidate.guid)
        local needsInspect = request.forceRefresh
            and not request.attemptedByGUID[candidate.guid]
            or not cached
        if needsInspect and (not self.active or self.active.guid ~= candidate.guid) then
            candidate.status = "queued"
            table.insert(self.queue, candidate.guid)
            self.queued[candidate.guid] = true
        end
    end
end

function Competition:GetNextInspectionCandidate()
    local request = self.request
    while request and #self.queue > 0 do
        local guid = table.remove(self.queue, 1)
        self.queued[guid] = nil
        local candidate = request.candidateByGUID[guid]
        if candidate then
            local needsInspect = request.forceRefresh
                and not request.attemptedByGUID[guid]
                or not self:GetFreshCache(guid)
            if needsInspect then
                request.attemptedByGUID[guid] = true
                return candidate, "request"
            end
        end
    end

    while #self.backgroundQueue > 0 do
        local guid = table.remove(self.backgroundQueue, 1)
        self.backgroundQueued[guid] = nil
        local candidate = self.membersByGUID[guid]
        if candidate and not self:GetFreshCache(guid) then
            return candidate, "background"
        end
    end
end

function Competition:BeginInspect(candidate, queueKind)
    local guid = candidate.guid
    local unit = candidate.unit
    self.inspectSerial = self.inspectSerial + 1
    local token = self.inspectSerial
    self.active = {
        token = token,
        guid = guid,
        unit = unit,
        queueKind = queueKind,
        requestID = self.request and self.request.id,
    }
    self.nextInspectAt = GetTime() + INSPECT_INTERVAL
    candidate.status = "loading"
    local requestCandidate = self.request and self.request.candidateByGUID[guid]
    if requestCandidate then
        requestCandidate.status = "loading"
    end
    NotifyInspect(unit)
    self:NotifyUpdated()

    C_Timer.After(INSPECT_TIMEOUT, function()
        local active = self.active
        if not active or active.token ~= token or active.guid ~= guid then
            return
        end
        self.active = nil
        local request = self.request
        local currentCandidate = request and request.candidateByGUID[guid]
        if currentCandidate then
            currentCandidate.status = "timeout"
        end
        local member = self.membersByGUID[guid]
        if member then
            member.status = "timeout"
        end
        self:NotifyUpdated()
        self:ScheduleProcess(math.max(0, self.nextInspectAt - GetTime()))
    end)
end

function Competition:ProcessQueue()
    local request = self.request
    if self.active or (#self.queue == 0 and #self.backgroundQueue == 0) then
        return
    end

    if IsPlayerInCombat() then
        if request then
            for _, guid in ipairs(self.queue) do
                local candidate = request.candidateByGUID[guid]
                if candidate then
                    candidate.status = "combat"
                end
            end
        end
        self:NotifyUpdated()
        return
    end

    if IsInspectFrameBusy() then
        if request then
            for _, guid in ipairs(self.queue) do
                local candidate = request.candidateByGUID[guid]
                if candidate then
                    candidate.status = "inspect_busy"
                end
            end
        end
        self:NotifyUpdated()
        self:ScheduleProcess(0.5)
        return
    end

    local waitTime = self.nextInspectAt - GetTime()
    if waitTime > 0 then
        self:ScheduleProcess(waitTime)
        return
    end

    while true do
        local candidate, queueKind = self:GetNextInspectionCandidate()
        if not candidate then
            break
        end
        local guid = candidate.guid
        local unit = candidate.unit
        if not UnitExists(unit) or UnitGUID(unit) ~= guid then
            candidate.status = "unavailable"
        elseif not UnitIsConnected(unit) then
            candidate.status = "offline"
        elseif UnitAffectingCombat and UnitAffectingCombat(unit) then
            candidate.status = "combat"
        elseif CheckInteractDistance and not CheckInteractDistance(unit, 1) then
            candidate.status = "out_of_range"
        else
            local ok, canInspect = pcall(CanInspect, unit)
            if not ok or not canInspect then
                candidate.status = "unavailable"
            else
                self:BeginInspect(candidate, queueKind)
                return
            end
        end
    end

    self:NotifyUpdated()
end

function Competition:GetGroupEquipmentRows()
    local rows = {}

    local playerGUID = UnitGUID("player")
    if playerGUID then
        local cached = self:GetFreshCache(playerGUID)
        if not cached then
            cached = self:ScanUnit("player", playerGUID)
            cached.specID = Addon:GetCurrentSpecID()
        end
        local playerName, playerRealm
        if UnitFullName then
            playerName, playerRealm = UnitFullName("player")
        else
            playerName = UnitName("player")
        end
        local _, classFile, classID = UnitClass("player")
        local fullName = playerName
        if playerName and playerRealm and playerRealm ~= "" then
            fullName = playerName .. "-" .. playerRealm
        end
        table.insert(rows, {
            guid = playerGUID,
            unit = "player",
            name = playerName or "玩家",
            fullName = fullName,
            classID = classID,
            classFile = classFile,
            status = "ready",
            cache = cached,
            isPlayer = true,
        })
    end

    for _, unit in ipairs(GetGroupUnits()) do
        local candidate = self:CreateCandidate(unit)
        if candidate then
            local tracked = self.membersByGUID[candidate.guid]
            local requestCandidate = self.request and self.request.candidateByGUID[candidate.guid]
            local cached = self:GetFreshCache(candidate.guid)
            local status = requestCandidate and requestCandidate.status
                or tracked and tracked.status
                or candidate.status
            if cached then
                status = "ready"
            elseif self.active and self.active.guid == candidate.guid then
                status = "loading"
            end
            table.insert(rows, {
                guid = candidate.guid,
                unit = candidate.unit,
                name = candidate.name,
                fullName = candidate.fullName,
                classID = candidate.classID,
                classFile = candidate.classFile,
                status = status,
                cache = cached,
            })
        end
    end
    return rows
end

function Competition:GetRows()
    local request = self.request
    if not request then
        return {}, { total = 0, ready = 0, reliable = false }
    end

    request.targetItemLevel = request.targetItemLevel or GetTargetItemLevel(request.item)

    local rows = {}
    local readyCount = 0
    for _, candidate in ipairs(request.candidates) do
        local cached = self:GetFreshCache(candidate.guid)
        if self:IsCandidateEligible(candidate, cached, request.eligibility) then
            local row = {
                guid = candidate.guid,
                name = candidate.name,
                fullName = candidate.fullName,
                classID = candidate.classID,
                classFile = candidate.classFile,
                status = candidate.status or "queued",
                specID = cached and cached.specID or 0,
                specUnknown = cached and cached.specID == 0 or false,
                currentItems = {},
            }
            if cached then
                row.hasCachedData = true
                if not REFRESH_FAILURE_STATUS[row.status] then
                    row.status = "ready"
                end
                row.targetEquipped, row.currentItems, row.needState, row.comparisonItemLevel =
                    self:CompareEquipment(request.item, request.eligibility, cached, request.targetItemLevel)
                row.targetItemLevel = request.targetItemLevel
                readyCount = readyCount + 1
            end
            table.insert(rows, row)
        end
    end

    return rows, {
        total = #rows,
        ready = readyCount,
        reliable = request.eligibility.reliable,
        isTier = request.eligibility.tierInfo ~= nil,
        targetItemLevel = request.targetItemLevel,
    }
end

function Competition:Request(item, source, owner, onUpdate)
    self:Cancel()
    if not IsGrouped() or not item or not item.itemID then
        return false
    end

    local eligibility = self:GetEligibility(item, source)
    if not self:GetTargetSlots(item, eligibility.tierInfo) then
        return false
    end

    local targetItemLevel = GetTargetItemLevel(item)

    self.requestSerial = self.requestSerial + 1
    local request = {
        id = self.requestSerial,
        item = item,
        source = source,
        owner = owner,
        onUpdate = onUpdate,
        eligibility = eligibility,
        targetItemLevel = targetItemLevel,
        candidates = {},
        candidateByGUID = {},
        attemptedByGUID = {},
    }

    for _, unit in ipairs(GetGroupUnits()) do
        local candidate = self:CreateCandidate(unit)
        if candidate and eligibility.classes[candidate.classID] then
            local guid = candidate.guid
            if guid then
                table.insert(request.candidates, candidate)
                request.candidateByGUID[guid] = candidate
            end
        end
    end

    self.request = request
    self:QueueMissingCandidates(true)
    self:NotifyUpdated()
    self:ProcessQueue()
    return true
end

function Competition:Cancel(owner)
    if owner and self.request and self.request.owner ~= owner then
        return
    end
    self.request = nil
    WipeTable(self.queue)
    WipeTable(self.queued)
    self.processSerial = self.processSerial + 1
    if #self.backgroundQueue > 0 and not self.active then
        self:ScheduleProcess(math.max(0, self.nextInspectAt - GetTime()))
    end
end

function Competition:RestartRequest()
    local request = self.request
    if not request then
        return
    end
    self:Request(request.item, request.source, request.owner, request.onUpdate)
end

function Competition:HandleInspectReady(guid)
    local active = self.active
    if not active or active.guid ~= guid then
        return
    end

    local unit = active.unit
    if not UnitExists(unit) or UnitGUID(unit) ~= guid then
        for _, groupUnit in ipairs(GetGroupUnits()) do
            if UnitGUID(groupUnit) == guid then
                unit = groupUnit
                break
            end
        end
    end

    if UnitExists(unit) and UnitGUID(unit) == guid then
        self:ScanUnit(unit, guid)
    end
    self.active = nil

    if ClearInspectPlayer and not IsInspectFrameBusy() then
        ClearInspectPlayer()
    end

    local request = self.request
    local candidate = request and request.candidateByGUID[guid]
    if candidate then
        request.attemptedByGUID[guid] = true
        candidate.status = self:GetFreshCache(guid) and "ready" or "unavailable"
    end
    local member = self.membersByGUID[guid]
    if member then
        member.status = self:GetFreshCache(guid) and "ready" or "unavailable"
    end
    self:NotifyUpdated()
    self:ScheduleProcess(math.max(0, self.nextInspectAt - GetTime()))
end

Competition.unitCache = {}
Competition.eligibilityCache = {}
Competition.queue = {}
Competition.queued = {}
Competition.backgroundQueue = {}
Competition.backgroundQueued = {}
Competition.membersByGUID = {}
Competition.requestSerial = 0
Competition.inspectSerial = 0
Competition.processSerial = 0
Competition.nextInspectAt = 0

local eventFrame = CreateFrame("Frame")
Competition.eventFrame = eventFrame
eventFrame:RegisterEvent("INSPECT_READY")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "INSPECT_READY" then
        Competition:HandleInspectReady(...)
    elseif event == "GROUP_ROSTER_UPDATE" then
        if Competition.active
            and (not UnitExists(Competition.active.unit)
                or UnitGUID(Competition.active.unit) ~= Competition.active.guid) then
            Competition.active = nil
        end
        Competition:RestartRequest()
        Competition:RefreshGroupMembers()
    elseif event == "PLAYER_ENTERING_WORLD" then
        WipeTable(Competition.unitCache)
        Competition:Cancel()
        WipeTable(Competition.backgroundQueue)
        WipeTable(Competition.backgroundQueued)
        WipeTable(Competition.membersByGUID)
        C_Timer.After(1, function()
            Competition:RefreshGroupMembers()
        end)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if Competition.request then
            Competition:QueueMissingCandidates()
            Competition:NotifyUpdated()
        end
        Competition:ProcessQueue()
    elseif event == "PLAYER_REGEN_DISABLED" then
        Competition:ProcessQueue()
    elseif event == "UNIT_INVENTORY_CHANGED" then
        local unit = ...
        local guid = unit and UnitGUID(unit)
        if guid and Competition.unitCache[guid] then
            Competition.unitCache[guid] = nil
            if Competition.request and Competition.request.candidateByGUID[guid] then
                Competition.request.attemptedByGUID[guid] = nil
                Competition:QueueMissingCandidates()
                Competition:NotifyUpdated()
            end
            Competition:QueueBackgroundCandidate(guid)
            Competition:ProcessQueue()
            if UnitIsUnit(unit, "player") then
                Competition:NotifyUpdated()
            end
        end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        local itemID = ...
        Competition:RefreshCachedItemInfo(itemID)
        Competition:NotifyUpdated()
    end
end)
