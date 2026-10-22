-- Servidor: consumibles del Grow Shop (porros, comestibles) y liado manual

local Consumables = {
    ["joint_weed"]   = { health = 10, armor = 0, effect = "weed" },
    ["joint_cbd"]    = { health = 30, armor = 0, effect = "cbd" },
    ["joint_kush"]   = { health = 20, armor = 10, effect = "kush" },
    ["blunt_amnesia"]= { health = 50, armor = 20, effect = "amnesia" },
    ["weed_cookie"]  = { health = 40, armor = 0, effect = "cookie" },
    ["weed_brownie"] = { health = 60, armor = 0, effect = "brownie" },
    ["thc_gummies"]  = { health = 15, armor = 5, effect = "gummies" }
}

CreateThread(function()
    for itemName, data in pairs(Consumables) do
        Bridge.RegisterUsableItem(itemName, function(src, item)
            if Bridge.RemoveItem(src, itemName, 1, item and item.slot) then
                -- Animación y efectos en el cliente
                TriggerClientEvent("JGR_IlegalSystem:Client:UseConsumable", src, itemName, data)
            end
        end)
    end
    -- "rolling_paper" se registra en modules/drugs/server/processing.lua (antes estaba duplicado aquí
    -- y el registro de un archivo pisaba al del otro).
end)

-- Liado desde el menú del Grow Shop (compatibilidad con el flujo antiguo).
RegisterNetEvent('JGR_IlegalSystem:Server:FinishRolling', function(reqItem, rewardItem, paperReq)
    local src = source
    reqItem = tostring(reqItem or "")
    rewardItem = tostring(rewardItem or "")
    paperReq = Bridge.Util.ToInt(paperReq, 1, 10)
    if not paperReq then return end

    -- Lista blanca en el servidor: nunca se confía en los nombres de item del cliente.
    local recipe = nil
    for _, cfg in ipairs((Config.Processing and Config.Processing.Joints) or {}) do
        if cfg.bud == reqItem and cfg.result == rewardItem and (tonumber(cfg.paper_amt) or 1) == paperReq then
            recipe = cfg
            break
        end
    end
    if not recipe then
        Bridge.Notify(src, "Receta inválida.", "error")
        return
    end

    local paperItem = recipe.paper or "rolling_paper"
    if Bridge.GetItemCount(src, reqItem) < 1 or Bridge.GetItemCount(src, paperItem) < paperReq then
        Bridge.Notify(src, "Te faltan materiales para liar esto.", "error")
        return
    end
    if not Bridge.CanCarryItem(src, rewardItem, 1) then
        Bridge.Notify(src, "No tienes espacio en el inventario.", "error")
        return
    end

    if Bridge.RemoveItem(src, reqItem, 1) then
        if Bridge.RemoveItem(src, paperItem, paperReq) then
            Bridge.AddItem(src, rewardItem, 1)
        else
            Bridge.AddItem(src, reqItem, 1) -- devolver el cogollo si falló el papel
        end
    end
end)
