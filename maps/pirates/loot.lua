
local Math = require 'maps.pirates.math'
local Memory = require 'maps.pirates.memory'
local Balance = require 'maps.pirates.balance'
local CoreData = require 'maps.pirates.coredata'
local Common = require 'maps.pirates.common'
local inspect = require 'utils.inspect'.inspect

local Public = {}

Public.buried_treasure_loot_data_raw = {
	{100, 0, 1, false, 'coin', 1, 600},
	{50, 0, 1, false, 'steel-plate', 100, 150},
	{50, 0, 1, false, 'defender-capsule', 5, 18},
	{25, 0, 1, false, 'distractor-capsule', 5, 18},
	{10, 0, 1, false, 'destroyer-capsule', 5, 18},
	{20, 0, 1, false, 'flying-robot-frame', 20, 35},
	{40, 0, 1, false, 'construction-robot', 15, 25},
	{100, 0, 1, false, 'electronic-circuit', 150, 250},
	{70, 0, 1, false, 'advanced-circuit', 20, 40},
	{150, 0, 1, false, 'crude-oil-barrel', 25, 45},
	{70, 0, 1, false, 'effectivity-module-3', 3, 4},
	{70, 0, 1, false, 'speed-module-3', 3, 4},
	{10, 0, 1, false, 'productivity-module-3', 2, 2},
	{70, 0, 1, false, 'plastic-bar', 40, 70},
	{60, 0, 1, false, 'chemical-science-pack', 12, 24},
	{70, 0, 1, false, 'assembling-machine-3', 2, 2},
	{65, 0, 1, false, 'solar-panel', 7, 8},
	{20, 0, 1, false, 'radar', 10, 20},
	{10, 0, 1, false, 'production-science-pack', 12, 24},
	{5, 0, 1, false, 'modular-armor', 1, 1},
	{5, 0, 1, false, 'laser-turret', 1, 1},
	{5, 0, 1, false, 'cannon-shell', 5, 10},
	{50, 0, 1, false, 'artillery-shell', 4, 8},
	{50, 0, 1, false, 'express-transport-belt', 8, 20},
	{35, 0, 1, false, 'express-underground-belt', 4, 4},
	{35, 0, 1, false, 'express-splitter', 4, 11},
	{50, 0, 1, false, 'stack-inserter', 4, 12},
	{0.1, 0, 1, false, 'atomic-bomb', 1, 1},
}

