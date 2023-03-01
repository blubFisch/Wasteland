local Public = {}
local math_floor = math.floor
local math_log10 = math.log10

local ScenarioTable = require 'maps.scrap_towny_ffa.table'
local Utils = require 'maps.scrap_towny_ffa.utils'
local Score = require 'maps.scrap_towny_ffa.score'

local biters = {
    [1] = 'small-biter',
    [2] = 'medium-biter',
    [3] = 'big-biter',
    [4] = 'behemoth-biter'
}

local spitters = {
    [1] = 'small-spitter',
    [2] = 'medium-spitter',
    [3] = 'big-spitter',
    [4] = 'behemoth-spitter'
}

local worms = {
    [1] = 'small-worm-turret',
    [2] = 'medium-worm-turret',
    [3] = 'big-worm-turret',
    [4] = 'behemoth-worm-turret'
}

-- evolution max distance in tiles
local max_evolution_distance = 700
local max_pollution_behemoth = 256
local max_pollution_big = 64
local max_pollution_medium = 16
-- max_factor < 1.0 means technology sum of weights will be greater than 1.0
local max_factor = 0.8

-- technology weights
local technology_weights = {
    ['advanced-electronics'] = 1,
    ['advanced-electronics-2'] = 1,
    ['advanced-material-processing'] = 1,
    ['advanced-material-processing-2'] = 1,
    ['advanced-oil-processing'] = 1,
    ['artillery'] = 1,
    ['artillery-shell-range-1'] = 1,
    ['artillery-shell-speed-1'] = 1,
    ['atomic-bomb'] = 1,
    ['automated-rail-transportation'] = 1,
    ['automation'] = 1,
    ['automation-2'] = 1,
    ['automation-3'] = 1,
    ['automobilism'] = 1,
    ['battery'] = 1,
    ['battery-equipment'] = 1,
    ['battery-mk2-equipment'] = 1,
    ['belt-immunity-equipment'] = 1,
    ['braking-force-1'] = 1,
    ['braking-force-2'] = 1,
    ['braking-force-3'] = 1,
    ['braking-force-4'] = 1,
    ['braking-force-5'] = 1,
    ['braking-force-6'] = 1,
    ['braking-force-7'] = 1,
    ['chemical-science-pack'] = 20,
    ['circuit-network'] = 1,
    ['cliff-explosives'] = 1,
    ['coal-liquefaction'] = 1,
    ['concrete'] = 1,
    ['construction-robotics'] = 1,
    ['defender'] = 1,
    ['destroyer'] = 1,
    ['discharge-defense-equipment'] = 5,
    ['distractor'] = 1,
    ['effect-transmission'] = 1,
    ['effectivity-module'] = 1,
    ['effectivity-module-2'] = 1,
    ['effectivity-module-3'] = 1,
    ['electric-energy-accumulators'] = 1,
    ['electric-energy-distribution-1'] = 1,
    ['electric-energy-distribution-2'] = 1,
    ['electric-engine'] = 1,
    ['electronics'] = 1,
    ['energy-shield-equipment'] = 5,
    ['energy-shield-mk2-equipment'] = 5,
    ['energy-weapons-damage-1'] = 5,
    ['energy-weapons-damage-2'] = 5,
    ['energy-weapons-damage-3'] = 5,
    ['energy-weapons-damage-4'] = 5,
    ['energy-weapons-damage-5'] = 20,
    ['energy-weapons-damage-6'] = 20,
    ['energy-weapons-damage-7'] = 20,
    ['engine'] = 1,
    ['exoskeleton-equipment'] = 5,
    ['explosive-rocketry'] = 1,
    ['explosives'] = 5,
    ['fast-inserter'] = 1,
    ['flamethrower'] = 20,
    ['flammables'] = 1,
    ['fluid-handling'] = 1,
    ['fluid-wagon'] = 1,
    ['follower-robot-count-1'] = 5,
    ['follower-robot-count-2'] = 5,
    ['follower-robot-count-3'] = 5,
    ['follower-robot-count-4'] = 5,
    ['follower-robot-count-5'] = 5,
    ['follower-robot-count-6'] = 5,
    ['follower-robot-count-7'] = 5,
    ['fusion-reactor-equipment'] = 1,
    ['gate'] = 1,
    ['gun-turret'] = 1,
    ['heavy-armor'] = 5,
    ['inserter-capacity-bonus-1'] = 1,
    ['inserter-capacity-bonus-2'] = 1,
    ['inserter-capacity-bonus-3'] = 1,
    ['inserter-capacity-bonus-4'] = 1,
    ['inserter-capacity-bonus-5'] = 1,
    ['inserter-capacity-bonus-6'] = 1,
    ['inserter-capacity-bonus-7'] = 1,
    ['kovarex-enrichment-process'] = 1,
    ['land-mine'] = 5,
    ['landfill'] = 1,
    ['laser'] = 5,
    ['laser-shooting-speed-1'] = 5,
    ['laser-shooting-speed-2'] = 5,
    ['laser-shooting-speed-3'] = 5,
    ['laser-shooting-speed-4'] = 5,
    ['laser-shooting-speed-5'] = 20,
    ['laser-shooting-speed-6'] = 20,
    ['laser-shooting-speed-7'] = 20,
    ['laser-turret'] = 20,
    ['logistic-robotics'] = 1,
    ['logistic-science-pack'] = 20,
    ['logistic-system'] = 1,
    ['logistics'] = 1,
    ['logistics-2'] = 1,
    ['logistics-3'] = 1,
    ['low-density-structure'] = 1,
    ['lubricant'] = 1,
    ['military'] = 50,
    ['military-2'] = 50,
    ['military-3'] = 50,
    ['military-4'] = 50,
    ['military-science-pack'] = 20,
    ['mining-productivity-1'] = 1,
    ['mining-productivity-2'] = 1,
    ['mining-productivity-3'] = 1,
    ['mining-productivity-4'] = 1,
    ['modular-armor'] = 10,
    ['modules'] = 1,
    ['night-vision-equipment'] = 1,
    ['nuclear-fuel-reprocessing'] = 1,
    ['nuclear-power'] = 1,
    ['oil-processing'] = 1,
    ['optics'] = 1,
    ['personal-laser-defense-equipment'] = 50,
    ['personal-roboport-equipment'] = 1,
    ['personal-roboport-mk2-equipment'] = 1,
    ['physical-projectile-damage-1'] = 5,
    ['physical-projectile-damage-2'] = 5,
    ['physical-projectile-damage-3'] = 5,
    ['physical-projectile-damage-4'] = 5,
    ['physical-projectile-damage-5'] = 20,
    ['physical-projectile-damage-6'] = 20,
    ['physical-projectile-damage-7'] = 20,
    ['plastics'] = 1,
    ['power-armor'] = 50,
    ['power-armor-mk2'] = 50,
    ['production-science-pack'] = 20,
    ['productivity-module'] = 1,
    ['productivity-module-2'] = 1,
    ['productivity-module-3'] = 1,
    ['rail-signals'] = 1,
    ['railway'] = 1,
    ['refined-flammables-1'] = 5,
    ['refined-flammables-2'] = 5,
    ['refined-flammables-3'] = 5,
    ['refined-flammables-4'] = 5,
    ['refined-flammables-5'] = 20,
    ['refined-flammables-6'] = 20,
    ['refined-flammables-7'] = 20,
    ['research-speed-1'] = 1,
    ['research-speed-2'] = 1,
    ['research-speed-3'] = 1,
    ['research-speed-4'] = 1,
    ['research-speed-5'] = 1,
    ['research-speed-6'] = 1,
    ['robotics'] = 1,
    ['rocket-control-unit'] = 1,
    ['rocket-fuel'] = 1,
    ['rocket-silo'] = 1,
    ['rocketry'] = 1,
    ['solar-energy'] = 1,
    ['solar-panel-equipment'] = 1,
    ['space-science-pack'] = 20,
    ['speed-module'] = 1,
    ['speed-module-2'] = 1,
    ['speed-module-3'] = 1,
    --['spidertron'] = 1,
    ['stack-inserter'] = 1,
    ['steel-axe'] = 1,
    ['steel-processing'] = 1,
    ['stone-wall'] = 1,
    ['stronger-explosives-1'] = 5,
    ['stronger-explosives-2'] = 5,
    ['stronger-explosives-3'] = 5,
    ['stronger-explosives-4'] = 5,
    ['stronger-explosives-5'] = 20,
    ['stronger-explosives-6'] = 20,
    ['stronger-explosives-7'] = 20,
    ['sulfur-processing'] = 1,
    ['tank'] = 50,
    ['toolbelt'] = 1,
    ['uranium-ammo'] = 50,
    ['uranium-processing'] = 1,
    ['utility-science-pack'] = 20,
    ['weapon-shooting-speed-1'] = 5,
    ['weapon-shooting-speed-2'] = 5,
    ['weapon-shooting-speed-3'] = 5,
    ['weapon-shooting-speed-4'] = 5,
    ['weapon-shooting-speed-5'] = 20,
    ['weapon-shooting-speed-6'] = 20,
    ['worker-robots-speed-1'] = 1,
    ['worker-robots-speed-2'] = 1,
    ['worker-robots-speed-3'] = 1,
    ['worker-robots-speed-4'] = 1,
    ['worker-robots-speed-5'] = 1,
    ['worker-robots-speed-6'] = 1,
    ['worker-robots-storage-1'] = 1,
    ['worker-robots-storage-2'] = 1,
    ['worker-robots-storage-3'] = 1
}

