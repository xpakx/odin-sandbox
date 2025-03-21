package tower

import "core:fmt"
import rl "vendor:raylib"
import "core:math/rand"
import "core:math"
import "core:time"

WINDOW_WIDTH :: 640
WINDOW_HEIGHT :: 480
DEBUG :: true
RHYTHM :: false

CELL_SIZE :: 8

BEAT_TIME :: 1.0

timer: f32
r: u8
result: i32
temp_res: i32
input: [5]u8
inputLen: int
collision_avoidance: bool
sound: rl.Sound

Vec2i :: [2]int
Vec2f :: [2]f32
PheromoneMap :: [GRID_WIDTH][GRID_HEIGHT]PheromoneCell

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

beat_played := false

processBeat :: proc(dt: f32) {
	timer -= dt

	if !beat_played && timer < BEAT_TIME - 0.07 {
		rl.PlaySound(sound)
		beat_played = true
	}
	if timer > 0.0 {
		return
	}
	beat_played = false
	timer = BEAT_TIME + timer
	result = temp_res
	temp_res = 0
	if (result != 1) {
		inputLen = 0
	}
	if checkCommand(1, 1, 1) {
		pawnTask = .Wood
		task_changed = true
	} else if checkCommand(1, 1, 2) {
		pawnTask = .Food
		task_changed = true
	} else if checkCommand(1, 3, 1) {
		pawnTask = .NormalTower
		task_changed = true
	} else if checkCommand(1, 3, 2) {
		pawnTask = .ArcherTower
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

TOWER_SPOT :: Vec2f{500.0, 120.0}
ENEMY_SPAWN :: Vec2f{WINDOW_WIDTH - 8.0, WINDOW_HEIGHT - 8.0}
FRAME_LENGTH :: 0.1
row_list: [GRID_HEIGHT]^Ant

Animation :: struct {
	texture: rl.Texture,
	rows: int,
	columns: int,
	animation_start: int,
	animation_end: int,
}

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
    walking_animation: Animation,
    walking_res_animation: Animation,
    idle_animation: Animation,
    idle_res_animation: Animation,
}

PawnTask :: enum {
    Food,
    Wood,
    NormalTower,
    ArcherTower,
}
pawnTask: PawnTask
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

isForaging :: proc() -> bool {
	return pawnTask == .Food || pawnTask == .Wood
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

insideGrid :: proc(x: int, y: int) -> bool {
	return x >= 0 && x < GRID_WIDTH && y >= 0 && y < GRID_HEIGHT
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
			ant.dir = rand_direction()
			ant.task_len = 100.0
		} 
	} else if pawnTask == .Food && rl.Vector2Distance(ant.pos, FOOD_POS) < food_radius && !ant.carrying_food && !ant.carrying_wood {
		// food_radius -= 0.2
		ant.carrying_food = true
		ant.homing = true
		ant.dir = rand_direction()
		ant.task_len = 100.0
	} else if pawnTask == .Wood && rl.Vector2Distance(ant.pos, WOOD_POS) < wood_radius && !ant.carrying_wood && !ant.carrying_food {
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

updateOccupation :: proc(pheromones: ^PheromoneMap, x: int, y: int, value: bool) {
	if (!collision_avoidance) {
		return
	}
	if insideGrid(x, y) {
		pheromones[x][y].occupied = value
	}
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

addToDrawingList :: proc(ant: ^Ant) {
	new_cell_y := int(ant.pos.y / CELL_SIZE)
	if !(new_cell_y >= 0 && new_cell_y < GRID_HEIGHT) {
		new_cell_y = new_cell_y - 1
	}
	if row_list[new_cell_y] == nil {
		row_list[new_cell_y] = ant
	} else {
		ant.nextInRow = row_list[new_cell_y]
		row_list[new_cell_y] = ant
	}
}

update_ant :: proc(ant: ^Ant, pheromones: ^PheromoneMap, dt: f32) {
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

	new_cell_x := int(ant.pos.x / CELL_SIZE)
	new_cell_y := int(ant.pos.y / CELL_SIZE)

	updateOccupation(pheromones, new_cell_x, new_cell_y, true)
	addToDrawingList(ant)
}

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Tower")
	defer rl.CloseWindow()
	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()
	sound = rl.LoadSound("assets/drum.wav")
	defer rl.UnloadSound(sound)

	timer = BEAT_TIME
	result = 0
	temp_res = 0
	inputLen = 0
	pawnTask = .Food

	food_radius = 20.0
	wood_radius = 20.0
	collision_avoidance = true

	worker_texture := rl.LoadTexture("assets/worker.png")
	enemy_texture := rl.LoadTexture("assets/enemy_knight.png")

	walking_animation := Animation {
		texture = worker_texture,
		rows = 6,
		columns = 6,
		animation_start = 1 * 6,
		animation_end = 1 * 6 + 5,
	}

	walking_res_animation := Animation {
		texture = worker_texture,
		rows = 6,
		columns = 6,
		animation_start = 5 * 6,
		animation_end = 5 * 6 + 5,
	}

	idle_animation := Animation {
		texture = worker_texture,
		rows = 6,
		columns = 6,
		animation_start = 0 * 6,
		animation_end = 0 * 6 + 5,
	}

	idle_res_animation := Animation {
		texture = worker_texture,
		rows = 6,
		columns = 6,
		animation_start = 4 * 6,
		animation_end = 4 * 6 + 5,
	}

	enemy_walking_animation := Animation {
		texture = enemy_texture,
		rows = 8,
		columns = 6,
		animation_start = 1 * 6,
		animation_end = 1 * 6 + 5,
	}

	ants: [20]Ant
	enemy_ants: [1]Ant
	for i in 0..<20 {
		ants[i] = Ant{
			pos = HOME_POS,
			dir = rand_direction(),
			homing = false,
			carrying_food = false,
			task_len = 100.0,
			frame_timer = FRAME_LENGTH,
			animation_frame = 0,
			nextInRow = nil,
			walking_animation = walking_animation,
			walking_res_animation = walking_res_animation,
			idle_animation = idle_animation,
			idle_res_animation = idle_res_animation,
		}
	}
	for i in 0..<1 {
		enemy_ants[i] = Ant{
			pos = ENEMY_SPAWN,
			dir = rand_direction(),
			enemy = true,
			task_len = 100.0,
			frame_timer = FRAME_LENGTH,
			animation_frame = 0,
			walking_animation = enemy_walking_animation,
		}
	}

	pheromones: PheromoneMap
	for x in 0..<WINDOW_WIDTH/CELL_SIZE {
		for y in 0..<WINDOW_HEIGHT/CELL_SIZE {
			pheromones[x][y] = PheromoneCell{0, 0, 0, 0, false}
		}
	}

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()
		when RHYTHM {
			processBeat(dt)
		}
		res := checkKeyBoardInput(timer)
		if (res != 0) {
			temp_res = res
		}

		for &ant in ants {
			when RHYTHM {
				if result != 1 {
					addToDrawingList(&ant)
				} else {
					update_ant(&ant, &pheromones, dt)
				}
			} else {
				update_ant(&ant, &pheromones, dt)
			}
		}
		for &ant in enemy_ants {
			update_ant(&ant, &pheromones, dt)
		}
		task_changed = false

		decayPheromones(&pheromones, dt)

		rl.BeginDrawing()

		drawBackground(timer)
		if (DEBUG) {
			drawPheromones(&pheromones)
		}

		when RHYTHM {
			drawRhythmIndicator()
		}
		drawStructures()
		drawAnts(&row_list, dt)

		rl.EndDrawing()
	}
}

decayPheromones :: proc(pheromones: ^PheromoneMap, dt: f32) {
	if result != 1 { // ???? still not sure if that's an ideal solution
		return
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
			if (pheromones[x][y].wood < decay) {
				pheromones[x][y].wood = 0
			} else {
				pheromones[x][y].wood -= decay
			}
		}
	}
}


