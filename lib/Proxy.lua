--[[
    NOVA Bridge - Proxy Module
    Comunicação cross-resource (mesmo lado: server↔server ou client↔client)
    Usado por scripts vRP via: local Proxy = module("vrp", "lib/Proxy")
]]

Proxy = {}

local interfaces = {}
local rcount = 0

--- Regista uma interface acessível por outros resources
---@param name string Nome da interface (ex: "vRP")
---@param itable table Tabela com funções
function Proxy.addInterface(name, itable)
    interfaces[name] = itable

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

--- Obtém uma interface (local ou remota via eventos)
---@param name string Nome da interface
---@param identifier string|nil Identificador opcional
---@return table
function Proxy.getInterface(name, identifier)
    if interfaces[name] then
        return interfaces[name]
    end

    return setmetatable({}, {
        __index = function(self, k)
            local noWait = string.sub(k, 1, 1) == '_'
            local funcName = noWait and string.sub(k, 2) or k

            if noWait then
                return function(...)
                    TriggerEvent('vRP:proxy:' .. name .. ':' .. funcName, '', ...)
                end
            else
                return function(...)
                    rcount = rcount + 1
                    local rid = (identifier or GetCurrentResourceName()) .. ':p:' .. tostring(rcount)
                    local p = promise.new()

                    local handler = AddEventHandler('vRP:proxy_res:' .. rid, function(...)
                        p:resolve({...})
                    end)

                    TriggerEvent('vRP:proxy:' .. name .. ':' .. funcName, rid, ...)

                    local result = Citizen.Await(p)
                    RemoveEventHandler(handler)

                    if result then
                        return table.unpack(result)
                    end
                end
            end
        end
    })
end

return Proxy
