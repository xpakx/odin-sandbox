package tower

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

loadMap :: proc(filepath: string, layers: ^TileMap, tiles: ^[4]Tile) {
	data, ok := os.read_entire_file(filepath)
	defer delete(data)
	if !ok {
		return
	}
	clearLayers(layers)

	it := string(data)
	tileMode := true;
	currentLayer := -1
	for line in strings.split_lines_iterator(&it) {
		switch line {
		case "[layer]": 
			currentLayer += 1
		case "[tiles]": 
			tileMode = true
		case "[elevation]": 
			tileMode = false
		case: 
			pos, tilePos, name, ok := parseLine(line)
			if !ok {
				continue
			}
			tile: ^Tile
			switch name {
				case "grass": tile = &tiles[0]
				case "sand": tile = &tiles[1]
				case "elevation": tile = &tiles[2]
				case "elev2": tile = &tiles[3]
			}
			if tile == nil {
				continue
			}
			if (tileMode) {
				layers[currentLayer][pos.x][pos.y].tile = tile
				layers[currentLayer][pos.x][pos.y].tilePos = tilePos
			} else {
				layers[currentLayer][pos.x][pos.y].elevTile = tile
				layers[currentLayer][pos.x][pos.y].elevTilePos = tilePos
				if (currentLayer > 0) {
					layers[currentLayer-1][pos.x][pos.y].blocked = true
				}
			}
		}
	}
	fmt.println("Loading")
}

parseLine :: proc(s: string) -> (Vec2i, Vec2i, string, bool) {
	ss := strings.split(s, " ")

	if len(ss) != 5 {
		return {0, 0}, {0, 0}, "", false
	}
	pos := Vec2i {0, 0}
	tilePos := Vec2i {0, 0}
	name := ""
	for i in 0..<5 {
		if i == 0 {
			x, ok := strconv.parse_int(ss[0])
			if !ok {
				return pos, tilePos, name, false
			}
			pos.x = x
		}
		if i == 1 {
			y, ok := strconv.parse_int(ss[1])
			if !ok {
				return pos, tilePos, name, false
			}
			pos.y = y
		}
		if i == 2 {
			x, ok := strconv.parse_int(ss[2])
			if !ok {
				return pos, tilePos, name, false
			}
			tilePos.x = x
		}
		if i == 3 {
			y, ok := strconv.parse_int(ss[3])
			if !ok {
				return pos, tilePos, name, false
			}
			tilePos.y = y
		}

		if i == 4 {
			name = ss[i]
		}
	}

	return pos, tilePos, name, true
}
