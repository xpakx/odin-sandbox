package snake

import "core:fmt"
import rl "vendor:raylib"


CELL_SIZE :: 16
Vec2i :: [2]int

snake_pos: Vec2i

main :: proc() {
	snake_pos = { 10, 10 }

	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(640, 480, "Snake")

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground({55, 55, 55, 255})
		rect := rl.Rectangle{
			f32(snake_pos.x)*CELL_SIZE,
			f32(snake_pos.y)*CELL_SIZE,
			CELL_SIZE,
			CELL_SIZE
		}
		rl.DrawRectangleRec(rect, {70, 100, 70, 255})
		rl.EndDrawing()
	}

	rl.CloseWindow()
}
