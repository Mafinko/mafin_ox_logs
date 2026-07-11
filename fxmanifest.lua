fx_version 'cerulean'
game 'gta5'
lua54 'yes'
server_only 'yes'

name 'mafin_ox_logs'
author 'Mafin'
description 'Server-side ox_inventory Discord webhook logs for item drops, pickups, sharing, stashes, trunks, and gloveboxes.'
version '1.0.0'

server_scripts {
    'config.lua',
    'server.lua'
}

dependency 'ox_inventory'
