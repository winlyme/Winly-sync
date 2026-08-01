(function (Game) {
  "use strict";

  if (!Game.Core || !Game.Data) throw new Error("inventory.js dependencies are missing");

  const rarities = Game.Data.rarityDefinitions;

  function getMemberStats(member) {
    const totals = { ...member.baseStats };
    Object.values(member.equipment).forEach((item) => {
      if (!item) return;
      Object.entries(item.stats).forEach(([key, value]) => {
        totals[key] = (totals[key] || 0) + value;
      });
    });
    return totals;
  }

  function equipItem(member, item) {
    const previousStats = getMemberStats(member);
    const healthRatio = previousStats.maxHp > 0 ? member.currentHp / previousStats.maxHp : 1;
    const previousItem = member.equipment[item.slot];
    member.equipment[item.slot] = item;
    const nextStats = getMemberStats(member);
    member.currentHp = Math.max(1, Math.round(nextStats.maxHp * healthRatio));
    return previousItem;
  }

  function addItem(inventory, item) {
    if (!item || inventory.some((candidate) => candidate.id === item.id)) return false;
    inventory.push(item);
    return true;
  }

  function removeItem(inventory, itemId) {
    const index = inventory.findIndex((item) => item.id === itemId);
    if (index < 0) return null;
    return inventory.splice(index, 1)[0];
  }

  function discardItem(inventory, itemId) {
    return Boolean(removeItem(inventory, itemId));
  }

  function clearAll(inventory) {
    const count = inventory.length;
    inventory.splice(0, inventory.length);
    return count;
  }

  function unequipItem(member, inventory, slot) {
    const item = member.equipment[slot];
    if (!item) return null;
    member.equipment[slot] = null;
    addItem(inventory, item);
    const stats = getMemberStats(member);
    member.currentHp = Math.min(member.currentHp, stats.maxHp);
    return item;
  }

  function normalizeSavedItem(item, expectedSlot) {
    if (!item || item.slot !== expectedSlot || typeof item.name !== "string") return null;
    const stats = {};
    ["maxHp", "attack", "defense"].forEach((key) => {
      const value = Number(item.stats?.[key]);
      if (Number.isFinite(value) && value >= 0) stats[key] = value;
    });
    return {
      id: typeof item.id === "string" ? item.id : `saved_${expectedSlot}_${Date.now()}`,
      slot: expectedSlot,
      name: item.name,
      rarity: rarities[item.rarity] ? item.rarity : "common",
      itemLevel: Game.Core.toNonNegativeInteger(item.itemLevel),
      stats,
      starter: Boolean(item.starter),
    };
  }

  function slotLabel(slot) {
    return { weapon: "武器", armor: "护甲", charm: "饰品" }[slot] || slot;
  }

  function formatItemStats(stats) {
    const labels = { maxHp: "生命", attack: "攻击", defense: "防御" };
    const parts = Object.entries(stats)
      .filter(([, value]) => value !== 0)
      .map(([key, value]) => `${labels[key]} +${value}`);
    return parts.length > 0 ? parts.join(" · ") : "无额外属性";
  }

  function compareItem(nextItem, currentItem) {
    const labels = { maxHp: "生命", attack: "攻击", defense: "防御" };
    const keys = new Set([
      ...Object.keys(nextItem.stats),
      ...Object.keys(currentItem?.stats || {}),
    ]);
    const changes = [];
    keys.forEach((key) => {
      const difference = (nextItem.stats[key] || 0) - (currentItem?.stats[key] || 0);
      if (difference !== 0) {
        changes.push(`${labels[key]} ${difference > 0 ? "+" : ""}${difference}`);
      }
    });
    return changes.length > 0 ? `替换后：${changes.join(" · ")}` : "与当前装备属性相同";
  }

  function itemColor(item) {
    if (!item) return "#9ab0a1";
    if (item.starter) return "#c9bea4";
    return rarities[item.rarity]?.color || rarities.common.color;
  }

  Game.Inventory = Object.freeze({
    getMemberStats,
    equipItem,
    addItem,
    removeItem,
    discardItem,
    clearAll,
    unequipItem,
    normalizeSavedItem,
    slotLabel,
    formatItemStats,
    compareItem,
    itemColor,
  });
})(window.CampfireTrials);
