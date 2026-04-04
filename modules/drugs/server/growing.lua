local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================================
-- IN-MEMORY PLANT CACHE (synced from DB)
-- ============================================================
local Plants = {} -- { [id] = { id, owner, seed_type, coords={x,y,z}, stage, water, _elapsed } }
local ScissorUses = {} -- { [citizenid] = usageCount } — resets every 2 harvests

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
            local c = json.decode(row.coords)
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
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local seedCfg = Config.Growing.Seeds[seedType]
    if not seedCfg then return end

    local hasSeed = Player.Functions.GetItemByName(seedType)
    if not hasSeed or hasSeed.amount < 1 then
        TriggerClientEvent('QBCore:Notify', src, "No tienes esa semilla.", "error")
        return
    end

    if seedCfg.requiresPot then
        local hasPot = Player.Functions.GetItemByName("grow_pot")
        if not hasPot or hasPot.amount < 1 then
            TriggerClientEvent('QBCore:Notify', src, "Necesitas una maceta para esta semilla.", "error")
            return
        end
        Player.Functions.RemoveItem("grow_pot", 1)
    end

    Player.Functions.RemoveItem(seedType, 1)

    local citizenid = Player.PlayerData.citizenid
    local coordsJson = json.encode({ x = coords.x, y = coords.y, z = coords.z })

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
                    coords = { x = coords.x, y = coords.y, z = coords.z },
                    stage = 1,
                    water = 0,
                    _elapsed = initialElapsed,
                }
                Plants[id] = plantData
                SyncSinglePlant(plantData)
                TriggerClientEvent('QBCore:Notify', src, "Has plantado " .. seedCfg.label .. ". ¡Riégala!", "success")
            end
        end)
end)

-- ============================================================
-- WATER A PLANT (from inventory watercan)
-- ============================================================
RegisterNetEvent('JGR_Drugs:Server:WaterPlant', function(plantId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local plant = Plants[plantId]
    if not plant then return end

    local hasWater = Player.Functions.GetItemByName("grow_watercan")
    if not hasWater or hasWater.amount < 1 then
        TriggerClientEvent('QBCore:Notify', src, "Necesitas una regadera.", "error")
        return
    end

    -- Fill water to 100%
    plant.water = 100
    MySQL.update('UPDATE jgr_plants SET water = 100 WHERE id = ?', { plantId })
    SyncSinglePlant(plant)
    TriggerClientEvent('QBCore:Notify', src, "Planta regada al 100%. 💧", "success")
end)

-- ============================================================
-- HARVEST A PLANT (any stage — yield scales with stage)
-- ============================================================
RegisterNetEvent('JGR_Drugs:Server:HarvestPlant', function(plantId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local plant = Plants[plantId]
    if not plant then return end

    local seedCfg = Config.Growing.Seeds[plant.seed_type]
    if not seedCfg then return end

    -- Must have trimming scissors
    local hasScissors = Player.Functions.GetItemByName("trimming_scissors")
    if not hasScissors or hasScissors.amount < 1 then
        TriggerClientEvent('QBCore:Notify', src, "Necesitas tijeras de podar.", "error")
        return
    end

    -- Calculate yield based on stage (1-5)
    local stagePct = plant.stage / 5
    local minYield = math.max(1, math.floor(seedCfg.harvestMin * stagePct))
    local maxYield = math.max(1, math.floor(seedCfg.harvestMax * stagePct))
    local amount = math.random(minYield, maxYield)

    Player.Functions.AddItem(seedCfg.bud, amount)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[seedCfg.bud], "add")

    -- Scissors durability: consume 1 every 2 harvests
    local cid = Player.PlayerData.citizenid
    ScissorUses[cid] = (ScissorUses[cid] or 0) + 1
    if ScissorUses[cid] >= 2 then
        Player.Functions.RemoveItem("trimming_scissors", 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items["trimming_scissors"], "remove")
        ScissorUses[cid] = 0
    end

    -- Remove from DB and memory
    MySQL.query('DELETE FROM jgr_plants WHERE id = ?', { plantId })
    Plants[plantId] = nil
    SyncRemovePlant(plantId)

    TriggerClientEvent('QBCore:Notify', src, ("Has recogido %dx %s"):format(amount, seedCfg.label), "success")
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

                -- Check if plant should die
                if plant.water <= 0 and Config.Growing.DeathAtZeroWater then
                    MySQL.query('DELETE FROM jgr_plants WHERE id = ?', { id })
                    Plants[id] = nil
                    SyncRemovePlant(id)
                elseif plant.water > 0 and plant.stage < 5 then
                    -- Try to advance stage
                    local currentStageCfg = seedCfg.stages[plant.stage]
                    if currentStageCfg then
                        plant._elapsed = (plant._elapsed or 0) + 1
                        if plant._elapsed >= currentStageCfg.time then
                            plant.stage = plant.stage + 1
                            plant._elapsed = 0
                            SyncSinglePlant(plant)
                        end
                    end
                end

                -- Sync water updates to clients every tick
                SyncSinglePlant(plant)

                -- Update DB periodically
                MySQL.update('UPDATE jgr_plants SET stage = ?, water = ? WHERE id = ?',
                    { plant.stage, plant.water, id })
            end
        end
    end
end)

-- ============================================================
-- REGISTER SEED ITEMS + WATERCAN AS USABLE
-- ============================================================
CreateThread(function()
    if Config.Framework ~= "qbcore" then return end

    -- Seeds
    for seedName, _ in pairs(Config.Growing.Seeds) do
        QBCore.Functions.CreateUseableItem(seedName, function(source, item)
            TriggerClientEvent('JGR_Drugs:Client:StartPlanting', source, item.name)
        end)
    end

    -- Watercan — use from inventory to water nearby plant
    QBCore.Functions.CreateUseableItem("grow_watercan", function(source, item)
        TriggerClientEvent('JGR_Drugs:Client:UseWatercan', source)
    end)

    if Config.Debug then
        print("[JGR_Drugs] Registered seed + watercan usable items.")
    end
end)
