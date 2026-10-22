fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'JGR Studio'
description 'JGR_IlegalSystem - Sistema ilegal modular: bandas, cultivo de marihuana, procesado y Grow Shop'
version '1.1.0'
jgr_version_key 'JGR_IlegalSystem'
repository 'https://github.com/jgr-ry/JGR_IlegalSystem'

ui_page 'ui/index.html'

-- Solo dependencias comunes: el framework (QBCore, Qbox, ESX o ninguno) se detecta en bridge/bridge.lua
dependencies {
    'ox_lib',
    'oxmysql',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config/config.lua',
    'config/locales/es.lua',
    'bridge/bridge.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/main.lua',
    'modules/gangs/client/classes/GhostPed.lua',
    'modules/gangs/client/creator.lua',
    'modules/gangs/client/menu.lua',
    'modules/gangs/client/npc.lua',
    'modules/gangs/client/admin.lua',
    'modules/growshop/client/consumables.lua',
    'modules/growshop/client/menu.lua',
    'modules/growshop/client/logistics.lua',
    'modules/drugs/client/growing.lua',
    'modules/drugs/client/processing.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/init.lua',
    'server/version_check.lua',
    'bridge/server.lua',
    'server/sql.lua',
    'server/main.lua',
    'modules/gangs/server/creator.lua',
    'modules/gangs/server/admin.lua',
    'modules/gangs/server/menu.lua',
    'modules/growshop/server/roles.lua',
    'modules/growshop/server/consumables.lua',
    'modules/growshop/server/menu.lua',
    'modules/growshop/server/management.lua',
    'modules/drugs/server/growing.lua',
    'modules/drugs/server/processing.lua',
}

files {
    'ui/index.html',
    'ui/style.css',
    'ui/script.js',
    'ui/assets/**/*',
}

escrow_ignore {
    'config/*',
    'bridge/*',
}
