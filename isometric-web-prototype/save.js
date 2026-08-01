(function (Game) {
  "use strict";

  if (!Game.Core || !Game.Inventory) throw new Error("save.js dependencies are missing");

  function sanitizeDifficulty(value, fallback) {
    const number = Number(value);
    if (!Number.isFinite(number)) return fallback;
    return Game.Core.clampInteger(number, 1, Game.Core.MAX_DIFFICULTY);
  }

  function sanitizeDifficultyClears(value) {
    if (!value || typeof value !== "object" || Array.isArray(value)) return {};
    const clears = {};
    Object.entries(value).forEach(([rawDifficulty, rawCount]) => {
      const difficulty = Number(rawDifficulty);
      if (
        !Number.isInteger(difficulty) ||
        difficulty < 1 ||
        difficulty > Game.Core.MAX_DIFFICULTY
      ) {
        return;
      }
      clears[difficulty] = Game.Core.toSafeNonNegativeInteger(rawCount);
    });
    return clears;
  }

  function normalizeInventory(value) {
    if (!Array.isArray(value)) return [];
    const inventory = [];
    const seenIds = new Set();
    value.forEach((rawItem, index) => {
      if (!["weapon", "armor", "charm"].includes(rawItem?.slot)) return;
      const item = Game.Inventory.normalizeSavedItem(rawItem, rawItem.slot);
      if (!item) return;
      const normalizedId =
        typeof item.id === "string" && item.id.trim().length > 0
          ? item.id.trim()
          : `saved_${item.slot}_${index}`;
      if (seenIds.has(normalizedId)) return;
      item.id = normalizedId;
      seenIds.add(normalizedId);
      inventory.push(item);
    });
    return inventory;
  }

  function sanitizePendingIds(value, inventory) {
    if (!Array.isArray(value)) return [];
    const inventoryIds = new Set(inventory.map((item) => item.id));
    const seenIds = new Set();
    return value.filter((id) => {
      if (typeof id !== "string" || !inventoryIds.has(id) || seenIds.has(id)) {
        return false;
      }
      seenIds.add(id);
      return true;
    });
  }

  function save(state, party) {
    const maxUnlockedDifficulty = sanitizeDifficulty(state.maxUnlockedDifficulty, 1);
    const selectedDifficulty = Game.Core.clampInteger(
      state.selectedDifficulty,
      1,
      maxUnlockedDifficulty,
    );
    const data = {
      version: 2,
      savedAt: Date.now(),
      victories: Game.Core.toSafeNonNegativeInteger(state.victories),
      defeats: Game.Core.toSafeNonNegativeInteger(state.defeats),
      dungeonCompletions: Game.Core.toSafeNonNegativeInteger(state.dungeonCompletions),
      maxUnlockedDifficulty,
      selectedDifficulty,
      difficultyClears: sanitizeDifficultyClears(state.difficultyClears),
      equipment: party.members[0].equipment,
      inventory: state.inventory,
      unreviewedLootIds: sanitizePendingIds(state.unreviewedLootIds, state.inventory),
    };
    try {
      globalThis.localStorage.setItem(Game.Core.SAVE_KEY, JSON.stringify(data));
      return { ok: true, savedAt: data.savedAt };
    } catch (error) {
      return { ok: false, error };
    }
  }

  function load(state, party) {
    try {
      const raw = globalThis.localStorage.getItem(Game.Core.SAVE_KEY);
      if (!raw) return { ok: true, found: false, message: "尚无通关存档" };
      const data = JSON.parse(raw);
      if (data.version !== 1 && data.version !== 2) {
        throw new Error("unsupported save version");
      }
      state.victories = Game.Core.toSafeNonNegativeInteger(data.victories);
      state.defeats = Game.Core.toSafeNonNegativeInteger(data.defeats);
      state.dungeonCompletions = Game.Core.toSafeNonNegativeInteger(data.dungeonCompletions);

      const migratedMax = Math.min(
        Game.Core.MAX_DIFFICULTY,
        state.dungeonCompletions + 1,
      );
      state.maxUnlockedDifficulty = sanitizeDifficulty(
        data.maxUnlockedDifficulty,
        Math.max(1, migratedMax),
      );
      state.selectedDifficulty = Game.Core.clampInteger(
        data.selectedDifficulty ?? state.maxUnlockedDifficulty,
        1,
        state.maxUnlockedDifficulty,
      );
      state.difficultyClears = sanitizeDifficultyClears(data.difficultyClears);

      ["weapon", "armor", "charm"].forEach((slot) => {
        const item = Game.Inventory.normalizeSavedItem(data.equipment?.[slot], slot);
        if (Object.prototype.hasOwnProperty.call(data.equipment || {}, slot)) {
          party.members[0].equipment[slot] = item;
        }
      });
      state.inventory = normalizeInventory(data.inventory);
      state.unreviewedLootIds = sanitizePendingIds(
        data.unreviewedLootIds,
        state.inventory,
      );

      const savedTime = Number(data.savedAt);
      const timeLabel = Number.isFinite(savedTime)
        ? new Date(savedTime).toLocaleTimeString("zh-CN", {
            hour: "2-digit",
            minute: "2-digit",
          })
        : "上次";
      return {
        ok: true,
        found: true,
        message: `已恢复难度 ${state.maxUnlockedDifficulty} · ${timeLabel}`,
      };
    } catch (error) {
      return { ok: false, found: false, error, message: "存档无法读取，已使用新进度" };
    }
  }

  Game.Save = Object.freeze({ save, load });
})(window.CampfireTrials);
