"use strict";

// T-20260804-010：从运行时 data.js 重建血色大厅 R2 正式资料 SVG。
const fs = require("fs");
const path = require("path");

global.window = global;
require(path.join(__dirname, "..", "..", "core.js"));
require(path.join(__dirname, "..", "..", "data.js"));
require(path.join(__dirname, "..", "..", "world.js"));

const Game = global.CampfireTrials;
const dungeon = Game.Data.createWorld(1280, 720).dungeon;
const validation = Game.Data.validateDungeon(dungeon);
if (!validation.ok) {
  throw new Error(`地图数据校验失败：${validation.errors.join("；")}`);
}

const OUTPUT = path.join(__dirname, "graystone-trial-overview.svg");
const WIDTH = 2400;
const HEIGHT = 4300;
const CELL = 34;
const MAP_LEFT = 105;
const MAP_TOP = 410;
const PANEL_LEFT = 1645;

const tileColors = Object.freeze({
  stone: "#6d5a61",
  training: "#81645b",
  arsenal: "#63515d",
  library: "#584a64",
  sunken: "#372b35",
  descendingStairs: "#72505d",
});

const propStyles = Object.freeze({
  lowWall: { fill: "#9d8a82", stroke: "#d0bbb0", label: "矮墙" },
  ironFence: { fill: "#27313a", stroke: "#a9bdc5", label: "围栏" },
  trainingDummy: { fill: "#a66f4a", stroke: "#e3b27b", label: "假人" },
  archeryTarget: { fill: "#c9b89b", stroke: "#da5757", label: "靶子" },
  crateStack: { fill: "#865b3d", stroke: "#c79663", label: "箱子" },
  weaponRack: { fill: "#596571", stroke: "#aebdca", label: "武器架" },
  routeDebris: { fill: "#574a46", stroke: "#a58d7f", label: "堵路杂物" },
});

function escapeXml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

function center(position) {
  return {
    x: MAP_LEFT + (position.x + 0.5) * CELL,
    y: MAP_TOP + (position.y + 0.5) * CELL,
  };
}

function arrow(start, direction, length = 25) {
  const end = { x: start.x + direction.x * length, y: start.y + direction.y * length };
  return `<line x1="${start.x}" y1="${start.y}" x2="${end.x}" y2="${end.y}" class="direction" marker-end="url(#arrow)"/>`;
}

const routeSegments = [];
let routePosition = { ...dungeon.entry };
let routeDirection = { x: 1, y: 0 };
const cleared = new Set();

function aliveBosses() {
  return dungeon.roomOrder
    .filter((roomId) => !cleared.has(roomId))
    .map((roomId) => ({ ...dungeon.routeNodes[roomId].position, alive: true }));
}

function addRoute(label, goal, color, postDirection = null) {
  const blocked = Game.World.buildBlockedSet(dungeon.props, aliveBosses());
  const result = Game.World.findPreferredPathResult(
    routePosition,
    goal,
    dungeon.map,
    blocked,
    { initialDirection: routeDirection },
  );
  if (!result.reachable) throw new Error(`资料图路线不可达：${label}`);
  routeSegments.push({
    label,
    color,
    points: [{ ...routePosition }, ...result.path],
    steps: result.path.length,
    shortest: result.shortestLength,
    turns: result.metrics.turns,
    wallSteps: result.metrics.wallSteps,
  });
  routePosition = { ...goal };
  routeDirection = postDirection || result.metrics.endDirection || routeDirection;
}

const boss1 = dungeon.routeNodes.lower_gate_room;
const boss2 = dungeon.routeNodes.ember_gallery_room;
const boss3 = dungeon.routeNodes.deep_sanctum_room;
const fork = dungeon.routeNodes.main_fork;
addRoute("入口→Boss1", boss1.engagement.position, "#ffd166", boss1.engagement.memberDirection);
cleared.add("lower_gate_room");
addRoute("Boss1→原分叉", fork.position, "#ffd166");
addRoute("原分叉→Boss2", boss2.engagement.position, "#ff9f43", boss2.engagement.memberDirection);
cleared.add("ember_gallery_room");
addRoute("Boss2→原分叉", fork.position, "#56c7ff");
addRoute("原分叉→Boss3", boss3.engagement.position, "#d99bff", boss3.engagement.memberDirection);

