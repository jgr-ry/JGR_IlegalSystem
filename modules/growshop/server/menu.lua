-- Servidor: compras mayoristas, repartos y crafteo de "El Cocinero" del Grow Shop
-- Los fondos de la sociedad se gestionan en modules/growshop/server/management.lua

local GS = JGR.GrowShop
local U = Bridge.Util

local MAX_QTY_PER_ITEM = 1000
local PICKUP_RADIUS = 10.0

local PendingOrders = {} -- [identifier] = { items = { [item] = qty }, kind = 'pickup'|'delivery', readyAt, coords }
local PendingCrafts = {} -- [identifier] = { recipeId, batches, readyAt }

local function wholesaleItem(itemName)
    for _, wItem in pairs(Config.GrowShop.Wholesale) do
        if wItem.item == itemName then return wItem end
    end
    return nil
end

--- Entrega los items de un pedido al jugador. Lo que no quepa se deja en el almacén del negocio.
local function giveOrderToPlayer(src, items)
    for itemKey, qty in pairs(items) do
        if not Bridge.AddItem(src, itemKey, qty) then
            if not Bridge.AddItemToStash(Config.GrowShop.Stash.Name, itemKey, qty) then
                print(('^1[JGR_IlegalSystem]^7 No se pudo entregar %dx %s a %s (inventario lleno y almacén no disponible).'):format(qty, itemKey, src))
            end
        end
    end
end

--- Deja un pedido en el almacén del negocio. Si no se puede (sin ox_inventory/qb-inventory), se le da al jugador.
local function deliverOrderToStash(src, items)
    local stashName = Config.GrowShop.Stash.Name
    local leftovers = {}
    for itemKey, qty in pairs(items) do
        if not Bridge.AddItemToStash(stashName, itemKey, qty) then
            leftovers[itemKey] = qty
        end
    end
    if next(leftovers) and src and Bridge.IsOnline(src) then
        giveOrderToPlayer(src, leftovers)
        return false
    end
    return true
end

