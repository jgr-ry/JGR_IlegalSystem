JGR.RegisterModule("gang_menu_server", function()
    -- Fetch Gang Data for NUI
    local function getGangMenuData(source, gangName, cb)
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
            gangData.ranks = json.decode(gangData.ranks)
            gangData.coords = json.decode(gangData.coords)
            
            -- Parse new level stats safely
            if gangData.stats and gangData.stats ~= "" then
                gangData.stats = json.decode(gangData.stats) or {}
            else
                gangData.stats = {}
            end

            MySQL.query('SELECT citizenid, rank FROM jgr_gang_members WHERE gang_name = ?', {gangName}, function(members)
                local memberList = {}
                local rawMembers = members or {}
                
                -- Determine player permissions
                local myRankName = nil
                local isBoss = false
                
                local function SendPayload(gData, mList, mRank, mIsBoss, cbFunc)
                    local perms = {
                        rankName = mRank,
                        isBoss = mIsBoss,
                        manage_members = mIsBoss, -- default for boss
                        manage_points = mIsBoss,
                        manage_ranks = mIsBoss,
                        manage_docs = mIsBoss
                    }

                    if mRank and gData.ranks[mRank] then
                        local rData = gData.ranks[mRank]
                        perms.isBoss = rData.isBoss or false
                        if not perms.isBoss then
                            perms.manage_members = rData.manage_members or false
                            perms.manage_points = rData.manage_points or false
                            perms.manage_ranks = rData.manage_ranks or false
                            perms.manage_docs = rData.manage_docs or false
                        else
                            -- Force all true for bosses
                            perms.manage_members = true
                            perms.manage_points = true
                            perms.manage_ranks = true
                            perms.manage_docs = true
                        end
                    end

                    local payload = {
                        gang = {
                            name = gData.name,
                            color = gData.color,
                            level = gData.level or 0,
                            xp = gData.xp or 0,
                            stats = gData.stats,
                            territories = 0,
                            members = mList,
                            documents = gData.stats.documents or {},
                            ranks = gData.ranks
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

                -- Now fill in actual names
                if #memberList > 0 then
                    local pCount = #memberList
                    local processed = 0

                    for i, mem in ipairs(memberList) do
                        if Config.Framework == "qbcore" then
                            MySQL.query('SELECT charinfo FROM players WHERE citizenid = ?', {mem.citizenid}, function(pRes)
                                if pRes and pRes[1] and pRes[1].charinfo then
                                    local info = json.decode(pRes[1].charinfo)
                                    if info then
                                        mem.name = (info.firstname or "") .. " " .. (info.lastname or "")
                                        mem.phone = info.phone or "N/A"
                                    end
                                end
                                processed = processed + 1
                                if processed == pCount then SendPayload(gangData, memberList, myRankName, isBoss, cb) end
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
                                if processed == pCount then SendPayload(gangData, memberList, myRankName, isBoss, cb) end
                            end)
                        end
                    end
                else
                    SendPayload(gangData, memberList, myRankName, isBoss, cb)
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

    RegisterNetEvent('JGR_IlegalSystem:server:SaveGangPoint')
    AddEventHandler('JGR_IlegalSystem:server:SaveGangPoint', function(pointType, coords, heading)
        local source = source
        local citizenid = nil
        
        if Config.Framework == "qbcore" then
            local Player = Bridge.Core.Functions.GetPlayer(source)
            if Player then citizenid = Player.PlayerData.citizenid end
        elseif Config.Framework == "esx" then
            local Player = Bridge.Core.GetPlayerFromId(source)
            if Player then citizenid = Player.identifier end
        end
        
        if not citizenid then return end
        
        MySQL.query('SELECT gang_name, rank FROM jgr_gang_members WHERE citizenid = ?', {citizenid}, function(memberRes)
            if not memberRes or #memberRes == 0 then return end
            
            local gangName = memberRes[1].gang_name
            local rankName = memberRes[1].rank
            
            MySQL.query('SELECT stats, ranks FROM jgr_gangs WHERE name = ?', {gangName}, function(gangRes)
               if gangRes and gangRes[1] then
                   local ranks = json.decode(gangRes[1].ranks)
                   -- Basic auth: if they have full_access or simply are in the menu
                   if ranks[rankName] then
                       local stats = gangRes[1].stats
                       if not stats or stats == "" then stats = {} else stats = json.decode(stats) end
                       
                       if not stats.points then stats.points = {} end
                       stats.points[pointType] = { x = coords.x, y = coords.y, z = coords.z, h = heading }
                       
                       MySQL.update('UPDATE jgr_gangs SET stats = ? WHERE name = ?', {json.encode(stats), gangName})
                   end
               end
            end)
        end)
    end)

    RegisterNetEvent('JGR_IlegalSystem:server:InviteMember')
    AddEventHandler('JGR_IlegalSystem:server:InviteMember', function(targetId, rankName)
        local admin = source
        local citizenid = nil
        local targetCitizenId = nil
        
        if Config.Framework == "qbcore" then
            local Player = Bridge.Core.Functions.GetPlayer(admin)
            local Target = Bridge.Core.Functions.GetPlayer(targetId)
            if Player then citizenid = Player.PlayerData.citizenid end
            if Target then targetCitizenId = Target.PlayerData.citizenid end
        elseif Config.Framework == "esx" then
            local Player = Bridge.Core.GetPlayerFromId(admin)
            local Target = Bridge.Core.GetPlayerFromId(targetId)
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
                    local ranksData = json.decode(result[1].ranks)
                    
                    -- Security config check: Does myRank have invite_member or manage_members or full_access? 
                    -- Technically Boss has full_access. We'll simply verify the rank object exists for safety.
                    if not ranksData[myRank] then return end

                    -- Check if target Rank exists in that gang
                    if not ranksData[rankName] then
                        Bridge.Notify(admin, Locales[Config.Locale]['rank_not_found'] and string.format(Locales[Config.Locale]['rank_not_found'], rankName, gangName) or "El rango especificado no existe", "error")
                        return
                    end
                    
                    -- Add to members table
                    MySQL.query('SELECT id FROM jgr_gang_members WHERE citizenid = ? AND gang_name = ?', {targetCitizenId, gangName}, function(targetRes)
                        if targetRes and #targetRes > 0 then
                            -- Already in gang, update rank
                            MySQL.update('UPDATE jgr_gang_members SET rank = ? WHERE citizenid = ? AND gang_name = ?', {rankName, targetCitizenId, gangName}, function(affected)
                                Bridge.Notify(admin, Locales[Config.Locale]['gang_member_updated'] and string.format(Locales[Config.Locale]['gang_member_updated'], GetPlayerName(targetId), gangName, rankName) or "Miembro actualizado", "success")
                                Bridge.Notify(targetId, Locales[Config.Locale]['you_are_now_in_gang'] and string.format(Locales[Config.Locale]['you_are_now_in_gang'], gangName, rankName) or "Ahora estás en la banda", "success")
                                TriggerClientEvent('JGR_IlegalSystem:client:RefreshNPCs', targetId)
                            end)
                        else
                            -- Insert New Member
                            MySQL.insert('INSERT INTO jgr_gang_members (gang_name, citizenid, rank) VALUES (?, ?, ?)', {gangName, targetCitizenId, rankName}, function(id)
                                Bridge.Notify(admin, Locales[Config.Locale]['gang_member_added'] and string.format(Locales[Config.Locale]['gang_member_added'], GetPlayerName(targetId), gangName, rankName) or "Miembro reclutado", "success")
                                Bridge.Notify(targetId, Locales[Config.Locale]['you_are_now_in_gang'] and string.format(Locales[Config.Locale]['you_are_now_in_gang'], gangName, rankName) or "Has sido reclutado", "success")
                                TriggerClientEvent('JGR_IlegalSystem:client:RefreshNPCs', targetId)
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

    RegisterNetEvent('JGR_IlegalSystem:server:SaveDocument')
    AddEventHandler('JGR_IlegalSystem:server:SaveDocument', function(docId, title, content)
        local src = source
        getPlayerGang(src, function(gangName)
            if not gangName then return end
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
                    -- Send updated documents to client for instant visual refresh
                    TriggerClientEvent('JGR_IlegalSystem:client:UpdateDocuments', src, stats.documents)
                end)
            end)
        end)
    end)

    RegisterNetEvent('JGR_IlegalSystem:server:DeleteDocument')
    AddEventHandler('JGR_IlegalSystem:server:DeleteDocument', function(docId)
        local src = source
        getPlayerGang(src, function(gangName)
            if not gangName then return end
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
                    -- Send updated documents to client for instant visual refresh
                    TriggerClientEvent('JGR_IlegalSystem:client:UpdateDocuments', src, stats.documents)
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
            MySQL.query('SELECT ranks FROM jgr_gangs WHERE name = ?', {gangName}, function(gangRes)
                if not gangRes or #gangRes == 0 then return end
                local ranks = json.decode(gangRes[1].ranks)
                if ranks[rankName] then
                    Bridge.Notify(src, "El rango '" .. rankName .. "' ya existe.", "error")
                    return
                end
                ranks[rankName] = {}
                MySQL.update('UPDATE jgr_gangs SET ranks = ? WHERE name = ?', {json.encode(ranks), gangName})
                Bridge.Notify(src, "Rango '" .. rankName .. "' creado correctamente.", "success")
                -- Send updated ranks to client for instant visual refresh
                TriggerClientEvent('JGR_IlegalSystem:client:UpdateRanks', src, ranks)
            end)
        end)
    end)

    RegisterNetEvent('JGR_IlegalSystem:server:DeleteRank')
    AddEventHandler('JGR_IlegalSystem:server:DeleteRank', function(rankName)
        local src = source
        getPlayerGang(src, function(gangName)
            if not gangName then return end
            MySQL.query('SELECT ranks FROM jgr_gangs WHERE name = ?', {gangName}, function(gangRes)
                if not gangRes or #gangRes == 0 then return end
                local ranks = json.decode(gangRes[1].ranks)
                if not ranks[rankName] then
                    Bridge.Notify(src, "El rango '" .. rankName .. "' no existe.", "error")
                    return
                end
                if ranks[rankName].isBoss then
                    Bridge.Notify(src, "No puedes eliminar el rango de Jefe.", "error")
                    return
                end
                ranks[rankName] = nil
                MySQL.update('UPDATE jgr_gangs SET ranks = ? WHERE name = ?', {json.encode(ranks), gangName})
                Bridge.Notify(src, "Rango '" .. rankName .. "' eliminado.", "success")
                -- Send updated ranks to client for instant visual refresh
                TriggerClientEvent('JGR_IlegalSystem:client:UpdateRanks', src, ranks)
            end)
        end)
    end)

    RegisterNetEvent('JGR_IlegalSystem:server:UpdateRankPermissions')
    AddEventHandler('JGR_IlegalSystem:server:UpdateRankPermissions', function(rankName, permissions)
        local src = source
        getPlayerGang(src, function(gangName)
            if not gangName then return end
            MySQL.query('SELECT ranks FROM jgr_gangs WHERE name = ?', {gangName}, function(gangRes)
                if not gangRes or #gangRes == 0 then return end
                local ranks = json.decode(gangRes[1].ranks)
                if not ranks[rankName] then return end
                
                -- Update permissions
                ranks[rankName].manage_members = permissions.manage_members
                ranks[rankName].manage_points = permissions.manage_points
                ranks[rankName].manage_ranks = permissions.manage_ranks
                ranks[rankName].manage_docs = permissions.manage_docs
                
                MySQL.update('UPDATE jgr_gangs SET ranks = ? WHERE name = ?', {json.encode(ranks), gangName}, function()
                    Bridge.Notify(src, "Permisos de '" .. rankName .. "' actualizados.", "success")
                    TriggerClientEvent('JGR_IlegalSystem:client:UpdateRanks', src, ranks)
                end)
            end)
        end)
    end)
end)
