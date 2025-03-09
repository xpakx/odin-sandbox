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
    last_dir: Vec2i,
    timer: f32,
    dead: bool,
    looping: bool,
    extend: bool
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
	s.last_dir = s.dir
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
	if (s.extend) {
		append(&snake.segments, old)
		s.extend = false
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

checkKeyBoardInput :: proc(s: ^Snake) {
	new_dir: Vec2i
	if rl.IsKeyPressed(.UP) {
		new_dir = {0, -1}
	} else if rl.IsKeyPressed(.DOWN) {
		new_dir = {0, 1}
	} else if rl.IsKeyPressed(.LEFT) {
		new_dir = {-1, 0}
	} else if rl.IsKeyPressed(.RIGHT) {
		new_dir = {1, 0}
	} else {
		return
	}
	
	if new_dir + s.last_dir != {0,0} {
		s.dir = new_dir
	}
}

drawFood :: proc(food: Vec2i) {
		rect := rl.Rectangle{
			f32(food.x)*CELL_SIZE,
			f32(food.y)*CELL_SIZE,
			CELL_SIZE,
			CELL_SIZE
		}
		rl.DrawRectangleRec(rect, {140, 70, 70, 255})
}

getRandomFood :: proc(snake: Snake) -> Vec2i {
	free_fields := 40*30 - len(snake.segments)
	occupied: [40][30]bool

	for i in 1..<len(snake.segments) {
		segment := snake.segments[i]
		occupied[segment[0]][segment[1]] = true
	}

	val := rl.GetRandomValue(0, i32(free_fields))
	for x in 1..<40 {
		for y in 1..<30 {
			if (occupied[x][y]) {
				continue
			}
			if val == 0 {
				return {x, y}
			}
			val -= 1
		}
	}
	return {0, 0}
}

checkFoodCollision :: proc(snake: Snake, food: Vec2i) -> bool {
	head := snake.segments[0]
	return head == food
}


checkSnakeCollision :: proc(snake: Snake) -> bool {
	head := snake.segments[0]

	for i in 1..<len(snake.segments) {
		segment := snake.segments[i]
		if segment[0] == head[0] && segment[1] == head[1] {
			return true
		}
	}
	return false
}

snake: Snake
food: Vec2i

main :: proc() {
	snake = Snake {
		[dynamic]Vec2i{Vec2i{10,10}},
		{0,1},
		{0,1},
		SPEED,
		false,
		true,
		false
	}
	defer delete(snake.segments)
	append(&snake.segments, Vec2i{10,9}, Vec2i{10,8})
	food = getRandomFood(snake)

	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(40*CELL_SIZE, 30*CELL_SIZE, "Snake")

	for !rl.WindowShouldClose() {
		dt := rl.GetFrameTime()

		if snake.dead && rl.IsKeyPressed(.ENTER) {
			clear(&snake.segments)
			append(&snake.segments, Vec2i{10,10}, Vec2i{10,9}, Vec2i{10,8})
			snake.dir = {0, 1}
			snake.last_dir = {0, 1}
			snake.timer = SPEED
			snake.dead = false
			food = getRandomFood(snake)
		}
		checkKeyBoardInput(&snake)
		rl.BeginDrawing()
		rl.ClearBackground({55, 55, 55, 255})
		advance(&snake, dt)
		drawFood(food)
		drawSnake(snake)
		if checkFoodCollision(snake, food) {
			food = getRandomFood(snake)
			snake.extend = true
		}
		if checkSnakeCollision(snake) {
			snake.dead = true
		}
		rl.EndDrawing()
	}

	rl.CloseWindow()
}