RegisterNetEvent('JGR_IlegalSystem:Server:CheckoutCart', function(cartData)
    local src = source
    if not Config.GrowShop.Enabled then return end
    if not GS.IsManager(src) then
        Bridge.Notify(src, "No tienes permisos de gestión.", "error")
        return
    end
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end

    local pending = PendingOrders[identifier]
    if pending then
        if pending.kind == 'delivery' and os.time() > (pending.readyAt or 0) + 180 then
            -- El repartidor nunca llegó a confirmar (cliente reiniciado, NPC atascado…): se entrega ya.
            PendingOrders[identifier] = nil
            deliverOrderToStash(src, pending.items)
        elseif pending.kind == 'pickup' then
            TriggerClientEvent('JGR_IlegalSystem:Client:StartPickupMission', src, pending.coords)
            Bridge.Notify(src, "Ya tienes un pedido pendiente. Te hemos vuelto a marcar el punto de recogida.", "error")
            return
        else
            Bridge.Notify(src, "Ya tienes un pedido pendiente. Espera a que llegue antes de hacer otro.", "error")
            return
        end
    end

    if type(cartData) ~= "table" then
        Bridge.Notify(src, "Carrito inválido.", "error")
        return
    end

    -- Precios y cantidades se calculan en el servidor con la configuración, nunca con lo que envía el cliente.
    local items, totalCost, totalItems = {}, 0, 0
    for itemKey, cartItem in pairs(cartData) do
        local qty = U.ToInt(type(cartItem) == "table" and cartItem.qty, 1, MAX_QTY_PER_ITEM)
        if not qty then
            Bridge.Notify(src, "Cantidad inválida en el carrito.", "error")
            return
        end
        local configItem = type(itemKey) == "string" and wholesaleItem(itemKey)
        if not configItem then
            Bridge.Notify(src, "Objeto inválido en el carrito.", "error")
            return
        end
        items[itemKey] = qty
        totalCost = totalCost + (configItem.price * qty)
        totalItems = totalItems + qty
    end

    if totalCost <= 0 then return end

    -- Cobro atómico: solo descuenta si hay fondos suficientes.
    local jobName = Config.GrowShop.JobName
    local affected = MySQL.update.await('UPDATE jgr_societies SET funds = funds - ? WHERE job_name = ? AND funds >= ?', { totalCost, jobName, totalCost })
    if (affected or 0) < 1 then
        Bridge.Notify(src, "La sociedad no tiene fondos suficientes.", "error")
        return
    end

    local newFunds = MySQL.scalar.await('SELECT funds FROM jgr_societies WHERE job_name = ?', { jobName }) or 0
    TriggerClientEvent('JGR_IlegalSystem:Client:UpdateGrowShopMoney', src, newFunds)

    if totalItems < 6 then
        -- PEDIDO PEQUEÑO: un repartidor lo deja en el almacén en 3-5 minutos
        local deliverySeconds = math.random(180, 300)
        PendingOrders[identifier] = { items = items, kind = 'delivery', readyAt = os.time() + deliverySeconds }
        TriggerClientEvent('JGR_IlegalSystem:Client:StartDeliveryTimer', src, deliverySeconds)
        Bridge.Notify(src, ("Pedido pequeño (%s uds). Un repartidor lo traerá en %d minutos."):format(totalItems, math.ceil(deliverySeconds / 60)), "primary")

        SetTimeout(deliverySeconds * 1000, function()
            local order = PendingOrders[identifier]
            if not order or order.kind ~= 'delivery' then return end
            local current = Bridge.GetSourceFromIdentifier(identifier)
            if current then
                -- El cliente reproduce la llegada del repartidor y luego avisa con CompleteDelivery.
                TriggerClientEvent('JGR_IlegalSystem:Client:DeliveryArrived', current)
            else
                -- El jugador se desconectó: el pedido se deja directamente en el almacén.
                deliverOrderToStash(nil, order.items)
                PendingOrders[identifier] = nil
            end
        end)
    else
        -- PEDIDO GRANDE: hay que ir a recogerlo con la furgoneta
        local spawnPoints = Config.GrowShop.DeliveryPoints
        local dropoffCoords = spawnPoints[math.random(1, #spawnPoints)]
        PendingOrders[identifier] = { items = items, kind = 'pickup', coords = dropoffCoords }
        TriggerClientEvent('JGR_IlegalSystem:Client:StartPickupMission', src, dropoffCoords)
        Bridge.Notify(src, ("Pedido grande (%s uds). Ve con la furgoneta al punto marcado en el GPS."):format(totalItems), "primary")
    end
end)

RegisterNetEvent('JGR_IlegalSystem:Server:CompletePickup', function()
    local src = source
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end
    local order = PendingOrders[identifier]

    if not order or order.kind ~= 'pickup' then
        Bridge.Notify(src, "No tienes ningún pedido pendiente de recoger.", "error")
        return
    end

    local ped = GetPlayerPed(src)
    local c = order.coords
    if not ped or ped == 0 or #(GetEntityCoords(ped) - vector3(c.x, c.y, c.z)) > PICKUP_RADIUS then
        Bridge.Notify(src, "Tienes que estar en el punto de recogida.", "error")
        return
    end

    PendingOrders[identifier] = nil
    giveOrderToPlayer(src, order.items)
    TriggerClientEvent('JGR_IlegalSystem:Client:RemovePickupTarget', src)
    Bridge.Notify(src, "Has recogido con éxito todo el pedido.", "success")
end)

-- Pedido pequeño: el repartidor deja los items en el almacén del negocio
RegisterNetEvent('JGR_IlegalSystem:Server:CompleteDelivery', function()
    local src = source
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end
    local order = PendingOrders[identifier]
    if not order or order.kind ~= 'delivery' or os.time() < (order.readyAt or 0) then return end

    PendingOrders[identifier] = nil
    if deliverOrderToStash(src, order.items) then
        Bridge.Notify(src, "El repartidor ha dejado el pedido en el almacén del negocio.", "success")
    else
        Bridge.Notify(src, "El almacén no está disponible: el pedido se ha entregado en tu inventario.", "primary")
    end
end)

RegisterNetEvent('JGR_IlegalSystem:Server:CraftGrowItem', function(recipeId, batches)
    local src = source
    if not Config.GrowShop.Enabled then return end
    if not GS.IsManager(src) then
        Bridge.Notify(src, "No tienes permisos de gestión.", "error")
        return
    end
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end

    local recipe = type(recipeId) == "string" and Config.GrowShop.Crafting[recipeId]
    if not recipe then return end
    batches = U.ToInt(batches, 1, 100)
    if not batches then
        Bridge.Notify(src, "Cantidad inválida para craftear.", "error")
        return
    end

    local pendingCraft = PendingCrafts[identifier]
    if pendingCraft then
        if os.time() > pendingCraft.readyAt + 120 then
            -- El encargo anterior nunca se recogió (desconexión, NPC atascado…): se entrega ahora.
            PendingCrafts[identifier] = nil
            local prev = Config.GrowShop.Crafting[pendingCraft.recipeId]
            if prev then giveOrderToPlayer(src, { [pendingCraft.recipeId] = prev.amount * pendingCraft.batches }) end
        else
            Bridge.Notify(src, "El Cocinero todavía está con tu pedido anterior.", "error")
            return
        end
    end

    for _, req in pairs(recipe.required) do
        if Bridge.GetItemCount(src, req.item) < req.amount * batches then
            Bridge.Notify(src, "No tienes los materiales suficientes en tu inventario.", "error")
            return
        end
    end

    for _, req in pairs(recipe.required) do
        Bridge.RemoveItem(src, req.item, req.amount * batches)
    end

    PendingCrafts[identifier] = { recipeId = recipeId, batches = batches, readyAt = os.time() + 15 }

    TriggerClientEvent('JGR_IlegalSystem:Client:RunNPCSequence', src, false)
    Bridge.Notify(src, "El Mensajero ha recogido los materiales. El Cocinero se pone manos a la obra.", "primary")

    SetTimeout(15000, function()
        local current = Bridge.GetSourceFromIdentifier(identifier)
        if current then
            TriggerClientEvent('JGR_IlegalSystem:Client:RunNPCSequence', current, true)
        end
    end)
end)

RegisterNetEvent('JGR_IlegalSystem:Server:CookFinished', function()
    local src = source
    local identifier = Bridge.GetIdentifier(src)
    if not identifier then return end
    local craftData = PendingCrafts[identifier]
    if not craftData or os.time() < craftData.readyAt then return end

    PendingCrafts[identifier] = nil
    local recipe = Config.GrowShop.Crafting[craftData.recipeId]
    if not recipe then return end

    local rewardAmount = recipe.amount * craftData.batches
    giveOrderToPlayer(src, { [craftData.recipeId] = rewardAmount })
    Bridge.Notify(src, ("El Cocinero ha terminado %sx %s y se han entregado."):format(rewardAmount, recipe.label), "success")
end)
