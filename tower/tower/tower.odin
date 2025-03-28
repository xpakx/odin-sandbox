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
TileMap :: [5][WINDOW_WIDTH/TILE_SIZE][WINDOW_HEIGHT/TILE_SIZE]Cell

ANT_SPEED :: 75.0
HOME_RADIUS :: 20.0
food_radius: f32
wood_radius: f32
HOME_POS :: Vec2f{50.0, 50.0}
FOOD_POS :: Vec2f{500.0, 400.0}
WOOD_POS :: Vec2f{300.0, 100.0}

TOWER_SPOT :: Vec2f{500.0, 120.0}
ENEMY_SPAWN :: Vec2f{WINDOW_WIDTH - 50.0, WINDOW_HEIGHT - 50.0}
FRAME_LENGTH :: 0.1
row_list: [GRID_HEIGHT]^Ant

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

PawnTask :: enum {
    Food,
    Wood,
    NormalTower,
    ArcherTower,
}
pawnTask: PawnTask
task_changed: bool

Cell :: struct {
    tile: ^Tile,
    tilePos: Vec2i,
    elevTile: ^Tile,
    elevTilePos: Vec2i,
    blocked: bool,
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

insideGrid :: proc(x: int, y: int) -> bool {
	return x >= 0 && x < GRID_WIDTH && y >= 0 && y < GRID_HEIGHT
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

update_ant :: proc(ant: ^Ant, pheromones: ^PheromoneMap, tiles: ^TileMap, dt: f32) {
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

insideTileGrid :: proc(x: int, y: int) -> bool {
	return x >= 0 && x < WINDOW_WIDTH/TILE_SIZE && y >= 0 && y < WINDOW_HEIGHT/TILE_SIZE
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

	worker_animations := CharAnimationSet {
		walking = walking_animation,
		walking_res = walking_res_animation,
		idle = idle_animation,
		idle_res = idle_res_animation,
	}

	enemy_animations := CharAnimationSet {
		walking = enemy_walking_animation,
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
			animations = worker_animations,
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
			animations = enemy_animations,
		}
	}

	pheromones: PheromoneMap
	for x in 0..<WINDOW_WIDTH/CELL_SIZE {
		for y in 0..<WINDOW_HEIGHT/CELL_SIZE {
			pheromones[x][y] = PheromoneCell{0, 0, 0, 0, false}
		}
	}

	layers: TileMap
	loadMap("assets/001.map", &layers, &tiles)

	for !rl.WindowShouldClose() {
		if rl.IsKeyPressed(.Q) {
			break;
		}
		dt := rl.GetFrameTime()

		for &ant in ants {
			update_ant(&ant, &pheromones, &layers, dt)
		}
		for &ant in enemy_ants {
			update_ant(&ant, &pheromones, &layers, dt)
		}
		task_changed = false

		decayPheromones(&pheromones, dt)

		rl.BeginDrawing()

		drawBackground()


		for layer in 0..<5 {
			for x in 0..<WINDOW_WIDTH/TILE_SIZE {
				for y in 0..<WINDOW_HEIGHT/TILE_SIZE  {
					drawTile(x, y, layers[layer][x][y], true)
					drawTile(x, y, layers[layer][x][y])
				}
			}
		}

		if (DEBUG) {
			drawPheromones(&pheromones)
		}

		drawStructures()
		drawAnts(&row_list, dt)

		rl.EndDrawing()
	}
}

drawBackground :: proc() {
	rl.ClearBackground({55, 55, 55, 255})
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
			drawAnt(ant, dt)
			antPtr = ant.nextInRow
		}
		row_list[i] = nil
	}
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

drawTile :: proc(x: int, y: int, cell: Cell, elevation: bool = false) {
	tile := cell.elevTile if elevation else cell.tile
	if tile == nil {
		return
	}
	tile_width := f32(tile.texture.width)
	src_width := tile_width/f32(tile.columns)

	tile_height := f32(tile.texture.height)
	src_height := tile_height/f32(tile.rows)

	tileCoord := cell.elevTilePos if elevation else cell.tilePos
 
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

clearLayers :: proc(layers: ^TileMap) {
	for layer in 0..<5 {
		for x in 0..<WINDOW_WIDTH/TILE_SIZE {
			for y in 0..<WINDOW_HEIGHT/TILE_SIZE  {
				layers[layer][x][y].tile = nil
			}
		}
	}
}

loadMap :: proc(filepath: string, layers: ^TileMap, tiles: ^[4]Tile) {
	data, ok := os.read_entire_file(filepath)
	defer delete(data)
	if !ok {
		return
	}
	// clearLayers(layers)

	it := string(data)
	tileMode := true;
	currentLayer := -1
	for line in strings.split_lines_iterator(&it) {
		switch line {
		case "[layer]": 
			currentLayer += 1
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
			if (tileMode) {
				layers[currentLayer][pos.x][pos.y].tile = tile
				layers[currentLayer][pos.x][pos.y].tilePos = tilePos
			} else {
				layers[currentLayer][pos.x][pos.y].elevTile = tile
				layers[currentLayer][pos.x][pos.y].elevTilePos = tilePos
			}
		}
	}
	fmt.println("Loading")
}

isBlocked :: proc(cell: Cell) -> bool {
	return cell.tile == nil || cell.blocked
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