local max_weight = 0
for _, weight in pairs(technology_weights) do
    max_weight = max_weight + weight
end
max_weight = max_weight * max_factor

local function get_unit_size(evolution)
    -- returns a value 1-4 that represents the unit size

    -- basically evo values of:  0%      10%     20%     30%     40%     50%     60%     70%     80%     90%     100%
    --                           -----------------------------------------------------------------------------------
    -- small unit chances are    100%    60%     40%     30%     20%     15%     7.5%    0%      0%      0%      0%
    -- medium unit chances are   0%      40%     40%     30%     20%     15%     7.5%    12.5%   25%     0%      0%
    -- big unit chances are      0%      0%      20%     40%     60%     60%     75%     75%     50%     50%     0%
    -- behemoth unit chances are 0%      0%      0%      0%      0%      10%     10%     12.5%   25%     50%     100%
    -- and curve accordingly in between evo values

    -- magic stuff happens here
    -- 0%
    if (evolution < 0.1) then
        return 1
    end
    -- 10%
    if (evolution >= 0.1 and evolution < 0.2) then
        local r = math.random()
        if r < 0.6 then
            return 1
        end
        return 2
    end
    -- 20%
    if (evolution >= 0.2 and evolution < 0.3) then
        local r = math.random()
        if r < 0.8 then
            if r < 0.4 then
                return 1
            else
                return 2
            end
        end
        return 3
    end
    -- 30%
    if (evolution >= 0.3 and evolution < 0.4) then
        local r = math.random()
        if r < 0.6 then
            if r < 0.3 then
                return 1
            else
                return 2
            end
        end
        return 3
    end
    -- 40%
    if (evolution >= 0.4 and evolution < 0.5) then
        local r = math.random()
        if r < 0.4 then
            if r < 0.2 then
                return 1
            else
                return 2
            end
        end
        return 3
    end
    -- 50%
    if (evolution >= 0.5 and evolution < 0.6) then
        local r = math.random()
        if r < 0.9 then
            if r < 0.3 then
                if r < 0.15 then
                    return 1
                else
                    return 2
                end
            end
            return 3
        end
        return 4
    end
    -- 60%
    if (evolution >= 0.60 and evolution < 0.70) then
        local r = math.random()
        if r < 0.9 then
            if r < 0.15 then
                if r < 0.075 then
                    return 1
                else
                    return 2
                end
            end
            return 3
        end
        return 4
    end
    -- 70%
    if (evolution >= 0.70 and evolution < 0.80) then
        local r = math.random()
        if r < 0.985 then
            if r < 0.125 then
                return 2
            else
                return 3
            end
        end
        return 4
    end
    -- 80%
    if (evolution >= 0.80 and evolution < 0.90) then
        local r = math.random()
        if r < 0.75 then
            if r < 0.25 then
                return 2
            else
                return 3
            end
        end
        return 4
    end
    -- 90%
    if (evolution >= 0.90 and evolution < 1) then
        local r = math.random()
        if r < 0.5 then
            return 3
        end
        return 4
    end
    -- 100%
    if (evolution >= 1.0) then
        return 4
    end
