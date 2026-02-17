--[[
    NOVA Bridge - QBCore Client
    Só ativo quando BridgeConfig.Mode == 'qbcore'
]]

if BridgeConfig.Mode ~= 'qbcore' then return end

local isPlayerLoaded = false
local playerData = {}

CreateThread(function()
    while not exports['nova_core']:IsFrameworkReady() do Wait(100) end
end)

-- DADOS DO JOGADOR

function QBCore.Functions.GetPlayerData()
    local ok, data = pcall(function() return exports['nova_core']:GetPlayerData() end)
    if not ok or not data then return playerData end

    local qbData = {
        source = PlayerId(), citizenid = data.citizenid, name = data.name,
        license = data.identifier, cid = 1,
        charinfo = {
            firstname = data.charinfo and data.charinfo.firstname or '',
            lastname = data.charinfo and data.charinfo.lastname or '',
            birthdate = data.charinfo and data.charinfo.dateofbirth or '',
            gender = data.charinfo and data.charinfo.gender or 0,
            nationality = data.charinfo and data.charinfo.nationality or '',
            phone = data.charinfo and data.charinfo.phone or '',
        },
        money = {
            cash = data.money and data.money.cash or 0,
            bank = data.money and data.money.bank or 0,
            crypto = data.money and data.money.black_money or 0,
        },
        job = {
            name = data.job and data.job.name or 'desempregado',
            label = data.job and data.job.label or 'Desempregado',
            type = data.job and data.job.type or nil,
            onduty = data.job and data.job.duty or false,
            payment = data.job and data.job.salary or 0,
            isboss = data.job and data.job.is_boss or false,
            grade = { name = data.job and tostring(data.job.grade) or '0', level = data.job and data.job.grade or 0 },
        },
        gang = {
            name = data.gang and data.gang.name or 'none',
            label = data.gang and data.gang.label or 'Nenhuma',
            isboss = data.gang and data.gang.is_boss or false,
            grade = { name = data.gang and tostring(data.gang.grade) or '0', level = data.gang and data.gang.grade or 0 },
        },
        metadata = data.metadata or {},
        position = data.position,
    }
    playerData = qbData
    return qbData
end

-- CALLBACKS

function QBCore.Functions.TriggerCallback(name, cb, ...)
    exports['nova_core']:TriggerCallback(name, cb, ...)
end

-- NOTIFICAÇÕES

function QBCore.Functions.Notify(text, nType, duration)
    if nType == 'primary' then nType = 'info' end
    exports['nova_core']:ClientNotify(text, nType or 'info', duration)
end

-- PROGRESSBAR (stub)

function QBCore.Functions.Progressbar(name, label, duration, useWhileDead, canCancel, disableControls, animation, prop, propTwo, onFinish, onCancel)
    if duration and duration > 0 then
        SetTimeout(duration, function() if onFinish then onFinish() end end)
    else
        if onFinish then onFinish() end
    end
end

-- VEÍCULOS

function QBCore.Functions.SpawnVehicle(model, cb, coords, isNetwork, teleportInto)
    local hash = type(model) == 'string' and joaat(model) or model
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) do Wait(10); timeout=timeout+10; if timeout>10000 then if cb then cb(nil) end return end end
    local ped = PlayerPedId()
    local pos = coords or GetEntityCoords(ped)
    local vehicle = CreateVehicle(hash, pos.x, pos.y, pos.z, GetEntityHeading(ped), isNetwork ~= false, false)
    SetModelAsNoLongerNeeded(hash)
    if teleportInto then TaskWarpPedIntoVehicle(ped, vehicle, -1) end
    if cb then cb(vehicle) end
end

function QBCore.Functions.DeleteVehicle(vehicle)
    if DoesEntityExist(vehicle) then SetEntityAsMissionEntity(vehicle, true, true); DeleteVehicle(vehicle) end
end

