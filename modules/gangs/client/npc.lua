local ActiveNPCs = {}
local LocalPlayerGang = nil
local FetchMyGang, FetchAndSpawnAllNPCs, ProcessSpawns
local TEXT_OWNER = "gang_npc"

local function trimGangName(s)
    if s == nil then return nil end
    s = tostring(s)
    return (s:match("^%s*(.-)%s*$")) or s
end

function FetchMyGang()
    lib.callback('JGR_IlegalSystem:server:GetMyGang', false, function(gang)
        LocalPlayerGang = trimGangName(gang)
    end)
end

JGR.RegisterModule("gang_npc_spawner", function()
    -- Start fetching on resource start if player is already loaded
    Citizen.CreateThread(function()
        Citizen.Wait(2000)
        FetchMyGang()
        FetchAndSpawnAllNPCs()
    end)

    Bridge.OnPlayerLoaded(function()
        FetchMyGang()
        FetchAndSpawnAllNPCs()
    end)

    -- Refresh event from server (When a new gang is created or ranks update)
    RegisterNetEvent('JGR_IlegalSystem:client:RefreshNPCs')
    AddEventHandler('JGR_IlegalSystem:client:RefreshNPCs', function()
        FetchMyGang()
        FetchAndSpawnAllNPCs()
        if type(_G.JGR_SyncGangWorldData) == "function" then
            Citizen.SetTimeout(800, _G.JGR_SyncGangWorldData)
        end
    end)

    -- Hilo de interacción aquí: menu.lua ya cargó y los módulos se inicializaron (OpenGangMenu disponible).
    Citizen.CreateThread(function()
        Citizen.Wait(800)
        while true do
            local sleep = 1000

            if #ActiveNPCs > 0 and LocalPlayerGang then
                local plyCoords = GetEntityCoords(PlayerPedId())
                local closestNPC = nil
                local minDistance = 2.5
                local myGang = LocalPlayerGang

                for _, npcObj in ipairs(ActiveNPCs) do
                    if trimGangName(npcObj.name) == myGang then
                        local pos = npcObj.coords
                        if npcObj.handle and DoesEntityExist(npcObj.handle) then
                            pos = GetEntityCoords(npcObj.handle)
                        end
                        local dist = #(plyCoords - pos)
                        if dist < minDistance then
                            minDistance = dist
                            closestNPC = npcObj
                        end
                    end
                end

                if closestNPC then
                    sleep = 0
                    Bridge.ShowText(TEXT_OWNER, _L('interact_npc', closestNPC.npc_name))

                    local ePressed = IsControlJustPressed(0, 38) or IsDisabledControlJustPressed(0, 38)
                    if ePressed then
                        if type(_G.JGR_SyncGangWorldData) == "function" then
                            _G.JGR_SyncGangWorldData()
                        end
                        local open = OpenGangMenu or _G.OpenGangMenu
                        if type(open) == "function" then
                            open(trimGangName(closestNPC.name))
                        else
                            Bridge.Notify(PlayerId(), _L('gang_menu_fn_missing'), "error")
                        end
                    end
                else
                    Bridge.HideText(TEXT_OWNER)
                end
            else
                Bridge.HideText(TEXT_OWNER)
            end

            Citizen.Wait(sleep)
        end
    end)
end)

function FetchAndSpawnAllNPCs()
    lib.callback('JGR_IlegalSystem:server:GetAllGangs', false, function(gangs)
        ProcessSpawns(gangs)
    end)
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
        -- Coordenadas en JSON: { x, y, z, h }
        local success, coordsNode = pcall(json.decode, gang.coords)

        if success and type(coordsNode) == "table" and coordsNode.x and coordsNode.y and coordsNode.z then
            local model = GetHashKey(gang.npc_model)
            if IsModelValid(model) and pcall(lib.requestModel, model, 10000) then
                local ped = CreatePed(4, model, coordsNode.x, coordsNode.y, coordsNode.z, coordsNode.h or 0.0, false, false)
                SetModelAsNoLongerNeeded(model)

                SetEntityInvincible(ped, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                FreezeEntityPosition(ped, true)
                TaskStartScenarioInPlace(ped, "WORLD_HUMAN_STAND_GUARD", 0, true)
                
                -- Save reference to delete if script restarts and for distance checks
                table.insert(ActiveNPCs, {
                    handle = ped,
                    name = trimGangName(gang.name) or gang.name,
                    npc_name = gang.npc_name,
                    coords = vector3(coordsNode.x, coordsNode.y, coordsNode.z)
                })
            end
        end
    end
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, npcObj in pairs(ActiveNPCs) do
        if npcObj.handle and DoesEntityExist(npcObj.handle) then DeleteEntity(npcObj.handle) end
    end
end)
