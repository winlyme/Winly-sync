(function (Game) {
  "use strict";

  if (!Game.Core || !Game.Data || !Game.World || !Game.Inventory) {
    throw new Error("render.js dependencies are missing");
  }

  function create(canvas, worldData, runtime) {
    const context = canvas.getContext("2d");
    const { state, party } = runtime;
    const { camp, dungeon } = worldData;
    const palette = Game.Data.palette;
    const { TILE_WIDTH, TILE_HEIGHT, SCENES } = Game.Core;
    const raelynActions = {
      idle: { frameCount: 23, frameRate: 30, looping: true },
      walk: { frameCount: 24, frameRate: 30, looping: true },
      melee_attack: { frameCount: 38, frameRate: 40, looping: false },
      death: { frameCount: 44, frameRate: 36, looping: false },
    };
    const raelynFrames = loadRaelynFrames();
    const raelynMemberStates = new WeakMap();
    const RAELYN_FRAME_WIDTH = 192;
    const RAELYN_FRAME_HEIGHT = 156;
    const RAELYN_ANCHOR_X = 96;
    const RAELYN_ANCHOR_Y = 81;
    const RAELYN_SCALE = 1.55;
    let characterAnimationTime = 0;
    let previousVisualElapsedTime = state.visualElapsedTime;

    function loadRaelynFrames() {
      const actions = {};
      Object.entries(raelynActions).forEach(([action, definition]) => {
        actions[action] = {};
        ["left", "right"].forEach((direction) => {
          actions[action][direction] = Array.from(
            { length: definition.frameCount },
            (_, index) => {
              const frame = { image: new Image(), failed: false };
              const frameNumber = String(index + 1).padStart(4, "0");
              frame.image.decoding = "async";
              frame.image.addEventListener(
                "error",
                () => {
                  frame.failed = true;
                },
                { once: true },
              );
              frame.image.src =
                `art/third-party/raelyn-runtime/${action}/${direction}/` +
                `frame_${frameNumber}.png`;
              return frame;
            },
          );
        });
      });
      return actions;
    }

    function activeScene() {
      if (state.scene === SCENES.CAMP) return camp;
      return dungeon;
    }

    function advanceCharacterAnimationClock() {
      const visualDelta = Math.max(
        0,
        state.visualElapsedTime - previousVisualElapsedTime,
      );
      const animationSpeed = state.speedMultiplier === 2 ? 2 : 1;
      characterAnimationTime += visualDelta * animationSpeed;
      previousVisualElapsedTime = state.visualElapsedTime;
    }

    function gridToScreen(x, y) {
      const point = Game.World.gridToScreen(activeScene().origin, x, y);
      if (state.scene === SCENES.DUNGEON) {
        point.x += state.camera.x;
        point.y += state.camera.y;
      }
      return point;
    }

    function render() {
      advanceCharacterAnimationClock();
      context.clearRect(0, 0, canvas.width, canvas.height);
      context.imageSmoothingEnabled = false;
      drawBackdrop();
      const scene = activeScene();
      const tiles = [];
      for (let y = 0; y < scene.map.height; y += 1) {
        for (let x = 0; x < scene.map.width; x += 1) {
          const tile = scene.map.tiles[y][x];
          if (tile.exists) tiles.push({ x, y, ...tile });
        }
      }
      tiles
        .sort((a, b) => a.x + a.y - (b.x + b.y) || a.x - b.x)
        .forEach(drawTile);
      if (state.scene === SCENES.CAMP) drawTargetMarker();

      const renderables = scene.props.map((prop) => ({
        depth: prop.x + prop.y + 0.12,
        draw: () => drawProp(prop),
      }));
      if (state.scene === SCENES.DUNGEON) {
        state.encounterBosses.filter((boss) => boss.alive).forEach((boss) => {
          renderables.push({
            depth: boss.x + boss.y + 0.3,
            draw: () => drawBoss(boss),
          });
        });
      }
      party.members.forEach((member) => {
        renderables.push({
          depth: member.x + member.y + 0.35,
          draw: () => drawWarrior(member),
        });
      });
      renderables
        .sort((a, b) => a.depth - b.depth)
        .forEach((renderable) => renderable.draw());
      drawFloatingTexts();
      drawAmbientParticles();
    }

    function drawBackdrop() {
      const isCamp = state.scene === SCENES.CAMP;
      const gradient = context.createLinearGradient(0, 0, 0, canvas.height);
      gradient.addColorStop(0, isCamp ? palette.campSkyTop : palette.dungeonSkyTop);
      gradient.addColorStop(1, isCamp ? palette.campSkyBottom : palette.dungeonSkyBottom);
      context.fillStyle = gradient;
      context.fillRect(0, 0, canvas.width, canvas.height);
      context.globalAlpha = isCamp ? 0.17 : 0.11;
      for (let index = 0; index < 18; index += 1) {
        const x = (index * 193 + 80) % canvas.width;
        const y = (index * 83 + 42) % canvas.height;
        const radius = 1 + (index % 3);
        context.fillStyle = isCamp
          ? index % 2 === 0
            ? "#f3e5b7"
            : "#b4da7f"
          : index % 2 === 0
            ? "#af9fc6"
            : "#795f58";
        context.fillRect(x, y, radius, radius);
      }
      context.globalAlpha = 1;
    }

    function drawTile(tile) {
      const point = gridToScreen(tile.x, tile.y);
      const halfWidth = TILE_WIDTH / 2;
      const halfHeight = TILE_HEIGHT / 2;
      const depth = state.scene === SCENES.CAMP ? 12 : 17;
      const top = { x: point.x, y: point.y - halfHeight };
      const right = { x: point.x + halfWidth, y: point.y };
      const bottom = { x: point.x, y: point.y + halfHeight };
      const left = { x: point.x - halfWidth, y: point.y };
      const isCamp = state.scene === SCENES.CAMP;
      context.fillStyle = isCamp ? palette.campSideLeft : palette.dungeonSideLeft;
      context.beginPath();
      context.moveTo(left.x, left.y);
      context.lineTo(bottom.x, bottom.y);
      context.lineTo(bottom.x, bottom.y + depth);
      context.lineTo(left.x, left.y + depth);
      context.closePath();
      context.fill();
      context.fillStyle = isCamp ? palette.campSideRight : palette.dungeonSideRight;
      context.beginPath();
      context.moveTo(bottom.x, bottom.y);
      context.lineTo(right.x, right.y);
      context.lineTo(right.x, right.y + depth);
      context.lineTo(bottom.x, bottom.y + depth);
      context.closePath();
      context.fill();
      context.fillStyle = tileTopColor(tile);
      context.strokeStyle = palette.tileEdge;
      context.lineWidth = 1;
      context.beginPath();
      context.moveTo(top.x, top.y);
      context.lineTo(right.x, right.y);
      context.lineTo(bottom.x, bottom.y);
      context.lineTo(left.x, left.y);
      context.closePath();
      context.fill();
      context.stroke();
      drawFloorDetail(tile, point);
      if (!isCamp) drawDungeonBoundaryEdges(tile, { top, right, bottom, left });
      if (tile.type === "grass" && (tile.x * 5 + tile.y * 3) % 11 === 0) {
        drawGrassTuft(point.x + 5, point.y - 3, tile.variant);
      }
      if (tile.type === "stone" && (tile.x * 3 + tile.y * 5) % 8 === 0) {
        drawStoneCrack(point.x, point.y, tile.variant);
      }
    }

    function tileExists(x, y) {
      return Boolean(activeScene().map.tiles?.[y]?.[x]?.exists);
    }

    function drawFloorDetail(tile, point) {
      const stableSeed = tile.x * 17 + tile.y * 29 + tile.variant * 11;
      context.save();
      context.lineWidth = 1;
      if (tile.type === "training" && stableSeed % 5 === 0) {
        context.strokeStyle = "rgba(66, 50, 39, 0.34)";
        context.beginPath();
        context.moveTo(point.x - 12, point.y - 2);
        context.lineTo(point.x - 3, point.y + 3);
        context.moveTo(point.x + 4, point.y - 4);
        context.lineTo(point.x + 12, point.y);
        context.stroke();
      }
      if (tile.type === "arsenal") {
        context.strokeStyle = "rgba(31, 35, 42, 0.35)";
        context.beginPath();
        if (stableSeed % 3 === 0) {
          context.moveTo(point.x - 16, point.y - 1);
          context.lineTo(point.x, point.y + 7);
        } else {
          context.moveTo(point.x + 2, point.y - 7);
          context.lineTo(point.x + 17, point.y);
        }
        context.stroke();
        if (stableSeed % 7 === 0) {
          context.fillStyle = "rgba(173, 156, 124, 0.42)";
          context.fillRect(point.x - 3, point.y - 1, 2, 2);
          context.fillRect(point.x + 6, point.y + 2, 2, 2);
        }
      }
      if (tile.type === "library" && stableSeed % 4 === 0) {
        context.strokeStyle = "rgba(177, 153, 126, 0.25)";
        context.beginPath();
        context.moveTo(point.x - 11, point.y + 1);
        context.lineTo(point.x - 2, point.y + 5);
        context.moveTo(point.x + 3, point.y - 4);
        context.lineTo(point.x + 11, point.y);
        context.stroke();
      }
      if (tile.type === "stairs") {
        context.strokeStyle = "rgba(33, 30, 39, 0.48)";
        context.beginPath();
        context.moveTo(point.x - 18, point.y);
        context.lineTo(point.x, point.y + 8);
        context.moveTo(point.x, point.y - 8);
        context.lineTo(point.x + 18, point.y);
        context.stroke();
      }
      if (
        tile.zone === "keeper_hall" ||
        tile.zone === "east_round_hall" ||
        tile.zone === "north_round_sanctum"
      ) {
        const accent =
          tile.zone === "north_round_sanctum"
            ? "rgba(101, 52, 102, 0.28)"
            : tile.zone === "east_round_hall"
              ? "rgba(143, 70, 45, 0.22)"
              : "rgba(102, 89, 73, 0.22)";
        if (stableSeed % 9 === 0) {
          context.strokeStyle = accent;
          context.beginPath();
          context.ellipse(point.x, point.y, 12, 5, 0, 0, Math.PI * 2);
          context.stroke();
        }
      }
      context.restore();
    }

    function drawDungeonBoundaryEdges(tile, corners) {
      const exposedEdges = [
        !tileExists(tile.x, tile.y - 1) && [corners.top, corners.right],
        !tileExists(tile.x + 1, tile.y) && [corners.right, corners.bottom],
        !tileExists(tile.x, tile.y + 1) && [corners.bottom, corners.left],
        !tileExists(tile.x - 1, tile.y) && [corners.left, corners.top],
      ].filter(Boolean);
      if (exposedEdges.length === 0) return;
      context.save();
      context.strokeStyle = "rgba(139, 128, 134, 0.72)";
      context.lineWidth = 2;
      exposedEdges.forEach(([start, end], index) => {
        const damaged = (tile.x * 13 + tile.y * 7 + index) % 5 === 0;
        context.beginPath();
        context.moveTo(start.x, start.y - 1);
        if (damaged) {
          const midX = (start.x + end.x) / 2;
          const midY = (start.y + end.y) / 2;
          context.lineTo(midX - 2, midY + 2);
          context.lineTo(midX + 3, midY - 1);
        }
        context.lineTo(end.x, end.y - 1);
        context.stroke();
      });
      context.restore();
    }

    function tileTopColor(tile) {
      if (tile.type === "path") return tile.variant === 0 ? palette.pathA : palette.pathB;
      if (tile.type === "stone") return tile.variant <= 1 ? palette.stoneA : palette.stoneB;
      if (tile.type === "training") {
        return tile.variant <= 1 ? palette.trainingA : palette.trainingB;
      }
      if (tile.type === "arsenal") {
        return tile.variant <= 1 ? palette.arsenalA : palette.arsenalB;
      }
      if (tile.type === "library") {
        return tile.variant <= 1 ? palette.libraryA : palette.libraryB;
      }
      if (tile.type === "stairs") {
        return tile.variant <= 1 ? palette.stairsA : palette.stairsB;
      }
      return tile.variant === 0 ? palette.grassA : palette.grassB;
    }

    function drawGrassTuft(x, y, variant) {
      context.strokeStyle = variant === 0 ? "#bad777" : "#4b7d3d";
      context.lineWidth = 2;
      context.beginPath();
      context.moveTo(x, y);
      context.lineTo(x - 2, y - 5);
      context.moveTo(x, y);
      context.lineTo(x + 2, y - 6);
      context.moveTo(x, y);
      context.lineTo(x + 5, y - 3);
      context.stroke();
    }

    function drawStoneCrack(x, y, variant) {
      context.strokeStyle = palette.stoneCrack;
      context.lineWidth = 1;
      context.beginPath();
      context.moveTo(x - 8, y - 1);
      context.lineTo(x - 2, y + 2 + variant);
      context.lineTo(x + 3, y - 1);
      context.lineTo(x + 8, y + 1);
      context.stroke();
    }

    function drawTargetMarker() {
      const member = party.members[0];
      if (!member.target) return;
      const point = gridToScreen(member.target.x, member.target.y);
      const pulse = 0.64 + Math.sin(state.elapsedTime * 4) * 0.16;
      context.save();
      context.globalAlpha = pulse;
      context.strokeStyle = palette.target;
      context.lineWidth = 2;
      context.beginPath();
      context.ellipse(point.x, point.y - 1, 15, 7, 0, 0, Math.PI * 2);
      context.stroke();
      context.restore();
    }

    function drawProp(prop) {
      const point = gridToScreen(prop.x, prop.y);
      const drawers = {
        tree: drawTree,
        rock: drawRock,
        stump: drawStump,
        tent: drawTent,
        campfire: drawCampfire,
        stoneWall: drawStoneWall,
        stoneDoorway: drawStoneDoorway,
        pillar: drawPillar,
        brazier: drawBrazier,
        stairs: drawStairs,
        trainingDummy: drawTrainingDummy,
        weaponRack: drawWeaponRack,
        bookshelf: drawBookshelf,
        grassPatch: drawGrassPatch,
        pathWear: drawPathWear,
        pebble: drawPebble,
        supplyPile: drawSupplyPile,
        ruinedPillar: drawRuinedPillar,
        rubble: drawRubble,
        oldSign: drawOldSign,
        doorFrame: drawDoorFrame,
        crateStack: drawCrateStack,
        storageShelf: drawStorageShelf,
        forgeBase: drawForgeBase,
        weaponPile: drawWeaponPile,
        readingDesk: drawReadingDesk,
        loosePages: drawLoosePages,
        candleStand: drawCandleStand,
        obsidianPedestal: drawObsidianPedestal,
        arcaneMark: drawArcaneMark,
        brokenRing: drawBrokenRing,
      };
      drawers[prop.type]?.(point.x, point.y, prop.scale || 1, prop);
    }

    function drawTree(x, y, scale) {
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      drawGroundShadow(0, 1, 21, 8);
      context.fillStyle = "#6f4930";
      context.fillRect(-5, -31, 10, 32);
      context.fillStyle = "#9a6841";
      context.fillRect(-4, -30, 3, 27);
      [
        [-16, -48, 28, 24, "#315b3d"],
        [2, -48, 24, 26, "#3e7047"],
        [-8, -67, 29, 28, "#4c8050"],
        [-2, -75, 17, 18, "#609158"],
      ].forEach(([bx, by, width, height, color]) => {
        context.fillStyle = color;
        context.fillRect(bx, by, width, height);
      });
      context.fillStyle = "rgba(216, 239, 156, 0.42)";
      context.fillRect(-2, -69, 9, 6);
      context.fillRect(-11, -57, 8, 5);
      context.restore();
    }

    function drawRock(x, y, scale) {
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      drawGroundShadow(0, 2, 18, 7);
      context.fillStyle = "#536963";
      context.beginPath();
      context.moveTo(-15, -3);
      context.lineTo(-10, -18);
      context.lineTo(3, -24);
      context.lineTo(16, -12);
      context.lineTo(12, 0);
      context.lineTo(0, 5);
      context.closePath();
      context.fill();
      context.fillStyle = "#82918a";
      context.beginPath();
      context.moveTo(-10, -18);
      context.lineTo(3, -24);
      context.lineTo(9, -17);
      context.lineTo(-3, -11);
      context.closePath();
      context.fill();
      context.restore();
    }

    function drawStump(x, y, scale) {
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      drawGroundShadow(0, 2, 13, 5);
      context.fillStyle = "#6e492f";
      context.fillRect(-9, -12, 18, 13);
      context.fillStyle = "#b3834f";
      context.beginPath();
      context.ellipse(0, -12, 10, 5, 0, 0, Math.PI * 2);
      context.fill();
      context.restore();
    }

    function drawTent(x, y, scale) {
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      drawGroundShadow(0, 4, 28, 10);
      context.fillStyle = "#7c4c35";
      context.beginPath();
      context.moveTo(-28, 0);
      context.lineTo(0, -47);
      context.lineTo(29, 0);
      context.closePath();
      context.fill();
      context.fillStyle = "#b66f43";
      context.beginPath();
      context.moveTo(-28, 0);
      context.lineTo(0, -47);
      context.lineTo(-2, 0);
      context.closePath();
      context.fill();
      context.fillStyle = "#31251f";
      context.beginPath();
      context.moveTo(-7, 0);
      context.lineTo(0, -21);
      context.lineTo(8, 0);
      context.closePath();
      context.fill();
      context.restore();
    }

    function drawCampfire(x, y, scale) {
      const flicker = Math.sin(state.elapsedTime * 12) * 2;
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      drawGroundShadow(0, 3, 18, 7);
      context.fillStyle = "#5c3b2b";
      context.fillRect(-14, -3, 28, 5);
      context.fillRect(-3, -9, 6, 19);
      context.fillStyle = "#e56a35";
      context.beginPath();
      context.moveTo(-10, -7);
      context.lineTo(-2, -31 - flicker);
      context.lineTo(4, -20);
      context.lineTo(10, -6);
      context.closePath();
      context.fill();
      context.fillStyle = "#ffd66b";
      context.fillRect(-2, -23 + flicker * 0.4, 5, 16);
      context.restore();
    }

    function drawStoneWall(x, y, scale, prop) {
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      context.fillStyle = "rgba(10, 9, 13, 0.34)";
      context.fillRect(-23, -2, 46, 7);
      context.fillStyle = "#35343b";
      context.fillRect(-22, -64, 44, 65);
      context.fillStyle = "#595860";
      context.fillRect(-19, -61, 38, 57);
      context.fillStyle = "#77757d";
      context.fillRect(-19, -61, 38, 7);
      context.fillRect(-19, -34, 38, 5);
      context.fillStyle = "#44434b";
      context.fillRect(-2, -54, 4, 20);
      const seamOffset = prop.variant % 2 === 0 ? -11 : 8;
      context.fillRect(seamOffset, -28, 4, 24);
      context.fillStyle = "#85828a";
      context.fillRect(-17, -51, 13, 4);
      context.fillRect(5, -23, 12, 4);
      context.fillStyle = "#2a2930";
      context.fillRect(-22, -4, 44, 5);
      context.restore();
    }

    function drawStoneDoorway(x, y, scale) {
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      context.fillStyle = "rgba(10, 9, 13, 0.36)";
      context.fillRect(-27, -2, 54, 7);
      context.fillStyle = "#1b1a20";
      context.fillRect(-15, -53, 30, 54);
      context.fillStyle = "#3a3941";
      context.fillRect(-27, -63, 12, 64);
      context.fillRect(15, -63, 12, 64);
      context.fillRect(-27, -76, 54, 15);
      context.fillStyle = "#67656d";
      context.fillRect(-23, -59, 8, 55);
      context.fillRect(15, -59, 8, 55);
      context.fillRect(-23, -72, 46, 8);
      context.fillStyle = "#85828a";
      context.fillRect(-21, -68, 13, 4);
      context.fillRect(8, -68, 13, 4);
      context.fillStyle = "#09090d";
      context.fillRect(-11, -48, 22, 49);
      context.fillStyle = "#302e35";
      context.fillRect(-15, -4, 30, 5);
      context.restore();
    }

    function drawPillar(x, y, scale) {
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      drawGroundShadow(0, 2, 16, 6);
      context.fillStyle = "#47454e";
      context.fillRect(-12, -48, 24, 49);
      context.fillStyle = "#6a6870";
      context.fillRect(-8, -45, 7, 42);
      context.fillStyle = "#7b7880";
      context.fillRect(-16, -53, 32, 9);
      context.restore();
    }

    function drawBrazier(x, y, scale) {
      const flicker = Math.sin(state.elapsedTime * 13 + x) * 2;
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      drawGroundShadow(0, 2, 13, 5);
      context.fillStyle = "#40343a";
      context.fillRect(-3, -19, 6, 20);
      context.fillRect(-11, -22, 22, 6);
      context.fillStyle = "#b64d3f";
      context.fillRect(-8, -40 - flicker, 16, 19 + flicker);
      context.fillStyle = "#f1b254";
      context.fillRect(-2, -34 - flicker * 0.35, 5, 13);
      context.restore();
    }

    function drawStairs(x, y, scale) {
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      for (let step = 0; step < 5; step += 1) {
        context.fillStyle = step % 2 === 0 ? "#87818b" : "#716c76";
        context.fillRect(-22 + step * 3, -4 - step * 4, 44 - step * 6, 5);
      }
      context.restore();
    }

    function drawTrainingDummy(x, y, scale) {
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      drawGroundShadow(0, 2, 14, 5);
      context.fillStyle = "#4b3529";
      context.fillRect(-3, -35, 6, 36);
      context.fillRect(-15, -28, 30, 5);
      context.fillStyle = "#8b5b42";
      context.fillRect(-10, -48, 20, 18);
      context.fillStyle = "#c09962";
      context.fillRect(-6, -44, 5, 5);
      context.restore();
    }

    function drawWeaponRack(x, y, scale) {
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      drawGroundShadow(0, 2, 17, 5);
      context.fillStyle = "#4d3629";
      context.fillRect(-18, -31, 5, 32);
      context.fillRect(13, -31, 5, 32);
      context.fillRect(-18, -27, 36, 5);
      context.fillStyle = "#a9a7aa";
      context.fillRect(-9, -44, 3, 35);
      context.fillRect(6, -41, 3, 32);
      context.fillStyle = "#6f4a32";
      context.fillRect(-13, -12, 11, 3);
      context.fillRect(2, -12, 11, 3);
      context.restore();
    }

    function drawBookshelf(x, y, scale) {
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      drawGroundShadow(0, 2, 19, 6);
      context.fillStyle = "#46352f";
      context.fillRect(-20, -82, 40, 83);
      context.fillStyle = "#6f5545";
      context.fillRect(-16, -75, 32, 5);
      context.fillRect(-16, -52, 32, 4);
      context.fillRect(-16, -28, 32, 4);
      ["#8d5e52", "#586c75", "#8b7650", "#65577c"].forEach((color, index) => {
        context.fillStyle = color;
        context.fillRect(-14 + index * 7, -69, 5, 15);
        context.fillRect(-11 + index * 7, -47, 5, 17);
        context.fillRect(-14 + index * 7, -23, 5, 17);
      });
      context.restore();
    }

    function drawGrassPatch(x, y, scale, prop) {
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      const shift = prop.variant || 0;
      context.strokeStyle = shift % 2 === 0 ? "#4d7c3d" : "#6a984e";
      context.lineWidth = 2;
      [-9, 0, 8].forEach((offset, index) => {
        context.beginPath();
        context.moveTo(offset, 1);
        context.lineTo(offset - 3, -8 - ((shift + index) % 4));
        context.moveTo(offset, 1);
        context.lineTo(offset + 3, -12 + ((shift + index) % 3));
        context.stroke();
      });
      context.restore();
    }

    function drawPathWear(x, y, scale, prop) {
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      context.globalAlpha = 0.3;
      context.strokeStyle = "#6f5b3c";
      context.lineWidth = 2;
      context.beginPath();
      const shift = (prop.variant || 0) * 2;
      context.moveTo(-16 + shift, -3);
      context.lineTo(-3 + shift, 2);
      context.moveTo(2 - shift, -1);
      context.lineTo(16 - shift, 4);
      context.stroke();
      context.restore();
    }

    function drawPebble(x, y, scale, prop) {
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      drawGroundShadow(0, 1, 7, 3);
      context.fillStyle = prop.variant % 2 === 0 ? "#788078" : "#626b66";
      context.beginPath();
      context.moveTo(-7, 0);
      context.lineTo(-3, -7);
      context.lineTo(4, -8);
      context.lineTo(8, -2);
      context.lineTo(4, 1);
      context.closePath();
      context.fill();
      context.restore();
    }

    function drawSupplyPile(x, y, scale) {
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      drawGroundShadow(0, 3, 20, 7);
      context.fillStyle = "#79583c";
      context.fillRect(-20, -24, 24, 25);
      context.fillStyle = "#a27a4d";
      context.fillRect(-16, -21, 16, 3);
      context.fillRect(-16, -10, 16, 3);
      context.fillStyle = "#6d7457";
      context.beginPath();
      context.ellipse(11, -10, 10, 13, -0.25, 0, Math.PI * 2);
      context.fill();
      context.restore();
    }

    function drawRuinedPillar(x, y, scale) {
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      drawGroundShadow(0, 3, 19, 7);
      context.fillStyle = "#4d4d55";
      context.fillRect(-14, -73, 28, 74);
      context.fillStyle = "#74737a";
      context.fillRect(-9, -70, 7, 66);
      context.fillStyle = "#85828a";
      context.beginPath();
      context.moveTo(-18, -73);
      context.lineTo(-9, -86);
      context.lineTo(1, -77);
      context.lineTo(9, -84);
      context.lineTo(18, -72);
      context.closePath();
      context.fill();
      context.fillStyle = "#3c3b43";
      context.fillRect(-19, -8, 38, 9);
      context.restore();
    }

    function drawRubble(x, y, scale, prop) {
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      drawGroundShadow(0, 3, 19, 6);
      const colors = ["#575860", "#6e6c73", "#474850"];
      [
        [-14, -11, 10, 10],
        [-3, -20, 13, 18],
        [8, -12, 12, 11],
        [-18, -6, 8, 7],
      ].forEach(([left, top, width, height], index) => {
        context.fillStyle = colors[(index + (prop.variant || 0)) % colors.length];
        context.fillRect(left, top, width, height);
      });
      context.restore();
    }

    function drawOldSign(x, y, scale) {
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      drawGroundShadow(0, 2, 12, 4);
      context.fillStyle = "#49382c";
      context.fillRect(-3, -55, 6, 56);
      context.fillStyle = "#725238";
      context.beginPath();
      context.moveTo(-18, -56);
      context.lineTo(12, -56);
      context.lineTo(19, -48);
      context.lineTo(11, -39);
      context.lineTo(-18, -39);
      context.closePath();
      context.fill();
      context.fillStyle = "#a17a4f";
      context.fillRect(-12, -51, 20, 3);
      context.restore();
    }

    function drawDoorFrame(x, y, scale) {
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      drawGroundShadow(0, 3, 29, 8);
      context.fillStyle = "#494951";
      context.fillRect(-29, -79, 10, 80);
      context.fillRect(19, -79, 10, 80);
      context.fillRect(-29, -92, 58, 14);
      context.fillStyle = "#77757d";
      context.fillRect(-25, -75, 4, 70);
      context.fillRect(21, -75, 4, 70);
      context.fillRect(-23, -88, 46, 4);
      context.restore();
    }

    function drawCrateStack(x, y, scale, prop) {
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      drawGroundShadow(0, 3, 22, 7);
      const shifted = (prop.variant || 0) % 2 === 0;
      context.fillStyle = "#624b37";
      context.fillRect(-20, -22, 22, 23);
      context.fillStyle = "#8b6845";
      context.fillRect(-16, -18, 14, 3);
      context.fillRect(-16, -7, 14, 3);
      context.fillStyle = "#594331";
      context.fillRect(shifted ? 0 : -3, -42, 22, 22);
      context.fillStyle = "#99734d";
      context.fillRect(shifted ? 4 : 1, -38, 14, 3);
      context.restore();
    }

    function drawStorageShelf(x, y, scale, prop) {
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      drawGroundShadow(0, 3, 21, 7);
      context.fillStyle = "#373b42";
      context.fillRect(-20, -82, 40, 83);
      context.fillStyle = "#62666b";
      [-75, -51, -27].forEach((top) => context.fillRect(-17, top, 34, 5));
      const colors = ["#8a5f44", "#6d7075", "#9b784f"];
      [0, 1, 2].forEach((row) => {
        context.fillStyle = colors[(row + (prop.variant || 0)) % colors.length];
        context.fillRect(-14, -69 + row * 24, 12, 13);
        context.fillRect(3, -69 + row * 24, 11, 13);
      });
      context.restore();
    }

    function drawForgeBase(x, y, scale) {
      const flicker = 0.45 + Math.sin(state.elapsedTime * 8 + x) * 0.12;
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      drawGroundShadow(0, 3, 24, 8);
      context.fillStyle = "#353940";
      context.fillRect(-24, -35, 48, 36);
      context.fillStyle = "#62646a";
      context.fillRect(-19, -31, 38, 6);
      context.globalAlpha = flicker;
      context.fillStyle = "#d65e35";
      context.fillRect(-13, -20, 26, 14);
      context.fillStyle = "#f0a44e";
      context.fillRect(-7, -18, 14, 9);
      context.globalAlpha = 1;
      context.fillStyle = "#292d34";
      context.fillRect(-25, -48, 10, 19);
      context.fillRect(15, -48, 10, 19);
      context.restore();
    }

    function drawWeaponPile(x, y, scale) {
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      drawGroundShadow(0, 2, 19, 6);
      context.strokeStyle = "#b2afb0";
      context.lineWidth = 3;
      context.beginPath();
      context.moveTo(-16, -4);
      context.lineTo(9, -28);
      context.moveTo(15, -3);
      context.lineTo(-7, -30);
      context.moveTo(-4, -2);
      context.lineTo(18, -24);
      context.stroke();
      context.fillStyle = "#705039";
      context.fillRect(-18, -5, 36, 6);
      context.restore();
    }

    function drawReadingDesk(x, y, scale) {
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      drawGroundShadow(0, 3, 23, 7);
      context.fillStyle = "#49372f";
      context.fillRect(-22, -32, 44, 15);
      context.fillRect(-18, -18, 5, 19);
      context.fillRect(13, -18, 5, 19);
      context.fillStyle = "#b8a77f";
      context.fillRect(-12, -36, 24, 10);
      context.strokeStyle = "#705a48";
      context.beginPath();
      context.moveTo(0, -35);
      context.lineTo(0, -27);
      context.stroke();
      context.restore();
    }

    function drawLoosePages(x, y, scale, prop) {
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      context.fillStyle = "rgba(198, 184, 144, 0.76)";
      const shift = (prop.variant || 0) * 2;
      context.fillRect(-15 + shift, -3, 12, 6);
      context.fillRect(2 - shift, 1, 13, 6);
      context.strokeStyle = "rgba(84, 67, 55, 0.6)";
      context.beginPath();
      context.moveTo(-12 + shift, -1);
      context.lineTo(-5 + shift, 1);
      context.moveTo(5 - shift, 3);
      context.lineTo(12 - shift, 5);
      context.stroke();
      context.restore();
    }

    function drawCandleStand(x, y, scale) {
      const flicker = Math.sin(state.elapsedTime * 11 + x * 0.2) * 2;
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      drawGroundShadow(0, 2, 9, 3);
      context.fillStyle = "#45414c";
      context.fillRect(-2, -37, 4, 38);
      context.fillRect(-8, -5, 16, 4);
      context.fillStyle = "#d8caa4";
      context.fillRect(-3, -44, 6, 9);
      context.fillStyle = "#e69a4a";
      context.beginPath();
      context.moveTo(-4, -44);
      context.lineTo(0, -53 - flicker);
      context.lineTo(4, -44);
      context.closePath();
      context.fill();
      context.restore();
    }

    function drawObsidianPedestal(x, y, scale) {
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      drawGroundShadow(0, 3, 20, 7);
      context.fillStyle = "#292534";
      context.beginPath();
      context.moveTo(-20, 0);
      context.lineTo(-14, -13);
      context.lineTo(-10, -42);
      context.lineTo(10, -48);
      context.lineTo(14, -12);
      context.lineTo(20, 0);
      context.closePath();
      context.fill();
      context.fillStyle = "#5f405f";
      context.fillRect(-8, -42, 5, 33);
      context.fillStyle = "#7e4f69";
      context.fillRect(-13, -48, 26, 6);
      context.restore();
    }

    function drawArcaneMark(x, y, scale) {
      const pulse = 0.26 + Math.sin(state.elapsedTime * 3) * 0.08;
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      context.globalAlpha = pulse;
      context.strokeStyle = "#9d567e";
      context.lineWidth = 2;
      context.beginPath();
      context.ellipse(0, 0, 21, 8, 0, 0, Math.PI * 2);
      context.moveTo(-15, -5);
      context.lineTo(15, 5);
      context.moveTo(15, -5);
      context.lineTo(-15, 5);
      context.stroke();
      context.restore();
    }

    function drawBrokenRing(x, y, scale) {
      context.save();
      context.translate(Math.round(x), Math.round(y));
      context.scale(scale, scale);
      context.strokeStyle = "rgba(53, 30, 49, 0.72)";
      context.lineWidth = 3;
      context.beginPath();
      context.ellipse(0, 0, 21, 8, 0, 0.25, 2.6);
      context.moveTo(-17, 5);
      context.ellipse(0, 0, 21, 8, 0, 3.25, 5.75);
      context.stroke();
      context.restore();
    }

    function getRaelynRenderState(member) {
      let renderState = raelynMemberStates.get(member);
      if (!renderState) {
        renderState = {
          lastAlive: member.alive,
          lastAttackPulse: 0,
          lastAttackTimer: member.attackTimer,
          attackStartedAt: null,
          deathStartedAt: member.alive ? null : characterAnimationTime,
        };
        raelynMemberStates.set(member, renderState);
      }
      return renderState;
    }

    function selectRaelynFrame(member, facingRight) {
      const renderState = getRaelynRenderState(member);
      if (member.alive && !renderState.lastAlive) {
        renderState.deathStartedAt = null;
        renderState.attackStartedAt = null;
      } else if (!member.alive && renderState.lastAlive) {
        renderState.deathStartedAt = characterAnimationTime;
        renderState.attackStartedAt = null;
      }

      const attackTimerJumped =
        member.attackTimer > renderState.lastAttackTimer + 0.25;
      const attackTriggered =
        member.alive &&
        member.attackPulse > 0 &&
        (member.attackPulse >= 0.16 || attackTimerJumped) &&
        (member.attackPulse > renderState.lastAttackPulse || attackTimerJumped);
      if (attackTriggered && renderState.attackStartedAt === null) {
        renderState.attackStartedAt = characterAnimationTime;
      }

      let action = "idle";
      let actionElapsed = characterAnimationTime;
      if (!member.alive) {
        action = "death";
        if (renderState.deathStartedAt === null) {
          renderState.deathStartedAt = characterAnimationTime;
        }
        actionElapsed = characterAnimationTime - renderState.deathStartedAt;
      } else if (renderState.attackStartedAt !== null) {
        const attackElapsed =
          characterAnimationTime - renderState.attackStartedAt;
        const attackDefinition = raelynActions.melee_attack;
        const attackDuration =
          attackDefinition.frameCount / attackDefinition.frameRate;
        if (attackElapsed < attackDuration) {
          action = "melee_attack";
          actionElapsed = attackElapsed;
        } else {
          renderState.attackStartedAt = null;
          action = member.moving ? "walk" : "idle";
        }
      } else if (member.moving) {
        action = "walk";
      }

      const definition = raelynActions[action];
      const rawFrameIndex = Math.floor(actionElapsed * definition.frameRate);
      const frameIndex = definition.looping
        ? rawFrameIndex % definition.frameCount
        : Math.min(rawFrameIndex, definition.frameCount - 1);
      const direction = facingRight ? "right" : "left";

      renderState.lastAlive = member.alive;
      renderState.lastAttackPulse = member.attackPulse;
      renderState.lastAttackTimer = member.attackTimer;
      return raelynFrames[action][direction][frameIndex];
    }

    function drawRaelynWarrior(member, point, facingRight) {
      const frame = selectRaelynFrame(member, facingRight);
      if (
        !frame ||
        frame.failed ||
        !frame.image.complete ||
        frame.image.naturalWidth !== RAELYN_FRAME_WIDTH ||
        frame.image.naturalHeight !== RAELYN_FRAME_HEIGHT
      ) {
        return false;
      }

      context.save();
      context.translate(Math.round(point.x), Math.round(point.y));
      context.filter = member.hitFlash > 0 ? "brightness(1.75) saturate(0.35)" : "none";
      context.drawImage(
        frame.image,
        -RAELYN_ANCHOR_X * RAELYN_SCALE,
        -RAELYN_ANCHOR_Y * RAELYN_SCALE,
        RAELYN_FRAME_WIDTH * RAELYN_SCALE,
        RAELYN_FRAME_HEIGHT * RAELYN_SCALE,
      );
      context.restore();
      return true;
    }

    function drawFallbackWarrior(member, point, facingRight) {
      const walking = member.moving;
      const visualWalkClock = characterAnimationTime * 9;
      const step = walking ? Math.round(Math.sin(visualWalkClock)) : 0;
      const bob = walking
        ? Math.abs(Math.sin(visualWalkClock)) * 2
        : Math.sin(characterAnimationTime * 2) * 0.5;
      const attackOffset = member.attackPulse > 0 ? 3 : 0;
      context.save();
      context.translate(
        Math.round(point.x + (facingRight ? attackOffset : -attackOffset)),
        Math.round(point.y - bob),
      );
      drawGroundShadow(0, 3 + bob, 14, 5);
      context.globalAlpha = member.alive ? 1 : 0.5;
      context.fillStyle = "#263438";
      context.fillRect(-9, -16 + step, 7, 15);
      context.fillRect(2, -16 - step, 7, 15);
      context.fillStyle = member.hitFlash > 0 ? "#f3d9c0" : "#596f83";
      context.fillRect(-11, -38, 22, 24);
      context.fillStyle = "#efc495";
      context.fillRect(-9, -54, 18, 17);
      context.fillStyle = "#70422d";
      context.fillRect(-10, -59, 20, 8);
      context.fillStyle = "#2b2724";
      context.fillRect(facingRight ? 4 : -6, -49, 2, 2);
      const weapon = member.equipment.weapon;
      context.fillStyle = Game.Inventory.itemColor(weapon);
      context.fillRect(facingRight ? 13 : -15, -39, 3, 25);
      context.fillRect(facingRight ? 10 : -17, -18, 9, 3);
      context.restore();
    }

    function drawWarrior(member) {
      const point = gridToScreen(member.x, member.y);
      const facingRight = member.direction.x - member.direction.y >= 0;
      if (!drawRaelynWarrior(member, point, facingRight)) {
        drawFallbackWarrior(member, point, facingRight);
      }
      if (state.scene === SCENES.DUNGEON) {
        const stats = Game.Inventory.getMemberStats(member);
        drawEntityHealthBar(point.x, point.y - 69, member.currentHp, stats.maxHp, "#78c46e");
      }
    }

    function drawBoss(boss) {
      const point = gridToScreen(boss.x, boss.y);
      const collapsed = !boss.alive;
      const direction = boss.direction || { x: 0, y: 1 };
      const screenDirection = {
        x: Math.sign(direction.x - direction.y),
        y: Math.sign(direction.x + direction.y),
      };
      context.save();
      context.translate(Math.round(point.x), Math.round(point.y + (collapsed ? 12 : 0)));
      context.globalAlpha = collapsed ? 0.66 : 1;
      drawGroundShadow(0, 5, 27, 9);
      context.fillStyle = "#3f3e46";
      context.fillRect(-18, -18, 13, 19);
      context.fillRect(5, -18, 13, 19);
      context.fillStyle = "#66656c";
      context.fillRect(-28, -47, 56, 31);
      context.fillStyle = boss.hitFlash > 0 ? "#e8d5ca" : boss.bodyColor;
      context.fillRect(-20, -65, 40, 24);
      context.fillStyle = boss.highlightColor;
      context.fillRect(-13, -59, 10, 8);
      context.fillStyle = boss.eyeColor;
      context.fillRect(
        screenDirection.x >= 0 ? 8 : -16,
        -51 + screenDirection.y * 3,
        8,
        5,
      );
      context.fillStyle = "rgba(20, 18, 23, 0.68)";
      context.fillRect(
        screenDirection.x >= 0 ? -15 : 9,
        -48 - screenDirection.y * 2,
        6,
        4,
      );
      context.restore();
    }

    function drawEntityHealthBar(x, y, current, max, color) {
      const width = 36;
      const ratio = Math.max(0, Math.min(1, current / max));
      context.fillStyle = "rgba(4, 11, 9, 0.72)";
      context.fillRect(Math.round(x - width / 2), Math.round(y), width, 5);
      context.fillStyle = color;
      context.fillRect(Math.round(x - width / 2 + 1), Math.round(y + 1), (width - 2) * ratio, 3);
    }

    function drawFloatingTexts() {
      context.save();
      context.textAlign = "center";
      context.font = "900 14px ui-monospace, SFMono-Regular, Menlo, monospace";
      state.floatingTexts.forEach((text) => {
        const point = gridToScreen(text.x, text.y);
        context.globalAlpha = Math.min(1, text.life * 1.8);
        context.fillStyle = text.color;
        context.fillText(text.value, point.x, point.y - 64 - text.offsetY);
      });
      context.restore();
    }

    function drawGroundShadow(x, y, radiusX, radiusY) {
      context.save();
      context.globalAlpha = 0.26;
      context.fillStyle = "#050f0b";
      context.beginPath();
      context.ellipse(x, y, radiusX, radiusY, 0, 0, Math.PI * 2);
      context.fill();
      context.restore();
    }

    function drawAmbientParticles() {
      const isCamp = state.scene === SCENES.CAMP;
      context.save();
      context.globalAlpha = isCamp ? 0.38 : 0.2;
      context.fillStyle = isCamp ? "#d6eb9e" : "#b79bd2";
      for (let index = 0; index < 7; index += 1) {
        const travel = (state.elapsedTime * (7 + index) + index * 71) % 470;
        const x = 260 + ((index * 97) % 470);
        const y = 520 - travel * 0.63 + Math.sin(state.elapsedTime + index) * 8;
        context.fillRect(Math.round(x), Math.round(y), 2, 2);
      }
      context.restore();
    }

    return Object.freeze({ render, activeScene, gridToScreen });
  }

  Game.Renderer = Object.freeze({ create });
})(window.CampfireTrials);
