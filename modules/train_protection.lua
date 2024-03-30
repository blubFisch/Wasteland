--- Original source: https://github.com/ZwerOxotnik/factorio-train_protection by ZwerOxotnik


---@class PE : module
local M = {}


local _allow_ally_connection = false
local _allow_connection_with_neutral = false


--#region Functions of events


---@param train LuaTrain
---@param entity LuaEntity
---@param first_carriage LuaEntity
local function disconnect_train(train, entity, first_carriage)
	train.speed = 0
	entity.disconnect_rolling_stock(defines.rail_direction.front)
	if first_carriage.valid then
		first_carriage.train.speed = 0.1

		local passengers = first_carriage.train.passengers
		for i = 1, #passengers do
			local passenger = passengers[i]
			if passenger.valid then
				passenger.vehicle.set_driver(nil)
			end
		end
	end
end
M.disconnect_train = disconnect_train


function M.on_train_created(event)
	if event.old_train_id_2 == nil then return end

	local train = event.train
	if not train.valid then return end

	local neutral_force = game.forces.neutral
	local first_carriage = train.carriages[1]
	local force = first_carriage.force
	local carriages = train.carriages
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
			break
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
