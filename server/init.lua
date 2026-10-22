-- Comprobación del nombre del recurso. La misma regla está en server/sql.lua y server/main.lua (no quitar).
-- El aviso de actualizaciones ahora está en server/version_check.lua (común a todos los scripts JGR).
local EXPECTED_RESOURCE_NAME = 'JGR_IlegalSystem'

do
    local n = GetCurrentResourceName()
    if n ~= EXPECTED_RESOURCE_NAME then
        print(('^1[%s]^0 ^1Renombra la carpeta del recurso a^0 ^3%s^0 (nombre oficial).^0'):format(n, EXPECTED_RESOURCE_NAME))
        StopResource(n)
        return
    end
end
