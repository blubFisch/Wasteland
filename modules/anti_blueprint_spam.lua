-- Original source: https://mods.factorio.com/mod/anti_blueprint_spam


if script.level.level_name ~= "anti_blueprint_spam" and
	script.active_mods["anti_blueprint_spam"] and
	script.mod_name == "level"
then
	remote.add_interface("disable-anti_blueprint_spam", {})
end


local Event = require 'utils.event'


local M = {}


--#region Global data
---@class anti_blueprint_spam_mod_data
local mod_data
---@type table<uint, true>
local restricted_players
---@type table<uint, uint>
local ghost_players_rate
---@type table<uint, uint>
local players_restiction_time
--#endregion


local RED_TEXT = {255, 0, 0}
local GREEN_TEXT = {0, 255, 0}
local _BUILD_ACTION = defines.input_action.build
---@type uint
local _ghost_rate_limit = (settings.global["ASBZO_max_ghost_rate"] and settings.global["ASBZO_max_ghost_rate"].value) or 2000 --[[@as uint]]
local _restriction_time = (settings.global["ASBZO_restriction_time"] and settings.global["ASBZO_restriction_time"].value) or 10 --[[@as uint]]


---@param player LuaPlayer
---@return boolean
M.remove_build_restriction = function(player)
	local player_index = player.index
	local is_restricted = restricted_players[player_index]
	players_restiction_time[player_index] = nil
	if not is_restricted then return false end
	local ghost_player_rate = ghost_players_rate[player_index]
	if ghost_player_rate and ghost_player_rate >= _ghost_rate_limit then return false end

	restricted_players[player_index] = nil

	-- Check if other players have build restriction
	local permission_group = player.permission_group
	for _, _player in pairs(permission_group.players) do
		if not _player.valid then goto continue end
		if restricted_players[_player.index] then return true end
	    ::continue::
	end

	-- Allow building ghost entities
	permission_group.set_allows_action(_BUILD_ACTION, true)

	-- Send messaged about removing build restriction
	local message = {"anti_blueprint_spam.allowed_to_build_again"}
	for _, _player in pairs(permission_group.players) do
		if not (_player.valid and _player.connected) then goto continue end
		player.print(message, GREEN_TEXT)
	    ::continue::
	end

	return true
end
local _remove_build_restriction = M.remove_build_restriction


---@param player LuaPlayer
---@return boolean
M.add_build_restriction = function(player)
	local player_index = player.index
	local is_restricted = restricted_players[player_index]
	if is_restricted then return false end

	restricted_players[player_index] = true
	players_restiction_time[player_index] = _restriction_time

	-- Prohibit building ghost entities
	local permission_group = player.permission_group
	permission_group.set_allows_action(_BUILD_ACTION, false)

	log(string.format("[WARNING] \"%s\" player got build restriction!", player.name))

	-- Send message about build restriction
	local message = {"anti_blueprint_spam.warning_to_group", player.name}
	local is_restricted_one = true
	for _, _player in pairs(permission_group.players) do
		if not (_player.valid and _player.connected) then goto continue end
		if player == _player then goto continue end
		is_restricted_one = false
		player.print(message, RED_TEXT)
	    ::continue::
	end
	if is_restricted_one then
		player.print({"anti_blueprint_spam.warning"}, RED_TEXT)
	else
		player.print(message, RED_TEXT)
	end

	return true
end


remote.add_interface("anti_blueprint_spam", {
	getSource = function()
		local mod_name = script.mod_name
		rcon.print(mod_name) -- Returns "level" if it's a scenario, otherwise "entities_drop_content" as a mod.
		return mod_name
	end,
	remove_build_restriction = M.remove_build_restriction,
	add_build_restriction = M.add_build_restriction,
	get_ghost_players_rate = function()
		return ghost_players_rate
	end,
	get_restricted_players = function()
		return restricted_players
	end,
	is_player_restricted = function(player_index)
		return (restricted_players[player_index] == true)
	end,
	get_ghost_player_rate = function(player_index)
		return ghost_players_rate[player_index] or 0
	end,
})


