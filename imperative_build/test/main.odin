package build

import "core:fmt"
import rl "vendor:raylib"

SCREEN_WIDTH :: 640
SCREEN_HEIGHT :: 480
GRID_SIZE :: 10

Vec2f :: [2]f32
Vec3f :: [3]f32


correction := GRID_SIZE/2 if GRID_SIZE %% 2 == 0 else (GRID_SIZE - 1)/2
size: f32 = 0.5

drawCube :: proc(x: int, y: int) {
	translX := f32(x)*size + size/2 - size*f32(correction)
	translY := f32(y)*size + size/2 - size*f32(correction)
	cubePosition := Vec3f{translX, size/2, translY}
	rl.DrawCube(cubePosition, size, size, size, {145, 128, 0, 255})
	rl.DrawCubeWires(cubePosition, size, size, size, {0, 128, 0, 255})
}

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
		if rl.IsKeyPressed(.Q) {
			break;
		}

		dt := rl.GetFrameTime()
		rl.UpdateCamera(&camera, .ORBITAL)
		rl.BeginDrawing()
		rl.ClearBackground({55, 55, 55, 255})
		rl.BeginMode3D(camera)
		drawCube(0, 0)
		drawCube(5, 5)
		drawCube(4, 4)
		drawCube(9, 9)
		drawCube(9, 0)
		drawCube(0, 9)
		rl.DrawGrid(GRID_SIZE, 0.5)
		rl.EndMode3D()
		rl.EndDrawing()
	}

}
