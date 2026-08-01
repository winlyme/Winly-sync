(function (Game) {
  "use strict";

  const requiredModules = [
    "Core",
    "Data",
    "Inventory",
    "State",
    "World",
    "Combat",
    "Save",
    "Renderer",
    "UI",
  ];
  const missingModules = requiredModules.filter((name) => !Game[name]);
  if (missingModules.length > 0) {
    throw new Error(`Missing game modules: ${missingModules.join(", ")}`);
  }

  const canvas = document.getElementById("gameCanvas");
  const worldData = Game.Data.createWorld(canvas.width, canvas.height);
  const runtime = Game.State.createRuntime(worldData.camp);
  const { state, party } = runtime;
  const ui = Game.UI.create(document, runtime);
  const renderer = Game.Renderer.create(canvas, worldData, runtime);
  const { SCENES, PHASES, OVERLAYS, MAX_DIFFICULTY } = Game.Core;
  const dungeonBounds = Game.World.getMapScreenBounds(worldData.dungeon);
  const GAMEPLAY_BASELINE_MULTIPLIER = 2;

  const loadResult = Game.Save.load(state, party);
  if (!loadResult.ok) setStatus("SAVE_FAILED");
  Game.State.resetPartyForCamp(
    party,
    worldData.camp,
    Game.Inventory.getMemberStats,
  );
  if (state.unreviewedLootIds.length > 0) {
    state.overlay = OVERLAYS.LOOT;
    state.selectedItemId = state.unreviewedLootIds[0];
  }

  ui.bindHandlers({
    challenge: startSelectedDifficulty,
    changeSpeed,
    selectDifficulty,
    inspectItem,
    discardItem,
    clearInventory,
    selectLoot,
    equipSelected,
    discardSelected,
    closeOverlay,
    visibilityChange,
  });

  ui.render();
  requestAnimationFrame(gameLoop);

  function gameLoop(now) {
    const delta = Math.min((now - state.lastFrameTime) / 1000, 0.05);
    state.lastFrameTime = now;
    const gameplayDelta =
      delta * state.speedMultiplier * GAMEPLAY_BASELINE_MULTIPLIER;
    state.visualElapsedTime += delta;
    state.elapsedTime += gameplayDelta;
    update(gameplayDelta, delta);
    renderer.render();
    ui.render();
    requestAnimationFrame(gameLoop);
  }

  function update(delta, cameraDelta = delta) {
    Game.State.updateTransientEffects(state, party, delta);
    if (state.scene === SCENES.CAMP) {
      Game.World.updateCamp(
        delta,
        party,
        worldData.camp,
        Game.Inventory.getMemberStats,
      );
    } else {
      updateDungeon(delta);
      if (state.scene === SCENES.DUNGEON) updateDungeonCamera(cameraDelta);
    }
  }

  function updateDungeon(delta) {
    const routeRuntime = state.routeRuntime;
    if (!routeRuntime) return;
    const livingMembers = party.members.filter((member) => member.alive);

    if (state.phase === PHASES.APPROACH) {
      livingMembers.forEach((member) => {
        if (member.path.length > 0) {
          Game.World.advanceAlongPath(member, delta, Game.Inventory.getMemberStats);
        }
      });
      if (state.roomRuntime?.boss) {
        const ready = membersAtEngagementPosition(livingMembers, state.roomRuntime);
        if (ready) beginCombat();
      } else {
        const ready = livingMembers.every(
          (member) =>
            member.path.length === 0 &&
            Game.Core.distanceBetween(member, routeRuntime.node.position) <= 0.01,
        );
        if (ready) advanceFromRouteNode();
      }
      return;
    }

    if (state.phase === PHASES.COMBAT) {
      const runtimeRoom = state.roomRuntime;
      if (!runtimeRoom?.boss) {
        abortDungeonRoute();
        return;
      }
      const events = Game.Combat.updateBattle(delta, party, runtimeRoom.boss);
      for (const event of events) {
        if (event.type === "damage") {
          Game.State.addFloatingText(
            state,
            event.x,
            event.y,
            `-${event.damage}`,
            event.target === "boss" ? "#f6d77d" : "#ef8d70",
          );
        }
        if (event.type === "boss-defeated") {
          finishVictory();
          break;
        }
        if (event.type === "party-defeated") {
          finishDefeat();
          break;
        }
      }
      return;
    }

    if (state.phase === PHASES.VICTORY) {
      state.resolveTimer -= delta;
      if (state.resolveTimer <= 0) advanceAfterVictory();
      return;
    }

    if (state.phase === PHASES.DEFEAT) {
      state.resolveTimer -= delta;
      if (state.resolveTimer <= 0) {
        returnToCamp(saveProgress("FAILURE"));
      }
    }
  }

  function startSelectedDifficulty() {
    if (state.scene !== SCENES.CAMP) return;
    state.scene = SCENES.DUNGEON;
    state.runDifficulty = Game.Core.clampInteger(
      state.selectedDifficulty,
      1,
      MAX_DIFFICULTY,
    );
    state.currentRoomIndex = 0;
    state.visitedRoomIds = [];
    state.currentRouteNodeId = null;
    state.visitedProgressKeys = [];
    state.clearedEncounterIds = [];
    state.lootGeneratedEncounterIds = [];
    state.encounterBosses = createEncounterBosses();
    state.routeRuntime = null;
    state.roomRuntime = null;
    state.floatingTexts = [];
    state.camera.initialized = false;
    party.members.forEach((member, index) => {
      Game.State.resetMemberCombat(member, Game.Inventory.getMemberStats);
      member.x = worldData.dungeon.entry.x - (index % 2);
      member.y = worldData.dungeon.entry.y - Math.floor(index / 2);
      member.direction = { x: 1, y: 0 };
    });
    enterRouteNode(worldData.dungeon.entranceRoomId);
    if (state.scene === SCENES.DUNGEON) updateDungeonCamera(0, true);
  }

  function enterRouteNode(nodeId) {
    const node = Game.Data.getDungeonNode(worldData.dungeon, nodeId);
    if (!node) {
      abortDungeonRoute();
      return false;
    }
    const progressKey = createProgressKey(nodeId);
    if (state.visitedProgressKeys.includes(progressKey)) {
      abortDungeonRoute();
      return false;
    }
    if (node.kind === "boss" && state.clearedEncounterIds.includes(nodeId)) {
      abortDungeonRoute();
      return false;
    }

    state.scene = SCENES.DUNGEON;
    state.phase = PHASES.APPROACH;
    state.currentRouteNodeId = nodeId;
    state.visitedProgressKeys.push(progressKey);
    state.routeRuntime = { node };
    state.roomRuntime = null;
    state.encounterBosses.forEach((boss) => {
      boss.active = false;
    });
    state.currentRoomId = node.kind === "boss" ? nodeId : null;
    state.currentRoomIndex = nextEncounterIndex();
    state.floatingTexts = [];

    party.members.forEach((member) => {
      Game.State.prepareMemberForRoom(member);
    });

    if (node.kind === "boss") {
      const roomIndex = worldData.dungeon.roomOrder.indexOf(nodeId);
      if (roomIndex < 0) {
        abortDungeonRoute();
        return false;
      }
      state.currentRoomIndex = roomIndex;
      if (!state.visitedRoomIds.includes(nodeId)) state.visitedRoomIds.push(nodeId);
      const boss = state.encounterBosses.find(
        (candidate) => candidate.encounterId === nodeId && candidate.alive,
      );
      const engagementValidation = Game.Data.validateBossEngagement(
        worldData.dungeon,
        node,
      );
      if (!boss || !engagementValidation.ok) {
        abortDungeonRoute();
        return false;
      }
      const blocked = Game.World.buildBlockedSet(
        worldData.dungeon.props,
        aliveEncounterBosses(),
      );
      const plans = party.members.map((member) =>
        Game.World.findApproachPathResult(
          member,
          node.engagement.position,
          worldData.dungeon.map,
          blocked,
          { initialDirection: member.direction },
        ),
      );
      if (plans.some((plan) => !plan.reachable)) {
        abortDungeonRoute();
        return false;
      }
      state.roomRuntime = {
        room: node,
        boss,
        engagement: {
          position: { ...node.engagement.position },
          bossDirection: { ...node.engagement.bossDirection },
          memberDirection: { ...node.engagement.memberDirection },
        },
        cleared: false,
        lootGenerated: false,
      };
      boss.active = true;
      party.members.forEach((member, index) => {
        member.path = plans[index].path;
        member.target = { ...node.engagement.position };
      });
    } else {
      const blocked = Game.World.buildBlockedSet(
        worldData.dungeon.props,
        aliveEncounterBosses(),
      );
      const plans = party.members.map((member) =>
        Game.World.findPreferredPathResult(
          { x: Math.round(member.x), y: Math.round(member.y) },
          node.position,
          worldData.dungeon.map,
          blocked,
          { initialDirection: member.direction },
        ),
      );
      if (plans.some((plan) => !plan.reachable)) {
        abortDungeonRoute();
        return false;
      }
      party.members.forEach((member, index) => {
        member.path = plans[index].path;
        member.target = { ...node.position };
      });
    }
    setStatus("APPROACH", { bossNumber: state.currentRoomIndex + 1 });
    return true;
  }

  function beginCombat() {
    if (state.phase !== PHASES.APPROACH || !state.roomRuntime?.boss) return;
    const boss = state.roomRuntime.boss;
    const runtimeRoom = state.roomRuntime;
    const engagementValidation = Game.Data.validateBossEngagement(
      worldData.dungeon,
      runtimeRoom.room,
    );
    if (
      !engagementValidation.ok ||
      !membersAtEngagementPosition(party.members.filter((member) => member.alive), runtimeRoom)
    ) {
      abortDungeonRoute();
      return;
    }
    party.members.forEach((member) => {
      member.moving = false;
      member.attackTimer = 0.28;
      member.direction = { ...runtimeRoom.engagement.memberDirection };
    });
    boss.direction = { ...runtimeRoom.engagement.bossDirection };
    boss.attackTimer = 0.78;
    state.phase = PHASES.COMBAT;
    setStatus("COMBAT", { bossNumber: state.currentRoomIndex + 1 });
  }

  function finishVictory() {
    if (state.phase !== PHASES.COMBAT) return;
    const runtimeRoom = state.roomRuntime;
    runtimeRoom.boss.alive = false;
    runtimeRoom.boss.active = false;
    runtimeRoom.boss.currentHp = 0;
    state.encounterBosses = state.encounterBosses.filter(
      (boss) => boss !== runtimeRoom.boss,
    );
    runtimeRoom.cleared = true;
    if (!state.clearedEncounterIds.includes(state.currentRouteNodeId)) {
      state.clearedEncounterIds.push(state.currentRouteNodeId);
    }
    party.members.forEach((member) => {
      member.moving = false;
      member.path = [];
    });
    state.victories = incrementCount(state.victories);
    state.phase = PHASES.VICTORY;
    state.resolveTimer = 0.85;
    setStatus("VICTORY", { bossNumber: state.currentRoomIndex + 1 });
  }

  function finishDefeat() {
    if (state.phase !== PHASES.COMBAT) return;
    state.defeats = incrementCount(state.defeats);
    state.phase = PHASES.DEFEAT;
    state.resolveTimer = 1.35;
    setStatus("FAILURE");
  }

  function advanceAfterVictory() {
    const runtimeRoom = state.roomRuntime;
    const encounterId = state.currentRouteNodeId;
    if (
      !runtimeRoom ||
      runtimeRoom.lootGenerated ||
      state.lootGeneratedEncounterIds.includes(encounterId)
    ) {
      return;
    }
    runtimeRoom.lootGenerated = true;
    state.lootGeneratedEncounterIds.push(encounterId);
    const shouldPreserveSelection =
      state.overlay === OVERLAYS.LOOT &&
      state.inventory.some((item) => item.id === state.selectedItemId);
    const loot = Game.Combat.generateLoot(runtimeRoom.boss.level);
    Game.Inventory.addItem(state.inventory, loot);
    state.unreviewedLootIds.push(loot.id);
    state.overlay = OVERLAYS.LOOT;
    if (!shouldPreserveSelection) {
      state.selectedItemId = loot.id;
    }
    const lootStatus = saveProgress("LOOT");

    continueFromCurrentNode(true, lootStatus);
  }

  function advanceFromRouteNode() {
    if (state.phase !== PHASES.APPROACH || state.roomRuntime) return;
    continueFromCurrentNode(false);
  }

  function continueFromCurrentNode(healAfterBoss, successStatusKey) {
    const route = Game.Data.resolveNextNode(
      worldData.dungeon,
      state.currentRouteNodeId,
      state.clearedEncounterIds,
    );
    if (route.type === "next") {
      if (healAfterBoss) {
        party.members.forEach((member) => {
          const stats = Game.Inventory.getMemberStats(member);
          member.currentHp = Math.min(
            stats.maxHp,
            member.currentHp + Math.round(stats.maxHp * 0.4),
          );
        });
      }
      if (!enterRouteNode(route.nodeId)) return false;
      if (successStatusKey) setStatus(successStatusKey);
      return true;
    }
    if (
      route.type === "complete" &&
      state.roomRuntime?.cleared &&
      state.clearedEncounterIds.includes(state.currentRouteNodeId)
    ) {
      completeDifficulty();
      return true;
    }
    abortDungeonRoute();
    return false;
  }

  function createProgressKey(nodeId) {
    const cleared = [...state.clearedEncounterIds].sort().join(",");
    return `${nodeId}|${cleared}`;
  }

  function createEncounterBosses() {
    return worldData.dungeon.roomOrder.map((roomId, roomIndex) => {
      const reference = Game.Data.getDungeonRoom(worldData.dungeon, roomId);
      if (!reference) throw new Error(`Invalid encounter node: ${roomId}`);
      const boss = Game.Combat.createBoss(
        state.runDifficulty + roomIndex,
        reference.room.bossId,
        party.members.length,
        reference.room.position,
      );
      boss.encounterId = roomId;
      boss.active = false;
      boss.direction = { ...reference.room.engagement.bossDirection };
      return boss;
    });
  }

  function membersAtEngagementPosition(members, runtimeRoom) {
    const position = runtimeRoom?.engagement?.position;
    return (
      Boolean(position) &&
      members.length > 0 &&
      members.every(
        (member) =>
          member.path.length === 0 &&
          Math.abs(member.x - position.x) <= 0.001 &&
          Math.abs(member.y - position.y) <= 0.001,
      )
    );
  }

  function aliveEncounterBosses() {
    return state.encounterBosses.filter((boss) => boss.alive);
  }

  function nextEncounterIndex() {
    const nextId = worldData.dungeon.roomOrder.find(
      (roomId) => !state.clearedEncounterIds.includes(roomId),
    );
    const index = worldData.dungeon.roomOrder.indexOf(nextId);
    return index >= 0 ? index : Math.max(0, worldData.dungeon.roomOrder.length - 1);
  }

  function updateDungeonCamera(delta, snap = false) {
    const member = party.members[0];
    const focusPoint = Game.World.gridToScreen(
      worldData.dungeon.origin,
      member.x,
      member.y,
    );
    const target = Game.World.computeClampedCameraTarget(
      focusPoint,
      dungeonBounds,
      { width: canvas.width, height: canvas.height },
    );
    Game.World.updateCamera(state.camera, target, delta, snap);
  }

  function completeDifficulty() {
    const difficulty = state.runDifficulty;
    state.dungeonCompletions = incrementCount(state.dungeonCompletions);
    state.difficultyClears[difficulty] =
      incrementCount(state.difficultyClears[difficulty]);
    const difficultyProgress = Game.Core.resolveDifficultyProgress(
      difficulty,
      state.maxUnlockedDifficulty,
    );
    state.maxUnlockedDifficulty = difficultyProgress.maxUnlockedDifficulty;
    state.selectedDifficulty = difficultyProgress.selectedDifficulty;
    const completionStatus = difficulty === MAX_DIFFICULTY ? "MAX_CLEAR" : "CLEAR";
    returnToCamp(saveProgress(completionStatus));
  }

  function abortDungeonRoute() {
    returnToCamp(saveProgress("ROUTE_ERROR"));
  }

  function returnToCamp(statusKey) {
    state.scene = SCENES.CAMP;
    state.phase = PHASES.CAMP;
    state.currentRoomId = null;
    state.currentRoomIndex = 0;
    state.visitedRoomIds = [];
    state.currentRouteNodeId = null;
    state.visitedProgressKeys = [];
    state.clearedEncounterIds = [];
    state.lootGeneratedEncounterIds = [];
    state.encounterBosses = [];
    state.routeRuntime = null;
    state.roomRuntime = null;
    state.camera.x = 0;
    state.camera.y = 0;
    state.camera.initialized = false;
    state.floatingTexts = [];
    Game.State.resetPartyForCamp(
      party,
      worldData.camp,
      Game.Inventory.getMemberStats,
    );
    setStatus(statusKey);
  }

  function selectDifficulty(value) {
    if (state.scene !== SCENES.CAMP) return;
    state.selectedDifficulty = Game.Core.clampInteger(
      value,
      1,
      Math.min(MAX_DIFFICULTY, state.maxUnlockedDifficulty),
    );
    saveProgress("DIFFICULTY_SELECTED");
  }

  function changeSpeed(value) {
    state.speedMultiplier = [1, 2].includes(value) ? value : 1;
    ui.elements.speedButtons.forEach((button) => {
      button.classList.toggle("is-active", Number(button.dataset.speed) === state.speedMultiplier);
    });
  }

  function visibilityChange() {
    state.lastFrameTime = performance.now();
  }

  function inspectItem(itemId) {
    if (state.scene !== SCENES.CAMP) return;
    if (!state.inventory.some((item) => item.id === itemId)) return;
    state.selectedItemId = itemId;
    state.overlay = OVERLAYS.INVENTORY;
    setStatus("INVENTORY_VIEW");
  }

  function selectLoot(itemId) {
    if (!canManageLoot()) return;
    if (!state.inventory.some((item) => item.id === itemId)) return;
    state.selectedItemId = itemId;
  }

  function equipSelected() {
    if (!canManageLoot()) return;
    const item = Game.Inventory.removeItem(state.inventory, state.selectedItemId);
    if (!item) return;
    const previous = Game.Inventory.equipItem(party.members[0], item);
    if (previous) Game.Inventory.addItem(state.inventory, previous);
    removeUnreviewed(item.id);
    chooseNextOverlayItem();
    saveProgress("EQUIPPED");
  }

  function discardSelected() {
    if (!canManageLoot()) return;
    const item = state.inventory.find((candidate) => candidate.id === state.selectedItemId);
    if (!item) return;
    Game.Inventory.discardItem(state.inventory, item.id);
    removeUnreviewed(item.id);
    chooseNextOverlayItem();
    saveProgress("DISCARDED");
  }

  function discardItem(itemId) {
    if (state.scene !== SCENES.CAMP) return;
    const item = state.inventory.find((candidate) => candidate.id === itemId);
    if (!item) return;
    Game.Inventory.discardItem(state.inventory, itemId);
    removeUnreviewed(itemId);
    if (state.selectedItemId === itemId) chooseNextOverlayItem();
    saveProgress("DISCARDED");
  }

  function clearInventory() {
    if (state.scene !== SCENES.CAMP || state.inventory.length === 0) return;
    if (!globalThis.confirm(`确定清空背包中的 ${state.inventory.length} 件装备吗？`)) return;
    Game.Inventory.clearAll(state.inventory);
    state.unreviewedLootIds = [];
    state.selectedItemId = null;
    state.overlay = OVERLAYS.NONE;
    saveProgress("INVENTORY_CLEARED");
  }

  function closeOverlay() {
    if (!canManageLoot()) return;
    state.overlay = OVERLAYS.NONE;
    state.selectedItemId = null;
    setStatus("LOOT_CLOSED");
  }

  function removeUnreviewed(itemId) {
    state.unreviewedLootIds = state.unreviewedLootIds.filter((id) => id !== itemId);
  }

  function chooseNextOverlayItem() {
    const availableIds = new Set(state.inventory.map((item) => item.id));
    state.unreviewedLootIds = state.unreviewedLootIds.filter((id) => availableIds.has(id));
    const nextId =
      state.overlay === OVERLAYS.LOOT
        ? state.unreviewedLootIds[0]
        : null;
    state.selectedItemId = nextId || null;
    if (!nextId) state.overlay = OVERLAYS.NONE;
  }

  function saveProgress(successStatusKey) {
    const result = Game.Save.save(state, party);
    const statusKey = result.ok ? successStatusKey : "SAVE_FAILED";
    setStatus(statusKey);
    return statusKey;
  }

  function setStatus(statusKey, statusContext = null) {
    Game.Core.getStatusText(statusKey, statusContext);
    state.statusKey = statusKey;
    state.statusContext = statusContext ? { ...statusContext } : null;
  }

  function canManageLoot() {
    return state.phase === PHASES.CAMP || state.phase === PHASES.APPROACH;
  }

  function incrementCount(value) {
    return Math.min(
      Number.MAX_SAFE_INTEGER,
      Game.Core.toSafeNonNegativeInteger(value) + 1,
    );
  }

  if (globalThis.__CAMPFIRE_TEST__) {
    Game.Debug = Object.freeze({
      state,
      party,
      worldData,
      ui,
      renderer,
      startSelectedDifficulty,
      update,
      enterRouteNode,
      advanceFromRouteNode,
      beginCombat,
      finishVictory,
      finishDefeat,
      advanceAfterVictory,
      handlers: Object.freeze({
        selectLoot,
        equipSelected,
        discardSelected,
        closeOverlay,
        changeSpeed,
        visibilityChange,
      }),
    });
  }
})(window.CampfireTrials);
