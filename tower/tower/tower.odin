package tower

import "core:fmt"
import rl "vendor:raylib"
import "core:math/rand"
import "core:math"
import "core:time"


WINDOW_WIDTH :: 640
WINDOW_HEIGHT :: 480
DEBUG :: true

CELL_SIZE :: 8

BEAT_TIME :: 1.0

timer: f32
r: u8
result: i32
temp_res: i32
input: [5]u8
inputLen: int
collision_avoidance: bool


Vec2i :: [2]int
Vec2f :: [2]f32

checkCommand :: proc(args: ..u8) -> bool {
    if inputLen != len(args) {
        return false
    }

    for i in 0..<len(args) {
        if input[i] != args[i] {
            return false
        }
    }

    return true
}

processBeat :: proc(dt: f32) {
	timer -= dt
	if timer > 0.0 {
		return
	}
	timer = BEAT_TIME + timer
	result = temp_res
	temp_res = 0
	if (result != 1) {
		inputLen = 0
	}
	if checkCommand(1, 1, 1) {
		food_task = false
		wood_task = true
		task_changed = true
	} else if checkCommand(1, 1, 2) {
		wood_task = false
		food_task = true
		task_changed = true
	}
}

checkKeyBoardInput :: proc(timer: f32) -> i32 {
	action: = false
	actionType : u8
	if rl.IsKeyPressed(.UP) {
		actionType = 1
		action = true
	} else if rl.IsKeyPressed(.DOWN) {
		actionType = 2
		action = true
	} else if rl.IsKeyPressed(.LEFT) {
		actionType = 3
		action = true
	} else if rl.IsKeyPressed(.RIGHT) {
		actionType = 4
		action = true
	} 

	if !action {
		return 0
	}

	if temp_res != 0 {
		return -1
	}
	

	if timer >=  BEAT_TIME - 0.15 {
		if inputLen >= 5 {
			inputLen = 0
		}
		input[inputLen] = actionType
		inputLen += 1
		return 1
	}
	return -1
}

PHEROMONE_CAPACITY :: 10.0
DECAY_FACTOR :: 0.1
ANT_SPEED :: 75.0
HOME_RADIUS :: 20.0
food_radius: f32
wood_radius: f32
HOME_POS :: Vec2f{50.0, 50.0}
FOOD_POS :: Vec2f{500.0, 400.0}
WOOD_POS :: Vec2f{300.0, 100.0}
ENEMY_SPAWN :: Vec2f{WINDOW_WIDTH - 8.0, WINDOW_HEIGHT - 8.0}

Ant :: struct {
    pos: Vec2f,
    dir: Vec2f,
    homing: bool,
    carrying_food: bool,
    carrying_wood: bool,
    task_len: f32,
    enemy: bool,
}

food_task: bool
wood_task: bool
task_changed: bool

PheromoneCell :: struct {
    home: f32,
    food: f32,
    wood: f32,
    enemy: f32,
    occupied: bool,
}

rand_direction :: proc() -> Vec2f {
	angle := rand.float32() * 2 * math.PI
	return Vec2f{math.cos(angle), math.sin(angle)}
}

GRID_WIDTH :: WINDOW_WIDTH/CELL_SIZE
GRID_HEIGHT :: WINDOW_HEIGHT/CELL_SIZE


depositPheromones :: proc(ant: ^Ant, pheromones: ^[GRID_WIDTH][GRID_HEIGHT]PheromoneCell, cell_x: int, cell_y: int, max_deposit: f32) {
	if cell_x >= 0 && cell_x < GRID_WIDTH && cell_y >= 0 && cell_y < GRID_HEIGHT {
		if ant.enemy {
			enemyPher := pheromones[cell_x][cell_y].enemy 
			if enemyPher < max_deposit {
				pheromones[cell_x][cell_y].enemy = max_deposit
			} 
		} else if ant.carrying_food {
			foodPher := pheromones[cell_x][cell_y].food 
			if foodPher < max_deposit {
				pheromones[cell_x][cell_y].food = max_deposit
			} 
		} else if ant.carrying_wood {
			woodPher := pheromones[cell_x][cell_y].wood 
			if woodPher < max_deposit {
				pheromones[cell_x][cell_y].wood = max_deposit
			} 
		} else if !ant.homing {
			homePher := pheromones[cell_x][cell_y].home 
			if homePher < max_deposit {
				pheromones[cell_x][cell_y].home = max_deposit
			} 

		}
	}
}