const totalSteps = routeSegments.reduce((sum, segment) => sum + segment.steps, 0);
const totalTurns = routeSegments.reduce((sum, segment) => sum + segment.turns, 0);
const totalWallSteps = routeSegments.reduce((sum, segment) => sum + segment.wallSteps, 0);
const propCounts = {};
dungeon.props.forEach((prop) => {
  propCounts[prop.type] = (propCounts[prop.type] || 0) + 1;
});

const svg = [];
svg.push(`<?xml version="1.0" encoding="UTF-8"?>`);
svg.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${WIDTH}" height="${HEIGHT}" viewBox="0 0 ${WIDTH} ${HEIGHT}">`);
svg.push(`<defs>
  <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#170f18"/><stop offset="1" stop-color="#09070b"/></linearGradient>
  <filter id="shadow"><feDropShadow dx="0" dy="4" stdDeviation="6" flood-color="#000" flood-opacity=".65"/></filter>
  <marker id="arrow" markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto"><path d="M0,0 L0,6 L7,3 z" fill="#e8f3f6"/></marker>
  <style>
    text{font-family:"Microsoft YaHei","Noto Sans CJK SC",sans-serif;fill:#f4e9e8}.title{font-size:54px;font-weight:700}.subtitle{font-size:25px;fill:#cdbabc}.panel-title{font-size:29px;font-weight:700}.body{font-size:21px;fill:#dccfd0}.small{font-size:18px;fill:#bcaeb1}.cell{stroke:#2a2026;stroke-width:1}.route{fill:none;stroke-width:8;stroke-linecap:round;stroke-linejoin:round;opacity:.92}.direction{stroke:#e8f3f6;stroke-width:5}.boss{fill:#b83946;stroke:#ffd2d4;stroke-width:4}.engage{fill:#36b6c5;stroke:#d8fbff;stroke-width:4}.fork{fill:#f0c05a;stroke:#fff0b2;stroke-width:4}.entry{fill:#78d388;stroke:#dcffe3;stroke-width:4}.panel{fill:#21171d;stroke:#5d434d;stroke-width:3}.divider{stroke:#5d434d;stroke-width:2}
  </style>
</defs>`);
svg.push(`<rect width="${WIDTH}" height="${HEIGHT}" fill="url(#bg)"/>`);
svg.push(`<text x="105" y="88" class="title">血色大厅 R2｜运行时网格资料图</text>`);
svg.push(`<text x="105" y="132" class="subtitle">T-20260804-010 · Sheet1!C2:AS103 · C2=(0,0) · 一格对一格 43×102</text>`);
svg.push(`<text x="105" y="174" class="subtitle">上北(-Y) / 右东(+X) / 下南(+Y) / 左西(-X)　黄/橙：前进　蓝：Boss2 折返　紫：Boss3</text>`);
svg.push(`<rect x="${MAP_LEFT - 16}" y="${MAP_TOP - 16}" width="${dungeon.map.width * CELL + 32}" height="${dungeon.map.height * CELL + 32}" rx="16" fill="#120d11" stroke="#67454f" stroke-width="4" filter="url(#shadow)"/>`);

for (let y = 0; y < dungeon.map.height; y += 1) {
  for (let x = 0; x < dungeon.map.width; x += 1) {
    const tile = dungeon.map.tiles[y][x];
    if (!tile.exists) continue;
    const fill = tileColors[tile.type] || tileColors.stone;
    const px = MAP_LEFT + x * CELL;
    const py = MAP_TOP + y * CELL;
    const classes = tile.elevation > 0 ? ` cell elevated-${tile.elevation}` : "cell";
    svg.push(`<rect x="${px}" y="${py}" width="${CELL}" height="${CELL}" fill="${fill}" class="${classes}" data-grid="${x},${y}" data-source="${escapeXml(tile.sourceSymbol)}"/>`);
    if (tile.type === "descendingStairs") {
      svg.push(`<path d="M${px + 5} ${py + 9} H${px + CELL - 5} M${px + 5} ${py + 17} H${px + CELL - 5} M${px + 5} ${py + 25} H${px + CELL - 5}" stroke="#c4949f" stroke-width="2" opacity=".8"/>`);
    }
  }
}

