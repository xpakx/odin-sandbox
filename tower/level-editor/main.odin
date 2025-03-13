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

	tile_x: int
	tile_y: int
	if cell.dirMap == 0b1111 {
		tile_x = 1
		tile_y = 1
	} else if cell.dirMap == 0b0001 {
		tile_x = 3
		tile_y = 0
	} else if cell.dirMap == 0b0010 {
		tile_x = 0
		tile_y = 3
	} else if cell.dirMap == 0b0011 {
		tile_x = 0
		tile_y = 0
	} else if cell.dirMap == 0b0100 {
		tile_x = 3
		tile_y = 2
	} else if cell.dirMap == 0b0101 {
		tile_x = 3
		tile_y = 1
	} else if cell.dirMap == 0b0110 {
		tile_x = 0
		tile_y = 2
	} else if cell.dirMap == 0b0111 {
		tile_x = 0
		tile_y = 1
	} else if cell.dirMap == 0b1000 {
		tile_x = 2
		tile_y = 3
	} else if cell.dirMap == 0b1001 {
		tile_x = 2
		tile_y = 0
	} else if cell.dirMap == 0b1010 {
		tile_x = 1
		tile_y = 3
	} else if cell.dirMap == 0b1011 {
		tile_x = 1
		tile_y = 0
	} else if cell.dirMap == 0b1100 {
		tile_x = 2
		tile_y = 2
	} else if cell.dirMap == 0b1101 {
		tile_x = 2
		tile_y = 1
	} else if cell.dirMap == 0b1110 {
		tile_x = 1
		tile_y = 2
	} else {
		tile_x = 3
		tile_y = 3
	}

	tile_src := rl.Rectangle {
		x = f32(tile.x + tile_x) * (tile_height / f32(tile.rows)), 
		y =  f32(tile.y + tile_y) * tile_width / f32(tile.columns),
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

updateNeighbour :: proc(x: int, y: int, dirMap: u8) {
	tiles[x][y].dirMap ~= dirMap
	
}

addTile :: proc(x: int, y: int, tile: ^Tile) {
	dirMap: u8 = 0;
	if checkNeighbour(x-1, y, tile) {
		dirMap ~= 0b1000
		updateNeighbour(x-1, y, 0b0010)
	}
	if checkNeighbour(x, y-1, tile) {
		dirMap ~= 0b0100
		updateNeighbour(x, y-1, 0b0001)
	}
	if checkNeighbour(x+1, y, tile) {
		dirMap ~= 0b0010
		updateNeighbour(x+1, y, 0b1000)
	}
	if checkNeighbour(x, y+1, tile) {
		dirMap ~= 0b0001
		updateNeighbour(x, y+1, 0b0100)
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
	grass := Tile {
		texture = ground_texture,
		rows = 4,
		columns = 10,
		x = 0,
		y = 0,
	}
	sand := Tile {
		texture = ground_texture,
		rows = 4,
		columns = 10,
		x = 5,
		y = 0,
	}
	tile := grass
	addTile(5, 5, &tile)
	addTile(5, 6, &tile)
	addTile(6, 5, &tile)
	addTile(5, 4, &tile)
	addTile(4, 5, &tile)


	addTile(8, 5, &tile)
	addTile(9, 5, &tile)
	addTile(10, 5, &tile)


	addTile(12, 5, &tile)
	addTile(12, 6, &tile)
	addTile(12, 7, &tile)


	addTile(8, 7, &tile)
	addTile(8, 8, &tile)
	addTile(8, 9, &tile)
	addTile(9, 7, &tile)
	addTile(9, 8, &tile)
	addTile(9, 9, &tile)
	addTile(10, 7, &tile)
	addTile(10, 8, &tile)
	addTile(10, 9, &tile)

	addTile(1, 1, &tile)

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		rl.BeginDrawing()
		rl.ClearBackground({55, 55, 55, 255})

		mouse := rl.GetMousePosition()
		if (rl.IsMouseButtonPressed(.LEFT)) {
			fmt.println(mouse)
			x := int(math.floor(mouse.x/CELL_SIZE))
			y := int(math.floor(mouse.y/CELL_SIZE))
			fmt.printfln("[%d, %d]", x, y)
			if !checkNeighbour(x, y, &tile) {
				addTile(x, y, &tile)
			}
		}

		for i in 0..<len(tiles) {
			for j in 0..<len(tiles[i]) {
				drawTile(i, j)
			}
		}


		rl.EndDrawing()
	}
}
