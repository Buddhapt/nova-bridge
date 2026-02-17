--[[
    NOVA Bridge - Compatibility Layer Unificado
    Permite usar scripts feitos para ESX, QBCore, vRPex ou Creative com o NOVA Framework.
    
    Configuração em config.lua:
    - BridgeConfig.Mode = 'esx'      → Scripts ESX funcionam
    - BridgeConfig.Mode = 'qbcore'   → Scripts QBCore funcionam
    - BridgeConfig.Mode = 'vrpex'    → Scripts vRPex funcionam
    - BridgeConfig.Mode = 'creative' → Scripts Creative funcionam
    - BridgeConfig.Mode = 'none'     → Sem bridge
]]

fx_version 'cerulean'
game 'gta5'

name 'nova_bridge'
description 'NOVA Framework - ESX, QBCore, vRPex & Creative Compatibility Bridge'
author 'NOVA Development'
version '2.0.0'
lua54 'yes'

shared_scripts {
    'config.lua',
    'shared/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/esx.lua',
    'server/qb.lua',
    'server/vrpex.lua',
    'server/creative.lua',
}

client_scripts {
    'client/esx.lua',
    'client/qb.lua',
    'client/vrpex.lua',
    'client/creative.lua',
}

dependencies {
    'nova_core',
}

-- Provide todos: o runtime decide qual ativar via config
provide 'es_extended'
provide 'qb-core'
provide 'vrp'