drawBackground :: proc(timer: f32) {
	r = 55 + u8((BEAT_TIME - timer) * 45)
	rl.ClearBackground({r, 55, 55, 255})


	rect1 := rl.Rectangle{
		5.0,
		5.0,
		f32(WINDOW_WIDTH) - 10.0,
		f32(WINDOW_HEIGHT) - 10.0
	}

	rl.DrawRectangleRec(rect1, {55, 55, 55, 255})
}


drawPheromones :: proc(pheromones: ^PheromoneMap) {
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

// TODO
drawRhythmIndicator :: proc() {
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
}

// TODO
drawStructures :: proc() {
	rl.DrawCircleV(HOME_POS, HOME_RADIUS, rl.BLUE)
	rl.DrawCircleV(FOOD_POS, food_radius, rl.GREEN)
	rl.DrawCircleV(WOOD_POS, wood_radius, rl.BROWN)
	rl.DrawCircleV(TOWER_SPOT, wood_radius, rl.GRAY)
}

drawAnts :: proc(row_list: ^[GRID_HEIGHT]^Ant, dt: f32) {
	for i in 0..<len(row_list) {
		antPtr := row_list[i]
		for antPtr != nil {
			ant := &antPtr^
			drawAnt(antPtr, dt)
			antPtr = ant.nextInRow
		}
		row_list[i] = nil
	}
}


drawAnt :: proc(antPtr: ^Ant, dt: f32) {
	ant := antPtr^
	animation := ant.walking_res_animation if ant.carrying_food || ant.carrying_wood else ant.walking_animation
	if result != 1 && !ant.enemy {
		animation = ant.idle_res_animation if ant.carrying_food || ant.carrying_wood else ant.idle_animation
	}
	ant.frame_timer -= dt
	frames := animation.animation_end - animation.animation_start + 1
	if ant.frame_timer <= 0 {
		ant.frame_timer = FRAME_LENGTH + ant.frame_timer
		ant.animation_frame = (ant.animation_frame + 1) % frames
	}
	current_frame := ant.animation_frame + animation.animation_start

	worker_width := f32(animation.texture.width)
	src_width := worker_width/f32(animation.columns)
	if ant.dir.x < 0.0 {
		src_width *= -1
	}
	worker_height := f32(animation.texture.height)
	src_x := current_frame %% animation.rows
	src_y := current_frame / animation.rows
	worker_src := rl.Rectangle {
		x = f32(src_x) * (worker_height / f32(animation.rows)), 
		y =  f32(src_y) * worker_width / f32(animation.columns),
		width = src_width,
		height = worker_height / f32(animation.rows)
	}
	middle_x := 0.5*worker_width/(2.0*f32(animation.columns))
	middle_y := 0.5*worker_height/(2.0*f32(animation.rows))
	worker_dst := rl.Rectangle {
		x = ant.pos.x - middle_x,
		y = ant.pos.y - middle_y,
		width = 0.5*worker_width / f32(animation.columns),
		height = 0.5*worker_height / f32(animation.rows)
	}
	rl.DrawTexturePro(animation.texture, worker_src, worker_dst, 0, 0, rl.WHITE)
}
