"use strict";

// 一次性资料图生成器：直接读取运行时 data.js，不进入游戏加载链。
const fs = require("fs");
const path = require("path");

global.window = global;
require(path.join(__dirname, "..", "..", "core.js"));
require(path.join(__dirname, "..", "..", "data.js"));
require(path.join(__dirname, "..", "..", "world.js"));

const Game = global.CampfireTrials;
const dungeon = Game.Data.createWorld(960, 620).dungeon;
const validation = Game.Data.validateDungeon(dungeon);
if (!validation.ok) {
  throw new Error(`地图数据校验失败：${validation.errors.join("；")}`);
}

const OUTPUT = path.join(__dirname, "graystone-trial-overview.svg");
const WIDTH = 3200;
const HEIGHT = 3700;
const CELL = 34;
const MAP_LEFT = Math.round((WIDTH - dungeon.map.width * CELL) / 2);
const MAP_TOP = 330;
const tileColors = {
  stone: "#65707b",
  training: "#8b7660",
  arsenal: "#665e6b",
  library: "#655b7b",
  stairs: "#9191a0",
};

function escapeXml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

function point(position) {
  return {
    x: MAP_LEFT + (position.x + 0.5) * CELL,
    y: MAP_TOP + (position.y + 0.5) * CELL,
  };
}

function createBlockedSet(blockedBossIds, ignoredObstacleGroups) {
  const props = dungeon.props.filter(
    (prop) => !ignoredObstacleGroups.has(prop.routeObstacleGroup),
  );
  const bosses = [...blockedBossIds].map((roomId) => ({
    ...dungeon.routeNodes[roomId].position,
    alive: true,
  }));
  return Game.World.buildBlockedSet(props, bosses);
}

const routeSequence = [
  { id: "entrance", position: dungeon.entry },
  { id: "entrance_route", position: dungeon.routeNodes.entrance_route.position },
  { id: "training_route", position: dungeon.routeNodes.training_route.position },
  { id: "zigzag_route", position: dungeon.routeNodes.zigzag_route.position },
  {
    id: "lower_gate_room",
    position: dungeon.routeNodes.lower_gate_room.engagement.position,
    clearsBoss: "lower_gate_room",
  },
  { id: "stairs_route", position: dungeon.routeNodes.stairs_route.position },
  { id: "arsenal_route", position: dungeon.routeNodes.arsenal_route.position },
  {
    id: "arsenal_stairs_route",
    position: dungeon.routeNodes.arsenal_stairs_route.position,
  },
  { id: "main_fork", position: dungeon.routeNodes.main_fork.position },
  {
    id: "ember_gallery_room",
    position: dungeon.routeNodes.ember_gallery_room.engagement.position,
    clearsBoss: "ember_gallery_room",
  },
  {
    id: "main_fork_return",
    position: dungeon.routeNodes.main_fork.position,
    returnRoute: true,
  },
  {
    id: "library_turn_route",
    position: dungeon.routeNodes.library_turn_route.position,
  },
  { id: "library_route", position: dungeon.routeNodes.library_route.position },
  {
    id: "deep_sanctum_room",
    position: dungeon.routeNodes.deep_sanctum_room.engagement.position,
    clearsBoss: "deep_sanctum_room",
  },
];

function buildRouteSegments(ignoredObstacleGroups = new Set(), preferred = true) {
  const activeBossIds = new Set(dungeon.roomOrder);
  let direction = { x: 1, y: 0 };
  return routeSequence.slice(1).map((step, index) => {
    const previous = routeSequence[index];
    const blocked = createBlockedSet(activeBossIds, ignoredObstacleGroups);
    const result = preferred
      ? Game.World.findPreferredPathResult(
          previous.position,
          step.position,
          dungeon.map,
          blocked,
          { initialDirection: direction },
        )
      : Game.World.findPathResult(
          previous.position,
          step.position,
          dungeon.map,
          blocked,
        );
    if (!result.reachable) {
      throw new Error(
        `俯视路线不可达：${previous.position.x},${previous.position.y} -> ${step.position.x},${step.position.y}`,
      );
    }
    const metrics = preferred
      ? result.metrics
      : Game.World.measurePathMetrics(
          previous.position,
          result.path,
          dungeon.map,
          blocked,
          direction,
        );
    direction = metrics.endDirection || direction;
    if (step.clearsBoss) {
      direction = {
        ...dungeon.routeNodes[step.clearsBoss].engagement.memberDirection,
      };
      activeBossIds.delete(step.clearsBoss);
    }
    return {
      ...step,
      cells: [{ ...previous.position }, ...result.path],
      metrics,
      shortestLength: result.path.length,
    };
  });
}

