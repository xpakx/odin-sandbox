package tower

import "core:fmt"
import rl "vendor:raylib"
import "core:math/rand"
import "core:math"
import "core:time"

WINDOW_WIDTH :: 640
WINDOW_HEIGHT :: 480
CELL_SIZE :: 16

GRID_WIDTH :: WINDOW_WIDTH/CELL_SIZE
GRID_HEIGHT :: WINDOW_HEIGHT/CELL_SIZE

Tile :: struct {
	texture: rl.Texture,
	rows: int,
	columns: int,
	x: int,
	y: int,
}

Cell :: struct {
	tile: ^Tile,
}

tiles: [GRID_WIDTH][GRID_HEIGHT]Cell

drawTile :: proc(x: int, y: int) {
	cell := tiles[x][y]
	if cell.tile == nil {
		return
	}
	tile := cell.tile
	tile_width := f32(tile.texture.width)
	src_width := tile_width/f32(tile.columns)

	tile_height := f32(tile.texture.height)
	src_height := tile_height/f32(tile.rows)

	tile_src := rl.Rectangle {
		x = f32(tile.x) * (tile_height / f32(tile.rows)), 
		y =  f32(tile.y) * tile_width / f32(tile.columns),
		width = src_width,
		height = src_height
	}
	tile_dst := rl.Rectangle {
		x = 0,
		y = 0,
		width = 0.5*src_width,
		height = 0.5*src_height
	}
	rl.DrawTexturePro(tile.texture, tile_src, tile_dst, 0, 0, rl.WHITE)
}

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Tower")
	defer rl.CloseWindow()


	ground_texture := rl.LoadTexture("assets/ground.png")
	tile := Tile {
		texture = ground_texture,
		rows = 4,
		columns = 10,
		x = 1,
		y = 1,
	}
	tiles[0][0] = Cell { &tile }

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		rl.BeginDrawing()
		rl.ClearBackground({55, 55, 55, 255})

		for i in 0..<len(tiles) {
			for j in 0..<len(tiles[i]) {
				drawTile(i, j)
			}
		}


		rl.EndDrawing()
	}
}
