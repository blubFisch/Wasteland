local Public = {}

local GameSettings = require 'game_settings'

local AGE_SCORE_FACTOR = GameSettings.age_score_factor
local RESEARCH_EVO_SCORE_FACTOR = GameSettings.research_evo_score_factor

function Public.score_increment_for_research(evo_increase)
    return evo_increase * RESEARCH_EVO_SCORE_FACTOR
end

function Public.research_score(town_center)
    return math.min(town_center.evolution.worms * RESEARCH_EVO_SCORE_FACTOR, 70)
end

function Public.survival_score(town_center)
    return math.min(Public.age_h(town_center) * AGE_SCORE_FACTOR, 70)
end

function Public.age_h(town_center)
    return (game.tick - town_center.creation_tick) / 60 / 3600
end

function Public.total_score(town_center)
    return Public.research_score(town_center) + Public.survival_score(town_center)
end

function Public.survival_score(town_center)
    return math.min(Public.age_h(town_center) * AGE_SCORE_FACTOR, 70)
end

return Public
