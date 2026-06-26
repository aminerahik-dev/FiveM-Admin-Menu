fx_version 'cerulean'
game 'gta5'

name        'FiveM-Admin-Menu'
author      'aminerahik-dev'
version     '2.0.0'
description 'Professional multi-framework admin menu — ESX, QBCore, Standalone'
repository  'https://github.com/aminerahik-dev/FiveM-Admin-Menu'

-- Shared
shared_scripts {
    'config.lua'
}

-- Server
server_scripts {
    -- '@oxmysql/lib/MySQL.lua', -- uncomment if using oxmysql for persistent ban storage
    'server/database.lua',
    'server/permissions.lua',
    'server/logging.lua',
    'server/main.lua'
}

-- Client
client_scripts {
    'client/main.lua'
}

-- NUI
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

-- Lua 5.4
lua54 'yes'