const entranceSymbols = [];
for (let y = 0; y < dungeon.map.height; y += 1) {
  for (let x = 0; x < dungeon.map.width; x += 1) {
    if (dungeon.map.tiles[y][x].sourceSymbol === "e") entranceSymbols.push({ x, y });
  }
}
for (const position of entranceSymbols) {
  const p = center(position);
  svg.push(`<rect x="${p.x - 12}" y="${p.y - 12}" width="24" height="24" rx="5" fill="#3e8f58" stroke="#bcf4ca" stroke-width="3"/>`);
}

for (const prop of dungeon.props) {
  const p = center(prop);
  const style = propStyles[prop.type];
  if (!style) continue;
  if (prop.type === "ironFence") {
    svg.push(`<rect x="${p.x - 14}" y="${p.y - 4}" width="28" height="8" rx="2" fill="${style.fill}" stroke="${style.stroke}" stroke-width="3"/>`);
    svg.push(`<line x1="${p.x - 8}" y1="${p.y - 13}" x2="${p.x - 8}" y2="${p.y + 13}" stroke="${style.stroke}" stroke-width="3"/><line x1="${p.x + 8}" y1="${p.y - 13}" x2="${p.x + 8}" y2="${p.y + 13}" stroke="${style.stroke}" stroke-width="3"/>`);
  } else if (prop.type === "archeryTarget") {
    svg.push(`<circle cx="${p.x}" cy="${p.y}" r="13" fill="${style.fill}" stroke="${style.stroke}" stroke-width="4"/><circle cx="${p.x}" cy="${p.y}" r="4" fill="#da5757"/>`);
  } else {
    svg.push(`<rect x="${p.x - 12}" y="${p.y - 12}" width="24" height="24" rx="${prop.type === "routeDebris" ? 10 : 3}" fill="${style.fill}" stroke="${style.stroke}" stroke-width="3"/>`);
  }
}

for (const segment of routeSegments) {
  const points = segment.points.map((position) => {
    const p = center(position);
    return `${p.x},${p.y}`;
  }).join(" ");
  svg.push(`<polyline points="${points}" class="route" stroke="${segment.color}"/>`);
}

const entryPoint = center(dungeon.entry);
svg.push(`<rect x="${entryPoint.x - 10}" y="${entryPoint.y - 10}" width="20" height="20" transform="rotate(45 ${entryPoint.x} ${entryPoint.y})" class="entry"/>`);
svg.push(`<text x="${entryPoint.x + 18}" y="${entryPoint.y + 7}" class="small">出生 (3,99)</text>`);
const forkPoint = center(fork.position);
svg.push(`<circle cx="${forkPoint.x}" cy="${forkPoint.y}" r="12" class="fork"/>`);
svg.push(`<text x="${forkPoint.x + 18}" y="${forkPoint.y - 10}" class="small">原分叉 (37,29)</text>`);

for (const [index, room] of [boss1, boss2, boss3].entries()) {
  const bp = center(room.position);
  const ep = center(room.engagement.position);
  svg.push(`<circle cx="${bp.x}" cy="${bp.y}" r="15" class="boss"/>`);
  svg.push(`<rect x="${ep.x - 10}" y="${ep.y - 10}" width="20" height="20" transform="rotate(45 ${ep.x} ${ep.y})" class="engage"/>`);
  svg.push(arrow(bp, room.engagement.bossDirection));
  svg.push(arrow(ep, room.engagement.memberDirection));
  svg.push(`<text x="${bp.x + 20}" y="${bp.y - 13}" class="small">Boss${index + 1} (${room.position.x},${room.position.y})</text>`);
}

