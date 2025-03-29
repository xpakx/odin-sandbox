package tower

import rl "vendor:raylib"

RowList :: [GRID_HEIGHT]^Ant
row_list: RowList

draw :: proc(pheromones: ^PheromoneMap, layers: ^TileMap, row_list: ^RowList, dt: f32) {
	drawBackground()
	drawTiles(layers)
	if (DEBUG) {
		drawPheromones(pheromones)
	}
	drawStructures()
	drawAnts(row_list, dt)
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
	rl.DrawCircleV(FOOD_POS, foodRadius, rl.GREEN)
	rl.DrawCircleV(WOOD_POS, woodRadius, rl.BROWN)
	rl.DrawCircleV(TOWER_SPOT, woodRadius, rl.GRAY)
}

drawAnts :: proc(row_list: ^RowList, dt: f32) {
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


drawTiles :: proc(layers: ^TileMap) {
	for layer in 0..<5 {
		for x in 0..<WINDOW_WIDTH/TILE_SIZE {
			for y in 0..<WINDOW_HEIGHT/TILE_SIZE  {
				drawTile(x, y, layers[layer][x][y], true)
				drawTile(x, y, layers[layer][x][y])
			}
		}
	}
}