end

local function distance_squared(pos1, pos2)
    -- calculate the distance squared
    local dx = pos1.x - pos2.x
    local dy = pos1.y - pos2.y
    local d2 = dx * dx + dy * dy
    return d2
end

-- calculate the relative evolution based on evolution factor (0.0-1.0) and distance factor (0.0-1.0)
local function calculate_relative_evolution(evolution_factor, distance_factor)
    -- distance factor will be from 0.0 to 1.0 but drop off dramatically towards zero
    local log_distance_factor = math_log10(distance_factor * 10 + 1)
    local evo = log_distance_factor * evolution_factor
    if evo < 0.0 then
        evo = 0.0
    end
    if evo > 1.0 then
        evo = 1.0
    end
    return evo
end

local function get_relative_biter_evolution(position)
    local this = ScenarioTable.get_table()
    local relative_evolution = 0.0
    local max_d2 = max_evolution_distance * max_evolution_distance
    -- for all of the teams
    local teams = this.town_centers
    for _, town_center in pairs(teams) do
        local market = town_center.market
        if market == nil or not market.valid then
            return relative_evolution
        end
        -- calculate the distance squared
        local d2 = distance_squared(position, market.position)
        if d2 < max_d2 then
            -- get the distance factor (0.0-1.0)
            local distance_factor = 1.0 - d2 / max_d2
            -- get the evolution factor (0.0-1.0)
            if not town_center.evolution then
                town_center.evolution = {}
            end
            if town_center.evolution.biters == nil then
                town_center.evolution.biters = 0.0
            end
            local evo = calculate_relative_evolution(town_center.evolution.biters, distance_factor)
            -- get the highest of the relative evolutions of each town
            relative_evolution = math.max(relative_evolution, evo)
        end
    end
    return relative_evolution
