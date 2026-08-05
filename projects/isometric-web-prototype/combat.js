(function (Game) {
  "use strict";

  if (!Game.Core || !Game.Data || !Game.Inventory) {
    throw new Error("combat.js dependencies are missing");
  }

  function createBoss(level, bossId, partySize, position) {
    const definition = Game.Data.bossDefinitions[bossId] || Game.Data.bossDefinitions.graystone_keeper;
    const activeMembers = Math.max(1, partySize);
    const healthScale = 1 + (activeMembers - 1) * 0.72;
    const attackScale = 1 + (activeMembers - 1) * 0.09;
    const maxHp = Math.round(
      (66 + level * 18) * healthScale * definition.healthMultiplier,
    );
    return {
      id: bossId,
      name: definition.name,
      level,
      x: Number.isInteger(position?.x) ? position.x : 3,
      y: Number.isInteger(position?.y) ? position.y : 2,
      maxHp,
      currentHp: maxHp,
      attack: Math.round(
        (8 + level * 1.4) * attackScale * definition.attackMultiplier,
      ),
      defense: 2 + Math.floor(level * 0.45),
      attackInterval: Math.max(1.05, 1.42 - level * 0.025),
      attackTimer: 0,
      alive: true,
      hitFlash: 0,
      attackPulse: 0,
      bodyColor: definition.bodyColor,
      highlightColor: definition.highlightColor,
      eyeColor: definition.eyeColor,
    };
  }

  function calculateDamage(attack, defense, defenseWeight) {
    const variance = 0.92 + Math.random() * 0.16;
    return Math.max(1, Math.round((attack - defense * defenseWeight) * variance));
  }

  function generateLoot(level) {
    const roll = Math.random() + Math.min(level * 0.012, 0.15);
    const rarity = roll > 0.92 ? "epic" : roll > 0.59 ? "rare" : "common";
    const definition = Game.Data.rarityDefinitions[rarity];
    const slots = ["weapon", "armor", "charm"];
    const slot = slots[Math.floor(Math.random() * slots.length)];
    const names = {
      weapon: ["灰石长剑", "营火守卫斧", "铁脊战刃"],
      armor: ["旅团锁甲", "炉灰胸甲", "守门者重铠"],
      charm: ["余烬护符", "岩心徽记", "远征铜印"],
    };
    const stats = {};
    if (slot === "weapon") {
      stats.attack = 2 + Math.ceil(level * 1.15 * definition.multiplier);
    } else if (slot === "armor") {
      stats.maxHp = 8 + Math.ceil(level * 3.1 * definition.multiplier);
      stats.defense = 1 + Math.floor(level * 0.48 * definition.multiplier);
    } else {
      stats.attack = 1 + Math.ceil(level * 0.42 * definition.multiplier);
      stats.maxHp = 4 + Math.ceil(level * 1.6 * definition.multiplier);
      stats.defense = Math.floor(level * 0.22 * definition.multiplier);
    }
    return {
      id: `${slot}_${level}_${Date.now()}_${Math.floor(Math.random() * 100000)}`,
      slot,
      name: names[slot][Math.floor(Math.random() * names[slot].length)],
      rarity,
      itemLevel: level,
      stats,
      starter: false,
    };
  }

  function updateBattle(delta, party, boss) {
    const events = [];
    const livingMembers = party.members.filter((member) => member.alive);
    livingMembers.forEach((member) => {
      member.attackTimer -= delta;
      member.direction = Game.Core.directionToward(member, boss);
      if (member.attackTimer <= 0 && boss.alive) {
        const stats = Game.Inventory.getMemberStats(member);
        const damage = calculateDamage(stats.attack, boss.defense, 0.48);
        boss.currentHp = Math.max(0, boss.currentHp - damage);
        boss.hitFlash = 0.16;
        member.attackPulse = 0.18;
        member.attackTimer += stats.attackInterval;
        events.push({ type: "damage", target: "boss", x: boss.x, y: boss.y, damage });
        if (boss.currentHp <= 0) boss.alive = false;
      }
    });

    if (!boss.alive) {
      events.push({ type: "boss-defeated" });
      return events;
    }

    boss.attackTimer -= delta;
    const target = livingMembers[0];
    if (target && boss.attackTimer <= 0) {
      const targetStats = Game.Inventory.getMemberStats(target);
      const damage = calculateDamage(boss.attack, targetStats.defense, 0.62);
      target.currentHp = Math.max(0, target.currentHp - damage);
      target.hitFlash = 0.16;
      target.attackPulse = 0.12;
      boss.attackPulse = 0.2;
      boss.attackTimer += boss.attackInterval;
      events.push({ type: "damage", target: "member", x: target.x, y: target.y, damage });
      if (target.currentHp <= 0) {
        target.alive = false;
        target.moving = false;
      }
    }
    if (party.members.every((member) => !member.alive)) {
      events.push({ type: "party-defeated" });
    }
    return events;
  }

  Game.Combat = Object.freeze({ createBoss, generateLoot, updateBattle });
})(window.CampfireTrials);