function QBCore.Functions.GetVehicleProperties(vehicle)
    if not DoesEntityExist(vehicle) then return nil end
    local props = {
        model = GetEntityModel(vehicle), plate = GetVehicleNumberPlateText(vehicle),
        plateIndex = GetVehicleNumberPlateTextIndex(vehicle),
        bodyHealth = GetVehicleBodyHealth(vehicle), engineHealth = GetVehicleEngineHealth(vehicle),
        tankHealth = GetVehiclePetrolTankHealth(vehicle),
        fuelLevel = GetVehicleFuelLevel(vehicle), dirtLevel = GetVehicleDirtLevel(vehicle),
        color1 = table.pack(GetVehicleColours(vehicle))[1], color2 = table.pack(GetVehicleColours(vehicle))[2],
        pearlescentColor = table.pack(GetVehicleExtraColours(vehicle))[1],
        wheelColor = table.pack(GetVehicleExtraColours(vehicle))[2],
        wheels = GetVehicleWheelType(vehicle), windowTint = GetVehicleWindowTint(vehicle),
        neonEnabled = { IsVehicleNeonLightEnabled(vehicle,0), IsVehicleNeonLightEnabled(vehicle,1), IsVehicleNeonLightEnabled(vehicle,2), IsVehicleNeonLightEnabled(vehicle,3) },
        neonColor = table.pack(GetVehicleNeonLightsColour(vehicle)),
        tyreSmokeColor = table.pack(GetVehicleTyreSmokeColor(vehicle)),
        modSpoilers=GetVehicleMod(vehicle,0), modFrontBumper=GetVehicleMod(vehicle,1),
        modRearBumper=GetVehicleMod(vehicle,2), modSideSkirt=GetVehicleMod(vehicle,3),
        modExhaust=GetVehicleMod(vehicle,4), modFrame=GetVehicleMod(vehicle,5),
        modGrille=GetVehicleMod(vehicle,6), modHood=GetVehicleMod(vehicle,7),
        modFender=GetVehicleMod(vehicle,8), modRightFender=GetVehicleMod(vehicle,9),
        modRoof=GetVehicleMod(vehicle,10), modEngine=GetVehicleMod(vehicle,11),
        modBrakes=GetVehicleMod(vehicle,12), modTransmission=GetVehicleMod(vehicle,13),
        modHorns=GetVehicleMod(vehicle,14), modSuspension=GetVehicleMod(vehicle,15),
        modArmor=GetVehicleMod(vehicle,16),
        modTurbo=IsToggleModOn(vehicle,18), modSmokeEnabled=IsToggleModOn(vehicle,20),
        modXenon=IsToggleModOn(vehicle,22),
        modFrontWheels=GetVehicleMod(vehicle,23), modBackWheels=GetVehicleMod(vehicle,24),
        modLivery = GetVehicleMod(vehicle,48)==-1 and GetVehicleLivery(vehicle) or GetVehicleMod(vehicle,48),
        extras = {},
    }
    for i=0,14 do if DoesExtraExist(vehicle, i) then props.extras[tostring(i)] = IsVehicleExtraTurnedOn(vehicle, i) end end
    return props
end

function QBCore.Functions.SetVehicleProperties(vehicle, props)
    if not DoesEntityExist(vehicle) or not props then return end
    if props.plate then SetVehicleNumberPlateText(vehicle, props.plate) end
    if props.plateIndex then SetVehicleNumberPlateTextIndex(vehicle, props.plateIndex) end
    if props.bodyHealth then SetVehicleBodyHealth(vehicle, props.bodyHealth+0.0) end
    if props.engineHealth then SetVehicleEngineHealth(vehicle, props.engineHealth+0.0) end
    if props.tankHealth then SetVehiclePetrolTankHealth(vehicle, props.tankHealth+0.0) end
    if props.fuelLevel then SetVehicleFuelLevel(vehicle, props.fuelLevel+0.0) end
    if props.dirtLevel then SetVehicleDirtLevel(vehicle, props.dirtLevel+0.0) end
    if props.color1 and props.color2 then SetVehicleColours(vehicle, props.color1, props.color2) end
    if props.pearlescentColor and props.wheelColor then SetVehicleExtraColours(vehicle, props.pearlescentColor, props.wheelColor) end
    if props.wheels then SetVehicleWheelType(vehicle, props.wheels) end
    if props.windowTint then SetVehicleWindowTint(vehicle, props.windowTint) end
    if props.neonEnabled then for i=1,4 do SetVehicleNeonLightEnabled(vehicle, i-1, props.neonEnabled[i]) end end
    if props.neonColor then SetVehicleNeonLightsColour(vehicle, props.neonColor[1] or 0, props.neonColor[2] or 0, props.neonColor[3] or 0) end
    if props.tyreSmokeColor then SetVehicleTyreSmokeColor(vehicle, props.tyreSmokeColor[1] or 0, props.tyreSmokeColor[2] or 0, props.tyreSmokeColor[3] or 0) end
    local mods = {[0]='modSpoilers',[1]='modFrontBumper',[2]='modRearBumper',[3]='modSideSkirt',[4]='modExhaust',[5]='modFrame',[6]='modGrille',[7]='modHood',[8]='modFender',[9]='modRightFender',[10]='modRoof',[11]='modEngine',[12]='modBrakes',[13]='modTransmission',[14]='modHorns',[15]='modSuspension',[16]='modArmor',[23]='modFrontWheels',[24]='modBackWheels'}
    for slot, key in pairs(mods) do if props[key] then SetVehicleMod(vehicle, slot, props[key], false) end end
    if props.modTurbo ~= nil then ToggleVehicleMod(vehicle, 18, props.modTurbo) end
    if props.modSmokeEnabled ~= nil then ToggleVehicleMod(vehicle, 20, props.modSmokeEnabled) end
    if props.modXenon ~= nil then ToggleVehicleMod(vehicle, 22, props.modXenon) end
    if props.modLivery then SetVehicleMod(vehicle, 48, props.modLivery, false); SetVehicleLivery(vehicle, props.modLivery) end
    if props.extras then for k,v in pairs(props.extras) do local id=tonumber(k); if id and DoesExtraExist(vehicle,id) then SetVehicleExtra(vehicle,id,not v) end end end
