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
    sunkenA: "#4a3b43",
    sunkenB: "#40333b",
    descendingStairsA: "#745763",
    descendingStairsB: "#654b56",
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
    lowWall: Object.freeze({ baseHeight: 21 }),
    ironFence: Object.freeze({ baseHeight: 36 }),
    archeryTarget: Object.freeze({ baseHeight: 47 }),
    routeDebris: Object.freeze({ baseHeight: 31 }),
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

  const BLOOD_HALL_R2_ROWS = Object.freeze([
    "              ....                         ",
    "             ......                        ",
    "            ........                       ",
    "            ...3....                       ",
    "            ........                       ",
    "            ........                       ",
    "             ......                        ",
    "              ....                         ",
    "               ..                          ",
    "              ....                         ",
    "              ....                         ",
    "              ....                         ",
    "              ....                         ",
    "               ..                          ",
    "              ....                         ",
    "              ....                         ",
    "              ....                         ",
    "              ....                         ",
    "               ..                   ....   ",
    "              ....                 ......  ",
    "              ....                ..f..f.. ",
    "              ....                .ff..ff. ",
    "              ....               ..f....f..",
    "               ..                ..f.2..f..",
    "              .... ... ....       .ff..ff. ",
    "              ..............      ...ff... ",
    "              ..............       ......  ",
    "              .... ... ....          ..    ",
    "               ..   ..  ..           ..    ",
    "              .... ... .................   ",
    "              .... ... ..................  ",
    "              .... ... .................   ",
    "                        ..           ..    ",
    "                       ....          ..    ",
    "                       ....          ..    ",
    "                       ....          ..    ",
    "                                     ..    ",
    "                                rrr  ..    ",
    "                               .........   ",
    "                               .........   ",
    "                               .........   ",
    "                                ...  ..    ",
    "                           ...  ...        ",
    "                          .........        ",
    "                          .c.......        ",
    "                          .........        ",
    "                           ...  ...        ",
    "                           ...             ",
    "                       .c.........r        ",
    "                      ............r        ",
    "                      ............r        ",
    "                       ... rrr  ...        ",
    "                       ..                  ",
    "                       ..                  ",
    "                       ..                  ",
    "                       ..                  ",
    "                       ..                  ",
    "                  ...........              ",
    "                  ...........              ",
    "                  .wwww..www.              ",
    "                  .w.......w.              ",
    "                  .........w.              ",
    "                  .....1...w.              ",
    "                  .w............ ...       ",
    "                  .w............ ...       ",
    "                  .w.......w. ......       ",
    "                  .www..wwww.              ",
    "                  ...........              ",
    "                  ...........              ",
    "                  ..                       ",
    "                  ..                       ",
    "                  ..                       ",
    "                  ..                       ",
    "                  ..                       ",
    "            ............                   ",
    "            ..wwww..ww..                   ",
    "            ..w......w..                   ",
    "            ..wdd....w..                   ",
    "            .........w..                   ",
    "            .......t w..                   ",
    "            ..wd.....w..                   ",
    "            ..wd...t w..                   ",
    "            ..w......w..                   ",
    "            ..wd...t w..                   ",
    "            ..w......w..                   ",
    "            ..wd.....w..                   ",
    "            ..w......w..                   ",
    "            ..w......wxx                   ",
    "            ..w......wxx                   ",
    "            ..w......w..                   ",
    "            xxw......w..                   ",
    "            xxw.........                   ",
    "            ..w.........                   ",
    "            ..w......w..                   ",
    "            ..ww..wwww..                   ",
    "            ............                   ",
    "            ..                             ",
    " ...............                           ",
    ".................                          ",
    " ...............                           ",
    "  eee                                      ",
    "  eee                                      ",
  ]);
  const BLOOD_HALL_R2_SOURCE_COUNTS = Object.freeze({
    floor: 826,
    lowWall: 66,
    fence: 16,
    boss: 3,
    entrance: 6,
    trainingDummy: 6,
    archeryTarget: 3,
    crate: 2,
    weaponRack: 9,
    routeDebris: 8,
  });
  const BLOOD_HALL_R2_LOW_ROOM_KEYS = new Set([
    "37,20",
    "38,20",
    "37,21",
    "38,21",
    "36,22",
    "37,22",
    "38,22",
    "39,22",
    "36,23",
    "37,23",
    "38,23",
    "39,23",
    "37,24",
    "38,24",
  ]);
  const BLOOD_HALL_R2_STAIR_KEYS = new Set([
    "35,19",
    "36,19",
    "37,19",
    "38,19",
    "39,19",
    "40,19",
    "34,20",
    "35,20",
    "40,20",
    "41,20",
    "34,21",
    "41,21",
    "34,22",
    "41,22",
    "34,23",
    "41,23",
    "34,24",
    "41,24",
    "34,25",
    "35,25",
    "36,25",
    "39,25",
    "40,25",
    "41,25",
    "36,26",
    "37,26",
    "38,26",
    "39,26",
  ]);
  const BLOOD_HALL_R2_LOWERED_SCREEN_Y = 18;
  const BLOOD_HALL_R2_STAIR_SCREEN_Y = 9;

  function dungeonZoneAt(x, y) {
    const positionKey = `${x},${y}`;
    if (
      BLOOD_HALL_R2_LOW_ROOM_KEYS.has(positionKey) ||
      BLOOD_HALL_R2_STAIR_KEYS.has(positionKey)
    ) {
      return "sunken_arena";
    }
    if (y <= 18) return "north_sanctum";
    if (y >= 74) return "training_hall";
    if (y >= 37 && y <= 56) return "arsenal_hall";
    if (y >= 57 && y <= 73) return "keeper_hall";
    return "blood_hall";
  }

  function dungeonTileTypeAt(x, y) {
    const positionKey = `${x},${y}`;
    if (BLOOD_HALL_R2_LOW_ROOM_KEYS.has(positionKey)) return "sunken";
    if (BLOOD_HALL_R2_STAIR_KEYS.has(positionKey)) return "descendingStairs";
    const zone = dungeonZoneAt(x, y);
    if (zone === "north_sanctum") return "library";
    if (zone === "training_hall") return "training";
    if (zone === "arsenal_hall") return "arsenal";
    return "stone";
  }

  function createDungeonMap() {
    const width = 43;
    const height = 102;
    if (
      BLOOD_HALL_R2_ROWS.length !== height ||
      BLOOD_HALL_R2_ROWS.some((row) => row.length !== width)
    ) {
      throw new Error("血色大厅 R2 编译网格尺寸无效");
    }
    const blockingSymbols = new Set(["w", "f", "d", "t", "c", "r", "x"]);
    const tiles = BLOOD_HALL_R2_ROWS.map((row, y) =>
      Array.from(row, (symbol, x) => {
        const exists = symbol !== " ";
        const positionKey = `${x},${y}`;
        const elevation = BLOOD_HALL_R2_LOW_ROOM_KEYS.has(positionKey)
          ? BLOOD_HALL_R2_LOWERED_SCREEN_Y
          : BLOOD_HALL_R2_STAIR_KEYS.has(positionKey)
            ? BLOOD_HALL_R2_STAIR_SCREEN_Y
            : 0;
        return {
          exists,
          type: exists ? dungeonTileTypeAt(x, y) : "void",
          zone: exists ? dungeonZoneAt(x, y) : null,
          variant: (x * 5 + y * 3) % 4,
          sourceSymbol: symbol,
          sourceBlocked: blockingSymbols.has(symbol),
          elevation,
        };
      }),
    );
    return {
      width,
      height,
      tiles,
      sourceCounts: BLOOD_HALL_R2_SOURCE_COUNTS,
      heightModel: Object.freeze({
        loweredScreenY: BLOOD_HALL_R2_LOWERED_SCREEN_Y,
        stairScreenY: BLOOD_HALL_R2_STAIR_SCREEN_Y,
        loweredTileCount: BLOOD_HALL_R2_LOW_ROOM_KEYS.size,
        stairTileCount: BLOOD_HALL_R2_STAIR_KEYS.size,
        center: Object.freeze({ x: 37.5, y: 22.5 }),
      }),
    };
  }

  function createDungeonProps() {
    const propBySymbol = Object.freeze({
      w: Object.freeze({ type: "lowWall", scale: 1, label: "矮墙" }),
      f: Object.freeze({ type: "ironFence", scale: 1, label: "围栏" }),
      d: Object.freeze({ type: "trainingDummy", scale: 1.2, label: "假人" }),
      t: Object.freeze({ type: "archeryTarget", scale: 1.08, label: "靶子" }),
      c: Object.freeze({ type: "crateStack", scale: 0.92, label: "箱子" }),
      r: Object.freeze({ type: "weaponRack", scale: 1.16, label: "武器架" }),
      x: Object.freeze({ type: "routeDebris", scale: 1, label: "堵路杂物" }),
    });
    const props = [];
    BLOOD_HALL_R2_ROWS.forEach((row, y) => {
      Array.from(row).forEach((symbol, x) => {
        const definition = propBySymbol[symbol];
        if (!definition) return;
        props.push({
          type: definition.type,
          x,
          y,
          scale: definition.scale,
          blocks: true,
          zone: dungeonZoneAt(x, y),
          variant: (x * 7 + y * 11) % 4,
          sourceLabel: definition.label,
        });
      });
    });
    return props;
  }


  function createDungeon(canvasWidth) {
    const roomOrder = ["lower_gate_room", "ember_gallery_room", "deep_sanctum_room"];
    const routeNodes = {
      entrance_route: {
        id: "entrance_route",
        name: "血色大厅入口",
        kind: "route",
        position: { x: 3, y: 99 },
        exits: [{ to: "lower_gate_room" }],
      },
      lower_gate_room: {
        id: "lower_gate_room",
        name: "血色训练厅",
        kind: "boss",
        bossId: "graystone_keeper",
        position: { x: 23, y: 62 },
        engagement: {
          bossDirection: { x: 0, y: 1 },
          entryDirection: { x: 0, y: 1 },
          position: { x: 23, y: 63 },
          memberDirection: { x: 0, y: -1 },
        },
        exits: [{ to: "main_fork" }],
      },
      main_fork: {
        id: "main_fork",
        name: "血色大厅分叉",
        kind: "route",
        position: { x: 37, y: 29 },
        exits: [
          { to: "ember_gallery_room", unlessCleared: ["ember_gallery_room"] },
          { to: "deep_sanctum_room", requiresCleared: ["ember_gallery_room"] },
        ],
      },
      ember_gallery_room: {
        id: "ember_gallery_room",
        name: "下沉围栏厅",
        kind: "boss",
        bossId: "furnace_colossus",
        position: { x: 37, y: 23 },
        engagement: {
          bossDirection: { x: -1, y: 0 },
          entryDirection: { x: -1, y: 0 },
          position: { x: 36, y: 23 },
          memberDirection: { x: 1, y: 0 },
        },
        exits: [{ to: "main_fork" }],
      },
      deep_sanctum_room: {
        id: "deep_sanctum_room",
        name: "北端血色圆厅",
        kind: "boss",
        bossId: "stonecrown_lord",
        position: { x: 15, y: 3 },
        engagement: {
          bossDirection: { x: 0, y: 1 },
          entryDirection: { x: 0, y: 1 },
          position: { x: 15, y: 4 },
          memberDirection: { x: 0, y: -1 },
        },
        final: true,
        exits: [],
      },
    };
    const map = createDungeonMap();
    const props = createDungeonProps();
    const dungeon = {
      id: "blood_hall_r2",
      name: "血色大厅",
      orientation: Object.freeze({
        north: "-y",
        east: "+x",
        south: "+y",
        west: "-x",
      }),
      origin: { x: canvasWidth / 2, y: 0 },
      map,
      props,
      entry: { x: 3, y: 99 },
      entranceRoomId: "entrance_route",
      roomOrder,
      routeNodes,
      source: Object.freeze({
        taskId: "T-20260804-010",
        workbook: "art/maps/source/blood-hall-map-r2.xlsx",
        sourcePath: "C:/Users/winly/Downloads/血色大厅地图.xlsx",
        sha256: "3ed310070b04433573088df1f134305d40242a44e46197a811c21f4e19451951",
        range: "Sheet1!C2:AS103",
        normalizedOrigin: "C2=(0,0)",
        width: 43,
        height: 102,
        counts: BLOOD_HALL_R2_SOURCE_COUNTS,
      }),
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
