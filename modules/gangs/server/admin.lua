-- Servidor: comandos y panel de administración de bandas

JGR.RegisterModule("gang_admin_server", function()

    local function isRankBossAdm(rankName, r)
        if not rankName then return false end
        if type(r) == "table" and r.isBoss then return true end
        local n = string.lower(tostring(rankName))
        return n == "jefe" or n == "boss"
    end

    local function orderedRankNamesAdm(ranks)
        if type(ranks) ~= "table" then return {} end
        local bossName = nil
        local rest = {}
        for name, data in pairs(ranks) do
            if isRankBossAdm(name, data) then
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

    -- /setgang [ID] [banda] [índiceRango] — 0 = jefe, 1 = siguiente, …
    -- Si el jugador estaba en otra banda, se le mueve a la nueva.
    RegisterCommand('setgang', function(source, args)
        local admin = source
        if not Bridge.IsAdmin(admin) then
            Bridge.Notify(admin, _L('no_permission'), "error")
            return
        end

        local targetId = tonumber(args[1])
        local gangName = args[2]
        local rankIdx = tonumber(args[3])
        if not targetId or not gangName or rankIdx == nil then
            Bridge.Notify(admin, _L('invalid_args'), "error")
            return
        end

        local citizenid = Bridge.GetIdentifier(targetId)
        if not citizenid then
            Bridge.Notify(admin, _L('player_not_found'), "error")
            return
        end

        local result = MySQL.query.await('SELECT name, ranks FROM jgr_gangs WHERE name = ?', { gangName })
        if not result or #result == 0 then
            Bridge.Notify(admin, _L('gang_not_found', gangName), "error")
            return
        end

        local ranksData = Bridge.Util.SafeDecode(result[1].ranks, {})
        local ordered = orderedRankNamesAdm(ranksData)
        local rankName = ordered[math.floor(rankIdx) + 1]
        if not rankName then
            Bridge.Notify(admin, "Índice de rango inválido. Usa 0.." .. tostring(math.max(0, #ordered - 1)) .. " (0 = jefe).", "error")
            return
        end

        -- Un jugador solo puede pertenecer a una banda.
        MySQL.update.await('DELETE FROM jgr_gang_members WHERE citizenid = ? AND gang_name <> ?', { citizenid, gangName })

        local existing = MySQL.scalar.await('SELECT id FROM jgr_gang_members WHERE citizenid = ? AND gang_name = ?', { citizenid, gangName })
        if existing then
            MySQL.update.await('UPDATE jgr_gang_members SET `rank` = ? WHERE citizenid = ? AND gang_name = ?', { rankName, citizenid, gangName })
            Bridge.Notify(admin, _L('gang_member_updated', GetPlayerName(targetId), gangName, rankName), "success")
        else
            MySQL.insert.await('INSERT INTO jgr_gang_members (gang_name, citizenid, `rank`) VALUES (?, ?, ?)', { gangName, citizenid, rankName })
            Bridge.Notify(admin, _L('gang_member_added', GetPlayerName(targetId), gangName, rankName), "success")
        end
        Bridge.Notify(targetId, _L('you_are_now_in_gang', gangName, rankName), "success")
        TriggerClientEvent('JGR_IlegalSystem:client:RefreshNPCs', targetId)
    end, false)

    local function setGangCapacity(admin, gangName, amount)
        amount = Bridge.Util.ToInt(amount, 1, 1000)
        if type(gangName) ~= "string" or not amount then
            Bridge.Notify(admin, _L('invalid_args'), "error")
            return false
        end
        local affectedRows = MySQL.update.await('UPDATE jgr_gangs SET max_members = ? WHERE name = ?', { amount, gangName })
        if (affectedRows or 0) > 0 then
            Bridge.Notify(admin, _L('gang_capacity_updated', gangName, amount), "success")
            return true
        end
        Bridge.Notify(admin, _L('gang_not_found', gangName), "error")
        return false
    end

    -- /setgangmember [banda] [cantidad]
    RegisterCommand('setgangmember', function(source, args)
        if not Bridge.IsAdmin(source) then
            Bridge.Notify(source, _L('no_permission'), "error")
            return
        end
        setGangCapacity(source, args[1], args[2])
    end, false)

    -- Lista pública de bandas para colocar sus NPC (sin datos sensibles).
    lib.callback.register('JGR_IlegalSystem:server:GetAllGangs', function()
        return MySQL.query.await('SELECT name, npc_model, coords, npc_name FROM jgr_gangs', {}) or {}
    end)

    lib.callback.register('JGR_IlegalSystem:server:GetMyGang', function(source)
        local citizenid = Bridge.GetIdentifier(source)
        if not citizenid then return nil end
        local gn = MySQL.scalar.await('SELECT gang_name FROM jgr_gang_members WHERE citizenid = ? LIMIT 1', { citizenid })
        if type(gn) == 'string' then gn = Bridge.Util.Trim(gn) end
        return gn
    end)

    -- /ilegalpanel
    lib.callback.register('JGR_IlegalSystem:server:GetAdminPanelData', function(source)
        if not Bridge.IsAdmin(source) then return false end

        local gangsData = {}
        local gangs = MySQL.query.await('SELECT name, color, max_members FROM jgr_gangs', {})
        if not gangs or #gangs == 0 then return gangsData end

        local counts = {}
        local membersCount = MySQL.query.await('SELECT gang_name, COUNT(*) as count FROM jgr_gang_members GROUP BY gang_name', {})
        for _, row in ipairs(membersCount or {}) do
            counts[row.gang_name] = row.count
        end

        for _, g in ipairs(gangs) do
            gangsData[#gangsData + 1] = {
                name = g.name,
                color = g.color,
                max_members = g.max_members,
                current_members = counts[g.name] or 0
            }
        end
        return gangsData
    end)

    RegisterNetEvent('JGR_IlegalSystem:server:AdminEditGang', function(gangName, newMax)
        local src = source
        if not Bridge.IsAdmin(src) then return end
        if setGangCapacity(src, gangName, newMax) then
            TriggerClientEvent('JGR_IlegalSystem:client:RefreshAdminPanel', src)
        end
    end)

    RegisterNetEvent('JGR_IlegalSystem:server:AdminDeleteGang', function(gangName)
        local src = source
        if not Bridge.IsAdmin(src) then return end
        if type(gangName) ~= "string" or gangName == "" then return end
        local affected = MySQL.update.await('DELETE FROM jgr_gangs WHERE name = ?', { gangName })
        if (affected or 0) > 0 then
            -- Por si la clave foránea no existe en bases de datos antiguas.
            MySQL.update.await('DELETE FROM jgr_gang_members WHERE gang_name = ?', { gangName })
            Bridge.Notify(src, _L('gang_deleted', gangName), "success")
            TriggerClientEvent('JGR_IlegalSystem:client:RefreshNPCs', -1)
        else
            Bridge.Notify(src, _L('gang_not_found', gangName), "error")
        end
        TriggerClientEvent('JGR_IlegalSystem:client:RefreshAdminPanel', src)
    end)
end)
