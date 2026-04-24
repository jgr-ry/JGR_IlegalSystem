fx_version 'cerulean'
game 'gta5'

author 'JGR Studio'
description 'JGR_IlegalSystem - Advanced Integrated Illegal Roles System'
version '1.0.0'

ui_page 'ui/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'config/config.lua',
    'config/locales/es.lua',
    'bridge/bridge.lua',
}

client_scripts {
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
    'server/version_check.lua',
    '@oxmysql/lib/MySQL.lua',
    'server/sql.lua',
    'server/main.lua',
    'modules/gangs/server/creator.lua',
    'modules/gangs/server/admin.lua',
    'modules/gangs/server/menu.lua',
    'modules/growshop/server/consumables.lua',
    'modules/growshop/server/menu.lua',
    'modules/growshop/server/management.lua',
    'modules/drugs/server/growing.lua',
    'modules/drugs/server/processing.lua',
}

files {
    'jgr_ilegalsystem.sql',
    'ui/index.html',
    'ui/style.css',
    'ui/script.js',
    'ui/assets/**/*'
}

escrow_ignore {
    'config/*'
}

lua54 'yes'
