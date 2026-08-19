local _, Addon = ...

local TierSets = {}
Addon.TierSets = TierSets

-- T16 专精与套装对应关系。一个套装可供多个同职责专精共用。
TierSets.SPEC_TO_SET = {
    [71] = 1180, [72] = 1180, [73] = 1179,
    [65] = 1188, [66] = 1189, [70] = 1190,
    [253] = 1195, [254] = 1195, [255] = 1195,
    [259] = 1185, [260] = 1185, [261] = 1185,
    [256] = 1186, [257] = 1186, [258] = 1187,
    [250] = 1201, [251] = 1200, [252] = 1200,
    [262] = 1184, [263] = 1183, [264] = 1182,
    [62] = 1194, [63] = 1194, [64] = 1194,
    [265] = 1181, [266] = 1181, [267] = 1181,
    [268] = 1191, [269] = 1193, [270] = 1192,
    [102] = 1197, [103] = 1199, [104] = 1196, [105] = 1198,
}

TierSets.SPEC_TO_CLASS = {
    [71] = 1, [72] = 1, [73] = 1,
    [65] = 2, [66] = 2, [70] = 2,
    [253] = 3, [254] = 3, [255] = 3,
    [259] = 4, [260] = 4, [261] = 4,
    [256] = 5, [257] = 5, [258] = 5,
    [250] = 6, [251] = 6, [252] = 6,
    [262] = 7, [263] = 7, [264] = 7,
    [62] = 8, [63] = 8, [64] = 8,
    [265] = 9, [266] = 9, [267] = 9,
    [268] = 10, [269] = 10, [270] = 10,
    [102] = 11, [103] = 11, [104] = 11, [105] = 11,
}

TierSets.TOKEN_GROUPS = {
    VANQUISHER = { classIDs = { 4, 6, 8, 11 } },
    CONQUEROR = { classIDs = { 2, 5, 9 } },
    PROTECTOR = { classIDs = { 1, 3, 7 } },
}

TierSets.CLASS_TO_TOKEN_GROUP = {}
for groupKey, group in pairs(TierSets.TOKEN_GROUPS) do
    group.classLookup = {}
    for _, classID in ipairs(group.classIDs) do
        group.classLookup[classID] = true
        TierSets.CLASS_TO_TOKEN_GROUP[classID] = groupKey
    end
end

-- T16 套装物品顺序：头、肩、胸、手、腿。
TierSets.TIER_SLOT_KEYS = { "HEAD", "SHOULDER", "CHEST", "HANDS", "LEGS" }
TierSets.TIER_INVENTORY_SLOTS = { 1, 3, 5, 10, 7 }

-- 熊猫人之谜三档职业套装的 ItemSet ID 区间。
TierSets.RAID_TIER_SET_RANGES = {
    { tier = 16, firstSetID = 1179, lastSetID = 1201 },
    { tier = 15, firstSetID = 1151, lastSetID = 1173 },
    { tier = 14, firstSetID = 1123, lastSetID = 1145 },
}

TierSets.SET_BONUSES = {
    [1179] = { 144503, 144502 }, [1180] = { 144436, 144441 },
    [1181] = { 145072, 145091 }, [1182] = { 144998, 145003 },
    [1183] = { 144962, 144966 }, [1184] = { 145378, 145380 },
    [1185] = { 145185, 145210 }, [1186] = { 145174, 145179 },
    [1187] = { 145306, 145334 }, [1188] = { 144580, 144566 },
    [1189] = { 144625, 144613 }, [1190] = { 144586, 144593 },
    [1191] = { 145049, 145055 }, [1192] = { 145439, 145449 },
    [1193] = { 145004, 145022 }, [1194] = { 145251, 145257 },
    [1195] = { 144637, 144641 }, [1196] = { 144879, 144887 },
    [1197] = { 144767, 144756 }, [1198] = { 144869, 144875 },
    [1199] = { 144864, 144841 }, [1200] = { 144899, 144907 },
    [1201] = { 144934, 144950 },
}

