(function (Game) {
  "use strict";

  if (!Game.Core || !Game.Data) throw new Error("state.js dependencies are missing");

  function createStarterItem(slot, name) {
    return {
      id: `starter_${slot}`,
      slot,
      name,
      rarity: "common",
      itemLevel: 0,
      stats: {},
      starter: true,
    };
  }

  function getCampFormationPositions(camp, memberCount) {
    const spawn = camp?.spawn;
    const bounds = camp?.activityBounds;
    if (
      !Number.isInteger(spawn?.x) ||
      !Number.isInteger(spawn?.y) ||
      !bounds
    ) {
      throw new Error("Camp spawn data is missing");
    }
    const blocked = new Set(
      (camp.props || [])
        .filter((prop) => prop.blocks !== false)
        .map((prop) => Game.Core.cellKey(prop.x, prop.y)),
    );
    const positions = [];
    for (let y = bounds.minY; y <= bounds.maxY; y += 1) {
      for (let x = bounds.minX; x <= bounds.maxX; x += 1) {
        if (!camp.map?.tiles?.[y]?.[x]?.exists) continue;
        if (blocked.has(Game.Core.cellKey(x, y))) continue;
        positions.push({ x, y });
      }
    }
    positions.sort((first, second) => {
      const firstDistance =
        Math.abs(first.x - spawn.x) + Math.abs(first.y - spawn.y);
      const secondDistance =
        Math.abs(second.x - spawn.x) + Math.abs(second.y - spawn.y);
      return (
        firstDistance - secondDistance ||
        first.y - second.y ||
        first.x - second.x
      );
    });
    if (positions.length < memberCount) {
      throw new Error("Camp formation has insufficient walkable positions");
    }
    return positions.slice(0, memberCount);
  }

  function createRuntime(camp) {
    const [initialPosition] = getCampFormationPositions(camp, 1);
    const warrior = {
      id: "warrior_raelyn",
      name: "蕾琳",
      classId: "warrior",
      role: "fighter",
      x: initialPosition.x,
      y: initialPosition.y,
      path: [],
      target: null,
      direction: { x: 1, y: 0 },
      moving: false,
      alive: true,
      currentHp: 100,
      attackTimer: 0,
      walkClock: 0,
      waitTimer: 0,
      hitFlash: 0,
      attackPulse: 0,
      baseStats: {
        maxHp: 100,
        attack: 12,
        defense: 5,
        attackInterval: 1.05,
        moveSpeed: 1.55,
      },
      equipment: {
        weapon: createStarterItem("weapon", "旧营地短剑"),
        armor: createStarterItem("armor", "旧皮甲"),
        charm: null,
      },
    };

    const party = {
      members: [warrior],
      maxSize: 1,
      formation: "solo",
    };

    const state = {
      scene: Game.Core.SCENES.CAMP,
      phase: Game.Core.PHASES.CAMP,
      overlay: Game.Core.OVERLAYS.NONE,
      speedMultiplier: 1,
      elapsedTime: 0,
      visualElapsedTime: 0,
      lastFrameTime: performance.now(),
      victories: 0,
      defeats: 0,
      dungeonCompletions: 0,
      maxUnlockedDifficulty: 1,
      selectedDifficulty: 1,
      difficultyClears: {},
      runDifficulty: 1,
      currentRoomId: null,
      currentRoomIndex: 0,
      visitedRoomIds: [],
      currentRouteNodeId: null,
      visitedProgressKeys: [],
      clearedEncounterIds: [],
      lootGeneratedEncounterIds: [],
      encounterBosses: [],
      routeRuntime: null,
      roomRuntime: null,
      camera: {
        x: 0,
        y: 0,
        initialized: false,
      },
      resolveTimer: 0,
      inventory: [],
      unreviewedLootIds: [],
      selectedItemId: null,
      floatingTexts: [],
      statusKey: "CAMP",
      statusContext: null,
    };

    return { state, party, warrior };
  }

  function resetMemberCombat(member, getStats) {
    const stats = getStats(member);
    member.currentHp = stats.maxHp;
    member.alive = true;
    prepareMemberForRoom(member);
  }

  function prepareMemberForRoom(member) {
    member.path = [];
    member.target = null;
    member.moving = false;
    member.attackTimer = 0;
    member.hitFlash = 0;
    member.attackPulse = 0;
  }

  function resetPartyForCamp(party, camp, getStats) {
    const formationPositions = getCampFormationPositions(
      camp,
      party.members.length,
    );
    party.members.forEach((member, index) => {
      resetMemberCombat(member, getStats);
      member.x = formationPositions[index].x;
      member.y = formationPositions[index].y;
      member.waitTimer = 0.25 + index * 0.15;
      member.direction = { x: 1, y: 0 };
    });
  }

  function updateTransientEffects(state, party, delta) {
    party.members.forEach((member) => {
      member.hitFlash = Math.max(0, member.hitFlash - delta);
      member.attackPulse = Math.max(0, member.attackPulse - delta);
    });
    (state.encounterBosses || []).forEach((boss) => {
      boss.hitFlash = Math.max(0, boss.hitFlash - delta);
      boss.attackPulse = Math.max(0, boss.attackPulse - delta);
    });
    state.floatingTexts.forEach((text) => {
      text.life -= delta;
      text.offsetY += delta * 24;
    });
    state.floatingTexts = state.floatingTexts.filter((text) => text.life > 0);
  }

  function addFloatingText(state, x, y, value, color) {
    state.floatingTexts.push({ x, y, value, color, life: 0.72, offsetY: 0 });
  }

  Game.State = Object.freeze({
    createRuntime,
    createStarterItem,
    resetMemberCombat,
    prepareMemberForRoom,
    resetPartyForCamp,
    updateTransientEffects,
    addFloatingText,
  });
})(window.CampfireTrials);