end

local function get_relative_spitter_evolution(position)
    local this = ScenarioTable.get_table()
    local relative_evolution = 0.0
    local max_d2 = max_evolution_distance * max_evolution_distance
    -- for all of the teams
    local teams = this.town_centers
    for _, town_center in pairs(teams) do
        local market = town_center.market
        if market == nil or not market.valid then
            return relative_evolution
        end
        -- calculate the distance squared
        local d2 = distance_squared(position, market.position)
        if d2 < max_d2 then
            -- get the distance factor (0.0-1.0)
            local distance_factor = 1.0 - d2 / max_d2
            -- get the evolution factor (0.0-1.0)
            if not town_center.evolution then
                town_center.evolution = {}
            end
            if town_center.evolution.spitters == nil then
                town_center.evolution.spitters = 0.0
            end
            local evo = calculate_relative_evolution(town_center.evolution.spitters, distance_factor)
            -- get the highest of the relative evolutions of each town
            relative_evolution = math.max(relative_evolution, evo)
        end
    end
    return relative_evolution
end

local function get_relative_worm_evolution(position)
    local this = ScenarioTable.get_table()
    local relative_evolution = 0.0
    local max_d2 = max_evolution_distance * max_evolution_distance
    -- for all of the teams
    local teams = this.town_centers
    for _, town_center in pairs(teams) do
        local market = town_center.market
        if market == nil or not market.valid then
            return relative_evolution
        end
        -- calculate the distance squared
        local d2 = distance_squared(position, market.position)
        if d2 < max_d2 then
            -- get the distance factor (0.0-1.0)
            local distance_factor = 1.0 - d2 / max_d2
            -- get the evolution factor (0.0-1.0)
            if not town_center.evolution then
                town_center.evolution = {}
            end
            if town_center.evolution.worms == nil then
                town_center.evolution.worms = 0.0
            end
            local evo = calculate_relative_evolution(town_center.evolution.worms, distance_factor)
            -- get the highest of the relative evolutions of each town
            relative_evolution = math.max(relative_evolution, evo)
        end
    end
    return relative_evolution
end

