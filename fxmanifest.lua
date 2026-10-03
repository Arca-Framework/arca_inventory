fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'arca_inventory'
author 'Arca'
description 'Container-based inventory for the Arca framework'
version '0.1.0'

shared_scripts {
    '@arca_core/shared/import.lua',
    'config.lua',
    'shared/items.lua',
}

client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/usable.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/images/*.png',
}

dependencies {
    'oxmysql',
    'arca_core',
}
