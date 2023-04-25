require 'utils.data_stages'
_LIFECYCLE = _STAGE.control -- Control stage
_DEBUG = false
_DUMP_ENV = false

require 'utils.server'
require 'utils.server_commands'
require 'utils.command_handler'
require 'utils.utils'
require 'utils.pause_game'
require 'utils.table'
require 'utils.datastore.server_ups_data'
require 'utils.datastore.current_time_data'
require 'utils.datastore.color_data'
require 'utils.datastore.session_data'
require 'utils.datastore.jail_data'
require 'utils.datastore.quickbar_data'
require 'utils.datastore.message_on_join_data'
require 'utils.datastore.player_tag_data'
require 'utils.datastore.supporters'
require 'utils.datastore.banhandler'
require 'utils.chatbot'
require 'utils.commands'
require 'utils.antigrief'
require 'utils.debug.command'
require 'modules.corpse_markers'
require 'modules.floaty_chat'
require 'modules.show_inventory'
require 'modules.inserter_drops_pickup'
require 'modules.autostash'
require 'modules.blueprint_requesting'

require 'utils.gui'
require 'utils.gui.player_list'
require 'utils.gui.admin'
require 'utils.gui.group'
require 'utils.gui.score'
require 'utils.gui.config'
require 'utils.gui.poll'
require 'utils.freeplay'

require 'maps.wasteland.main'

if _DUMP_ENV then
    require 'utils.dump_env'
    require 'utils.profiler'
end

local function on_player_created(event)
    local player = game.players[event.player_index]
    player.gui.top.style = 'slot_table_spacing_horizontal_flow'
    player.gui.left.style = 'slot_table_spacing_vertical_flow'
end

local loaded = _G.package.loaded
function require(path)
    return loaded[path] or error('Can only require files at runtime that have been required in the control stage.', 2)
end

local Event = require 'utils.event'
Event.add(defines.events.on_player_created, on_player_created)
