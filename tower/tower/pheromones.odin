package tower

import rl "vendor:raylib"
import "core:math/rand"

PheromoneMap :: [GRID_WIDTH][GRID_HEIGHT]PheromoneCell
PHEROMONE_CAPACITY :: 10.0
DECAY_FACTOR :: 0.1

PheromoneCell :: struct {
    home: f32,
    food: f32,
    wood: f32,
    enemy: f32,
    occupied: bool,
}

getPheromoneStrength :: proc(ant: ^Ant, pheromones: ^PheromoneMap, cell_x: int, cell_y: int, dx: int, dy: int) -> f32 {

	if dx == 0 && dy == 0 {
		return 0
	}
	x := cell_x + dx
	y := cell_y + dy
	if !insideGrid(x, y) {
		return 0 
	}

	if (collisionAvoidance && pheromones[x][y].occupied) {
		return 0
	}
	if ant.enemy {
		return 0 //enemy // TODO
	} 
	if (ant.homing) {
		return pheromones[x][y].home
	} 

	power: f32

	#partial switch pawnTask {
	case .Food: power = pheromones[x][y].food
	case .Wood: power = pheromones[x][y].food
	case: power = 0.0
	}
	if power == 0.0 {
		power -= pheromones[x][y].home
	}

	return power
}

findNewDir :: proc(ant: ^Ant, pheromones: ^PheromoneMap, cell_x: int, cell_y: int) -> Vec2f {
	max_strength: f32 = 0
	target_cell := Vec2f{0, 0}
	for dx in -1..=1 {
		for dy in -1..=1 {
			strength := getPheromoneStrength(ant, pheromones, cell_x, cell_y, dx, dy)
			if strength > max_strength || (strength == max_strength && rand.float32() > 0.5) {
				max_strength = strength
				target_cell = Vec2f{
					f32(cell_x + dx) * CELL_SIZE + CELL_SIZE/2,
					f32(cell_y + dy) * CELL_SIZE + CELL_SIZE/2,
				}
			}
		}
	}

	// Calculate new direction
	if max_strength > 0 {
		desired_dir := rl.Vector2Normalize(target_cell - ant.pos)
		return rl.Vector2Normalize(0.7*ant.dir + 0.3*desired_dir)
	} else {
		// Random wander
		angle := rand.float32_range(-0.3, 0.3)
		return rl.Vector2Rotate(ant.dir, angle)
	}
}

depositPheromones :: proc(ant: ^Ant, pheromones: ^PheromoneMap, x: int, y: int, max_deposit: f32) {
	if !insideGrid(x, y) {
		return
	}
	if ant.enemy {
		return // TODO
	} 
	cell := &pheromones[x][y]
	if !ant.homing {
		updatePheromone(&cell.home, max_deposit)
	}
	if isForaging() {
		depositResourcePheromones(ant^, cell, max_deposit)
		return
	}
}

updatePheromone :: proc(pher: ^f32, max_deposit: f32) {
    pher^ = max(pher^, max_deposit)
}

depositResourcePheromones :: proc(ant: Ant, cell: ^PheromoneCell, maxDeposit: f32) {
	if ant.carrying_food {
		updatePheromone(&cell.food, maxDeposit)
	} else if ant.carrying_wood {
		updatePheromone(&cell.wood, maxDeposit)
	}
}

decayPheromones :: proc(pheromones: ^PheromoneMap, dt: f32) {
	decay: = DECAY_FACTOR * dt
	for x in 0..<GRID_WIDTH {
		for y in 0..<GRID_HEIGHT {
			if (pheromones[x][y].home < decay) {
				pheromones[x][y].home = 0
			} else {
				pheromones[x][y].home -= decay
			}
			if (pheromones[x][y].food < decay) {
				pheromones[x][y].food = 0
			} else {
				pheromones[x][y].food -= decay
			}
			if (pheromones[x][y].wood < decay) {
				pheromones[x][y].wood = 0
			} else {
				pheromones[x][y].wood -= decay
			}
		}
	}
}

clearPheromones :: proc(pheromones: ^PheromoneMap) {
	for x in 0..<WINDOW_WIDTH/CELL_SIZE {
		for y in 0..<WINDOW_HEIGHT/CELL_SIZE {
			pheromones[x][y] = PheromoneCell{0, 0, 0, 0, false}
		}
	}
}
