--[[
    NOVA Bridge - vRPex Server
    Só ativo quando BridgeConfig.Mode == 'vrpex'
    
    Implementa a API vRPex mapeada para o NOVA Framework.
    Scripts vRP acedem via Proxy.getInterface("vRP").
]]

if BridgeConfig.Mode ~= 'vrpex' then return end

-- ============================================================
-- HELPERS
-- ============================================================

local Nova = exports['nova_core']

-- Mapeamento user_id ↔ source
local userIdToSource = {}
local sourceToUserId = {}

-- Data tables de sessão por user_id
local dataTables = {}

-- Prepared statements
local preparedQueries = {}

-- Server data cache
local serverData = {}

local function getPlayerByUserId(user_id)
    local src = userIdToSource[user_id]
    if not src then return nil end
    return Nova:GetPlayer(src)
end

local function getSourceByUserId(user_id)
    return userIdToSource[user_id]
end

-- Regista handlers Proxy para uma interface
local function registerProxyInterface(name, itable)
    for k, v in pairs(itable) do
        if type(v) == 'function' then
            AddEventHandler('vRP:proxy:' .. name .. ':' .. k, function(rid, ...)
                if rid and rid ~= '' then
                    local rets = {v(...)}
                    TriggerEvent('vRP:proxy_res:' .. rid, table.unpack(rets))
                else
                    v(...)
                end
            end)
        end
    end
end

-- Regista handlers Tunnel (server recebe chamadas do client)
local function registerServerTunnel(name, itable)
    for k, v in pairs(itable) do
        if type(v) == 'function' then
            RegisterNetEvent('vRP:tunnel:' .. name .. ':' .. k)
            AddEventHandler('vRP:tunnel:' .. name .. ':' .. k, function(rid, ...)
                local _source = source
                if rid and rid ~= '' then
                    local rets = {v(...)}
                    TriggerClientEvent('vRP:tunnel_res:' .. rid, _source, table.unpack(rets))
                else
                    v(...)
                end
            end)
        end
    end
end

-- ============================================================
-- vRP INTERFACE (SERVER-SIDE PROXY)
-- ============================================================

local vRP = {}

-- ============================
-- JOGADORES
-- ============================

function vRP.getUserId(source)
    if not source or source <= 0 then return nil end
    local player = Nova:GetPlayer(source)
    if not player then return nil end
    local user_id = player.userId or tonumber(player.citizenid) or source
    -- Atualizar mapeamento
    userIdToSource[user_id] = source
    sourceToUserId[source] = user_id
    -- Inicializar datatable se não existir
    if not dataTables[user_id] then
        dataTables[user_id] = {}
    end
    return user_id
end

function vRP.getUserSource(user_id)
    return userIdToSource[user_id]
end

function vRP.getUsers()
    local users = {}
    local novaPlayers = Nova:GetPlayers()
    if novaPlayers then
        for _, data in ipairs(novaPlayers) do
            if data.player then
                local uid = data.player.userId or tonumber(data.player.citizenid) or data.source
                users[uid] = data.source
                userIdToSource[uid] = data.source
                sourceToUserId[data.source] = uid
            end
        end
    end
    return users
end

function vRP.getUserDataTable(user_id)
    if not dataTables[user_id] then
        dataTables[user_id] = {}
    end
    return dataTables[user_id]
end

function vRP.setKeyDataTable(user_id, key, value)
    if not dataTables[user_id] then
        dataTables[user_id] = {}
    end
    dataTables[user_id][key] = value
end

function vRP.getIdentifiers(source)
    local ids = {}
    local numIds = GetNumPlayerIdentifiers(source)
    for i = 0, numIds - 1 do
        local id = GetPlayerIdentifier(source, i)
        if id then
            local prefix = string.match(id, '^([^:]+):')
            if prefix then
                ids[prefix] = id
            end
        end
    end
    return ids
end

