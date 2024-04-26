local gs_store = require 'game_settings_store'

-- Load initial settings form previous rounds if they exist
global.game_mode = gs_store.game_mode
global.last_winner_name = gs_store.last_winner_name
global.auto_reset_enabled = gs_store.auto_reset_enabled
