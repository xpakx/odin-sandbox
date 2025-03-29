package toweredit

toTileCoord :: proc(cell: Cell) -> Vec2i {
	switch cell.dirMap {
		case 0b1111: return {1, 1}
		case 0b0001: return {3, 0}
		case 0b0010: return {0, 3}
		case 0b0011: return {0, 0}
		case 0b0100: return {3, 2}
		case 0b0101: return {3, 1}
		case 0b0110: return {0, 2}
		case 0b0111: return {0, 1}
		case 0b1000: return {2, 3}
		case 0b1001: return {2, 0}
		case 0b1010: return {1, 3}
		case 0b1011: return {1, 0}
		case 0b1100: return {2, 2}
		case 0b1101: return {2, 1}
		case 0b1110: return {1, 2}
		case: return {3, 3}
	}
}

toElevationTileCoord :: proc(cell: Cell) -> Vec2i {
	if !cell.tile.short {
		tileCoord := toTileCoord(cell)
		if 0b0101 & cell.dirMap == 0 {
			tileCoord.y += 1
		}
		return tileCoord
	}
	switch cell.dirMap {
		case 0b0010: return {0, 5}
		case 0b1000: return {2, 5}
		case 0b1010: return {1, 5}
		case: return {3, 5}
	}
}
