fx_version 'cerulean'
game 'gta5'

name        'fivem-admin-menu'
author      'aminerahik-dev'
version     '2.0.0'
description 'Professional multi-framework admin menu — ESX, QBCore, Standalone'
repository  'https://github.com/aminerahik-dev/fivem-admin-menu'


shared_scripts {
    'config.lua'
}


server_scripts {
    -- '@oxmysql/lib/MySQL.lua', -- uncomment if using oxmysql for persistent ban storage
    'server/database.lua',
    'server/permissions.lua',
    'server/logging.lua',
    'server/main.lua'
}


client_scripts {
    'client/main.lua'
}


ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

