local Event = require 'utils.event'
local Global = require 'utils.global'
local Gui = require 'utils.gui'

local this = {
    players = {},
    module_disabled = false
}

Global.register(
    this,
    function(t)
        this = t
    end
)

local Public = {}

local locate_player_frame_name = Gui.uid_name()
local player_frame_name = Gui.uid_name()

local function create_player_data(player)
    local player_data = this.players[player.index]
    if player_data then
        return this.players[player.index]
    else
        this.players[player.index] = {}
        return this.players[player.index]
    end
end

local function remove_player_data(player)
    local player_data = this.players[player.index]
    if player_data then
        this.players[player.index] = nil
    end
end

local function remove_camera_frame(player)
    if player.gui.center[locate_player_frame_name] then
        player.gui.center[locate_player_frame_name].destroy()
        remove_player_data(player)
        return
    end
end

local function validate_player(player)
    if not player then
        return false
    end
    if not player.valid then
        return false
    end
    return true
end

local function validate_frame(frame)
    if not frame then
        return false
    end
    if not frame.valid then
        return false
    end

    return true
end

local function create_mini_camera_gui(player, target)
    if not player or not player.valid then
        return
    end

    if player.gui.center[locate_player_frame_name] then
        player.gui.center[locate_player_frame_name].destroy()
        remove_player_data(player)
        return
    end

    if validate_player(target) then
        local player_data = create_player_data(player)
        player_data.target = target
    else
        remove_player_data(player)
        return
    end

    local frame = player.gui.center[locate_player_frame_name]
    if not validate_frame(frame) then
        frame = player.gui.center.add({type = 'frame', name = locate_player_frame_name, caption = target.name})
    end

    local surface = tonumber(target.surface.index)

    if frame[player_frame_name] and frame[player_frame_name].valid then
        frame[player_frame_name].destroy()
    end

    local camera =
        frame.add(
        {
            type = 'camera',
            name = player_frame_name,
            position = target.position,
            zoom = 0.4,
            surface_index = surface
        }
    )
    local res = player.display_resolution
    camera.style.minimal_width = res.width * 0.6
    camera.style.minimal_height = res.height * 0.6
    local player_data = create_player_data(player)
    player_data.camera_frame = camera
end

local function on_nth_tick()
    for p, data in pairs(this.players) do
        if data and data.target and data.target.valid then
            local target = data.target
            local camera_frame = data.camera_frame
            local player = game.get_player(p)

            if not (validate_player(player) or validate_player(target)) then
                remove_player_data(player)
                goto continue
            end

            if not validate_frame(camera_frame) then
                remove_player_data(player)
                goto continue
            end

            camera_frame.position = target.position
            camera_frame.surface_index = target.surface.index

            ::continue::
        end
    end
end

Gui.on_click(
    locate_player_frame_name,
    function(event)
        remove_camera_frame(event.player)
    end
)

Gui.on_click(
    player_frame_name,
    function(event)
        remove_camera_frame(event.player)
    end
)

--- Disables the module.
---@param state boolean
function Public.module_disabled(state)
    this.module_disabled = state or false
end

Public.create_mini_camera_gui = create_mini_camera_gui
Public.remove_camera_frame = remove_camera_frame

Event.on_nth_tick(2, on_nth_tick)

return Public
