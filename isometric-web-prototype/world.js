(function (Game) {
  "use strict";

  if (!Game.Core) throw new Error("core.js must load before world.js");

  const { DIRECTIONS, TILE_WIDTH, TILE_HEIGHT } = Game.Core;
  const PREFERRED_DIRECTIONS = Object.freeze([
    Object.freeze({ x: 1, y: 0 }),
    Object.freeze({ x: 0, y: 1 }),
    Object.freeze({ x: -1, y: 0 }),
    Object.freeze({ x: 0, y: -1 }),
  ]);
  const DEFAULT_PATH_PREFERENCES = Object.freeze({
    maxExtraSteps: 2,
    minimumLengthForDetour: 6,
    extraStepPenalty: 50,
    turnPenalty: 14,
    initialTurnPenalty: 10,
    reversePenalty: 4,
    orthogonalObstaclePenalty: 8,
    diagonalObstaclePenalty: 3,
    distanceTwoObstaclePenalty: 1,
    goalRelaxDistance: 2,
  });

  function buildBlockedSet(props, bossOrBosses) {
    const blocked = new Set(
      props
        .filter((prop) => prop.blocks !== false)
        .map((prop) => Game.Core.cellKey(prop.x, prop.y)),
    );
    const bosses = Array.isArray(bossOrBosses)
      ? bossOrBosses
      : bossOrBosses
        ? [bossOrBosses]
        : [];
    bosses.forEach((boss) => {
      if (boss?.alive !== false) blocked.add(Game.Core.cellKey(boss.x, boss.y));
    });
    return blocked;
  }

  function isWalkable(x, y, map, blocked) {
    return (
      Number.isInteger(x) &&
      Number.isInteger(y) &&
      x >= 0 &&
      y >= 0 &&
      x < map.width &&
      y < map.height &&
      map.tiles[y][x].exists &&
      !blocked.has(Game.Core.cellKey(x, y))
    );
  }

  function findPathResult(start, goal, map, blocked) {
    if (!isWalkable(start.x, start.y, map, blocked)) {
      return { reachable: false, path: [] };
    }
    if (!isWalkable(goal.x, goal.y, map, blocked)) {
      return { reachable: false, path: [] };
    }
    const queue = [start];
    let queueIndex = 0;
    const cameFrom = new Map([[Game.Core.cellKey(start.x, start.y), null]]);
    while (queueIndex < queue.length) {
      const current = queue[queueIndex];
      queueIndex += 1;
      if (current.x === goal.x && current.y === goal.y) {
        const path = [];
        let cursor = current;
        while (cursor && !(cursor.x === start.x && cursor.y === start.y)) {
          path.unshift(cursor);
          cursor = cameFrom.get(Game.Core.cellKey(cursor.x, cursor.y));
        }
        return { reachable: true, path };
      }
      for (const direction of DIRECTIONS) {
        const next = { x: current.x + direction.x, y: current.y + direction.y };
        const key = Game.Core.cellKey(next.x, next.y);
        if (!isWalkable(next.x, next.y, map, blocked) || cameFrom.has(key)) continue;
        cameFrom.set(key, current);
        queue.push(next);
      }
    }
    return { reachable: false, path: [] };
  }

  function findPath(start, goal, map, blocked) {
    return findPathResult(start, goal, map, blocked).path;
  }

  function directionIndex(direction) {
    return PREFERRED_DIRECTIONS.findIndex(
      (candidate) =>
        candidate.x === direction?.x &&
        candidate.y === direction?.y,
    );
  }

  function orderedDirectionIndexes(previousDirectionIndex) {
    if (previousDirectionIndex < 0) return [0, 1, 2, 3];
    return [
      previousDirectionIndex,
      (previousDirectionIndex + 3) % 4,
      (previousDirectionIndex + 1) % 4,
      (previousDirectionIndex + 2) % 4,
    ];
  }

  function isObstacle(x, y, map, blocked) {
    return !isWalkable(x, y, map, blocked);
  }

  function clearancePenalty(x, y, goal, map, blocked, preferences) {
    const distanceToGoal = Math.abs(goal.x - x) + Math.abs(goal.y - y);
    if (distanceToGoal <= preferences.goalRelaxDistance) return 0;
    let penalty = 0;
    PREFERRED_DIRECTIONS.forEach((direction) => {
      if (isObstacle(x + direction.x, y + direction.y, map, blocked)) {
        penalty += preferences.orthogonalObstaclePenalty;
      }
    });
    [
      { x: 1, y: 1 },
      { x: 1, y: -1 },
      { x: -1, y: 1 },
      { x: -1, y: -1 },
    ].forEach((direction) => {
      if (isObstacle(x + direction.x, y + direction.y, map, blocked)) {
        penalty += preferences.diagonalObstaclePenalty;
      }
    });
    for (let offsetY = -2; offsetY <= 2; offsetY += 1) {
      for (let offsetX = -2; offsetX <= 2; offsetX += 1) {
        if (Math.max(Math.abs(offsetX), Math.abs(offsetY)) !== 2) continue;
        if (isObstacle(x + offsetX, y + offsetY, map, blocked)) {
          penalty += preferences.distanceTwoObstaclePenalty;
        }
      }
    }
    return penalty;
  }

  function mergePathPreferences(options, shortestLength) {
    const merged = {
      ...DEFAULT_PATH_PREFERENCES,
      ...options,
    };
    const requestedExtraSteps = Number.isInteger(options?.maxExtraSteps)
      ? Math.max(0, options.maxExtraSteps)
      : merged.maxExtraSteps;
    const maxExtraSteps =
      shortestLength >= merged.minimumLengthForDetour
        ? requestedExtraSteps
        : 0;
    return {
      ...merged,
      maxExtraSteps,
    };
  }

  function compareGoalCandidates(first, second, shortestLength, preferences) {
    const firstScore =
      (first.step - shortestLength) * preferences.extraStepPenalty +
      first.penalty;
    const secondScore =
      (second.step - shortestLength) * preferences.extraStepPenalty +
      second.penalty;
    if (firstScore !== secondScore) return firstScore - secondScore;
    if (first.step !== second.step) return first.step - second.step;
    if (first.penalty !== second.penalty) return first.penalty - second.penalty;
    return first.directionIndex - second.directionIndex;
  }

  function reconstructPreferredPath(candidate) {
    const path = [];
    let cursor = candidate;
    while (cursor?.parent) {
      path.unshift({ x: cursor.x, y: cursor.y });
      cursor = cursor.parent;
    }
    return path;
  }

  function measurePathMetrics(start, path, map, blocked, initialDirection) {
    let previous = { x: start.x, y: start.y };
    let previousDirectionIndex = directionIndex(initialDirection);
    let turns = 0;
    let wallSteps = 0;
    path.forEach((cell) => {
      const nextDirectionIndex = directionIndex({
        x: cell.x - previous.x,
        y: cell.y - previous.y,
      });
      if (
        previousDirectionIndex >= 0 &&
        nextDirectionIndex >= 0 &&
        nextDirectionIndex !== previousDirectionIndex
      ) {
        turns += 1;
      }
      if (
        PREFERRED_DIRECTIONS.some((direction) =>
          isObstacle(cell.x + direction.x, cell.y + direction.y, map, blocked),
        )
      ) {
        wallSteps += 1;
      }
      previous = cell;
      previousDirectionIndex = nextDirectionIndex;
    });
    const endDirection =
      previousDirectionIndex >= 0
        ? { ...PREFERRED_DIRECTIONS[previousDirectionIndex] }
        : directionIndex(initialDirection) >= 0
          ? {
              ...PREFERRED_DIRECTIONS[directionIndex(initialDirection)],
            }
          : null;
    return {
      steps: path.length,
      turns,
      wallSteps,
      endDirection,
    };
  }

  function findPreferredPathResult(start, goal, map, blocked, options = {}) {
    const shortest = findPathResult(start, goal, map, blocked);
    if (!shortest.reachable) {
      return {
        reachable: false,
        path: [],
        shortestLength: 0,
        maxSteps: 0,
        metrics: null,
      };
    }
    const shortestLength = shortest.path.length;
    if (shortestLength === 0) {
      return {
        reachable: true,
        path: [],
        shortestLength: 0,
        maxSteps: 0,
        metrics: measurePathMetrics(start, [], map, blocked, options.initialDirection),
      };
    }
    const preferences = mergePathPreferences(options, shortestLength);
    const maxSteps = shortestLength + preferences.maxExtraSteps;
    const initialDirectionIndex = directionIndex(options.initialDirection);
    let currentStates = new Map();
    const startState = {
      x: start.x,
      y: start.y,
      directionIndex: initialDirectionIndex,
      penalty: 0,
      step: 0,
      parent: null,
    };
    currentStates.set(
      `${start.x},${start.y}|${initialDirectionIndex}`,
      startState,
    );
    const goalCandidates = [];

    for (let step = 1; step <= maxSteps; step += 1) {
      const nextStates = new Map();
      currentStates.forEach((current) => {
        orderedDirectionIndexes(current.directionIndex).forEach((nextDirectionIndex) => {
          const direction = PREFERRED_DIRECTIONS[nextDirectionIndex];
          const nextX = current.x + direction.x;
          const nextY = current.y + direction.y;
          if (!isWalkable(nextX, nextY, map, blocked)) return;
          const changedDirection =
            current.directionIndex >= 0 &&
            nextDirectionIndex !== current.directionIndex;
          const reversed =
            current.directionIndex >= 0 &&
            nextDirectionIndex === (current.directionIndex + 2) % 4;
          let transitionPenalty = clearancePenalty(
            nextX,
            nextY,
            goal,
            map,
            blocked,
            preferences,
          );
          if (changedDirection) {
            transitionPenalty += preferences.turnPenalty;
            if (current.step === 0) {
              transitionPenalty += preferences.initialTurnPenalty;
            }
          }
          if (reversed) transitionPenalty += preferences.reversePenalty;
          const candidate = {
            x: nextX,
            y: nextY,
            directionIndex: nextDirectionIndex,
            penalty: current.penalty + transitionPenalty,
            step,
            parent: current,
          };
          const key = `${nextX},${nextY}|${nextDirectionIndex}`;
          const existing = nextStates.get(key);
          if (!existing || candidate.penalty < existing.penalty) {
            nextStates.set(key, candidate);
          }
        });
      });
      currentStates = nextStates;
      currentStates.forEach((candidate) => {
        if (candidate.x === goal.x && candidate.y === goal.y) {
          goalCandidates.push(candidate);
        }
      });
      if (currentStates.size === 0) break;
    }

    if (goalCandidates.length === 0) {
      return {
        reachable: false,
        path: [],
        shortestLength,
        maxSteps,
        metrics: null,
      };
    }
    goalCandidates.sort((first, second) =>
      compareGoalCandidates(first, second, shortestLength, preferences),
    );
    const path = reconstructPreferredPath(goalCandidates[0]);
    return {
      reachable: true,
      path,
      shortestLength,
      maxSteps,
      metrics: measurePathMetrics(
        start,
        path,
        map,
        blocked,
        options.initialDirection,
      ),
    };
  }

  function findPreferredPath(start, goal, map, blocked, options = {}) {
    return findPreferredPathResult(start, goal, map, blocked, options).path;
  }

  function findApproachPathResult(member, engagementPosition, map, blocked, options = {}) {
    const goal = {
      x: engagementPosition?.x,
      y: engagementPosition?.y,
    };
    const result = findPreferredPathResult(
      { x: Math.round(member.x), y: Math.round(member.y) },
      goal,
      map,
      blocked,
      {
        ...options,
        initialDirection: options.initialDirection || member.direction,
      },
    );
    return { ...result, goal: result.reachable ? goal : null };
  }

  function findApproachPath(member, engagementPosition, map, blocked, options = {}) {
    return findApproachPathResult(
      member,
      engagementPosition,
      map,
      blocked,
      options,
    ).path;
  }

  function chooseCampDestination(member, map, blocked, activityBounds) {
    const bounds = activityBounds || {
      minX: 0,
      maxX: map.width - 1,
      minY: 0,
      maxY: map.height - 1,
    };
    const routeBlocked = new Set(blocked);
    for (let y = 0; y < map.height; y += 1) {
      for (let x = 0; x < map.width; x += 1) {
        if (
          x < bounds.minX ||
          x > bounds.maxX ||
          y < bounds.minY ||
          y > bounds.maxY
        ) {
          routeBlocked.add(Game.Core.cellKey(x, y));
        }
      }
    }
    const candidates = [];
    for (let y = bounds.minY; y <= bounds.maxY; y += 1) {
      for (let x = bounds.minX; x <= bounds.maxX; x += 1) {
        if (!isWalkable(x, y, map, routeBlocked)) continue;
        const distance = Math.abs(x - member.x) + Math.abs(y - member.y);
        if (distance >= 3 && distance <= 8) candidates.push({ x, y });
      }
    }
    Game.Core.shuffle(candidates);
    for (const candidate of candidates) {
      const path = findPath(
        { x: Math.round(member.x), y: Math.round(member.y) },
        candidate,
        map,
        routeBlocked,
      );
      if (path.length > 0) {
        member.target = candidate;
        member.path = path;
        return;
      }
    }
    member.waitTimer = 0.8;
  }

  function advanceAlongPath(member, delta, getStats) {
    if (member.path.length === 0) {
      member.moving = false;
      return;
    }
    const nextCell = member.path[0];
    const deltaX = nextCell.x - member.x;
    const deltaY = nextCell.y - member.y;
    const distance = Math.hypot(deltaX, deltaY);
    const travel = getStats(member).moveSpeed * delta;
    member.direction = { x: Math.sign(deltaX), y: Math.sign(deltaY) };
    member.moving = true;
    member.walkClock += delta * 9;
    if (distance <= 0.0001 || travel >= distance) {
      member.x = nextCell.x;
      member.y = nextCell.y;
      member.path.shift();
      if (member.path.length === 0) {
        member.moving = false;
        member.waitTimer = 0.7 + Math.random() * 0.8;
      }
    } else {
      member.x += (deltaX / distance) * travel;
      member.y += (deltaY / distance) * travel;
    }
  }

  function updateCamp(delta, party, camp, getStats) {
    const blocked = buildBlockedSet(camp.props);
    party.members.forEach((member) => {
      if (member.path.length === 0) {
        member.moving = false;
        member.waitTimer -= delta;
        if (member.waitTimer <= 0) {
          chooseCampDestination(
            member,
            camp.map,
            blocked,
            camp.activityBounds,
          );
        }
      } else {
        advanceAlongPath(member, delta, getStats);
      }
    });
  }

  function gridToScreen(origin, gridX, gridY) {
    return {
      x: origin.x + (gridX - gridY) * (TILE_WIDTH / 2),
      y: origin.y + (gridX + gridY) * (TILE_HEIGHT / 2),
    };
  }

  function getMapScreenBounds(scene) {
    const halfWidth = TILE_WIDTH / 2;
    const halfHeight = TILE_HEIGHT / 2;
    let minimumX = Infinity;
    let maximumX = -Infinity;
    let minimumY = Infinity;
    let maximumY = -Infinity;
    for (let y = 0; y < scene.map.height; y += 1) {
      for (let x = 0; x < scene.map.width; x += 1) {
        if (!scene.map.tiles[y][x].exists) continue;
        const point = gridToScreen(scene.origin, x, y);
        minimumX = Math.min(minimumX, point.x - halfWidth);
        maximumX = Math.max(maximumX, point.x + halfWidth);
        minimumY = Math.min(minimumY, point.y - halfHeight);
        maximumY = Math.max(maximumY, point.y + halfHeight + 17);
      }
    }
    if (!Number.isFinite(minimumX)) {
      return { minX: 0, maxX: 0, minY: 0, maxY: 0, width: 0, height: 0 };
    }
    return {
      minX: minimumX,
      maxX: maximumX,
      minY: minimumY,
      maxY: maximumY,
      width: maximumX - minimumX,
      height: maximumY - minimumY,
    };
  }

  function computeClampedCameraTarget(focusPoint, bounds, viewport, padding = 32) {
    const desiredX = viewport.width / 2 - focusPoint.x;
    const desiredY = viewport.height * 0.48 - focusPoint.y;
    const usableWidth = Math.max(0, viewport.width - padding * 2);
    const usableHeight = Math.max(0, viewport.height - padding * 2);
    const x =
      bounds.width <= usableWidth
        ? viewport.width / 2 - (bounds.minX + bounds.maxX) / 2
        : Math.max(
            viewport.width - padding - bounds.maxX,
            Math.min(padding - bounds.minX, desiredX),
          );
    const y =
      bounds.height <= usableHeight
        ? viewport.height / 2 - (bounds.minY + bounds.maxY) / 2
        : Math.max(
            viewport.height - padding - bounds.maxY,
            Math.min(padding - bounds.minY, desiredY),
          );
    return { x, y };
  }

  function updateCamera(camera, target, delta, snap = false) {
    if (snap || !camera.initialized) {
      camera.x = target.x;
      camera.y = target.y;
      camera.initialized = true;
      return camera;
    }
    const alpha = 1 - Math.exp(-7 * Math.max(0, delta));
    camera.x += (target.x - camera.x) * alpha;
    camera.y += (target.y - camera.y) * alpha;
    return camera;
  }

  Game.World = Object.freeze({
    buildBlockedSet,
    isWalkable,
    findPathResult,
    findPath,
    findPreferredPathResult,
    findPreferredPath,
    findApproachPathResult,
    findApproachPath,
    measurePathMetrics,
    chooseCampDestination,
    advanceAlongPath,
    updateCamp,
    gridToScreen,
    getMapScreenBounds,
    computeClampedCameraTarget,
    updateCamera,
  });
})(window.CampfireTrials);
