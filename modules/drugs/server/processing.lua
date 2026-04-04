local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================================
-- ROLLING JOINTS SYSTEM (Papel de liar)
-- ============================================================

-- Register usable item
CreateThread(function()
    if Config.Framework ~= "qbcore" then return end

    QBCore.Functions.CreateUseableItem("rolling_paper", function(source, item)
        TriggerClientEvent('JGR_Drugs:Client:RollJointMenu', source)
    end)
end)

RegisterNetEvent('JGR_Drugs:Server:RollJoint', function(index)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local cfg = Config.Processing.Joints[index]
    if not cfg then return end

    -- Verify items on server
    local hasBud = Player.Functions.GetItemByName(cfg.bud)
    local hasPaper = Player.Functions.GetItemByName(cfg.paper)

    if not hasBud or hasBud.amount < 1 then
        TriggerClientEvent('QBCore:Notify', src, "No tienes suficientes cogollos.", "error")
        return
    end

    if not hasPaper or hasPaper.amount < cfg.paper_amt then
        TriggerClientEvent('QBCore:Notify', src, "No tienes suficiente papel de liar.", "error")
        return
    end

    -- Remove items and add result
    Player.Functions.RemoveItem(cfg.bud, 1)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[cfg.bud], "remove")
    
    Player.Functions.RemoveItem(cfg.paper, cfg.paper_amt)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[cfg.paper], "remove")

    Player.Functions.AddItem(cfg.result, 1)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[cfg.result], "add")

    TriggerClientEvent('QBCore:Notify', src, "Has liado un " .. cfg.label, "success")
end)

-- ============================================================
-- DRUG BAGGING SYSTEM (Mesa de procesado)
-- ============================================================

RegisterNetEvent('JGR_Drugs:Server:ProcessBaggie', function(index)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local cfg = Config.Processing.Baggies[index]
    if not cfg then return end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local targetCoords = Config.Processing.BaggieLocation.xyz
    local dist = #(coords - targetCoords)

    if dist > (Config.Processing.BaggieTargetDistance + 2.0) then
        -- Anti-cheat flag, too far
        return
    end

    -- Verify items on server
    local hasBud = Player.Functions.GetItemByName(cfg.bud)
    local hasBag = Player.Functions.GetItemByName(cfg.baggie)

    if not hasBud or hasBud.amount < cfg.bud_amt then
        TriggerClientEvent('QBCore:Notify', src, "No tienes suficientes cogollos.", "error")
        return
    end

    if not hasBag or hasBag.amount < 1 then
        TriggerClientEvent('QBCore:Notify', src, "No tienes bolsitas vacías.", "error")
        return
    end

    -- Remove items and add result
    Player.Functions.RemoveItem(cfg.bud, cfg.bud_amt)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[cfg.bud], "remove")
    
    Player.Functions.RemoveItem(cfg.baggie, 1)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[cfg.baggie], "remove")

    Player.Functions.AddItem(cfg.result, 1)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[cfg.result], "add")

    TriggerClientEvent('QBCore:Notify', src, "Has procesado 1x " .. cfg.label, "success")
end)