function Public.get_highest_evolution()
    local this = ScenarioTable.get_table()
    local max_evo = 0
    for _, town_center in pairs(this.town_centers) do
		if town_center.evolution.worms > max_evo then
			max_evo = town_center.evolution.worms
		end
    end
    return max_evo
end

function Public.get_evolution(position)
    return get_relative_biter_evolution(position)
end

function Public.get_biter_evolution(entity)
    return get_relative_biter_evolution(entity.position)
end

function Public.get_spitter_evolution(entity)
    return get_relative_spitter_evolution(entity.position)
end

function Public.get_worm_evolution(entity)
    return get_relative_worm_evolution(entity.position)
end

local function get_nearby_location(position, surface, radius, entity_name)
    return surface.find_non_colliding_position(entity_name, position, radius, 0.5, false)
end

local function set_biter_type(entity)
    -- checks nearby evolution levels for bases and returns an appropriately leveled type
    local position = entity.position
    local evo = get_relative_biter_evolution(position)
    local unit_size = get_unit_size(evo)
    local entity_name = biters[unit_size]
    if entity.name == entity_name then
        return
    end
    local surface = entity.surface
    local pollution = surface.get_pollution(position)
    local behemoth = math_floor(pollution / max_pollution_behemoth)
    local big = math_floor((pollution - (behemoth * max_pollution_behemoth)) / max_pollution_big)
    local medium = math_floor((pollution - (behemoth * max_pollution_behemoth) - (big * max_pollution_big)) / max_pollution_medium)
    local small = pollution - (behemoth * max_pollution_behemoth) - (big * max_pollution_big) - (medium * max_pollution_medium) + 1

    if entity.valid then
        for _ = 1, behemoth do
            local e = surface.create_entity({name = biters[4], position = get_nearby_location(position, surface, 5, biters[4])})
            e.copy_settings(entity)
            e.ai_settings.allow_try_return_to_spawner = true
        end
        for _ = 1, big do
            local e = surface.create_entity({name = biters[3], position = get_nearby_location(position, surface, 5, biters[3])})
            e.copy_settings(entity)
            e.ai_settings.allow_try_return_to_spawner = true
        end
        for _ = 1, medium do
            local e = surface.create_entity({name = biters[2], position = get_nearby_location(position, surface, 5, biters[2])})
            e.copy_settings(entity)
            e.ai_settings.allow_try_return_to_spawner = true
        end
        for _ = 1, small do
            local e = surface.create_entity({name = biters[1], position = get_nearby_location(position, surface, 5, biters[1])})
            e.copy_settings(entity)
            e.ai_settings.allow_try_return_to_spawner = true
        end
        local e = surface.create_entity({name = entity_name, position = get_nearby_location(position, surface, 5, entity_name)})
        e.copy_settings(entity)
        e.ai_settings.allow_try_return_to_spawner = true
        entity.destroy()
    --log("spawned " .. entity_name)
    end
end

local function set_spitter_type(entity)
    -- checks nearby evolution levels for bases and returns an appropriately leveled type
    local position = entity.position
    local evo = get_relative_spitter_evolution(position)
    local unit_size = get_unit_size(evo)
    local entity_name = spitters[unit_size]
    if entity.name == entity_name then
        return
    end
    local surface = entity.surface
    local pollution = surface.get_pollution(position)
    local behemoth = math_floor(pollution / max_pollution_behemoth)
    local big = math_floor((pollution - (behemoth * max_pollution_behemoth)) / max_pollution_big)
    local medium = math_floor((pollution - (behemoth * max_pollution_behemoth) - (big * max_pollution_big)) / max_pollution_medium)
    local small = pollution - (behemoth * max_pollution_behemoth) - (big * max_pollution_big) - (medium * max_pollution_medium) + 1

    if entity.valid then
        for _ = 1, behemoth do
            local e = surface.create_entity({name = spitters[4], position = get_nearby_location(position, surface, 5, spitters[4])})
            e.copy_settings(entity)
            e.ai_settings.allow_try_return_to_spawner = true
        end
        for _ = 1, big do
            local e = surface.create_entity({name = spitters[3], position = get_nearby_location(position, surface, 5, spitters[3])})
            e.copy_settings(entity)
            e.ai_settings.allow_try_return_to_spawner = true
        end
        for _ = 1, medium do
            local e = surface.create_entity({name = spitters[2], position = get_nearby_location(position, surface, 5, spitters[2])})
            e.copy_settings(entity)
            e.ai_settings.allow_try_return_to_spawner = true
        end
        for _ = 1, small do
            local e = surface.create_entity({name = spitters[1], position = get_nearby_location(position, surface, 5, spitters[1])})
            e.copy_settings(entity)
            e.ai_settings.allow_try_return_to_spawner = true
        end
        local e = surface.create_entity({name = entity_name, position = get_nearby_location(position, surface, 5, entity_name)})
        e.copy_settings(entity)
        e.ai_settings.allow_try_return_to_spawner = true
        entity.destroy()
    --log("spawned " .. entity_name)
    end
