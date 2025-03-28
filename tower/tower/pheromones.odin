package tower

import rl "vendor:raylib"
import "core:math/rand"

getPheromoneStrength :: proc(ant: ^Ant, pheromones: ^PheromoneMap, cell_x: int, cell_y: int, dx: int, dy: int) -> f32 {

	if dx == 0 && dy == 0 {
		return 0
	}
	x := cell_x + dx
	y := cell_y + dy
	if !insideGrid(x, y) {
		return 0 
	}

	if (collision_avoidance && pheromones[x][y].occupied) {
		return 0
	}
	if ant.enemy {
		return 0 //enemy // TODO
	} else if (ant.homing) {
		return pheromones[x][y].home
	} else if pawnTask == .Food {
		return pheromones[x][y].food
	} else if pawnTask == .Wood {
		return pheromones[x][y].wood
	}
	return 0
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