Public.chest_loot_data_raw = {
	{20, -1, 0.5, true, 'splitter', 4, 12},
	-- {20, -1, 0.5, true, 'underground-belt', 4, 12},
	{40, -0.4, 0.4, true, 'firearm-magazine', 10, 40},
	{60, -1, 1, true, 'piercing-rounds-magazine', 8, 16},
	{20, 0, 1, false, 'assembling-machine-2', 1, 3},
	{20, 0, 1, false, 'solar-panel', 2, 5},
	{40, -1, 0.5, true, 'speed-module', 1, 3},
	{40, 0, 1.5, true, 'speed-module-2', 1, 2},
	{40, 0, 2, true, 'speed-module-3', 1, 1},
	{4, -1, 1, true, 'effectivity-module', 1, 3},
	{4, 0, 1, true, 'effectivity-module-2', 1, 3},
	{4, 0, 2, true, 'effectivity-module-3', 1, 3},
	{10, 0, 1, false, 'uranium-rounds-magazine', 3, 6},
	{10, 0, 1, false, 'fast-transport-belt', 6, 24},
	-- {10, 0, 1, false, 'fast-underground-belt', 2, 5},
	{10, 0, 1, false, 'fast-splitter', 2, 5},
	{12, 0, 1, false, 'artillery-shell', 1, 1},
	{40, 0, 1, false, 'rail-signal', 25, 100},
	{40, 0, 1, false, 'medium-electric-pole', 2, 5},
	{2, 0.2, 1, false, 'electric-engine-unit', 1, 1},

	{40, 0, 1, false, 'coin', 200, 400},
	{10, 0, 1, false, 'coal', 60, 100},

	{2, 0, 2, true, 'rocket-launcher', 1, 1},
	{4, 0, 2, true, 'rocket', 4, 24},

	{3, 0, 0.5, false, 'stack-inserter', 1, 4},
	{1, 0, 0.5, false, 'stack-filter-inserter', 1, 4},
	{3, 0.5, 1, false, 'stack-inserter', 5, 8},
	{1, 0.5, 1, false, 'stack-filter-inserter', 5, 8},

	-- copying over most of those i made for chronotrain:
	--always there (or normally always there):
	{4, 0, 1, false, 'pistol', 1, 2},
	{1, 0, 1, false, 'gun-turret', 2, 4},
	{6, 0, 1, false, 'grenade', 2, 12},
	{4, 0, 1, false, 'stone-wall', 12, 50},
	-- {4, 0, 1, false, 'gate', 14, 32}, --can beat biters with them
	{1, 0, 1, false, 'radar', 1, 2},
	{3, 0, 1, false, 'small-lamp', 8, 32},
	{2, 0, 1, false, 'electric-mining-drill', 2, 4},
	{3, 0, 1, false, 'long-handed-inserter', 4, 16},
	{0.5, 0, 1, false, 'filter-inserter', 2, 12},
	{0.2, 0, 1, false, 'slowdown-capsule', 2, 4},
	{0.2, 0, 1, false, 'destroyer-capsule', 2, 4},
	{0.2, 0, 1, false, 'defender-capsule', 2, 4},
	{0.2, 0, 1, false, 'distractor-capsule', 2, 4},
	-- {0.25, 0, 1, false, 'rail', 50, 100},
	-- {0.25, 0, 1, false, 'uranium-rounds-magazine', 1, 4},
	{1, 0.15, 1, false, 'pump', 1, 2},
	{2, 0.15, 1, false, 'pumpjack', 1, 3},
	{0.02, 0.15, 1, false, 'oil-refinery', 1, 2},
	{3, 0, 1, false, 'effectivity-module', 1, 4},
	{3, 0, 1, false, 'speed-module', 1, 4},
	{3, 0, 1, false, 'productivity-module', 1, 4},
	--shotgun meta:
	{10, -0.2, 0.4, true, 'shotgun-shell', 12, 24},
	{5, 0, 0.4, true, 'shotgun', 1, 1},
	{3, 0.4, 1.2, true, 'piercing-shotgun-shell', 4, 9},
	{2, 0.4, 1.2, true, 'combat-shotgun', 1, 1},
	--modular armor meta:
	{0.07, 0.25, 1.75, true, 'modular-armor', 1, 1},
	{0.04, 0.5, 1.5, true, 'power-armor', 1, 1},
	-- {0.5, -1,3, true, "power-armor-mk2", 1, 1},
	{0.3, 0.1, 1, true, 'solar-panel-equipment', 1, 2},
	{0.2, 0.1, 1, true, 'battery-equipment', 1, 1},
	{0.16, 0.2, 1, true, 'energy-shield-equipment', 1, 2},
	{0.08, 0.1, 1, true, 'night-vision-equipment', 1, 1},
	{0.04, 0.5, 1.5, true, 'personal-laser-defense-equipment', 1, 1},
	--loader meta:
	{0.5, 0, 0.1, false, 'loader', 1, 2},
	{0.5, 0.1, 0.5, false, 'fast-loader', 1, 2},
	{0.5, 0.5, 1, false, 'express-loader', 1, 2},
	--science meta:
	{8, -0.5, 0.5, true, 'automation-science-pack', 4, 32},
	{8, -0.6, 0.6, true, 'logistic-science-pack', 4, 32},
	{6, -0.1, 1, true, 'military-science-pack', 8, 32},
	{6, -0.5, 1.5, true, 'chemical-science-pack', 8, 24},
	{6, 0, 1.5, true, 'production-science-pack', 8, 24},
	-- {4, 0.4, 1.5, true, 'utility-science-pack', 16, 32},
	-- {10, 0.5, 1.5, true, 'space-science-pack', 16, 32},

	--early-game:
	--{3, -0.1, 0.2, false, "railgun-dart", 2, 4},
	-- {3, -0.1, 0.1, true, 'wooden-chest', 8, 40},
	{5, -0.1, 0.1, true, 'burner-inserter', 8, 20},
	{1, -0.2, 0.2, true, 'offshore-pump', 1, 3},
	{3, -0.2, 0.2, true, 'boiler', 3, 6},
	{3, 0, 0.1, true, 'lab', 1, 3},
	{3, -0.2, 0.2, true, 'steam-engine', 2, 4},
	-- {3, -0.2, 0.2, true, 'burner-mining-drill', 2, 4},
	{2, 0, 0.1, false, 'submachine-gun', 1, 1},
	{3, 0, 0.3, true, 'iron-chest', 8, 40},
	{4, 0, 0.1, false, 'light-armor', 1, 1},
	{4, -0.3, 0.3, true, 'inserter', 8, 16},
	{8, -0.3, 0.3, true, 'small-electric-pole', 16, 30},
	{6, -0.4, 0.4, true, 'stone-furnace', 8, 16},
	-- {1, -0.3, 0.3, true, 'underground-belt', 3, 10},
	{1, -0.3, 0.3, true, 'splitter', 1, 5},
	{1, -0.3, 0.3, true, 'assembling-machine-1', 2, 4},
	{5, -0.8, 0.8, true, 'transport-belt', 15, 80},
	--mid-game:
	--{6, 0.2, 0.5, false, "railgun-dart", 4, 8},
	{5, -0.2, 0.7, true, 'pipe', 30, 50},
	{1, -0.2, 0.7, true, 'pipe-to-ground', 4, 8},
	{5, -0.2, 0.7, true, 'iron-gear-wheel', 20, 80},
	{5, -0.2, 0.7, true, 'copper-cable', 30, 100},
	{5, -0.2, 0.7, true, 'electronic-circuit', 20, 60},
	{4, -0.1, 0.8, true, 'fast-transport-belt', 10, 60},
	-- {4, -0.1, 0.8, true, 'fast-underground-belt', 3, 10},
	{4, -0.1, 0.8, true, 'fast-splitter', 1, 5},
	{2, 0, 0.6, true, 'storage-tank', 2, 6},
	{2, 0, 0.5, true, 'heavy-armor', 1, 1},
	{3, 0, 0.7, true, 'steel-plate', 15, 80},
	-- {8, 0, 0.9, true, 'piercing-rounds-magazine', 10, 64},
	-- {4, 0.2, 0.6, true, 'engine-unit', 8, 16},
	{4, 0, 1, true, 'fast-inserter', 2, 12},
	{5, 0, 1, true, 'steel-furnace', 4, 8},
	{5, 0, 1, true, 'assembling-machine-2', 2, 4},
	{5, 0, 1, true, 'medium-electric-pole', 6, 20},
	{5, 0, 1, true, 'accumulator', 3, 6},
	{5, 0, 1, true, 'solar-panel', 3, 6},
	{8, 0, 1, true, 'steel-chest', 8, 16},
	{3, 0.2, 1, true, 'chemical-plant', 1, 3},
	--late-game:
	--{9, 0.5, 0.8, false, "railgun-dart", 8, 16},
	-- {5, 0, 1.2, true, 'land-mine', 16, 32},
	{4, 0.2, 1.2, true, 'lubricant-barrel', 4, 10},
	{1, 0.2, 1.2, true, 'battery', 10, 50},
	{5, 0.2, 1.8, true, 'explosive-rocket', 2, 8},
	{4, 0.2, 1.4, true, 'advanced-circuit', 20, 60},
	{3, 0.2, 1.4, true, 'big-electric-pole', 4, 8},
	{2, 0.3, 1, true, 'rocket-fuel', 4, 10},
	-- {5, 0.4, 0.7, true, 'cannon-shell', 16, 32},
	-- {5, 0.4, 0.8, true, 'explosive-cannon-shell', 16, 32},
	{5, 0.2, 1.8, true, 'cluster-grenade', 8, 16},
	-- {5, 0.2, 1.4, true, 'construction-robot', 5, 25},
	-- {2, 0.25, 1.75, true, 'logistic-robot', 5, 25},
	{1, 0.25, 1.75, true, 'substation', 2, 3},
	{3, 0.25, 1.75, true, 'assembling-machine-3', 2, 4},
	{3, 0.2, 1.8, true, 'express-transport-belt', 5, 10},
	{3, 0.2, 1.8, true, 'express-underground-belt', 4, 4},
	{3, 0.2, 1.8, true, 'express-splitter', 1, 3},
	{1, 0.25, 1.75, true, 'electric-furnace', 2, 4},
	-- {1, 0.25, 1.75, true, 'laser-turret', 1, 1},
	-- {4, 0.4, 1.6, true, 'processing-unit', 30, 200},
	{2, 0.6, 1.4, true, 'roboport', 1, 1},
	-- super late-game:
	--{9, 0.8, 1.2, false, "railgun-dart", 12, 20},
	-- {1, 0.9, 1.1, true, 'power-armor-mk2', 1, 1},
	-- {1, 0.8, 1.2, true, 'fusion-reactor-equipment', 1, 1}

	--{2, 0, 1, , "computer", 1, 1},
	--{1, 0.2, 1, , "railgun", 1, 1},
	--{1, 0.9, 1, , "personal-roboport-mk2-equipment", 1, 1},
}

