
local Public = {}

local Memory = require 'maps.pirates.memory'
local Math = require 'maps.pirates.math'
local Balance = require 'maps.pirates.balance'
local Common = require 'maps.pirates.common'
local CoreData = require 'maps.pirates.coredata'
local Utils = require 'maps.pirates.utils_local'
local inspect = require 'utils.inspect'.inspect
local Server = require 'utils.server'

local Structures = require 'maps.pirates.structures.structures'
local Boats = require 'maps.pirates.structures.boats.boats'
local Surfaces = require 'maps.pirates.surfaces.surfaces'
local Crowsnest = require 'maps.pirates.surfaces.crowsnest'
local Dock = require 'maps.pirates.surfaces.dock'
local Islands = require 'maps.pirates.surfaces.islands.islands'
local Sea = require 'maps.pirates.surfaces.sea.sea'
local Crew = require 'maps.pirates.crew'
local Roles = require 'maps.pirates.roles.roles'
local Classes = require 'maps.pirates.roles.classes'
local Quest = require 'maps.pirates.quest'
local Parrot = require 'maps.pirates.parrot'
local Hold = require 'maps.pirates.surfaces.hold'
local Cabin = require 'maps.pirates.surfaces.cabin'
local Shop = require 'maps.pirates.shop.shop'
local Upgrades = require 'maps.pirates.boat_upgrades'
local Kraken = require 'maps.pirates.surfaces.sea.kraken'
local Highscore = require 'maps.pirates.highscore'


