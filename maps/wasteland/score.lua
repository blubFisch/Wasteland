local Public = {}

local age_score_factors = { 8.0, 0.8, 0.4 }
local age_score_factor = age_score_factors[global.game_mode]
local research_evo_score_factors = { 150, 65, 65 }
local research_evo_score_factor = research_evo_score_factors[global.game_mode]

function Public.score_increment_for_research(evo_increase)
    return evo_increase * research_evo_score_factor
end

function Public.research_score(town_center)
    return math.min(town_center.evolution.worms * research_evo_score_factor, 70)
end

function Public.survival_score(town_center)
    return math.min(Public.age_h(town_center) * age_score_factor, 70)
end

function Public.age_h(town_center)
    return (game.tick - town_center.creation_tick) / 60 / 3600
end

function Public.total_score(town_center)
    return Public.research_score(town_center) + Public.survival_score(town_center)
end

function Public.survival_score(town_center)
    return math.min(Public.age_h(town_center) * age_score_factor, 70)
end

return Public
