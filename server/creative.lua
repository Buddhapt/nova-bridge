--[[
    NOVA Bridge - Creative Server
    Só ativo quando BridgeConfig.Mode == 'creative'
    
    Implementa a API Creative (vRP-based) mapeada para o NOVA Framework.
    Scripts Creative acedem via Proxy.getInterface("vRP").
    
    Diferenças principais do Creative em relação ao vRPex:
    - Funções com nomes diferentes (userSource, userBank, userInventory, etc.)
    - Sistema de premium/gems
    - Sistema de necessidades (fome, sede, stress)
    - Sistema de multas
]]

if BridgeConfig.Mode ~= 'creative' then return end

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
-- vRP INTERFACE (CREATIVE API)
-- ============================================================

local vRP = {}

-- ============================
-- JOGADORES (Creative naming)
-- ============================

function vRP.getUserId(source)
    if not source or source <= 0 then return nil end
    local player = Nova:GetPlayer(source)
    if not player then return nil end
    local user_id = player.userId or tonumber(player.citizenid) or source
    userIdToSource[user_id] = source
    sourceToUserId[source] = user_id
    if not dataTables[user_id] then
        dataTables[user_id] = {}
    end
    return user_id
end

-- Creative usa userSource em vez de getUserSource
function vRP.userSource(user_id)
    return userIdToSource[user_id]
end

function vRP.getUserSource(user_id)
    return userIdToSource[user_id]
end

-- Creative aliases para getUsers
function vRP.userList()
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

function vRP.getPlayersOn()
    return vRP.userList()
end

function vRP.getUsers()
    return vRP.userList()
end

-- Data tables (Creative naming)
function vRP.getDatatable(user_id)
    if not dataTables[user_id] then
        dataTables[user_id] = {}
    end
    return dataTables[user_id]
end

function vRP.getUserDataTable(user_id)
    return vRP.getDatatable(user_id)
end

function vRP.setDatatable(user_id, index, value)
    if not dataTables[user_id] then
        dataTables[user_id] = {}
    end
    dataTables[user_id][index] = value
end

function vRP.setKeyDataTable(user_id, key, value)
    vRP.setDatatable(user_id, key, value)
end

function vRP.userData(user_id, key)
    local dt = vRP.getDatatable(user_id)
    return dt and dt[key]
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

function vRP.kick(source, reason)
    local player = Nova:GetPlayer(source)
    if player then player:Kick(reason or 'Kicked') end
end

function vRP.dropPlayer(source, reason)
    DropPlayer(source, reason or 'Disconnected')
end

-- ============================
-- IDENTIDADE (Creative naming)
-- ============================

function vRP.userIdentity(user_id)
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
        image = player:GetMetadata('profile_image') or '',
    }
end

function vRP.getUserIdentity(user_id)
    return vRP.userIdentity(user_id)
end

function vRP.updateProfile(user_id, image_url)
    local player = getPlayerByUserId(user_id)
    if player then
        player:SetMetadata('profile_image', image_url)
    end
end

function vRP.updateName(user_id, name, name2)
    local player = getPlayerByUserId(user_id)
    if not player then return end
    if name then player.charinfo.firstname = name end
    if name2 then player.charinfo.lastname = name2 end
end

function vRP.upgradePhone(user_id, phone)
    local player = getPlayerByUserId(user_id)
    if player then
        player.charinfo.phone = phone
    end
end

function vRP.upgradeNames(user_id, name, name2)
    vRP.updateName(user_id, name, name2)
end

function vRP.falseIdentity(user_id)
    -- Stub: gera identidade falsa temporária
    return {
        name = 'Desconhecido',
        name2 = '',
        registration = vRP.generateStringNumber('LLLDDDD'),
        phone = vRP.generateStringNumber('DDDD-DDDD'),
    }
end

function vRP.userPlate(vehPlate)
    return nil
end

function vRP.userPhone(phoneNumber)
    local novaPlayers = Nova:GetPlayers()
    if novaPlayers then
        for _, data in ipairs(novaPlayers) do
            if data.player and data.player.charinfo and data.player.charinfo.phone == phoneNumber then
                return sourceToUserId[data.source]
            end
        end
    end
    return nil
end

function vRP.userBlood(bloodTypes)
    return nil
