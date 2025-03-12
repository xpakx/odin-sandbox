package tower

import "core:fmt"
import rl "vendor:raylib"
import "core:math/rand"
import "core:math"
import "core:time"

WINDOW_WIDTH :: 640
WINDOW_HEIGHT :: 480
CELL_SIZE :: 32

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
	dirMap: u8,
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
		x = f32(x*CELL_SIZE),
		y = f32(y*CELL_SIZE),
		width = f32(CELL_SIZE),
		height = f32(CELL_SIZE),
	}
	rl.DrawTexturePro(tile.texture, tile_src, tile_dst, 0, 0, rl.WHITE)
}

checkNeighbour :: proc(x: int, y: int, tile: ^Tile) -> bool {
	if x < 0 || x >= len(tiles) {
		return false
	}
	if y < 0 || y >= len(tiles[x]) {
		return false
	}
	cell := tiles[x][y]
	if cell.tile == nil {
		return false
	}
	return tile == cell.tile
}

addTile :: proc(x: int, y: int, tile: ^Tile) {
	dirMap: u8 = 0;
	if checkNeighbour(x-1, y, tile) {
		dirMap ~= 0b1000
	}
	if checkNeighbour(x, y-1, tile) {
		dirMap ~= 0b0100
	}
	if checkNeighbour(x+1, y, tile) {
		dirMap ~= 0b0010
	}
	if checkNeighbour(x, y+1, tile) {
		dirMap ~= 0b0001
	}

	tiles[x][y] = Cell { 
		tile = tile,
		dirMap = dirMap,
	}
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
	addTile(0, 0, &tile)
	addTile(1, 1, &tile)

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
