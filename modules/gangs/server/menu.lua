JGR.RegisterModule("gang_menu_server", function()
    local function isRankBoss(rankName, r)
        if not rankName then return false end
        if type(r) ~= "table" then
            local n = string.lower(tostring(rankName))
            return n == "jefe" or n == "boss"
        end
        if r.isBoss then return true end
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
        if #out == 0 then
            for k in pairs(ranks) do out[#out + 1] = k end
            table.sort(out)
        end
        return out
    end

    -- Fetch Gang Data for NUI
    local function getGangMenuData(source, gangName, cb)
        if type(gangName) == "string" then
            gangName = gangName:match("^%s*(.-)%s*$") or gangName
        end
        if not gangName or gangName == "" then return cb(nil) end

        local citizenid = nil
        if Config.Framework == "qbcore" then
            local Player = Bridge.Core.Functions.GetPlayer(source)
            if Player then citizenid = Player.PlayerData.citizenid end
        elseif Config.Framework == "esx" then
            local Player = Bridge.Core.GetPlayerFromId(source)
            if Player then citizenid = Player.identifier end
        end

        if not citizenid then return cb(nil) end

        -- Fetch main gang details
        MySQL.query('SELECT * FROM jgr_gangs WHERE name = ?', {gangName}, function(gangResult)
            if not gangResult or #gangResult == 0 then return cb(nil) end
            local gangData = gangResult[1]
            do
                local okR, ranks = pcall(json.decode, gangData.ranks or "{}")
                gangData.ranks = (okR and type(ranks) == "table") and ranks or {}
                for rk, rv in pairs(gangData.ranks) do
                    if type(rv) ~= "table" then
                        gangData.ranks[rk] = {}
                    end
                end
                local okC, coords = pcall(json.decode, gangData.coords or "{}")
                gangData.coords = (okC and type(coords) == "table") and coords or {}
            end
            
            -- Parse new level stats safely
            if gangData.stats and gangData.stats ~= "" then
                local okS, st = pcall(json.decode, gangData.stats)
                gangData.stats = (okS and type(st) == "table") and st or {}
            else
                gangData.stats = {}
            end
            if not gangData.stats.documents then gangData.stats.documents = {} end
            if not gangData.stats.territories then gangData.stats.territories = {} end
            if not gangData.stats.points or type(gangData.stats.points) ~= "table" then
                gangData.stats.points = {}
            end
            MySQL.query('SELECT citizenid, rank FROM jgr_gang_members WHERE gang_name = ?', {gangName}, function(members)
                local memberList = {}
                local rawMembers = members or {}

                -- Determine player permissions
                local myRankName = nil

                local function SendPayload(gData, mList, mRank, mIsBoss, cbFunc)
                    local perms = {
                        rankName = mRank,
                        isBoss = mIsBoss,
                        manage_members = mIsBoss,
                        manage_points = mIsBoss,
                        manage_ranks = mIsBoss,
                        manage_docs = mIsBoss,
                        manage_territories = mIsBoss
                    }

                    if mRank and gData.ranks[mRank] then
                        local rData = gData.ranks[mRank]
                        local rankIsBoss = isRankBoss(mRank, rData)
                        perms.isBoss = rankIsBoss
                        if not rankIsBoss then
                            perms.manage_members = rData.manage_members or false
                            perms.manage_points = rData.manage_points or false
                            perms.manage_ranks = rData.manage_ranks or false
                            perms.manage_docs = rData.manage_docs or false
                            perms.manage_territories = rData.manage_territories or false
                        else
                            perms.manage_members = true
                            perms.manage_points = true
                            perms.manage_ranks = true
                            perms.manage_docs = true
                            perms.manage_territories = true
                        end
                    else
                        -- Rango no encontrado en JSON de rangos (nombre distinto / datos viejos): no bloquear el menú
                        perms.isBoss = false
                        perms.manage_members = true
                        perms.manage_points = true
                        perms.manage_ranks = true
                        perms.manage_docs = true
                        perms.manage_territories = true
                    end

                    local terrList = {}
                    if gData.stats and type(gData.stats.territories) == "table" then
                        terrList = gData.stats.territories
                    end

                    local npcCoords = nil
                    if gData.coords and type(gData.coords) == "table" and gData.coords.x and gData.coords.y then
                        npcCoords = {
                            x = gData.coords.x,
                            y = gData.coords.y,
                            z = gData.coords.z,
                            h = gData.coords.h
                        }
                    end

                    local controlZone = nil
                    if gData.stats and type(gData.stats.control_zone) == "table" then
                        local cz = gData.stats.control_zone
                        if cz.x and cz.y then
                            controlZone = {
                                x = cz.x,
                                y = cz.y,
                                z = cz.z or 0.0,
                                radius = tonumber(cz.radius) or 100.0
                            }
                        end
                    end

                    local terrCount = controlZone and 1 or #terrList
                    local rankOrder = orderedRankNames(gData.ranks)

                    local payload = {
                        gang = {
                            name = gData.name,
                            color = gData.color,
                            level = gData.level or 0,
                            xp = gData.xp or 0,
                            stats = gData.stats,
                            territories = terrCount,
                            members = mList,
                            documents = gData.stats.documents or {},
                            territories_list = terrList,
                            ranks = gData.ranks,
                            rank_order = rankOrder,
                            npc_coords = npcCoords,
                            control_zone = controlZone
                        },
                        permissions = perms,
                        translations = Locales[Config.Locale] or {}
                    }
                    cbFunc(payload)
                end

                -- We will process all members, then fetch their names individually to avoid SQL JOIN Collation crashes
                for _, m in ipairs(rawMembers) do
                    if m.citizenid == citizenid then
                        myRankName = m.rank
                    end

                    table.insert(memberList, {
                        citizenid = m.citizenid,
                        rank = m.rank,
                        name = m.citizenid, -- Default to ID, will update below
                        phone = "N/A"
                    })
                end

                local myRankData = myRankName and gangData.ranks[myRankName]
                local isBossPlayer = myRankName and isRankBoss(myRankName, type(myRankData) == "table" and myRankData or {}) or false

                -- Now fill in actual names
                if #memberList > 0 then
                    local pCount = #memberList
                    local processed = 0

                    for i, mem in ipairs(memberList) do
                        if Config.Framework == "qbcore" then
                            MySQL.query('SELECT charinfo FROM players WHERE citizenid = ?', {mem.citizenid}, function(pRes)
                                if pRes and pRes[1] and pRes[1].charinfo then
                                    local okI, info = pcall(json.decode, pRes[1].charinfo)
                                    if okI and type(info) == "table" and info then
                                        mem.name = (info.firstname or "") .. " " .. (info.lastname or "")
                                        mem.phone = info.phone or "N/A"
                                    end
                                end
                                processed = processed + 1
                                if processed == pCount then SendPayload(gangData, memberList, myRankName, isBossPlayer, cb) end
                            end)
                        elseif Config.Framework == "esx" then
                            MySQL.query('SELECT firstname, lastname, phone_number FROM users WHERE identifier = ?', {mem.citizenid}, function(pRes)
                                if pRes and pRes[1] then
                                    if pRes[1].firstname and pRes[1].lastname then
                                        mem.name = pRes[1].firstname .. " " .. pRes[1].lastname
                                    end
                                    if pRes[1].phone_number then
                                        mem.phone = pRes[1].phone_number
                                    end
                                end
                                processed = processed + 1
                                if processed == pCount then SendPayload(gangData, memberList, myRankName, isBossPlayer, cb) end
                            end)
                        end
                    end
                else
                    SendPayload(gangData, memberList, myRankName, isBossPlayer, cb)
                end
            end)
        end)
    end

    if Config.Framework == "qbcore" then
        Bridge.Core.Functions.CreateCallback('JGR_IlegalSystem:server:GetGangMenuData', function(source, cb, gangName)
            getGangMenuData(source, gangName, cb)
        end)
    elseif Config.Framework == "esx" then
        Bridge.Core.RegisterServerCallback('JGR_IlegalSystem:server:GetGangMenuData', function(source, cb, gangName)
            getGangMenuData(source, gangName, cb)
        end)
    end

    local function memberHasPermission(rankName, ranks, key)
        if not rankName or type(ranks) ~= "table" then return false end
        local r = ranks[rankName]
        if r == nil then
            return isRankBoss(rankName, {})
        end
        if isRankBoss(rankName, r) then return true end
        if type(r) ~= "table" then return false end
        if r[key] == false then return false end
        return r[key] == true
    end

    --- Coincidir rango del desplegable con la clave en JSON (mayúsculas / espacios).
    local function resolveRankNameKey(requested, ranksData)
        if not requested or type(ranksData) ~= "table" then return nil end
        if ranksData[requested] ~= nil then return requested end
        local rl = string.lower(tostring(requested):match("^%s*(.-)%s*$") or "")
        for k in pairs(ranksData) do
            if string.lower(tostring(k)) == rl then return k end
        end
        return nil
    end

    local function gangStashId(gangName)
        return "jgr_gang_" .. tostring(gangName):gsub("%s+", "_")
    end

    local function ensureOxGangStashRegistered(gangName, px, py, pz)
        if GetResourceState("ox_inventory") ~= "started" then return end
        local id = gangStashId(gangName)
        local label = "Almacén · " .. tostring(gangName)
        local coords = nil
        if px and py then coords = vector3(px + 0.0, py + 0.0, (pz or 0.0) + 0.0) end
        pcall(function()
            exports.ox_inventory:RegisterStash(id, label, 100, 1000000, nil, nil, coords)
        end)
    end

    RegisterNetEvent('JGR_IlegalSystem:server:SaveGangPoint')
    AddEventHandler('JGR_IlegalSystem:server:SaveGangPoint', function(pointType, coords, heading)
        local src = source
        local citizenid = nil
        
        if Config.Framework == "qbcore" then
            local Player = Bridge.Core.Functions.GetPlayer(src)
            if Player then citizenid = Player.PlayerData.citizenid end
        elseif Config.Framework == "esx" then
            local Player = Bridge.Core.GetPlayerFromId(src)
            if Player then citizenid = Player.identifier end
        end
        
        if not citizenid then return end
        if type(pointType) ~= "string" then return end

        local validPointTypes = {
            stash = true, boss = true,
            garage_menu = true, garage_spawn = true, garage_store = true,
            garage = true,
        }
        if not validPointTypes[pointType] then return end

        MySQL.query('SELECT gang_name, rank FROM jgr_gang_members WHERE citizenid = ?', {citizenid}, function(memberRes)
            if not memberRes or #memberRes == 0 then return end

            local gangName = memberRes[1].gang_name
            local rankName = memberRes[1].rank

            MySQL.query('SELECT stats, ranks FROM jgr_gangs WHERE name = ?', {gangName}, function(gangRes)
               if not gangRes or not gangRes[1] then return end
               local ranks = {}
               local okR, rdec = pcall(json.decode, gangRes[1].ranks or "{}")
               if okR and type(rdec) == "table" then ranks = rdec end
               if not memberHasPermission(rankName, ranks, "manage_points") then
                   Bridge.Notify(src, Locales[Config.Locale]['no_permission'] or "Sin permiso.", "error")
                   return
               end

               local statsRaw = gangRes[1].stats
               local stats = {}
               if statsRaw and statsRaw ~= "" then
                   local okSt, dec = pcall(json.decode, statsRaw)
                   if okSt and type(dec) == "table" then stats = dec end
               end
               if not stats.points then stats.points = {} end
               stats.points[pointType] = { x = coords.x, y = coords.y, z = coords.z, h = heading }
               MySQL.update('UPDATE jgr_gangs SET stats = ? WHERE name = ?', {json.encode(stats), gangName}, function()
                   if pointType == "stash" then
                       ensureOxGangStashRegistered(gangName, coords.x, coords.y, coords.z)
                   end
                   TriggerClientEvent('JGR_IlegalSystem:client:RefreshGangPoints', src)
               end)
            end)
        end)
    end)

    RegisterNetEvent('JGR_IlegalSystem:server:RequestOpenGangStash', function()
        local src = source
        if Config.GangInventory ~= "ox_inventory" then return end
        if GetResourceState("ox_inventory") ~= "started" then
            Bridge.Notify(src, "ox_inventory no está iniciado.", "error")
            return
        end
        local citizenid = nil
        if Config.Framework == "qbcore" then
            local Player = Bridge.Core.Functions.GetPlayer(src)
            if Player then citizenid = Player.PlayerData.citizenid end
        elseif Config.Framework == "esx" then
            local Player = Bridge.Core.GetPlayerFromId(src)
            if Player then citizenid = Player.identifier end
        end
        if not citizenid then return end
        MySQL.query('SELECT gang_name FROM jgr_gang_members WHERE citizenid = ?', {citizenid}, function(mr)
            if not mr or #mr == 0 then return end
            local gangName = mr[1].gang_name
            MySQL.query('SELECT stats FROM jgr_gangs WHERE name = ?', {gangName}, function(gr)
                if not gr or #gr == 0 then return end
                local stats = {}
                if gr[1].stats and gr[1].stats ~= "" then
                    local okS, d = pcall(json.decode, gr[1].stats)
                    if okS and type(d) == "table" then stats = d end
                end
                local stash = stats.points and stats.points.stash
                if not stash or stash.x == nil then
                    Bridge.Notify(src, "La banda no tiene almacén colocado.", "error")
                    return
                end
                local ped = GetPlayerPed(src)
                if not ped or ped == 0 then return end
                local pc = GetEntityCoords(ped)
                if #(pc - vector3(stash.x + 0.0, stash.y + 0.0, stash.z + 0.0)) > 3.2 then
                    Bridge.Notify(src, "Demasiado lejos del almacén.", "error")
                    return
                end
                ensureOxGangStashRegistered(gangName, stash.x, stash.y, stash.z)
                TriggerClientEvent('JGR_IlegalSystem:client:OpenOxGangStash', src, gangName)
            end)
        end)
    end)

    lib.callback.register('JGR_IlegalSystem:server:GetGangGarageVehicles', function(source)
        local src = source
        local citizenid = nil
        if Config.Framework == "qbcore" then
            local Player = Bridge.Core.Functions.GetPlayer(src)
            if Player then citizenid = Player.PlayerData.citizenid end
        elseif Config.Framework == "esx" then
            local Player = Bridge.Core.GetPlayerFromId(src)
            if Player then citizenid = Player.identifier end
        end
        if not citizenid then return {} end
        local rows = MySQL.query.await('SELECT stats FROM jgr_gangs g INNER JOIN jgr_gang_members m ON m.gang_name = g.name WHERE m.citizenid = ?', {citizenid})
        local row = rows and rows[1]
        if not row or not row.stats or row.stats == "" then return {} end
        local okS, stats = pcall(json.decode, row.stats)
        if not okS or type(stats) ~= "table" then return {} end
        local gg = stats.gang_garage
        if type(gg) ~= "table" or type(gg.vehicles) ~= "table" then return {} end
        return gg.vehicles
    end)

    RegisterNetEvent('JGR_IlegalSystem:server:SaveGangGarageVehicle', function(props)
        local src = source
        if type(props) ~= "table" or not props.model then return end
        local citizenid = nil
        if Config.Framework == "qbcore" then
            local Player = Bridge.Core.Functions.GetPlayer(src)
            if Player then citizenid = Player.PlayerData.citizenid end
        elseif Config.Framework == "esx" then
            local Player = Bridge.Core.GetPlayerFromId(src)
            if Player then citizenid = Player.identifier end
        end
        if not citizenid then return end
        local maxV = tonumber(Config.GangGarageMaxVehicles) or 8
        MySQL.query('SELECT gang_name, rank FROM jgr_gang_members WHERE citizenid = ?', {citizenid}, function(mr)
            if not mr or #mr == 0 then return end
            local gangName = mr[1].gang_name
            local rankName = mr[1].rank
            MySQL.query('SELECT stats, ranks FROM jgr_gangs WHERE name = ?', {gangName}, function(gr)
                if not gr or #gr == 0 then return end
                local ranks = {}
                local okR, rdec = pcall(json.decode, gr[1].ranks or "{}")
                if okR and type(rdec) == "table" then ranks = rdec end
                if not memberHasPermission(rankName, ranks, "manage_points") then
                    Bridge.Notify(src, Locales[Config.Locale]['no_permission'] or "Sin permiso.", "error")
                    return
                end
                local stats = {}
                if gr[1].stats and gr[1].stats ~= "" then
                    local okS, d = pcall(json.decode, gr[1].stats)
                    if okS and type(d) == "table" then stats = d end
                end
                local store = stats.points and stats.points.garage_store
                if not store or store.x == nil then
                    Bridge.Notify(src, "Falta colocar el punto de guardado de vehículos.", "error")
                    return
                end
                local ped = GetPlayerPed(src)
                if not ped or ped == 0 then return end
                local pc = GetEntityCoords(ped)
                if #(pc - vector3(store.x + 0.0, store.y + 0.0, store.z + 0.0)) > 6.0 then
                    Bridge.Notify(src, "Acércate al punto de guardado del garaje.", "error")
                    return
                end
                if not stats.gang_garage then stats.gang_garage = { vehicles = {} } end
                if type(stats.gang_garage.vehicles) ~= "table" then stats.gang_garage.vehicles = {} end
                if #stats.gang_garage.vehicles >= maxV then
                    Bridge.Notify(src, "Garaje lleno.", "error")
                    return
                end
                props.stored_at = os.date("%d/%m/%Y %H:%M")
                table.insert(stats.gang_garage.vehicles, props)
                MySQL.update('UPDATE jgr_gangs SET stats = ? WHERE name = ?', {json.encode(stats), gangName}, function()
                    Bridge.Notify(src, "Vehículo guardado en el garaje de la banda.", "success")
                    TriggerClientEvent('JGR_IlegalSystem:client:DeleteGarageVehicleEntity', src)
                    TriggerClientEvent('JGR_IlegalSystem:client:RefreshGangPoints', src)
                end)
            end)
        end)
    end)

    RegisterNetEvent('JGR_IlegalSystem:server:SpawnGangGarageVehicle', function(index)
        local src = source
        local idx = tonumber(index)
        if not idx or idx < 1 then return end
        local citizenid = nil
        if Config.Framework == "qbcore" then
            local Player = Bridge.Core.Functions.GetPlayer(src)
            if Player then citizenid = Player.PlayerData.citizenid end
        elseif Config.Framework == "esx" then
            local Player = Bridge.Core.GetPlayerFromId(src)
            if Player then citizenid = Player.identifier end
        end
        if not citizenid then return end
        MySQL.query('SELECT gang_name FROM jgr_gang_members WHERE citizenid = ?', {citizenid}, function(mr)
            if not mr or #mr == 0 then return end
            local gangName = mr[1].gang_name
            MySQL.query('SELECT stats FROM jgr_gangs WHERE name = ?', {gangName}, function(gr)
                if not gr or #gr == 0 then return end
                local stats = {}
                if gr[1].stats and gr[1].stats ~= "" then
                    local okS, d = pcall(json.decode, gr[1].stats)
                    if okS and type(d) == "table" then stats = d end
                end
                local menu = stats.points and stats.points.garage_menu
                if not menu or menu.x == nil then
                    menu = stats.points and stats.points.garage
                end
                local spawn = stats.points and stats.points.garage_spawn
                if not menu or menu.x == nil or not spawn or spawn.x == nil then
                    Bridge.Notify(src, "Faltan puntos de garaje (menú o aparición).", "error")
                    return
                end
                local ped = GetPlayerPed(src)
                if not ped or ped == 0 then return end
                local pc = GetEntityCoords(ped)
                if #(pc - vector3(menu.x + 0.0, menu.y + 0.0, menu.z + 0.0)) > 3.5 then
                    Bridge.Notify(src, "Debes estar en el punto de menú del garaje.", "error")
                    return
                end
                local gg = stats.gang_garage
                if type(gg) ~= "table" or type(gg.vehicles) ~= "table" or not gg.vehicles[idx] then
                    Bridge.Notify(src, "Vehículo no encontrado.", "error")
                    return
                end
                local props = gg.vehicles[idx]
                table.remove(gg.vehicles, idx)
                MySQL.update('UPDATE jgr_gangs SET stats = ? WHERE name = ?', {json.encode(stats), gangName}, function()
                    TriggerClientEvent('JGR_IlegalSystem:client:SpawnGangGarageVehicle', src, props, spawn)
                    Bridge.Notify(src, "Saliendo vehículo del garaje…", "success")
                end)
            end)
        end)
    end)

    RegisterNetEvent('JGR_IlegalSystem:server:InviteMember')
    AddEventHandler('JGR_IlegalSystem:server:InviteMember', function(targetId, rankName)
        local admin = source
        local citizenid = nil
        local targetCitizenId = nil

        targetId = tonumber(targetId) or targetId
        if type(rankName) == "string" then
            rankName = rankName:match("^%s*(.-)%s*$")
        end
        if not rankName or rankName == "" then
            Bridge.Notify(admin, "Rango no válido.", "error")
            return
        end

        if Config.Framework == "qbcore" then
            local Player = Bridge.Core.Functions.GetPlayer(admin)
            local Target = Bridge.Core.Functions.GetPlayer(tonumber(targetId) or targetId)
            if Player then citizenid = Player.PlayerData.citizenid end
            if Target then targetCitizenId = Target.PlayerData.citizenid end
        elseif Config.Framework == "esx" then
            local Player = Bridge.Core.GetPlayerFromId(admin)
            local Target = Bridge.Core.GetPlayerFromId(tonumber(targetId) or targetId)
            if Player then citizenid = Player.identifier end
            if Target then targetCitizenId = Target.identifier end
        end

        if not citizenid then return end
        if not targetCitizenId then 
            Bridge.Notify(admin, Locales[Config.Locale]['player_not_found'], "error")
            return 
        end

        -- Check inviter's gang and permissions
        MySQL.query('SELECT gang_name, rank FROM jgr_gang_members WHERE citizenid = ?', {citizenid}, function(memberRes)
            if not memberRes or #memberRes == 0 then return end
            
            local gangName = memberRes[1].gang_name
            local myRank = memberRes[1].rank
            
            -- Verify Gang Exists & Fetch Ranks
            MySQL.query('SELECT name, ranks FROM jgr_gangs WHERE name = ?', {gangName}, function(result)
                if result and #result > 0 then
                    local ranksData = {}
                    local okRd, rd = pcall(json.decode, result[1].ranks or "{}")
                    if okRd and type(rd) == "table" then ranksData = rd end

                    if not memberHasPermission(myRank, ranksData, "manage_members") then
                        Bridge.Notify(admin, Locales[Config.Locale]['no_permission'] or "Sin permiso.", "error")
                        return
                    end

                    local resolvedRank = resolveRankNameKey(rankName, ranksData)
                    if not resolvedRank then
                        Bridge.Notify(admin, Locales[Config.Locale]['rank_not_found'] and string.format(Locales[Config.Locale]['rank_not_found'], rankName, gangName) or "El rango especificado no existe", "error")
                        return
                    end
                    rankName = resolvedRank

                    -- Add to members table
                    MySQL.query('SELECT id FROM jgr_gang_members WHERE citizenid = ? AND gang_name = ?', {targetCitizenId, gangName}, function(targetRes)
                        if targetRes and #targetRes > 0 then
                            -- Already in gang, update rank
                            MySQL.update('UPDATE jgr_gang_members SET rank = ? WHERE citizenid = ? AND gang_name = ?', {rankName, targetCitizenId, gangName}, function(affected)
                                Bridge.Notify(admin, Locales[Config.Locale]['gang_member_updated'] and string.format(Locales[Config.Locale]['gang_member_updated'], GetPlayerName(targetId), gangName, rankName) or "Miembro actualizado", "success")
                                Bridge.Notify(targetId, Locales[Config.Locale]['you_are_now_in_gang'] and string.format(Locales[Config.Locale]['you_are_now_in_gang'], gangName, rankName) or "Ahora estás en la banda", "success")
                                TriggerClientEvent('JGR_IlegalSystem:client:RefreshNPCs', targetId)
                                TriggerClientEvent('JGR_IlegalSystem:client:RequestGangMenuResync', admin)
                            end)
                        else
                            -- Insert New Member
                            MySQL.insert('INSERT INTO jgr_gang_members (gang_name, citizenid, rank) VALUES (?, ?, ?)', {gangName, targetCitizenId, rankName}, function(id)
                                Bridge.Notify(admin, Locales[Config.Locale]['gang_member_added'] and string.format(Locales[Config.Locale]['gang_member_added'], GetPlayerName(targetId), gangName, rankName) or "Miembro reclutado", "success")
                                Bridge.Notify(targetId, Locales[Config.Locale]['you_are_now_in_gang'] and string.format(Locales[Config.Locale]['you_are_now_in_gang'], gangName, rankName) or "Has sido reclutado", "success")
                                TriggerClientEvent('JGR_IlegalSystem:client:RefreshNPCs', targetId)
                                TriggerClientEvent('JGR_IlegalSystem:client:RequestGangMenuResync', admin)
                            end)
                        end
                    end)
                end
            end)
        end)
    end)

    -- =============================================
    -- DOCUMENT MANAGEMENT
    -- =============================================
    local function getPlayerGang(source, cb)
        local citizenid = nil
        if Config.Framework == "qbcore" then
            local Player = Bridge.Core.Functions.GetPlayer(source)
            if Player then citizenid = Player.PlayerData.citizenid end
        elseif Config.Framework == "esx" then
            local Player = Bridge.Core.GetPlayerFromId(source)
            if Player then citizenid = Player.identifier end
        end
        if not citizenid then return cb(nil) end

        MySQL.query('SELECT gang_name FROM jgr_gang_members WHERE citizenid = ?', {citizenid}, function(res)
            if res and #res > 0 then
                cb(res[1].gang_name)
            else
                cb(nil)
            end
        end)
    end

    local function assertDocOrTerrPerm(src, gangName, permKey, cb)
        local citizenid = nil
        if Config.Framework == "qbcore" then
            local Player = Bridge.Core.Functions.GetPlayer(src)
            if Player then citizenid = Player.PlayerData.citizenid end
        elseif Config.Framework == "esx" then
            local Player = Bridge.Core.GetPlayerFromId(src)
            if Player then citizenid = Player.identifier end
        end
        if not citizenid then return end
        MySQL.query('SELECT rank FROM jgr_gang_members WHERE citizenid = ? AND gang_name = ?', {citizenid, gangName}, function(mr)
            if not mr or #mr == 0 then return end
            local rankName = mr[1].rank
            MySQL.query('SELECT ranks FROM jgr_gangs WHERE name = ?', {gangName}, function(gr)
                if not gr or #gr == 0 then return end
                local ranks = {}
                local okDec, rdec = pcall(json.decode, gr[1].ranks or "{}")
                if okDec and type(rdec) == "table" then ranks = rdec end
                if not memberHasPermission(rankName, ranks, permKey) then
                    Bridge.Notify(src, Locales[Config.Locale]['no_permission'] or "Sin permiso.", "error")
                    return
                end
                cb()
            end)
        end)
    end

    RegisterNetEvent('JGR_IlegalSystem:server:SaveDocument')
    AddEventHandler('JGR_IlegalSystem:server:SaveDocument', function(docId, title, content)
        local src = source
        getPlayerGang(src, function(gangName)
            if not gangName then return end
            assertDocOrTerrPerm(src, gangName, "manage_docs", function()
            MySQL.query('SELECT stats FROM jgr_gangs WHERE name = ?', {gangName}, function(gangRes)
                if not gangRes or #gangRes == 0 then return end
                local stats = gangRes[1].stats
                if not stats or stats == "" then stats = {} else stats = json.decode(stats) end
                if not stats.documents then stats.documents = {} end

                if docId then
                    -- Update existing
                    for _, doc in ipairs(stats.documents) do
                        if doc.id == docId then
                            doc.title = title
                            doc.content = content
                            doc.date = os.date("%d/%m/%Y %H:%M")
                            break
                        end
                    end
                else
                    -- Create new
                    table.insert(stats.documents, {
                        id = tostring(os.time()) .. tostring(math.random(1000,9999)),
                        title = title,
                        content = content,
                        date = os.date("%d/%m/%Y %H:%M")
                    })
                end
                MySQL.update('UPDATE jgr_gangs SET stats = ? WHERE name = ?', {json.encode(stats), gangName}, function()
                    TriggerClientEvent('JGR_IlegalSystem:client:UpdateDocuments', src, stats.documents)
                end)
            end)
            end)
        end)
    end)

    RegisterNetEvent('JGR_IlegalSystem:server:DeleteDocument')
    AddEventHandler('JGR_IlegalSystem:server:DeleteDocument', function(docId)
        local src = source
        getPlayerGang(src, function(gangName)
            if not gangName then return end
            assertDocOrTerrPerm(src, gangName, "manage_docs", function()
            MySQL.query('SELECT stats FROM jgr_gangs WHERE name = ?', {gangName}, function(gangRes)
                if not gangRes or #gangRes == 0 then return end
                local stats = gangRes[1].stats
                if not stats or stats == "" then stats = {} else stats = json.decode(stats) end
                if not stats.documents then return end

                for i, doc in ipairs(stats.documents) do
                    if doc.id == docId then
                        table.remove(stats.documents, i)
                        break
                    end
                end
                MySQL.update('UPDATE jgr_gangs SET stats = ? WHERE name = ?', {json.encode(stats), gangName}, function()
                    TriggerClientEvent('JGR_IlegalSystem:client:UpdateDocuments', src, stats.documents)
                end)
            end)
            end)
        end)
    end)

    -- =============================================
    -- TERRITORIES (persisted in stats.territories, same pattern as documents)
    -- =============================================
    RegisterNetEvent('JGR_IlegalSystem:server:SaveTerritory')
    AddEventHandler('JGR_IlegalSystem:server:SaveTerritory', function(terrId, title, content, influence, coords)
        local src = source
        getPlayerGang(src, function(gangName)
            if not gangName then return end
            assertDocOrTerrPerm(src, gangName, "manage_territories", function()
            MySQL.query('SELECT stats FROM jgr_gangs WHERE name = ?', {gangName}, function(gangRes)
                if not gangRes or #gangRes == 0 then return end
                local stats = gangRes[1].stats
                if not stats or stats == "" then stats = {} else stats = json.decode(stats) end
                if not stats.territories then stats.territories = {} end

                local inf = tonumber(influence) or 0
                if inf < 0 then inf = 0 end
                if inf > 100 then inf = 100 end

                local wx, wy, wz = nil, nil, nil
                if coords and coords.x then
                    wx, wy, wz = coords.x, coords.y, coords.z
                end

                if terrId and tostring(terrId) ~= "" then
                    for _, t in ipairs(stats.territories) do
                        if t.id == terrId then
                            t.title = title
                            t.content = content or ""
                            t.influence = inf
                            t.date = os.date("%d/%m/%Y %H:%M")
                            if wx then t.wx, t.wy, t.wz = wx, wy, wz end
                            break
                        end
                    end
                else
                    table.insert(stats.territories, {
                        id = tostring(os.time()) .. tostring(math.random(1000, 9999)),
                        title = title,
                        content = content or "",
                        influence = inf,
                        wx = wx, wy = wy, wz = wz,
                        date = os.date("%d/%m/%Y %H:%M")
                    })
                end

                MySQL.update('UPDATE jgr_gangs SET stats = ? WHERE name = ?', {json.encode(stats), gangName}, function()
                    TriggerClientEvent('JGR_IlegalSystem:client:UpdateTerritories', src, stats.territories, #stats.territories)
                end)
            end)
            end)
        end)
    end)

    RegisterNetEvent('JGR_IlegalSystem:server:SaveControlZone')
    AddEventHandler('JGR_IlegalSystem:server:SaveControlZone', function(wx, wy, wz, radius)
        local src = source
        if type(wx) ~= "number" or type(wy) ~= "number" then return end
        local rad = tonumber(radius) or 100.0
        if rad < 10.0 then rad = 10.0 end
        if rad > 500.0 then rad = 500.0 end
        getPlayerGang(src, function(gangName)
            if not gangName then return end
            assertDocOrTerrPerm(src, gangName, "manage_territories", function()
                MySQL.query('SELECT stats FROM jgr_gangs WHERE name = ?', {gangName}, function(gangRes)
                    if not gangRes or #gangRes == 0 then return end
                    local statsRaw = gangRes[1].stats
                    local stats = {}
                    if statsRaw and statsRaw ~= "" then
                        local okSt, dec = pcall(json.decode, statsRaw)
                        if okSt and type(dec) == "table" then stats = dec end
                    end
                    stats.control_zone = {
                        x = wx,
                        y = wy,
                        z = type(wz) == "number" and wz or 0.0,
                        radius = rad,
                        updated = os.date("%d/%m/%Y %H:%M")
                    }
                    MySQL.update('UPDATE jgr_gangs SET stats = ? WHERE name = ?', {json.encode(stats), gangName}, function()
                        Bridge.Notify(src, "Zona de control actualizada.", "success")
                        TriggerClientEvent('JGR_IlegalSystem:client:UpdateControlZone', src, stats.control_zone)
                    end)
                end)
            end)
        end)
    end)

    RegisterNetEvent('JGR_IlegalSystem:server:DeleteTerritory')
    AddEventHandler('JGR_IlegalSystem:server:DeleteTerritory', function(terrId)
        local src = source
        getPlayerGang(src, function(gangName)
            if not gangName then return end
            assertDocOrTerrPerm(src, gangName, "manage_territories", function()
            MySQL.query('SELECT stats FROM jgr_gangs WHERE name = ?', {gangName}, function(gangRes)
                if not gangRes or #gangRes == 0 then return end
                local stats = gangRes[1].stats
                if not stats or stats == "" then stats = {} else stats = json.decode(stats) end
                if not stats.territories then return end
                for i, t in ipairs(stats.territories) do
                    if t.id == terrId then
                        table.remove(stats.territories, i)
                        break
                    end
                end
                MySQL.update('UPDATE jgr_gangs SET stats = ? WHERE name = ?', {json.encode(stats), gangName}, function()
                    TriggerClientEvent('JGR_IlegalSystem:client:UpdateTerritories', src, stats.territories, #stats.territories)
                end)
            end)
            end)
        end)
    end)

    RegisterNetEvent('JGR_IlegalSystem:server:KickMember')
    AddEventHandler('JGR_IlegalSystem:server:KickMember', function(targetCitizenId)
        local src = source
        if type(targetCitizenId) ~= "string" then return end
        local adminCid = nil
        if Config.Framework == "qbcore" then
            local Player = Bridge.Core.Functions.GetPlayer(src)
            if Player then adminCid = Player.PlayerData.citizenid end
        elseif Config.Framework == "esx" then
            local Player = Bridge.Core.GetPlayerFromId(src)
            if Player then adminCid = Player.identifier end
        end
        if not adminCid or adminCid == targetCitizenId then return end

        MySQL.query('SELECT gang_name, rank FROM jgr_gang_members WHERE citizenid = ?', {adminCid}, function(adminMem)
            if not adminMem or #adminMem == 0 then return end
            local gangName = adminMem[1].gang_name
            local adminRank = adminMem[1].rank
            MySQL.query('SELECT ranks FROM jgr_gangs WHERE name = ?', {gangName}, function(gr)
                if not gr or #gr == 0 then return end
                local ranks = {}
                local okR, rdec = pcall(json.decode, gr[1].ranks or "{}")
                if okR and type(rdec) == "table" then ranks = rdec end
                if not memberHasPermission(adminRank, ranks, "manage_members") then
                    Bridge.Notify(src, Locales[Config.Locale]['no_permission'] or "Sin permiso.", "error")
                    return
                end
                MySQL.query('SELECT rank FROM jgr_gang_members WHERE citizenid = ? AND gang_name = ?', {targetCitizenId, gangName}, function(tm)
                    if not tm or #tm == 0 then
                        Bridge.Notify(src, Locales[Config.Locale]['player_not_found'] or "Miembro no encontrado.", "error")
                        return
                    end
                    local tRank = tm[1].rank
                    local trd = ranks[tRank]
                    if isRankBoss(tRank, type(trd) == "table" and trd or {}) then
                        Bridge.Notify(src, "No puedes expulsar al jefe.", "error")
                        return
                    end
                    MySQL.update('DELETE FROM jgr_gang_members WHERE citizenid = ? AND gang_name = ?', {targetCitizenId, gangName}, function()
                        Bridge.Notify(src, "Miembro expulsado.", "success")
                        TriggerClientEvent('JGR_IlegalSystem:client:RequestGangMenuResync', src)
                        for _, pid in ipairs(GetPlayers()) do
                            local tid = tonumber(pid)
                            if tid then
                                local tcid = nil
                                if Config.Framework == "qbcore" then
                                    local tPlayer = Bridge.Core.Functions.GetPlayer(tid)
                                    if tPlayer then tcid = tPlayer.PlayerData.citizenid end
                                elseif Config.Framework == "esx" then
                                    local tPlayer = Bridge.Core.GetPlayerFromId(tid)
                                    if tPlayer then tcid = tPlayer.identifier end
                                end
                                if tcid == targetCitizenId then
                                    TriggerClientEvent('JGR_IlegalSystem:client:RefreshNPCs', tid)
                                    Bridge.Notify(tid, "Has sido expulsado de la banda.", "error")
                                    break
                                end
                            end
                        end
                    end)
                end)
            end)
        end)
    end)

    -- =============================================
    -- RANK MANAGEMENT
    -- =============================================
    RegisterNetEvent('JGR_IlegalSystem:server:CreateRank')
    AddEventHandler('JGR_IlegalSystem:server:CreateRank', function(rankName)
        local src = source
        getPlayerGang(src, function(gangName)
            if not gangName then return end
            assertDocOrTerrPerm(src, gangName, "manage_ranks", function()
            MySQL.query('SELECT ranks FROM jgr_gangs WHERE name = ?', {gangName}, function(gangRes)
                if not gangRes or #gangRes == 0 then return end
                local ranks = {}
                local okDec, rdec = pcall(json.decode, gangRes[1].ranks or "{}")
                if okDec and type(rdec) == "table" then ranks = rdec end
                if ranks[rankName] then
                    Bridge.Notify(src, "El rango '" .. rankName .. "' ya existe.", "error")
                    return
                end
                ranks[rankName] = {}
                MySQL.update('UPDATE jgr_gangs SET ranks = ? WHERE name = ?', {json.encode(ranks), gangName}, function()
                    Bridge.Notify(src, "Rango '" .. rankName .. "' creado correctamente.", "success")
                    TriggerClientEvent('JGR_IlegalSystem:client:UpdateRanks', src, ranks)
                    TriggerClientEvent('JGR_IlegalSystem:client:RequestGangMenuResync', src)
                end)
            end)
            end)
        end)
    end)

    RegisterNetEvent('JGR_IlegalSystem:server:DeleteRank')
    AddEventHandler('JGR_IlegalSystem:server:DeleteRank', function(rankName)
        local src = source
        getPlayerGang(src, function(gangName)
            if not gangName then return end
            assertDocOrTerrPerm(src, gangName, "manage_ranks", function()
            MySQL.query('SELECT ranks FROM jgr_gangs WHERE name = ?', {gangName}, function(gangRes)
                if not gangRes or #gangRes == 0 then return end
                local ranks = {}
                local okDec, rdec = pcall(json.decode, gangRes[1].ranks or "{}")
                if okDec and type(rdec) == "table" then ranks = rdec end
                if not ranks[rankName] then
                    Bridge.Notify(src, "El rango '" .. rankName .. "' no existe.", "error")
                    return
                end
                if isRankBoss(rankName, ranks[rankName]) then
                    Bridge.Notify(src, "No puedes eliminar el rango de Jefe.", "error")
                    return
                end
                ranks[rankName] = nil
                MySQL.update('UPDATE jgr_gangs SET ranks = ? WHERE name = ?', {json.encode(ranks), gangName}, function()
                    Bridge.Notify(src, "Rango '" .. rankName .. "' eliminado.", "success")
                    TriggerClientEvent('JGR_IlegalSystem:client:UpdateRanks', src, ranks)
                    TriggerClientEvent('JGR_IlegalSystem:client:RequestGangMenuResync', src)
                end)
            end)
            end)
        end)
    end)

    RegisterNetEvent('JGR_IlegalSystem:server:UpdateRankPermissions')
    AddEventHandler('JGR_IlegalSystem:server:UpdateRankPermissions', function(rankName, permissions)
        local src = source
        getPlayerGang(src, function(gangName)
            if not gangName then return end
            assertDocOrTerrPerm(src, gangName, "manage_ranks", function()
            MySQL.query('SELECT ranks FROM jgr_gangs WHERE name = ?', {gangName}, function(gangRes)
                if not gangRes or #gangRes == 0 then return end
                local ranks = {}
                local okDec, rdec = pcall(json.decode, gangRes[1].ranks or "{}")
                if okDec and type(rdec) == "table" then ranks = rdec end
                if not ranks[rankName] then return end
                if isRankBoss(rankName, ranks[rankName]) then
                    Bridge.Notify(src, "No puedes cambiar permisos del rango de jefe desde aquí.", "error")
                    return
                end

                -- Update permissions
                ranks[rankName].manage_members = permissions.manage_members
                ranks[rankName].manage_points = permissions.manage_points
                ranks[rankName].manage_ranks = permissions.manage_ranks
                ranks[rankName].manage_docs = permissions.manage_docs
                ranks[rankName].manage_territories = permissions.manage_territories
                
                MySQL.update('UPDATE jgr_gangs SET ranks = ? WHERE name = ?', {json.encode(ranks), gangName}, function()
                    Bridge.Notify(src, "Permisos de '" .. rankName .. "' actualizados.", "success")
                    TriggerClientEvent('JGR_IlegalSystem:client:UpdateRanks', src, ranks)
                    TriggerClientEvent('JGR_IlegalSystem:client:RequestGangMenuResync', src)
                end)
            end)
            end)
        end)
    end)
end)
