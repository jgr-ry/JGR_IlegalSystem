-- Server logic for Gang Creation

local CreationTokens = {}

local FirstNames = {"Paquito", "Jose", "Maria", "Carlos", "Lucia", "Miguel", "Antonio", "Elena", "Jorge", "Laura", "Hector", "Sofia", "Diego"}
local LastNames = {"Porras", "Garcia", "Rodriguez", "Lopez", "Martinez", "Sanchez", "Perez", "Gomez", "Martin", "Ramos", "Ruiz", "Hernandez"}

local function GenerateNPCName()
    local fn = FirstNames[math.random(#FirstNames)]
    local ln = LastNames[math.random(#LastNames)]
    return fn .. " " .. ln
end

JGR.RegisterModule("gang_creator_server", function()

    -- Give token command (Admin only)
    RegisterCommand('givegang', function(source, args)
        local admin = source
        local targetId = tonumber(args[1])
        
        -- Add Admin Permission Check here based on Framework
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
            isAdmin = true -- Standalone
        end

        if isAdmin then
            if targetId then
                CreationTokens[targetId] = true
                Bridge.Notify(admin, _L('token_granted', targetId), "success")
                Bridge.Notify(targetId, _L('token_received'), "success")
            else
                Bridge.Notify(admin, _L('player_not_found'), "error")
            end
        else
            Bridge.Notify(admin, _L('no_permission'), "error")
        end
    end, false)

    -- Callback to check token
    if Config.Framework == "qbcore" then
        Bridge.Core.Functions.CreateCallback('JGR_IlegalSystem:server:CheckToken', function(source, cb)
            cb(CreationTokens[source] == true)
        end)
    elseif Config.Framework == "esx" then
        Bridge.Core.RegisterServerCallback('JGR_IlegalSystem:server:CheckToken', function(source, cb)
            cb(CreationTokens[source] == true)
        end)
    end

    -- Save Gang Database Logic
    RegisterNetEvent('JGR_IlegalSystem:server:SaveGang')
    AddEventHandler('JGR_IlegalSystem:server:SaveGang', function(data)
        local src = source
        if not CreationTokens[src] then
            if Config.Debug then print("[JGR_WARNING] Player " .. src .. " attempted to save a gang without token.") end
            return
        end
        
        -- data.config (name, color, ranks), data.npc (model, coords, heading), data.specialization
        local gangName = data.config.name
        local gangColor = data.config.color
        local ranks = json.encode(data.config.ranks)
        local npcModel = data.npc.model
        local coords = json.encode({x = data.npc.coords.x, y = data.npc.coords.y, z = data.npc.coords.z, h = data.npc.heading})
        local spec = data.specialization
        local npcName = GenerateNPCName()

        -- Execute query
        MySQL.insert('INSERT INTO jgr_gangs (name, color, ranks, npc_model, npc_name, coords, specialization) VALUES (?, ?, ?, ?, ?, ?, ?)', 
        {gangName, gangColor, ranks, npcModel, npcName, coords, spec}, function(id)
            if id then
                -- Consume token
                CreationTokens[src] = false
                
                Bridge.Notify(src, _L('gang_created'), "success")
                if Config.Debug then print("[JGR_IlegalSystem] Gang created successfully: " .. gangName .. " Spec: " .. spec) end
                
                -- Tell all clients to refresh NPC spawners
                TriggerClientEvent('JGR_IlegalSystem:client:RefreshNPCs', -1)
            else
                Bridge.Notify(src, _L('gang_creation_failed'), "error")
            end
        end)
    end)
end)
