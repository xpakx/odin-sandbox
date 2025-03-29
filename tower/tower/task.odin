package tower

PawnTask :: enum {
    Food,
    Wood,
    NormalTower,
    ArcherTower,
}
pawnTask: PawnTask
task_changed: bool

updateOccupation :: proc(pheromones: ^PheromoneMap, x: int, y: int, value: bool) {
	if (!collisionAvoidance) {
		return
	}
	if insideGrid(x, y) {
		pheromones[x][y].occupied = value
	}
}

isForaging :: proc() -> bool {
	return pawnTask == .Food || pawnTask == .Wood
}
