-- Servidor: menú de banda (miembros, rangos, documentos, territorios, puntos, almacén y garaje)

JGR.RegisterModule("gang_menu_server", function()
    local U = Bridge.Util

    local MAX_DOCUMENTS = tonumber(Config.GangSystem.MaxDocuments) or 100
    local MAX_TERRITORIES = tonumber(Config.GangSystem.MaxTerritories) or 50
    local MAX_DOC_LENGTH = 5000
    local PERM_KEYS = { "manage_members", "manage_points", "manage_ranks", "manage_docs", "manage_territories" }

    local function L(key, ...)
        local t = Locales[Config.Locale] and Locales[Config.Locale][key]
        if not t then return nil end
        return select('#', ...) > 0 and string.format(t, ...) or t
    end

    local function isRankBoss(rankName, r)
        if not rankName then return false end
        if type(r) == "table" and r.isBoss then return true end
        local n = string.lower(tostring(rankName))
        return n == "jefe" or n == "boss"
    end

    --- Orden: jefe primero (índice 0 en /setgang), resto por nombre estable.
    local function orderedRankNames(ranks)
        if type(ranks) ~= "table" then return {} end
        local bossName = nil
        local rest = {}
        for name, data in pairs(ranks) do
            if isRankBoss(name, data) then
                if not bossName then bossName = name end
            else
                rest[#rest + 1] = name
            end
        end
        table.sort(rest)
        local out = {}
        if bossName then out[#out + 1] = bossName end
        for _, n in ipairs(rest) do out[#out + 1] = n end
        return out
    end

    local function memberHasPermission(rankName, ranks, key)
        if not rankName or type(ranks) ~= "table" then return false end
        local r = ranks[rankName]
        if r == nil then
            return isRankBoss(rankName, {})
        end
        if isRankBoss(rankName, r) then return true end
        if type(r) ~= "table" then return false end
        return r[key] == true
    end

    --- Coincidir rango del desplegable con la clave en JSON (mayúsculas / espacios).
    local function resolveRankNameKey(requested, ranksData)
        if type(requested) ~= "string" or type(ranksData) ~= "table" then return nil end
        if ranksData[requested] ~= nil then return requested end
        local rl = string.lower(U.Trim(requested) or "")
        for k in pairs(ranksData) do
            if string.lower(tostring(k)) == rl then return k end
        end
        return nil
    end

    --- Banda y rango del jugador. @return gangName, rankName, citizenid
    local function getMembership(src)
        local citizenid = Bridge.GetIdentifier(src)
        if not citizenid then return nil end
        local row = MySQL.single.await('SELECT gang_name, `rank` FROM jgr_gang_members WHERE citizenid = ? LIMIT 1', { citizenid })
        if not row then return nil, nil, citizenid end
        return row.gang_name, row.rank, citizenid
    end

    local function loadGang(gangName)
        local row = MySQL.single.await('SELECT * FROM jgr_gangs WHERE name = ?', { gangName })
        if not row then return nil end
        row.ranks = U.SafeDecode(row.ranks, {})
        for rk, rv in pairs(row.ranks) do
            if type(rv) ~= "table" then row.ranks[rk] = {} end
        end
        row.coords = U.SafeDecode(row.coords, {})
        row.stats = U.SafeDecode(row.stats, {})
        return row
    end

    local function saveStats(gangName, stats)
        MySQL.update.await('UPDATE jgr_gangs SET stats = ? WHERE name = ?', { json.encode(stats), gangName })
    end

    local function saveRanks(gangName, ranks)
        MySQL.update.await('UPDATE jgr_gangs SET ranks = ? WHERE name = ?', { json.encode(ranks), gangName })
    end

    --- Comprueba banda + permiso del jugador. @return gangName, gangRow, rankName | nil
    local function requirePermission(src, permKey)
        local gangName, rankName = getMembership(src)
        if not gangName then return nil end
        local gang = loadGang(gangName)
        if not gang then return nil end
        if permKey and not memberHasPermission(rankName, gang.ranks, permKey) then
            Bridge.Notify(src, L('no_permission') or "Sin permiso.", "error")
            return nil
        end
        return gangName, gang, rankName
    end

    local function playerCoords(src)
        local ped = GetPlayerPed(src)
        if not ped or ped == 0 then return nil end
        return GetEntityCoords(ped)
    end

    local function isNear(src, point, maxDist)
        local pc = playerCoords(src)
        if not pc or type(point) ~= "table" or point.x == nil then return false end
        return #(pc - vector3(point.x + 0.0, point.y + 0.0, (point.z or pc.z) + 0.0)) <= maxDist
    end

    local function readCoords(c)
        if type(c) ~= "table" and type(c) ~= "vector3" and type(c) ~= "vector4" then return nil end
        local x, y, z = tonumber(c.x), tonumber(c.y), tonumber(c.z)
        if not (x and y and z) then return nil end
        return { x = x, y = y, z = z }
    end

    -- =============================================
    -- DATOS DEL MENÚ (NUI)
    -- =============================================
    local function getGangMenuData(source, gangName)
        gangName = U.Trim(gangName)
        if type(gangName) ~= "string" or gangName == "" then return nil end

        local myGang, myRankName, citizenid = getMembership(source)
        if not citizenid then return nil end
        -- Solo los miembros (o un admin) pueden ver los datos internos de una banda.
        if myGang ~= gangName then
            if not Bridge.IsAdmin(source) then return nil end
            myRankName = nil
        end

        local gangData = loadGang(gangName)
        if not gangData then return nil end

        local stats = gangData.stats
        stats.documents = type(stats.documents) == "table" and stats.documents or {}
        stats.territories = type(stats.territories) == "table" and stats.territories or {}
        stats.points = type(stats.points) == "table" and stats.points or {}

        local members = MySQL.query.await('SELECT citizenid, `rank` FROM jgr_gang_members WHERE gang_name = ?', { gangName }) or {}
        local ids = {}
        for i, m in ipairs(members) do ids[i] = m.citizenid end
        local info = Bridge.GetCharacterInfo(ids)

        local memberList = {}
        for _, m in ipairs(members) do
            local ci = info[m.citizenid]
            memberList[#memberList + 1] = {
                citizenid = m.citizenid,
                rank = m.rank,
                name = ci and ci.name or m.citizenid,
                phone = ci and ci.phone or "N/A",
            }
        end

        local isAdminView = myRankName == nil
        local perms = { rankName = myRankName, isBoss = isAdminView or isRankBoss(myRankName, gangData.ranks[myRankName]) }
        for _, key in ipairs(PERM_KEYS) do
            perms[key] = isAdminView or memberHasPermission(myRankName, gangData.ranks, key)
        end

        local npcCoords = nil
        if gangData.coords.x and gangData.coords.y then
            npcCoords = { x = gangData.coords.x, y = gangData.coords.y, z = gangData.coords.z, h = gangData.coords.h }
        end

        local controlZone = nil
        local cz = stats.control_zone
        if type(cz) == "table" and cz.x and cz.y then
            controlZone = { x = cz.x, y = cz.y, z = cz.z or 0.0, radius = tonumber(cz.radius) or 100.0 }
        end

        return {
            gang = {
                name = gangData.name,
                color = gangData.color,
                level = gangData.level or 0,
                xp = gangData.xp or 0,
                stats = stats,
                territories = controlZone and 1 or #stats.territories,
                members = memberList,
                documents = stats.documents,
                territories_list = stats.territories,
                ranks = gangData.ranks,
                rank_order = orderedRankNames(gangData.ranks),
                npc_coords = npcCoords,
                control_zone = controlZone
            },
            permissions = perms,
            translations = Locales[Config.Locale] or {}
        }
    end

    lib.callback.register('JGR_IlegalSystem:server:GetGangMenuData', function(source, gangName)
        return getGangMenuData(source, gangName)
    end)

    -- =============================================
    -- PUNTOS DE BANDA Y ALMACÉN
    -- =============================================
    local function gangStashId(gangName)
        return "jgr_gang_" .. tostring(gangName):gsub("%s+", "_")
    end

    local function ensureOxGangStashRegistered(gangName, px, py, pz)
        local coords = nil
        if px and py then coords = vector3(px + 0.0, py + 0.0, (pz or 0.0) + 0.0) end
        Bridge.RegisterStash(gangStashId(gangName), "Almacén · " .. tostring(gangName), 100, 1000000, nil, coords)
    end

    local validPointTypes = {
        stash = true, boss = true,
        garage_menu = true, garage_spawn = true, garage_store = true,
        garage = true,
    }

    RegisterNetEvent('JGR_IlegalSystem:server:SaveGangPoint', function(pointType, coords, heading)
        local src = source
        if type(pointType) ~= "string" or not validPointTypes[pointType] then return end
        local c = readCoords(coords)
        if not c then return end
        -- El punto se coloca con un raycast de 30 m desde la cámara.
        if not isNear(src, c, 40.0) then return end

        local gangName, gang = requirePermission(src, "manage_points")
        if not gangName then return end

        local stats = gang.stats
        if type(stats.points) ~= "table" then stats.points = {} end
        stats.points[pointType] = { x = c.x, y = c.y, z = c.z, h = tonumber(heading) or 0.0 }
        saveStats(gangName, stats)
        if pointType == "stash" then
            ensureOxGangStashRegistered(gangName, c.x, c.y, c.z)
        end
        TriggerClientEvent('JGR_IlegalSystem:client:RefreshGangPoints', src)
    end)

    local function useOxForGangStash()
        local pref = string.lower(tostring(Config.GangInventory or "auto"))
        if pref == "qb-inventory" then return false end
        return Bridge.IsStarted("ox_inventory")
    end

    RegisterNetEvent('JGR_IlegalSystem:server:RequestOpenGangStash', function()
        local src = source
        local gangName, gang = requirePermission(src, nil)
        if not gangName then return end

        local stash = type(gang.stats.points) == "table" and gang.stats.points.stash
        if not stash or stash.x == nil then
            Bridge.Notify(src, "La banda no tiene almacén colocado.", "error")
            return
        end
        if not isNear(src, stash, 3.2) then
            Bridge.Notify(src, "Demasiado lejos del almacén.", "error")
            return
        end

        if useOxForGangStash() then
            Bridge.OpenStash(src, gangStashId(gangName), {
                label = "Almacén · " .. gangName, slots = 100, weight = 1000000,
                coords = vector3(stash.x + 0.0, stash.y + 0.0, stash.z + 0.0),
            })
        else
            -- Mismo identificador que en versiones anteriores para conservar el contenido.
            Bridge.OpenStash(src, "gangstash_" .. gangName, { label = "Almacén · " .. gangName, slots = 100, weight = 1000000 })
        end
    end)

    -- =============================================
    -- GARAJE DE BANDA
    -- =============================================
    lib.callback.register('JGR_IlegalSystem:server:GetGangGarageVehicles', function(source)
        local gangName = getMembership(source)
        if not gangName then return {} end
        local gang = loadGang(gangName)
        local gg = gang and gang.stats.gang_garage
        if type(gg) ~= "table" or type(gg.vehicles) ~= "table" then return {} end
        return gg.vehicles
    end)

    local function plateOf(value)
        return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
    end

    RegisterNetEvent('JGR_IlegalSystem:server:SaveGangGarageVehicle', function(props)
        local src = source
        if type(props) ~= "table" or not props.model then return end

        -- El vehículo se comprueba en el servidor: el cliente no puede "guardar" un coche que no tiene.
        local ped = GetPlayerPed(src)
        local veh = ped and ped ~= 0 and GetVehiclePedIsIn(ped, false) or 0
        if veh == 0 or not DoesEntityExist(veh) or GetPedInVehicleSeat(veh, -1) ~= ped then
            Bridge.Notify(src, "Debes ser el conductor de un vehículo.", "error")
            return
        end
        local realModel = GetEntityModel(veh)
        local propModel = tonumber(props.model) or (type(props.model) == "string" and joaat(props.model)) or nil
        if not propModel or (propModel & 0xFFFFFFFF) ~= (realModel & 0xFFFFFFFF) then
            Bridge.Notify(src, "No se pudieron leer los datos del vehículo.", "error")
            return
        end
        props.plate = plateOf(GetVehicleNumberPlateText(veh))
        local encoded = json.encode(props)
        if #encoded > 16000 then
            Bridge.Notify(src, "Los datos del vehículo son demasiado grandes.", "error")
            return
        end

        local gangName, gang = requirePermission(src, "manage_points")
        if not gangName then return end

        local stats = gang.stats
        local store = type(stats.points) == "table" and stats.points.garage_store
        if not store or store.x == nil then
            Bridge.Notify(src, "Falta colocar el punto de guardado de vehículos.", "error")
            return
        end
        if not isNear(src, store, 6.0) then
            Bridge.Notify(src, "Acércate al punto de guardado del garaje.", "error")
            return
        end
        if type(stats.gang_garage) ~= "table" then stats.gang_garage = { vehicles = {} } end
        if type(stats.gang_garage.vehicles) ~= "table" then stats.gang_garage.vehicles = {} end
        local maxV = tonumber(Config.GangGarageMaxVehicles) or 8
        if #stats.gang_garage.vehicles >= maxV then
            Bridge.Notify(src, "Garaje lleno.", "error")
            return
        end

        props.stored_at = os.date("%d/%m/%Y %H:%M")
        table.insert(stats.gang_garage.vehicles, props)
        saveStats(gangName, stats)

        TriggerClientEvent('JGR_IlegalSystem:client:DeleteGarageVehicleEntity', src)
        -- Por si el cliente no lo borra (o hace trampas), se elimina también desde el servidor.
        SetTimeout(1500, function()
            if DoesEntityExist(veh) then DeleteEntity(veh) end
        end)
        Bridge.Notify(src, "Vehículo guardado en el garaje de la banda.", "success")
        TriggerClientEvent('JGR_IlegalSystem:client:RefreshGangPoints', src)
    end)

    RegisterNetEvent('JGR_IlegalSystem:server:SpawnGangGarageVehicle', function(index)
        local src = source
        local idx = U.ToInt(index, 1, 1000)
        if not idx then return end

        local gangName, gang = requirePermission(src, nil)
        if not gangName then return end

        local stats = gang.stats
        local points = type(stats.points) == "table" and stats.points or {}
        local menu = points.garage_menu
        if not menu or menu.x == nil then menu = points.garage end
        local spawn = points.garage_spawn
        if not menu or menu.x == nil or not spawn or spawn.x == nil then
            Bridge.Notify(src, "Faltan puntos de garaje (menú o aparición).", "error")
            return
        end
        if not isNear(src, menu, 3.5) then
            Bridge.Notify(src, "Debes estar en el punto de menú del garaje.", "error")
            return
        end
        local gg = stats.gang_garage
        if type(gg) ~= "table" or type(gg.vehicles) ~= "table" or not gg.vehicles[idx] then
            Bridge.Notify(src, "Vehículo no encontrado.", "error")
            return
        end
        local props = table.remove(gg.vehicles, idx)
        saveStats(gangName, stats)
        TriggerClientEvent('JGR_IlegalSystem:client:SpawnGangGarageVehicle', src, props, spawn)
        Bridge.Notify(src, "Saliendo vehículo del garaje…", "success")
    end)

    -- =============================================
    -- MIEMBROS
    -- =============================================
    RegisterNetEvent('JGR_IlegalSystem:server:InviteMember', function(targetId, rankName)
        local src = source
        targetId = tonumber(targetId)
        rankName = U.Trim(rankName)
        if type(rankName) ~= "string" or rankName == "" then
            Bridge.Notify(src, "Rango no válido.", "error")
            return
        end
        if not targetId or targetId == src or not Bridge.IsOnline(targetId) then
            Bridge.Notify(src, L('player_not_found') or "Jugador no encontrado.", "error")
            return
        end

        local gangName, gang, myRank = requirePermission(src, "manage_members")
        if not gangName then return end

        local targetCitizenId = Bridge.GetIdentifier(targetId)
        if not targetCitizenId then
            Bridge.Notify(src, L('player_not_found') or "Jugador no encontrado.", "error")
            return
        end

        local resolvedRank = resolveRankNameKey(rankName, gang.ranks)
        if not resolvedRank then
            Bridge.Notify(src, L('rank_not_found', rankName, gangName) or "El rango especificado no existe", "error")
            return
        end
        -- Solo el jefe puede asignar el rango de jefe.
        if isRankBoss(resolvedRank, gang.ranks[resolvedRank]) and not isRankBoss(myRank, gang.ranks[myRank]) then
            Bridge.Notify(src, L('no_permission') or "Sin permiso.", "error")
            return
        end

        local targetGang = MySQL.scalar.await('SELECT gang_name FROM jgr_gang_members WHERE citizenid = ? LIMIT 1', { targetCitizenId })
        if targetGang and targetGang ~= gangName then
            Bridge.Notify(src, "Ese jugador ya pertenece a otra banda.", "error")
            return
        end

        local targetName = GetPlayerName(targetId) or tostring(targetId)
        if targetGang == gangName then
            local targetRank = MySQL.scalar.await('SELECT `rank` FROM jgr_gang_members WHERE citizenid = ? AND gang_name = ?', { targetCitizenId, gangName })
            if isRankBoss(targetRank, gang.ranks[targetRank]) and not isRankBoss(myRank, gang.ranks[myRank]) then
                Bridge.Notify(src, L('no_permission') or "Sin permiso.", "error")
                return
            end
            MySQL.update.await('UPDATE jgr_gang_members SET `rank` = ? WHERE citizenid = ? AND gang_name = ?', { resolvedRank, targetCitizenId, gangName })
            Bridge.Notify(src, L('gang_member_updated', targetName, gangName, resolvedRank) or "Miembro actualizado", "success")
        else
            local maxMembers = tonumber(gang.max_members) or 10
            local current = MySQL.scalar.await('SELECT COUNT(*) FROM jgr_gang_members WHERE gang_name = ?', { gangName }) or 0
            if current >= maxMembers then
                Bridge.Notify(src, ("La banda está completa (%d/%d miembros)."):format(current, maxMembers), "error")
                return
            end
            MySQL.insert.await('INSERT INTO jgr_gang_members (gang_name, citizenid, `rank`) VALUES (?, ?, ?)', { gangName, targetCitizenId, resolvedRank })
            Bridge.Notify(src, L('gang_member_added', targetName, gangName, resolvedRank) or "Miembro reclutado", "success")
        end
        Bridge.Notify(targetId, L('you_are_now_in_gang', gangName, resolvedRank) or "Ahora estás en la banda", "success")
        TriggerClientEvent('JGR_IlegalSystem:client:RefreshNPCs', targetId)
        TriggerClientEvent('JGR_IlegalSystem:client:RequestGangMenuResync', src)
    end)

    RegisterNetEvent('JGR_IlegalSystem:server:KickMember', function(targetCitizenId)
        local src = source
        if type(targetCitizenId) ~= "string" then return end

        local adminCid = Bridge.GetIdentifier(src)
        if not adminCid or adminCid == targetCitizenId then return end
        local gangName, gang = requirePermission(src, "manage_members")
        if not gangName then return end

        local tRank = MySQL.scalar.await('SELECT `rank` FROM jgr_gang_members WHERE citizenid = ? AND gang_name = ?', { targetCitizenId, gangName })
        if not tRank then
            Bridge.Notify(src, L('player_not_found') or "Miembro no encontrado.", "error")
            return
        end
        if isRankBoss(tRank, gang.ranks[tRank]) then
            Bridge.Notify(src, "No puedes expulsar al jefe.", "error")
            return
        end

        MySQL.update.await('DELETE FROM jgr_gang_members WHERE citizenid = ? AND gang_name = ?', { targetCitizenId, gangName })
        Bridge.Notify(src, "Miembro expulsado.", "success")
        TriggerClientEvent('JGR_IlegalSystem:client:RequestGangMenuResync', src)

        local tid = Bridge.GetSourceFromIdentifier(targetCitizenId)
        if tid then
            TriggerClientEvent('JGR_IlegalSystem:client:RefreshNPCs', tid)
            Bridge.Notify(tid, "Has sido expulsado de la banda.", "error")
        end
    end)

    -- =============================================
    -- DOCUMENTOS
    -- =============================================
    RegisterNetEvent('JGR_IlegalSystem:server:SaveDocument', function(docId, title, content)
        local src = source
        title = U.CleanText(title, 80)
        if not title then
            Bridge.Notify(src, "El documento necesita un título.", "error")
            return
        end
        content = U.CleanMultiline(content, MAX_DOC_LENGTH)

        local gangName, gang = requirePermission(src, "manage_docs")
        if not gangName then return end

        local stats = gang.stats
        if type(stats.documents) ~= "table" then stats.documents = {} end

        if docId ~= nil and docId ~= "" then
            docId = tostring(docId)
            for _, doc in ipairs(stats.documents) do
                if tostring(doc.id) == docId then
                    doc.title = title
                    doc.content = content
                    doc.date = os.date("%d/%m/%Y %H:%M")
                    break
                end
            end
        else
            if #stats.documents >= MAX_DOCUMENTS then
                Bridge.Notify(src, ("Límite de documentos alcanzado (%d)."):format(MAX_DOCUMENTS), "error")
                return
            end
            table.insert(stats.documents, {
                id = tostring(os.time()) .. tostring(math.random(1000, 9999)),
                title = title,
                content = content,
                date = os.date("%d/%m/%Y %H:%M")
            })
        end
        saveStats(gangName, stats)
        TriggerClientEvent('JGR_IlegalSystem:client:UpdateDocuments', src, stats.documents)
    end)

    RegisterNetEvent('JGR_IlegalSystem:server:DeleteDocument', function(docId)
        local src = source
        if docId == nil then return end
        docId = tostring(docId)
        local gangName, gang = requirePermission(src, "manage_docs")
        if not gangName then return end

        local stats = gang.stats
        if type(stats.documents) ~= "table" then return end
        for i, doc in ipairs(stats.documents) do
            if tostring(doc.id) == docId then
                table.remove(stats.documents, i)
                break
            end
        end
        saveStats(gangName, stats)
        TriggerClientEvent('JGR_IlegalSystem:client:UpdateDocuments', src, stats.documents)
    end)

    -- =============================================
    -- TERRITORIOS (stats.territories) Y ZONA DE CONTROL
    -- =============================================
    RegisterNetEvent('JGR_IlegalSystem:server:SaveTerritory', function(terrId, title, content, influence, coords)
        local src = source
        title = U.CleanText(title, 80, true) or ""
        content = U.CleanMultiline(content, 2000)
        local inf = math.max(0, math.min(100, tonumber(influence) or 0))
        local c = coords and readCoords(coords) or nil

        local gangName, gang = requirePermission(src, "manage_territories")
        if not gangName then return end

        local stats = gang.stats
        if type(stats.territories) ~= "table" then stats.territories = {} end

        if terrId ~= nil and tostring(terrId) ~= "" then
            terrId = tostring(terrId)
            for _, t in ipairs(stats.territories) do
                if tostring(t.id) == terrId then
                    t.title = title
                    t.content = content
                    t.influence = inf
                    t.date = os.date("%d/%m/%Y %H:%M")
                    if c then t.wx, t.wy, t.wz = c.x, c.y, c.z end
                    break
                end
            end
        else
            if #stats.territories >= MAX_TERRITORIES then
                Bridge.Notify(src, ("Límite de territorios alcanzado (%d)."):format(MAX_TERRITORIES), "error")
                return
            end
            table.insert(stats.territories, {
                id = tostring(os.time()) .. tostring(math.random(1000, 9999)),
                title = title,
                content = content,
                influence = inf,
                wx = c and c.x, wy = c and c.y, wz = c and c.z,
                date = os.date("%d/%m/%Y %H:%M")
            })
        end

        saveStats(gangName, stats)
        TriggerClientEvent('JGR_IlegalSystem:client:UpdateTerritories', src, stats.territories, #stats.territories)
    end)

    RegisterNetEvent('JGR_IlegalSystem:server:SaveControlZone', function(wx, wy, wz, radius)
        local src = source
        if type(wx) ~= "number" or type(wy) ~= "number" then return end
        local rad = math.max(10.0, math.min(500.0, tonumber(radius) or 100.0))

        local gangName, gang = requirePermission(src, "manage_territories")
        if not gangName then return end

        local stats = gang.stats
        stats.control_zone = {
            x = wx,
            y = wy,
            z = type(wz) == "number" and wz or 0.0,
            radius = rad,
            updated = os.date("%d/%m/%Y %H:%M")
        }
        saveStats(gangName, stats)
        Bridge.Notify(src, "Zona de control actualizada.", "success")
        TriggerClientEvent('JGR_IlegalSystem:client:UpdateControlZone', src, stats.control_zone)
    end)

    RegisterNetEvent('JGR_IlegalSystem:server:DeleteTerritory', function(terrId)
        local src = source
        if terrId == nil then return end
        terrId = tostring(terrId)
        local gangName, gang = requirePermission(src, "manage_territories")
        if not gangName then return end

        local stats = gang.stats
        if type(stats.territories) ~= "table" then return end
        for i, t in ipairs(stats.territories) do
            if tostring(t.id) == terrId then
                table.remove(stats.territories, i)
                break
            end
        end
        saveStats(gangName, stats)
        TriggerClientEvent('JGR_IlegalSystem:client:UpdateTerritories', src, stats.territories, #stats.territories)
    end)

    -- =============================================
    -- RANGOS
    -- =============================================
    local function afterRanksChanged(src, ranks)
        TriggerClientEvent('JGR_IlegalSystem:client:UpdateRanks', src, ranks)
        TriggerClientEvent('JGR_IlegalSystem:client:RequestGangMenuResync', src)
    end

    RegisterNetEvent('JGR_IlegalSystem:server:CreateRank', function(rankName)
        local src = source
        rankName = U.CleanText(rankName, 30)
        if not rankName then return end

        local gangName, gang = requirePermission(src, "manage_ranks")
        if not gangName then return end

        local ranks = gang.ranks
        if resolveRankNameKey(rankName, ranks) then
            Bridge.Notify(src, "El rango '" .. rankName .. "' ya existe.", "error")
            return
        end
        local count = 0
        for _ in pairs(ranks) do count = count + 1 end
        local maxRoles = tonumber(Config.GangSystem.MaxRoles) or 10
        if count >= maxRoles then
            Bridge.Notify(src, ("Límite de rangos alcanzado (%d)."):format(maxRoles), "error")
            return
        end
        -- Un rango nuevo nunca puede llamarse como el de jefe (heredaría todos los permisos).
        if isRankBoss(rankName, {}) then
            Bridge.Notify(src, "Ese nombre está reservado para el rango de jefe.", "error")
            return
        end

        ranks[rankName] = {}
        saveRanks(gangName, ranks)
        Bridge.Notify(src, "Rango '" .. rankName .. "' creado correctamente.", "success")
        afterRanksChanged(src, ranks)
    end)

    RegisterNetEvent('JGR_IlegalSystem:server:DeleteRank', function(rankName)
        local src = source
        if type(rankName) ~= "string" then return end

        local gangName, gang = requirePermission(src, "manage_ranks")
        if not gangName then return end

        local ranks = gang.ranks
        if not ranks[rankName] then
            Bridge.Notify(src, "El rango no existe.", "error")
            return
        end
        if isRankBoss(rankName, ranks[rankName]) then
            Bridge.Notify(src, "No puedes eliminar el rango de Jefe.", "error")
            return
        end
        ranks[rankName] = nil
        saveRanks(gangName, ranks)
        Bridge.Notify(src, "Rango '" .. rankName .. "' eliminado.", "success")
        afterRanksChanged(src, ranks)
    end)

    RegisterNetEvent('JGR_IlegalSystem:server:UpdateRankPermissions', function(rankName, permissions)
        local src = source
        if type(rankName) ~= "string" or type(permissions) ~= "table" then return end

        local gangName, gang = requirePermission(src, "manage_ranks")
        if not gangName then return end

        local ranks = gang.ranks
        if not ranks[rankName] then return end
        if isRankBoss(rankName, ranks[rankName]) then
            Bridge.Notify(src, "No puedes cambiar permisos del rango de jefe desde aquí.", "error")
            return
        end

        for _, key in ipairs(PERM_KEYS) do
            ranks[rankName][key] = permissions[key] == true
        end
        saveRanks(gangName, ranks)
        Bridge.Notify(src, "Permisos de '" .. rankName .. "' actualizados.", "success")
        afterRanksChanged(src, ranks)
    end)
end)
