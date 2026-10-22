-- Servidor: liar porros (papel de liar) y empaquetar cogollos en bolsitas

-- ============================================================
-- LIAR PORROS (Papel de liar)
-- ============================================================
CreateThread(function()
    Bridge.RegisterUsableItem("rolling_paper", function(src)
        TriggerClientEvent('JGR_Drugs:Client:RollJointMenu', src)
    end)
end)

--- Quita los ingredientes y entrega el resultado; si algo falla, devuelve lo quitado.
local function craft(src, inputs, result, resultAmount)
    for _, input in ipairs(inputs) do
        if Bridge.GetItemCount(src, input.item) < input.amount then return false, 'missing' end
    end
    if not Bridge.CanCarryItem(src, result, resultAmount) then return false, 'full' end

    local removed = {}
    for _, input in ipairs(inputs) do
        if not Bridge.RemoveItem(src, input.item, input.amount) then
            for _, r in ipairs(removed) do Bridge.AddItem(src, r.item, r.amount) end
            return false, 'missing'
        end
        removed[#removed + 1] = input
    end
    Bridge.AddItem(src, result, resultAmount)
    return true
end

RegisterNetEvent('JGR_Drugs:Server:RollJoint', function(index)
    local src = source
    index = Bridge.Util.ToInt(index, 1)
    local cfg = index and Config.Processing.Joints[index]
    if not cfg then return end

    local ok, reason = craft(src, {
        { item = cfg.bud, amount = 1 },
        { item = cfg.paper, amount = tonumber(cfg.paper_amt) or 1 },
    }, cfg.result, 1)

    if ok then
        Bridge.Notify(src, "Has liado un " .. cfg.label, "success")
    elseif reason == 'full' then
        Bridge.Notify(src, "No tienes espacio en el inventario.", "error")
    else
        Bridge.Notify(src, "No tienes suficientes cogollos o papel de liar.", "error")
    end
end)

-- ============================================================
-- EMPAQUETAR COGOLLOS (Mesa de procesado)
-- ============================================================
RegisterNetEvent('JGR_Drugs:Server:ProcessBaggie', function(index)
    local src = source
    index = Bridge.Util.ToInt(index, 1)
    local cfg = index and Config.Processing.Baggies[index]
    if not cfg then return end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local dist = #(GetEntityCoords(ped) - Config.Processing.BaggieLocation.xyz)
    if dist > (Config.Processing.BaggieTargetDistance + 2.0) then
        -- Demasiado lejos de la mesa: petición ignorada
        return
    end

    local ok, reason = craft(src, {
        { item = cfg.bud, amount = tonumber(cfg.bud_amt) or 1 },
        { item = cfg.baggie, amount = 1 },
    }, cfg.result, 1)

    if ok then
        Bridge.Notify(src, "Has procesado 1x " .. cfg.label, "success")
    elseif reason == 'full' then
        Bridge.Notify(src, "No tienes espacio en el inventario.", "error")
    else
        Bridge.Notify(src, "No tienes suficientes cogollos o bolsitas vacías.", "error")
    end
end)
