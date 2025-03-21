#+feature dynamic-literals
package tower

import "core:fmt"
import rl "vendor:raylib"
import "core:math/rand"
import "core:math"
import "core:time"
import "core:os"
import "core:strings"
import "core:strconv"

WINDOW_WIDTH :: 640
WINDOW_HEIGHT :: 480
CELL_SIZE :: 32

GRID_WIDTH :: WINDOW_WIDTH/CELL_SIZE
GRID_HEIGHT :: WINDOW_HEIGHT/CELL_SIZE

Vec2i :: [2]int

Tile :: struct {
	name: string,
	short: bool,
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
	cells: [GRID_WIDTH][GRID_HEIGHT]Cell,
	elevation: [GRID_WIDTH][GRID_HEIGHT]Cell
}

layers: [dynamic]Layer
current_layer: int

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
	switch cell.dirMap {
		case 0b0010: return {0, 5}
		case 0b1000: return {2, 5}
		case 0b1010: return {1, 5}
		case: return {3, 5}
	}
}

drawTile :: proc(x: int, y: int, layer: Layer, elevation: bool = false) {
	cell := layer.elevation[x][y] if elevation else layer.cells[x][y]
	if cell.tile == nil {
		return
	}
	tile := cell.tile
	tile_width := f32(tile.texture.width)
	src_width := tile_width/f32(tile.columns)

	tile_height := f32(tile.texture.height)
	src_height := tile_height/f32(tile.rows)

	tileCoord := toElevationTileCoord(cell) if cell.tile.short else toTileCoord(cell)
 
	tile_src := rl.Rectangle {
		x = f32(tile.x + tileCoord.x) * (tile_height / f32(tile.rows)), 
		y =  f32(tile.y + tileCoord.y) * tile_width / f32(tile.columns),
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

hasTile :: proc(x: int, y: int, tile: ^Tile, layer: ^Layer, elevation: bool = false) -> bool {
	if !onMap(x, y, layer) {
		return false
	}
	cell := layer.elevation[x][y] if elevation else layer.cells[x][y]
	return tile == cell.tile
}


isEmpty :: proc(x: int, y: int, layer: ^Layer) -> bool {
	if !onMap(x, y, layer) {
		return false
	}
	cell := layer.cells[x][y]
	return nil == cell.tile
}

onMap :: proc(x: int, y: int, layer: ^Layer) -> bool {
	if x < 0 || x >= len(layer.cells) {
		return false
	}
	if y < 0 || y >= len(layer.cells[x]) {
		return false
	}
	return true
}

updateNeighbour :: proc(x: int, y: int, dirMap: u8, layer: ^Layer, elevation: bool = false) {
	if !onMap(x, y, layer) {
		return
	}
	if elevation {
		layer.elevation[x][y].dirMap ~= dirMap
	} else {
		layer.cells[x][y].dirMap ~= dirMap
	}
}

processNewTileForNeighbour :: proc(x: int, y: int, tile: ^Tile, layer: ^Layer, maskNeigh: u8, maskSelf: u8, elevation: bool = false) -> u8 {
	if hasTile(x, y, tile, layer, elevation) {
		updateNeighbour(x, y, maskNeigh, layer, elevation)
		return maskSelf
	}
	return 0
}

addTile :: proc(x: int, y: int, tile: ^Tile, layer: ^Layer, elevation: bool = false) {
	if elevation && !isEmpty(x, y, layer) {
		return
	}
	cell := &layer.elevation[x][y] if elevation else &layer.cells[x][y]
	currTile := cell.tile
	dirMap: u8 = 0;
	if currTile != nil {
		deleteTile(x, y, layer, elevation)
	}

	dirMap ~= processNewTileForNeighbour(x-1, y, tile, layer, 0b0010, 0b1000, elevation)
	dirMap ~= processNewTileForNeighbour(x+1, y, tile, layer, 0b1000, 0b0010, elevation)

	if !tile.short {
		dirMap ~= processNewTileForNeighbour(x, y+1, tile, layer, 0b0100, 0b0001, elevation)
		dirMap ~= processNewTileForNeighbour(x, y-1, tile, layer, 0b0001, 0b0100, elevation)
	}

	if elevation {
		layer.elevation[x][y] = Cell { tile = tile, dirMap = dirMap, }
	} else {
		layer.cells[x][y] = Cell { tile = tile, dirMap = dirMap, }
	}
}

deleteTile :: proc(x: int, y: int, layer: ^Layer, elevation: bool = false) {
	cell := &layer.elevation[x][y] if elevation else &layer.cells[x][y]
	tile := cell.tile
	processNewTileForNeighbour(x-1, y, tile, layer, 0b0010, 0, elevation)
	processNewTileForNeighbour(x+1, y, tile, layer, 0b1000, 0, elevation)
	if tile != nil && !tile.short {
		processNewTileForNeighbour(x, y-1, tile, layer, 0b0001, 0, elevation)
		processNewTileForNeighbour(x, y+1, tile, layer, 0b0100, 0, elevation)
	}
	cell.tile = nil
	cell.dirMap = 0b0000
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
	elev_texture := rl.LoadTexture("assets/elevation.png")
	grass := Tile {
		name = "grass",
		texture = ground_texture,
		rows = 4,
		columns = 10,
		x = 0,
		y = 0,
	}
	sand := Tile {
		name = "sand",
		texture = ground_texture,
		rows = 4,
		columns = 10,
		x = 5,
		y = 0,
	}
	elev := Tile {
		name = "elevation",
		texture = elev_texture,
		rows = 8,
		columns = 4,
		x = 0,
		y = 0,
		short = true,
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
			if !hasTile(x, y, current_tile, &layers[current_layer]) {
				addTile(x, y, current_tile, &layers[current_layer])
				if(current_layer > 0) {
					deleteTile(x, y, &layers[current_layer], true) 
					addTile(x, y+1, &elev, &layers[current_layer], true);
				}
			}
		}
		if (rl.IsMouseButtonPressed(.RIGHT)) {
			x := int(math.floor(mouse.x/CELL_SIZE))
			y := int(math.floor(mouse.y/CELL_SIZE))
			if !hasTile(x, y, nil, &layers[current_layer]) {
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

		if rl.IsKeyPressed(.S) {
			mapData := prepareMap(&layers)
			saveMap("assets/001.map", mapData)
		}
		if rl.IsKeyPressed(.O) {
			loadMap("assets/001.map", &layers, &grass, &sand, &elev, &elev2)
		}

		for layer in layers {
			for i in 0..<len(layer.cells) {
				for j in 0..<len(layer.cells[i]) {
					drawTile(i, j, layer, true)
					drawTile(i, j, layer)
				}
			}
		}


		rl.EndDrawing()
	}
}

prepareTiles :: proc(builder: ^strings.Builder, cells: [GRID_WIDTH][GRID_HEIGHT]Cell, elevation: bool = false) {
	for i in 0..<len(cells) {
		for j in 0..<len(cells[i]) {
			cell := cells[i][j]
			if cell.tile != nil {
				coord: Vec2i
				if elevation {
					coord = toElevationTileCoord(cell)
				} else {
					coord = toTileCoord(cell)
				}
				fmt.sbprintf(builder, "%d %d %d %d %s\n", i, j, coord.x, coord.y, cell.tile.name)
			}
		}
	}
}

approxLayersSize :: proc(layers: ^[dynamic]Layer) -> int {
	longest_tile_name := 9
	longest_coord_index := 3
	longest_tileset_coord_index := 3
	max_line_len := longest_tile_name + 2*(longest_coord_index+1) + 2*(longest_tileset_coord_index+1) + 1
	cells_in_layer := 2*GRID_WIDTH*GRID_HEIGHT
	headers_len := 8 + 8 + 12
	return 8 * (cells_in_layer * max_line_len * len(layers))
}

prepareMap :: proc(layers: ^[dynamic]Layer) -> string {
	builder := strings.builder_make_none()
	defer strings.builder_destroy(&builder)

	layersSize := approxLayersSize(layers)
	strings.builder_grow(&builder, layersSize)

	for layer in layers {
		strings.write_string(&builder, "[layer]\n")
		strings.write_string(&builder, "[tiles]\n")
		prepareTiles(&builder, layer.cells)
		strings.write_string(&builder, "[elevation]\n")
		prepareTiles(&builder, layer.elevation, true)
	}
	return strings.to_string(builder)
}

saveMap :: proc(filepath: string, data: string) {
	data_as_bytes := transmute([]byte)(data)
	ok := os.write_entire_file(filepath, data_as_bytes)
	if !ok {
		fmt.println("Error writing file")
	}
}

loadMap :: proc(filepath: string, layers: ^[dynamic]Layer, grass: ^Tile, sand: ^Tile, elev: ^Tile, elev2: ^Tile) {
	data, ok := os.read_entire_file(filepath)
	defer delete(data)
	if !ok {
		return
	}

	it := string(data)
	tileMode := true;
	currentLayer := -1
	for line in strings.split_lines_iterator(&it) {
		switch line {
		case "[layer]": 
			append(layers, Layer {} )
			currentLayer += 1
		case "[tiles]": 
			tileMode = true
		case "[elevation]": 
			tileMode = false
		case: 
			pos, name, ok := parseLine(line)
			if !ok {
				continue
			}
			tile: ^Tile
			switch name {
				case "grass": tile = grass
				case "sand": tile = grass
				case "elevation": tile = elev
				case "elev2": tile = elev2
			}
			if tile == nil {
				continue
			}
			addTile(pos.x, pos.y, tile, &layers[currentLayer], !tileMode)
		}
	}
	fmt.println("Loading")
}

parseLine :: proc(s: string) -> (Vec2i, string, bool) {
	ss := strings.split(s, " ")

	if len(ss) != 5 {
		return {0, 0}, "", false
	}
	pos := Vec2i {0, 0}
	name := ""
	for i in 0..<5 {
		if i == 0 {
			x, ok := strconv.parse_int(ss[0])
			if !ok {
				return pos, name, false
			}
			pos.x = x
		}
		if i == 1 {
			y, ok := strconv.parse_int(ss[1])
			if !ok {
				return pos, name, false
			}
			pos.y = y
		}
		if i == 4 {
			name = ss[i]
		}
	}

	return pos, name, true
}
