package tower

import "core:fmt"
import rl "vendor:raylib"
import "core:math/rand"
import "core:math"
import "core:time"
import "core:os"
import "core:strconv"
import "core:strings"

WINDOW_WIDTH :: 640
WINDOW_HEIGHT :: 480
DEBUG :: true

CELL_SIZE :: 8
TILE_SIZE :: 32

BEAT_TIME :: 1.0

r: u8
collision_avoidance: bool
sound: rl.Sound

Vec2i :: [2]int
Vec2f :: [2]f32
PheromoneMap :: [GRID_WIDTH][GRID_HEIGHT]PheromoneCell

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
    tile: ^Tile,
    tilePos: Vec2i,
}

Tile :: struct {
	name: string,
	short: bool,
	texture: rl.Texture,
	rows: int,
	columns: int,
	x: int,
	y: int,
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


	tiles: [4]Tile
	loadTiles(&tiles)


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
			pheromones[x][y] = PheromoneCell{0, 0, 0, 0, false, nil, {0,0}}
		}
	}

	loadMap("assets/001.map", &pheromones, &tiles)

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		for &ant in ants {
			update_ant(&ant, &pheromones, dt)
		}
		for &ant in enemy_ants {
			update_ant(&ant, &pheromones, dt)
		}
		task_changed = false

		decayPheromones(&pheromones, dt)

		rl.BeginDrawing()

		drawBackground()
		if (DEBUG) {
			drawPheromones(&pheromones)
		}

		drawStructures()
		drawAnts(&row_list, dt)

		rl.EndDrawing()
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


drawBackground :: proc() {
	rl.ClearBackground({55, 55, 55, 255})
}


drawPheromones :: proc(pheromones: ^PheromoneMap) {
	for x in 0..<GRID_WIDTH {
		for y in 0..<GRID_HEIGHT {
			drawTile(x, y, pheromones[x][y])
			if (DEBUG) {
				alpha := u8(100*(pheromones[x][y].home)/(PHEROMONE_CAPACITY))
				rl.DrawRectangle(
					i32(x*CELL_SIZE), i32(y*CELL_SIZE),
					i32(CELL_SIZE), i32(CELL_SIZE),
					rl.Color{0, 0, 255, alpha},
				)

			}
		}
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

loadTiles :: proc(tiles: ^[4]Tile) {
	ground_texture := rl.LoadTexture("assets/ground.png")
	elev_texture := rl.LoadTexture("assets/elevation.png")
	tiles[0] = Tile {
		name = "grass",
		texture = ground_texture,
		rows = 4,
		columns = 10,
		x = 0,
		y = 0,
	}
	tiles[1] = Tile {
		name = "sand",
		texture = ground_texture,
		rows = 4,
		columns = 10,
		x = 5,
		y = 0,
	}
	tiles[2] = Tile {
		name = "elevation",
		texture = elev_texture,
		rows = 8,
		columns = 4,
		x = 0,
		y = 0,
		short = true,
	}
	tiles[3] = Tile {
		name = "elev2",
		texture = elev_texture,
		rows = 8,
		columns = 4,
		x = 0,
		y = 0,
		short = false,
	}
}


drawTile :: proc(x: int, y: int, cell: PheromoneCell) {
	if cell.tile == nil {
		return
	}
	tile := cell.tile
	tile_width := f32(tile.texture.width)
	src_width := tile_width/f32(tile.columns)

	tile_height := f32(tile.texture.height)
	src_height := tile_height/f32(tile.rows)

	tileCoord := cell.tilePos
 
	tile_src := rl.Rectangle {
		x = f32(tile.x + tileCoord.x) * (tile_height / f32(tile.rows)), 
		y =  f32(tile.y + tileCoord.y) * tile_width / f32(tile.columns),
		width = src_width,
		height = src_height
	}
	tile_dst := rl.Rectangle {
		x = f32(x*TILE_SIZE),
		y = f32(y*TILE_SIZE),
		width = f32(TILE_SIZE),
		height = f32(TILE_SIZE),
	}
	rl.DrawTexturePro(tile.texture, tile_src, tile_dst, 0, 0, rl.WHITE)
}

loadMap :: proc(filepath: string, layers: ^PheromoneMap, tiles: ^[4]Tile) {
	data, ok := os.read_entire_file(filepath)
	defer delete(data)
	if !ok {
		return
	}
	// clear(layers)

	it := string(data)
	tileMode := true;
	currentLayer := -1
	for line in strings.split_lines_iterator(&it) {
		switch line {
		case "[layer]": 
			currentLayer += 1
			if currentLayer > 0 {
				return // TODO
			}
		case "[tiles]": 
			tileMode = true
		case "[elevation]": 
			tileMode = false
		case: 
			pos, tilePos, name, ok := parseLine(line)
			if !ok {
				continue
			}
			tile: ^Tile
			switch name {
				case "grass": tile = &tiles[0]
				case "sand": tile = &tiles[1]
				case "elevation": tile = &tiles[2]
				case "elev2": tile = &tiles[3]
			}
			if tile == nil {
				continue
			}
			layers[pos.x][pos.y].tile = tile
			layers[pos.x][pos.y].tilePos = tilePos
		}
	}
	fmt.println("Loading")
}

parseLine :: proc(s: string) -> (Vec2i, Vec2i, string, bool) {
	ss := strings.split(s, " ")

	if len(ss) != 5 {
		return {0, 0}, {0, 0}, "", false
	}
	pos := Vec2i {0, 0}
	tilePos := Vec2i {0, 0}
	name := ""
	for i in 0..<5 {
		if i == 0 {
			x, ok := strconv.parse_int(ss[0])
			if !ok {
				return pos, tilePos, name, false
			}
			pos.x = x
		}
		if i == 1 {
			y, ok := strconv.parse_int(ss[1])
			if !ok {
				return pos, tilePos, name, false
			}
			pos.y = y
		}
		if i == 2 {
			x, ok := strconv.parse_int(ss[2])
			if !ok {
				return pos, tilePos, name, false
			}
			tilePos.x = x
		}
		if i == 3 {
			y, ok := strconv.parse_int(ss[3])
			if !ok {
				return pos, tilePos, name, false
			}
			tilePos.y = y
		}

		if i == 4 {
			name = ss[i]
		}
	}

	return pos, tilePos, name, true
}
