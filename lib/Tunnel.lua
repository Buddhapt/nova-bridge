--[[
    NOVA Bridge - Tunnel Module
    Comunicação cross-side (client↔server)
    Usado por scripts vRP via: local Tunnel = module("vrp", "lib/Tunnel")
]]

Tunnel = {}

local interfaces = {}
local rcount = 0

--- Bind de uma interface para receber chamadas do outro lado
---@param name string Nome da interface
---@param itable table Tabela com funções
function Tunnel.bindInterface(name, itable)
    interfaces[name] = itable

    for k, v in pairs(itable) do
        if type(v) == 'function' then
            RegisterNetEvent('vRP:tunnel:' .. name .. ':' .. k)
            AddEventHandler('vRP:tunnel:' .. name .. ':' .. k, function(rid, ...)
                local _source = source
                if rid and rid ~= '' then
                    local rets = {v(...)}
                    if IsDuplicityVersion() then
                        TriggerClientEvent('vRP:tunnel_res:' .. rid, _source, table.unpack(rets))
                    else
                        TriggerServerEvent('vRP:tunnel_res:' .. rid, table.unpack(rets))
                    end
                else
                    v(...)
                end
            end)
        end
    end
end

--- Obtém interface para chamar funções no outro lado
---@param name string Nome da interface
---@param identifier string|nil Identificador opcional
---@return table
function Tunnel.getInterface(name, identifier)
    return setmetatable({}, {
        __index = function(self, k)
            local noWait = string.sub(k, 1, 1) == '_'
            local funcName = noWait and string.sub(k, 2) or k

            if IsDuplicityVersion() then
                -- Server → Client
                if noWait then
                    return function(target, ...)
                        TriggerClientEvent('vRP:tunnel:' .. name .. ':' .. funcName, target, '', ...)
                    end
                else
                    return function(target, ...)
                        rcount = rcount + 1
                        local rid = (identifier or GetCurrentResourceName()) .. ':ts:' .. tostring(rcount)
                        local p = promise.new()

                        RegisterNetEvent('vRP:tunnel_res:' .. rid)
                        local handler = AddEventHandler('vRP:tunnel_res:' .. rid, function(...)
                            p:resolve({...})
                        end)

                        TriggerClientEvent('vRP:tunnel:' .. name .. ':' .. funcName, target, rid, ...)

                        local result = Citizen.Await(p)
                        RemoveEventHandler(handler)

                        if result then
                            return table.unpack(result)
                        end
                    end
                end
            else
                -- Client → Server
                if noWait then
                    return function(...)
                        TriggerServerEvent('vRP:tunnel:' .. name .. ':' .. funcName, '', ...)
                    end
                else
                    return function(...)
                        rcount = rcount + 1
                        local rid = (identifier or GetCurrentResourceName()) .. ':tc:' .. tostring(rcount)
                        local p = promise.new()

                        RegisterNetEvent('vRP:tunnel_res:' .. rid)
                        local handler = AddEventHandler('vRP:tunnel_res:' .. rid, function(...)
                            p:resolve({...})
                        end)

                        TriggerServerEvent('vRP:tunnel:' .. name .. ':' .. funcName, rid, ...)

                        local result = Citizen.Await(p)
                        RemoveEventHandler(handler)

                        if result then
                            return table.unpack(result)
                        end
                    end
                end
            end
        end
    })
end

--- Define atraso para um destino (compatibilidade)
---@param dest string
---@param delay number
function Tunnel.setDestDelay(dest, delay)
    -- stub para compatibilidade
end

return Tunnel
