package tower

import rl "vendor:raylib"

row_list: [GRID_HEIGHT]^Ant

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