TierSets.ITEMS = {
    -- 弹性
    [14] = {
        [1179] = { 99557, 99597, 99562, 99563, 99558 },
        [1180] = { 99602, 99561, 99603, 99559, 99560 },
        [1181] = { 99570, 99568, 99601, 99567, 99569 },
        [1182] = { 99579, 99645, 99647, 99580, 99646 },
        [1183] = { 99615, 99649, 99663, 99616, 99650 },
        [1184] = { 99636, 99612, 99614, 99611, 99613 },
        [1185] = { 99631, 99635, 99629, 99630, 99634 },
        [1186] = { 99627, 99587, 99628, 99586, 99588 },
        [1187] = { 99584, 99591, 99585, 99590, 99592 },
        [1188] = { 99598, 99596, 99594, 99595, 99593 },
        [1189] = { 99626, 99665, 99656, 99648, 99666 },
        [1190] = { 99566, 99651, 99662, 99625, 99661 },
        [1191] = { 99643, 99607, 99565, 99644, 99606 },
        [1192] = { 99641, 99553, 99642, 99552, 99554 },
        [1193] = { 99555, 99653, 99655, 99556, 99654 },
        [1194] = { 99658, 99576, 99659, 99575, 99657 },
        [1195] = { 99660, 99574, 99577, 99578, 99573 },
        [1196] = { 99624, 99664, 99622, 99623, 99610 },
        [1197] = { 99618, 99621, 99620, 99617, 99619 },
        [1198] = { 99638, 99583, 99582, 99637, 99581 },
        [1199] = { 99599, 99589, 99632, 99633, 99600 },
        [1200] = { 99571, 99639, 99608, 99609, 99572 },
        [1201] = { 99605, 99652, 99640, 99604, 99564 },
    },
    -- 普通
    [3] = {
        [1179] = { 99203, 99196, 99201, 99202, 99195 },
        [1180] = { 99206, 99200, 99197, 99198, 99199 },
        [1181] = { 99204, 99097, 99205, 99096, 99098 },
        [1182] = { 99106, 99093, 99095, 99092, 99094 },
        [1183] = { 99101, 99103, 99105, 99102, 99104 },
        [1184] = { 99107, 99109, 99100, 99108, 99099 },
        [1185] = { 99114, 99116, 99112, 99113, 99115 },
        [1186] = { 99110, 99122, 99111, 99121, 99123 },
        [1187] = { 99119, 99117, 99120, 99131, 99118 },
        [1188] = { 99126, 99128, 99130, 99127, 99129 },
        [1189] = { 99133, 99135, 99125, 99134, 99124 },
        [1190] = { 99136, 99138, 99132, 99137, 99139 },
        [1191] = { 99140, 99142, 99144, 99141, 99143 },
        [1192] = { 99150, 99148, 99151, 99147, 99149 },
        [1193] = { 99154, 99156, 99146, 99155, 99145 },
        [1194] = { 99152, 99161, 99153, 99160, 99162 },
        [1195] = { 99157, 99159, 99167, 99168, 99158 },
        [1196] = { 99164, 99166, 99170, 99163, 99165 },
        [1197] = { 99175, 99169, 99177, 99174, 99176 },
        [1198] = { 99178, 99173, 99172, 99185, 99171 },
        [1199] = { 99182, 99184, 99180, 99181, 99183 },
        [1200] = { 99194, 99187, 99192, 99193, 99186 },
        [1201] = { 99190, 99179, 99188, 99189, 99191 },
    },
    -- 英雄
    [5] = {
        [1179] = { 99409, 99407, 99415, 99408, 99410 },
        [1180] = { 99418, 99414, 99411, 99412, 99413 },
        [1181] = { 99416, 99425, 99417, 99424, 99426 },
        [1182] = { 99344, 99332, 99334, 99345, 99333 },
        [1183] = { 99347, 99341, 99343, 99340, 99342 },
        [1184] = { 99351, 99353, 99346, 99352, 99354 },
        [1185] = { 99348, 99350, 99356, 99355, 99349 },
        [1186] = { 99362, 99360, 99363, 99359, 99361 },
        [1187] = { 99357, 99366, 99358, 99365, 99367 },
        [1188] = { 99368, 99370, 99364, 99369, 99371 },
        [1189] = { 99374, 99376, 99378, 99375, 99377 },
        [1190] = { 99387, 99379, 99373, 99380, 99372 },
        [1191] = { 99382, 99384, 99386, 99383, 99385 },
        [1192] = { 99391, 99389, 99381, 99388, 99390 },
        [1193] = { 99396, 99393, 99395, 99392, 99394 },
        [1194] = { 99400, 99398, 99401, 99397, 99399 },
        [1195] = { 99402, 99404, 99405, 99406, 99403 },
        [1196] = { 99421, 99423, 99419, 99420, 99422 },
        [1197] = { 99433, 99428, 99427, 99432, 99434 },
        [1198] = { 99436, 99431, 99430, 99435, 99429 },
        [1199] = { 99328, 99322, 99326, 99327, 99329 },
        [1200] = { 99337, 99339, 99335, 99336, 99338 },
        [1201] = { 99323, 99325, 99330, 99331, 99324 },
    },
}