M.check_players_data = function()
	for player_index, rate in pairs(ghost_players_rate) do
		rate = rate - 60
		if rate > 0 then
			ghost_players_rate[player_index] = rate
		else
			ghost_players_rate[player_index] = nil
		end
	end

	for player_index, time in pairs(players_restiction_time) do
		time = time - 1
		if time > 0 then
			players_restiction_time[player_index] = time
		else
			ghost_players_rate[player_index] = nil	-- Note: Overrides other rate logic
			local player = game.get_player(player_index)
			if not (player and player.valid) then goto continue end
			_remove_build_restriction(player)
		end
	    ::continue::
	end
end


--- Probably, not really safe
-- ---@param event on_player_left_game
-- M.on_player_left_game = function(event)
-- 	local player_index = event.player_index
-- 	local player = game.get_player(player_index)
-- 	if not (player and player.valid) then return end
-- 	M.remove_build_restriction(player)
-- end


---@param event on_player_removed
M.on_player_removed = function(event)
	local player_index = event.player_index
	ghost_players_rate[player_index] = nil
	restricted_players[player_index] = nil
	players_restiction_time[player_index] = nil
end


local ENTITY_TYPE_BLACKLIST = {
	["entity-ghost"] = true,
	["tile-ghost"]   = true
}

---@param event on_built_entity
M.on_built_entity = function(event)
	local entity = event.created_entity
	if not entity.valid then return end
	if ENTITY_TYPE_BLACKLIST[entity.type] then return end

	local player_index = event.player_index
	local player = game.get_player(player_index)
	if not (player and player.valid) then return end

	local ghost_player_rate = (ghost_players_rate[player_index] or 0) + 1
	ghost_players_rate[player_index] = ghost_player_rate

	if ghost_player_rate < _ghost_rate_limit then return end
	entity.destroy()

	if ghost_player_rate == _ghost_rate_limit then -- should be safe
		M.add_build_restriction(player)
	end
end


---@param event on_runtime_mod_setting_changed
M.on_runtime_mod_setting_changed = function(event)
	local setting_name = event.setting
	if setting_name == "ASBZO_max_ghost_rate" then
		_ghost_rate_limit = settings.global[setting_name].value --[[@as uint]]
	elseif setting_name == "ASBZO_restriction_time" then
		_restriction_time = settings.global[setting_name].value --[[@as uint]]
	end
end

--#region Pre-game stage

M.validate_global_data = function()
	local players = game.players

	local function validate_players_data(data)
		for player_index in pairs(data) do
			local player = players[player_index]
			if not (player and player.valid) then
				data[player_index] = nil
			end
		end
	end

	validate_players_data(restricted_players)
	validate_players_data(ghost_players_rate)
	validate_players_data(players_restiction_time)
end


M.link_data = function()
	mod_data = global.ASBZO
	restricted_players = mod_data.restricted_players
	ghost_players_rate = mod_data.ghost_players_rate
	players_restiction_time = mod_data.players_restiction_time
end


M.update_global_data = function()
	global.ASBZO = global.ASBZO or {}
	mod_data = global.ASBZO
	mod_data.restricted_players = mod_data.restricted_players or {}
	mod_data.ghost_players_rate = mod_data.ghost_players_rate or {}
	mod_data.players_restiction_time = mod_data.players_restiction_time or {}

	M.link_data()

	if game then
		M.validate_global_data()
	end
end


Event.on_init(M.update_global_data)
Event.on_load(M.link_data)
Event.on_configuration_changed(M.update_global_data)

--#endregion


M.events = {
	[defines.events.on_built_entity] = M.on_built_entity,
	-- [defines.events.on_player_left_game] = M.on_player_left_game,
	[defines.events.on_player_removed] = M.on_player_removed,
	[defines.events.on_runtime_mod_setting_changed] = M.on_runtime_mod_setting_changed,
}

for k, v in pairs(M.events) do
	Event.add(k, v)
end

M.on_nth_tick = {
	[60] = M.check_players_data,
}

for k, v in pairs(M.on_nth_tick) do
	Event.on_nth_tick(k, v)
end

return M
