local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================================
-- ROLLING JOINTS SYSTEM (Papel de liar)
-- ============================================================
RegisterNetEvent('JGR_Drugs:Client:RollJointMenu', function()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData or not PlayerData.items then return end

    -- Check what buds the player currently has
    local hasBuds = {}
    for _, item in pairs(PlayerData.items) do
        local amt = item and (item.amount or item.count or 0) or 0
        if amt > 0 then
            hasBuds[item.name] = (hasBuds[item.name] or 0) + amt
        end
    end

    local options = {}

    for i, jointCfg in ipairs(Config.Processing.Joints) do
        -- Only show options if the player has the required bud
        if hasBuds[jointCfg.bud] and hasBuds[jointCfg.bud] >= 1 then
            options[#options + 1] = {
                title = "Liar " .. jointCfg.label,
                description = "Requiere: 1x " .. QBCore.Shared.Items[jointCfg.bud].label .. " y " .. jointCfg.paper_amt .. "x " .. QBCore.Shared.Items[jointCfg.paper].label,
                icon = 'cannabis',
                onSelect = function()
                    RollJoint(i, jointCfg)
                end
            }
        end
    end

    if #options == 0 then
        QBCore.Functions.Notify("No tienes cogollos para liar.", "error")
        return
    end

    lib.registerContext({
        id = 'jgr_roll_joints_menu',
        title = 'Liar Porros',
        options = options
    })

    lib.showContext('jgr_roll_joints_menu')
end)

function RollJoint(index, cfg)
    if lib.progressBar({
        duration = 5000,
        label = 'Liando ' .. cfg.label .. '...',
        useWhileDead = false,
        canCancel = true,
        disable = { car = false, move = true, combat = true },
        anim = {
            dict = 'amb@world_human_smoking@male@male_a@base',
            clip = 'base',
            flags = 49
        },
    }) then
        TriggerServerEvent('JGR_Drugs:Server:RollJoint', index)
    else
        QBCore.Functions.Notify("Cancelado.", "error")
    end
end

-- ============================================================
-- DRUG BAGGING SYSTEM (Mesa de procesado)
-- ============================================================

CreateThread(function()
    if Config.Framework ~= "qbcore" then return end

    -- Setup targeting for processing location
    exports['qb-target']:AddBoxZone("jgr_drug_processing_table", Config.Processing.BaggieLocation.xyz, 1.5, 1.5, {
        name = "jgr_drug_processing_table",
        heading = Config.Processing.BaggieLocation.w,
        debugPoly = false,
        minZ = Config.Processing.BaggieLocation.z - 1.0,
        maxZ = Config.Processing.BaggieLocation.z + 1.0,
    }, {
        options = {
            {
                type = "client",
                event = "JGR_Drugs:Client:BaggingMenu",
                icon = "fas fa-box",
                label = "Procesar Cogollos",
            },
        },
        distance = Config.Processing.BaggieTargetDistance
    })
end)

RegisterNetEvent('JGR_Drugs:Client:BaggingMenu', function()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData or not PlayerData.items then return end

    -- Check what buds the player currently has
    local hasBuds = {}
    local hasBaggies = 0
    for _, item in pairs(PlayerData.items) do
        local amt = item and (item.amount or item.count or 0) or 0
        if amt > 0 then
            hasBuds[item.name] = (hasBuds[item.name] or 0) + amt
            if item.name == "empty_baggies" then
                hasBaggies = hasBaggies + amt
            end
        end
    end

    if hasBaggies < 1 then
        QBCore.Functions.Notify("Necesitas bolsitas vacías (empty_baggies).", "error")
        return
    end

    local options = {}

    for i, bagCfg in ipairs(Config.Processing.Baggies) do
        -- Only show options if the player has the required bud
        if hasBuds[bagCfg.bud] and hasBuds[bagCfg.bud] >= bagCfg.bud_amt then
            options[#options + 1] = {
                title = "Empaquetar " .. bagCfg.label,
                description = "Requiere: " .. bagCfg.bud_amt .. "x " .. QBCore.Shared.Items[bagCfg.bud].label .. " y 1x Bolsita Vacía",
                icon = 'box-open',
                onSelect = function()
                    ProcessBaggie(i, bagCfg)
                end
            }
        end
    end

    if #options == 0 then
        QBCore.Functions.Notify("No tienes cogollos suficientes para procesar.", "error")
        return
    end

    lib.registerContext({
        id = 'jgr_process_baggies_menu',
        title = 'Procesar Cogollos',
        options = options
    })

    lib.showContext('jgr_process_baggies_menu')
end)

function ProcessBaggie(index, cfg)
    if lib.progressBar({
        duration = 4000,
        label = 'Empaquetando ' .. cfg.label .. '...',
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, move = true, combat = true },
        anim = {
            dict = 'mini@repair',
            clip = 'fixing_a_ped',
            flags = 16
        },
    }) then
        TriggerServerEvent('JGR_Drugs:Server:ProcessBaggie', index)
    else
        QBCore.Functions.Notify("Cancelado.", "error")
    end
end
