--- Original source: https://github.com/ZwerOxotnik/factorio-train_protection by ZwerOxotnik


---@class PE : module
local M = {}


local _allow_ally_connection = false
local _allow_connection_with_neutral = false


local _render_text_position = {0, 0}
local draw_text = rendering.draw_text
local _render_target_forces = {nil}
local _render_text_param = {
	text = {"train_protection.warning"},
	target = _render_text_position,
	surface = nil,
	forces = _render_target_forces,
	scale = 1,
	time_to_live = 210,
	color = {255, 0, 125}
}

--#region Functions of events


---@param train LuaTrain
---@param entity LuaEntity
---@param first_carriage LuaEntity
local function disconnect_train(train, entity, first_carriage)
	train.speed = 0

	local neutral_force = game.forces.neutral
	local force = entity.force
	local back_entity = entity.get_connected_rolling_stock(defines.rail_direction.back)
	if back_entity and back_entity.valid then
		local back_force = back_entity.force
		if force ~= back_force and
				not (_allow_connection_with_neutral and back_force == neutral_force) and
				not (_allow_ally_connection and (force.get_cease_fire(back_force) and
				back_force.get_cease_fire(force) and
				force.get_friend(back_force) and
				back_force.get_friend(force)))
		then
			entity.disconnect_rolling_stock(defines.rail_direction.back)
		end
	end

	local front_entity = entity.get_connected_rolling_stock(defines.rail_direction.front)
	if front_entity and front_entity.valid then
		local front_force = front_entity.force
		if force ~= front_force and
				not (_allow_connection_with_neutral and front_force == neutral_force) and
				not (_allow_ally_connection and (force.get_cease_fire(front_force) and
				front_force.get_cease_fire(force) and
				force.get_friend(front_force) and
				front_force.get_friend(force)))
		then
			entity.disconnect_rolling_stock(defines.rail_direction.front)
		end
	end

	if not first_carriage.valid then return end
	local passengers = first_carriage.train.passengers
	if passengers == 0 then return end

	first_carriage.train.speed = 0.1

	for i = 1, #passengers do
		local passenger = passengers[i]
		if passenger.valid then
			passenger.vehicle.set_driver(nil)

			_render_text_position[1] = passenger.position.x
			_render_text_position[2] = passenger.position.y
			-- Show warning text
			_render_target_forces[1] = passenger.force
			_render_text_param.surface = passenger.surface
			draw_text(_render_text_param)
		end
	end
end
M.disconnect_train = disconnect_train


function M.on_train_created(event)
	if event.old_train_id_2 == nil then return end

	local train = event.train
	if not train.valid then return end

	local neutral_force = game.forces.neutral
	local carriages = train.carriages
	local first_carriage = carriages[1]

	local force = first_carriage.force
	for i = 2, #carriages do
		local carriage = carriages[i]
		local _force = carriage.force
		if force ~= _force and
			not (_allow_connection_with_neutral and _force == neutral_force) and
			not (_allow_ally_connection and (force.get_cease_fire(_force) and
			_force.get_cease_fire(force) and
			force.get_friend(_force) and
			_force.get_friend(force)))
		then
			disconnect_train(train, carriage, first_carriage)
			return
		end
	end
end

--#endregion


--#region Pre-game stage


local function add_remote_interface()
	-- https://lua-api.factorio.com/latest/LuaRemote.html
	remote.remove_interface("train_protection") -- For safety
	remote.add_interface("train_protection", {})
end

M.add_remote_interface = add_remote_interface

--#endregion


M.events = {
	[defines.events.on_train_created] = M.on_train_created
}
M.events_when_off = {}

return M