getPheromoneStrength :: proc(ant: ^Ant, pheromones: ^[GRID_WIDTH][GRID_HEIGHT]PheromoneCell, cell_x: int, cell_y: int, dx: int, dy: int) -> f32 {

	if dx == 0 && dy == 0 {
		return 0
	}
	x := cell_x + dx
	y := cell_y + dy
	if x >= 0 && x < GRID_WIDTH && y >= 0 && y < GRID_HEIGHT {
		if (collision_avoidance && pheromones[x][y].occupied) {
			return 0
		}
		if ant.enemy {
			return 0 //enemy // TODO
		} else if (ant.homing) {
			return pheromones[x][y].home
		} else if food_task {
			return pheromones[x][y].food
		} else if wood_task {
			return pheromones[x][y].wood
		}
	}
	return 0
}

updateTasks :: proc(ant: ^Ant, dt: f32) {
	// Update task length
	ant.task_len = max(ant.task_len - dt, 0.0)

	if task_changed {
		ant.homing = true
	}
	if rl.Vector2Distance(ant.pos, HOME_POS) < HOME_RADIUS {
		if ant.homing {
			ant.carrying_food = false
			ant.carrying_wood = false
			ant.homing = false
			ant.dir = rand_direction()
			ant.task_len = 100.0
		} 
	} else if food_task && rl.Vector2Distance(ant.pos, FOOD_POS) < food_radius && !ant.carrying_food && !ant.carrying_wood {
		// food_radius -= 0.2
		ant.carrying_food = true
		ant.homing = true
		ant.dir = rand_direction()
		ant.task_len = 100.0
	} else if wood_task && rl.Vector2Distance(ant.pos, WOOD_POS) < wood_radius && !ant.carrying_wood && !ant.carrying_food {
		// wood_radius -= 0.2
		ant.carrying_wood = true
		ant.homing = true
		ant.dir = rand_direction()
		ant.task_len = 100.0
	}

	if ant.task_len == 0.0 {
		ant.homing = true
	}
}


updateOccupation :: proc(pheromones: ^[GRID_WIDTH][GRID_HEIGHT]PheromoneCell, x: int, y: int, value: bool) {
	if (!collision_avoidance) {
		return
	}
	if x >= 0 && x < GRID_WIDTH && y >= 0 && y < GRID_HEIGHT {
		pheromones[x][y].occupied = value
	}
}

