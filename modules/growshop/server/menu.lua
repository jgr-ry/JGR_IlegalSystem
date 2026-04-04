local QBCore = exports['qb-core']:GetCoreObject()

-- Society funds are now fetched via JGR_IlegalSystem:Server:GetSocietyFunds in server/management.lua

local PendingOrders = {}

RegisterNetEvent('JGR_IlegalSystem:Server:CheckoutCart', function(cartData)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not Config.GrowShop.Enabled then return end

    if Player.PlayerData.job.name ~= Config.GrowShop.JobName then return end

    local totalCost = 0
    local totalItems = 0
    -- Verify pricing against config
    for itemKey, cartItem in pairs(cartData) do
        local configItem = nil
        for _, wItem in pairs(Config.GrowShop.Wholesale) do
            if wItem.item == itemKey then
                configItem = wItem
                break
            end
        end
        if configItem then
            totalCost = totalCost + (configItem.price * cartItem.qty)
            totalItems = totalItems + cartItem.qty
        else
            TriggerClientEvent('QBCore:Notify', src, "Objeto inválido en el carrito.", "error")
            return
        end
    end

    if totalCost <= 0 then return end
    
    -- Try to remove money from society
    local fundsResult = MySQL.query.await('SELECT funds FROM jgr_societies WHERE job_name = ?', {Config.GrowShop.JobName})
    local currentFunds = 0
    if fundsResult and #fundsResult > 0 then currentFunds = fundsResult[1].funds end
    
    if currentFunds >= totalCost then
        MySQL.update.await('UPDATE jgr_societies SET funds = funds - ? WHERE job_name = ?', {totalCost, Config.GrowShop.JobName})
        
        -- Store the pending order
        PendingOrders[Player.PlayerData.citizenid] = cartData

        -- Update UI society money
        local newFunds = currentFunds - totalCost
        TriggerClientEvent('JGR_IlegalSystem:Client:UpdateGrowShopMoney', src, newFunds)

        if totalItems < 6 then
            -- SMALL ORDER: NPC delivers to stash in 3-5 minutes
            local deliverySeconds = math.random(180, 300) -- 3 to 5 minutes
            TriggerClientEvent('JGR_IlegalSystem:Client:StartDeliveryTimer', src, deliverySeconds)
            TriggerClientEvent('QBCore:Notify', src, ("Pedido pequeño (%s uds). Un repartidor lo traerá en %d minutos."):format(totalItems, math.ceil(deliverySeconds / 60)), "primary")

            SetTimeout(deliverySeconds * 1000, function()
                local StillPlayer = QBCore.Functions.GetPlayer(src)
                if StillPlayer then
                    TriggerClientEvent('JGR_IlegalSystem:Client:DeliveryArrived', src)
                end
            end)
        else
            -- LARGE ORDER: Go pick it up
            local spawnPoints = Config.GrowShop.DeliveryPoints
            local dropoffCoords = spawnPoints[math.random(1, #spawnPoints)]
            TriggerClientEvent('JGR_IlegalSystem:Client:StartPickupMission', src, dropoffCoords)
            TriggerClientEvent('QBCore:Notify', src, ("Pedido grande (%s uds). Ve con la furgoneta al punto marcado en el GPS."):format(totalItems), "primary")
        end
    else
        TriggerClientEvent('QBCore:Notify', src, "La sociedad no tiene fondos suficientes.", "error")
    end
end)

RegisterNetEvent('JGR_IlegalSystem:Server:CompletePickup', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citz = Player.PlayerData.citizenid
    local order = PendingOrders[citz]
    
    if not order then
        TriggerClientEvent('QBCore:Notify', src, "No tienes ningún pedido pendiente de recoger.", "error")
        return
    end

    -- Give the items
    for itemKey, cartItem in pairs(order) do
        Player.Functions.AddItem(itemKey, cartItem.qty)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemKey], "add", cartItem.qty)
    end
    
    TriggerClientEvent('JGR_IlegalSystem:Client:RemovePickupTarget', src)
    TriggerClientEvent('QBCore:Notify', src, "Has recogido con éxito todo el pedido.", "success")
    PendingOrders[citz] = nil
end)

-- Small order: NPC delivered items go into the business stash
RegisterNetEvent('JGR_IlegalSystem:Server:CompleteDelivery', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citz = Player.PlayerData.citizenid
    local order = PendingOrders[citz]
    
    if not order then return end

    -- Add items to the stash instead of player inventory
    local stashName = Config.GrowShop.Stash.Name
    for itemKey, cartItem in pairs(order) do
        -- Use QBCore stash inventory export to add items directly to the stash
        exports['qb-inventory']:AddItem(stashName, itemKey, cartItem.qty, false, false, 'stash')
    end
    
    TriggerClientEvent('QBCore:Notify', src, "El repartidor ha dejado el pedido en el almacén del negocio.", "success")
    PendingOrders[citz] = nil
end)

RegisterNetEvent('JGR_IlegalSystem:Server:CraftGrowItem', function(recipeId, batches)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if not Config.GrowShop.Enabled then return end

    if Player.PlayerData.job.name ~= Config.GrowShop.JobName then return end

    local recipe = Config.GrowShop.Crafting[recipeId]
    if not recipe then return end

    -- Validate if player has all required items in sufficient quantities
    local hasAllItems = true
    for _, req in pairs(recipe.required) do
        local requiredAmount = req.amount * batches
        local playerItem = Player.Functions.GetItemByName(req.item)
        if not playerItem or playerItem.amount < requiredAmount then
            hasAllItems = false
            break
        end
    end

    if not hasAllItems then
        TriggerClientEvent('QBCore:Notify', src, "No tienes los materiales suficientes en tu inventario.", "error")
        return
    end

    -- Remove required items
    for _, req in pairs(recipe.required) do
        local requiredAmount = req.amount * batches
        Player.Functions.RemoveItem(req.item, requiredAmount)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[req.item], "remove", requiredAmount)
    end

    -- Trigger Client NPC to go inside
    TriggerClientEvent('JGR_IlegalSystem:Client:RunNPCSequence', src, false)
    TriggerClientEvent('QBCore:Notify', src, "El Mensajero ha recogido los materiales. El Cocinero se pone manos a la obra.", "primary")

    -- Server Timer (Simulated craft time)
    SetTimeout(15000, function()
        -- Wait for player to still be online
        local StillPlayer = QBCore.Functions.GetPlayer(src)
        if StillPlayer then
            TriggerClientEvent('JGR_IlegalSystem:Client:RunNPCSequence', src, true)
            
            -- Save pending craft to be collected when NPC leaves
            PendingOrders["CRAFT_"..StillPlayer.PlayerData.citizenid] = {
                recipeId = recipeId,
                batches = batches
            }
        end
    end)
end)

RegisterNetEvent('JGR_IlegalSystem:Server:CookFinished', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local citz = Player.PlayerData.citizenid
    local craftData = PendingOrders["CRAFT_"..citz]
    
    if craftData then
        local recipeId = craftData.recipeId
        local batches = craftData.batches
        local recipe = Config.GrowShop.Crafting[recipeId]
        
        if recipe then
            local rewardAmount = recipe.amount * batches
            Player.Functions.AddItem(recipeId, rewardAmount)
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[recipeId], "add", rewardAmount)
            TriggerClientEvent('QBCore:Notify', src, ("El Cocinero ha terminado %sx %s y se han entregado."):format(rewardAmount, recipe.label), "success")
        end
        PendingOrders["CRAFT_"..citz] = nil
    end
end)
