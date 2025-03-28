package tower

import rl "vendor:raylib"

TILE_SIZE :: 32

TILEMAP_WIDTH :: WINDOW_WIDTH/TILE_SIZE
TILEMAP_HEIGHT :: WINDOW_HEIGHT/TILE_SIZE

TileMap :: [5][TILEMAP_WIDTH][TILEMAP_HEIGHT]Cell

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

insideTileGrid :: proc(x: int, y: int) -> bool {
	return x >= 0 && x < TILEMAP_WIDTH && y >= 0 && y < TILEMAP_HEIGHT
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

clearLayers :: proc(layers: ^TileMap) {
	for layer in 0..<5 {
		for x in 0..<WINDOW_WIDTH/TILE_SIZE {
			for y in 0..<WINDOW_HEIGHT/TILE_SIZE  {
				layers[layer][x][y].tile = nil
			}
		}
	}
}

isBlocked :: proc(cell: Cell) -> bool {
	return cell.tile == nil || cell.blocked
}