end

local function set_worm_type(entity)
    -- checks nearby evolution levels for bases and returns an appropriately leveled type
    local position = entity.position
    local evo = get_relative_worm_evolution(position)
    local unit_size = get_unit_size(evo)
    local entity_name = worms[unit_size]
    if entity.name == entity_name then
        return
    end
    local surface = entity.surface
    if entity.valid then
        entity.destroy()
        surface.create_entity({name = entity_name, position = position})
    --log("spawned " .. entity_name)
    end
end

local function is_biter(entity)
    if entity == nil or not entity.valid then
        return false
    end
    if entity.name == 'small-biter' or entity.name == 'medium-biter' or entity.name == 'big-biter' or entity.name == 'behemoth-biter' then
        return true
    end
    return false
end

local function is_spitter(entity)
    if entity == nil or not entity.valid then
        return false
    end
    if entity.name == 'small-spitter' or entity.name == 'medium-spitter' or entity.name == 'big-spitter' or entity.name == 'behemoth-spitter' then
        return true
    end
    return false
end

local function is_worm(entity)
    if entity == nil or not entity.valid then
        return false
    end
    if entity.name == 'small-worm-turret' or entity.name == 'medium-worm-turret' or entity.name == 'big-worm-turret' or entity.name == 'behemoth-worm-turret' then
        return true
    end
    return false
end

-- update evolution based on research completed (weighted)
-- sets the evolution to a value from 0.0 to 1.0 based on research progress
local function update_evolution(force_name, technology)
    if technology == nil then
        return
    end
    local this = ScenarioTable.get_table()
    local town_center = this.town_centers[force_name]
    -- town_center is a reference to a global table
    if not town_center then
        return
    end
    -- initialize if not already
    local evo = town_center.evolution
    -- get the weights for this technology
    local weight = technology_weights[technology]
    if weight == nil then
        log('no technology_weights for ' .. technology)
        return
    end
    -- update the evolution values (0.0 to 1.0)
    -- max weights might be less than 1.0, to allow for evo > 1.0
    local b = weight / max_weight
    local s = weight / max_weight
    local w = weight / max_weight

    game.forces[force_name].print("Research has increased the evolution around your town by "
            .. string.format('%.1f%%', 100 * w)
            .. " and increased your town score by "
            .. string.format('%.2f', Score.score_increment(w)), Utils.scenario_color)

    b = b + evo.biters
    s = s + evo.spitters
    w = w + evo.worms
    evo.biters = b
    evo.spitters = s
    evo.worms = w
end

local function on_research_finished(event)
    local research = event.research
    local force = research.force
    local technology = research.name
    update_evolution(force.name, technology)
end

local function on_entity_spawned(event)
    local entity = event.entity
    -- check the unit type and handle appropriately
    if is_biter(entity) then
        set_biter_type(entity)
    end
    if is_spitter(entity) then
        set_spitter_type(entity)
    end
    if is_worm(entity) then
        set_worm_type(entity)
    end
end

local function on_biter_base_built(event)
    local entity = event.entity
    if is_worm(entity) then
        set_worm_type(entity)
    end
end

local Event = require 'utils.event'
Event.add(defines.events.on_research_finished, on_research_finished)
Event.add(defines.events.on_entity_spawned, on_entity_spawned)
Event.add(defines.events.on_biter_base_built, on_biter_base_built)

return Public
