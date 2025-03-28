package tower

import rl "vendor:raylib"

Animation :: struct {
	texture: rl.Texture,
	rows: int,
	columns: int,
	animation_start: int,
	animation_end: int,
	src_width: f32,
	src_height: f32,
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

	width := f32(tileset.texture.width)
	src_width := width/f32(tileset.columns)

	height := f32(tileset.texture.height)
	src_height := height/f32(tileset.rows)

	return Animation {
		texture = tileset.texture,
		rows = tileset.rows,
		columns = tileset.columns,
		animation_start = startIndex,
		animation_end = endIndex,
		src_width = src_width,
		src_height = src_height,
	}
}

selectAnimation :: proc(ant: ^Ant) -> Animation {
	animations := ant.animations
	if ant.carrying_food || ant.carrying_wood {
		return animations.walking_res
	}
	return animations.walking
}

updateFrameTimer :: proc(ant: ^Ant, animation: Animation, dt: f32) {
	ant.frame_timer -= dt
	frames := animation.animation_end - animation.animation_start + 1
	if ant.frame_timer <= 0 {
		ant.frame_timer = FRAME_LENGTH + ant.frame_timer
		ant.animation_frame = (ant.animation_frame + 1) % frames
	}
}

getSourceRectangle :: proc(animation: Animation, frame: int, dir: Vec2f) -> rl.Rectangle {
	src_width := animation.src_width
	if dir.x < 0.0 {
		src_width *= -1
	}
	src_x := frame %% animation.rows
	src_y := frame / animation.rows
	return rl.Rectangle {
		x = f32(src_x) * animation.src_height, 
		y =  f32(src_y) * animation.src_width,
		width = src_width,
		height = animation.src_height
	}
}

getDestRectangle :: proc(pos: Vec2f, animation: Animation) -> rl.Rectangle {
	width := 0.5*animation.src_width
	height := 0.5*animation.src_height
	return rl.Rectangle {
		x = pos.x - 0.5*width,
		y = pos.y - 0.5*height,
		width = width,
		height = height
	}
}

drawAnt :: proc(ant: ^Ant, dt: f32) {
	animation := selectAnimation(ant)
	updateFrameTimer(ant, animation, dt)
	current_frame := ant.animation_frame + animation.animation_start

	worker_src := getSourceRectangle(animation, current_frame, ant.dir)
	worker_dst := getDestRectangle(ant.pos, animation)

	rl.DrawTexturePro(animation.texture, worker_src, worker_dst, 0, 0, rl.WHITE)
}
