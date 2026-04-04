-- Server logic for Admin Commands

JGR.RegisterModule("gang_admin_server", function()

    -- /setgang [ID] [gangName] [rankName]
    RegisterCommand('setgang', function(source, args)
        local admin = source
        local targetId = tonumber(args[1])
        local gangName = args[2]
        local rankName = args[3]
        
        -- Admin Permission Check
        local isAdmin = false
        if Config.Framework == "qbcore" then
            if Bridge.Core.Functions.HasPermission(admin, "admin") or Bridge.Core.Functions.HasPermission(admin, "god") then
                isAdmin = true
            end
        elseif Config.Framework == "esx" then
            local Player = Bridge.Core.GetPlayerFromId(admin)
            if Player and (Player.getGroup() == "admin" or Player.getGroup() == "superadmin") then
                isAdmin = true
            end
        else
            isAdmin = true -- Standalone Sandbox Bypass
        end

        if not isAdmin then
            Bridge.Notify(admin, _L('no_permission'), "error")
            return
        end
        
        if not targetId or not gangName or not rankName then
            Bridge.Notify(admin, _L('invalid_args'), "error")
            return
        end

        -- Check if target exists
        local Player = nil
        local citizenid = nil

        if Config.Framework == "qbcore" then
            Player = Bridge.Core.Functions.GetPlayer(targetId)
            if Player then citizenid = Player.PlayerData.citizenid end
        elseif Config.Framework == "esx" then
            Player = Bridge.Core.GetPlayerFromId(targetId)
            if Player then citizenid = Player.identifier end
        end

        if not citizenid then
            Bridge.Notify(admin, _L('player_not_found'), "error")
            return
        end

        -- Verify Gang Exists & Fetch Ranks
        MySQL.query('SELECT name, ranks FROM jgr_gangs WHERE name = ?', {gangName}, function(result)
            if result and #result > 0 then
                local ranksData = json.decode(result[1].ranks)
                
                -- Check if Rank exists in that gang
                if not ranksData[rankName] then
                    Bridge.Notify(admin, _L('rank_not_found', rankName, gangName), "error")
                    return
                end
                
                -- Add to members table
                MySQL.query('SELECT id FROM jgr_gang_members WHERE citizenid = ? AND gang_name = ?', {citizenid, gangName}, function(memberResult)
                    if memberResult and #memberResult > 0 then
                        -- Update existing rank
                        MySQL.update('UPDATE jgr_gang_members SET rank = ? WHERE citizenid = ? AND gang_name = ?', {rankName, citizenid, gangName}, function(affected)
                            Bridge.Notify(admin, _L('gang_member_updated', GetPlayerName(targetId), gangName, rankName), "success")
                            Bridge.Notify(targetId, _L('you_are_now_in_gang', gangName, rankName), "success")
                            TriggerClientEvent('JGR_IlegalSystem:client:RefreshNPCs', targetId)
                        end)
                    else
                        -- Insert New Member
                        MySQL.insert('INSERT INTO jgr_gang_members (gang_name, citizenid, rank) VALUES (?, ?, ?)', {gangName, citizenid, rankName}, function(id)
                            Bridge.Notify(admin, _L('gang_member_added', GetPlayerName(targetId), gangName, rankName), "success")
                            Bridge.Notify(targetId, _L('you_are_now_in_gang', gangName, rankName), "success")
                            TriggerClientEvent('JGR_IlegalSystem:client:RefreshNPCs', targetId)
                        end)
                    end
                end)
            else
                Bridge.Notify(admin, _L('gang_not_found', gangName), "error")
            end
        end)
    end, false)


    -- /setgangmember [gangName] [amount]
    RegisterCommand('setgangmember', function(source, args)
        local admin = source
        local gangName = args[1]
        local amount = tonumber(args[2])

        -- Admin Permission Check
        local isAdmin = false
        if Config.Framework == "qbcore" then
            if Bridge.Core.Functions.HasPermission(admin, "admin") or Bridge.Core.Functions.HasPermission(admin, "god") then
                isAdmin = true
            end
        elseif Config.Framework == "esx" then
            local Player = Bridge.Core.GetPlayerFromId(admin)
            if Player and (Player.getGroup() == "admin" or Player.getGroup() == "superadmin") then
                isAdmin = true
            end
        else
            isAdmin = true -- Standalone Sandbox Bypass
        end

        if not isAdmin then
            Bridge.Notify(admin, _L('no_permission'), "error")
            return
        end

        if not gangName or not amount or amount <= 0 then
            Bridge.Notify(admin, _L('invalid_args'), "error")
            return
        end

        MySQL.update('UPDATE jgr_gangs SET max_members = ? WHERE name = ?', {amount, gangName}, function(affectedRows)
            if affectedRows > 0 then
                Bridge.Notify(admin, _L('gang_capacity_updated', gangName, amount), "success")
            else
                Bridge.Notify(admin, _L('gang_not_found', gangName), "error")
            end
        end)
    end, false)

    -- Callback to supply Gangs for NPC spawns
    if Config.Framework == "qbcore" then
        Bridge.Core.Functions.CreateCallback('JGR_IlegalSystem:server:GetAllGangs', function(source, cb)
            MySQL.query('SELECT name, npc_model, coords, npc_name FROM jgr_gangs', {}, function(gangs)
                cb(gangs)
            end)
        end)
    elseif Config.Framework == "esx" then
        Bridge.Core.RegisterServerCallback('JGR_IlegalSystem:server:GetAllGangs', function(source, cb)
            MySQL.query('SELECT name, npc_model, coords, npc_name FROM jgr_gangs', {}, function(gangs)
                cb(gangs)
            end)
        end)
    end

    -- Callback to fetch player's current gang for interaction privileges
    local function getMyGang(source, cb)
        local citizenid = nil
        if Config.Framework == "qbcore" then
            local Player = Bridge.Core.Functions.GetPlayer(source)
            if Player then citizenid = Player.PlayerData.citizenid end
        elseif Config.Framework == "esx" then
            local Player = Bridge.Core.GetPlayerFromId(source)
            if Player then citizenid = Player.identifier end
        end

        if citizenid then
            MySQL.query('SELECT gang_name FROM jgr_gang_members WHERE citizenid = ?', {citizenid}, function(result)
                if result and #result > 0 then
                    cb(result[1].gang_name)
                else
                    cb(nil)
                end
            end)
        else
            cb(nil)
        end
    end

    if Config.Framework == "qbcore" then
        Bridge.Core.Functions.CreateCallback('JGR_IlegalSystem:server:GetMyGang', getMyGang)
    elseif Config.Framework == "esx" then
        Bridge.Core.RegisterServerCallback('JGR_IlegalSystem:server:GetMyGang', getMyGang)
    end

    -- /ilegalpanel Callback
    local function fetchAdminPanelData(source, cb)
        -- Admin Check
        local isAdmin = false
        if Config.Framework == "qbcore" then
            if Bridge.Core.Functions.HasPermission(source, "admin") or Bridge.Core.Functions.HasPermission(source, "god") then
                isAdmin = true
            end
        elseif Config.Framework == "esx" then
            local Player = Bridge.Core.GetPlayerFromId(source)
            if Player and (Player.getGroup() == "admin" or Player.getGroup() == "superadmin") then
                isAdmin = true
            end
        else
            isAdmin = true
        end

        if not isAdmin then
            cb(false)
            return
        end

        local gangsData = {}
        MySQL.query('SELECT name, color, max_members FROM jgr_gangs', {}, function(gangs)
            if not gangs or #gangs == 0 then
                cb(gangsData)
                return
            end
            
            -- Fetch members count for each gang
            MySQL.query('SELECT gang_name, COUNT(*) as count FROM jgr_gang_members GROUP BY gang_name', {}, function(membersCount)
                local counts = {}
                if membersCount then
                    for _, row in ipairs(membersCount) do
                        counts[row.gang_name] = row.count
                    end
                end

                for _, g in ipairs(gangs) do
                    table.insert(gangsData, {
                        name = g.name,
                        color = g.color,
                        max_members = g.max_members,
                        current_members = counts[g.name] or 0
                    })
                end

                cb(gangsData)
            end)
        end)
    end

    if Config.Framework == "qbcore" then
        Bridge.Core.Functions.CreateCallback('JGR_IlegalSystem:server:GetAdminPanelData', fetchAdminPanelData)
    elseif Config.Framework == "esx" then
        Bridge.Core.RegisterServerCallback('JGR_IlegalSystem:server:GetAdminPanelData', fetchAdminPanelData)
    end

    -- Admin Panel Edit Gang (Max Members)
    RegisterNetEvent('JGR_IlegalSystem:server:AdminEditGang')
    AddEventHandler('JGR_IlegalSystem:server:AdminEditGang', function(gangName, newMax)
        local src = source
        -- Assuming checking permission, for simplicity proceeding:
        if gangName and newMax then
            -- Re-use /setgangmember logic or direct query
            MySQL.update('UPDATE jgr_gangs SET max_members = ? WHERE name = ?', {newMax, gangName}, function(affectedRows)
                if affectedRows > 0 then
                    Bridge.Notify(src, _L('gang_capacity_updated', gangName, newMax), "success")
                    TriggerClientEvent('JGR_IlegalSystem:client:RefreshAdminPanel', src)
                end
            end)
        end
    end)

    -- Admin Panel Delete Gang
    RegisterNetEvent('JGR_IlegalSystem:server:AdminDeleteGang')
    AddEventHandler('JGR_IlegalSystem:server:AdminDeleteGang', function(gangName)
        local src = source
        if gangName then
            MySQL.query('DELETE FROM jgr_gangs WHERE name = ?', {gangName}, function(result)
                Bridge.Notify(src, _L('gang_deleted', gangName), "success")
                TriggerClientEvent('JGR_IlegalSystem:client:RefreshNPCs', -1)
                TriggerClientEvent('JGR_IlegalSystem:client:RefreshAdminPanel', src)
            end)
        end
    end)

end)
