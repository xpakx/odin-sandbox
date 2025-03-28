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

r: u8
collision_avoidance: bool
sound: rl.Sound

Vec2i :: [2]int
Vec2f :: [2]f32

HOME_RADIUS :: 20.0
food_radius: f32
wood_radius: f32
HOME_POS :: Vec2f{50.0, 50.0}
FOOD_POS :: Vec2f{500.0, 400.0}
WOOD_POS :: Vec2f{300.0, 100.0}

TOWER_SPOT :: Vec2f{500.0, 120.0}
ENEMY_SPAWN :: Vec2f{WINDOW_WIDTH - 50.0, WINDOW_HEIGHT - 50.0}
FRAME_LENGTH :: 0.1

rand_direction :: proc() -> Vec2f {
	angle := rand.float32() * 2 * math.PI
	return Vec2f{math.cos(angle), math.sin(angle)}
}

GRID_WIDTH :: WINDOW_WIDTH/CELL_SIZE
GRID_HEIGHT :: WINDOW_HEIGHT/CELL_SIZE

insideGrid :: proc(x: int, y: int) -> bool {
	return x >= 0 && x < GRID_WIDTH && y >= 0 && y < GRID_HEIGHT
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

	workerTileset := loadTileset("assets/worker.png", 6, 6)
	enemyTileset := loadTileset("assets/enemy_knight.png", 8, 6)

	walkingAnimation := createAnimation(workerTileset, {1, 0}, {1, 5})
	walkingResAnimation := createAnimation(workerTileset, {5, 0}, {5, 5})
	idleAnimation := createAnimation(workerTileset, {0, 0}, {0, 5})
	idleResAnimation := createAnimation(workerTileset, {4, 0}, {4, 5})

	enemyWalkingAnimation := createAnimation(enemyTileset, {1, 0}, {1, 5})

	worker_animations := CharAnimationSet {
		walking = walkingAnimation,
		walking_res = walkingResAnimation,
		idle = idleAnimation,
		idle_res = idleResAnimation,
	}

	enemy_animations := CharAnimationSet {
		walking = enemyWalkingAnimation,
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