function sumRouteMetrics(segments) {
  return segments.reduce(
    (totals, segment) => ({
      steps: totals.steps + segment.metrics.steps,
      turns: totals.turns + segment.metrics.turns,
      wallSteps: totals.wallSteps + segment.metrics.wallSteps,
    }),
    { steps: 0, turns: 0, wallSteps: 0 },
  );
}

const routeObstacleGroups = new Set(["training", "arsenal", "library"]);
const routeSegments = buildRouteSegments();
const ordinaryRouteSegments = buildRouteSegments(new Set(), false);
const unobstructedRouteSegments = buildRouteSegments(routeObstacleGroups);
const routeMetrics = sumRouteMetrics(routeSegments);
const ordinaryRouteMetrics = sumRouteMetrics(ordinaryRouteSegments);
const unobstructedRouteMetrics = sumRouteMetrics(unobstructedRouteSegments);
const routeIncrease = (
  ((routeMetrics.steps - unobstructedRouteMetrics.steps) /
    unobstructedRouteMetrics.steps) *
  100
).toFixed(1);

function renderRouteSegment(segment) {
  const points = segment.cells.map((position) => {
    const screen = point(position);
    return `${screen.x},${screen.y}`;
  });
  const color = segment.returnRoute ? "#72d6f6" : "#f1c96c";
  return [
    `<polyline points="${points.join(" ")}" fill="none" stroke="#151a21" stroke-width="22" stroke-linecap="round" stroke-linejoin="round" opacity="0.75" />`,
    `<polyline points="${points.join(" ")}" fill="none" stroke="${color}" stroke-width="11" stroke-linecap="round" stroke-linejoin="round" marker-end="url(#arrow-${segment.returnRoute ? "return" : "route"})" />`,
  ].join("\n");
}

function renderBoss(roomId, index) {
  const room = dungeon.routeNodes[roomId];
  const bossPoint = point(room.position);
  const engagementPoint = point(room.engagement.position);
  const bossArrowEnd = {
    x: bossPoint.x + room.engagement.bossDirection.x * CELL * 1.05,
    y: bossPoint.y + room.engagement.bossDirection.y * CELL * 1.05,
  };
  const memberArrowEnd = {
    x: engagementPoint.x + room.engagement.memberDirection.x * CELL * 0.9,
    y: engagementPoint.y + room.engagement.memberDirection.y * CELL * 0.9,
  };
  const labelX = bossPoint.x + (index === 1 ? 118 : 86);
  const labelY = bossPoint.y - 58;
  return `
    <g class="boss-marker">
      <line x1="${bossPoint.x}" y1="${bossPoint.y}" x2="${bossArrowEnd.x}" y2="${bossArrowEnd.y}" stroke="#e26e62" stroke-width="12" stroke-linecap="round" marker-end="url(#arrow-boss)" />
      <circle cx="${bossPoint.x}" cy="${bossPoint.y}" r="25" fill="#5a2328" stroke="#f39a83" stroke-width="7" />
      <text x="${bossPoint.x}" y="${bossPoint.y + 8}" class="marker-number">${index + 1}</text>
      <rect x="${engagementPoint.x - 15}" y="${engagementPoint.y - 15}" width="30" height="30" fill="#183f4f" stroke="#82e0fb" stroke-width="6" transform="rotate(45 ${engagementPoint.x} ${engagementPoint.y})" />
      <line x1="${engagementPoint.x}" y1="${engagementPoint.y}" x2="${memberArrowEnd.x}" y2="${memberArrowEnd.y}" stroke="#82e0fb" stroke-width="9" stroke-linecap="round" marker-end="url(#arrow-member)" />
      <text x="${labelX}" y="${labelY}" class="boss-label">${index + 1}. ${escapeXml(Game.Data.bossDefinitions[room.bossId].name)}</text>
      <text x="${labelX}" y="${labelY + 30}" class="room-label">${escapeXml(room.name)}</text>
      <text x="${labelX}" y="${labelY + 60}" class="coordinate-label">首领 (${room.position.x}, ${room.position.y}) · 交战位 (${room.engagement.position.x}, ${room.engagement.position.y})</text>
    </g>`;
}