end

function vRP.userSerial(number)
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

function vRP.generatePlate()
    return vRP.generateStringNumber('LLLDDDLL')
end

function vRP.generatePhone()
    return vRP.generateStringNumber('DDDD-DDDD')
end

function vRP.generateSerial()
    return vRP.generateStringNumber('LLDDDDLL')
end

function vRP.generateBlood()
    local types = {'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'}
    return types[math.random(1, #types)]
end

function vRP.generateBloodTypes(format)
    return vRP.generateBlood()
end

-- ============================
-- DINHEIRO (Creative naming + vRPex compat)
-- ============================

function vRP.getMoney(user_id)
    local player = getPlayerByUserId(user_id)
    if not player then return 0 end
    return player:GetMoney('cash')
end

function vRP.giveMoney(user_id, value)
    local player = getPlayerByUserId(user_id)
    if not player then return end
    player:AddMoney('cash', value, 'creative_bridge')
end

function vRP.tryPayment(user_id, value)
    local player = getPlayerByUserId(user_id)
    if not player then return false end
    if player:GetMoney('cash') >= value then
        return player:RemoveMoney('cash', value, 'creative_bridge')
    end
    return false
end

-- Creative bank functions
function vRP.userBank(user_id)
    local player = getPlayerByUserId(user_id)
    if not player then return {bank = 0} end
    return {bank = player:GetMoney('bank')}
end

function vRP.getBank(user_id)
    local player = getPlayerByUserId(user_id)
    if not player then return 0 end
    return player:GetMoney('bank')
end

function vRP.getBankMoney(user_id)
    return vRP.getBank(user_id)
end

function vRP.addBank(user_id, amount)
    local player = getPlayerByUserId(user_id)
    if not player then return end
    player:AddMoney('bank', amount, 'creative_bridge')
end

function vRP.giveBankMoney(user_id, amount)
    vRP.addBank(user_id, amount)
end

function vRP.delBank(user_id, amount)
    local player = getPlayerByUserId(user_id)
    if not player then return false end
    if player:GetMoney('bank') >= amount then
        return player:RemoveMoney('bank', amount, 'creative_bridge')
    end
    return false
end

function vRP.removeBankMoney(user_id, amount)
    return vRP.delBank(user_id, amount)
end

function vRP.setBankMoney(user_id, amount)
    local player = getPlayerByUserId(user_id)
    if not player then return end
    player:SetMoney('bank', amount)
end

function vRP.paymentBank(user_id, amount)
    return vRP.delBank(user_id, amount)
end

function vRP.tryBankPayment(user_id, amount)
    return vRP.delBank(user_id, amount)
end

function vRP.paymentFull(user_id, amount)
    local player = getPlayerByUserId(user_id)
    if not player then return false end
    local cash = player:GetMoney('cash')
    if cash >= amount then
        return player:RemoveMoney('cash', amount, 'creative_bridge')
    end
    local bank = player:GetMoney('bank')
    if cash + bank >= amount then
        local remaining = amount - cash
        if cash > 0 then player:RemoveMoney('cash', cash, 'creative_bridge') end
        return player:RemoveMoney('bank', remaining, 'creative_bridge')
    end
    return false
end

function vRP.tryFullPayment(user_id, amount)
    return vRP.paymentFull(user_id, amount)
end

function vRP.withdrawCash(user_id, amount)
    local player = getPlayerByUserId(user_id)
    if not player then return false end
    if player:GetMoney('bank') >= amount then
        player:RemoveMoney('bank', amount, 'creative_bridge')
        player:AddMoney('cash', amount, 'creative_bridge')
        return true
    end
    return false
end

function vRP.tryWithdraw(user_id, amount)
    return vRP.withdrawCash(user_id, amount)
end

function vRP.tryDeposit(user_id, amount)
    local player = getPlayerByUserId(user_id)
    if not player then return false end
    if player:GetMoney('cash') >= amount then
        player:RemoveMoney('cash', amount, 'creative_bridge')
        player:AddMoney('bank', amount, 'creative_bridge')
        return true
    end
    return false
end

function vRP.getAllMoney(user_id)
    local player = getPlayerByUserId(user_id)
    if not player then return 0 end
    return player:GetMoney('cash') + player:GetMoney('bank')
end

-- Creative gems (mapeado para black_money)
function vRP.userGemstone(user_id)
    local player = getPlayerByUserId(user_id)
    if not player then return 0 end
    return player:GetMoney('black_money')
end

function vRP.upgradeGemstone(user_id, amount)
    local player = getPlayerByUserId(user_id)
    if not player then return end
    player:AddMoney('black_money', amount, 'creative_bridge_gems')
end

function vRP.paymentGems(user_id, amount)
    local player = getPlayerByUserId(user_id)
    if not player then return false end
    if player:GetMoney('black_money') >= amount then
        return player:RemoveMoney('black_money', amount, 'creative_bridge_gems')
    end
    return false
end

-- Multas (fines) - mapeado para metadata
function vRP.getFines(user_id)
    local player = getPlayerByUserId(user_id)
    if not player then return 0 end
    return player:GetMetadata('fines') or 0
end

function vRP.addFines(user_id, amount)
    local player = getPlayerByUserId(user_id)
    if not player then return end
    local current = player:GetMetadata('fines') or 0
    player:SetMetadata('fines', current + amount)
end

function vRP.delFines(user_id, amount)
    local player = getPlayerByUserId(user_id)
    if not player then return end
    local current = player:GetMetadata('fines') or 0
    player:SetMetadata('fines', math.max(0, current - amount))
end

-- ============================
-- INVENTÁRIO (Creative naming)
-- ============================

function vRP.userInventory(user_id)
    local player = getPlayerByUserId(user_id)
    if not player then return {} end
    return player:GetInventory()
end

function vRP.giveInventoryItem(user_id, nameItem, amount, notify, slot)
    local player = getPlayerByUserId(user_id)
    if not player then return false end
    return player:AddItem(nameItem, amount)
end

function vRP.generateItem(user_id, nameItem, amount, notify, slot)
    return vRP.giveInventoryItem(user_id, nameItem, amount, notify, slot)
end

function vRP.tryGetInventoryItem(user_id, nameItem, amount, notify, slot)
    local player = getPlayerByUserId(user_id)
    if not player then return false end
    if player:GetItemCount(nameItem) >= amount then
        return player:RemoveItem(nameItem, amount)
    end
    return false
end

function vRP.removeInventoryItem(user_id, nameItem, amount, notify)
    return vRP.tryGetInventoryItem(user_id, nameItem, amount, notify)
end

function vRP.getInventoryItemAmount(user_id, nameItem)
    local player = getPlayerByUserId(user_id)
    if not player then return 0 end
    return player:GetItemCount(nameItem)
end

function vRP.itemAmount(user_id, nameItem)
    return vRP.getInventoryItemAmount(user_id, nameItem)
end

function vRP.getInventory(user_id)
    return vRP.userInventory(user_id)
end

function vRP.getWeight(user_id)
    local player = getPlayerByUserId(user_id)
    if not player then return 0 end
    local inv = player:GetInventory()
    local weight = 0
    for _, item in pairs(inv) do
        weight = weight + (item.weight or 0) * (item.amount or item.count or 1)
    end
    return weight
end

function vRP.inventoryWeight(user_id)
    return vRP.getWeight(user_id)
end

function vRP.setWeight(user_id, amount)
    -- Stub: definir peso máximo
end

function vRP.consultItem(Passport, Item, Amount)
    return vRP.getInventoryItemAmount(Passport, Item) >= (Amount or 1)
end

function vRP.checkBroken(nameItem)
    return false
end

function vRP.checkMaxItens(user_id, nameItem, amount)
    return true
end

function vRP.clearInventory(user_id)
    print('^3[NOVA Bridge] ^0clearInventory: requer implementação no nova_inventory')
end

function vRP.itemExists(item)
    local ok, result = pcall(function() return Nova:GetItems() end)
    if ok and result then return result[item] ~= nil end
    return false
end

function vRP.itemNameList(item)
    local ok, items = pcall(function() return Nova:GetItems() end)
    if ok and items and items[item] then return items[item].label or item end
    return item
end

-- ============================
-- GRUPOS & PERMISSÕES (Creative naming)
-- ============================

function vRP.Groups()
    local jobs = {}
    local ok, novaJobs = pcall(function() return Nova:GetJobs() end)
    if ok and novaJobs then
        for name, job in pairs(novaJobs) do jobs[name] = job end
    end
    local ok2, novaGangs = pcall(function() return Nova:GetGangs() end)
    if ok2 and novaGangs then
        for name, gang in pairs(novaGangs) do jobs[name] = gang end
    end
    return jobs
end

function vRP.getGroups()
    return vRP.Groups()
end

function vRP.getUserGroups(user_id)
    local player = getPlayerByUserId(user_id)
    if not player then return {} end
    local groups = {}
    local job = player:GetJob()
    if job and job.name then groups[job.name] = {grade = job.grade} end
    local gang = player:GetGang()
    if gang and gang.name and gang.name ~= 'none' then
        groups[gang.name] = {grade = gang.grade}
    end
    if player.group and player.group ~= 'user' then
        groups[player.group] = {grade = 0}
    end
    return groups
end

function vRP.hasGroup(Passport, Permission, Level)
    local groups = vRP.getUserGroups(Passport)
    if groups[Permission] then
        local grade = groups[Permission].grade or 0
        if Level then
            return grade >= (tonumber(Level) or 0), grade
        end
        return true, grade
    end
    return false, nil
end

function vRP.hasPermission(Passport, Permission, Level)
    return vRP.hasGroup(Passport, Permission, Level)
end

function vRP.setPermission(user_id, perm, Level)
    vRP.addUserGroup(user_id, perm, Level)
end

function vRP.remPermission(Passport, Permission)
    vRP.removeUserGroup(Passport, Permission)
end

function vRP.addUserGroup(user_id, group, grade)
    local player = getPlayerByUserId(user_id)
    if not player then return end
    grade = grade or 0
    local ok = pcall(function()
        local jobs = Nova:GetJobs()
        if jobs and jobs[group] then
            player:SetJob(group, grade)
            return
        end
    end)
    if not ok then
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
    if job and job.name == group then player:SetJob('desempregado', 0) end
    local gang = player:GetGang()
    if gang and gang.name == group then player:SetGang('none', 0) end
end

function vRP.insertPermission(source, user_id, perm)
    vRP.addUserGroup(user_id, perm, 0)
end

function vRP.removePermission(user_id, perm)
    vRP.removeUserGroup(user_id, perm)
end

function vRP.updatePermission(user_id, perm, new)
    vRP.removeUserGroup(user_id, perm)
    vRP.addUserGroup(user_id, new, 0)
end

function vRP.cleanPermission(user_id)
    local player = getPlayerByUserId(user_id)
    if not player then return end
    player:SetJob('desempregado', 0)
    player:SetGang('none', 0)
end

function vRP.getUsersByPermission(perm)
    local result = {}
    local novaPlayers = Nova:GetPlayers()
    if novaPlayers then
        for _, data in ipairs(novaPlayers) do
            local uid = sourceToUserId[data.source]
            if uid then
                local has = vRP.hasGroup(uid, perm)
                if has then result[#result + 1] = uid end
            end
        end
    end
    return result
end

function vRP.numPermission(perm)
    local result = {}
    local novaPlayers = Nova:GetPlayers()
    if novaPlayers then
        for _, data in ipairs(novaPlayers) do
            local uid = sourceToUserId[data.source]
            if uid and vRP.hasGroup(uid, perm) then
                result[#result + 1] = data.source
            end
        end
    end
    return result
end

function vRP.DataGroups(Permission)
    local groups = vRP.Groups()
    return groups[Permission]
end

function vRP.Hierarchy(Permission)
    local groups = vRP.Groups()
    if groups[Permission] and groups[Permission].grades then
        return groups[Permission].grades
    end
    return {}
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

-- ============================
-- SURVIVAL (Creative specific)
-- ============================

function vRP.upgradeThirst(user_id, amount)
    local player = getPlayerByUserId(user_id)
    if not player then return end
    local current = player:GetMetadata('thirst') or 100
    player:SetMetadata('thirst', math.min(100, current + amount))
end

function vRP.upgradeHunger(user_id, amount)
    local player = getPlayerByUserId(user_id)
    if not player then return end
    local current = player:GetMetadata('hunger') or 100
    player:SetMetadata('hunger', math.min(100, current + amount))
end

function vRP.upgradeStress(user_id, amount)
    local player = getPlayerByUserId(user_id)
    if not player then return end
    local current = player:GetMetadata('stress') or 0
    player:SetMetadata('stress', math.min(100, current + amount))
end

function vRP.downgradeThirst(user_id, amount)
    local player = getPlayerByUserId(user_id)
    if not player then return end
    local current = player:GetMetadata('thirst') or 100
    player:SetMetadata('thirst', math.max(0, current - amount))
end

function vRP.downgradeHunger(user_id, amount)
    local player = getPlayerByUserId(user_id)
    if not player then return end
    local current = player:GetMetadata('hunger') or 100
    player:SetMetadata('hunger', math.max(0, current - amount))
end

function vRP.downgradeStress(user_id, amount)
    local player = getPlayerByUserId(user_id)
    if not player then return end
    local current = player:GetMetadata('stress') or 0
    player:SetMetadata('stress', math.max(0, current - amount))
end

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

-- ============================
-- PREMIUM / VIP (Creative specific)
-- ============================

function vRP.userPremium(user_id)
    local player = getPlayerByUserId(user_id)
    if not player then return false end
    return player:GetMetadata('premium') or false
end

function vRP.setPremium(user_id)
    local player = getPlayerByUserId(user_id)
    if not player then return end
    player:SetMetadata('premium', true)
end

function vRP.upgradePremium(user_id)
    vRP.setPremium(user_id)
end

function vRP.steamPremium(steam)
    -- Stub: verificar premium por steam
    return false
end

-- ============================
-- EXPERIÊNCIA (Creative specific)
-- ============================

function vRP.getExperience(user_id, work)
    local player = getPlayerByUserId(user_id)
    if not player then return 0 end
    local exp = player:GetMetadata('experience') or {}
    return exp[work] or 0
end

function vRP.putExperience(user_id, work, number)
    local player = getPlayerByUserId(user_id)
    if not player then return end
    local exp = player:GetMetadata('experience') or {}
    exp[work] = (exp[work] or 0) + number
    player:SetMetadata('experience', exp)
end

-- ============================
-- PRISÃO (Creative specific)
-- ============================

function vRP.initPrison(user_id, amount)
    local player = getPlayerByUserId(user_id)
    if not player then return end
    player:SetMetadata('prison_time', amount)
    player:SetMetadata('in_prison', true)
end

function vRP.updatePrison(user_id)
    local player = getPlayerByUserId(user_id)
    if not player then return end
    local time = player:GetMetadata('prison_time') or 0
    if time > 0 then
        player:SetMetadata('prison_time', time - 1)
    else
        player:SetMetadata('in_prison', false)
        player:SetMetadata('prison_time', 0)
    end
end

-- ============================
-- CHARACTER (Creative specific)
-- ============================

function vRP.characterChosen(source, user_id, model, locate)
    -- Já tratado pelo nova_core na conexão
    TriggerClientEvent('vRP:bridge:characterChosen', source, user_id, model, locate)
end

function vRP.characterExit(source)
    local player = Nova:GetPlayer(source)
    if player then player:Logout() end
end

function vRP.rejoinPlayer(source)
    -- Stub: reconectar jogador
end

function vRP.upgradePort(user_id, statusPort)
    -- Stub: upgrade de porta/slot
end

function vRP.upgradeGarage(user_id)
    -- Stub
end

function vRP.upgradeChars(user_id)
    -- Stub
end

function vRP.updateHomePosition(user_id, x, y, z)
    local player = getPlayerByUserId(user_id)
    if player then
        player:SetMetadata('home_position', {x = x, y = y, z = z})
    end
end

function vRP.updateLocate(user_id)
    -- Stub
end

-- ============================
-- PLAYER STATE (Creative specific)
-- ============================

function vRP.getHealth(source)
    local ped = GetPlayerPed(source)
    if ped and DoesEntityExist(ped) then
        return GetEntityHealth(ped)
    end
    return 200
end

function vRP.modelPlayer(source)
    local ped = GetPlayerPed(source)
    if ped and DoesEntityExist(ped) then
        return GetEntityModel(ped)
    end
    return 0
end

function vRP.setArmour(source, amount)
    TriggerClientEvent('vRP:bridge:setArmour', source, amount)
end

function vRP.teleport(source, x, y, z)
    TriggerClientEvent('vRP:bridge:teleport', source, x, y, z)
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

function vRP.getSrvdata(key)
    if serverData[key] then return serverData[key] end
    local result = MySQL.Sync.fetchScalar('SELECT value FROM nova_sdata WHERE dkey = @key', {['@key'] = key})
    serverData[key] = result or ''
    return serverData[key]
end

function vRP.getSData(key)
    return vRP.getSrvdata(key)
end

function vRP.setSrvdata(key, data)
    serverData[key] = tostring(data)
    MySQL.Async.execute('INSERT INTO nova_sdata (dkey, value) VALUES (@key, @val) ON DUPLICATE KEY UPDATE value = @val', {
        ['@key'] = key, ['@val'] = tostring(data)
    })
end

function vRP.setSData(key, value)
    vRP.setSrvdata(key, value)
end

function vRP.remSrvdata(key)
    serverData[key] = nil
    MySQL.Async.execute('DELETE FROM nova_sdata WHERE dkey = @key', {['@key'] = key})
end

function vRP.remSData(key)
    vRP.remSrvdata(key)
end

function vRP.getUData(user_id, key)
    local player = getPlayerByUserId(user_id)
    if player then
        local val = player:GetMetadata('udata_' .. key)
        if val ~= nil then return tostring(val) end
    end
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

function vRP.prompt(source, title, default_text, value)
    return default_text or ''
end

function vRP.request(source, text)
    return true
end

function vRP.checkBanned(steam)
    local result = MySQL.Sync.fetchScalar(
        'SELECT COUNT(*) FROM nova_users WHERE identifier LIKE @steam AND banned = 1',
        {['@steam'] = '%' .. steam .. '%'}
    )
    return result and result > 0
end

function vRP.infoAccount(steam)
    return nil
end

function vRP.isBanned(id)
    return vRP.checkBanned(id)
end

function vRP.setBanned(id, banned, reason, days, staff_id)
    if banned then
        MySQL.Async.execute('UPDATE nova_users SET banned = 1 WHERE identifier = @id', {['@id'] = id})
    else
        MySQL.Async.execute('UPDATE nova_users SET banned = 0 WHERE identifier = @id', {['@id'] = id})
    end
end

function vRP.getDayHours(seconds)
    if not seconds or seconds <= 0 then return '0h 0m' end
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    if days > 0 then return days .. 'd ' .. hours .. 'h ' .. mins .. 'm' end
    return hours .. 'h ' .. mins .. 'm'
end

function vRP.getMinSecs(seconds)
    if not seconds or seconds <= 0 then return '0m 0s' end
    return math.floor(seconds / 60) .. 'm ' .. math.floor(seconds % 60) .. 's'
end

function vRP.antiflood(source, key, limite)
    return true
end

function vRP.webhook(url, data)
    PerformHttpRequest(url, function() end, 'POST', json.encode(data), {['Content-Type'] = 'application/json'})
end

-- Buckets
local nextBucket = 100
function vRP.genBucket()
    nextBucket = nextBucket + 1
    return nextBucket
end

function vRP.freeBucket(id) end

-- ============================================================
-- TUNNEL (SERVER → CLIENT)
-- ============================================================

registerServerTunnel('vRP', {
    getUserId = vRP.getUserId,
    getMoney = vRP.getMoney,
    getBank = vRP.getBank,
    getBankMoney = vRP.getBankMoney,
    getUserIdentity = vRP.getUserIdentity,
    userIdentity = vRP.userIdentity,
    hasGroup = vRP.hasGroup,
    hasPermission = vRP.hasPermission,
    getUserGroups = vRP.getUserGroups,
    getInventoryItemAmount = vRP.getInventoryItemAmount,
    itemAmount = vRP.itemAmount,
})

-- ============================================================
-- EVENTOS NOVA → Creative/vRP
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
        TriggerEvent('gb:playerExit', user_id, source)
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

-- ============================================================
-- REGISTAR INTERFACE PROXY
-- ============================================================

registerProxyInterface('vRP', vRP)

-- ============================================================
-- SQL AUXILIAR
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

    print('^2[NOVA Bridge] ^0Creative Server bridge carregado')
end)