TierSets.SET_TO_CLASS = {}
for specID, setID in pairs(TierSets.SPEC_TO_SET) do
    TierSets.SET_TO_CLASS[setID] = TierSets.SPEC_TO_CLASS[specID]
end

TierSets.ITEM_VARIANT_KEYS = {}
TierSets.ITEM_TIER_INFO = {}
for _, difficultySets in pairs(TierSets.ITEMS) do
    for setID, items in pairs(difficultySets) do
        for slotIndex, itemID in ipairs(items) do
            TierSets.ITEM_VARIANT_KEYS[itemID] = ("tier:%d:%d"):format(setID, slotIndex)
        end
    end
end

for difficultyID, difficultySets in pairs(TierSets.ITEMS) do
    for setID, items in pairs(difficultySets) do
        local classID = TierSets.SET_TO_CLASS[setID]
        local groupKey = TierSets.CLASS_TO_TOKEN_GROUP[classID]
        for slotIndex, itemID in ipairs(items) do
            TierSets.ITEM_TIER_INFO[itemID] = {
                kind = "tier",
                itemID = itemID,
                difficultyID = difficultyID,
                setID = setID,
                classID = classID,
                groupKey = groupKey,
                slotIndex = slotIndex,
                slotKey = TierSets.TIER_SLOT_KEYS[slotIndex],
                inventorySlot = TierSets.TIER_INVENTORY_SLOTS[slotIndex],
            }
        end
    end
end

TierSets.TOKEN_ITEMS = {}

local function RegisterTokenItems(difficultyID, groupKey, items)
    for slotIndex, itemID in ipairs(items) do
        TierSets.TOKEN_ITEMS[itemID] = {
            kind = "token",
            itemID = itemID,
            difficultyID = difficultyID,
            groupKey = groupKey,
            slotIndex = slotIndex,
            slotKey = TierSets.TIER_SLOT_KEYS[slotIndex],
            inventorySlot = TierSets.TIER_INVENTORY_SLOTS[slotIndex],
        }
    end
end

-- 团队查找器（兼容识别；当前界面不提供该难度）。
RegisterTokenItems(7, "VANQUISHER", { 99748, 99754, 99742, 99745, 99751 })
RegisterTokenItems(7, "CONQUEROR", { 99749, 99755, 99743, 99746, 99752 })
RegisterTokenItems(7, "PROTECTOR", { 99750, 99756, 99744, 99747, 99753 })

