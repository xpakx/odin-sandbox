#+feature dynamic-literals
package toweredit

import "core:fmt"
import rl "vendor:raylib"
import "core:math/rand"
import "core:math"
import "core:time"
import "core:os"
import "core:strings"
import "core:strconv"

import "../tower"

WINDOW_WIDTH :: 640
WINDOW_HEIGHT :: 480
CELL_SIZE :: 32

GRID_WIDTH :: WINDOW_WIDTH/CELL_SIZE
GRID_HEIGHT :: WINDOW_HEIGHT/CELL_SIZE

FRAME_LENGTH :: 0.1

Vec2i :: [2]int
Vec2f :: [2]f32

Cell :: struct {
	tile: ^tower.Tile,
	dirMap: u8,
}

DCell :: struct {
	building: tower.Building,
}

Layer :: struct {
	cells: [GRID_WIDTH][GRID_HEIGHT]Cell,
	elevation: [GRID_WIDTH][GRID_HEIGHT]Cell,
	buildings: [GRID_WIDTH][GRID_HEIGHT]DCell,
}

layers: [dynamic]Layer
current_layer: int

drawTile :: proc(x: int, y: int, layer: Layer, tint: bool, elevation: bool = false) {
	cell := layer.elevation[x][y] if elevation else layer.cells[x][y]
	if cell.tile == nil {
		return
	}
	tile := cell.tile
	tile_width := f32(tile.texture.width)
	src_width := tile_width/f32(tile.columns)

	tile_height := f32(tile.texture.height)
	src_height := tile_height/f32(tile.rows)

	tileCoord := toElevationTileCoord(cell) if elevation else toTileCoord(cell)
 
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
	color := rl.Color{255, 255, 255, 155} if tint else rl.WHITE
	rl.DrawTexturePro(tile.texture, tile_src, tile_dst, 0, 0, color)
}

