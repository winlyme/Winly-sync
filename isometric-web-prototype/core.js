(function (global) {
  "use strict";

  const Game = (global.CampfireTrials = global.CampfireTrials || {});
  const MAX_DIFFICULTY = 99;
  const STATUS_MAX_LENGTH = 12;
  const STATUS_MESSAGES = Object.freeze({
    CAMP: "战士正在营地巡游",
    LOOT: "新战利品已收入背包",
    EQUIPPED: "已更换当前装备",
    DISCARDED: "这件装备已丢弃",
    FAILURE: "本次副本攻略失败",
    CLEAR: "本次副本已经通关",
    MAX_CLEAR: "已完成最高难度挑战",
    ROUTE_ERROR: "路线异常已安全回营",
    SAVE_FAILED: "本次进度保存失败",
    DIFFICULTY_SELECTED: "副本难度已更新",
    INVENTORY_VIEW: "正在查看背包装备",
    INVENTORY_CLEARED: "背包装备已全部清空",
    LOOT_CLOSED: "战利品详情已关闭",
    RESPAWN: "蕾琳正在复苏",
    CAMP_DEPARTURE: "蕾琳正在启程",
    DUNGEON_ARRIVAL: "蕾琳抵达入口",
    DUNGEON_DEPARTURE: "蕾琳正在离场",
    UNKNOWN: "当前状态已更新",
  });
  const STATUS_BUILDERS = Object.freeze({
    APPROACH: (context) => `正在前往第${readBossNumber(context)}名首领`,
    COMBAT: (context) => `正在与第${readBossNumber(context)}名首领战斗`,
    VICTORY: (context) => `第${readBossNumber(context)}名首领已经被击败`,
  });

  Object.entries(STATUS_MESSAGES).forEach(([key, message]) => {
    validateStatusText(message, key);
  });

  function readBossNumber(context) {
    const bossNumber = Number(context?.bossNumber);
    if (!Number.isInteger(bossNumber) || bossNumber < 1) {
      throw new RangeError("Status context requires a positive integer bossNumber");
    }
    return bossNumber;
  }

  function validateStatusText(message, key) {
    if (typeof message !== "string" || message.length === 0) {
      throw new TypeError(`Status message ${key || "UNKNOWN"} must be a non-empty string`);
    }
    const length = Array.from(message).length;
    if (length > STATUS_MAX_LENGTH) {
      throw new RangeError(
        `Status message ${key || "UNKNOWN"} has ${length} characters; maximum is ${STATUS_MAX_LENGTH}`,
      );
    }
    return message;
  }

  Game.Core = Object.freeze({
    TILE_WIDTH: 64,
    TILE_HEIGHT: 32,
    MAX_DIFFICULTY,
    STATUS_MAX_LENGTH,
    STATUS_MESSAGES,
    STATUS_BUILDERS,
    SAVE_KEY: "campfire-trials-save-v1",
    DIRECTIONS: Object.freeze([
      Object.freeze({ x: 1, y: 0 }),
      Object.freeze({ x: -1, y: 0 }),
      Object.freeze({ x: 0, y: 1 }),
      Object.freeze({ x: 0, y: -1 }),
    ]),
    SCENES: Object.freeze({
      CAMP: "camp",
      DUNGEON: "dungeon",
    }),
    PHASES: Object.freeze({
      CAMP: "camp",
      TRANSITION: "transition",
      APPROACH: "approach",
      COMBAT: "combat",
      VICTORY: "victory",
      DEFEAT: "defeat",
    }),
    TRANSITION_ACTIONS: Object.freeze({
      LEVEL_UP: "levelup",
      RESPAWN: "respawn",
    }),
    TRANSITION_TYPES: Object.freeze({
      CAMP_RESPAWN: "camp_respawn",
      CAMP_DEPARTURE: "camp_departure",
      DUNGEON_ARRIVAL: "dungeon_arrival",
      DUNGEON_DEPARTURE: "dungeon_departure",
    }),
    OVERLAYS: Object.freeze({
      NONE: "none",
      LOOT: "loot",
      INVENTORY: "inventory",
    }),
    cellKey(x, y) {
      return `${x},${y}`;
    },
    distanceBetween(a, b) {
      return Math.hypot(a.x - b.x, a.y - b.y);
    },
    directionToward(source, target) {
      return {
        x: Math.sign(target.x - source.x),
        y: Math.sign(target.y - source.y),
      };
    },
    shuffle(items) {
      for (let index = items.length - 1; index > 0; index -= 1) {
        const randomIndex = Math.floor(Math.random() * (index + 1));
        [items[index], items[randomIndex]] = [items[randomIndex], items[index]];
      }
    },
    toNonNegativeInteger(value) {
      const number = Number(value);
      return Number.isFinite(number) ? Math.max(0, Math.floor(number)) : 0;
    },
    toSafeNonNegativeInteger(value) {
      const number = Number(value);
      if (!Number.isFinite(number)) return 0;
      return Math.min(Number.MAX_SAFE_INTEGER, Math.max(0, Math.floor(number)));
    },
    clampInteger(value, minimum, maximum) {
      const number = Number(value);
      if (!Number.isFinite(number)) return minimum;
      return Math.max(minimum, Math.min(maximum, Math.floor(number)));
    },
    getStatusText(key, context) {
      let message;
      if (Object.prototype.hasOwnProperty.call(STATUS_MESSAGES, key)) {
        message = STATUS_MESSAGES[key];
      } else if (Object.prototype.hasOwnProperty.call(STATUS_BUILDERS, key)) {
        message = STATUS_BUILDERS[key](context);
      } else {
        throw new Error(`Unknown status key: ${String(key)}`);
      }
      return validateStatusText(message, key);
    },
    resolveDifficultyProgress(runDifficulty, maxUnlockedDifficulty) {
      const difficulty = this.clampInteger(runDifficulty, 1, MAX_DIFFICULTY);
      const previousMaximum = this.clampInteger(
        maxUnlockedDifficulty,
        1,
        MAX_DIFFICULTY,
      );
      const unlockedNextDifficulty =
        difficulty >= previousMaximum &&
        difficulty < MAX_DIFFICULTY &&
        previousMaximum < MAX_DIFFICULTY;
      const nextMaximum = unlockedNextDifficulty
        ? Math.min(MAX_DIFFICULTY, difficulty + 1)
        : previousMaximum;
      return {
        maxUnlockedDifficulty: nextMaximum,
        selectedDifficulty: unlockedNextDifficulty ? nextMaximum : difficulty,
        unlockedNextDifficulty,
        reachedMaximum: difficulty === MAX_DIFFICULTY,
      };
    },
  });
})(window);
