package snake

import "core:fmt"
import rl "vendor:raylib"

main :: proc() {
	fmt.println("Hello world!")
	rl.InitWindow(640, 480, "Snake")

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.EndDrawing()
	}
}
