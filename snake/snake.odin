#+feature dynamic-literals
package snake

import "core:fmt"
import rl "vendor:raylib"


CELL_SIZE :: 16
SPEED :: 0.15
Vec2i :: [2]int

Snake :: struct {
    segments: [dynamic]Vec2i,
    dir: Vec2i,
    timer: f32
}

advance :: proc(s: ^Snake, dt: f32) {
	s.timer -= dt
	if s.timer > 0.0 {
		return
	}
	s.timer = SPEED
	old := s.segments[0]
	s.segments[0] += snake.dir
	for i in 1..<len(s.segments) {
		cache := s.segments[i]
		s.segments[i] = old
		old = cache
	}
}

drawSnake :: proc(s: Snake) {
	for i in 0..<len(snake.segments) {
		segment := snake.segments[i]
		rect := rl.Rectangle{
			f32(segment.x)*CELL_SIZE,
			f32(segment.y)*CELL_SIZE,
			CELL_SIZE,
			CELL_SIZE
		}
		rl.DrawRectangleRec(rect, {70, 100, 70, 255})
	}
}

snake: Snake

main :: proc() {
	snake = Snake {[dynamic]Vec2i{Vec2i{10,10}}, {0,1}, SPEED}
	defer delete(snake.segments)

	append(&snake.segments, Vec2i{10,9}, Vec2i{10,8})

	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(640, 480, "Snake")

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()
		rl.BeginDrawing()
		rl.ClearBackground({55, 55, 55, 255})
		advance(&snake, dt)
		drawSnake(snake)
		rl.EndDrawing()
	}

	rl.CloseWindow()
}
