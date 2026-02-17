--[[
    NOVA Bridge - vRP Utils Library
    Carregado por scripts via @vrp/lib/utils.lua
    Fornece a função module() usada pelo ecossistema vRP.
]]

if not vRP then vRP = {} end
if not vRP._modules then vRP._modules = {} end

--- Carrega um módulo de outro resource
---@param resource string Nome do resource
---@param path string Caminho do módulo (sem .lua)
---@return any
function module(resource, path)
    local key = resource .. '/' .. path
    if vRP._modules[key] then
        return vRP._modules[key]
    end

    local code = LoadResourceFile(resource, path .. '.lua')
    if not code then
        code = LoadResourceFile(resource, path)
    end

    if code then
        local func, err = load(code, '@' .. resource .. '/' .. path .. '.lua')
        if func then
            local result = func()
            if result ~= nil then
                vRP._modules[key] = result
            end
            return result
        else
            print('^1[NOVA Bridge] ^0Erro ao carregar módulo ' .. key .. ': ' .. tostring(err))
        end
    end

    return nil
end

--- Formata um número com separador de milhar
---@param n number
---@return string
function formatNumber(n)
    if not n then return '0' end
    local formatted = tostring(math.floor(n))
    local k
    while true do
        formatted, k = string.gsub(formatted, '^(-?%d+)(%d%d%d)', '%1.%2')
        if k == 0 then break end
    end
    return formatted
end
