local Public = {}
local math_floor = math.floor
local math_log10 = math.log10

local ScenarioTable = require 'maps.wasteland.table'
local Utils = require 'maps.wasteland.utils'
local Score = require 'maps.wasteland.score'

local biters = {
    [1] = 'small-biter',
    [2] = 'medium-biter',
    [3] = 'big-biter'
}

local spitters = {
    [1] = 'small-spitter',
    [2] = 'medium-spitter',
    [3] = 'big-spitter'
}

local worms = {
    [1] = 'small-worm-turret',
    [2] = 'medium-worm-turret',
    [3] = 'big-worm-turret'
}

-- evolution max distance in tiles
local max_evolution_distance = 500
local max_pollution_big = 64
local max_pollution_medium = 16
-- max_factor < 1.0 means technology sum of weights will be greater than 1.0
-- Note: Includes also for disabled but weight configured technologies
local max_factor = 0.75

-- Tech weights mostly weighted according to offensive military power to balance towns def/off
local technology_weights = {
    ['advanced-electronics'] = 0,
    ['advanced-electronics-2'] = 0,
    ['advanced-material-processing'] = 0,
    ['advanced-material-processing-2'] = 0,
    ['advanced-oil-processing'] = 0,
    ['artillery'] = 0,
    ['artillery-shell-range-1'] = 0,
    ['artillery-shell-speed-1'] = 0,
    ['atomic-bomb'] = 0,
    ['automated-rail-transportation'] = 0,
    ['automation'] = 0,
    ['automation-2'] = 0,
    ['automation-3'] = 0,
    ['automobilism'] = 0,
    ['battery'] = 0,
    ['battery-equipment'] = 0,  -- available in outlander market
    ['battery-mk2-equipment'] = 5,
    ['belt-immunity-equipment'] = 0,
    ['braking-force-1'] = 0,
    ['braking-force-2'] = 0,
    ['braking-force-3'] = 0,
    ['braking-force-4'] = 0,
    ['braking-force-5'] = 0,
    ['braking-force-6'] = 0,
    ['braking-force-7'] = 0,
    ['chemical-science-pack'] = 0,
    ['circuit-network'] = 0,
    ['cliff-explosives'] = 0,
    ['coal-liquefaction'] = 0,
    ['concrete'] = 0,
    ['construction-robotics'] = 0,
    ['defender'] = 20,
    ['destroyer'] = 5,
    ['discharge-defense-equipment'] = 5,
    ['distractor'] = 5,
    ['effect-transmission'] = 0,
    ['effectivity-module'] = 0,
    ['effectivity-module-2'] = 0,
    ['effectivity-module-3'] = 0,
    ['electric-energy-accumulators'] = 0,
    ['electric-energy-distribution-1'] = 0,
    ['electric-energy-distribution-2'] = 0,
    ['electric-engine'] = 0,
    ['electronics'] = 0,
    ['energy-shield-equipment'] = 5,
    ['energy-shield-mk2-equipment'] = 10,
    ['energy-weapons-damage-1'] = 10,
    ['energy-weapons-damage-2'] = 10,
    ['energy-weapons-damage-3'] = 10,
    ['energy-weapons-damage-4'] = 10,
    ['energy-weapons-damage-5'] = 20,
    ['energy-weapons-damage-6'] = 20,
    ['energy-weapons-damage-7'] = 20,
    ['engine'] = 0,
    ['exoskeleton-equipment'] = 10,
    ['explosive-rocketry'] = 5,
    ['explosives'] = 5,
    ['fast-inserter'] = 0,
    ['flamethrower'] = 5,
    ['flammables'] = 5,
    ['fluid-handling'] = 0,
    ['fluid-wagon'] = 0,
    ['follower-robot-count-1'] = 20,
    ['follower-robot-count-2'] = 20,
    ['follower-robot-count-3'] = 20,
    ['follower-robot-count-4'] = 20,
    ['follower-robot-count-5'] = 20,
    ['follower-robot-count-6'] = 20,
    ['follower-robot-count-7'] = 20,
    ['fusion-reactor-equipment'] = 0,
    ['gate'] = 0,
    ['gun-turret'] = 0,
    ['heavy-armor'] = 0,-- available in outlander market
    ['inserter-capacity-bonus-1'] = 0,
    ['inserter-capacity-bonus-2'] = 0,
    ['inserter-capacity-bonus-3'] = 0,
    ['inserter-capacity-bonus-4'] = 0,
    ['inserter-capacity-bonus-5'] = 0,
    ['inserter-capacity-bonus-6'] = 0,
    ['inserter-capacity-bonus-7'] = 0,
    ['kovarex-enrichment-process'] = 0,
    ['land-mine'] = 10,
    ['landfill'] = 0,
    ['laser'] = 0,
    ['laser-shooting-speed-1'] = 10,
    ['laser-shooting-speed-2'] = 10,
    ['laser-shooting-speed-3'] = 10,
    ['laser-shooting-speed-4'] = 10,
    ['laser-shooting-speed-5'] = 20,
    ['laser-shooting-speed-6'] = 20,
    ['laser-shooting-speed-7'] = 20,
    ['laser-turret'] = 0,   -- Available in town market
    ['logistic-robotics'] = 0,
    ['logistic-science-pack'] = 10,
    ['logistic-system'] = 0,
    ['logistics'] = 0,
    ['logistics-2'] = 0,
    ['logistics-3'] = 0,
    ['low-density-structure'] = 0,
    ['lubricant'] = 0,
    ['military'] = 20,
    ['military-2'] = 20,
    ['military-3'] = 20,
    ['military-4'] = 50,
    ['military-science-pack'] = 0,
    ['mining-productivity-1'] = 0,
    ['mining-productivity-2'] = 0,
    ['mining-productivity-3'] = 0,
    ['mining-productivity-4'] = 0,
    ['modular-armor'] = 0,  -- available in outlander market
    ['modules'] = 0,
    ['night-vision-equipment'] = 0, -- available in outlander market
    ['nuclear-fuel-reprocessing'] = 0,
    ['nuclear-power'] = 0,
    ['oil-processing'] = 0,
    ['optics'] = 0,
    ['personal-laser-defense-equipment'] = 20,
    ['personal-roboport-equipment'] = 0,    -- available in outlander market
    ['personal-roboport-mk2-equipment'] = 5,
    ['physical-projectile-damage-1'] = 10,
    ['physical-projectile-damage-2'] = 10,
    ['physical-projectile-damage-3'] = 10,
    ['physical-projectile-damage-4'] = 10,
    ['physical-projectile-damage-5'] = 20,
    ['physical-projectile-damage-6'] = 20,
    ['physical-projectile-damage-7'] = 20,
    ['plastics'] = 0,
    ['power-armor'] = 20,
    ['power-armor-mk2'] = 20,
    ['production-science-pack'] = 0,
    ['productivity-module'] = 0,
    ['productivity-module-2'] = 0,
    ['productivity-module-3'] = 0,
    ['rail-signals'] = 0,
    ['railway'] = 0,
    ['refined-flammables-1'] = 5,
    ['refined-flammables-2'] = 5,
    ['refined-flammables-3'] = 5,
    ['refined-flammables-4'] = 5,
    ['refined-flammables-5'] = 10,
    ['refined-flammables-6'] = 10,
    ['refined-flammables-7'] = 10,
    ['research-speed-1'] = 0,
    ['research-speed-2'] = 0,
    ['research-speed-3'] = 0,
    ['research-speed-4'] = 0,
    ['research-speed-5'] = 0,
    ['research-speed-6'] = 0,
    ['robotics'] = 0,
    ['rocket-control-unit'] = 0,
    ['rocket-fuel'] = 0,
    ['rocket-silo'] = 50,
    ['rocketry'] = 5,
    ['solar-energy'] = 0,
    ['solar-panel-equipment'] = 0,  -- available in outlander market
    ['space-science-pack'] = 50,
    ['speed-module'] = 0,
    ['speed-module-2'] = 0,
    ['speed-module-3'] = 0,
    --['spidertron'] = 0,
    ['stack-inserter'] = 0,
    ['steel-axe'] = 0,
    ['steel-processing'] = 0,
    ['stone-wall'] = 0,
    ['stronger-explosives-1'] = 10,
    ['stronger-explosives-2'] = 10,
    ['stronger-explosives-3'] = 10,
    ['stronger-explosives-4'] = 10,
    ['stronger-explosives-5'] = 20,
    ['stronger-explosives-6'] = 20,
    ['stronger-explosives-7'] = 20,
    ['sulfur-processing'] = 0,
    ['tank'] = 50,
    ['toolbelt'] = 0,
    ['uranium-ammo'] = 50,
    ['uranium-processing'] = 0,
    ['utility-science-pack'] = 10,
    ['weapon-shooting-speed-1'] = 10,
    ['weapon-shooting-speed-2'] = 10,
    ['weapon-shooting-speed-3'] = 10,
    ['weapon-shooting-speed-4'] = 10,
    ['weapon-shooting-speed-5'] = 20,
    ['weapon-shooting-speed-6'] = 20,
    ['worker-robots-speed-1'] = 10,
    ['worker-robots-speed-2'] = 10,
    ['worker-robots-speed-3'] = 20,
    ['worker-robots-speed-4'] = 20,
    ['worker-robots-speed-5'] = 50,
    ['worker-robots-speed-6'] = 50,
    ['worker-robots-storage-1'] = 0,
    ['worker-robots-storage-2'] = 0,
    ['worker-robots-storage-3'] = 0
}

