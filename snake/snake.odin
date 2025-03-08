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
    timer: f32,
    dead: bool,
    looping: bool
}

advance :: proc(s: ^Snake, dt: f32) {
	if s.dead {
		return
	}
	s.timer -= dt
	if s.timer > 0.0 {
		return
	}
	s.timer = SPEED
	old := s.segments[0]
	new_head := s.segments[0] + snake.dir
	if (!onScreen(new_head)) {
		if s.looping {
			new_head[0] = new_head[0] %% 40
			new_head[1] = new_head[1] %% 30
		} else {
			s.dead = true
			return
		}
	}
	s.segments[0] = new_head
	for i in 1..<len(s.segments) {
		cache := s.segments[i]
		s.segments[i] = old
		old = cache
	}
}

onScreen :: proc(pos: Vec2i) -> bool {
	if pos[0] < 0 || pos[0] >= 40 {
		return false
	}
	if pos[1] < 0 || pos[1] >= 30 {
		return false
	}
	return true
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
	snake = Snake {
		[dynamic]Vec2i{Vec2i{10,10}},
		{0,1},
		SPEED,
		false,
		false
	}
	defer delete(snake.segments)
	append(&snake.segments, Vec2i{10,9}, Vec2i{10,8})

	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(40*CELL_SIZE, 30*CELL_SIZE, "Snake")

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
