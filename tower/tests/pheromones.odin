package test

import "core:testing"
import "../tower"
import "core:math/rand"

createTestAnt :: proc(homing := false, enemy := false, carrying_food := false, carrying_wood := false) -> tower.Ant {
    return tower.Ant{
        homing = homing,
        enemy = enemy,
        carrying_food = carrying_food,
        carrying_wood = carrying_wood,
        pos = {0, 0},
        dir = {1, 0},
    }
}

createTestMap :: proc() -> tower.PheromoneMap {
    pheromones: tower.PheromoneMap
    pheromones[5][5] = tower.PheromoneCell{home = 5.0, food = 3.0, wood = 2.0}
    pheromones[5][6] = tower.PheromoneCell{home = 2.0, food = 8.0, wood = 1.0}
    pheromones[6][5] = tower.PheromoneCell{home = 1.0, food = 1.0, wood = 10.0, occupied = true}
    return pheromones
}

@(test)
testGetPheromoneStrength :: proc(t: ^testing.T) {
    ant := createTestAnt(homing = true)
    pheromones := createTestMap()
    
    strength := tower.getPheromoneStrength(&ant, &pheromones, 5, 5, 0, 1)
    testing.expect(t, strength == 2.0, "Should detect home pheromone strength when homing")
    
    ant.homing = false
    ant.carrying_food = true
    strength = tower.getPheromoneStrength(&ant, &pheromones, 5, 5, 0, 1)
    testing.expect(t, strength == 8.0, "Should detect food pheromone strength when foraging for food")
}