hasTile :: proc(x: int, y: int, tile: ^tower.Tile, layer: ^Layer, elevation: bool = false) -> bool {
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

isElevated :: proc(x: int, y: int, layer: ^Layer) -> bool {
	if !onMap(x, y, layer) {
		return false
	}
	cell := layer.elevation[x][y]
	return cell.tile != nil && cell.tile.name == "elevation"
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

processNewTileForNeighbour :: proc(x: int, y: int, tile: ^tower.Tile, layer: ^Layer, maskNeigh: u8, maskSelf: u8, elevation: bool = false) -> u8 {
	if hasTile(x, y, tile, layer, elevation) {
		updateNeighbour(x, y, maskNeigh, layer, elevation)
		return maskSelf
	}
	return 0
}

addTile :: proc(x: int, y: int, tile: ^tower.Tile, layer: ^Layer, elevation: bool = false) {
	if elevation && tile.short && !isEmpty(x, y, layer) {
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

Mode :: enum {
	Tiles,
	Objects,
}

tileMode :: proc(mouse: Vec2f, tile: TileType, tileLib: ^TileLibrary) {
	if (rl.IsMouseButtonDown(.LEFT)) {
		x := int(math.floor(mouse.x/CELL_SIZE))
		y := int(math.floor(mouse.y/CELL_SIZE))
		current_tile: ^tower.Tile
		switch tile {
		case .Grass: current_tile = &tileLib.grass
		case .Sand: current_tile = &tileLib.sand
		}
		if !hasTile(x, y, current_tile, &layers[current_layer]) {
			addTile(x, y, current_tile, &layers[current_layer])
			if(current_layer > 0) {
				addTile(x, y, &tileLib.elev2, &layers[current_layer], true)
				addTile(x, y+1, &tileLib.elev, &layers[current_layer], true);
			}
		}
	}
	if (rl.IsMouseButtonDown(.RIGHT)) {
		x := int(math.floor(mouse.x/CELL_SIZE))
		y := int(math.floor(mouse.y/CELL_SIZE))
		if !hasTile(x, y, nil, &layers[current_layer]) {
			deleteTile(x, y, &layers[current_layer])
			deleteTile(x, y, &layers[current_layer], true)
			if hasTile(x, y+1, &tileLib.elev, &layers[current_layer], true) {
				deleteTile(x, y+1, &layers[current_layer], true)
			}
			if current_layer > 0 && !hasTile(x, y-1, nil, &layers[current_layer]) {
				addTile(x, y, &tileLib.elev, &layers[current_layer], true)
			}
		}
	}
}

hasObject :: proc(x: int, y: int, layer: ^Layer) -> bool {
	if !onMap(x, y, layer) {
		return false
	}
	cell := layer.buildings[x][y]
	return cell.building.pos != {0.0, 0.0}
}

objectMode :: proc(mouse: Vec2f, building: ^tower.BuildingTile) {
	if (rl.IsMouseButtonPressed(.LEFT)) {
		x := int(math.floor(mouse.x/CELL_SIZE))
		y := int(math.floor(mouse.y/CELL_SIZE))
		if onMap(x, y, &layers[current_layer]) {
			layers[current_layer].buildings[x][y].building = tower.Building {
				proto = building,
				pos = {mouse.x, mouse.y}
			}
		}
	}
	if (rl.IsMouseButtonPressed(.RIGHT)) {
		x := int(math.floor(mouse.x/CELL_SIZE))
		y := int(math.floor(mouse.y/CELL_SIZE))
		if onMap(x, y, &layers[current_layer]) {
			layers[current_layer].buildings[x][y].building.pos = {0.0, 0.0}
		}
	}
}


TileLibrary :: struct {
	grass: tower.Tile,
	sand: tower.Tile,
	elev: tower.Tile,
	elev2: tower.Tile,
}

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Tower Editor")
	defer rl.CloseWindow()

	current_layer = 0
	append(&layers, Layer {} )

	ground_texture := rl.LoadTexture("assets/ground.png")
	elev_texture := rl.LoadTexture("assets/elevation.png")
	tileLib := TileLibrary {}
	tiles: [4]tower.Tile
	tower.loadTiles(&tiles)
	tileLib.grass = tiles[0]
	tileLib.sand = tiles[1]
	tileLib.elev = tiles[2]
	tileLib.elev2 = tiles[3]
	tile: TileType = .Grass
	mode: Mode = .Tiles

	frameTimer: f32 = FRAME_LENGTH
	currFrame := 0
	waterTileSet := tower.loadTileset("assets/water.png", 1, 8)
	water := tower.createAnimation(waterTileSet, {0, 0}, {0, 8})

	shadowTileSet := tower.loadTileset("assets/shadow.png", 1, 1)
	shadow := tower.createAnimation(shadowTileSet, {0, 0}, {0, 1})

	castle := loadBuilding("assets/castle.png", "castle")

	object := &castle

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		rl.BeginDrawing()
		rl.ClearBackground({47, 171, 189, 255})

		mouse := rl.GetMousePosition()
		switch mode {
		case .Tiles:
			tileMode(mouse, tile, &tileLib)
		case .Objects:
			objectMode(mouse, object)
		}


		if rl.IsKeyPressed(.UP) {
			current_layer += 1
			if current_layer >= len(layers) {
				append(&layers, Layer {} )
			}
		} else if rl.IsKeyPressed(.DOWN) {
			current_layer = math.max(0, current_layer - 1)
		} else if rl.IsKeyPressed(.B) {
			mode = .Objects
		} else if rl.IsKeyPressed(.T) {
			mode = .Tiles
		} 

		if rl.IsKeyPressed(.ONE) {
			switch mode {
			case .Objects: 
				object = &castle
			case .Tiles: 
				tile = .Grass
			}
		} else if rl.IsKeyPressed(.TWO) {
			switch mode {
			case .Objects: 
			case .Tiles: 
				tile = .Sand
			}
		}

		if rl.IsKeyPressed(.S) {
			mapData := prepareMap(&layers)
			saveMap("assets/001.map", mapData)
		}
		if rl.IsKeyPressed(.O) {
			loadMap("assets/001.map", &layers, &tileLib)
			current_layer = 0
		}
		if rl.IsKeyPressed(.Q) {
			break;
		}


		frameTimer -= dt
		if frameTimer <= 0 {
			frameTimer = FRAME_LENGTH + frameTimer
			currFrame = (currFrame + 1) % 8
		}
		drawWater(water, &layers[0], currFrame)

		layer_num := 0
		for layer in layers {
			if layer_num > 0 {
				drawShadows(shadow, &layers[layer_num-1], &layers[layer_num])
			}
			for i in 0..<len(layer.cells) {
				for j in 0..<len(layer.cells[i]) {
					tint := layer_num > current_layer
					drawTile(i, j, layer, tint, elevation=true)
					drawTile(i, j, layer, tint)
				}
			}
			for i in 0..<len(layer.cells) {
				for j in 0..<len(layer.cells[i]) {
					drawBuilding(i, j, layer)
				}
			}
			layer_num += 1
		}


		rl.EndDrawing()
	}
}

drawWater :: proc(water: tower.Animation, layer: ^Layer, frame: int = 0) {
	for i in 0..<len(layer.cells) {
		for j in 0..<len(layer.cells[i]) {
			if !isEmpty(i, j, layer) {
				if layer.cells[i][j].dirMap != 0b1111 {
					middle_x := (1.0/6.0)*water.src_width
					middle_y := (1.0/6.0)*water.src_height
					tile_src := rl.Rectangle {
						x = f32(frame) * water.src_width, 
						y =  f32(0),
						width = water.src_width,
						height = water.src_height
					}
					tile_dst := rl.Rectangle {
						x = f32(i*CELL_SIZE) - middle_x,
						y = f32(j*CELL_SIZE) - middle_y,
						width = f32(CELL_SIZE)*3.0,
						height = f32(CELL_SIZE)*3.0,
					}
					rl.DrawTexturePro(water.texture, tile_src, tile_dst, 0, 0, rl.WHITE)

				}
			}

		}
	}
}

drawShadows :: proc(water: tower.Animation, prevLayer: ^Layer, layer: ^Layer) {
	for i in 0..<len(layer.cells) {
		for j in 0..<len(layer.cells[i]) {
			if isElevated(i, j, layer) && !isElevated(i+1, j, prevLayer)  {
				if layer.cells[i][j].dirMap != 0b1111 {
					middle_x := (1.0/6.0)*water.src_width
					middle_y := (1.0/6.0)*water.src_height
					tile_src := rl.Rectangle {
						x = f32(0) , 
						y =  f32(0),
						width = water.src_width,
						height = water.src_height
					}
					tile_dst := rl.Rectangle {
						x = f32(i*CELL_SIZE) - middle_x,
						y = f32(j*CELL_SIZE) - middle_y,
						width = f32(CELL_SIZE)*3.0,
						height = f32(CELL_SIZE)*3.0,
					}
					rl.DrawTexturePro(water.texture, tile_src, tile_dst, 0, 0, rl.WHITE)

				}
			}

		}
	}
}

drawBuilding :: proc(i: int, j: int, layer: Layer) {
	cell :=  layer.buildings[i][j]
	if cell.building.pos == {0.0, 0.0} {
		return
	}
	building := cell.building
	tower.drawBuilding(building)
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

loadMap :: proc(filepath: string, layers: ^[dynamic]Layer, tileLib: ^TileLibrary) {
	data, ok := os.read_entire_file(filepath)
	defer delete(data)
	if !ok {
		return
	}
	clear(layers)

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
			pos, _, name, ok := tower.parseLine(line)
			if !ok {
				continue
			}
			tile: ^tower.Tile
			switch name {
				case "grass": tile = &tileLib.grass
				case "sand": tile = &tileLib.sand
				case "elevation": tile = &tileLib.elev
				case "elev2": tile = &tileLib.elev2
			}
			if tile == nil {
				continue
			}
			addTile(pos.x, pos.y, tile, &layers[currentLayer], !tileMode)
		}
	}
	fmt.println("Loading")
}

loadBuilding :: proc(s: cstring, name: string) -> tower.BuildingTile {
	texture := rl.LoadTexture(s)
	return tower.BuildingTile {
		name = name,
		type = .HomeArea,
		texture = texture,
		imgWidth = f32(texture.width),
		imgHeight = f32(texture.height),
		width = f32(texture.width)/2.0,
		height = f32(texture.height)/2.0,
		radius = 10.0,
	}
}
