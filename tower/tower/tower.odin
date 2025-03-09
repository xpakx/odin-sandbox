package tower

import "core:fmt"
import rl "vendor:raylib"


WINDOW_WIDTH :: 640
WINDOW_HEIGHT :: 480

BEAT_TIME :: 0.5

timer: f32
r: u8

processBeat :: proc(dt: f32) {
	timer -= dt
	if timer > 0.0 {
		return
	}
	timer = BEAT_TIME - timer

}

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Tower")
	timer = BEAT_TIME

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()
		processBeat(dt)
		rl.BeginDrawing()
		r = 55 + u8((BEAT_TIME - timer) * 45)
		rl.ClearBackground({r, 55, 55, 255})

		rl.EndDrawing()
	}

	rl.CloseWindow()
}
