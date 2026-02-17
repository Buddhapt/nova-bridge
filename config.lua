--[[
    NOVA Bridge - Configuração
    
    Define qual bridge ativar para compatibilidade com scripts existentes.
    
    Modos disponíveis:
    - 'esx'      → Ativa compatibilidade com scripts ESX (es_extended)
    - 'qbcore'   → Ativa compatibilidade com scripts QBCore (qb-core)
    - 'vrpex'    → Ativa compatibilidade com scripts vRPex
    - 'creative' → Ativa compatibilidade com scripts Creative (vRP-based)
    - 'none'     → Desativa bridges (só usas scripts nativos NOVA)
]]

BridgeConfig = {
    Mode = 'esx',  -- 'esx', 'qbcore', 'vrpex', 'creative', ou 'none'
}
