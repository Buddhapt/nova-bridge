--[[
    NOVA Bridge - vRPex Client
    Só ativo quando BridgeConfig.Mode == 'vrpex'
    
    Implementa a API vRPex client-side mapeada para o NOVA Framework.
    Scripts acedem via Tunnel.getInterface("vRP").
]]

if BridgeConfig.Mode ~= 'vrpex' then return end

local isReady = false

CreateThread(function()
    while not exports['nova_core']:IsFrameworkReady() do Wait(100) end
    isReady = true
end)

-- ============================================================
-- HELPERS
-- ============================================================

-- Regista handlers Tunnel (client recebe chamadas do server)
local function registerClientTunnel(name, itable)
    for k, v in pairs(itable) do
        if type(v) == 'function' then
            RegisterNetEvent('vRP:tunnel:' .. name .. ':' .. k)
            AddEventHandler('vRP:tunnel:' .. name .. ':' .. k, function(rid, ...)
                if rid and rid ~= '' then
                    local rets = {v(...)}
                    TriggerServerEvent('vRP:tunnel_res:' .. rid, table.unpack(rets))
                else
                    v(...)
                end
            end)
        end
    end
end

-- ============================================================
-- vRP CLIENT INTERFACE (TUNNEL - chamada pelo server)
-- ============================================================

local vRPclient = {}

function vRPclient.teleport(x, y, z)
    local ped = PlayerPedId()
    SetEntityCoords(ped, x + 0.0, y + 0.0, z + 0.0, false, false, false, true)
end

function vRPclient.isInside()
    return GetInteriorFromEntity(PlayerPedId()) ~= 0
end

function vRPclient.getCamDirection()
    local heading = GetGameplayCamRelativeHeading()
    local pitch = GetGameplayCamRelativePitch()
    local x = -math.sin(heading * math.pi / 180.0) * math.abs(math.cos(pitch * math.pi / 180.0))
    local y = math.cos(heading * math.pi / 180.0) * math.abs(math.cos(pitch * math.pi / 180.0))
    local z = math.sin(pitch * math.pi / 180.0)
    return x, y, z
end

function vRPclient.getNearestPlayers(radius)
    radius = radius or 10.0
    local result = {}
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local players = GetActivePlayers()

    for _, pid in ipairs(players) do
        local ped = GetPlayerPed(pid)
        if ped ~= myPed then
            local dist = #(myCoords - GetEntityCoords(ped))
            if dist <= radius then
                result[GetPlayerServerId(pid)] = dist
            end
        end
    end
    return result
end

function vRPclient.getNearestPlayer(radius)
    radius = radius or 10.0
    local nearest = nil
    local nearestDist = radius
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local players = GetActivePlayers()

    for _, pid in ipairs(players) do
        local ped = GetPlayerPed(pid)
        if ped ~= myPed then
            local dist = #(myCoords - GetEntityCoords(ped))
            if dist < nearestDist then
                nearest = GetPlayerServerId(pid)
                nearestDist = dist
            end
        end
    end
    return nearest
end

function vRPclient.playAnim(upper, seq, looping)
    if type(seq) ~= 'table' then return end
    local ped = PlayerPedId()
    for _, anim in ipairs(seq) do
        if anim[1] and anim[2] then
            RequestAnimDict(anim[1])
            local timeout = 0
            while not HasAnimDictLoaded(anim[1]) and timeout < 5000 do
                Wait(10)
                timeout = timeout + 10
            end
            if HasAnimDictLoaded(anim[1]) then
                local flags = looping and 1 or 0
                if upper then flags = flags + 48 end
                TaskPlayAnim(ped, anim[1], anim[2], 8.0, -8.0, -1, flags, 0, false, false, false)
            end
        end
    end
end

function vRPclient.stopAnim(upper)
    local ped = PlayerPedId()
    if upper then
        ClearPedSecondaryTask(ped)
    else
        ClearPedTasks(ped)
    end
end

function vRPclient.playSound(dict, name)
    PlaySoundFrontend(-1, name, dict, true)
end

function vRPclient.playScreenEffect(effect, duration)
    StartScreenEffect(effect, 0, false)
    if duration and duration > 0 then
        SetTimeout(duration, function()
            StopScreenEffect(effect)
        end)
    end
end

function vRPclient.setHandcuffed(state)
    local ped = PlayerPedId()
    if state then
        SetEnableHandcuffs(ped, true)
        DisablePlayerFiring(ped, true)
    else
        SetEnableHandcuffs(ped, false)
        DisablePlayerFiring(ped, false)
    end
end

function vRPclient.setFreeze(state)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, state)
end

function vRPclient.notify(msg)
    exports['nova_core']:ClientNotify(msg, 'info')
end

function vRPclient.getPosition()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    return coords.x, coords.y, coords.z
end

function vRPclient.getSpeed()
    local ped = PlayerPedId()
    return GetEntitySpeed(ped) * 3.6
end

function vRPclient.getHealth()
    return GetEntityHealth(PlayerPedId())
end

-- Registar como Tunnel para que scripts acedam via Tunnel.getInterface("vRP")
registerClientTunnel('vRP', vRPclient)

-- ============================================================
-- EVENTOS BRIDGE (receber comandos do servidor)
-- ============================================================

RegisterNetEvent('vRP:bridge:teleport')
AddEventHandler('vRP:bridge:teleport', function(x, y, z)
    vRPclient.teleport(x, y, z)
end)

RegisterNetEvent('vRP:bridge:playAnim')
AddEventHandler('vRP:bridge:playAnim', function(upper, seq, looping)
    vRPclient.playAnim(upper, seq, looping)
end)

RegisterNetEvent('vRP:bridge:stopAnim')
AddEventHandler('vRP:bridge:stopAnim', function(upper)
    vRPclient.stopAnim(upper)
end)

RegisterNetEvent('vRP:bridge:playSound')
AddEventHandler('vRP:bridge:playSound', function(dict, name)
    vRPclient.playSound(dict, name)
end)

-- ============================================================
-- EVENTOS NOVA → vRP
-- ============================================================

RegisterNetEvent('nova:client:onPlayerLoaded', function(data)
    TriggerEvent('Active')
    TriggerEvent('vRP:playerSpawned')
end)

RegisterNetEvent('nova:client:onLogout', function()
    TriggerEvent('vRP:playerLogout')
end)

RegisterNetEvent('nova:client:updatePlayerData', function(data)
    -- vRP não tem evento genérico de update no client
end)

print('^2[NOVA Bridge] ^0vRPex Client bridge carregado')
