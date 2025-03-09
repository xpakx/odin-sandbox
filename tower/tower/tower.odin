package tower

import "core:fmt"
import rl "vendor:raylib"
import "core:math/rand"
import "core:math"
import "core:time"


WINDOW_WIDTH :: 640
WINDOW_HEIGHT :: 480

CELL_SIZE :: 8

BEAT_TIME :: 1.0

timer: f32
r: u8
result: i32
temp_res: i32
input: [5]u8
inputLen: int

Vec2i :: [2]int
Vec2f :: [2]f32

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

PHEROMONE_DEPOSIT :: 5.0
PHEROMONE_CAPACITY :: 10.0
DECAY_FACTOR :: 0.01
ANT_SPEED :: 150.0
HOME_RADIUS :: 20.0
FOOD_RADIUS :: 20.0
HOME_POS :: Vec2f{f32(WINDOW_WIDTH)/2, f32(WINDOW_HEIGHT)/2}
FOOD_POS :: Vec2f{300.0, 100.0}

Ant :: struct {
    pos: Vec2f,
    dir: Vec2f,
    carrying_food: bool,
}

PheromoneCell :: struct {
    home: f32,
    food: f32,
}

rand_direction :: proc() -> Vec2f {
	angle := rand.float32() * 2 * math.PI
	return Vec2f{math.cos(angle), math.sin(angle)}
}

GRID_WIDTH :: WINDOW_WIDTH/CELL_SIZE
GRID_HEIGHT :: WINDOW_HEIGHT/CELL_SIZE

update_ant :: proc(ant: ^Ant, pheromones: ^[GRID_WIDTH][GRID_HEIGHT]PheromoneCell, dt: f32) {
	// Check if at home or food
	if rl.Vector2Distance(ant.pos, HOME_POS) < HOME_RADIUS {
		if ant.carrying_food {
			ant.carrying_food = false
			ant.dir = rand_direction()
		}
	} else if rl.Vector2Distance(ant.pos, FOOD_POS) < FOOD_RADIUS && !ant.carrying_food {
		ant.carrying_food = true
		ant.dir = rand_direction()
	}

	// Deposit pheromones
	cell_x := int(ant.pos.x / CELL_SIZE)
	cell_y := int(ant.pos.y / CELL_SIZE)
	if cell_x >= 0 && cell_x < GRID_WIDTH && cell_y >= 0 && cell_y < GRID_HEIGHT {
		if ant.carrying_food {
			new_var := PHEROMONE_DEPOSIT * dt
			foodPher := pheromones[cell_x][cell_y].food 
			if foodPher + new_var > PHEROMONE_CAPACITY {
				pheromones[cell_x][cell_y].food = PHEROMONE_CAPACITY
			} else {
				pheromones[cell_x][cell_y].food += new_var
			}
		} else {
			new_var := PHEROMONE_DEPOSIT * dt
			homePher := pheromones[cell_x][cell_y].home 
			if homePher + new_var > PHEROMONE_CAPACITY {
				pheromones[cell_x][cell_y].home = PHEROMONE_CAPACITY
			} else {
				pheromones[cell_x][cell_y].home += new_var
			}

		}
	}

	// Follow pheromone gradient
	current_cell_x := int(ant.pos.x / CELL_SIZE)
	current_cell_y := int(ant.pos.y / CELL_SIZE)

	max_strength: f32 = 0
	target_cell := Vec2f{0, 0}
	for dx in -1..=1 {
		for dy in -1..=1 {
			if dx == 0 && dy == 0 {
				continue
			}
			x := current_cell_x + dx
			y := current_cell_y + dy
			if x >= 0 && x < GRID_WIDTH && y >= 0 && y < GRID_HEIGHT {
				strength: f32
				if (ant.carrying_food) {
					strength = pheromones[x][y].home
				} else {
					strength = pheromones[x][y].food
				}
				if strength > max_strength || (strength == max_strength && rand.float32() > 0.5) {
					max_strength = strength
					target_cell = Vec2f{
						f32(x) * CELL_SIZE + CELL_SIZE/2,
						f32(y) * CELL_SIZE + CELL_SIZE/2,
					}
				}
			}
		}
	}

	// Update direction
	if max_strength > 0 {
		desired_dir := rl.Vector2Normalize(target_cell - ant.pos)
		ant.dir = rl.Vector2Normalize(0.7*ant.dir + 0.3*desired_dir)
	} else {
		// Random wander
		angle := rand.float32_range(-0.3, 0.3)
		ant.dir = rl.Vector2Rotate(ant.dir, angle)
	}

	// Update position
	ant.pos = ant.pos + ant.dir * ANT_SPEED * dt

	// Keep within screen bounds
	ant.pos.x = clamp(ant.pos.x, 0, WINDOW_WIDTH)
	ant.pos.y = clamp(ant.pos.y, 0, WINDOW_HEIGHT)
}

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Tower")
	timer = BEAT_TIME
	result = 0
	temp_res = 0
	inputLen = 0

	ants: [100]Ant
	for i in 0..<100 {
		ants[i] = Ant{
			pos = HOME_POS,
			dir = rand_direction(),
			carrying_food = false,
		}
	}

	pheromones: [GRID_WIDTH][GRID_HEIGHT]PheromoneCell
	for x in 0..<WINDOW_WIDTH/CELL_SIZE {
		for y in 0..<WINDOW_HEIGHT/CELL_SIZE {
			pheromones[x][y] = PheromoneCell{0, 0}
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

		for x in 0..<GRID_WIDTH {
			for y in 0..<GRID_HEIGHT {
				alpha := u8(255*(pheromones[x][y].home)/(PHEROMONE_CAPACITY))
				rl.DrawRectangle(
					i32(x*CELL_SIZE), i32(y*CELL_SIZE),
					i32(CELL_SIZE), i32(CELL_SIZE),
					rl.Color{0, 0, 255, alpha},
				)
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
		rl.DrawCircleV(FOOD_POS, FOOD_RADIUS, rl.GREEN)

		// Draw ants
		for ant in ants {
			color := rl.RED if ant.carrying_food else rl.BLACK
			rl.DrawCircleV(ant.pos, 3, color)
		}


		rl.EndDrawing()
	}

	rl.CloseWindow()
}