function Public.wooden_chest_loot()
	local memory = Memory.get_crew_memory()
	local overworldx = memory.overworldx or 0
	local num = 1

	return Public.chest_loot(num,
	Math.max(0,Math.min(1, Math.sloped(Common.difficulty(),1/2) * Common.game_completion_progress())) --enforce 0 to 1
)
end

function Public.iron_chest_loot()
	local memory = Memory.get_crew_memory()
	local overworldx = memory.overworldx or 0
	local num = 2

	local loot = Public.chest_loot(num,
	Math.max(0,Math.min(1, Math.sloped(Common.difficulty(),1/2) * (5/100 + Common.game_completion_progress()))) --enforce 0 to 1
) --reward higher difficulties with better loot
	loot[#loot + 1] = {name = 'coin', count = Math.random(1,1500)}

    return loot
end

function Public.covered_wooden_chest_loot()
	local memory = Memory.get_crew_memory()
	local overworldx = memory.overworldx or 0
	local num = 2

	local loot = Public.chest_loot(num,
	Math.max(0,Math.min(1, Math.sloped(Common.difficulty(),1/2) * (10/100 + Common.game_completion_progress()))) --enforce 0 to 1
) --reward higher difficulties with better loot

    return loot
end

function Public.stone_furnace_loot()
    return {
		{name = 'coal', count = 50},
	}
end
function Public.storage_tank_fluid_loot(force_type)
	local ret
	local rng = Math.random(10)
	if force_type == 'crude-oil' then
		ret = {name = 'crude-oil', amount = Math.random(3000, 15000)}
	elseif force_type == 'petroleum-gas' then
		ret = {name = 'petroleum-gas', amount = Math.random(1500, 7500)}
	elseif rng < 6 then
		ret = {name = 'crude-oil', amount = Math.random(1000, 5000)}
	elseif rng == 7 then
		ret = {name = 'heavy-oil', amount = Math.random(1000, 4000)}
	elseif rng == 8 then
		ret = {name = 'lubricant', amount = Math.random(1000, 2000)}
	else
		ret = {name = 'petroleum-gas', amount = Math.random(1000, 3000)}
	end
    return ret
end

function Public.swamp_storage_tank_fluid_loot()
	local ret
	ret = {name = 'sulfuric-acid', amount = Math.random(500, 1500)}
    return ret
end

function Public.roboport_bots_loot()
    return {
		{name = 'logistic-robot', count = 5},
	}
    -- construction robots
end

function Public.random_plates(multiplier)
	multiplier = multiplier or 1
	local platesrng = Math.random(5)
	if platesrng <= 2 then
		return {name = 'iron-plate', count = 120 * multiplier}
	elseif platesrng <= 4 then
		return {name = 'copper-plate', count = 120 * multiplier}
	else
		return {name = 'steel-plate', count = 20 * multiplier}
	end
end

function Public.chest_loot(number_of_items, game_completion_progress)
	local ret = Common.raffle_from_processed_loot_data(Common.processed_loot_data(Public.chest_loot_data_raw), number_of_items, game_completion_progress)

	ret[#ret + 1] = ret[1]
	ret[1] = Public.random_plates()

	return ret
end

function Public.buried_treasure_loot()
	local ret = Common.raffle_from_processed_loot_data(Common.processed_loot_data(Public.buried_treasure_loot_data_raw), 1, Math.sloped(Common.difficulty(),1/2) * Common.game_completion_progress_capped())

	if ret and ret[1] then return ret[1] end
end

--@TODO: Perhaps add more modular armor chance here?

function Public.maze_camp_loot()
	if Math.random(10) <= 7 then
		return {Public.random_plates()}
	else
		return Common.raffle_from_processed_loot_data(Common.processed_loot_data(Public.chest_loot_data_raw), 1, Math.max(0,Math.min(1, Math.sloped(Common.difficulty(),1/2) * (15/100 + Common.game_completion_progress()))))
	end
end

Public.maze_lab_loot_data_raw = {
	{8, -0.5, 0.5, true, 'automation-science-pack', 8, 20},
	{8, -0.6, 0.6, true, 'logistic-science-pack', 8, 20},
	{6, -0.1, 1, true, 'military-science-pack', 8, 20},
	{6, -0.5, 1.5, true, 'chemical-science-pack', 8, 20},
	{6, 0, 1.5, true, 'production-science-pack', 8, 20},
	-- {4, 0.4, 1.5, true, 'utility-science-pack', 16, 32},
	-- {10, 0.5, 1.5, true, 'space-science-pack', 16, 32},
}

function Public.maze_lab_loot()
	return Common.raffle_from_processed_loot_data(Common.processed_loot_data(Public.maze_lab_loot_data_raw), 1, Math.max(0,Math.min(1, Math.sloped(Common.difficulty(),1/2) * (10/100 + Common.game_completion_progress()))))
end

Public.maze_treasure_data_raw = {
	{2, -1, 1, true, 'rocket', 18, 24},
	{2, -1, 1, false, 'stack-inserter', 8, 10},
	{2, -1, 1, false, 'stack-filter-inserter', 5, 6},
	{2, -1, 1, false, 'poison-capsule', 10, 12},
	{2, -1, 1, false, 'slowdown-capsule', 8, 10},

	{2, 0, 1, false, 'uranium-rounds-magazine', 15, 25},
	{2, 0, 1, false, 'artillery-shell', 5, 7},
	{2, 0, 1, false, 'rail-signal', 400, 500},
	{2, 0, 1, false, 'electric-engine-unit', 3, 4},
	{2, 0, 1, false, 'cluster-grenade', 8, 12},

	{1, 0, 0.8, false, 'speed-module-3', 2, 2},
	{1, 0, 0.8, false, 'effectivity-module-3', 3, 3},
	{0.5, 0, 1, false, 'productivity-module-3', 2, 2},

	{2, 0, 1.5, true, 'production-science-pack', 20, 25},
	{2, 0, 1.5, true, 'coin', 5000, 10000},

	{1, 0.2, 1.8, true, 'explosive-rocket', 6, 8},

	{1, 0, 0.9, false, 'express-transport-belt', 20, 60},
	{0.5, 0, 0.9, false, 'express-underground-belt', 12, 12},
	{0.5, 0, 0.9, false, 'express-splitter', 10, 10},
	{1, 0, 0.9, false, 'express-loader', 2, 2},
	{0.5, 0, 0.5, false, 'substation', 2, 2},
	{0.5, 0, 0.8, false, 'assembling-machine-3', 3, 3},
	{1, 0, 0.7, false, 'electric-furnace', 4, 6},

	{1, 0, 0.9, false, 'destroyer-capsule', 6, 6},
	
	{1, 0, 0.8, false, 'modular-armor', 1, 1},
	{1, 0, 2, true, 'power-armor', 1, 1},
	{0.08, 0, 2, true, "power-armor-mk2", 1, 1},

	{2, -1, 1, true, 'solar-panel-equipment', 3, 4},
	{2, -1, 1, true, 'battery-equipment', 1, 1},
	{1, 0, 2, true, 'battery-mk2-equipment', 1, 1},
	{2, -1, 1, true, 'energy-shield-equipment', 1, 2},
	{1, 0, 2, true, 'energy-shield-mk2-equipment', 1, 1},
	{1, -1, 1, true, 'personal-roboport-equipment', 1, 1},
	{0.5, 0, 2, true, 'personal-roboport-mk2-equipment', 1, 1},
	{0.5, 0, 0.8, false, 'night-vision-equipment', 1, 1},
	{1, 0, 1, false, 'personal-laser-defense-equipment', 1, 1},
	{0.5, 0, 1, false, 'fusion-reactor-equipment', 1, 1},
	{2, 0, 1, false, 'exoskeleton-equipment', 1, 1},
	{0.5, 0, 1, false, 'personal-laser-defense', 1, 1},

	{2, -0.7, 1.3, true, 'advanced-circuit', 40, 90},
	
	{2, 0, 0.5, false, 'laser-turret', 1, 2},
	{2, 0.6, 1, false, 'laser-turret', 4, 5},
	{1, 0, 0.5, false, 'roboport', 1, 1},

	{1, 0, 1, false, 'atomic-bomb', 1, 1},
}

function Public.maze_treasure_loot()
	if Math.random(5) == 1 then
		return {Public.random_plates(8)}
	else
		return Common.raffle_from_processed_loot_data(Common.processed_loot_data(Public.maze_treasure_data_raw), 1, Math.max(0,Math.min(1, Math.sloped(Common.difficulty(),1/2) * (70/100 + Common.game_completion_progress()))))
	end
end

return Public