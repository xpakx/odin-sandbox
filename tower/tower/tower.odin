package tower

import "core:fmt"
import rl "vendor:raylib"


WINDOW_WIDTH :: 640
WINDOW_HEIGHT :: 480

BEAT_TIME :: 1.0

timer: f32
r: u8
result: i32
temp_res: i32

processBeat :: proc(dt: f32) {
	timer -= dt
	if timer > 0.0 {
		return
	}
	timer = BEAT_TIME + timer
	result = temp_res
	temp_res = 0

}

checkKeyBoardInput :: proc(timer: f32) -> i32 {
	action: = false
	if rl.IsKeyPressed(.UP) {
		action = true
	} else if rl.IsKeyPressed(.DOWN) {
		action = true
	} else if rl.IsKeyPressed(.LEFT) {
		action = true
	} else if rl.IsKeyPressed(.RIGHT) {
		action = true
	} 

	if !action {
		return 0
	}

	if temp_res != 0 {
		return -1
	}
	

	if timer >=  BEAT_TIME - 0.15 {
		return 1
	}
	return -1
}

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Tower")
	timer = BEAT_TIME
	result = 0
	temp_res = 0

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()
		processBeat(dt)
		res := checkKeyBoardInput(timer)
		if (res != 0) {
			temp_res = res
		}

		rl.BeginDrawing()
		r = 55 + u8((BEAT_TIME - timer) * 45)
		rl.ClearBackground({r, 55, 55, 255})

		rect1 := rl.Rectangle{
			5.0,
			5.0,
			f32(WINDOW_WIDTH) - 10.0,
			f32(WINDOW_HEIGHT) - 10.0
		}

		rl.DrawRectangleRec(rect1, {55, 55, 55, 255})

		rect := rl.Rectangle{
			100.0,
			100.0,
			16.0,
			16.0
		}

		if result == 1 {
			rl.DrawRectangleRec(rect, {70, 100, 70, 255})
		} else if result == -1 {
			rl.DrawRectangleRec(rect, {140, 70, 70, 255})
		} else {
			rl.DrawRectangleRec(rect, {140, 140, 140, 255})
		}


		rl.EndDrawing()
	}

	rl.CloseWindow()
}