svg.push(`<rect x="${PANEL_LEFT}" y="410" width="650" height="3440" rx="20" class="panel" filter="url(#shadow)"/>`);
let panelY = 475;
function panelTitle(text) { svg.push(`<text x="${PANEL_LEFT + 38}" y="${panelY}" class="panel-title">${escapeXml(text)}</text>`); panelY += 48; }
function panelLine(text, className = "body") { svg.push(`<text x="${PANEL_LEFT + 38}" y="${panelY}" class="${className}">${escapeXml(text)}</text>`); panelY += 34; }
function divider() { svg.push(`<line x1="${PANEL_LEFT + 32}" y1="${panelY}" x2="${PANEL_LEFT + 618}" y2="${panelY}" class="divider"/>`); panelY += 48; }

panelTitle("确认设计源");
panelLine("art/maps/source/blood-hall-map-r2.xlsx", "small");
panelLine("SHA-256", "small");
panelLine(dungeon.source.sha256.slice(0, 32), "small");
panelLine(dungeon.source.sha256.slice(32), "small");
panelLine("原范围：Sheet1!C2:AS103", "small");
divider();
panelTitle("工作簿对账");
panelLine(`0 可通行：${dungeon.source.counts.floor}`);
panelLine(`1 矮墙：${dungeon.source.counts.lowWall}`);
panelLine(`2 围栏：${dungeon.source.counts.fence}`);
panelLine(`Boss / 入口：${dungeon.source.counts.boss} / ${dungeon.source.counts.entrance}`);
panelLine(`假人 / 靶子：${dungeon.source.counts.trainingDummy} / ${dungeon.source.counts.archeryTarget}`);
panelLine(`箱子 / 武器架：${dungeon.source.counts.crate} / ${dungeon.source.counts.weaponRack}`);
panelLine(`堵路杂物：${dungeon.source.counts.routeDebris}`);
panelLine(`可见阻挡合计：${dungeon.props.length}`);
divider();
panelTitle("Boss2 下沉高度");
panelLine(`围栏内低层：+${dungeon.map.heightModel.loweredScreenY}px（屏幕 Y）`);
panelLine(`外圈下行楼梯：+${dungeon.map.heightModel.stairScreenY}px`);
panelLine(`低层 / 楼梯：${dungeon.map.heightModel.loweredTileCount} / ${dungeon.map.heightModel.stairTileCount} 格`);
panelLine("网格、碰撞与交战坐标不变", "small");
panelLine("角色、Boss2、阴影和投射终点共享低层", "small");
divider();
panelTitle("运行时偏好路线");
for (const segment of routeSegments) {
  panelLine(`${segment.label}：${segment.steps}步 / ${segment.turns}转 / ${segment.wallSteps}贴墙`, "small");
}
panelLine(`合计：${totalSteps}步 / ${totalTurns}转 / ${totalWallSteps}贴墙`);
divider();
panelTitle("交战坐标 / 朝向");
panelLine("Boss1 (23,62) 南；蕾琳 (23,63) 北", "small");
panelLine("Boss2 (37,23) 西；蕾琳 (36,23) 东", "small");
panelLine("Boss3 (15,3) 南；蕾琳 (15,4) 北", "small");
divider();
panelTitle("图例");
for (const [type, style] of Object.entries(propStyles)) {
  panelLine(`${style.label}：${propCounts[type] || 0}（可见且阻挡）`, "small");
}
panelLine("深紫：围栏内部下沉地面", "small");
panelLine("玫紫条纹：围栏外圈弧形下行楼梯", "small");

svg.push(`<text x="105" y="4140" class="subtitle">本图由 data.js / world.js 同源重建；正式游戏仍由 Canvas 实时绘制，不加载此资料图。</text>`);
svg.push(`<text x="105" y="4190" class="small">生成命令：node art/maps/generate-graystone-trial-overview.js</text>`);
svg.push(`</svg>`);

fs.writeFileSync(OUTPUT, `${svg.join("\n")}\n`, "utf8");
console.log(JSON.stringify({
  output: path.relative(process.cwd(), OUTPUT),
  bytes: fs.statSync(OUTPUT).size,
  dimensions: `${dungeon.map.width}x${dungeon.map.height}`,
  props: dungeon.props.length,
  preferredRouteSteps: totalSteps,
  routeSegments: routeSegments.map(({ label, steps, shortest, turns, wallSteps }) => ({ label, steps, shortest, turns, wallSteps })),
}, null, 2));
