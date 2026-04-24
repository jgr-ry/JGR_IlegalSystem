-- Auto-import SQL script on server start

if GetCurrentResourceName() ~= 'JGR_IlegalSystem' then
    print(('^1[JGR]^0 Renombra la carpeta del recurso a ^3JGR_IlegalSystem^0 (actual: ^1%s^0).'):format(GetCurrentResourceName()))
    StopResource(GetCurrentResourceName())
    return
end

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end

    if Config.Debug then print('^4[JGR_IlegalSystem]^0 Checking Database Tables...') end
    local sqlFile = LoadResourceFile(resourceName, "jgr_ilegalsystem.sql")
    
    if sqlFile then
        local queries = {}
        for query in string.gmatch(sqlFile, "([^;]+);") do
            if query:match("%S") then
                table.insert(queries, query)
            end
        end
        
        for _, q in ipairs(queries) do
            MySQL.query.await(q)
        end
        
        -- Fallback: Ensure max_members exists if they didn't wipe their old DB
        MySQL.query([[
            SELECT COLUMN_NAME 
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'jgr_gangs' AND COLUMN_NAME = 'max_members'
        ]], {}, function(result)
            if not result or #result == 0 then
                if Config.Debug then print('^3[JGR_IlegalSystem]^0 Upgrading database: Adding `max_members` to `jgr_gangs`') end
                MySQL.query.await('ALTER TABLE `jgr_gangs` ADD COLUMN `max_members` int(11) NOT NULL DEFAULT 10 AFTER `specialization`')
            end
        end)

        -- Fallback: Ensure npc_name exists
        MySQL.query([[
            SELECT COLUMN_NAME 
            FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'jgr_gangs' AND COLUMN_NAME = 'npc_name'
        ]], {}, function(result)
            if not result or #result == 0 then
                if Config.Debug then print('^3[JGR_IlegalSystem]^0 Upgrading database: Adding `npc_name` to `jgr_gangs`') end
                MySQL.query.await('ALTER TABLE `jgr_gangs` ADD COLUMN `npc_name` varchar(50) NOT NULL DEFAULT "Desconocido" AFTER `npc_model`')
            end
        end)

        -- Fallback: Ensure jgr_societies exists
        MySQL.query([[
            SELECT count(*) as tableExists 
            FROM information_schema.tables 
            WHERE table_schema = DATABASE() AND table_name = 'jgr_societies'
        ]], {}, function(result)
            if not result or result[1].tableExists == 0 then
                if Config.Debug then print('^3[JGR_IlegalSystem]^0 Upgrading database: Creating `jgr_societies` table') end
                MySQL.query.await([[
                    CREATE TABLE IF NOT EXISTS `jgr_societies` (
                        `id` int(11) NOT NULL AUTO_INCREMENT,
                        `job_name` varchar(50) NOT NULL,
                        `funds` int(11) NOT NULL DEFAULT 0,
                        PRIMARY KEY (`id`),
                        UNIQUE KEY `job_name` (`job_name`)
                    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                ]])
            end
        end)

        -- Fallback: Ensure jgr_plants exists (Phase 4: Growing System)
        MySQL.query([[
            SELECT count(*) as tableExists 
            FROM information_schema.tables 
            WHERE table_schema = DATABASE() AND table_name = 'jgr_plants'
        ]], {}, function(result)
            if not result or result[1].tableExists == 0 then
                if Config.Debug then print('^3[JGR_IlegalSystem]^0 Upgrading database: Creating `jgr_plants` table') end
                MySQL.query.await([[
                    CREATE TABLE IF NOT EXISTS `jgr_plants` (
                        `id` int(11) NOT NULL AUTO_INCREMENT,
                        `owner` varchar(50) NOT NULL,
                        `seed_type` varchar(50) NOT NULL,
                        `coords` longtext NOT NULL,
                        `stage` int(11) NOT NULL DEFAULT 1,
                        `water` int(11) NOT NULL DEFAULT 100,
                        `planted_at` timestamp NOT NULL DEFAULT current_timestamp(),
                        `last_update` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                        PRIMARY KEY (`id`)
                    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                ]])
            end
        end)

        -- Fallback: Ensure level column exists
        local levelCheck = MySQL.query.await([[
            SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'jgr_gangs' AND COLUMN_NAME = 'level'
        ]])
        if not levelCheck or #levelCheck == 0 then
            if Config.Debug then print('^3[JGR_IlegalSystem]^0 Upgrading database: Adding `level` to `jgr_gangs`') end
            MySQL.query.await("ALTER TABLE `jgr_gangs` ADD COLUMN `level` int(11) NOT NULL DEFAULT 0")
        end

        -- Fallback: Ensure xp column exists
        local xpCheck = MySQL.query.await([[
            SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'jgr_gangs' AND COLUMN_NAME = 'xp'
        ]])
        if not xpCheck or #xpCheck == 0 then
            if Config.Debug then print('^3[JGR_IlegalSystem]^0 Upgrading database: Adding `xp` to `jgr_gangs`') end
            MySQL.query.await("ALTER TABLE `jgr_gangs` ADD COLUMN `xp` int(11) NOT NULL DEFAULT 0")
        end

        -- Fallback: Ensure stats column exists (Phase 6: Gang Management)
        local statsCheck = MySQL.query.await([[
            SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS 
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'jgr_gangs' AND COLUMN_NAME = 'stats'
        ]])
        if not statsCheck or #statsCheck == 0 then
            if Config.Debug then print('^3[JGR_IlegalSystem]^0 Upgrading database: Adding `stats` to `jgr_gangs`') end
            MySQL.query.await("ALTER TABLE `jgr_gangs` ADD COLUMN `stats` longtext NOT NULL DEFAULT '{}'")
        end

        if Config.Debug then print('^2[JGR_IlegalSystem]^0 Database imported/verified successfully.') end
    else
        if Config.Debug then print('^1[JGR_IlegalSystem]^0 ERROR: jgr_ilegalsystem.sql not found! Please check fxmanifest.lua or file exists.') end
    end
end)
