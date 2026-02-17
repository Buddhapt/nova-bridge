--[[
    NOVA Bridge - Shared
    Inicializa os objetos globais baseado no modo configurado.
    Apenas o bridge selecionado é ativado.
]]

local mode = BridgeConfig and BridgeConfig.Mode or 'none'

-- ============================================================
-- ESX GLOBALS (só se mode == 'esx')
-- ============================================================

if mode == 'esx' then
    ESX = {}
    ESX.PlayerData = {}
    ESX.PlayerLoaded = false

    ESX.AccountMap = {
        money = 'cash',
        cash = 'cash',
        bank = 'bank',
        black_money = 'black_money',
        dirty_money = 'black_money',
    }

    ESX.AccountMapReverse = {
        cash = 'money',
        bank = 'bank',
        black_money = 'black_money',
    }

    function ESX.MapAccount(account)
        return ESX.AccountMap[account] or account
    end

    function ESX.GetSharedObject()
        return ESX
    end

    print('^2[NOVA Bridge] ^0Modo ESX ativado')
end

-- ============================================================
-- QBCORE GLOBALS (só se mode == 'qbcore')
-- ============================================================

if mode == 'qbcore' then
    QBCore = {}
    QBCore.Functions = {}
    QBCore.Players = {}
    QBCore.Player = {}
    QBCore.Config = {}
    QBCore.Shared = {}
    QBCore.Commands = {}

    QBCore.Config.Money = {
        MoneyTypes = { cash = 'cash', bank = 'bank', crypto = 'black_money' },
        DefaultMoney = { cash = 5000, bank = 10000, crypto = 0 },
        DontAllowMinus = { 'cash', 'bank' },
    }

    QBCore.Shared.Items = {}
    QBCore.Shared.Jobs = {}
    QBCore.Shared.Gangs = {}
    QBCore.Shared.Vehicles = {}
    QBCore.Shared.Weapons = {}

    function QBCore.GetCoreObject()
        return QBCore
    end

    print('^2[NOVA Bridge] ^0Modo QBCore ativado')
end

-- ============================================================
-- vRPex / CREATIVE GLOBALS (só se mode == 'vrpex' ou 'creative')
-- ============================================================

if mode == 'vrpex' or mode == 'creative' then
    -- O vRP usa um sistema de Proxy/Tunnel em vez de globals directos.
    -- Os globals vRP são configurados pelo sistema Proxy quando
    -- scripts carregam module("vrp", "lib/Proxy") e chamam
    -- Proxy.getInterface("vRP").
    --
    -- Os ficheiros lib/Proxy.lua, lib/Tunnel.lua e lib/utils.lua
    -- são fornecidos para scripts via @vrp/lib/... (pois provide 'vrp').
    --
    -- A interface vRP é registada nos ficheiros server/vrpex.lua
    -- ou server/creative.lua via registerProxyInterface().

    local modeLabel = mode == 'vrpex' and 'vRPex' or 'Creative'
    print('^2[NOVA Bridge] ^0Modo ' .. modeLabel .. ' ativado (Proxy/Tunnel)')
end

-- ============================================================
-- NONE
-- ============================================================

if mode == 'none' then
    print('^3[NOVA Bridge] ^0Modo: nenhum bridge ativo')
end
