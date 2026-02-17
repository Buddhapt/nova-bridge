--[[
    NOVA Bridge - ESX Server
    Só ativo quando BridgeConfig.Mode == 'esx'
]]

if BridgeConfig.Mode ~= 'esx' then return end

local Nova = exports['nova_core']:GetObject()
local UsableItems = {}

-- ============================================================
-- xPLAYER WRAPPER
-- ============================================================

local function WrapPlayer(novaPlayer)
    if not novaPlayer then return nil end

    local xPlayer = {}

    xPlayer.source = novaPlayer:GetSource()
    xPlayer.identifier = novaPlayer.identifier
    xPlayer.name = novaPlayer.name
    xPlayer.group = novaPlayer.group
    xPlayer.citizenid = novaPlayer.citizenid

    local job = novaPlayer:GetJob()
    xPlayer.job = {
        name = job.name,
        label = job.label,
        grade = job.grade,
        grade_name = tostring(job.grade),
        grade_label = job.grade_label,
        grade_salary = job.salary or 0,
    }

    -- DINHEIRO

    function xPlayer.getMoney()
        local p = exports['nova_core']:GetPlayer(xPlayer.source)
        if p then return p:GetMoney('cash') end
        return 0
    end

    function xPlayer.getAccount(account)
        local p = exports['nova_core']:GetPlayer(xPlayer.source)
        if not p then return { name = account, money = 0, label = account } end
        local novaType = ESX.MapAccount(account)
        local amount = p:GetMoney(novaType)
        return {
            name = account,
            money = amount,
            label = account:sub(1, 1):upper() .. account:sub(2),
        }
    end

    function xPlayer.getAccounts()
        local p = exports['nova_core']:GetPlayer(xPlayer.source)
        local accounts = {}
        local accountList = {
            { name = 'money', novaType = 'cash' },
            { name = 'bank', novaType = 'bank' },
            { name = 'black_money', novaType = 'black_money' },
        }
        for _, acc in ipairs(accountList) do
            local amount = p and p:GetMoney(acc.novaType) or 0
            accounts[#accounts + 1] = {
                name = acc.name, money = amount,
                label = acc.name:sub(1, 1):upper() .. acc.name:sub(2),
            }
        end
        return accounts
    end

    function xPlayer.addMoney(amount, reason)
        local p = exports['nova_core']:GetPlayer(xPlayer.source)
        if p then p:AddMoney('cash', amount, reason or 'esx_bridge') end
    end

    function xPlayer.removeMoney(amount, reason)
        local p = exports['nova_core']:GetPlayer(xPlayer.source)
        if p then p:RemoveMoney('cash', amount, reason or 'esx_bridge') end
    end

    function xPlayer.addAccountMoney(account, amount, reason)
        local p = exports['nova_core']:GetPlayer(xPlayer.source)
        if p then p:AddMoney(ESX.MapAccount(account), amount, reason or 'esx_bridge') end
    end

    function xPlayer.removeAccountMoney(account, amount, reason)
        local p = exports['nova_core']:GetPlayer(xPlayer.source)
        if p then p:RemoveMoney(ESX.MapAccount(account), amount, reason or 'esx_bridge') end
    end

    function xPlayer.setAccountMoney(account, amount)
        local p = exports['nova_core']:GetPlayer(xPlayer.source)
        if p then p:SetMoney(ESX.MapAccount(account), amount) end
    end

    -- EMPREGO

    function xPlayer.getJob()
        local p = exports['nova_core']:GetPlayer(xPlayer.source)
        if not p then return xPlayer.job end
        local j = p:GetJob()
        return {
            name = j.name, label = j.label, grade = j.grade,
            grade_name = tostring(j.grade), grade_label = j.grade_label,
            grade_salary = j.salary or 0,
        }
    end

    function xPlayer.setJob(name, grade)
        local p = exports['nova_core']:GetPlayer(xPlayer.source)
        if p then
            p:SetJob(name, grade or 0)
            local j = p:GetJob()
            xPlayer.job = {
                name = j.name, label = j.label, grade = j.grade,
                grade_name = tostring(j.grade), grade_label = j.grade_label,
                grade_salary = j.salary or 0,
            }
        end
    end

    -- INVENTÁRIO

    function xPlayer.getInventory()
        local p = exports['nova_core']:GetPlayer(xPlayer.source)
        if not p then return {} end
        local inv = p:GetInventory()
        local result = {}
        for _, item in pairs(inv) do
            result[#result + 1] = {
                name = item.name, label = item.label or item.name,
                count = item.amount or item.count or 0,
                weight = item.weight or 0, metadata = item.metadata or {},
            }
        end
        return result
    end

    function xPlayer.getInventoryItem(name)
        local p = exports['nova_core']:GetPlayer(xPlayer.source)
        if not p then return { name = name, label = name, count = 0 } end
        local count = p:GetItemCount(name)
        local itemData = exports['nova_core']:GetItems()
        local item = itemData and itemData[name]
        return {
            name = name, label = item and item.label or name,
            count = count, weight = item and item.weight or 0,
        }
    end

    function xPlayer.addInventoryItem(name, count, metadata)
        local p = exports['nova_core']:GetPlayer(xPlayer.source)
        if p then p:AddItem(name, count, metadata) end
    end

    function xPlayer.removeInventoryItem(name, count)
        local p = exports['nova_core']:GetPlayer(xPlayer.source)
        if p then p:RemoveItem(name, count) end
    end

    function xPlayer.canCarryItem(name, count) return true end
    function xPlayer.canSwapItem(firstItem, firstCount, testItem, testCount) return true end

    -- METADATA

    function xPlayer.set(key, value)
        local p = exports['nova_core']:GetPlayer(xPlayer.source)
        if p then p:SetMetadata(key, value) end
    end

    function xPlayer.get(key)
        local p = exports['nova_core']:GetPlayer(xPlayer.source)
        if p then return p:GetMetadata(key) end
        return nil
    end

    function xPlayer.setMeta(key, value) xPlayer.set(key, value) end
    function xPlayer.getMeta(key) return xPlayer.get(key) end

    -- INFORMAÇÕES

    function xPlayer.getName()
        local p = exports['nova_core']:GetPlayer(xPlayer.source)
        if p then return p:GetFullName() end
        return xPlayer.name
    end

    function xPlayer.getIdentifier() return xPlayer.identifier end

    function xPlayer.getGroup()
        local p = exports['nova_core']:GetPlayer(xPlayer.source)
        if p then return p.group end
        return xPlayer.group
    end

    function xPlayer.setGroup(group)
        local p = exports['nova_core']:GetPlayer(xPlayer.source)
        if p then p.group = group; xPlayer.group = group end
    end

    function xPlayer.getCoords(vector)
        local ped = GetPlayerPed(xPlayer.source)
        if ped and DoesEntityExist(ped) then
            local coords = GetEntityCoords(ped)
            if vector then return coords end
            return { x = coords.x, y = coords.y, z = coords.z }
        end
        return vector3(0, 0, 0)
    end

    -- AÇÕES

    function xPlayer.kick(reason)
        local p = exports['nova_core']:GetPlayer(xPlayer.source)
        if p then p:Kick(reason) end
    end

    function xPlayer.ban(reason)
        local p = exports['nova_core']:GetPlayer(xPlayer.source)
        if p then p:Ban(reason) end
    end

    function xPlayer.showNotification(msg)
        exports['nova_core']:Notify(xPlayer.source, msg, 'info')
    end

    function xPlayer.showHelpNotification(msg, thisFrame, beep, duration)
        exports['nova_core']:Notify(xPlayer.source, msg, 'info', duration)
    end

    function xPlayer.triggerEvent(eventName, ...)
        TriggerClientEvent(eventName, xPlayer.source, ...)
    end

    function xPlayer.save()
        local p = exports['nova_core']:GetPlayer(xPlayer.source)
        if p then p:Save() end
    end

    return xPlayer
