fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kipchak_bodycam'
author 'Kipchak Studios'
description 'Kipchak Bodycam - Body camera, dashcam overlay and live view for emergency services'
version '1.0.1'
license 'MIT'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/logos/*',
    'html/fonts/*'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales/en.lua',
    'locales/tr.lua',
    'shared/utils.lua',
    'bridge/init.lua'
}

server_scripts {
    'server/sv_config.lua',
    'bridge/framework/qbox.lua',
    'bridge/framework/qbcore.lua',
    'bridge/framework/esx.lua',
    'bridge/inventory/ox.lua',
    'bridge/inventory/qb.lua',
    'bridge/inventory/esx.lua',
    'server/main.lua',
    'server/liveview.lua'
}

client_scripts {
    'client/main.lua',
    'client/dashcam.lua',
    'client/liveview.lua'
}

dependencies {
    'ox_lib'
}