function renderLandmark(label, position, anchor = "middle", offsetX = 0, offsetY = 0) {
  const marker = point(position);
  return `<text x="${marker.x + offsetX}" y="${marker.y + offsetY}" text-anchor="${anchor}" class="landmark-label">${escapeXml(label)}</text>`;
}

const tileSvg = [];
dungeon.map.tiles.forEach((row, y) => {
  row.forEach((tile, x) => {
    if (!tile.exists) return;
    const fill = tileColors[tile.type] || "#58636d";
    tileSvg.push(
      `<rect x="${MAP_LEFT + x * CELL}" y="${MAP_TOP + y * CELL}" width="${CELL}" height="${CELL}" fill="${fill}" stroke="#2a3038" stroke-width="1" />`,
    );
  });
});

const stairsSvg = dungeon.props
  .filter((prop) => prop.type === "stairs")
  .map((prop) => {
    const marker = point(prop);
    return `<g><rect x="${marker.x - 20}" y="${marker.y - 18}" width="40" height="36" rx="4" fill="#d3d4df" stroke="#353a45" stroke-width="5" />
      <path d="M ${marker.x - 13} ${marker.y - 8} h 26 M ${marker.x - 13} ${marker.y} h 26 M ${marker.x - 13} ${marker.y + 8} h 26" stroke="#656b79" stroke-width="4" /></g>`;
  })
  .join("\n");

const entranceStructureSvg = dungeon.props
  .filter((prop) => ["stoneWall", "stoneDoorway"].includes(prop.type))
  .map((prop) => {
    const marker = point(prop);
    if (prop.type === "stoneDoorway") {
      return `<g><rect x="${marker.x - 16}" y="${marker.y - 16}" width="32" height="32" fill="#18181d" stroke="#8a8890" stroke-width="5" />
        <path d="M ${marker.x - 11} ${marker.y + 13} V ${marker.y - 10} H ${marker.x + 11} V ${marker.y + 13}" fill="none" stroke="#c0bcc2" stroke-width="5" /></g>`;
    }
    return `<g><rect x="${marker.x - 16}" y="${marker.y - 16}" width="32" height="32" fill="#65636b" stroke="#302f35" stroke-width="5" />
      <path d="M ${marker.x - 13} ${marker.y} H ${marker.x + 13} M ${marker.x} ${marker.y - 13} V ${marker.y}" stroke="#918e96" stroke-width="3" /></g>`;
  })
  .join("\n");

const obstacleColors = {
  training: "#dba451",
  arsenal: "#d4775d",
  library: "#a98ad4",
};
const routeObstacleSvg = dungeon.props
  .filter((prop) => routeObstacleGroups.has(prop.routeObstacleGroup))
  .map((prop) => {
    const marker = point(prop);
    const color = obstacleColors[prop.routeObstacleGroup];
    return `<g><rect x="${marker.x - 12}" y="${marker.y - 12}" width="24" height="24" rx="4" fill="${color}" stroke="#171a20" stroke-width="5" />
      <path d="M ${marker.x - 7} ${marker.y + 6} L ${marker.x} ${marker.y - 7} L ${marker.x + 7} ${marker.y + 6} Z" fill="#f3ead5" opacity="0.78" /></g>`;
  })
  .join("\n");

