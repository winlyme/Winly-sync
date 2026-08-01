(function (Game) {
  "use strict";

  if (!Game.Core) throw new Error("core.js must load before data.js");

  const palette = Object.freeze({
    campSkyTop: "#14342a",
    campSkyBottom: "#071812",
    dungeonSkyTop: "#201b28",
    dungeonSkyBottom: "#0b0b12",
    grassA: "#7aa75d",
    grassB: "#6d9951",
    pathA: "#bea267",
    pathB: "#ae8e58",
    stoneA: "#65636a",
    stoneB: "#57555e",
    trainingA: "#70685e",
    trainingB: "#625b54",
    arsenalA: "#5e6268",
    arsenalB: "#50545b",
    libraryA: "#625c70",
    libraryB: "#554f63",
    stairsA: "#77727b",
    stairsB: "#66616b",
    stoneCrack: "rgba(25, 22, 30, 0.42)",
    campSideLeft: "#3d6143",
    campSideRight: "#2f5038",
    dungeonSideLeft: "#37363e",
    dungeonSideRight: "#292832",
    tileEdge: "rgba(18, 35, 27, 0.34)",
    target: "#caf180",
  });

  const rarityDefinitions = Object.freeze({
    common: Object.freeze({ label: "普通", multiplier: 1, color: "#e8dfc2" }),
    rare: Object.freeze({ label: "稀有", multiplier: 1.35, color: "#74b9ff" }),
    epic: Object.freeze({ label: "史诗", multiplier: 1.75, color: "#c78cff" }),
  });

  const bossDefinitions = Object.freeze({
    graystone_keeper: Object.freeze({
      name: "灰岩守门者",
      healthMultiplier: 1,
      attackMultiplier: 1,
      bodyColor: "#77767c",
      highlightColor: "#969399",
      eyeColor: "#ad4e3f",
    }),
    furnace_colossus: Object.freeze({
      name: "炉心巨像",
      healthMultiplier: 1.08,
      attackMultiplier: 1.06,
      bodyColor: "#765d54",
      highlightColor: "#a87d64",
      eyeColor: "#f08b46",
    }),
    stonecrown_lord: Object.freeze({
      name: "岩冠领主",
      healthMultiplier: 1.18,
      attackMultiplier: 1.12,
      bodyColor: "#615d78",
      highlightColor: "#8a82a5",
      eyeColor: "#c58cff",
    }),
  });

  const propDefinitions = Object.freeze({
    tree: Object.freeze({ baseHeight: 75 }),
    rock: Object.freeze({ baseHeight: 24 }),
    stump: Object.freeze({ baseHeight: 17 }),
    tent: Object.freeze({ baseHeight: 47 }),
    campfire: Object.freeze({ baseHeight: 31 }),
    stoneWall: Object.freeze({ baseHeight: 64 }),
    stoneDoorway: Object.freeze({ baseHeight: 76 }),
    pillar: Object.freeze({ baseHeight: 53 }),
    brazier: Object.freeze({ baseHeight: 40 }),
    stairs: Object.freeze({ baseHeight: 20 }),
    trainingDummy: Object.freeze({ baseHeight: 48 }),
    weaponRack: Object.freeze({ baseHeight: 44 }),
    bookshelf: Object.freeze({ baseHeight: 82 }),
    grassPatch: Object.freeze({ baseHeight: 13 }),
    pathWear: Object.freeze({ baseHeight: 2 }),
    pebble: Object.freeze({ baseHeight: 8 }),
    supplyPile: Object.freeze({ baseHeight: 34 }),
    ruinedPillar: Object.freeze({ baseHeight: 86 }),
    rubble: Object.freeze({ baseHeight: 24 }),
    oldSign: Object.freeze({ baseHeight: 58 }),
    doorFrame: Object.freeze({ baseHeight: 92 }),
    crateStack: Object.freeze({ baseHeight: 42 }),
    storageShelf: Object.freeze({ baseHeight: 82 }),
    forgeBase: Object.freeze({ baseHeight: 48 }),
    weaponPile: Object.freeze({ baseHeight: 30 }),
    readingDesk: Object.freeze({ baseHeight: 40 }),
    loosePages: Object.freeze({ baseHeight: 2 }),
    candleStand: Object.freeze({ baseHeight: 44 }),
    obsidianPedestal: Object.freeze({ baseHeight: 48 }),
    arcaneMark: Object.freeze({ baseHeight: 2 }),
    brokenRing: Object.freeze({ baseHeight: 3 }),
  });

  function createCampMap(spawn) {
    const width = 40;
    const height = 40;
    const tiles = [];
    for (let y = 0; y < height; y += 1) {
      const row = [];
      for (let x = 0; x < width; x += 1) {
        const isPath =
          (Math.abs(y - spawn.y) <= 1 &&
            x >= spawn.x - 6 &&
            x <= spawn.x + 6) ||
          (x === spawn.x && y >= spawn.y - 4 && y <= spawn.y + 5);
        row.push({
          exists: true,
          type: isPath ? "path" : "grass",
          variant: (x * 7 + y * 11) % 3,
        });
      }
      tiles.push(row);
    }
    return { width, height, tiles };
  }

  function createDungeonMap() {
    const width = 70;
    const height = 88;
    const cells = Array.from({ length: height }, () => Array(width).fill(null));

    const regions = [
      {
        id: "south_entry_loop",
        type: "stone",
        parts: [
          { shape: "circle", centerX: 9, centerY: 82, radius: 3.4 },
          { shape: "rect", x: 9, y: 80, width: 18, height: 4 },
          { shape: "rect", x: 23, y: 76, width: 5, height: 8 },
          { shape: "rect", x: 14, y: 75, width: 14, height: 4 },
        ],
      },
      {
        id: "training_complex",
        type: "training",
        parts: [
          { shape: "rect", x: 22, y: 59, width: 10, height: 21 },
          { shape: "rect", x: 13, y: 63, width: 10, height: 7 },
          { shape: "rect", x: 16, y: 72, width: 6, height: 6 },
          { shape: "rect", x: 31, y: 61, width: 6, height: 5 },
          { shape: "rect", x: 31, y: 67, width: 12, height: 9 },
        ],
      },
      {
        id: "north_zigzag",
        type: "stone",
        parts: [
          { shape: "rect", x: 24, y: 56, width: 4, height: 6 },
          { shape: "rect", x: 24, y: 54, width: 11, height: 4 },
          { shape: "rect", x: 31, y: 52, width: 4, height: 5 },
        ],
      },
      {
        id: "keeper_hall",
        type: "stone",
        parts: [
          { shape: "rect", x: 25, y: 46, width: 13, height: 11 },
          { shape: "rect", x: 36, y: 49, width: 3, height: 5 },
          { shape: "rect", x: 38, y: 48, width: 7, height: 7 },
          { shape: "rect", x: 29, y: 45, width: 7, height: 3 },
        ],
      },
      {
        id: "irregular_arsenal",
        type: "arsenal",
        parts: [
          {
            shape: "polygon",
            points: [
              [30, 31],
              [43, 31],
              [46, 34],
              [42, 37],
              [46, 40],
              [43, 45],
              [37, 45],
              [35, 43],
              [33, 47],
              [29, 45],
              [27, 42],
              [29, 39],
              [26, 36],
              [29, 33],
            ],
          },
          { shape: "rect", x: 25, y: 34, width: 5, height: 4 },
          { shape: "rect", x: 39, y: 40, width: 7, height: 4 },
          { shape: "circle", centerX: 34, centerY: 38, radius: 3.5 },
        ],
      },
      {
        id: "main_cross_hall",
        type: "stone",
        parts: [
          { shape: "rect", x: 28, y: 25, width: 26, height: 5 },
          { shape: "rect", x: 37, y: 23, width: 5, height: 3 },
          { shape: "rect", x: 43, y: 29, width: 5, height: 3 },
          { shape: "rect", x: 50, y: 24, width: 6, height: 7 },
        ],
      },
      {
        id: "east_round_hall",
        type: "arsenal",
        parts: [
          { shape: "rect", x: 52, y: 25, width: 5, height: 5 },
          { shape: "circle", centerX: 58, centerY: 27, radius: 7.2 },
          { shape: "rect", x: 56, y: 20, width: 5, height: 3 },
        ],
      },
      {
        id: "library_gallery",
        type: "library",
        parts: [
          { shape: "rect", x: 27, y: 10, width: 7, height: 18 },
          { shape: "rect", x: 25, y: 13, width: 3, height: 4 },
          { shape: "rect", x: 33, y: 15, width: 3, height: 4 },
          { shape: "rect", x: 25, y: 19, width: 3, height: 4 },
          { shape: "rect", x: 33, y: 22, width: 3, height: 4 },
          { shape: "rect", x: 27, y: 24, width: 12, height: 5 },
        ],
      },
      {
        id: "north_round_sanctum",
        type: "library",
        parts: [
          { shape: "circle", centerX: 30, centerY: 6, radius: 6.5 },
          { shape: "rect", x: 28, y: 9, width: 5, height: 4 },
        ],
      },
      {
        id: "keeper_stair_link",
        type: "stairs",
        parts: [{ shape: "rect", x: 30, y: 42, width: 5, height: 6 }],
      },
      {
        id: "arsenal_internal_stairs",
        type: "stairs",
        parts: [{ shape: "rect", x: 40, y: 28, width: 5, height: 8 }],
      },
    ];

    function paintCell(x, y, type, zone) {
      if (x < 0 || x >= width || y < 0 || y >= height) return;
      cells[y][x] = { type, zone };
    }

    function paintRect(x, y, rectWidth, rectHeight, type, zone) {
      for (let row = y; row < y + rectHeight; row += 1) {
        for (let column = x; column < x + rectWidth; column += 1) {
          paintCell(column, row, type, zone);
        }
      }
    }

    function paintCircle(centerX, centerY, radius, type, zone) {
      for (let y = Math.floor(centerY - radius); y <= Math.ceil(centerY + radius); y += 1) {
        for (let x = Math.floor(centerX - radius); x <= Math.ceil(centerX + radius); x += 1) {
          if (x < 0 || x >= width || y < 0 || y >= height) continue;
          if (Math.hypot(x - centerX, y - centerY) <= radius) {
            paintCell(x, y, type, zone);
          }
        }
      }
    }

    function pointInPolygon(x, y, points) {
      let inside = false;
      for (let index = 0, previous = points.length - 1; index < points.length; previous = index, index += 1) {
        const [currentX, currentY] = points[index];
        const [previousX, previousY] = points[previous];
        const crosses =
          currentY > y !== previousY > y &&
          x < ((previousX - currentX) * (y - currentY)) / (previousY - currentY) + currentX;
        if (crosses) inside = !inside;
      }
      return inside;
    }

    function paintPolygon(points, type, zone) {
      const xValues = points.map((point) => point[0]);
      const yValues = points.map((point) => point[1]);
      const minimumX = Math.floor(Math.min(...xValues));
      const maximumX = Math.ceil(Math.max(...xValues));
      const minimumY = Math.floor(Math.min(...yValues));
      const maximumY = Math.ceil(Math.max(...yValues));
      for (let y = minimumY; y <= maximumY; y += 1) {
        for (let x = minimumX; x <= maximumX; x += 1) {
          if (pointInPolygon(x + 0.5, y + 0.5, points)) paintCell(x, y, type, zone);
        }
      }
    }

    regions.forEach((region) => {
      region.parts.forEach((part) => {
        if (part.shape === "rect") {
          paintRect(part.x, part.y, part.width, part.height, region.type, region.id);
        }
        if (part.shape === "circle") {
          paintCircle(
            part.centerX,
            part.centerY,
            part.radius,
            region.type,
            region.id,
          );
        }
        if (part.shape === "polygon") {
          paintPolygon(part.points, region.type, region.id);
        }
      });
    });

    const tiles = cells.map((row, y) =>
      row.map((cell, x) => ({
        exists: cell !== null,
        type: cell?.type || "void",
        zone: cell?.zone || null,
        variant: (x * 5 + y * 3) % 4,
      })),
    );
    return {
      width,
      height,
      tiles,
      regions: regions.map((region) => ({
        id: region.id,
        type: region.type,
        parts: region.parts.map((part) => ({
          ...part,
          ...(part.points
            ? { points: part.points.map((point) => [...point]) }
            : {}),
        })),
      })),
    };
  }

  function createDungeonProps() {
    const props = [
      { type: "stoneWall", x: 8, y: 85, scale: 1, blocks: true, zone: "south_entry_loop", variant: 0 },
      { type: "stoneDoorway", x: 9, y: 85, scale: 1, blocks: false, zone: "south_entry_loop", variant: 0 },
      { type: "stoneWall", x: 10, y: 85, scale: 1, blocks: true, zone: "south_entry_loop", variant: 1 },
      { type: "ruinedPillar", x: 7, y: 81, scale: 1, blocks: true, zone: "south_entry_loop" },
      { type: "ruinedPillar", x: 11, y: 84, scale: 0.82, blocks: true, zone: "south_entry_loop" },
      { type: "rubble", x: 13, y: 81, scale: 0.92, blocks: true, zone: "south_entry_loop" },
      { type: "oldSign", x: 15, y: 83, scale: 0.95, blocks: true, zone: "south_entry_loop" },
      { type: "doorFrame", x: 24, y: 76, scale: 1, blocks: false, zone: "training_complex" },

      { type: "trainingDummy", x: 23, y: 67, scale: 1.28, blocks: true, zone: "training_complex" },
      { type: "trainingDummy", x: 29, y: 71, scale: 1.32, blocks: true, zone: "training_complex" },
      { type: "trainingDummy", x: 23, y: 75, scale: 1.25, blocks: true, zone: "training_complex" },
      { type: "weaponRack", x: 17, y: 65, scale: 1.28, blocks: true, zone: "training_complex" },
      { type: "supplyPile", x: 20, y: 74, scale: 0.95, blocks: false, zone: "training_complex" },
      { type: "weaponPile", x: 35, y: 72, scale: 1, blocks: false, zone: "training_complex" },
      { type: "doorFrame", x: 26, y: 78, scale: 1, blocks: false, zone: "training_complex" },

      { type: "doorFrame", x: 31, y: 55, scale: 1, blocks: false, zone: "keeper_hall" },
      { type: "doorFrame", x: 32, y: 46, scale: 1, blocks: false, zone: "keeper_hall" },
      { type: "pillar", x: 26, y: 47, scale: 1.52, blocks: true, zone: "keeper_hall" },
      { type: "pillar", x: 36, y: 47, scale: 1.48, blocks: true, zone: "keeper_hall" },
      { type: "brazier", x: 27, y: 48, scale: 1, blocks: true, zone: "keeper_hall" },
      { type: "brazier", x: 36, y: 54, scale: 1, blocks: true, zone: "keeper_hall" },
      { type: "rubble", x: 42, y: 51, scale: 1, blocks: true, zone: "keeper_hall" },
      { type: "stairs", x: 32, y: 43, scale: 1, blocks: false, zone: "keeper_stair_link" },

      { type: "doorFrame", x: 34, y: 43, scale: 1, blocks: false, zone: "irregular_arsenal" },
      { type: "weaponRack", x: 30, y: 35, scale: 1.28, blocks: true, zone: "irregular_arsenal" },
      { type: "weaponRack", x: 41, y: 42, scale: 1.25, blocks: true, zone: "irregular_arsenal" },
      { type: "forgeBase", x: 29, y: 42, scale: 1, blocks: true, zone: "irregular_arsenal" },
      { type: "weaponPile", x: 34, y: 35, scale: 1, blocks: false, zone: "irregular_arsenal" },
      { type: "rubble", x: 27, y: 36, scale: 0.9, blocks: false, zone: "irregular_arsenal" },
      { type: "stairs", x: 42, y: 31, scale: 1, blocks: false, zone: "arsenal_internal_stairs" },

      { type: "doorFrame", x: 40, y: 30, scale: 1, blocks: false, zone: "main_cross_hall" },
      { type: "doorFrame", x: 53, y: 27, scale: 1, blocks: false, zone: "main_cross_hall" },
      { type: "pillar", x: 38, y: 24, scale: 1.46, blocks: true, zone: "main_cross_hall" },
      { type: "pillar", x: 48, y: 29, scale: 1.48, blocks: true, zone: "main_cross_hall" },
      { type: "oldSign", x: 44, y: 29, scale: 0.88, blocks: false, zone: "main_cross_hall" },
      { type: "rubble", x: 51, y: 25, scale: 0.78, blocks: false, zone: "main_cross_hall" },

      { type: "pillar", x: 55, y: 23, scale: 1.48, blocks: true, zone: "east_round_hall" },
      { type: "pillar", x: 61, y: 31, scale: 1.48, blocks: true, zone: "east_round_hall" },
      { type: "pillar", x: 58, y: 21, scale: 1.46, blocks: true, zone: "east_round_hall" },
      { type: "pillar", x: 63, y: 25, scale: 1.48, blocks: true, zone: "east_round_hall" },
      { type: "pillar", x: 63, y: 29, scale: 1.46, blocks: true, zone: "east_round_hall" },
      { type: "pillar", x: 58, y: 33, scale: 1.5, blocks: true, zone: "east_round_hall" },
      { type: "pillar", x: 54, y: 31, scale: 1.46, blocks: true, zone: "east_round_hall" },
      { type: "brazier", x: 61, y: 23, scale: 1.05, blocks: true, zone: "east_round_hall" },
      { type: "brazier", x: 55, y: 31, scale: 1.02, blocks: true, zone: "east_round_hall" },
      { type: "weaponRack", x: 64, y: 27, scale: 1.26, blocks: true, zone: "east_round_hall" },

      { type: "doorFrame", x: 30, y: 24, scale: 1, blocks: false, zone: "library_gallery" },
      { type: "doorFrame", x: 30, y: 10, scale: 1, blocks: false, zone: "library_gallery" },
      { type: "bookshelf", x: 26, y: 15, scale: 1, blocks: true, zone: "library_gallery" },
      { type: "bookshelf", x: 34, y: 17, scale: 1, blocks: true, zone: "library_gallery" },
      { type: "bookshelf", x: 26, y: 21, scale: 1, blocks: true, zone: "library_gallery" },
      { type: "bookshelf", x: 34, y: 24, scale: 1, blocks: true, zone: "library_gallery" },
      { type: "readingDesk", x: 25, y: 16, scale: 1, blocks: true, zone: "library_gallery" },
      { type: "readingDesk", x: 35, y: 23, scale: 1, blocks: true, zone: "library_gallery" },
      { type: "loosePages", x: 31, y: 20, scale: 1, blocks: false, zone: "library_gallery" },
      { type: "loosePages", x: 29, y: 16, scale: 0.9, blocks: false, zone: "library_gallery" },
      { type: "candleStand", x: 27, y: 12, scale: 1, blocks: false, zone: "library_gallery" },
      { type: "candleStand", x: 33, y: 20, scale: 1, blocks: false, zone: "library_gallery" },

      { type: "pillar", x: 26, y: 4, scale: 1.5, blocks: true, zone: "north_round_sanctum" },
      { type: "pillar", x: 34, y: 7, scale: 1.5, blocks: true, zone: "north_round_sanctum" },
      { type: "obsidianPedestal", x: 26, y: 8, scale: 1, blocks: true, zone: "north_round_sanctum" },
      { type: "obsidianPedestal", x: 34, y: 4, scale: 1, blocks: true, zone: "north_round_sanctum" },
      { type: "brazier", x: 30, y: 1, scale: 1.08, blocks: true, zone: "north_round_sanctum" },
      { type: "brazier", x: 25, y: 6, scale: 1, blocks: true, zone: "north_round_sanctum" },
      { type: "brazier", x: 35, y: 6, scale: 1, blocks: true, zone: "north_round_sanctum" },
      { type: "arcaneMark", x: 30, y: 6, scale: 1.35, blocks: false, zone: "north_round_sanctum" },
      { type: "brokenRing", x: 31, y: 6, scale: 1.1, blocks: false, zone: "north_round_sanctum" },
    ];

    const trainingObstacles = [
      [22, 75, "weaponRack"],
      [24, 75, "trainingDummy"],
      [25, 75, "trainingDummy"],
      [26, 75, "weaponRack"],
      [25, 69, "weaponRack"],
      [26, 69, "trainingDummy"],
      [27, 69, "trainingDummy"],
      [28, 69, "weaponRack"],
      [29, 69, "trainingDummy"],
      [30, 69, "trainingDummy"],
      [31, 69, "weaponRack"],
    ].map(([x, y, type], index) => ({
      type,
      x,
      y,
      scale: type === "trainingDummy" ? 1.3 : 1.25,
      blocks: true,
      zone: "training_complex",
      routeObstacleGroup: "training",
      variant: index % 3,
    }));

    const arsenalObstacles = [
      ...Array.from({ length: 12 }, (_, index) => [31 + index, 38]),
      ...Array.from({ length: 6 }, (_, index) => [39 + index, 35]),
    ].map(([x, y], index) => ({
      type: index % 4 === 0 ? "storageShelf" : "crateStack",
      x,
      y,
      scale: index % 4 === 0 ? 1 : 0.95,
      blocks: true,
      zone: "irregular_arsenal",
      routeObstacleGroup: "arsenal",
      variant: index % 4,
    }));

    const libraryObstacles = [
      [30, 23],
      [31, 23],
      [32, 23],
      [28, 18],
      [29, 18],
      [30, 18],
      [30, 13],
      [31, 13],
      [32, 13],
    ].map(([x, y], index) => ({
      type: "bookshelf",
      x,
      y,
      scale: 1,
      blocks: true,
      zone: "library_gallery",
      routeObstacleGroup: "library",
      variant: index % 3,
    }));

    return [...props, ...trainingObstacles, ...arsenalObstacles, ...libraryObstacles];
  }

  function createDungeon(canvasWidth) {
    const roomOrder = ["lower_gate_room", "ember_gallery_room", "deep_sanctum_room"];
    const routeNodes = {
      entrance_route: {
        id: "entrance_route",
        name: "南侧回折入口",
        kind: "route",
        position: { x: 24, y: 81 },
        exits: [{ to: "training_route" }],
      },
      training_route: {
        id: "training_route",
        name: "训练场",
        kind: "route",
        position: { x: 26, y: 64 },
        exits: [{ to: "zigzag_route" }],
      },
      zigzag_route: {
        id: "zigzag_route",
        name: "北侧折线路径",
        kind: "route",
        position: { x: 31, y: 55 },
        exits: [{ to: "lower_gate_room" }],
      },
      lower_gate_room: {
        id: "lower_gate_room",
        name: "北侧守门厅",
        kind: "boss",
        bossId: "graystone_keeper",
        position: { x: 31, y: 51 },
        engagement: {
          bossDirection: { x: 0, y: 1 },
          entryDirection: { x: 0, y: 1 },
          position: { x: 31, y: 52 },
          memberDirection: { x: 0, y: -1 },
        },
        exits: [{ to: "stairs_route" }],
      },
      stairs_route: {
        id: "stairs_route",
        name: "北端楼梯连接",
        kind: "route",
        position: { x: 32, y: 43 },
        exits: [{ to: "arsenal_route" }],
      },
      arsenal_route: {
        id: "arsenal_route",
        name: "步兵武器库",
        kind: "route",
        position: { x: 34, y: 39 },
        exits: [{ to: "arsenal_stairs_route" }],
      },
      arsenal_stairs_route: {
        id: "arsenal_stairs_route",
        name: "武器库内部楼梯",
        kind: "route",
        position: { x: 42, y: 32 },
        exits: [{ to: "main_fork" }],
      },
      main_fork: {
        id: "main_fork",
        name: "主走廊分叉",
        kind: "route",
        position: { x: 42, y: 27 },
        exits: [
          { to: "ember_gallery_room", unlessCleared: ["ember_gallery_room"] },
          { to: "library_turn_route", requiresCleared: ["ember_gallery_room"] },
        ],
      },
      ember_gallery_room: {
        id: "ember_gallery_room",
        name: "圆形武备大厅",
        kind: "boss",
        bossId: "furnace_colossus",
        position: { x: 58, y: 27 },
        engagement: {
          bossDirection: { x: -1, y: 0 },
          entryDirection: { x: -1, y: 0 },
          position: { x: 57, y: 27 },
          memberDirection: { x: 1, y: 0 },
        },
        exits: [{ to: "main_fork" }],
      },
      library_turn_route: {
        id: "library_turn_route",
        name: "西转图书馆",
        kind: "route",
        position: { x: 30, y: 27 },
        exits: [{ to: "library_route" }],
      },
      library_route: {
        id: "library_route",
        name: "图书馆长廊",
        kind: "route",
        position: { x: 30, y: 14 },
        exits: [{ to: "deep_sanctum_room" }],
      },
      deep_sanctum_room: {
        id: "deep_sanctum_room",
        name: "顶部秘法圆厅",
        kind: "boss",
        bossId: "stonecrown_lord",
        position: { x: 30, y: 6 },
        engagement: {
          bossDirection: { x: 0, y: 1 },
          entryDirection: { x: 0, y: 1 },
          position: { x: 30, y: 7 },
          memberDirection: { x: 0, y: -1 },
        },
        final: true,
        exits: [],
      },
    };
    const dungeon = {
      id: "graystone_trial",
      name: "灰岩试炼",
      orientation: Object.freeze({
        north: "-y",
        east: "+x",
        south: "+y",
        west: "-x",
      }),
      origin: { x: canvasWidth / 2, y: 0 },
      map: createDungeonMap(),
      props: createDungeonProps(),
      entry: { x: 9, y: 82 },
      entranceRoomId: "entrance_route",
      roomOrder,
      routeNodes,
    };
    const validation = validateDungeon(dungeon);
    if (!validation.ok) {
      throw new Error(`Invalid dungeon data: ${validation.errors.join("; ")}`);
    }
    return dungeon;
  }

  function createCampOrigin(canvasWidth, canvasHeight, spawn) {
    const halfTileWidth = Game.Core.TILE_WIDTH / 2;
    const halfTileHeight = Game.Core.TILE_HEIGHT / 2;
    const spawnScreen = {
      x: canvasWidth / 2,
      y: canvasHeight / 2 + 10,
    };
    return {
      x: spawnScreen.x - (spawn.x - spawn.y) * halfTileWidth,
      y: spawnScreen.y - (spawn.x + spawn.y) * halfTileHeight,
    };
  }

  function createWorld(canvasWidth, canvasHeight = 620) {
    const campSpawn = { x: 20, y: 20 };
    const camp = {
      id: "campfire_camp",
      name: "篝火营地",
      origin: createCampOrigin(canvasWidth, canvasHeight, campSpawn),
      map: createCampMap(campSpawn),
      spawn: campSpawn,
      activityBounds: {
        minX: 14,
        maxX: 26,
        minY: 14,
        maxY: 26,
      },
      props: [
        { type: "tree", x: 16, y: 16, scale: 1.82, blocks: true, variant: 0 },
        { type: "tree", x: 17, y: 24, scale: 1.68, blocks: true, variant: 1 },
        { type: "tree", x: 24, y: 16, scale: 1.9, blocks: true, variant: 2 },
        { type: "tree", x: 25, y: 24, scale: 1.74, blocks: true, variant: 0 },
        { type: "rock", x: 16, y: 20, scale: 1.08, blocks: true },
        { type: "rock", x: 24, y: 23, scale: 0.95, blocks: true },
        { type: "stump", x: 24, y: 18, scale: 1.12, blocks: true },
        { type: "tent", x: 18, y: 18, scale: 1.72, blocks: true },
        { type: "campfire", x: 22, y: 20, scale: 1.15, blocks: true },
        { type: "grassPatch", x: 15, y: 19, scale: 1, blocks: false, variant: 0 },
        { type: "grassPatch", x: 18, y: 24, scale: 0.9, blocks: false, variant: 1 },
        { type: "grassPatch", x: 24, y: 22, scale: 1.05, blocks: false, variant: 2 },
        { type: "grassPatch", x: 26, y: 17, scale: 0.92, blocks: false, variant: 1 },
        { type: "grassPatch", x: 21, y: 26, scale: 1, blocks: false, variant: 0 },
        { type: "pathWear", x: 18, y: 20, scale: 1, blocks: false, variant: 0 },
        { type: "pathWear", x: 19, y: 20, scale: 1, blocks: false, variant: 1 },
        { type: "pathWear", x: 21, y: 20, scale: 1, blocks: false, variant: 2 },
        { type: "pathWear", x: 23, y: 20, scale: 1, blocks: false, variant: 0 },
        { type: "pebble", x: 15, y: 22, scale: 1, blocks: false, variant: 0 },
        { type: "pebble", x: 21, y: 16, scale: 0.9, blocks: false, variant: 1 },
        { type: "pebble", x: 26, y: 22, scale: 1.1, blocks: false, variant: 2 },
        { type: "supplyPile", x: 17, y: 21, scale: 0.9, blocks: false, variant: 0 },
        { type: "supplyPile", x: 24, y: 25, scale: 0.85, blocks: false, variant: 1 },

        { type: "tree", x: 10, y: 22, scale: 1.9, blocks: true, variant: 1, cluster: "west_grove" },
        { type: "tree", x: 13, y: 23, scale: 1.72, blocks: true, variant: 2, cluster: "west_grove" },
        { type: "rock", x: 12, y: 21, scale: 1.02, blocks: true, variant: 0, cluster: "west_grove" },
        { type: "grassPatch", x: 11, y: 24, scale: 1.08, blocks: false, variant: 2, cluster: "west_grove" },
        { type: "pebble", x: 13, y: 21, scale: 0.92, blocks: false, variant: 1, cluster: "west_grove" },

        { type: "tree", x: 13, y: 12, scale: 1.78, blocks: true, variant: 0, cluster: "north_copse" },
        { type: "tree", x: 16, y: 10, scale: 1.92, blocks: true, variant: 2, cluster: "north_copse" },
        { type: "stump", x: 15, y: 11, scale: 1.08, blocks: true, variant: 1, cluster: "north_copse" },
        { type: "grassPatch", x: 18, y: 11, scale: 0.96, blocks: false, variant: 0, cluster: "north_copse" },
        { type: "pebble", x: 14, y: 12, scale: 1.04, blocks: false, variant: 2, cluster: "north_copse" },

        { type: "tree", x: 28, y: 13, scale: 1.88, blocks: true, variant: 1, cluster: "east_thicket" },
        { type: "tree", x: 28, y: 16, scale: 1.7, blocks: true, variant: 0, cluster: "east_thicket" },
        { type: "rock", x: 27, y: 15, scale: 1.12, blocks: true, variant: 2, cluster: "east_thicket" },
        { type: "grassPatch", x: 29, y: 14, scale: 1.02, blocks: false, variant: 1, cluster: "east_thicket" },
        { type: "pebble", x: 27, y: 17, scale: 0.88, blocks: false, variant: 0, cluster: "east_thicket" },

        { type: "tree", x: 30, y: 24, scale: 1.82, blocks: true, variant: 2, cluster: "southeast_trees" },
        { type: "tree", x: 32, y: 23, scale: 1.68, blocks: true, variant: 0, cluster: "southeast_trees" },
        { type: "stump", x: 29, y: 25, scale: 1.14, blocks: true, variant: 2, cluster: "southeast_trees" },
        { type: "grassPatch", x: 31, y: 25, scale: 0.94, blocks: false, variant: 1, cluster: "southeast_trees" },
        { type: "pebble", x: 29, y: 27, scale: 1.08, blocks: false, variant: 2, cluster: "southeast_trees" },

        { type: "tree", x: 23, y: 29, scale: 1.76, blocks: true, variant: 1, cluster: "south_glade" },
        { type: "tree", x: 20, y: 31, scale: 1.86, blocks: true, variant: 2, cluster: "south_glade" },
        { type: "rock", x: 22, y: 30, scale: 1.06, blocks: true, variant: 1, cluster: "south_glade" },
        { type: "grassPatch", x: 25, y: 30, scale: 1.1, blocks: false, variant: 0, cluster: "south_glade" },
        { type: "pebble", x: 21, y: 29, scale: 0.9, blocks: false, variant: 2, cluster: "south_glade" },

        { type: "tree", x: 13, y: 27, scale: 1.66, blocks: true, variant: 0, cluster: "southwest_scrub" },
        { type: "rock", x: 14, y: 28, scale: 0.98, blocks: true, variant: 2, cluster: "southwest_scrub" },
        { type: "grassPatch", x: 16, y: 29, scale: 1.04, blocks: false, variant: 1, cluster: "southwest_scrub" },
        { type: "pebble", x: 17, y: 28, scale: 1.12, blocks: false, variant: 0, cluster: "southwest_scrub" },
      ],
    };
    const campValidation = validateCamp(camp);
    if (!campValidation.ok) {
      throw new Error(`Invalid camp data: ${campValidation.errors.join("; ")}`);
    }

    return {
      camp,
      dungeon: createDungeon(canvasWidth),
    };
  }

  function getDungeonNode(dungeon, nodeId) {
    if (!dungeon || typeof nodeId !== "string" || nodeId.length === 0) return null;
    const node = dungeon.routeNodes?.[nodeId];
    if (!node || node.id !== nodeId || !["route", "boss"].includes(node.kind)) return null;
    return node;
  }

  function getDungeonRoom(dungeon, roomId) {
    const room = getDungeonNode(dungeon, roomId);
    const roomIndex = Array.isArray(dungeon?.roomOrder)
      ? dungeon.roomOrder.indexOf(roomId)
      : -1;
    if (!room || room.kind !== "boss" || roomIndex < 0) return null;
    return { room, roomIndex };
  }

  function exitMatchesProgress(exit, clearedIds) {
    const required = Array.isArray(exit?.requiresCleared) ? exit.requiresCleared : [];
    const excluded = Array.isArray(exit?.unlessCleared) ? exit.unlessCleared : [];
    return required.every((id) => clearedIds.has(id)) && excluded.every((id) => !clearedIds.has(id));
  }

  function resolveNextNode(dungeon, currentNodeId, clearedEncounterIds) {
    const current = getDungeonNode(dungeon, currentNodeId);
    if (!current) {
      return { type: "error", reason: "当前路线节点无效" };
    }
    if (!Array.isArray(current.exits)) {
      return { type: "error", reason: "路线出口数据无效" };
    }
    if (current.exits.length === 0) {
      return current.kind === "boss" && current.final === true
        ? { type: "complete" }
        : { type: "error", reason: "非最终节点缺少出口" };
    }
    const clearedIds = new Set(
      Array.isArray(clearedEncounterIds) ? clearedEncounterIds : [],
    );
    const activeExits = current.exits.filter((exit) =>
      exitMatchesProgress(exit, clearedIds),
    );
    if (activeExits.length === 0) {
      return { type: "error", reason: "当前进度没有有效出口" };
    }
    if (activeExits.length > 1) {
      return { type: "error", reason: "当前进度存在多个出口" };
    }
    const nextNodeId = activeExits[0]?.to;
    const next = getDungeonNode(dungeon, nextNodeId);
    if (!next) {
      return { type: "error", reason: "路线出口指向无效" };
    }
    return {
      type: "next",
      nodeId: nextNodeId,
    };
  }

  function validateDungeon(dungeon) {
    const errors = [];
    const nodes = dungeon?.routeNodes;
    if (!nodes || !getDungeonNode(dungeon, dungeon.entranceRoomId)) {
      errors.push("入口节点无效");
    }
    const order = Array.isArray(dungeon?.roomOrder) ? dungeon.roomOrder : [];
    if (new Set(order).size !== order.length || order.length !== 3) {
      errors.push("首领展示顺序无效");
    }
    order.forEach((roomId) => {
      const reference = getDungeonRoom(dungeon, roomId);
      if (!reference || !bossDefinitions[reference.room.bossId]) {
        errors.push(`首领节点无效:${roomId}`);
      }
    });
    Object.values(nodes || {}).forEach((node) => {
      const tile = dungeon.map?.tiles?.[node.position?.y]?.[node.position?.x];
      if (!tile?.exists) errors.push(`节点不可行走:${node.id}`);
      const blockedByProp = dungeon.props?.some(
        (prop) =>
          prop.blocks !== false &&
          prop.x === node.position?.x &&
          prop.y === node.position?.y,
      );
      if (blockedByProp) errors.push(`节点被场景物件阻挡:${node.id}`);
      if (node.kind === "boss") {
        const engagement = validateBossEngagement(dungeon, node);
        errors.push(...engagement.errors);
      }
      if (!Array.isArray(node.exits)) errors.push(`节点出口无效:${node.id}`);
      (node.exits || []).forEach((exit) => {
        if (!getDungeonNode(dungeon, exit?.to)) errors.push(`出口目标无效:${node.id}`);
      });
    });
    const protectedPositions = [
      dungeon.entry,
      ...Object.values(nodes || {}).map((node) => node.position),
      ...Object.values(nodes || {})
        .filter((node) => node.kind === "boss")
        .map((node) => node.engagement?.position),
    ];
    const propValidation = validateSceneProps(dungeon, protectedPositions);
    errors.push(...propValidation.errors);
    return { ok: errors.length === 0, errors };
  }

  function validateSceneProps(scene, protectedPositions = []) {
    const errors = [];
    const occupied = new Set();
    const protectedKeys = new Set(
      protectedPositions
        .filter((position) => Number.isInteger(position?.x) && Number.isInteger(position?.y))
        .map((position) => `${position.x},${position.y}`),
    );
    (scene?.props || []).forEach((prop, index) => {
      const key = `${prop?.x},${prop?.y}`;
      const tile = scene?.map?.tiles?.[prop?.y]?.[prop?.x];
      if (!propDefinitions[prop?.type]) errors.push(`场景物件类型无效:${index}`);
      if (!tile?.exists) errors.push(`场景物件不在地形上:${index}`);
      if (!Number.isFinite(prop?.scale) || prop.scale <= 0) {
        errors.push(`场景物件尺寸无效:${index}`);
      }
      if (occupied.has(key)) errors.push(`场景物件重复占位:${key}`);
      occupied.add(key);
      if (prop?.blocks !== false && protectedKeys.has(key)) {
        errors.push(`阻挡物压住保护格:${key}`);
      }
    });
    return { ok: errors.length === 0, errors };
  }

  function validateCamp(camp) {
    const errors = [];
    const spawn = camp?.spawn;
    const bounds = camp?.activityBounds;
    const map = camp?.map;
    if (
      !Number.isInteger(spawn?.x) ||
      !Number.isInteger(spawn?.y) ||
      !map?.tiles?.[spawn.y]?.[spawn.x]?.exists
    ) {
      errors.push("营地出生点无效");
    }
    if (
      !Number.isInteger(bounds?.minX) ||
      !Number.isInteger(bounds?.maxX) ||
      !Number.isInteger(bounds?.minY) ||
      !Number.isInteger(bounds?.maxY) ||
      bounds.minX > bounds.maxX ||
      bounds.minY > bounds.maxY
    ) {
      errors.push("营地活动区无效");
    } else {
      for (let y = bounds.minY; y <= bounds.maxY; y += 1) {
        for (let x = bounds.minX; x <= bounds.maxX; x += 1) {
          if (!map?.tiles?.[y]?.[x]?.exists) {
            errors.push(`营地活动区不在地形上:${x},${y}`);
          }
        }
      }
      if (
        spawn?.x < bounds.minX ||
        spawn?.x > bounds.maxX ||
        spawn?.y < bounds.minY ||
        spawn?.y > bounds.maxY
      ) {
        errors.push("营地出生点不在活动区");
      }
    }
    const propValidation = validateSceneProps(camp, [spawn]);
    errors.push(...propValidation.errors);
    return { ok: errors.length === 0, errors };
  }

  function isCardinalDirection(direction) {
    return (
      Number.isInteger(direction?.x) &&
      Number.isInteger(direction?.y) &&
      Math.abs(direction.x) + Math.abs(direction.y) === 1
    );
  }

  function samePosition(first, second) {
    return first?.x === second?.x && first?.y === second?.y;
  }

  function hasWalkableTile(dungeon, position) {
    const tile = dungeon?.map?.tiles?.[position?.y]?.[position?.x];
    return Boolean(tile?.exists);
  }

  function hasBlockingProp(dungeon, position) {
    return (dungeon?.props || []).some(
      (prop) =>
        prop.blocks !== false &&
        prop.x === position?.x &&
        prop.y === position?.y,
    );
  }

  function validateBossEngagement(dungeon, node) {
    const errors = [];
    if (!node || node.kind !== "boss") return { ok: false, errors: ["首领交战节点无效"] };
    const engagement = node.engagement;
    const label = node.id || "unknown";
    if (!engagement || !hasWalkableTile(dungeon, node.position)) {
      errors.push(`首领交战数据无效:${label}`);
      return { ok: false, errors };
    }
    if (!hasWalkableTile(dungeon, engagement.position)) {
      errors.push(`交战位不可行走:${label}`);
    }
    if (hasBlockingProp(dungeon, node.position)) {
      errors.push(`首领格被场景物件阻挡:${label}`);
    }
    if (hasBlockingProp(dungeon, engagement.position)) {
      errors.push(`交战位被场景物件阻挡:${label}`);
    }
    const distance =
      Math.abs((engagement.position?.x ?? NaN) - (node.position?.x ?? NaN)) +
      Math.abs((engagement.position?.y ?? NaN) - (node.position?.y ?? NaN));
    if (distance !== 1) errors.push(`交战位不与首领相邻:${label}`);
    if (
      !isCardinalDirection(engagement.bossDirection) ||
      !isCardinalDirection(engagement.entryDirection) ||
      !isCardinalDirection(engagement.memberDirection)
    ) {
      errors.push(`交战朝向无效:${label}`);
    } else {
      const offset = {
        x: (engagement.position?.x ?? NaN) - (node.position?.x ?? NaN),
        y: (engagement.position?.y ?? NaN) - (node.position?.y ?? NaN),
      };
      const facesEntry =
        samePosition(offset, engagement.entryDirection) &&
        samePosition(engagement.bossDirection, engagement.entryDirection);
      const facesBoss =
        engagement.memberDirection.x === -engagement.bossDirection.x &&
        engagement.memberDirection.y === -engagement.bossDirection.y;
      if (!facesEntry || !facesBoss) errors.push(`交战朝向不相对:${label}`);
    }
    const bossNodes = Object.values(dungeon?.routeNodes || {}).filter(
      (candidate) => candidate.kind === "boss",
    );
    const sameBossPositions = bossNodes.filter((candidate) =>
      samePosition(candidate.position, node.position),
    );
    if (sameBossPositions.length !== 1) errors.push(`首领坐标不唯一:${label}`);
    if (
      bossNodes.some(
        (candidate) =>
          candidate.id !== node.id && samePosition(candidate.position, engagement.position),
      )
    ) {
      errors.push(`交战位与其他首领重叠:${label}`);
    }
    const duplicateEngagement = bossNodes.filter((candidate) =>
      samePosition(candidate.engagement?.position, engagement.position),
    );
    if (duplicateEngagement.length !== 1) errors.push(`交战位不唯一:${label}`);
    return { ok: errors.length === 0, errors };
  }

  function resolveNextRoom(dungeon, currentRoomId, clearedEncounterIds) {
    const route = resolveNextNode(dungeon, currentRoomId, clearedEncounterIds);
    if (route.type !== "next") return route;
    const room = getDungeonRoom(dungeon, route.nodeId);
    return room
      ? { type: "next", roomId: route.nodeId, roomIndex: room.roomIndex }
      : { type: "next", roomId: route.nodeId, roomIndex: -1 };
  }

  Game.Data = Object.freeze({
    palette,
    rarityDefinitions,
    bossDefinitions,
    propDefinitions,
    createWorld,
    getDungeonNode,
    getDungeonRoom,
    resolveNextNode,
    resolveNextRoom,
    validateCamp,
    validateDungeon,
    validateBossEngagement,
    validateSceneProps,
  });
})(window.CampfireTrials);