findNewDir :: proc(ant: ^Ant, pheromones: ^[GRID_WIDTH][GRID_HEIGHT]PheromoneCell, cell_x: int, cell_y: int) -> Vec2f {
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


update_ant :: proc(ant: ^Ant, pheromones: ^[GRID_WIDTH][GRID_HEIGHT]PheromoneCell, dt: f32) {
	// Update tasks
	if !ant.enemy {
		updateTasks(ant, dt)
	}

	current_pheromone_strength := ant.task_len/100.0
	current_pheromone_strength = math.pow(current_pheromone_strength, 2)
	max_deposit := current_pheromone_strength * PHEROMONE_CAPACITY

	// Deposit pheromones
	cell_x := int(ant.pos.x / CELL_SIZE)
	cell_y := int(ant.pos.y / CELL_SIZE)
	depositPheromones(ant, pheromones, cell_x, cell_y, max_deposit)

	// Follow pheromone gradient
	updateOccupation(pheromones, cell_x, cell_y, false)

	// Update position
	ant.dir = findNewDir(ant, pheromones, cell_x, cell_y)
	ant.pos = ant.pos + ant.dir * ANT_SPEED * dt

	// Keep within screen bounds
	ant.pos.x = clamp(ant.pos.x, 0, WINDOW_WIDTH)
	ant.pos.y = clamp(ant.pos.y, 0, WINDOW_HEIGHT)

	new_cell_x := int(ant.pos.x / CELL_SIZE)
	new_cell_y := int(ant.pos.y / CELL_SIZE)

	updateOccupation(pheromones, new_cell_x, new_cell_y, true)
}

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Tower")
	timer = BEAT_TIME
	result = 0
	temp_res = 0
	inputLen = 0
	food_task = true
	wood_task = false

	food_radius = 20.0
	wood_radius = 20.0
	collision_avoidance = true

	worker_texture := rl.LoadTexture("assets/worker.png")

	ants: [20]Ant
	enemy_ants: [1]Ant
	for i in 0..<20 {
		ants[i] = Ant{
			pos = HOME_POS,
			dir = rand_direction(),
			homing = false,
			carrying_food = false,
			task_len = 100.0,
		}
	}
	for i in 0..<1 {
		enemy_ants[i] = Ant{
			pos = ENEMY_SPAWN,
			dir = rand_direction(),
			enemy = true,
			task_len = 100.0,
		}
	}

	pheromones: [GRID_WIDTH][GRID_HEIGHT]PheromoneCell
	for x in 0..<WINDOW_WIDTH/CELL_SIZE {
		for y in 0..<WINDOW_HEIGHT/CELL_SIZE {
			pheromones[x][y] = PheromoneCell{0, 0, 0, 0, false}
		}
	}

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()
		processBeat(dt)
		res := checkKeyBoardInput(timer)
		if (res != 0) {
			temp_res = res
		}

		for &ant in ants {
			update_ant(&ant, &pheromones, dt)
		}
		for &ant in enemy_ants {
			update_ant(&ant, &pheromones, dt)
		}
		task_changed = false


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

		rl.BeginDrawing()
		r = 55 + u8((BEAT_TIME - timer) * 45)
		rl.ClearBackground({r, 55, 55, 255})


		rect1 := rl.Rectangle{
			5.0,
			5.0,
			f32(WINDOW_WIDTH) - 10.0,
			f32(WINDOW_HEIGHT) - 10.0
		}

		rl.DrawRectangleRec(rect1, {55, 55, 55, 255})

		if (DEBUG) {
			for x in 0..<GRID_WIDTH {
				for y in 0..<GRID_HEIGHT {
					alpha := u8(100*(pheromones[x][y].home)/(PHEROMONE_CAPACITY))
					rl.DrawRectangle(
						i32(x*CELL_SIZE), i32(y*CELL_SIZE),
						i32(CELL_SIZE), i32(CELL_SIZE),
						rl.Color{0, 0, 255, alpha},
					)
				}
			}
		}

		rect := rl.Rectangle{
			100.0,
			100.0,
			16.0,
			16.0
		}

		if result == 1 {
			rl.DrawRectangleRec(rect, {70, 100, 70, 255})
		} else if result == -1 {
			rl.DrawRectangleRec(rect, {140, 70, 70, 255})
		} else {
			rl.DrawRectangleRec(rect, {140, 140, 140, 255})
		}

		rl.DrawCircleV(HOME_POS, HOME_RADIUS, rl.BLUE)
		rl.DrawCircleV(FOOD_POS, food_radius, rl.GREEN)
		rl.DrawCircleV(WOOD_POS, wood_radius, rl.BROWN)

		// Draw ants
		for ant in ants {
			color := rl.BLACK
			if ant.carrying_food {
				color = rl.RED
			} else if ant.carrying_wood {
				color = rl.MAROON
			}
			worker_width := f32(worker_texture.width)
			worker_height := f32(worker_texture.height)
			worker_src := rl.Rectangle {
				x = 0, 
				y = 0,
				width = worker_width / 6.0,
				height = worker_height / 6.0
			}
			middle_x := 0.5*worker_width/12.0
			middle_y := 0.5*worker_height/12.0
			worker_dst := rl.Rectangle {
				x = ant.pos.x - middle_x,
				y = ant.pos.y - middle_y,
				width = 0.5*worker_width / 6.0,
				height = 0.5*worker_height / 6.0
			}
			rl.DrawTexturePro(worker_texture, worker_src, worker_dst, 0, 0, rl.WHITE)
		}
		for ant in enemy_ants {
			color := rl.GREEN
			rl.DrawCircleV(ant.pos, 3, color)
		}


		rl.EndDrawing()
	}

	rl.CloseWindow()
}
