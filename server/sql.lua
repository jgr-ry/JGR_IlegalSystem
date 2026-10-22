-- Importa/actualiza automáticamente las tablas SQL al arrancar el recurso

if GetCurrentResourceName() ~= 'JGR_IlegalSystem' then
    print(('^1[JGR]^0 Renombra la carpeta del recurso a ^3JGR_IlegalSystem^0 (actual: ^1%s^0).'):format(GetCurrentResourceName()))
    StopResource(GetCurrentResourceName())
    return
end

local function columnExists(tableName, columnName)
    local rows = MySQL.query.await([[
        SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?
    ]], { tableName, columnName })
    return rows ~= nil and #rows > 0
end

local function tableExists(tableName)
    local count = MySQL.scalar.await([[
        SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = DATABASE() AND table_name = ?
    ]], { tableName })
    return (tonumber(count) or 0) > 0
end

-- Columnas añadidas en versiones posteriores (para bases de datos antiguas)
local UPGRADES = {
    { 'max_members', 'ALTER TABLE `jgr_gangs` ADD COLUMN `max_members` int(11) NOT NULL DEFAULT 10 AFTER `specialization`' },
    { 'npc_name', "ALTER TABLE `jgr_gangs` ADD COLUMN `npc_name` varchar(50) NOT NULL DEFAULT 'Desconocido' AFTER `npc_model`" },
    { 'level', 'ALTER TABLE `jgr_gangs` ADD COLUMN `level` int(11) NOT NULL DEFAULT 0' },
    { 'xp', 'ALTER TABLE `jgr_gangs` ADD COLUMN `xp` int(11) NOT NULL DEFAULT 0' },
    { 'stats', "ALTER TABLE `jgr_gangs` ADD COLUMN `stats` longtext NOT NULL DEFAULT '{}'" },
}

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    if Config.Debug then print('^4[JGR_IlegalSystem]^0 Comprobando tablas de la base de datos...') end
    local sqlFile = LoadResourceFile(resourceName, "jgr_ilegalsystem.sql")
    if not sqlFile then
        print('^1[JGR_IlegalSystem]^0 ERROR: no se encontró jgr_ilegalsystem.sql dentro del recurso.')
        return
    end

    for query in string.gmatch(sqlFile, "([^;]+);") do
        if query:match("%S") then
            MySQL.query.await(query)
        end
    end

    for _, upgrade in ipairs(UPGRADES) do
        if not columnExists('jgr_gangs', upgrade[1]) then
            if Config.Debug then print(('^3[JGR_IlegalSystem]^0 Actualizando base de datos: añadiendo `%s` a `jgr_gangs`'):format(upgrade[1])) end
            MySQL.query.await(upgrade[2])
        end
    end

    -- jgr_societies y jgr_plants están en el .sql (CREATE TABLE IF NOT EXISTS); se comprueba por si acaso.
    if not tableExists('jgr_societies') or not tableExists('jgr_plants') then
        print('^1[JGR_IlegalSystem]^0 Faltan tablas (jgr_societies / jgr_plants). Importa jgr_ilegalsystem.sql manualmente.')
    end

    if Config.Debug then print('^2[JGR_IlegalSystem]^0 Base de datos importada/verificada correctamente.') end
end)
