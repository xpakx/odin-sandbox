package tower

import "core:math"
import rl "vendor:raylib"

ANT_SPEED :: 75.0

Ant :: struct {
    pos: Vec2f,
    dir: Vec2f,
    homing: bool,
    carrying_food: bool,
    carrying_wood: bool,
    task_len: f32,
    enemy: bool,
    frame_timer: f32,
    animation_frame: int,
    nextInRow: ^Ant,
    animations: CharAnimationSet,
}

createAnt :: proc(position: Vec2f, animations: CharAnimationSet, enemy: bool = false) -> Ant {
	return Ant{
		pos = position,
		dir = randDirection(),
		homing = false,
		carrying_food = false,
		task_len = 100.0,
		frame_timer = FRAME_LENGTH,
		animation_frame = 0,
		nextInRow = nil,
		enemy = enemy,
		animations = animations,
	}
}

updateTasks :: proc(ant: ^Ant, dt: f32) {
	ant.task_len = max(ant.task_len - dt, 0.0)

	if task_changed {
		ant.homing = true
	}
	if rl.Vector2Distance(ant.pos, HOME_POS) < HOME_RADIUS {
		if ant.homing {
			ant.carrying_food = false
			ant.carrying_wood = false
			ant.homing = false
			ant.dir = randDirection()
			ant.task_len = 100.0
		} 
	} else if pawnTask == .Food && rl.Vector2Distance(ant.pos, FOOD_POS) < foodRadius && !ant.carrying_food && !ant.carrying_wood {
		// food_radius -= 0.2
		ant.carrying_food = true
		ant.homing = true
		ant.dir = randDirection()
		ant.task_len = 100.0
	} else if pawnTask == .Wood && rl.Vector2Distance(ant.pos, WOOD_POS) < woodRadius && !ant.carrying_wood && !ant.carrying_food {
		// wood_radius -= 0.2
		ant.carrying_wood = true
		ant.homing = true
		ant.dir = randDirection()
		ant.task_len = 100.0
	}

	if ant.task_len == 0.0 {
		ant.homing = true
	}
}

updateAnt :: proc(ant: ^Ant, pheromones: ^PheromoneMap, tiles: ^TileMap, dt: f32) {
	ant.nextInRow = nil

	if !ant.enemy {
		updateTasks(ant, dt)
	}

	current_pheromone_strength := ant.task_len/100.0
	current_pheromone_strength = math.pow(current_pheromone_strength, 2)
	max_deposit := current_pheromone_strength * PHEROMONE_CAPACITY

	cell_x := int(ant.pos.x / CELL_SIZE)
	cell_y := int(ant.pos.y / CELL_SIZE)
	depositPheromones(ant, pheromones, cell_x, cell_y, max_deposit)

	updateOccupation(pheromones, cell_x, cell_y, false)

	// Follow pheromone gradient
	ant.dir = findNewDir(ant, pheromones, cell_x, cell_y)
	ant.pos = ant.pos + ant.dir * ANT_SPEED * dt

	ant.pos.x = clamp(ant.pos.x, 0, WINDOW_WIDTH)
	ant.pos.y = clamp(ant.pos.y, 0, WINDOW_HEIGHT)

	tile_x := int(ant.pos.x / TILE_SIZE)
	tile_y := int(ant.pos.y / TILE_SIZE)
	if insideTileGrid(tile_x, tile_y) {
		cell := tiles[0][tile_x][tile_y]
		if isBlocked(cell) {
			ant.pos = ant.pos - ant.dir * ANT_SPEED * dt // TODO
			ant.dir *= -1
		}
	}

	new_cell_x := int(ant.pos.x / CELL_SIZE)
	new_cell_y := int(ant.pos.y / CELL_SIZE)


	updateOccupation(pheromones, new_cell_x, new_cell_y, true)
	addToDrawingList(ant)
}