-- 弹性、普通、英雄。
RegisterTokenItems(14, "VANQUISHER", { 99671, 99668, 99677, 99680, 99674 })
RegisterTokenItems(14, "CONQUEROR", { 99672, 99669, 99678, 99681, 99675 })
RegisterTokenItems(14, "PROTECTOR", { 99673, 99670, 99679, 99667, 99676 })
RegisterTokenItems(3, "VANQUISHER", { 99683, 99685, 99696, 99682, 99684 })
RegisterTokenItems(3, "CONQUEROR", { 99689, 99690, 99686, 99687, 99688 })
RegisterTokenItems(3, "PROTECTOR", { 99694, 99695, 99691, 99692, 99693 })
RegisterTokenItems(5, "VANQUISHER", { 99723, 99717, 99714, 99720, 99726 })
RegisterTokenItems(5, "CONQUEROR", { 99724, 99718, 99715, 99721, 99712 })
RegisterTokenItems(5, "PROTECTOR", { 99725, 99719, 99716, 99722, 99713 })

function TierSets:GetVariantKey(itemID)
    return self.ITEM_VARIANT_KEYS[tonumber(itemID)]
end

function TierSets:IsTierToken(itemID)
    return self.TOKEN_ITEMS[tonumber(itemID)] ~= nil
end

function TierSets:GetTokenInfo(itemID)
    return self.TOKEN_ITEMS[tonumber(itemID)]
end

function TierSets:GetTierItemInfo(itemID)
    return self.ITEM_TIER_INFO[tonumber(itemID)]
end

function TierSets:GetRaidTierForSetID(setID)
    setID = tonumber(setID)
    if not setID then
        return nil
    end
    for _, range in ipairs(self.RAID_TIER_SET_RANGES) do
        if setID >= range.firstSetID and setID <= range.lastSetID then
            return range.tier
        end
    end
end

function TierSets:GetRaidTierForItem(itemID, setID)
    if self.ITEM_TIER_INFO[tonumber(itemID)] then
        return 16
    end
    return self:GetRaidTierForSetID(setID)
end

function TierSets:GetCompetitionInfo(itemID)
    itemID = tonumber(itemID)
    return self.TOKEN_ITEMS[itemID] or self.ITEM_TIER_INFO[itemID]
end

function TierSets:GetTokenGroupForClass(classID)
    return self.CLASS_TO_TOKEN_GROUP[tonumber(classID)]
end

function TierSets:IsClassInTokenGroup(classID, groupKey)
    local group = self.TOKEN_GROUPS[groupKey]
    return group and group.classLookup[tonumber(classID)] or false
end

function TierSets:GetInventorySlotForTierSlot(slotIndex)
    return self.TIER_INVENTORY_SLOTS[tonumber(slotIndex)]
end

function TierSets:GetSet(specID, difficultyID)
    local setID = self.SPEC_TO_SET[tonumber(specID)]
    local difficultySets = self.ITEMS[tonumber(difficultyID)]
    local items = setID and difficultySets and difficultySets[setID]
    if not items then
        return nil
    end
    return {
        setID = setID,
        items = items,
        bonuses = self.SET_BONUSES[setID],
    }
end

function TierSets:GetSetName(setID)
    local getter = C_Item and C_Item.GetItemSetInfo or _G.GetItemSetInfo
    if getter then
        local ok, name = pcall(getter, setID)
        if ok and name and name ~= "" then
            return name
        end
    end
    return "T16 职业套装"
end

function TierSets:GetBonusDescription(spellID)
    if C_Spell and C_Spell.GetSpellDescription then
        local description = C_Spell.GetSpellDescription(spellID)
        if description and description ~= "" then
            return description
        end
    end
    if _G.GetSpellDescription then
        local description = _G.GetSpellDescription(spellID)
        if description and description ~= "" then
            return description
        end
    end
    return "套装效果正在载入……"
end