local max_weight = 0
for _, weight in pairs(technology_weights) do
    max_weight = max_weight + weight
end
max_weight = max_weight * max_factor

local function get_unit_size(evolution)
    -- returns a value 1-3 that represents the unit size

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
        return 3
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
        return 3
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
        return 3
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
        return 3
    end
    -- 90%
    if (evolution >= 0.90 and evolution < 1) then
        local r = math.random()
        if r < 0.5 then
            return 3
        end
        return 3
    end
    -- 100%
    if (evolution >= 1.0) then
        return 3
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

local function get_relative_biter_evolution(position, estimate_extra_range)
    local this = ScenarioTable.get_table()
    local relative_evolution = 0.0
    local max_d2 = max_evolution_distance * max_evolution_distance
    if estimate_extra_range then    -- This is to calculate the danger from bigger biters roaming to nearby positions
        max_d2 = max_d2 * 1.5
    end
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

function Public.get_evolution(position, estimate_extra_range)
    return get_relative_biter_evolution(position, estimate_extra_range)
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
    local big = math_floor(pollution / max_pollution_big)
    local medium = math_floor((pollution - (big * max_pollution_big)) / max_pollution_medium)
    local small = pollution - (big * max_pollution_big) - (medium * max_pollution_medium) + 1

    if entity.valid then
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
    local big = math_floor(pollution / max_pollution_big)
    local medium = math_floor((pollution - (big * max_pollution_big)) / max_pollution_medium)
    local small = pollution - (big * max_pollution_big) - (medium * max_pollution_medium) + 1

    if entity.valid then
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
    if technology == nil or technology.name == nil then
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
    local weight = technology_weights[technology.name]
    if weight == nil then
        log('WARNING: no technology_weights for ' .. technology.name)
        return
    end
    if weight == 0 then
        return
    end
    -- update the evolution values (0.0 to 1.0)
    -- max weights might be less than 1.0, to allow for evo > 1.0
    local b = weight / max_weight
    local s = weight / max_weight
    local w = weight / max_weight

    evo.biters = b + evo.biters
    evo.spitters = s + evo.spitters
    evo.worms = w + evo.worms

    game.forces[force_name].print("Researching " .. technology.name
            .. " has increased the evolution around your town to "
            .. string.format('%.1f%%', 100 * evo.worms) .. string.format(' (+%.1f%%)', 100 * w)
            .. " and increased your town score by "
            .. string.format('+%.2f', Score.score_increment_for_research(w)), Utils.scenario_color)

end

local function on_research_finished(event)
    local technology = event.research
    update_evolution(technology.force.name, technology)
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