const entryPoint = point(dungeon.entry);
const doorway = dungeon.props.find((prop) => prop.type === "stoneDoorway");
const doorwayPoint = point(doorway);
const svg = `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${WIDTH}" height="${HEIGHT}" viewBox="0 0 ${WIDTH} ${HEIGHT}">
  <defs>
    <marker id="arrow-route" markerWidth="15" markerHeight="15" refX="11" refY="5" orient="auto"><path d="M0,0 L12,5 L0,10 Z" fill="#f1c96c" /></marker>
    <marker id="arrow-return" markerWidth="15" markerHeight="15" refX="11" refY="5" orient="auto"><path d="M0,0 L12,5 L0,10 Z" fill="#72d6f6" /></marker>
    <marker id="arrow-boss" markerWidth="14" markerHeight="14" refX="10" refY="5" orient="auto"><path d="M0,0 L11,5 L0,10 Z" fill="#e26e62" /></marker>
    <marker id="arrow-member" markerWidth="14" markerHeight="14" refX="10" refY="5" orient="auto"><path d="M0,0 L11,5 L0,10 Z" fill="#82e0fb" /></marker>
    <style>
      .title { fill:#f2e3ba; font: 700 54px -apple-system, BlinkMacSystemFont, &quot;PingFang SC&quot;, &quot;Microsoft YaHei&quot;, sans-serif; letter-spacing: 5px; }
      .subtitle { fill:#aeb6c2; font: 400 27px -apple-system, BlinkMacSystemFont, &quot;PingFang SC&quot;, &quot;Microsoft YaHei&quot;, sans-serif; }
      .card-title { fill:#e8ecf0; font: 700 28px -apple-system, BlinkMacSystemFont, &quot;PingFang SC&quot;, &quot;Microsoft YaHei&quot;, sans-serif; }
      .legend { fill:#d6dce4; font: 400 24px -apple-system, BlinkMacSystemFont, &quot;PingFang SC&quot;, &quot;Microsoft YaHei&quot;, sans-serif; }
      .landmark-label { fill:#edf1f5; stroke:#151a21; stroke-width:7px; paint-order:stroke; font: 700 27px -apple-system, BlinkMacSystemFont, &quot;PingFang SC&quot;, &quot;Microsoft YaHei&quot;, sans-serif; }
      .boss-label { fill:#ffd5c5; stroke:#151a21; stroke-width:7px; paint-order:stroke; font: 700 30px -apple-system, BlinkMacSystemFont, &quot;PingFang SC&quot;, &quot;Microsoft YaHei&quot;, sans-serif; }
      .room-label { fill:#f2d899; stroke:#151a21; stroke-width:6px; paint-order:stroke; font: 700 23px -apple-system, BlinkMacSystemFont, &quot;PingFang SC&quot;, &quot;Microsoft YaHei&quot;, sans-serif; }
      .coordinate-label { fill:#d3dbe4; stroke:#151a21; stroke-width:6px; paint-order:stroke; font: 400 21px -apple-system, BlinkMacSystemFont, &quot;PingFang SC&quot;, &quot;Microsoft YaHei&quot;, sans-serif; }
      .marker-number { fill:#fff3de; text-anchor:middle; font:700 25px -apple-system, BlinkMacSystemFont, sans-serif; }
      .north { fill:#f0e5c7; text-anchor:middle; font:700 31px -apple-system, BlinkMacSystemFont, &quot;PingFang SC&quot;, &quot;Microsoft YaHei&quot;, sans-serif; }
    </style>
  </defs>
  <rect width="${WIDTH}" height="${HEIGHT}" fill="#0e1318" />
  <rect x="150" y="105" width="2900" height="156" rx="24" fill="#171e26" stroke="#3c4654" stroke-width="3" />
  <text x="220" y="175" class="title">灰岩试炼 · 副本俯视总图</text>
  <text x="224" y="224" class="subtitle">地图 ${dungeon.map.width} × ${dungeon.map.height} · 上北 / 右东 / 下南 / 左西 · 数据来源：data.js</text>
  <g transform="translate(2840 166)">
    <path d="M0,-47 L24,24 L0,12 L-24,24 Z" fill="#f1c96c" stroke="#f7f1dc" stroke-width="3" />
    <text x="0" y="-70" class="north">北</text><text x="69" y="9" class="north">东</text><text x="0" y="77" class="north">南</text><text x="-69" y="9" class="north">西</text>
  </g>
  <rect x="${MAP_LEFT - 28}" y="${MAP_TOP - 28}" width="${dungeon.map.width * CELL + 56}" height="${dungeon.map.height * CELL + 56}" rx="22" fill="#151a21" stroke="#46515e" stroke-width="4" />
  ${tileSvg.join("\n")}
  ${routeObstacleSvg}
  ${routeSegments.map(renderRouteSegment).join("\n")}
  ${stairsSvg}
  ${entranceStructureSvg}
  <g>
    <circle cx="${entryPoint.x}" cy="${entryPoint.y}" r="25" fill="#274c68" stroke="#a2dfff" stroke-width="7" />
    <path d="M ${entryPoint.x - 10} ${entryPoint.y + 8} L ${entryPoint.x} ${entryPoint.y - 14} L ${entryPoint.x + 10} ${entryPoint.y + 8} Z" fill="#d9f2ff" />
    <text x="${entryPoint.x + 54}" y="${entryPoint.y + 10}" class="landmark-label" text-anchor="start">门内出生点 (${dungeon.entry.x}, ${dungeon.entry.y})</text>
  </g>
  <text x="${doorwayPoint.x + 54}" y="${doorwayPoint.y + 10}" class="landmark-label" text-anchor="start">南侧实体门洞 (${doorway.x}, ${doorway.y})</text>
  ${renderBoss("lower_gate_room", 0)}
  ${renderBoss("ember_gallery_room", 1)}
  ${renderBoss("deep_sanctum_room", 2)}
  ${renderLandmark("训练场", { x: 27, y: 68 }, "middle", 0, -40)}
  ${renderLandmark("楼梯连接", dungeon.routeNodes.stairs_route.position, "start", 58, -18)}
  ${renderLandmark("步兵武器库", dungeon.routeNodes.arsenal_route.position, "start", 82, 70)}
  ${renderLandmark("主走廊", dungeon.routeNodes.main_fork.position, "middle", 0, -52)}
  ${renderLandmark("图书馆长廊", dungeon.routeNodes.library_route.position, "start", 120, 0)}
  <g transform="translate(150 3410)">
    <rect width="2900" height="218" rx="20" fill="#171e26" stroke="#3c4654" stroke-width="3" />
    <text x="40" y="48" class="card-title">图例</text>
    <line x1="40" y1="92" x2="126" y2="92" stroke="#f1c96c" stroke-width="11" stroke-linecap="round" /><text x="148" y="101" class="legend">主路线</text>
    <line x1="405" y1="92" x2="491" y2="92" stroke="#72d6f6" stroke-width="11" stroke-linecap="round" /><text x="513" y="101" class="legend">第 2 名首领战后折返</text>
    <circle cx="955" cy="92" r="18" fill="#5a2328" stroke="#f39a83" stroke-width="5" /><text x="987" y="101" class="legend">首领 / 红箭头为首领朝向</text>
    <rect x="1584" y="76" width="30" height="30" fill="#183f4f" stroke="#82e0fb" stroke-width="5" transform="rotate(45 1599 91)" /><text x="1640" y="101" class="legend">蕾琳交战位 / 蓝箭头为蕾琳朝向</text>
    <rect x="2480" y="72" width="38" height="36" rx="4" fill="#d3d4df" stroke="#353a45" stroke-width="4" /><text x="2540" y="101" class="legend">楼梯</text>
    <rect x="40" y="132" width="25" height="25" rx="4" fill="${obstacleColors.training}" /><text x="82" y="153" class="legend">训练障碍</text>
    <rect x="270" y="132" width="25" height="25" rx="4" fill="${obstacleColors.arsenal}" /><text x="312" y="153" class="legend">武器库障碍</text>
    <rect x="545" y="132" width="25" height="25" rx="4" fill="${obstacleColors.library}" /><text x="587" y="153" class="legend">书架障碍</text>
    <rect x="790" y="130" width="26" height="28" fill="#18181d" stroke="#c0bcc2" stroke-width="4" /><text x="836" y="153" class="legend">南侧实体门洞</text>
    <text x="1180" y="153" class="subtitle">偏好 ${routeMetrics.steps}步/${routeMetrics.turns}转/${routeMetrics.wallSteps}贴墙 · 普通最短路 ${ordinaryRouteMetrics.steps}步/${ordinaryRouteMetrics.turns}转/${ordinaryRouteMetrics.wallSteps}贴墙</text>
    <text x="40" y="197" class="subtitle">偏好寻路直接调用 world.js；过滤三组本轮障碍为 ${unobstructedRouteMetrics.steps} 步，当前增幅 ${routeIncrease}%。</text>
  </g>
</svg>`;

fs.writeFileSync(OUTPUT, svg, "utf8");
console.log(`已生成 ${OUTPUT}`);
