package tower

import rl "vendor:raylib"

Tileset :: struct {
	texture: rl.Texture,
	rows: int,
	columns: int,
}

loadTileset :: proc(filename: cstring, rows: int, columns: int) -> Tileset {
	texture := rl.LoadTexture(filename)
	return Tileset {
		texture = texture,
		rows = rows,
		columns = columns,
	}
}
