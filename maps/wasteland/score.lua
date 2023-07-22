local Public = {}

local GameMode = require 'maps.wasteland.game_mode'

local evo_score_factor = 50

local age_score_weights = {
    1.4, 0.6, 0.25
}
local age_score_weight = age_score_weights[GameMode.mode]

function Public.score_increment(evo_increase)
    return evo_increase * evo_score_factor
end

function Public.research_score(town_center)
    return math.min(town_center.evolution.worms * evo_score_factor, 70)
end

function Public.survival_score(town_center)
    return math.min(Public.age_h(town_center) * age_score_weight, 70)
end

function Public.age_h(town_center)
    return (game.tick - town_center.creation_tick) / 60 / 3600
end

function Public.total_score(town_center)
    return Public.research_score(town_center) + Public.survival_score(town_center)
end

function Public.survival_score(town_center)
    return math.min(Public.age_h(town_center) * age_score_weight, 70)
end

return Public