local infront_positions = {}
for x = -6, -3 do
	for y = - 3, 3 do
		infront_positions[#infront_positions + 1] = {x = x, y = y}
	end
end
local interior_positions = {}
for x = 1, 14 do
	for y = - 3, 3 do
		interior_positions[#interior_positions + 1] = {x = x, y = y}
	end
end



function Public.generate_overworld_destination(p)
	-- be careful when calling any Balance functions that depend on overworldx — they will be evaluated when the island is chosen, not on arrival
	local memory = Memory.get_crew_memory()

	local macrop = {x = p.x/40, y = p.y/24}

	local type, subtype

	local island_subtype_raffle = {'none', 'none', Surfaces.Island.enum.STANDARD, Surfaces.Island.enum.STANDARD_VARIANT, Surfaces.Island.enum.RED_DESERT, Surfaces.Island.enum.HORSESHOE}

	if macrop.x >= 6 then island_subtype_raffle[#island_subtype_raffle + 1] = Surfaces.Island.enum.WALKWAYS end
	if macrop.x >= 6 then island_subtype_raffle[#island_subtype_raffle + 1] = 'none' end
	if macrop.x >= 13 and macrop.y == 1 then
		island_subtype_raffle[#island_subtype_raffle + 1] = Surfaces.Island.enum.MAZE
		island_subtype_raffle[#island_subtype_raffle + 1] = Surfaces.Island.enum.MAZE
	end
	if macrop.x >= 16 then island_subtype_raffle[#island_subtype_raffle + 1] = Surfaces.Island.enum.SWAMP end
	if macrop.x >= 16 then island_subtype_raffle[#island_subtype_raffle + 1] = 'none' end

	--avoid duplicate subtype twice in a row in the same lane
	for _, d in pairs(memory.destinations) do
		if d.subtype and d.overworld_position.x == p.x - 40 and d.overworld_position.y == p.y then
			local new_island_subtype_raffle = Utils.ordered_table_with_values_removed(island_subtype_raffle, d.subtype)
			-- if _DEBUG and #new_island_subtype_raffle ~= #island_subtype_raffle then
			-- 	game.print('Removed ' .. d.subtype .. ' from raffle at ' .. p.x .. ',' .. p.y)
			-- end
			island_subtype_raffle = new_island_subtype_raffle
		end
	end

	if macrop.x == 0 then
		if macrop.y == 0 then
			type = Surfaces.enum.ISLAND
			subtype = Surfaces.Island.enum.FIRST
		elseif macrop.y == -1 then
			type = Surfaces.enum.DOCK
		else
			type = nil
		end
	elseif macrop.x == 1 then
		type = Surfaces.enum.ISLAND
		subtype = Surfaces.Island.enum.HORSESHOE --map where you break rocks
	elseif macrop.x == 2 then
		type = Surfaces.enum.ISLAND
		subtype = Surfaces.Island.enum.STANDARD_VARIANT --aesthetically different to first map
	elseif macrop.y == -1 and (((macrop.x % 4) == 3 and macrop.x ~= 15) or macrop.x == 14) then --avoid x=15 because radioactive is there
		type = Surfaces.enum.DOCK
	elseif macrop.x == 5 then --biter boats appear. large island works well so players run off
		type = Surfaces.enum.ISLAND
		subtype = Surfaces.Island.enum.STANDARD
	elseif macrop.x == 6 then
		if macrop.y == 1 then
			type = Surfaces.enum.ISLAND
			subtype = Surfaces.Island.enum.MAZE
		else
			type = nil
		end
	elseif macrop.x == 8 then --game length decrease, pending more content
		type = nil
	-- elseif macrop.x == 9 then --just before krakens
	-- 	type = Surfaces.enum.ISLAND
	-- 	subtype = Surfaces.Island.enum.RED_DESERT
	elseif macrop.x == 10 then --krakens appear
		type = nil
	-- elseif macrop.x == 11 then
	-- 	if macrop.y == -1 then
	-- 		type = Surfaces.enum.ISLAND
	-- 		subtype = Surfaces.Island.enum.MAZE
	-- 	else
	-- 		type = nil
	-- 	end
	elseif macrop.x == 12 then --just after krakens, but dock is here too, so there's a choice
		type = Surfaces.enum.ISLAND
		subtype = Surfaces.Island.enum.SWAMP
	elseif macrop.x == 15 or (macrop.x > 25 and macrop.x % 12 == 3) then
		type = Surfaces.enum.ISLAND
		subtype = Surfaces.Island.enum.RADIOACTIVE
		 --electric engines needed at 20
	-- elseif macrop.x == 17 then --game length decrease, pending more content
	-- 	type = nil
	elseif macrop.x == 20 then --game length decrease, pending more content
		type = nil
	elseif macrop.x == 21 then --game length decrease, pending more content. also kinda fun to have to steer in realtime due to double space
		type = nil
	elseif macrop.x == 23 then --rocket launch cost
		type = Surfaces.enum.ISLAND
		subtype = Surfaces.Island.enum.MAZE
	elseif macrop.x == 24 then --rocket launch cost
		type = Surfaces.enum.ISLAND
		subtype = Surfaces.Island.enum.WALKWAYS
	elseif macrop.x == 25 then
		type = nil --finish line
	else
		type = Surfaces.enum.ISLAND

		subtype = island_subtype_raffle[Math.random(#island_subtype_raffle)]

		if subtype == 'none' then
			type = nil
			subtype = nil
		end
	end

	-- debug override to test islands:

	-- if _DEBUG and type == Surfaces.enum.ISLAND then
	-- 	-- warning: the first map is unique in that it isn't all loaded by the time you arrive, which can cause issues. For example, structures might get placed after ore, thereby deleting the ore underneath them.
	-- 	subtype = Surfaces.Island.enum.MAZE
	-- end

	-- if _DEBUG and ((macrop.x > 0 and macrop.x < 25)) and type ~= Surfaces.enum.DOCK then
	-- 	type = nil
	-- 	subtype = nil
	-- end

	if type == Surfaces.enum.ISLAND then

		local scope = Surfaces[Surfaces.enum.ISLAND][subtype]

		local static_params = Utils.deepcopy(scope.Data.static_params_default)
		local cost_to_leave, scheduled_raft_raids

		-- temporarily placed this back here, as moving it to shorehit broke things:
		local playercount = Common.activecrewcount()
		local max_evo = 0.85
		if Common.difficulty() < 1 then max_evo = 0.70 end
		if Common.difficulty() > 1 then max_evo = 0.90 end

		if macrop.x > 5 then
			scheduled_raft_raids = {}
			local times = {600, 360, 215, 210, 120, 30, 10, 5}
			for i = 1, #times do
				local t = times[i]
				if Math.random(7) == 1 and #scheduled_raft_raids < 6 then
					scheduled_raft_raids[#scheduled_raft_raids + 1] = {timeinseconds = t, max_evo = max_evo}
					-- scheduled_raft_raids[#scheduled_raft_raids + 1] = {timeinseconds = t, max_bonus_evolution = 0.52}
				end
			end
		elseif macrop.x == 5 then
			local times
			if playercount <= 2 then
				times = {1, 5, 10, 15, 20}
			elseif playercount <= 8 then
				times = {1, 5, 10, 15, 20, 25}
			elseif playercount <= 15 then
				times = {1, 5, 10, 15, 20, 25, 30}
			else
				times = {1, 5, 10, 15, 20, 25, 30, 35, 40}
			end
			scheduled_raft_raids = {}
			for _, t in pairs(times) do
				-- scheduled_raft_raids[#scheduled_raft_raids + 1] = {timeinseconds = t, max_bonus_evolution = 0.62}
				scheduled_raft_raids[#scheduled_raft_raids + 1] = {timeinseconds = t, max_evo = max_evo}
			end
		end

		static_params.scheduled_raft_raids = scheduled_raft_raids

		-- halved all of them for now, whilst testing...
		
		local normal_costitems = {'small-lamp', 'engine-unit', 'advanced-circuit'}
		local base_cost_0 = {
			['small-lamp'] = Math.ceil(((macrop.x-2)^(2/3))*25),
		}
		local base_cost_1 = {
			['small-lamp'] = Math.ceil(((macrop.x-2)^(2/3))*25),
			['engine-unit'] = Math.ceil(((macrop.x-7)^(2/3))*18),
		}
		local base_cost_2 = {
			['small-lamp'] = Math.ceil(((macrop.x-2)^(2/3))*25),
			['engine-unit'] = Math.ceil(((macrop.x-7)^(2/3))*18),
			['advanced-circuit'] = Math.ceil(((macrop.x-15)^(2/3))*8),
		}
		local base_cost_2b = {
			['small-lamp'] = Math.ceil(((macrop.x-2)^(2/3))*25),
			['engine-unit'] = Math.ceil(((macrop.x-7)^(2/3))*18),
			['electric-engine-unit'] = 2,
		}
		local base_cost_2c = {
			['small-lamp'] = Math.ceil(((macrop.x-2)^(2/3))*25),
			['engine-unit'] = Math.ceil(((macrop.x-7)^(2/3))*18),
			['advanced-circuit'] = Math.ceil(((macrop.x-15)^(2/3))*8),
			['launch_rocket'] = true,
		}
		local base_cost_3 = {
			['small-lamp'] = Math.ceil(((macrop.x-2)^(2/3))*25),
			['engine-unit'] = Math.ceil(((macrop.x-7)^(2/3))*18),
			['advanced-circuit'] = Math.ceil(((macrop.x-15)^(2/3))*8),
			['electric-engine-unit'] = Math.ceil(((macrop.x-18)^(2/3))*5),
			['launch_rocket'] = true,
		}
		local base_cost_4 = {
			['small-lamp'] = Math.ceil(((macrop.x-2)^(2/3))*25),
			['engine-unit'] = Math.ceil(((macrop.x-7)^(2/3))*18),
			['advanced-circuit'] = Math.ceil(((macrop.x-15)^(2/3))*8),
			['electric-engine-unit'] = Math.ceil(((macrop.x-18)^(2/3))*5),
		}
		if macrop.x == 0 then
			-- if _DEBUG then
			-- 	cost_to_leave = {
			-- 		['small-lamp'] = 5,
			-- 		['engine-unit'] = 5,
			-- 		['advanced-circuit'] = 5,
			-- 		['electric-engine-unit'] = 5,
			-- 	}
			-- end
			-- cost_to_leave = nil
		elseif macrop.x <= 6 then
			-- cost_to_leave = {['small-lamp'] = 5}
			cost_to_leave = nil
		elseif macrop.x <= 8 then
			cost_to_leave = base_cost_0
		elseif macrop.x <= 15 then
			if macrop.x % 3 > 0 then
				cost_to_leave = base_cost_1
			else
				cost_to_leave = nil
			end
		elseif macrop.x == 18 then --a super small amount of electric-engine-unit on a relatively early level so that they see they need lubricant
			cost_to_leave = base_cost_2b
		elseif macrop.x <= 22 then
			if macrop.x % 3 > 0 then
				cost_to_leave = base_cost_2
			else
				cost_to_leave = nil
			end
		elseif macrop.x == 23 then
			cost_to_leave = base_cost_2c
		elseif macrop.x == 24 then
			cost_to_leave = base_cost_3
		else
			cost_to_leave = Utils.deepcopy(base_cost_4)
			local delete = normal_costitems[Math.random(#normal_costitems)]
			cost_to_leave[delete] = nil
		end
		-- override:
		if subtype == Surfaces.Island.enum.RADIOACTIVE then
			cost_to_leave = {
				['uranium-235'] = Math.ceil(Math.ceil(80 + (macrop.x))),
				-- ['uranium-235'] = Math.ceil(Math.ceil(80 + (macrop.x)/2)), --tried adding beacons instead of this
			}
		end

		-- -- debug override:
		-- if _DEBUG then
		-- 	cost_to_leave = {
		-- 		['launch_rocket'] = true,
		-- 	}
		-- end

		static_params.cost_to_leave = cost_to_leave -- Multiplication by Balance.cost_to_leave_multiplier() happens later, in destination_on_collide.

		--scheduled raft raids moved to destination_on_arrival

		local ores_multiplier = Balance.island_richness_avg_multiplier()
		if macrop.x == 0 then ores_multiplier = 0.9 end
		
		local base_ores = scope.Data.base_ores()

		local rngs = {}
		local rngsum = 0
		local rngcount = 0
		for k, _ in pairs(base_ores) do
			if k ~= 'coal' then
				local rng = 2*Math.random()
				-- local rng = 1 + ((2*Math.random() - 1)^3) --lower variances
				rngs[k] = rng
				rngsum = rngsum + rng
				rngcount = rngcount + 1
			end
		end

		local abstract_ore_amounts = {}
		for k, v in pairs(base_ores) do
			local rng = 1
			if not (k == 'coal' or macrop.x == 0) then
				rng = rngs[k] / (rngsum/rngcount) --average of 1
			end
			abstract_ore_amounts[k] = ores_multiplier * v * rng
		end
		static_params.abstract_ore_amounts = abstract_ore_amounts

		static_params.radius_squared_modifier = (Math.sqrt(0.5) + 1 * Math.random())^2

		if macrop.x == 0 then static_params.radius_squared_modifier = 1 end

		static_params.discord_emoji = scope.Data.discord_emoji

		local rng = 0.5 + 1 * Math.random()
		static_params.starting_treasure_maps = Math.ceil((static_params.base_starting_treasure_maps or 0) * rng)
		static_params.starting_wood = Math.ceil(static_params.base_starting_wood or 1000)
		static_params.starting_rock_material = Math.ceil(static_params.base_starting_rock_material or 300) * Balance.island_richness_avg_multiplier()
		
		rng = 0.5 + 1 * Math.random()
		static_params.starting_treasure = Math.ceil((static_params.base_starting_treasure or 1000) * Balance.island_richness_avg_multiplier() * rng)

		static_params.name = scope.Data.display_names[Math.random(#scope.Data.display_names)]
		
        local dest = Surfaces.initialise_destination{
            static_params = static_params,
            type = type,
            subtype = subtype,
            overworld_position = p,
        }

		Crowsnest.draw_destination(dest)

	elseif type == Surfaces.enum.DOCK then

		local boat_for_sale_type
		-- if macrop.x == 3 then
		-- 	boat_for_sale_type = Boats.enum.CUTTER
		-- elseif macrop.x == 7 or macrop.x == 0 then
		-- 	boat_for_sale_type = Boats.enum.SLOOP_WITH_HOLD
		-- end
		boat_for_sale_type = Boats.enum.SLOOP

		local upgrade_for_sale
		if macrop.x == 0 then
			upgrade_for_sale = nil
		elseif macrop.x == 3 then
			upgrade_for_sale = Upgrades.enum.MORE_POWER
		elseif macrop.x == 7 then
			upgrade_for_sale = Upgrades.enum.EXTRA_HOLD
		elseif macrop.x % 16 < 8 then
			upgrade_for_sale = Upgrades.enum.MORE_POWER
		else
			upgrade_for_sale = Upgrades.enum.EXTRA_HOLD
		end --upgrades like UNLOCK_MERCHANTS will slot themselves in when necessary, due to .overwrite_a_dock_upgrade()
		-- one day it's worth making this system more readable

		local static_params = Utils.deepcopy(Dock.Data.static_params_default)
		static_params.upgrade_for_sale = upgrade_for_sale
		static_params.boat_for_sale_type = boat_for_sale_type

		static_params.name = Dock.Data.display_names[Math.random(#Dock.Data.display_names)]

        local dest = Surfaces.initialise_destination{
            static_params = static_params,
            type = type,
            subtype = subtype,
            overworld_position = {x = p.x, y = -36},
            -- overworld_position = {x = p.x, y = 36},
        }

		Crowsnest.draw_destination(dest)

		-- renderings e.g. for docks
	
		local surface = Crowsnest.get_crowsnest_surface()
		local x = Crowsnest.platformrightmostedge + dest.overworld_position.x
		local y = dest.overworld_position.y
		if dest.static_params.upgrade_for_sale then
			local display_form = Upgrades.crowsnest_display_form[dest.static_params.upgrade_for_sale]

			if not dest.dynamic_data.crowsnest_renderings then
				dest.dynamic_data.crowsnest_renderings = {}
			end
			
			dest.dynamic_data.crowsnest_renderings.base_text_rendering = rendering.draw_text{
				text = display_form .. ':',
				surface = surface,
				target = {x = x + 5.5, y = y + 2.5},
				color = CoreData.colors.renderingtext_green,
				scale = 7,
				font = 'default-game',
				alignment = 'right',
				visible = false,
			}

			local i = 1
			for price_name, price_count in pairs(Shop.main_shop_data_1[dest.static_params.upgrade_for_sale].base_cost) do
				local sprite
				if price_name == 'fuel' then
					sprite = 'item/coal'
				else
					sprite = 'item/coin'
				end
				dest.dynamic_data.crowsnest_renderings[price_name] = {
					text_rendering = rendering.draw_text{
						text = Utils.bignumber_abbrevform2(price_count),
						surface = surface,
						target = {x = x + 6, y = y + 8.3 - i * 3.5},
						color = CoreData.colors.renderingtext_green,
						scale = 5.2,
						font = 'default-game',
						alignment = 'left',
						visible = false,
					},
					sprite_rendering = rendering.draw_sprite{
						sprite = sprite,
						surface = surface,
						target = {x = x + 14.1, y = y + 10.8 - i * 3.5},
						x_scale = 4.5,
						y_scale = 4.5,
						visible = false,
					}
				}
				i = i + 1
			end
		end
	end

	--== krakens ==--

	local kraken_count = 0
	local position_candidates
	if type == nil then
		kraken_count = Balance.krakens_per_free_slot(macrop.x)
		position_candidates = interior_positions
	elseif type ~= Surfaces.enum.DOCK then
		kraken_count = Balance.krakens_per_slot(macrop.x)
		position_candidates = infront_positions
	end

	-- override:
	if macrop.x < 10 then
		kraken_count = 0
	elseif macrop.x == 10 then
		kraken_count = 1
	end

	-- if _DEBUG then
	-- 	kraken_count = 1
	-- end

	if position_candidates then
		local positions_placed = {}
		local whilesafety = 0
		while whilesafety < 10 and (#positions_placed < Math.min(kraken_count, 10)) do
			local p_chosen, p_kraken
			local whilesafety2 = 0
			while whilesafety2 < 50 and ((not p_kraken) or Utils.contains(positions_placed, p_chosen)) do
				p_chosen = position_candidates[Math.random(#position_candidates)]
				p_kraken = Utils.psum{p_chosen, p}
				whilesafety2 = whilesafety2 + 1
			end
			Crowsnest.draw_kraken(p_kraken)
			positions_placed[#positions_placed + 1] = p_kraken
			memory.overworld_krakens[#memory.overworld_krakens + 1] = p_kraken
			whilesafety = whilesafety + 1
		end
		-- game.print(#positions_placed .. ' krakens placed for' .. macrop.x .. ', ' .. macrop.y)
	end
end





function Public.ensure_lane_generated_up_to(lane_yvalue, x)
	-- make sure lane_yvalue=0 is painted first
	local memory = Memory.get_crew_memory()

	local highest_x = memory['greatest_overworldx_generated_for_' .. lane_yvalue] or -40

	local whilesafety = 0
	while whilesafety < 10 and highest_x < x do
		whilesafety = whilesafety + 1

		highest_x = highest_x + 32 + 7 + 1 -- should be at least maximum island size plus crowsnest platform size plus 1

		if lane_yvalue == 0 then
			Crowsnest.paint_water_between_overworld_positions(highest_x + 32 + 7 + 1, highest_x + 32 + 7 + 1 + 40)
			-- a little hack that we're updating this here rather than Crowsnest, due to the dependency on Shop to avoid a loop... almost finished 1.0, so too late to figure out how to restructure things for now!
			for _, dest in pairs(memory.destinations) do
				if dest.static_params.upgrade_for_sale and dest.dynamic_data.crowsnest_renderings then
					if rendering.is_valid(dest.dynamic_data.crowsnest_renderings.base_text_rendering) then
						rendering.set_text(dest.dynamic_data.crowsnest_renderings.base_text_rendering, Upgrades.crowsnest_display_form[dest.static_params.upgrade_for_sale] .. ':')
					end
					for rendering_name, r in pairs(dest.dynamic_data.crowsnest_renderings) do
						if type(r) == 'table' and r.text_rendering and rendering.is_valid(r.text_rendering) then
							rendering.set_text(r.text_rendering, Utils.bignumber_abbrevform2(Shop.main_shop_data_1[dest.static_params.upgrade_for_sale].base_cost[rendering_name]))
						end
					end
				end
			end
			Crowsnest.update_destination_renderings()
		end
		Public.generate_overworld_destination{x = highest_x, y = lane_yvalue}
	end

	memory['greatest_overworldx_generated_for_' .. lane_yvalue] = highest_x
end




function Public.is_position_free_to_move_to(p)
	local memory = Memory.get_crew_memory()

	local ret = true

	for _, destination_data in pairs(memory.destinations) do
		if p.x >= destination_data.overworld_position.x + 1 and p.x <= destination_data.overworld_position.x + destination_data.iconized_map_width + Crowsnest.platformwidth - 1 and p.y >= destination_data.overworld_position.y - destination_data.iconized_map_width/2 - Crowsnest.platformheight/2 + 1 and p.y <= destination_data.overworld_position.y + destination_data.iconized_map_width/2 + Crowsnest.platformheight/2 - 1 then
			ret = false
			break
		end
	end
	return ret
end


function Public.check_for_kraken_collisions()
	local memory = Memory.get_crew_memory()
	local krakens = memory.overworld_krakens

	for i, k in ipairs(krakens) do

		local relativex = Crowsnest.platformrightmostedge + k.x - memory.overworldx
		local relativey = k.y - memory.overworldy

		if (relativex <= 3.5 and relativex >= -3.5 and relativey >= -4 and relativey <= 4) then
			Kraken.try_spawn_kraken()
			memory.overworld_krakens = Utils.ordered_table_with_index_removed(krakens, i)
		end
	end
end


function Public.check_for_destination_collisions()
	local memory = Memory.get_crew_memory()

	-- if memory.overworldx > CoreData.victory_x - 10 then return end
	-- to avoid crashing into the finish line...

	for _, destination_data in pairs(memory.destinations) do

		local relativex = Crowsnest.platformrightmostedge + destination_data.overworld_position.x - memory.overworldx
		local relativey = destination_data.overworld_position.y - memory.overworldy

		if (relativex == 4 and relativey + destination_data.iconized_map_height/2 >= -3.5 and relativey - destination_data.iconized_map_height/2 <= 3.5) then
			--or (relativey - destination_data.iconized_map.height/2 == 5 and (relativex >= -3.5 or relativex <= 4.5)) or (relativey + destination_data.iconized_map.height/2 == -4 and (relativex >= -3.5 or relativex <= 4.5))
			
			Surfaces.clean_up(Common.current_destination())

			Surfaces.create_surface(destination_data)

			local index = destination_data.destination_index
			memory.loadingticks = 0
			memory.mapbeingloadeddestination_index = index
			memory.currentdestination_index = index
			memory.boat.state = Boats.enum_state.ATSEA_LOADING_MAP

			local destination = Common.current_destination()
			Surfaces.destination_on_collide(destination)

			return true
		end
	end
	return false
end





function Public.try_overworld_move_v2(vector) --islands stay, crowsnest moves
	local memory = Memory.get_crew_memory()

	if memory.game_lost or (memory.victory_pause_until_tick and game.tick < memory.victory_pause_until_tick) then return end

	if memory.victory_continue_message then
		memory.victory_continue_message = false
		local message = 'The run now continues on \'Freeplay\'.'
		Common.notify_force(memory.force, message, CoreData.colors.notify_victory)
	end

	Public.ensure_lane_generated_up_to(0, memory.overworldx + Crowsnest.Data.visibilitywidth)
	Public.ensure_lane_generated_up_to(24, memory.overworldx + Crowsnest.Data.visibilitywidth)
	Public.ensure_lane_generated_up_to(-24, memory.overworldx + Crowsnest.Data.visibilitywidth)
	Public.overwrite_a_dock_upgrade()

	if not Public.is_position_free_to_move_to{x = memory.overworldx + vector.x, y = memory.overworldy+ vector.y} then
		if _DEBUG then log(string.format('can\'t move by ' .. vector.x .. ', ' .. vector.y)) end
		return false
	else

		Crowsnest.move_crowsnest(vector.x, vector.y)
	
		if vector.x > 0 then

			-- crew bonus resources per x:
			local crew = Common.crew_get_crew_members()
			for _, player in pairs(crew) do
				if Common.validate_player_and_character(player) then
					local player_index = player.index
					if memory.classes_table and memory.classes_table[player_index] and memory.classes_table[player_index] == Classes.enum.MERCHANT then
						Common.flying_text_small(player.surface, player.position, '[color=0.97,0.9,0.2]+[/color]')
						Common.give_reward_items{{name = 'coin', count = 40 * vector.x}}
					end
				end
			end

			-- other freebies:
			for i=1,vector.x do
				Common.give_reward_items(Balance.periodic_free_resources_per_x())
				Balance.apply_crew_buffs_per_x(memory.force)
			end

		end

		if memory.overworldx >= CoreData.victory_x then
			Crew.try_win()
		end

		if memory.overworldx % 40 == 0 then
			local modal_captain = nil
			local modal_captain_time = 0
			for name, time in pairs(memory.captain_accrued_time_data) do
				if time > modal_captain_time then
					modal_captain_time = time
					modal_captain = name
				end
			end
			Highscore.write_score(memory.secs_id, memory.name, modal_captain, memory.completion_time or 0, memory.overworldx, CoreData.version_float, memory.difficulty, memory.max_players_recorded or 0)
		end

		return true
	end
end



function Public.overwrite_a_dock_upgrade()
	local memory = Memory.get_crew_memory()

	if (memory.overworldx % (40*8)) == (40*4-1) then -- pick a point that _must_ be visited, i.e. right before a destination
		if (memory.overworldx) == (40*4-1) then -- LEAVE A GAP at x=40*11, because we haven't developed an upgrade to put there yet
			for _, dest in pairs(memory.destinations) do
				if dest.type == Surfaces.enum.DOCK then
					if dest.overworld_position.x == memory.overworldx + 1 + (40*7) then
						dest.static_params.upgrade_for_sale = Upgrades.enum.MORE_POWER
					end
				end
			end
		else
			local upgrade_to_overwrite_with

			if not memory.dock_overwrite_variable then memory.dock_overwrite_variable = 1 end

			local possible_overwrites = {}
			if (not memory.merchant_ships_unlocked) then
				possible_overwrites[#possible_overwrites + 1] = Upgrades.enum.UNLOCK_MERCHANTS
			end
			if (not memory.rockets_for_sale) then
				possible_overwrites[#possible_overwrites + 1] = Upgrades.enum.ROCKETS_FOR_SALE
			end

			if #possible_overwrites > 0 then
				if memory.dock_overwrite_variable > #possible_overwrites then memory.dock_overwrite_variable = 1 end
				upgrade_to_overwrite_with = possible_overwrites[memory.dock_overwrite_variable]
	
				-- bump the variable up, but only if the list hasn't reduced in length. use a second variable to track this:
				if memory.dock_overwrite_variable_2 and memory.dock_overwrite_variable_2 == #possible_overwrites then
					memory.dock_overwrite_variable = memory.dock_overwrite_variable + 1
				end
				memory.dock_overwrite_variable_2 = #possible_overwrites
			end
		
			if upgrade_to_overwrite_with then
				for _, dest in pairs(memory.destinations) do
					if dest.type == Surfaces.enum.DOCK then
						if dest.overworld_position.x == memory.overworldx + 1 + (40*7) then
							dest.static_params.upgrade_for_sale = upgrade_to_overwrite_with
						end
					end
				end
			end
		end
	end
end








return Public