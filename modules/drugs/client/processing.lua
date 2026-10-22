-- Cliente: liar porros y mesa de empaquetado

local RollJoint, ProcessBaggie

-- ============================================================
-- ROLLING JOINTS SYSTEM (Papel de liar)
-- ============================================================
--- Cantidades (consultadas al servidor) de los items usados en una lista de recetas.
local function countItems(recipes, keys)
    local names, seen = {}, {}
    for _, cfg in ipairs(recipes) do
        for _, k in ipairs(keys) do
            local n = cfg[k]
            if n and not seen[n] then seen[n] = true names[#names + 1] = n end
        end
    end
    return Bridge.GetItemCounts(names)
end

RegisterNetEvent('JGR_Drugs:Client:RollJointMenu', function()
    -- Qué cogollos tiene el jugador
    local hasBuds = countItems(Config.Processing.Joints, { "bud", "paper" })

    local options = {}

    for i, jointCfg in ipairs(Config.Processing.Joints) do
        -- Only show options if the player has the required bud
        if hasBuds[jointCfg.bud] and hasBuds[jointCfg.bud] >= 1 then
            options[#options + 1] = {
                title = "Liar " .. jointCfg.label,
                description = "Requiere: 1x " .. Bridge.GetItemLabel(jointCfg.bud) .. " y " .. jointCfg.paper_amt .. "x " .. Bridge.GetItemLabel(jointCfg.paper),
                icon = 'cannabis',
                onSelect = function()
                    RollJoint(i, jointCfg)
                end
            }
        end
    end

    if #options == 0 then
        Bridge.Notify(PlayerId(), "No tienes cogollos para liar.", "error")
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
        Bridge.Notify(PlayerId(), "Cancelado.", "error")
    end
end

-- ============================================================
-- DRUG BAGGING SYSTEM (Mesa de procesado)
-- ============================================================

CreateThread(function()
    Wait(1000)
    -- Zona de la mesa de procesado (ox_target, qb-target o tecla E)
    Bridge.AddBoxZone("jgr_drug_processing_table", Config.Processing.BaggieLocation.xyz, 1.5, Config.Processing.BaggieLocation.w, {
        {
            label = "Procesar Cogollos",
            icon = "fas fa-box",
            onSelect = function() TriggerEvent("JGR_Drugs:Client:BaggingMenu") end,
        },
    }, Config.Processing.BaggieTargetDistance)
end)

-- Solo lo dispara la zona de este mismo recurso (evento local, no de red)
AddEventHandler('JGR_Drugs:Client:BaggingMenu', function()
    local hasBuds = countItems(Config.Processing.Baggies, { "bud", "baggie" })
    local hasBaggies = hasBuds["empty_baggies"] or 0

    if hasBaggies < 1 then
        Bridge.Notify(PlayerId(), "Necesitas bolsitas vacías (empty_baggies).", "error")
        return
    end

    local options = {}

    for i, bagCfg in ipairs(Config.Processing.Baggies) do
        -- Only show options if the player has the required bud
        if hasBuds[bagCfg.bud] and hasBuds[bagCfg.bud] >= bagCfg.bud_amt then
            options[#options + 1] = {
                title = "Empaquetar " .. bagCfg.label,
                description = "Requiere: " .. bagCfg.bud_amt .. "x " .. Bridge.GetItemLabel(bagCfg.bud) .. " y 1x Bolsita Vacía",
                icon = 'box-open',
                onSelect = function()
                    ProcessBaggie(i, bagCfg)
                end
            }
        end
    end

    if #options == 0 then
        Bridge.Notify(PlayerId(), "No tienes cogollos suficientes para procesar.", "error")
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
        Bridge.Notify(PlayerId(), "Cancelado.", "error")
    end
end
