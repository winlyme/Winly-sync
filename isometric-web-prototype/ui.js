(function (Game) {
  "use strict";

  if (!Game.Core || !Game.Data || !Game.Inventory) {
    throw new Error("ui.js dependencies are missing");
  }

  function create(documentRef, runtime) {
    const { state, party } = runtime;
    const elements = {};
    [
      "gameCanvas",
      "challengeButton",
      "difficultySelect",
      "statusText",
      "sceneLabel",
      "bossHud",
      "bossName",
      "bossHealthText",
      "bossHealthBar",
      "heroHpStat",
      "heroAttackStat",
      "heroDefenseStat",
      "heroSpeedStat",
      "weaponSlot",
      "armorSlot",
      "charmSlot",
      "victoryCount",
      "inventoryCount",
      "inventoryItems",
      "clearInventoryButton",
      "prepToggle",
      "prepContent",
      "prepSummaryStatus",
      "prepSummaryLootCount",
      "pendingLootBadge",
      "lootPanel",
      "lootKicker",
      "lootTitle",
      "lootQueue",
      "lootIcon",
      "lootName",
      "lootMeta",
      "lootStats",
      "lootCompare",
      "equipLootButton",
      "discardLootButton",
      "keepGearButton",
    ].forEach((id) => {
      elements[id] = documentRef.getElementById(id);
    });
    elements.statusCluster = documentRef.querySelector(".status-cluster");
    elements.speedButtons = [...documentRef.querySelectorAll("[data-speed]")];

    let inventorySignature = "";
    let difficultySignature = "";
    let lootSignature = "";
    let prepExpanded = false;
    let previousPendingCount = null;
    const narrowLayoutQuery = globalThis.matchMedia
      ? globalThis.matchMedia("(max-width: 900px)")
      : null;

    function bindHandlers(handlers) {
      elements.challengeButton.addEventListener("click", handlers.challenge);
      elements.difficultySelect.addEventListener("change", (event) => {
        handlers.selectDifficulty(Number(event.target.value));
      });
      elements.speedButtons.forEach((button) => {
        button.addEventListener("click", () => handlers.changeSpeed(Number(button.dataset.speed)));
      });
      elements.inventoryItems.addEventListener("click", (event) => {
        const target = event.target.closest("[data-item-action]");
        if (!target) return;
        const itemId = target.dataset.inventoryId;
        if (target.dataset.itemAction === "inspect") handlers.inspectItem(itemId);
        if (target.dataset.itemAction === "discard") handlers.discardItem(itemId);
      });
      elements.clearInventoryButton.addEventListener("click", handlers.clearInventory);
      elements.lootQueue.addEventListener("click", (event) => {
        const target = event.target.closest("[data-loot-id]");
        if (target) handlers.selectLoot(target.dataset.lootId);
      });
      elements.equipLootButton.addEventListener("click", handlers.equipSelected);
      elements.discardLootButton.addEventListener("click", handlers.discardSelected);
      elements.keepGearButton.addEventListener("click", handlers.closeOverlay);
      elements.prepToggle.addEventListener("click", togglePrepPanel);
      if (narrowLayoutQuery?.addEventListener) {
        narrowLayoutQuery.addEventListener("change", resetPrepPanel);
      } else if (narrowLayoutQuery?.addListener) {
        narrowLayoutQuery.addListener(resetPrepPanel);
      }
      documentRef.addEventListener("visibilitychange", handlers.visibilityChange);
    }

    function render() {
      const member = party.members[0];
      const stats = Game.Inventory.getMemberStats(member);
      const inDungeon = state.scene === Game.Core.SCENES.DUNGEON;
      elements.heroHpStat.textContent = inDungeon
        ? `${Math.ceil(member.currentHp)}/${stats.maxHp}`
        : String(stats.maxHp);
      elements.heroAttackStat.textContent = String(stats.attack);
      elements.heroDefenseStat.textContent = String(stats.defense);
      elements.heroSpeedStat.textContent = `${stats.attackInterval.toFixed(1)}s`;
      renderEquipment(member);
      renderInventory();
      renderDifficulty();
      renderLootOverlay(member);
      renderPrepSummary(member, stats);

      elements.victoryCount.textContent = `副本 ${state.dungeonCompletions} · 首领 ${state.victories}`;
      elements.statusCluster.classList.toggle("is-combat", state.phase === Game.Core.PHASES.COMBAT);
      elements.challengeButton.disabled = state.scene !== Game.Core.SCENES.CAMP;
      elements.challengeButton.textContent = `攻略难度 ${state.selectedDifficulty}`;
      elements.bossHud.hidden = !state.roomRuntime?.boss;

      if (state.roomRuntime) {
        const boss = state.roomRuntime.boss;
        elements.bossName.textContent = `${boss.name} · Lv.${boss.level}`;
        elements.bossHealthText.textContent = `生命 ${Math.ceil(boss.currentHp)} / ${boss.maxHp}`;
        elements.bossHealthBar.style.width = `${Math.max(0, (boss.currentHp / boss.maxHp) * 100)}%`;
      }

      if (inDungeon) {
        const node = state.routeRuntime?.node;
        elements.sceneLabel.textContent = `难度 ${state.runDifficulty} · ${node?.name || "连续副本"}`;
      } else {
        elements.sceneLabel.textContent = "营地";
      }
      elements.statusText.textContent = Game.Core.getStatusText(
        state.statusKey,
        state.statusContext,
      );
    }

    function renderEquipment(member) {
      ["weapon", "armor", "charm"].forEach((slot) => {
        const element = elements[`${slot}Slot`];
        const item = member.equipment[slot];
        element.textContent = item?.name || "空";
        element.style.color = Game.Inventory.itemColor(item);
      });
    }

    function renderDifficulty() {
      const maximumDifficulty = Math.min(
        Game.Core.MAX_DIFFICULTY,
        Math.max(1, state.maxUnlockedDifficulty),
      );
      const signature = `${maximumDifficulty}:${state.selectedDifficulty}:${state.scene}`;
      if (signature === difficultySignature) return;
      difficultySignature = signature;
      elements.difficultySelect.replaceChildren();
      for (let difficulty = 1; difficulty <= maximumDifficulty; difficulty += 1) {
        const option = documentRef.createElement("option");
        option.value = String(difficulty);
        option.textContent = `难度 ${difficulty}`;
        option.selected = difficulty === state.selectedDifficulty;
        elements.difficultySelect.append(option);
      }
      elements.difficultySelect.value = String(state.selectedDifficulty);
      elements.difficultySelect.disabled = state.scene !== Game.Core.SCENES.CAMP;
    }

    function renderPrepSummary(member, stats) {
      const pendingCount = state.unreviewedLootIds.length;
      if (
        previousPendingCount !== null &&
        pendingCount > previousPendingCount &&
        isNarrowLayout()
      ) {
        elements.prepToggle.classList.add("has-new-loot");
      }
      if (pendingCount === 0) {
        elements.prepToggle.classList.remove("has-new-loot");
      }
      previousPendingCount = pendingCount;

      const pendingText = `待处理 ${pendingCount}`;
      elements.prepSummaryLootCount.textContent = pendingText;
      elements.pendingLootBadge.textContent = pendingText;
      elements.prepSummaryLootCount.classList.toggle("has-pending", pendingCount > 0);
      elements.pendingLootBadge.classList.toggle("has-pending", pendingCount > 0);
      elements.prepSummaryStatus.textContent = `${member.name} · 生命 ${Math.ceil(member.currentHp)}/${stats.maxHp} · 攻击 ${stats.attack}`;
      syncPrepPanel();
    }

    function isNarrowLayout() {
      if (narrowLayoutQuery) return narrowLayoutQuery.matches;
      return documentRef.documentElement.clientWidth <= 900;
    }

    function syncPrepPanel() {
      const narrow = isNarrowLayout();
      elements.prepContent.hidden = narrow && !prepExpanded;
      elements.prepToggle.setAttribute(
        "aria-expanded",
        String(narrow ? prepExpanded : true),
      );
    }

    function togglePrepPanel() {
      if (!isNarrowLayout()) return;
      prepExpanded = !prepExpanded;
      elements.prepToggle.classList.remove("has-new-loot");
      syncPrepPanel();
    }

    function resetPrepPanel() {
      prepExpanded = false;
      syncPrepPanel();
    }

    function renderInventory() {
      const signature = `${state.scene}:${state.phase}|${state.inventory
        .map((item) => `${item.id}:${item.rarity}:${item.itemLevel}`)
        .join("|")}`;
      if (signature === inventorySignature) return;
      inventorySignature = signature;
      elements.inventoryCount.textContent = `${state.inventory.length} 件`;
      elements.clearInventoryButton.disabled =
        state.inventory.length === 0 || state.scene !== Game.Core.SCENES.CAMP;
      elements.inventoryItems.replaceChildren();
      if (state.inventory.length === 0) {
        const empty = documentRef.createElement("span");
        empty.className = "inventory-empty";
        empty.textContent = "暂无待处理装备";
        elements.inventoryItems.append(empty);
        return;
      }
      state.inventory.forEach((item) => {
        const row = documentRef.createElement("div");
        const inspect = documentRef.createElement("button");
        const discard = documentRef.createElement("button");
        row.className = "inventory-item-row";
        inspect.type = "button";
        inspect.className = "inventory-item";
        inspect.dataset.itemAction = "inspect";
        inspect.dataset.inventoryId = item.id;
        inspect.disabled = state.scene !== Game.Core.SCENES.CAMP;
        inspect.style.color = Game.Inventory.itemColor(item);
        inspect.innerHTML = `<strong></strong><span></span>`;
        inspect.querySelector("strong").textContent = item.name;
        inspect.querySelector("span").textContent = `${Game.Inventory.slotLabel(item.slot)} · ${item.itemLevel}`;
        discard.type = "button";
        discard.className = "inventory-discard";
        discard.dataset.itemAction = "discard";
        discard.dataset.inventoryId = item.id;
        discard.disabled = state.scene !== Game.Core.SCENES.CAMP;
        discard.textContent = "×";
        discard.setAttribute("aria-label", `丢弃${item.name}`);
        row.append(inspect, discard);
        elements.inventoryItems.append(row);
      });
    }

    function renderLootOverlay(member) {
      const lootInteractive = canManageLoot();
      const availableIds = new Set(state.inventory.map((item) => item.id));
      state.unreviewedLootIds = state.unreviewedLootIds.filter((id) => availableIds.has(id));
      const queue = state.unreviewedLootIds
        .map((id) => state.inventory.find((item) => item.id === id))
        .filter(Boolean);
      const selected = state.inventory.find((item) => item.id === state.selectedItemId) || queue[0];
      if (state.overlay === Game.Core.OVERLAYS.NONE || !selected) {
        elements.lootPanel.hidden = true;
        lootSignature = "";
        return;
      }
      if (!state.selectedItemId) state.selectedItemId = selected.id;
      elements.lootPanel.hidden = false;
      elements.lootPanel.classList.toggle("is-readonly", !lootInteractive);
      const signature = `${state.overlay}:${state.selectedItemId}:${lootInteractive}:${queue.map((item) => item.id).join("|")}`;
      if (signature !== lootSignature) {
        lootSignature = signature;
        elements.lootQueue.replaceChildren();
        const queueItems = state.overlay === Game.Core.OVERLAYS.LOOT ? queue : [selected];
        queueItems.forEach((item) => {
          const button = documentRef.createElement("button");
          button.type = "button";
          button.dataset.lootId = item.id;
          button.textContent = item.name;
          button.style.color = Game.Inventory.itemColor(item);
          button.disabled = !lootInteractive;
          button.classList.toggle("is-active", item.id === state.selectedItemId);
          elements.lootQueue.append(button);
        });
      }
      const rarity = Game.Data.rarityDefinitions[selected.rarity];
      const icons = { weapon: "†", armor: "▣", charm: "◆" };
      elements.lootKicker.textContent =
        state.overlay === Game.Core.OVERLAYS.LOOT
          ? `待处理战利品 · ${queue.length} 件`
          : "背包装备";
      elements.lootTitle.textContent = state.overlay === Game.Core.OVERLAYS.LOOT ? "获得装备" : "查看装备";
      elements.lootIcon.textContent = icons[selected.slot];
      elements.lootIcon.style.color = rarity.color;
      elements.lootName.textContent = selected.name;
      elements.lootName.style.color = rarity.color;
      elements.lootMeta.textContent = `${rarity.label} · 物品等级 ${selected.itemLevel} · ${Game.Inventory.slotLabel(selected.slot)}`;
      elements.lootStats.textContent = Game.Inventory.formatItemStats(selected.stats);
      elements.lootCompare.textContent = Game.Inventory.compareItem(
        selected,
        member.equipment[selected.slot],
      );
      elements.equipLootButton.textContent = "装备此物品";
      elements.discardLootButton.textContent = "丢弃这件";
      elements.keepGearButton.textContent =
        state.scene === Game.Core.SCENES.DUNGEON ? "稍后处理" : "关闭";
      elements.equipLootButton.disabled = !lootInteractive;
      elements.discardLootButton.disabled = !lootInteractive;
      elements.keepGearButton.disabled = !lootInteractive;
    }

    function canManageLoot() {
      return (
        state.phase === Game.Core.PHASES.CAMP ||
        state.phase === Game.Core.PHASES.APPROACH
      );
    }

    syncPrepPanel();

    return Object.freeze({ elements, bindHandlers, render });
  }

  Game.UI = Object.freeze({ create });
})(window.CampfireTrials);
