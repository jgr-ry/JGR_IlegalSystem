-- ============================================================
-- IN-MEMORY PLANT CACHE (synced from DB)
-- ============================================================
local Plants = {} -- { [id] = { id, owner, seed_type, coords={x,y,z}, stage, water, _elapsed } }
local ScissorUses = {} -- { [identificador] = usos } — se gastan unas tijeras cada 2 cosechas

local PLANT_INTERACT_DISTANCE = 3.5 -- distancia máxima (servidor) para regar / cosechar
local PLANT_PLACE_DISTANCE = 5.0    -- distancia máxima entre el jugador y el punto donde planta

local function isPlayerNear(src, coords, maxDist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or type(coords) ~= 'table' then return false end
    return #(GetEntityCoords(ped) - vector3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)) <= maxDist
end

-- ============================================================
-- LOAD ALL PLANTS FROM DB ON START
-- ============================================================
AddEventHandler('onResourceStart', function(resName)
    if GetCurrentResourceName() ~= resName then return end

    -- Ensure table exists with correct schema
    local colCheck = MySQL.query.await([[
        SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'jgr_plants' AND COLUMN_NAME = 'owner'
    ]])

    local tableExists = MySQL.query.await([[
        SELECT count(*) as cnt FROM information_schema.tables 
        WHERE table_schema = DATABASE() AND table_name = 'jgr_plants'
    ]])

    if tableExists and tableExists[1] and tableExists[1].cnt > 0 and (not colCheck or #colCheck == 0) then
        if Config.Debug then print('^3[JGR_Drugs]^0 Dropping corrupted jgr_plants table...') end
        MySQL.query.await('DROP TABLE `jgr_plants`')
    end

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `jgr_plants` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `owner` varchar(50) NOT NULL,
            `seed_type` varchar(50) NOT NULL,
            `coords` longtext NOT NULL,
            `stage` int(11) NOT NULL DEFAULT 1,
            `water` int(11) NOT NULL DEFAULT 0,
            `planted_at` timestamp NOT NULL DEFAULT current_timestamp(),
            `last_update` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    MySQL.query('SELECT * FROM jgr_plants', {}, function(results)
        if not results then return end
        for _, row in ipairs(results) do
            local c = Bridge.Util.SafeDecode(row.coords, nil)
            if c and c.x and c.y and c.z then
            Plants[row.id] = {
                id = row.id,
                owner = row.owner,
                seed_type = row.seed_type,
                coords = c,
                stage = row.stage,
                water = row.water,
                _elapsed = 0
            }
            end
        end
        if Config.Debug then
            print(("[JGR_Drugs] Loaded %d plants from database."):format(#results))
        end
    end)
end)

-- ============================================================
-- SYNC HELPERS
-- ============================================================
local function SyncAllPlants(targetSrc)
    local data = {}
    for id, p in pairs(Plants) do
        local seedCfg = Config.Growing.Seeds[p.seed_type]
        local stageTime = (seedCfg and seedCfg.stages[p.stage]) and seedCfg.stages[p.stage].time or 0
        data[#data + 1] = {
            id = p.id, owner = p.owner, seed_type = p.seed_type,
            coords = p.coords, stage = p.stage, water = p.water,
            elapsed = p._elapsed or 0,
            stageTime = stageTime
        }
    end
    if targetSrc then
        TriggerClientEvent('JGR_Drugs:Client:SyncPlants', targetSrc, data)
    else
        TriggerClientEvent('JGR_Drugs:Client:SyncPlants', -1, data)
    end
end

local function SyncSinglePlant(plantData)
    local seedCfg = Config.Growing.Seeds[plantData.seed_type]
    local stageTime = (seedCfg and seedCfg.stages[plantData.stage]) and seedCfg.stages[plantData.stage].time or 1

    TriggerClientEvent('JGR_Drugs:Client:UpdatePlant', -1, {
        id = plantData.id,
        owner = plantData.owner,
        seed_type = plantData.seed_type,
        coords = plantData.coords,
        stage = plantData.stage,
        water = plantData.water,
        elapsed = plantData._elapsed or 0,
        stageTime = stageTime
    })
end

local function SyncRemovePlant(plantId)
    TriggerClientEvent('JGR_Drugs:Client:RemovePlant', -1, plantId)
end

RegisterNetEvent('JGR_Drugs:Server:RequestPlants', function()
    SyncAllPlants(source)
end)

-- ============================================================
-- PLANT A SEED (water starts at 0!)
-- ============================================================
RegisterNetEvent('JGR_Drugs:Server:PlantSeed', function(seedType, coords)
    local src = source
    local citizenid = Bridge.GetIdentifier(src)
    if not citizenid then return end

    if type(seedType) ~= "string" then return end
    -- Los vectores llegan por red como "vector3", no como "table"
    local ct = type(coords)
    if ct ~= "table" and ct ~= "vector3" and ct ~= "vector4" then return end
    local x = tonumber(coords.x)
    local y = tonumber(coords.y)
    local z = tonumber(coords.z)
    if not x or not y or not z then return end

    local seedCfg = Config.Growing.Seeds[seedType]
    if not seedCfg then return end

    -- No se puede plantar a distancia (antes se aceptaban coordenadas arbitrarias del cliente).
    if not isPlayerNear(src, { x = x, y = y, z = z }, PLANT_PLACE_DISTANCE) then return end

    if Bridge.GetItemCount(src, seedType) < 1 then
        Bridge.Notify(src, "No tienes esa semilla.", "error")
        return
    end

    if seedCfg.requiresPot and Bridge.GetItemCount(src, "grow_pot") < 1 then
        Bridge.Notify(src, "Necesitas una maceta para esta semilla.", "error")
        return
    end

    if not Bridge.RemoveItem(src, seedType, 1) then return end
    if seedCfg.requiresPot and not Bridge.RemoveItem(src, "grow_pot", 1) then
        Bridge.AddItem(src, seedType, 1)
        return
    end

    local coordsJson = json.encode({ x = x, y = y, z = z })

    -- Water starts at 0 — player needs to water the plant!
    MySQL.insert('INSERT INTO jgr_plants (owner, seed_type, coords, water) VALUES (?, ?, ?, 0)',
        { citizenid, seedType, coordsJson }, function(id)
            if id then
                -- Initial Growth: Random between 0 and 20% (part way through stage 1)
                local initialElapsed = 0
                if seedCfg.stages[1] and seedCfg.stages[1].time > 1 then
                    initialElapsed = math.random(0, seedCfg.stages[1].time - 1)
                end

                local plantData = {
                    id = id,
                    owner = citizenid,
                    seed_type = seedType,
                    coords = { x = x, y = y, z = z },
                    stage = 1,
                    water = 0,
                    _elapsed = initialElapsed,
                }
                Plants[id] = plantData
                SyncSinglePlant(plantData)
                Bridge.Notify(src, "Has plantado " .. seedCfg.label .. ". ¡Riégala!", "success")
            end
        end)
end)

-- ============================================================
-- WATER A PLANT (from inventory watercan)
-- ============================================================
RegisterNetEvent('JGR_Drugs:Server:WaterPlant', function(plantId)
    local src = source
    plantId = tonumber(plantId)
    if not plantId then return end
    local plant = Plants[plantId]
    if not plant then return end
    if not isPlayerNear(src, plant.coords, PLANT_INTERACT_DISTANCE) then return end

    if Bridge.GetItemCount(src, "grow_watercan") < 1 then
        Bridge.Notify(src, "Necesitas una regadera.", "error")
        return
    end

    -- Fill water to 100%
    plant.water = 100
    MySQL.update('UPDATE jgr_plants SET water = 100 WHERE id = ?', { plantId })
    SyncSinglePlant(plant)
    Bridge.Notify(src, "Planta regada al 100%. 💧", "success")
end)

-- ============================================================
-- HARVEST A PLANT (any stage — yield scales with stage)
-- ============================================================
RegisterNetEvent('JGR_Drugs:Server:HarvestPlant', function(plantId)
    local src = source
    local cid = Bridge.GetIdentifier(src)
    if not cid then return end

    plantId = tonumber(plantId)
    if not plantId then return end
    local plant = Plants[plantId]
    if not plant then return end

    -- Hay que estar junto a la planta (antes se podía cosechar cualquier planta del mapa por su ID).
    if not isPlayerNear(src, plant.coords, PLANT_INTERACT_DISTANCE) then return end

    local seedCfg = Config.Growing.Seeds[plant.seed_type]
    if not seedCfg then return end

    if Bridge.GetItemCount(src, "trimming_scissors") < 1 then
        Bridge.Notify(src, "Necesitas tijeras de podar.", "error")
        return
    end

    -- Calculate yield based on stage (1-5)
    local stagePct = plant.stage / 5
    local minYield = math.max(1, math.floor(seedCfg.harvestMin * stagePct))
    local maxYield = math.max(1, math.floor(seedCfg.harvestMax * stagePct))
    local amount = math.random(minYield, maxYield)

    if not Bridge.CanCarryItem(src, seedCfg.bud, amount) then
        Bridge.Notify(src, "No tienes espacio en el inventario.", "error")
        return
    end

    -- Se quita la planta ANTES de dar los cogollos para que no se pueda cosechar dos veces.
    Plants[plantId] = nil
    MySQL.query('DELETE FROM jgr_plants WHERE id = ?', { plantId })
    SyncRemovePlant(plantId)

    Bridge.AddItem(src, seedCfg.bud, amount)

    -- Durabilidad de las tijeras: se gasta 1 cada 2 cosechas
    ScissorUses[cid] = (ScissorUses[cid] or 0) + 1
    if ScissorUses[cid] >= 2 then
        Bridge.RemoveItem(src, "trimming_scissors", 1)
        ScissorUses[cid] = 0
    end

    Bridge.Notify(src, ("Has recogido %dx %s"):format(amount, seedCfg.label), "success")
end)

-- ============================================================
-- GROWTH LOOP (runs every 60 seconds)
-- ============================================================
CreateThread(function()
    while true do
        Wait(60000) -- Every minute

        for id, plant in pairs(Plants) do
            local seedCfg = Config.Growing.Seeds[plant.seed_type]
            if seedCfg then
                -- Decay water
                plant.water = math.max(0, plant.water - Config.Growing.WaterDecayPerMinute)

                if plant.water <= 0 and Config.Growing.DeathAtZeroWater then
                    -- La planta muere: se borra y NO se vuelve a sincronizar
                    -- (antes se reenviaba a los clientes justo después de borrarla y reaparecía).
                    MySQL.query('DELETE FROM jgr_plants WHERE id = ?', { id })
                    Plants[id] = nil
                    SyncRemovePlant(id)
                else
                    if plant.water > 0 and plant.stage < 5 then
                        local currentStageCfg = seedCfg.stages[plant.stage]
                        if currentStageCfg then
                            plant._elapsed = (plant._elapsed or 0) + 1
                            if plant._elapsed >= currentStageCfg.time then
                                plant.stage = plant.stage + 1
                                plant._elapsed = 0
                            end
                        end
                    end

                    -- Un único envío por planta y minuto (antes se enviaba dos veces al cambiar de fase)
                    SyncSinglePlant(plant)
                    MySQL.update('UPDATE jgr_plants SET stage = ?, water = ? WHERE id = ?',
                        { plant.stage, plant.water, id })
                end
            end
        end
    end
end)

-- ============================================================
-- REGISTER SEED ITEMS + WATERCAN AS USABLE
-- ============================================================
CreateThread(function()
    -- Semillas
    for seedName, _ in pairs(Config.Growing.Seeds) do
        Bridge.RegisterUsableItem(seedName, function(src)
            TriggerClientEvent('JGR_Drugs:Client:StartPlanting', src, seedName)
        end)
    end

    -- Regadera: se usa desde el inventario junto a una planta
    Bridge.RegisterUsableItem("grow_watercan", function(src)
        TriggerClientEvent('JGR_Drugs:Client:UseWatercan', src)
    end)

    if Config.Debug then
        print("[JGR_Drugs] Registered seed + watercan usable items.")
    end
end)
