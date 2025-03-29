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
GRID_WIDTH :: WINDOW_WIDTH/CELL_SIZE
GRID_HEIGHT :: WINDOW_HEIGHT/CELL_SIZE

collisionAvoidance: bool
sound: rl.Sound

Vec2i :: [2]int
Vec2f :: [2]f32

HOME_RADIUS :: 20.0
foodRadius: f32
woodRadius: f32
HOME_POS :: Vec2f{500.0, 300.0}
FOOD_POS :: Vec2f{50.0, 50.0}
WOOD_POS :: Vec2f{300.0, 100.0}

TOWER_SPOT :: Vec2f{500.0, 120.0}
ENEMY_SPAWN :: Vec2f{WINDOW_WIDTH - 50.0, WINDOW_HEIGHT - 50.0}
FRAME_LENGTH :: 0.1

WORKERS :: 20
ENEMIES :: 1

BuildingType :: enum {
	HomeArea,
	WoodArea,
	FoodArea,
}

buildings: [1]Building
Buildings :: [1]Building

BuildingTile :: struct {
	name: string,
	type: BuildingType,
	texture: rl.Texture,
	imgWidth: f32,
	imgHeight: f32,
	width: f32,
	height: f32,
	radius: f32,
}

Building :: struct {
	proto: ^BuildingTile,
	pos: Vec2f,
}

randDirection :: proc() -> Vec2f {
	angle := rand.float32() * 2 * math.PI
	return Vec2f{math.cos(angle), math.sin(angle)}
}

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

	foodRadius = 20.0
	woodRadius = 20.0
	collisionAvoidance = true

	workerTileset := loadTileset("assets/worker.png", 6, 6)
	enemyTileset := loadTileset("assets/enemy_knight.png", 8, 6)

	walkingAnimation := createAnimation(workerTileset, {1, 0}, {1, 5})
	walkingResAnimation := createAnimation(workerTileset, {5, 0}, {5, 5})
	idleAnimation := createAnimation(workerTileset, {0, 0}, {0, 5})
	idleResAnimation := createAnimation(workerTileset, {4, 0}, {4, 5})

	enemyWalkingAnimation := createAnimation(enemyTileset, {1, 0}, {1, 5})

	workerAnimations := CharAnimationSet {
		walking = walkingAnimation,
		walking_res = walkingResAnimation,
		idle = idleAnimation,
		idle_res = idleResAnimation,
	}

	enemyAnimations := CharAnimationSet {
		walking = enemyWalkingAnimation,
	}

	ants: [WORKERS+ENEMIES]Ant
	for i in 0..<WORKERS {
		ants[i] = createAnt(HOME_POS, workerAnimations)
	}
	for i in 0..<ENEMIES {
		ants[WORKERS+i] = createAnt(ENEMY_SPAWN, enemyAnimations, enemy=true)
	}

	pheromones: PheromoneMap
	clearPheromones(&pheromones)

	layers: TileMap
	loadMap("assets/001.map", &layers, &tiles)

	castleTexture := rl.LoadTexture("assets/castle.png")

	castle := BuildingTile {
		name = "castle",
		type = .HomeArea,
		texture = castleTexture,
		imgWidth = f32(castleTexture.width),
		imgHeight = f32(castleTexture.height),
		width = f32(castleTexture.width)/2.0,
		height = f32(castleTexture.height)/2.0,
		radius = HOME_RADIUS,
	}
	buildings[0] = Building {
		proto = &castle,
		pos = HOME_POS,
	}

	for !rl.WindowShouldClose() {
		if rl.IsKeyPressed(.Q) {
			break;
		}
		dt := rl.GetFrameTime()

		for &ant in ants {
			updateAnt(&ant, &pheromones, &layers, dt)
		}
		task_changed = false

		decayPheromones(&pheromones, dt)

		rl.BeginDrawing()
		draw(&pheromones, &layers, &row_list, &buildings, dt)
		rl.EndDrawing()
	}
}
