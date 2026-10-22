--[[
    JGR_IlegalSystem · Bridge compartido (cliente + servidor)
    ------------------------------------------------------------------------
    Detecta el framework y expone utilidades comunes. El resto del código
    NUNCA llama directamente a un framework: usa las funciones Bridge.*
    definidas aquí, en bridge/client.lua y en bridge/server.lua.

    Config.Framework:
      'auto' (recomendado) | 'qb' | 'qbx' | 'esx' | 'standalone'
      Se aceptan también los valores antiguos: 'qbcore', 'qb-core', 'qbox', 'es_extended', 'ox', 'ox_core'.

    Orden de detección automática: qbx_core → qb-core → es_extended → ox_core → standalone.
    ox_core se trata como standalone (identificador = license, permisos por ACE,
    dinero/items vía ox_inventory).
]]

Bridge = Bridge or {}

local FRAMEWORK_ALIASES = {
    auto = 'auto',
    qb = 'qb', qbcore = 'qb', ['qb-core'] = 'qb',
    qbx = 'qbx', qbox = 'qbx', qbx_core = 'qbx',
    esx = 'esx', es_extended = 'esx',
    standalone = 'standalone', ox = 'standalone', ox_core = 'standalone', none = 'standalone',
}

local function resourceExists(name)
    local state = GetResourceState(name)
    return state ~= 'missing' and state ~= 'unknown'
end

local function detectFramework()
    local wanted = FRAMEWORK_ALIASES[string.lower(tostring(Config.Framework or 'auto'))]
    if not wanted then
        print(('^3[JGR_IlegalSystem]^7 Config.Framework = "%s" no es válido; se usa detección automática.'):format(tostring(Config.Framework)))
        wanted = 'auto'
    end
    if wanted ~= 'auto' then return wanted end

    if resourceExists('qbx_core') then return 'qbx' end
    if resourceExists('qb-core') then return 'qb' end
    if resourceExists('es_extended') then return 'esx' end
    return 'standalone'
end

--- 'qb' | 'qbx' | 'esx' | 'standalone'
Bridge.Framework = detectFramework()
Bridge.IsOxCore = resourceExists('ox_core')

function Bridge.IsStarted(name)
    return GetResourceState(name) == 'started'
end

--- Objeto del framework (se obtiene de forma perezosa, cuando ya ha arrancado).
local coreObject = nil
function Bridge.GetCore()
    if coreObject then return coreObject end
    local fw = Bridge.Framework
    local ok, obj = false, nil
    if fw == 'qb' then
        ok, obj = pcall(function() return exports['qb-core']:GetCoreObject() end)
    elseif fw == 'qbx' then
        -- Qbox NO exporta GetCoreObject bajo qbx_core; solo existe el puente de compatibilidad 'qb-core'.
        -- Se usa únicamente para QBCore.Shared.Items en clientes con qb-inventory (casi nunca en Qbox).
        ok, obj = pcall(function() return exports['qb-core']:GetCoreObject() end)
    elseif fw == 'esx' then
        ok, obj = pcall(function() return exports['es_extended']:getSharedObject() end)
    end
    if ok and obj then coreObject = obj end
    return coreObject
end

-- Compatibilidad con código antiguo que leía Bridge.Core directamente.
setmetatable(Bridge, {
    __index = function(_, key)
        if key == 'Core' then return Bridge.GetCore() end
    end
})

-- ---------------------------------------------------------------------------
-- Utilidades compartidas
-- ---------------------------------------------------------------------------
Bridge.Util = {}

function Bridge.Util.Trim(value)
    if type(value) ~= 'string' then return value end
    return value:match('^%s*(.-)%s*$')
end

--- Limpia un texto enviado por el cliente: quita caracteres que podrían inyectar
--- HTML/JS en la NUI de otros jugadores, controla la longitud y recorta espacios.
--- @return string|nil nil si no es un texto válido o queda vacío
function Bridge.Util.CleanText(value, maxLen, allowEmpty)
    if type(value) == 'number' then value = tostring(value) end
    if type(value) ~= 'string' then return nil end
    value = value:gsub('[%c]', ' '):gsub('[<>"\'`\\]', '')
    value = Bridge.Util.Trim(value) or ''
    if maxLen and #value > maxLen then value = value:sub(1, maxLen) end
    if value == '' and not allowEmpty then return nil end
    return value
end

--- Igual que CleanText pero conserva saltos de línea (textos largos como documentos).
function Bridge.Util.CleanMultiline(value, maxLen)
    if type(value) ~= 'string' then return '' end
    value = value:gsub('[\0-\8\11\12\14-\31]', ''):gsub('[<>`\\]', '')
    if maxLen and #value > maxLen then value = value:sub(1, maxLen) end
    return value
end

--- Entero positivo dentro de [min, max] o nil.
function Bridge.Util.ToInt(value, min, max)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return nil end
    value = math.floor(value)
    if min and value < min then return nil end
    if max and value > max then return nil end
    return value
end

function Bridge.Util.SafeDecode(raw, default)
    if type(raw) == 'table' then return raw end
    if type(raw) ~= 'string' or raw == '' then return default end
    local ok, data = pcall(json.decode, raw)
    if ok and type(data) == 'table' then return data end
    return default
end

local warned = {}
--- Avisa una sola vez en consola (para funciones que no existen en un framework).
function Bridge.WarnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    print(('^3[JGR_IlegalSystem]^7 %s'):format(msg))
end

CreateThread(function()
    local labels = { qb = 'QBCore', qbx = 'Qbox', esx = 'ESX Legacy', standalone = Bridge.IsOxCore and 'ox_core (modo standalone)' or 'Standalone' }
    if Config.Debug then
        print(('^2[JGR_IlegalSystem]^7 Framework detectado: ^5%s^7'):format(labels[Bridge.Framework] or Bridge.Framework))
    end
end)