end

-- ============================================================
-- FUNÇÕES ESX GLOBAIS
-- ============================================================

function ESX.GetPlayerFromId(source)
    local novaPlayer = exports['nova_core']:GetPlayer(source)
    return WrapPlayer(novaPlayer)
end

function ESX.GetPlayerFromIdentifier(identifier)
    local novaPlayers = exports['nova_core']:GetPlayers()
    for _, data in ipairs(novaPlayers) do
        if data.player and data.player.identifier == identifier then
            return WrapPlayer(data.player)
        end
    end
    return nil
end

function ESX.GetPlayers()
    local novaPlayers = exports['nova_core']:GetPlayers()
    local sources = {}
    for _, data in ipairs(novaPlayers) do
        sources[#sources + 1] = data.source
    end
    return sources
end

function ESX.GetExtendedPlayers(key, val)
    local novaPlayers = exports['nova_core']:GetPlayers()
    local result = {}
    for _, data in ipairs(novaPlayers) do
        local xPlayer = WrapPlayer(data.player)
        if xPlayer then
            if not key then
                result[#result + 1] = xPlayer
            elseif key == 'job' and xPlayer.job and xPlayer.job.name == val then
                result[#result + 1] = xPlayer
            elseif key == 'group' and xPlayer.group == val then
                result[#result + 1] = xPlayer
            end
        end
    end
    return result
end

function ESX.GetPlayerCount()
    return #ESX.GetPlayers()
end

-- CALLBACKS

function ESX.RegisterServerCallback(name, cb)
    exports['nova_core']:CreateCallback(name, cb)
end

function ESX.TriggerServerCallback(name, source, cb, ...)
    local novaCallbacks = Nova and Nova.ServerCallbacks
    if novaCallbacks and novaCallbacks[name] then
        novaCallbacks[name](source, cb, ...)
    end
end

-- ITEMS USÁVEIS

function ESX.RegisterUsableItem(name, cb) UsableItems[name] = cb end
function ESX.UseItem(source, name)
    if UsableItems[name] then UsableItems[name](source) end
end

function ESX.Trace(msg)
    print('^3[ESX Bridge] ^0' .. tostring(msg))
end

-- ============================================================
-- EVENTOS NOVA → ESX
-- ============================================================

AddEventHandler('nova:server:onPlayerLoaded', function(source, novaPlayer)
    local xPlayer = WrapPlayer(novaPlayer)
    if xPlayer then
        TriggerEvent('esx:playerLoaded', source, xPlayer)
        TriggerClientEvent('esx:playerLoaded', source, xPlayer.getAccounts(), xPlayer.getInventory(), xPlayer.getJob())
    end
end)

AddEventHandler('nova:server:onJobChange', function(source, newJob, oldJob)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        TriggerEvent('esx:setJob', source, xPlayer.getJob(), oldJob)
        TriggerClientEvent('esx:setJob', source, xPlayer.getJob())
    end
end)

AddEventHandler('nova:server:onPlayerDropped', function(source, citizenid, reason)
    TriggerEvent('esx:playerDropped', source, reason)
end)

AddEventHandler('nova:server:onPlayerLogout', function(source, citizenid)
    TriggerEvent('esx:playerLogout', source)
    TriggerClientEvent('esx:onPlayerLogout', source)
end)

AddEventHandler('nova:server:onMoneyChange', function(source, moneyType, action)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        local esxAccount = ESX.AccountMapReverse[moneyType] or moneyType
        TriggerEvent('esx:setAccountMoney', source, xPlayer.getAccount(esxAccount))
    end
end)

-- EXPORTS

exports('getSharedObject', function() return ESX end)

RegisterNetEvent('esx:getSharedObject', function()
    TriggerClientEvent('esx:getSharedObject', source)
end)

RegisterNetEvent('esx:useItem', function(name)
    local source = source
    if UsableItems[name] then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            UsableItems[name](source, name, xPlayer.getInventoryItem(name))
        end
    end
end)

print('^2[NOVA Bridge] ^0ESX Server bridge carregado')
