fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author "BOGi"
name "Vehicle wheel station"
description "The Underground - Wheel station"
version "4.2.0"

shared_scripts {
    '@ox_lib/init.lua',
    'config/cfg_settings.lua',
    'config/cfg_zones.lua',
    'shared/sh_framework.lua'
}

client_scripts {
    'client/cl_main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_discord.lua',
    'server/sv_main.lua'
}

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

dependencies {
    'ox_lib'
}