function vRP.getUserIdByIdentifiers(ids)
    -- Retorna user_id baseado em identifiers
    -- Procura jogador online com esses identifiers
    local novaPlayers = Nova:GetPlayers()
    if novaPlayers then
        for _, data in ipairs(novaPlayers) do
            if data.player and data.player.identifier then
                for _, id in pairs(ids) do
                    if string.find(id, data.player.identifier) then
                        return data.player.userId or tonumber(data.player.citizenid) or data.source
                    end
                end
            end
        end
    end
    return nil
end

function vRP.kick(source, reason)
    local player = Nova:GetPlayer(source)
    if player then player:Kick(reason or 'Kicked') end
end

function vRP.dropPlayer(source, reason)
    DropPlayer(source, reason or 'Disconnected')
end

-- ============================
-- IDENTIDADE
-- ============================

function vRP.getUserIdentity(user_id)
    local player = getPlayerByUserId(user_id)
    if not player then return nil end
    return {
        name = player.charinfo.firstname,
        firstname = player.charinfo.firstname,
        name2 = player.charinfo.lastname,
        lastname = player.charinfo.lastname,
        age = player.charinfo.dateofbirth or '01/01/2000',
        registration = player.citizenid,
        phone = player.charinfo.phone or '000-0000',
        rh = player:GetMetadata('blood_type') or 'O+',
    }
end

function vRP.getUserByRegistration(registration)
    local novaPlayers = Nova:GetPlayers()
    if novaPlayers then
        for _, data in ipairs(novaPlayers) do
            if data.player and data.player.citizenid == registration then
                return vRP.getUserIdentity(sourceToUserId[data.source] or data.source)
            end
        end
    end
    return nil
end

function vRP.getUserByPhone(phone)
    local novaPlayers = Nova:GetPlayers()
    if novaPlayers then
        for _, data in ipairs(novaPlayers) do
            if data.player and data.player.charinfo and data.player.charinfo.phone == phone then
                return vRP.getUserIdentity(sourceToUserId[data.source] or data.source)
            end
        end
    end
    return nil
end

function vRP.generateStringNumber(format)
    local result = ''
    for i = 1, #format do
        local c = format:sub(i, i)
        if c == 'D' then
            result = result .. tostring(math.random(0, 9))
        elseif c == 'L' then
            result = result .. string.char(math.random(65, 90))
        else
            result = result .. c
        end
    end
    return result
end

function vRP.generateRegistrationNumber()
    return vRP.generateStringNumber('LLLDDDD')
end

function vRP.generatePhoneNumber()
    return vRP.generateStringNumber('DDDD-DDDD')
end

