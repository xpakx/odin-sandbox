#+feature dynamic-literals
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

Layer :: struct {
	cells: [GRID_WIDTH][GRID_HEIGHT]Cell
}

layers: [dynamic]Layer
current_layer: int

drawTile :: proc(x: int, y: int, layer: Layer) {
	cell := layer.cells[x][y]
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

checkNeighbour :: proc(x: int, y: int, tile: ^Tile, layer: ^Layer) -> bool {
	if x < 0 || x >= len(layer.cells) {
		return false
	}
	if y < 0 || y >= len(layer.cells[x]) {
		return false
	}
	cell := layer.cells[x][y]
	if cell.tile == nil {
		return false
	}
	return tile == cell.tile
}

updateNeighbour :: proc(x: int, y: int, dirMap: u8, layer: ^Layer) {
	layer.cells[x][y].dirMap ~= dirMap
	
}

addTile :: proc(x: int, y: int, tile: ^Tile, layer: ^Layer) {
	dirMap: u8 = 0;
	if checkNeighbour(x-1, y, tile, layer) {
		dirMap ~= 0b1000
		updateNeighbour(x-1, y, 0b0010, layer)
	}
	if checkNeighbour(x, y-1, tile, layer) {
		dirMap ~= 0b0100
		updateNeighbour(x, y-1, 0b0001, layer)
	}
	if checkNeighbour(x+1, y, tile, layer) {
		dirMap ~= 0b0010
		updateNeighbour(x+1, y, 0b1000, layer)
	}
	if checkNeighbour(x, y+1, tile, layer) {
		dirMap ~= 0b0001
		updateNeighbour(x, y+1, 0b0100, layer)
	}

	layer.cells[x][y] = Cell { 
		tile = tile,
		dirMap = dirMap,
	}
}

deleteTile :: proc(x: int, y: int, layer: ^Layer) {
	tile := layer.cells[x][y].tile
	dirMap: u8 = 0;
	if checkNeighbour(x-1, y, tile, layer) {
		dirMap ~= 0b1000
		updateNeighbour(x-1, y, 0b0010, layer)
	}
	if checkNeighbour(x, y-1, tile, layer) {
		dirMap ~= 0b0100
		updateNeighbour(x, y-1, 0b0001, layer)
	}
	if checkNeighbour(x+1, y, tile, layer) {
		dirMap ~= 0b0010
		updateNeighbour(x+1, y, 0b1000, layer)
	}
	if checkNeighbour(x, y+1, tile, layer) {
		dirMap ~= 0b0001
		updateNeighbour(x, y+1, 0b0100, layer)
	}

	layer.cells[x][y].tile = nil
	layer.cells[x][y].dirMap = dirMap
}

TileType :: enum {
	Grass,
	Sand,
}


main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Tower")
	defer rl.CloseWindow()

	current_layer = 0
	append(&layers, Layer {} )

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
	tile: TileType = .Grass

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		rl.BeginDrawing()
		rl.ClearBackground({55, 55, 55, 255})

		mouse := rl.GetMousePosition()
		if (rl.IsMouseButtonPressed(.LEFT)) {
			x := int(math.floor(mouse.x/CELL_SIZE))
			y := int(math.floor(mouse.y/CELL_SIZE))
			current_tile: ^Tile
			switch tile {
				case .Grass: current_tile = &grass
				case .Sand: current_tile = &sand
			}
			if !checkNeighbour(x, y, current_tile, &layers[current_layer]) {
				addTile(x, y, current_tile, &layers[current_layer])
			}
		}
		if (rl.IsMouseButtonPressed(.RIGHT)) {
			x := int(math.floor(mouse.x/CELL_SIZE))
			y := int(math.floor(mouse.y/CELL_SIZE))
			if !checkNeighbour(x, y, nil, &layers[current_layer]) {
				deleteTile(x, y, &layers[current_layer])
			}
		}
		if rl.IsKeyPressed(.UP) {
			current_layer += 1
			if current_layer >= len(layers) {
				append(&layers, Layer {} )
			}
		} else if rl.IsKeyPressed(.DOWN) {
			current_layer = math.min(0, current_layer - 1)
		} 

		if rl.IsKeyPressed(.ONE) {
			tile = .Grass
		} else if rl.IsKeyPressed(.TWO) {
			tile = .Sand
		}

		for layer in layers {
			for i in 0..<len(layer.cells) {
				for j in 0..<len(layer.cells[i]) {
					drawTile(i, j, layer)
				}
			}
		}


		rl.EndDrawing()
	}
}