end

-- JOGADORES / PROXIMIDADE

function QBCore.Functions.GetClosestPlayer(coords)
    local players = GetActivePlayers()
    local closest, closestDist, myPed = -1, 9999.0, PlayerPedId()
    local pos = coords or GetEntityCoords(myPed)
    for _, pid in ipairs(players) do
        local ped = GetPlayerPed(pid)
        if ped ~= myPed then
            local dist = #(pos - GetEntityCoords(ped))
            if dist < closestDist then closest, closestDist = GetPlayerServerId(pid), dist end
        end
    end
    return closest, closestDist
end

function QBCore.Functions.GetPlayersFromCoords(coords, distance)
    local players, result, myPed = GetActivePlayers(), {}, PlayerPedId()
    local pos = coords or GetEntityCoords(myPed)
    distance = distance or 5.0
    for _, pid in ipairs(players) do
        local ped = GetPlayerPed(pid)
        if ped ~= myPed then
            local pCoords = GetEntityCoords(ped)
            local dist = #(pos - pCoords)
            if dist <= distance then result[#result+1] = { id = GetPlayerServerId(pid), ped = ped, coords = pCoords, dist = dist } end
        end
    end
    return result
end

function QBCore.Functions.IsPlayerInVehicle() return IsPedInAnyVehicle(PlayerPedId(), false) end

function QBCore.Functions.GetPlate(vehicle)
    if vehicle and DoesEntityExist(vehicle) then return string.gsub(GetVehicleNumberPlateText(vehicle), '^%s+', ''):gsub('%s+$', '') end
    return nil
end

function QBCore.Functions.HasPrimaryPermission() return true end

-- DRAW TEXT

function QBCore.Functions.DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35); SetTextFont(4); SetTextProportional(true)
    SetTextColour(255, 255, 255, 215); SetTextEntry('STRING'); SetTextCentre(true)
    AddTextComponentString(text); SetDrawOrigin(x, y, z, 0); DrawText(0.0, 0.0)
    DrawRect(0.0, 0.0125, 0.017 + (#text / 370), 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

-- EVENTOS NOVA → QBCORE

RegisterNetEvent('nova:client:onPlayerLoaded', function(data)
    isPlayerLoaded = true; playerData = QBCore.Functions.GetPlayerData()
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
end)

RegisterNetEvent('nova:client:onLogout', function()
    isPlayerLoaded = false; playerData = {}
    TriggerEvent('QBCore:Client:OnPlayerUnload')
end)

RegisterNetEvent('nova:client:updatePlayerData', function(data)
    if not data then return end
    playerData = QBCore.Functions.GetPlayerData()
    if data.type == 'job' then TriggerEvent('QBCore:Client:OnJobUpdate', playerData.job)
    elseif data.type == 'gang' then TriggerEvent('QBCore:Client:OnGangUpdate', playerData.gang)
    elseif data.type == 'money' then TriggerEvent('QBCore:Client:OnMoneyChange', playerData.money) end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() end)

AddEventHandler('QBCore:GetObject', function(cb)
    if cb and type(cb) == 'function' then cb(QBCore) end
end)

print('^2[NOVA Bridge] ^0QBCore Client bridge carregado')