function vRP.generateUserRH()
    local types = {'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'}
    return types[math.random(1, #types)]
end

-- ============================
-- DINHEIRO
-- ============================

function vRP.getMoney(user_id)
    local player = getPlayerByUserId(user_id)
    if not player then return 0 end
    return player:GetMoney('cash')
end

function vRP.giveMoney(user_id, value)
    local player = getPlayerByUserId(user_id)
    if not player then return end
    player:AddMoney('cash', value, 'vrp_bridge')
end

function vRP.tryPayment(user_id, value)
    local player = getPlayerByUserId(user_id)
    if not player then return false end
    if player:GetMoney('cash') >= value then
        return player:RemoveMoney('cash', value, 'vrp_bridge')
    end
    return false
end

function vRP.getBankMoney(user_id)
    local player = getPlayerByUserId(user_id)
    if not player then return 0 end
    return player:GetMoney('bank')
end

function vRP.giveBankMoney(user_id, value)
    local player = getPlayerByUserId(user_id)
    if not player then return end
    player:AddMoney('bank', value, 'vrp_bridge')
end

function vRP.tryBankPayment(user_id, value)
    local player = getPlayerByUserId(user_id)
    if not player then return false end
    if player:GetMoney('bank') >= value then
        return player:RemoveMoney('bank', value, 'vrp_bridge')
    end
    return false
end

function vRP.setBankMoney(user_id, value)
    local player = getPlayerByUserId(user_id)
    if not player then return end
    player:SetMoney('bank', value)
end

function vRP.getAllMoney(user_id)
    local player = getPlayerByUserId(user_id)
    if not player then return 0 end
    return player:GetMoney('cash') + player:GetMoney('bank')
end

function vRP.tryFullPayment(user_id, value)
    local player = getPlayerByUserId(user_id)
    if not player then return false end
    local cash = player:GetMoney('cash')
    if cash >= value then
        return player:RemoveMoney('cash', value, 'vrp_bridge')
    end
    local bank = player:GetMoney('bank')
    if cash + bank >= value then
        local remaining = value - cash
        if cash > 0 then player:RemoveMoney('cash', cash, 'vrp_bridge') end
        return player:RemoveMoney('bank', remaining, 'vrp_bridge')
    end
    return false
end

function vRP.tryWithdraw(user_id, value)
    local player = getPlayerByUserId(user_id)
    if not player then return false end
    if player:GetMoney('bank') >= value then
        player:RemoveMoney('bank', value, 'vrp_bridge')
        player:AddMoney('cash', value, 'vrp_bridge')
        return true
    end
    return false
end

function vRP.tryDeposit(user_id, value)
    local player = getPlayerByUserId(user_id)
    if not player then return false end
    if player:GetMoney('cash') >= value then
        player:RemoveMoney('cash', value, 'vrp_bridge')
        player:AddMoney('bank', value, 'vrp_bridge')
        return true
    end
    return false
end

-- ============================
-- INVENTÁRIO
-- ============================

function vRP.giveInventoryItem(user_id, idname, amount, slot, notify)
    local player = getPlayerByUserId(user_id)
    if not player then return false, nil end
    local success = player:AddItem(idname, amount)
    return success, slot
end

function vRP.tryGetInventoryItem(user_id, idname, amount, slot, notify)
    local player = getPlayerByUserId(user_id)
    if not player then return false end
    if player:GetItemCount(idname) >= amount then
        return player:RemoveItem(idname, amount)
    end
    return false
end

function vRP.getInventoryItemAmount(user_id, idname)
    local player = getPlayerByUserId(user_id)
    if not player then return 0 end
    return player:GetItemCount(idname)
end

function vRP.getInventory(user_id)
    local player = getPlayerByUserId(user_id)
    if not player then return {} end
    return player:GetInventory()
end

function vRP.getInventoryWeight(user_id)
    local player = getPlayerByUserId(user_id)
    if not player then return 0 end
    local inv = player:GetInventory()
    local weight = 0
    for _, item in pairs(inv) do
        weight = weight + (item.weight or 0) * (item.amount or item.count or 1)
    end
    return weight
end

function vRP.getInventoryMaxWeight(user_id)
    return 120000 -- Peso máximo padrão
end

function vRP.setInventoryMaxWeight(user_id, max)
    -- Stub: delegar ao sistema de inventário se disponível
end

function vRP.varyInventoryMaxWeight(user_id, vary)
    -- Stub
end

function vRP.getInventoryMaxSlots(user_id)
    return 41 -- Slots padrão
end

function vRP.setInventoryMaxSlots(user_id, max)
    -- Stub
end

function vRP.varyInventoryMaxSlots(user_id, vary)
    -- Stub
end

function vRP.clearInventory(user_id)
    -- Stub: limpar inventário requer acesso ao nova_inventory
    print('^3[NOVA Bridge] ^0clearInventory: requer implementação no nova_inventory')
end

function vRP.itemExists(item)
    local ok, result = pcall(function() return Nova:GetItems() end)
    if ok and result then
        return result[item] ~= nil
    end
    return false
end

function vRP.itemNameList(item)
    local ok, items = pcall(function() return Nova:GetItems() end)
    if ok and items and items[item] then
        return items[item].label or item
    end
    return item
end

function vRP.itemIndexList(item)
    return item
end

function vRP.itemTypeList(item)
    local ok, items = pcall(function() return Nova:GetItems() end)
    if ok and items and items[item] then
        return items[item].type or 'item'
    end
    return 'item'
end

function vRP.getItemWeight(item)
    local ok, items = pcall(function() return Nova:GetItems() end)
    if ok and items and items[item] then
        return items[item].weight or 0
    end
    return 0
end

function vRP.itemDurability(item)
    return 30, 100 -- days, usages padrão
end

function vRP.maxItem(item)
    return 999
end

function vRP.calcDurability(data)
    return 100 -- 100% durabilidade
end

-- ============================
-- GRUPOS & PERMISSÕES
-- ============================

function vRP.getUserGroups(user_id)
    local player = getPlayerByUserId(user_id)
    if not player then return {} end
    local groups = {}
    local job = player:GetJob()
    if job and job.name then
        groups[job.name] = {grade = job.grade}
    end
    local gang = player:GetGang()
    if gang and gang.name and gang.name ~= 'none' then
        groups[gang.name] = {grade = gang.grade}
    end
    if player.group and player.group ~= 'user' then
        groups[player.group] = {grade = 0}
    end
    return groups
end

function vRP.hasGroup(user_id, group)
    local groups = vRP.getUserGroups(user_id)
    if groups[group] then
        return true, groups[group].grade or 0
    end
    return false, nil
end

function vRP.hasGroupActive(user_id, group)
    return vRP.hasGroup(user_id, group)
end

function vRP.setGroupActive(user_id, group, active)
    -- Stub: NOVA não tem conceito de grupo ativo/inativo
end

function vRP.addUserGroup(user_id, group, grade)
    local player = getPlayerByUserId(user_id)
    if not player then return end
    grade = grade or 0
    -- Tentar definir como job primeiro
    local ok = pcall(function()
        local jobs = Nova:GetJobs()
        if jobs and jobs[group] then
            player:SetJob(group, grade)
            return
        end
    end)
    if not ok then
        -- Tentar como gang
        pcall(function()
            local gangs = Nova:GetGangs()
            if gangs and gangs[group] then
                player:SetGang(group, grade)
            end
        end)
    end
end

function vRP.removeUserGroup(user_id, group)
    local player = getPlayerByUserId(user_id)
    if not player then return end
    local job = player:GetJob()
    if job and job.name == group then
        player:SetJob('desempregado', 0)
    end
    local gang = player:GetGang()
    if gang and gang.name == group then
        player:SetGang('none', 0)
    end
end

function vRP.addTemporaryGroup(user_id, group, days)
    vRP.addUserGroup(user_id, group, 0)
end

function vRP.getUserGroupByType(user_id, gtype)
    local player = getPlayerByUserId(user_id)
    if not player then return nil, nil end
    local job = player:GetJob()
    if job and job.type == gtype then
        return job.name, {grade = job.grade}
    end
    return nil, nil
end

function vRP.hasPermission(user_id, perm)
    local src = getSourceByUserId(user_id)
    if not src then return false end
    local ok, result = pcall(function()
        return Nova:HasPermission(src, perm)
    end)
    if ok then return result end

    -- Fallback: verificar grupos
    local groups = vRP.getUserGroups(user_id)

    -- Sintaxe especial vRP
    if string.sub(perm, 1, 1) == '+' or string.sub(perm, 1, 1) == '>' or string.sub(perm, 1, 1) == '@' then
        local prefix = string.sub(perm, 1, 1)
        local parts = {}
        for part in string.gmatch(string.sub(perm, 2), '[^%.]+') do
            parts[#parts + 1] = part
        end
        if #parts >= 2 then
            local groupName = parts[1]
            local gradeName = parts[2]
            local has, currentGrade = vRP.hasGroup(user_id, groupName)
            if has then
                if prefix == '@' then
                    return tostring(currentGrade) == gradeName
                else
                    return (tonumber(currentGrade) or 0) >= (tonumber(gradeName) or 0)
                end
            end
        end
        return false
    end

    -- Permissão simples: verificar nos grupos
    for group, data in pairs(groups) do
        if group == perm or string.find(perm, group, 1, true) then
            return true
        end
    end
    return false
end

function vRP.getUsersByPermission(perm)
    local result = {}
    local novaPlayers = Nova:GetPlayers()
    if novaPlayers then
        for _, data in ipairs(novaPlayers) do
            local uid = sourceToUserId[data.source]
            if uid and vRP.hasPermission(uid, perm) then
                result[#result + 1] = uid
            end
        end
    end
    return result
end

function vRP.checkPermissions(user_id, permission)
    if type(permission) == 'table' then
        for _, perm in ipairs(permission) do
            if not vRP.hasPermission(user_id, perm) then
                return false
            end
        end
        return true
    end
    return vRP.hasPermission(user_id, permission)
end

function vRP.getGroups()
    local jobs = {}
    local ok, novaJobs = pcall(function() return Nova:GetJobs() end)
    if ok and novaJobs then
        for name, job in pairs(novaJobs) do
            jobs[name] = job
        end
    end
    local ok2, novaGangs = pcall(function() return Nova:GetGangs() end)
    if ok2 and novaGangs then
        for name, gang in pairs(novaGangs) do
            jobs[name] = gang
        end
    end
    return jobs
end

function vRP.getGroupTitle(group, grade)
    local ok, jobs = pcall(function() return Nova:GetJobs() end)
    if ok and jobs and jobs[group] then
        local g = jobs[group].grades and jobs[group].grades[grade or 0]
        return g and g.label or group
    end
    return group
end

function vRP.getGroupType(group)
    local ok, jobs = pcall(function() return Nova:GetJobs() end)
    if ok and jobs and jobs[group] then
        return jobs[group].type or 'job'
    end
    return 'job'
end

function vRP.isGroupWithGrades(group, retGrades)
    local ok, jobs = pcall(function() return Nova:GetJobs() end)
    if ok and jobs and jobs[group] and jobs[group].grades then
        if retGrades then return jobs[group].grades end
        return true
    end
    return false
end

-- ============================
-- BASE DE DADOS
-- ============================

function vRP.prepare(name, query)
    preparedQueries[name] = query
end

function vRP.query(name, params, mode)
    local q = preparedQueries[name] or name
    if params then
        for k, v in pairs(params) do
            q = string.gsub(q, '@' .. k, MySQL.Sync.escape(tostring(v)))
        end
    end
    mode = mode or 'query'
    if mode == 'query' then
        return MySQL.Sync.fetchAll(q)
    elseif mode == 'execute' then
        return MySQL.Sync.execute(q)
    elseif mode == 'scalar' then
        return MySQL.Sync.fetchScalar(q)
    elseif mode == 'insert' then
        return MySQL.Sync.insert(q)
    end
    return MySQL.Sync.fetchAll(q)
end

function vRP.execute(name, params)
    return vRP.query(name, params, 'execute')
end

function vRP.insert(name, params)
    return vRP.query(name, params, 'insert')
end

function vRP.scalar(name, params)
    return vRP.query(name, params, 'scalar')
end

-- ============================
-- DADOS DE UTILIZADOR
-- ============================

function vRP.getUData(user_id, key)
    local player = getPlayerByUserId(user_id)
    if player then
        local val = player:GetMetadata('udata_' .. key)
        if val ~= nil then return tostring(val) end
    end
    -- Fallback: tentar buscar da DB
    local result = MySQL.Sync.fetchScalar('SELECT value FROM nova_udata WHERE user_id = @uid AND dkey = @key', {
        ['@uid'] = user_id, ['@key'] = key
    })
    return result or ''
end

function vRP.setUData(user_id, key, value)
    local player = getPlayerByUserId(user_id)
    if player then
        player:SetMetadata('udata_' .. key, value)
    end
    MySQL.Async.execute('INSERT INTO nova_udata (user_id, dkey, value) VALUES (@uid, @key, @val) ON DUPLICATE KEY UPDATE value = @val', {
        ['@uid'] = user_id, ['@key'] = key, ['@val'] = tostring(value)
    })
end

function vRP.getSData(key)
    if serverData[key] then return serverData[key] end
    local result = MySQL.Sync.fetchScalar('SELECT value FROM nova_sdata WHERE dkey = @key', {
        ['@key'] = key
    })
    serverData[key] = result or ''
    return serverData[key]
end

function vRP.setSData(key, value)
    serverData[key] = tostring(value)
    MySQL.Async.execute('INSERT INTO nova_sdata (dkey, value) VALUES (@key, @val) ON DUPLICATE KEY UPDATE value = @val', {
        ['@key'] = key, ['@val'] = tostring(value)
    })
end

function vRP.remSData(dkey)
    serverData[dkey] = nil
    MySQL.Async.execute('DELETE FROM nova_sdata WHERE dkey = @key', {['@key'] = dkey})
end

-- ============================
-- UTILIDADES
-- ============================

function vRP.format(n)
    if not n then return '0' end
    local formatted = tostring(math.floor(n))
    local k
    while true do
        formatted, k = string.gsub(formatted, '^(-?%d+)(%d%d%d)', '%1.%2')
        if k == 0 then break end
    end
    return formatted
end

function vRP.prompt(source, questions)
    -- Stub: não suportado diretamente, retorna tabela vazia
    return {}
end

function vRP.request(source, title, message, time)
    -- Stub: retorna true por padrão
    return true
end

function vRP.isBanned(id)
    local result = MySQL.Sync.fetchScalar(
        'SELECT COUNT(*) FROM nova_users WHERE identifier = @id AND banned = 1',
        {['@id'] = id}
    )
    return result and result > 0
end

function vRP.setBanned(id, banned, reason, days, staff_id)
    if banned then
        MySQL.Async.execute(
            'UPDATE nova_users SET banned = 1 WHERE identifier = @id',
            {['@id'] = id}
        )
    else
        MySQL.Async.execute(
            'UPDATE nova_users SET banned = 0 WHERE identifier = @id',
            {['@id'] = id}
        )
    end
end

function vRP.antiflood(source, key, limite)
    -- Stub: sem anti-flood no bridge
    return true
end

function vRP.webhook(url, data)
    -- Stub: webhook
    PerformHttpRequest(url, function(err, text, headers) end, 'POST', json.encode(data), {['Content-Type'] = 'application/json'})
end

function vRP.getDayHours(seconds)
    if not seconds or seconds <= 0 then return '0h 0m' end
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    if days > 0 then
        return days .. 'd ' .. hours .. 'h ' .. mins .. 'm'
    end
    return hours .. 'h ' .. mins .. 'm'
end

function vRP.getMinSecs(seconds)
    if not seconds or seconds <= 0 then return '0m 0s' end
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return mins .. 'm ' .. secs .. 's'
end

-- Necessidades (mapeado para metadata)
function vRP.getNeed(user_id, need)
    local player = getPlayerByUserId(user_id)
    if not player then return 0 end
    return player:GetMetadata(need) or 100
end

function vRP.setNeed(user_id, need, value)
    local player = getPlayerByUserId(user_id)
    if not player then return end
    player:SetMetadata(need, value)
end

-- Buckets
local nextBucket = 100
function vRP.genBucket()
    nextBucket = nextBucket + 1
    return nextBucket
end

function vRP.freeBucket(id)
    -- Stub
end

-- Seriais
local serials = {}
function vRP.genSerial(prefix, format, data)
    local serial = (prefix or '') .. vRP.generateStringNumber(format or 'LLDDDDLL')
    serials[serial] = data or {}
    return serial
end

function vRP.getSerial(serial)
    return serials[serial]
end

function vRP.freeSerial(serial)
    serials[serial] = nil
end

-- Veículos (informação)
function vRP.vehicleName(vehicle)
    return vehicle or 'Unknown'
end

function vRP.vehicleMaker(vehicle)
    return 'Unknown'
end

function vRP.vehicleType(vehicle)
    return 'car'
end

function vRP.vehiclePrice(vehicle)
    return 0
end

function vRP.userPlate(plate)
    return nil
end

-- ============================================================
-- TUNNEL (SERVER → CLIENT)
-- ============================================================

-- Interface Tunnel do servidor (chamada por scripts vRPex locais)
local vRPclient = {}

function vRPclient.teleport(source, x, y, z)
    TriggerClientEvent('vRP:bridge:teleport', source, x, y, z)
end

function vRPclient.playAnim(source, upper, seq, looping)
    TriggerClientEvent('vRP:bridge:playAnim', source, upper, seq, looping)
end

function vRPclient.stopAnim(source, upper)
    TriggerClientEvent('vRP:bridge:stopAnim', source, upper)
end

function vRPclient.playSound(source, dict, name)
    TriggerClientEvent('vRP:bridge:playSound', source, dict, name)
end

-- Também registar como Tunnel para que scripts acedam via Tunnel.getInterface("vRP")
registerServerTunnel('vRP', {
    -- Funções do server chamáveis via Tunnel do client
    getUserId = vRP.getUserId,
    getMoney = vRP.getMoney,
    getBankMoney = vRP.getBankMoney,
    getUserIdentity = vRP.getUserIdentity,
    hasGroup = vRP.hasGroup,
    hasPermission = vRP.hasPermission,
    getUserGroups = vRP.getUserGroups,
    getInventoryItemAmount = vRP.getInventoryItemAmount,
})

-- ============================================================
-- EVENTOS NOVA → vRP
-- ============================================================

AddEventHandler('nova:server:onPlayerLoaded', function(source, novaPlayer)
    if not novaPlayer then return end
    local user_id = novaPlayer.userId or tonumber(novaPlayer.citizenid) or source
    userIdToSource[user_id] = source
    sourceToUserId[source] = user_id
    dataTables[user_id] = dataTables[user_id] or {}

    TriggerEvent('playerSpawn', user_id, source, true, false)
    TriggerEvent('vRP:playerSpawn', user_id, source, true)
end)

AddEventHandler('nova:server:onPlayerDropped', function(source, citizenid, reason)
    local user_id = sourceToUserId[source]
    if user_id then
        TriggerEvent('vRP:playerLeave', user_id, source)
        dataTables[user_id] = nil
        userIdToSource[user_id] = nil
    end
    sourceToUserId[source] = nil
end)

AddEventHandler('nova:server:onPlayerLogout', function(source, citizenid)
    local user_id = sourceToUserId[source]
    if user_id then
        TriggerEvent('vRP:playerLeave', user_id, source)
    end
end)

AddEventHandler('nova:server:onJobChange', function(source, newJob, oldJob)
    local user_id = sourceToUserId[source]
    if user_id then
        TriggerEvent('group:event', user_id, 'update', newJob)
    end
end)

AddEventHandler('nova:server:onMoneyChange', function(source, moneyType, action)
    -- vRP não tem evento genérico de money change
end)

-- ============================================================
-- REGISTAR INTERFACE PROXY
-- ============================================================

registerProxyInterface('vRP', vRP)

-- ============================================================
-- SQL AUXILIAR (tabelas para udata/sdata)
-- ============================================================

CreateThread(function()
    while not exports['nova_core']:IsFrameworkReady() do Wait(100) end
    Wait(2000)

    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS nova_udata (
            user_id INT NOT NULL,
            dkey VARCHAR(100) NOT NULL,
            value TEXT,
            PRIMARY KEY (user_id, dkey)
        )
    ]])

    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS nova_sdata (
            dkey VARCHAR(100) NOT NULL PRIMARY KEY,
            value TEXT
        )
    ]])

    print('^2[NOVA Bridge] ^0vRPex Server bridge carregado')
end)
