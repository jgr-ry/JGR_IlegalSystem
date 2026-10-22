-- Servidor: creación de bandas (/givegang + asistente /creategang)

local CreationTokens = {}

local FirstNames = {"Paquito", "Jose", "Maria", "Carlos", "Lucia", "Miguel", "Antonio", "Elena", "Jorge", "Laura", "Hector", "Sofia", "Diego"}
local LastNames = {"Porras", "Garcia", "Rodriguez", "Lopez", "Martinez", "Sanchez", "Perez", "Gomez", "Martin", "Ramos", "Ruiz", "Hernandez"}

local function GenerateNPCName()
    local fn = FirstNames[math.random(#FirstNames)]
    local ln = LastNames[math.random(#LastNames)]
    return fn .. " " .. ln
end

local function inList(list, value)
    for _, v in ipairs(list or {}) do
        if v == value then return true end
    end
    return false
end

--- Valida y normaliza los datos del asistente (vienen del cliente: no se confía en nada).
--- @return table|nil datos limpios, string|nil motivo del error
local function ValidateGangData(data)
    if type(data) ~= "table" or type(data.config) ~= "table" or type(data.npc) ~= "table" then
        return nil, "datos incompletos"
    end

    local name = Bridge.Util.CleanText(data.config.name, 30)
    if not name or #name < 3 then return nil, "nombre inválido (3-30 caracteres)" end

    local color = type(data.config.color) == "string" and data.config.color:match("^#%x%x%x%x%x%x$") or "#a855f7"

    -- Rangos: { [nombre] = { permisos booleanos... } }
    local ranks, count = {}, 0
    local maxRoles = tonumber(Config.GangSystem.MaxRoles) or 10
    if type(data.config.ranks) == "table" then
        for rankName, perms in pairs(data.config.ranks) do
            local cleanName = Bridge.Util.CleanText(rankName, 30)
            if cleanName and count < maxRoles then
                local cleanPerms = {}
                if type(perms) == "table" then
                    for k, v in pairs(perms) do
                        if type(k) == "string" and #k <= 40 and type(v) == "boolean" then cleanPerms[k] = v end
                    end
                end
                ranks[cleanName] = cleanPerms
                count = count + 1
            end
        end
    end
    local hasBoss = false
    for rankName, perms in pairs(ranks) do
        local low = string.lower(rankName)
        if perms.isBoss or low == "jefe" or low == "boss" then hasBoss = true break end
    end
    if not hasBoss then ranks["Jefe"] = { isBoss = true } end

    local model = data.npc.model
    if type(model) ~= "string" or not inList(Config.GangSystem.CreatorModels, model) then
        return nil, "modelo de NPC no permitido"
    end

    local c = data.npc.coords
    local x, y, z
    if type(c) == "table" or type(c) == "vector3" or type(c) == "vector4" then
        x, y, z = tonumber(c.x), tonumber(c.y), tonumber(c.z)
    end
    if not (x and y and z) then return nil, "coordenadas del NPC inválidas" end

    local spec = data.specialization
    if not inList(Config.GangSystem.Specializations, spec) then
        return nil, "especialización inválida"
    end

    return {
        name = name,
        color = color,
        ranks = ranks,
        model = model,
        coords = { x = x, y = y, z = z, h = tonumber(data.npc.heading) or 0.0 },
        specialization = spec,
    }
end

JGR.RegisterModule("gang_creator_server", function()

    -- /givegang [ID] — da permiso de un solo uso para crear una banda (solo admins)
    RegisterCommand('givegang', function(source, args)
        local admin = source
        if not Bridge.IsAdmin(admin) then
            Bridge.Notify(admin, _L('no_permission'), "error")
            return
        end

        local targetId = tonumber(args[1])
        if not targetId or not Bridge.IsOnline(targetId) then
            Bridge.Notify(admin, _L('player_not_found'), "error")
            return
        end

        CreationTokens[targetId] = true
        Bridge.Notify(admin, _L('token_granted', targetId), "success")
        Bridge.Notify(targetId, _L('token_received'), "success")
    end, false)

    AddEventHandler('playerDropped', function()
        CreationTokens[source] = nil
    end)

    lib.callback.register('JGR_IlegalSystem:server:CheckToken', function(source)
        return CreationTokens[source] == true
    end)

    RegisterNetEvent('JGR_IlegalSystem:server:SaveGang', function(data)
        local src = source
        if not CreationTokens[src] then
            if Config.Debug then print(("[JGR_WARNING] El jugador %s intentó guardar una banda sin permiso."):format(src)) end
            return
        end

        local clean, err = ValidateGangData(data)
        if not clean then
            Bridge.Notify(src, _L('gang_creation_failed') .. " (" .. tostring(err) .. ")", "error")
            return
        end

        local existing = MySQL.scalar.await('SELECT name FROM jgr_gangs WHERE name = ?', { clean.name })
        if existing then
            Bridge.Notify(src, _L('gang_already_exists'), "error")
            return
        end

        -- Se consume el permiso antes de insertar para evitar dobles envíos simultáneos.
        CreationTokens[src] = nil

        local id = MySQL.insert.await('INSERT INTO jgr_gangs (name, color, ranks, npc_model, npc_name, coords, specialization) VALUES (?, ?, ?, ?, ?, ?, ?)', {
            clean.name, clean.color, json.encode(clean.ranks), clean.model, GenerateNPCName(), json.encode(clean.coords), clean.specialization
        })

        if id then
            Bridge.Notify(src, _L('gang_created'), "success")
            if Config.Debug then print(("[JGR_IlegalSystem] Banda creada: %s (especialización: %s)"):format(clean.name, clean.specialization)) end
            TriggerClientEvent('JGR_IlegalSystem:client:RefreshNPCs', -1)
        else
            CreationTokens[src] = true -- devolver el permiso si falló la base de datos
            Bridge.Notify(src, _L('gang_creation_failed'), "error")
        end
    end)
end)
