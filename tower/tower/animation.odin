package tower

import rl "vendor:raylib"

Animation :: struct {
	texture: rl.Texture,
	rows: int,
	columns: int,
	animation_start: int,
	animation_end: int,
}

CharAnimationSet :: struct {
	walking: Animation,
	idle: Animation,
	walking_res: Animation,
	idle_res: Animation,
}

createAnimation :: proc (tileset: Tileset, start: Vec2i, end: Vec2i) -> Animation {
	startIndex := start.x * tileset.columns + start.y
	endIndex := end.x * tileset.columns + end.y

	return Animation {
		texture = tileset.texture,
		rows = tileset.rows,
		columns = tileset.columns,
		animation_start = startIndex,
		animation_end = endIndex,
	}
}

drawAnt :: proc(ant: ^Ant, dt: f32) {
	animations := ant.animations
	animation := animations.walking_res if ant.carrying_food || ant.carrying_wood else animations.walking
	ant.frame_timer -= dt
	frames := animation.animation_end - animation.animation_start + 1
	if ant.frame_timer <= 0 {
		ant.frame_timer = FRAME_LENGTH + ant.frame_timer
		ant.animation_frame = (ant.animation_frame + 1) % frames
	}
	current_frame := ant.animation_frame + animation.animation_start

	worker_width := f32(animation.texture.width)
	src_width := worker_width/f32(animation.columns)
	if ant.dir.x < 0.0 {
		src_width *= -1
	}
	worker_height := f32(animation.texture.height)
	src_x := current_frame %% animation.rows
	src_y := current_frame / animation.rows
	worker_src := rl.Rectangle {
		x = f32(src_x) * (worker_height / f32(animation.rows)), 
		y =  f32(src_y) * worker_width / f32(animation.columns),
		width = src_width,
		height = worker_height / f32(animation.rows)
	}
	middle_x := 0.5*worker_width/(2.0*f32(animation.columns))
	middle_y := 0.5*worker_height/(2.0*f32(animation.rows))
	worker_dst := rl.Rectangle {
		x = ant.pos.x - middle_x,
		y = ant.pos.y - middle_y,
		width = 0.5*worker_width / f32(animation.columns),
		height = 0.5*worker_height / f32(animation.rows)
	}
	rl.DrawTexturePro(animation.texture, worker_src, worker_dst, 0, 0, rl.WHITE)
}
