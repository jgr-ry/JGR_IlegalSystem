local ActiveNPCs = {}
local LocalPlayerGang = nil

function FetchMyGang()
    if Config.Framework == "qbcore" then
        Bridge.Core.Functions.TriggerCallback('JGR_IlegalSystem:server:GetMyGang', function(gang)
            LocalPlayerGang = gang
        end)
    elseif Config.Framework == "esx" then
        Bridge.Core.TriggerServerCallback('JGR_IlegalSystem:server:GetMyGang', function(gang)
            LocalPlayerGang = gang
        end)
    end
end

JGR.RegisterModule("gang_npc_spawner", function()
    -- Start fetching on resource start if player is already loaded
    Citizen.CreateThread(function()
        Citizen.Wait(2000)
        FetchMyGang()
        FetchAndSpawnAllNPCs()
    end)

    -- Refresh event from server (When a new gang is created or ranks update)
    RegisterNetEvent('JGR_IlegalSystem:client:RefreshNPCs')
    AddEventHandler('JGR_IlegalSystem:client:RefreshNPCs', function()
        FetchMyGang()
        FetchAndSpawnAllNPCs()
    end)
end)

function FetchAndSpawnAllNPCs()
    -- Only framework specific callback since QBCore/ESX structure diverges slightly
    if Config.Framework == "qbcore" then
        Bridge.Core.Functions.TriggerCallback('JGR_IlegalSystem:server:GetAllGangs', function(gangs)
            ProcessSpawns(gangs)
        end)
    elseif Config.Framework == "esx" then
        Bridge.Core.TriggerServerCallback('JGR_IlegalSystem:server:GetAllGangs', function(gangs)
            ProcessSpawns(gangs)
        end)
    end
end

function ProcessSpawns(gangs)
    -- Cleanup existing
    for _, npcObj in pairs(ActiveNPCs) do
        if npcObj.handle and DoesEntityExist(npcObj.handle) then
            DeleteEntity(npcObj.handle)
        end
    end
    ActiveNPCs = {}

    if not gangs then return end
    
    for _, gang in ipairs(gangs) do
        local coordsStr = table.concat({gang.coords})
        -- Parse the JSON coords safely
        local success, coordsNode = pcall(json.decode, gang.coords)
        
        if success and coordsNode then
            local model = GetHashKey(gang.npc_model)
            if IsModelValid(model) then
                RequestModel(model)
                while not HasModelLoaded(model) do Citizen.Wait(10) end
                
                -- Spawn Target Ped
                local ped = CreatePed(4, model, coordsNode.x, coordsNode.y, coordsNode.z, coordsNode.h, false, false)
                
                SetEntityInvincible(ped, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                FreezeEntityPosition(ped, true)
                TaskStartScenarioInPlace(ped, "WORLD_HUMAN_STAND_GUARD", 0, true)
                
                -- Save reference to delete if script restarts and for distance checks
                table.insert(ActiveNPCs, {
                    handle = ped,
                    name = gang.name,
                    npc_name = gang.npc_name,
                    coords = vector3(coordsNode.x, coordsNode.y, coordsNode.z)
                })
            end
        end
    end
end

-- Distance Check Thread for NPC Interaction
local isTextUIShown = false

Citizen.CreateThread(function()
    while true do
        local sleep = 1000
        
        if #ActiveNPCs > 0 and LocalPlayerGang then
            local plyCoords = GetEntityCoords(PlayerPedId())
            local closestNPC = nil
            local minDistance = 2.5
            
            for _, npcObj in ipairs(ActiveNPCs) do
                -- Verification Gate: Only evaluate NPCs belonging to the Player's Gang
                if npcObj.name == LocalPlayerGang then
                    local dist = #(plyCoords - npcObj.coords)
                    if dist < minDistance then
                        minDistance = dist
                        closestNPC = npcObj
                    end
                end
            end
            
            if closestNPC then
                sleep = 0
                if not isTextUIShown then
                    lib.showTextUI(_L('interact_npc', closestNPC.npc_name))
                    isTextUIShown = true
                end
                
                if IsControlJustPressed(0, 38) then -- 38 is 'E'
                    OpenGangMenu(closestNPC.name)
                end
            else
                if isTextUIShown then
                    lib.hideTextUI()
                    isTextUIShown = false
                end
            end
        else
            if isTextUIShown then
                lib.hideTextUI()
                isTextUIShown = false
            end
        end
        
        Citizen.Wait(sleep)
    end
end)
