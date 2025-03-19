package build

import "core:fmt"
import rl "vendor:raylib"

SCREEN_WIDTH :: 640
SCREEN_HEIGHT :: 480

Vec2f :: [2]f32

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "3D")
	defer rl.CloseWindow()
	camera := rl.Camera3D{
		position = {4, 4, 4},
		target = {0, 0, 0},
		up = {0, 1, 0},
		fovy = 60,
		projection = .PERSPECTIVE,
	}

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()
		rl.UpdateCamera(&camera, .ORBITAL)
		rl.BeginDrawing()
		rl.ClearBackground({55, 55, 55, 255})
		rl.BeginMode3D(camera)
		rl.DrawCube({0, 0, 0}, 1, 1, 1, {145, 128, 0, 255})
		rl.DrawCubeWires({0, 0, 0}, 1, 1, 1, {0, 128, 0, 255})
		rl.EndMode3D()
		rl.EndDrawing()
	}

}
