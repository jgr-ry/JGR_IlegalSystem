# JGR_IlegalSystem

Sistema ilegal modular para FiveM: **bandas** con panel propio, **cultivo de marihuana**, **procesado** (porros y bolsitas) y un **Grow Shop** con compras mayoristas, repartos, crafteo y gestión de empleados.

`Versión 1.1.0` · `QBCore · Qbox · ESX · Standalone (ox_core)` · `ox_lib` · `oxmysql`

---

## Características

### Bandas
- **Creación guiada** (`/creategang`) con interfaz NUI: nombre, color, rangos con permisos, colocación del NPC de la sede en 3D (modelo, rotación) y especialización (hierba, cocaína, metanfetamina, armas).
- La creación requiere un **permiso de un solo uso** que da un administrador con `/givegang`.
- **NPC de sede** por banda: los miembros hablan con él (`E`) para abrir el panel.
- **Panel de banda** (NUI): resumen, miembros con nombre y teléfono, rangos y permisos, documentos compartidos, territorios en mapa táctico, zona de control y puntos de la banda.
- **Rangos con permisos**: gestionar miembros, puntos, rangos, documentos y territorios. El jefe siempre lo puede todo.
- **Puntos en el mundo** colocados con la mira: almacén, panel de gestión, menú de garaje, aparición y guardado de vehículos.
- **Almacén de banda** (ox_inventory o qb-inventory).
- **Garaje de banda**: guarda los vehículos con sus propiedades (límite configurable) y sácalos desde un menú de ox_lib o un panel NUI.
- **Límite de miembros** por banda (configurable por admin).
- **Panel de administración** (`/ilegalpanel`): lista de bandas, miembros/límite, editar límite y borrar bandas.

### Cultivo (drogas)
- 4 semillas configurables (Standard, CBD, Kush, Amnesia) con fases, props por fase y rendimiento.
- Plantar solo en **suelos válidos** (hierba, tierra, barro…); la CBD necesita **maceta** y se puede plantar en cualquier sitio.
- **Agua**: la planta empieza a 0 %, se riega con la regadera y pierde agua cada minuto (opcionalmente muere al llegar a 0).
- **HUD** de la planta al acercarse (fase, agua, progreso) y cosecha con **tijeras de podar** (se gastan cada 2 cosechas).
- Plantas **persistentes** en base de datos y sincronizadas con todos los jugadores.

### Procesado
- **Liar porros** usando el papel de liar (`rolling_paper`) según las recetas de `Config.Processing.Joints`.
- **Mesa de empaquetado** (coordenada configurable) para convertir cogollos en bolsitas.

### Grow Shop
- Negocio con blip, **panel de administración** y **almacén** para el trabajo `growshop`.
- **Compras mayoristas** con los fondos de la sociedad: pedidos pequeños (<6 uds.) los trae un repartidor al almacén en 3-5 min; los grandes hay que recogerlos con la furgoneta en un punto del GPS.
- **El Cocinero**: craftea comestibles y porros a partir de tus materiales.
- **Fondos de la sociedad**: ingresar y retirar dinero (cuenta bancaria).
- **Empleados**: contratar al jugador más cercano y despedir (conectados o no).
- **Garaje de empresa** con furgoneta persistente (guarda el daño).
- **Consumibles** con animación, vida/chaleco y efectos visuales.

---

## Requisitos

**Obligatorios**
- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)
- OneSync activado (el servidor comprueba distancias y vehículos).
- MariaDB 10.2+ o MySQL 8.0.13+ (las tablas usan `longtext` con valor por defecto).

**Framework** (uno, o ninguno): QBCore, Qbox, ESX Legacy, ox_core o standalone.

**Opcionales**
| Recurso | Para qué |
|---|---|
| `ox_inventory` | Recomendado. Obligatorio en Qbox y en standalone/ox_core (items, dinero y almacenes). |
| `qb-inventory` (o compatibles) | Items y almacenes en QBCore si no usas ox_inventory. |
| `ox_target` / `qb-target` | Interacciones del Grow Shop, mesa de procesado y punto de recogida. Sin target se usa la tecla **E**. |
| `qb-vehiclekeys` | Llaves de la furgoneta y de los vehículos del garaje de banda. |
| `ox_fuel` / `LegacyFuel` / `cdn-fuel` | Combustible lleno al sacar la furgoneta. |

---

## Instalación

1. Descarga el recurso y coloca la carpeta con el nombre exacto **`JGR_IlegalSystem`** (si se renombra, el recurso se detiene y avisa en consola).
2. **Base de datos**: las tablas se crean solas al arrancar (`jgr_ilegalsystem.sql`). Si lo prefieres, impórtalo a mano.
3. **Items**: añádelos a tu inventario (lista abajo). Las imágenes están en `ui/assets/items/`.
4. **Trabajo** `growshop` (si usas el Grow Shop) con al menos los grados cuyo nombre o número esté en `Config.GrowShop.ManagementRanks` (por defecto `jefe` y `encargado`).
5. En `server.cfg`, después del framework y sus dependencias:
   ```cfg
   ensure ox_lib
   ensure oxmysql
   ensure qb-core        # o qbx_core / es_extended / ox_core (opcional)
   ensure ox_inventory   # si lo usas
   ensure ox_target      # si lo usas
   ensure JGR_IlegalSystem
   ```

### Items

| Grupo | Items |
|---|---|
| Semillas (usables) | `seed_weed_standard`, `seed_weed_cbd`, `seed_weed_kush`, `seed_weed_amnesia` |
| Cultivo | `grow_watercan` (usable), `grow_pot`, `grow_fertilizer`, `grow_uv_light`, `trimming_scissors` |
| Cogollos | `bud_standard`, `bud_cbd`, `bud_kush`, `bud_amnesia` |
| Procesado | `rolling_paper` (usable), `empty_baggies`, `digital_scale`, `bag_standard`, `bag_cbd`, `bag_kush`, `bag_amnesia` |
| Consumibles (usables) | `joint_weed`, `joint_cbd`, `joint_kush`, `blunt_amnesia`, `weed_cookie`, `weed_brownie`, `thc_gummies` |
| Ingredientes Cocinero | `package_gelato`, `package_gorilla` |

**ox_inventory** (`ox_inventory/data/items.lua`), ejemplo:
```lua
['joint_weed'] = { label = 'Porro Standard', weight = 10, stack = true, close = true },
['seed_weed_standard'] = { label = 'Semilla Standard', weight = 5, stack = true, close = true },
```
Con QBCore, Qbox o ESX los items usables se registran solos a través del framework.

**Solo en standalone / ox_core** (sin framework de jugadores), los items usables necesitan la exportación del recurso:
```lua
['joint_weed'] = {
    label = 'Porro Standard', weight = 10, stack = true, close = true,
    server = { export = 'JGR_IlegalSystem.joint_weed' }
},
```
(igual para cada semilla, `grow_watercan`, `rolling_paper` y los consumibles: `export = 'JGR_IlegalSystem.<nombre_item>'`).

---

## Configuración (`config/config.lua`)

| Opción | Descripción |
|---|---|
| `Config.Framework` | `"auto"` (recomendado), `"qb"`, `"qbx"`, `"esx"` o `"standalone"`. Se acepta el valor antiguo `"qbcore"`. |
| `Config.Locale` | Idioma (`config/locales/es.lua`). |
| `Config.Debug` | Mensajes en consola y comandos de prueba `/testnpc`, `/tpnpc`. Desactivado por defecto. |
| `Config.GangInventory` | `"auto"`, `"ox_inventory"` o `"qb-inventory"` para el almacén de banda. |
| `Config.GangGarageMaxVehicles` | Vehículos máximos en el garaje de banda. |
| `Config.GangGarageMenuMode` | `"ox_lib"` (menú contextual) o `"nui"` (panel HTML). |
| `Config.GangSystem` | Modelos de NPC, máximo de rangos, permisos y especializaciones. Opcionales: `MaxDocuments` (100) y `MaxTerritories` (50). |
| `Config.GrowShop` | Activar, ubicación, blip, trabajo, grados de gestión, garaje, puntos de recogida, almacén, catálogo mayorista y recetas del Cocinero. |
| `Config.Growing` | Pérdida de agua, muerte sin agua, suelos permitidos y semillas (fases, props, rendimiento, maceta). |
| `Config.Processing` | Mesa de empaquetado, recetas de porros y de bolsitas. |

---

## Compatibilidad con frameworks

El framework se detecta solo en este orden: `qbx_core` → `qb-core` → `es_extended` → `ox_core` → standalone. Se puede forzar con `Config.Framework`.

| Función | QBCore | Qbox | ESX Legacy | Standalone / ox_core |
|---|---|---|---|---|
| Identificador guardado | `citizenid` | `citizenid` | `identifier` | `license` |
| Bandas, panel, rangos, documentos, territorios | ✅ | ✅ | ✅ | ✅ |
| Nombres de miembros | `charinfo` | `charinfo` | `users.firstname/lastname` | Nombre de FiveM (solo conectados) |
| Admin | `HasPermission admin/god` | ACE `group.admin` | grupo `admin`/`superadmin` | ACE `command` |
| Items | qb-inventory u ox_inventory | ox_inventory | inventario ESX u ox_inventory | ox_inventory |
| Almacén banda / Grow Shop | ✅ | ✅ (ox) | ✅ solo con ox_inventory | ✅ (ox) |
| Fondos (ingresar/retirar) | cuenta `bank` | cuenta `bank` | cuenta `bank` | item `money` de ox_inventory |
| Grow Shop: quién trabaja | trabajo `growshop` | trabajo `growshop` | trabajo `growshop` | ACE (ver abajo) |
| Contratar / despedir | ✅ | ✅ (despedir desconectado vía `RemovePlayerFromJob`) | ✅ | ❌ (se usan ACE) |

En **todos** los frameworks, el ACE `jgr_ilegalsystem.admin` da acceso de administrador.

**Grow Shop en standalone / ox_core** (no hay trabajos):
```cfg
add_ace identifier.license:XXXXXXXX jgr_ilegalsystem.growshop allow       # empleado
add_ace identifier.license:XXXXXXXX jgr_ilegalsystem.growshop.boss allow  # gestor
```

> **Nota ESX**: la columna `citizenid` de `jgr_gang_members` guarda el `identifier` de ESX (y la `license` en standalone). No hay que renombrarla.

---

## Comandos

| Comando | Quién | Descripción |
|---|---|---|
| `/givegang [id]` | Admin | Da permiso de un solo uso para crear una banda. |
| `/creategang` | Jugador con permiso | Abre el asistente de creación. |
| `/setgang [id] [banda] [rango]` | Admin | Mete a un jugador en una banda (`0` = jefe, `1` = siguiente rango…). Si estaba en otra, se le cambia. |
| `/setgangmember [banda] [cantidad]` | Admin | Cambia el máximo de miembros. |
| `/ilegalpanel` | Admin | Panel de administración de bandas. |
| `/testnpc`, `/tpnpc` | Solo con `Config.Debug` | Pruebas del NPC repartidor. |

Los comandos de admin también funcionan desde la consola del servidor.

## Eventos y funciones públicas

- `RemoveSocietyFunds(jobName, amount)` (servidor, global): descuenta fondos de `jgr_societies` de forma atómica; devuelve `true` si había saldo.
- `JGR_IlegalSystem:client:RefreshNPCs` (cliente): recarga los NPC de las bandas.

---

## Actualizaciones

Al arrancar, el recurso consulta el `versions.json` común de JGR y avisa en la consola del servidor si hay una versión nueva (con el enlace de descarga). Para desactivar el aviso, en `server.cfg`:
```cfg
set jgr_versioncheck 0
```

---

## Changelog

### 1.1.0
**Compatibilidad**
- Nuevo bridge (`bridge/bridge.lua`, `bridge/client.lua`, `bridge/server.lua`) con detección automática de **QBCore, Qbox, ESX Legacy y standalone/ox_core**. Ningún archivo llama ya a `qb-core` directamente.
- `Config.Framework = "auto"` por defecto (se sigue aceptando `"qbcore"`).
- Callbacks unificados con `lib.callback` de ox_lib (antes el modo standalone no funcionaba y Qbox no estaba soportado).
- Inventario: ox_inventory, qb-inventory y ESX. Almacenes con ox_inventory, qb-inventory v2 y el evento clásico.
- Interacciones con ox_target, qb-target o tecla E (antes solo qb-target).
- Fondos y trabajos del Grow Shop para ESX; ACE para standalone.

**Seguridad**
- `AdminEditGang` y `AdminDeleteGang` no comprobaban permisos: **cualquier jugador podía borrar bandas** o cambiar su límite.
- En standalone, `/givegang`, `/setgang`, `/setgangmember` y `/ilegalpanel` daban acceso de admin a **todo el mundo**; ahora se usa ACE.
- Cosechar, regar y plantar exigían solo el ID de la planta: se podía cosechar **cualquier planta del mapa a distancia**. Ahora hay comprobación de distancia en el servidor.
- Garaje de banda: el cliente podía "guardar" un vehículo inventado y sacarlo después. Ahora el servidor comprueba el vehículo real (conductor, modelo, matrícula) y lo borra él mismo.
- Grow Shop: se podía despedir a jugadores de **cualquier trabajo**; cantidades con decimales en el carrito/crafteo; recoger el pedido grande desde cualquier sitio; completar el reparto antes de tiempo; ver/crear fondos de cualquier sociedad; pedir la lista de empleados en nombre de otro jugador.
- Fondos: cobros y retiradas atómicos (sin carreras) y se corrige `ON DUPLICATE KEY UPDATE funds = 0`, que podía poner los fondos a 0.
- Bandas: cualquiera podía leer los datos internos (documentos, miembros) de otra banda; un miembro con "gestionar miembros" podía ascenderse a jefe; no se respetaba el máximo de miembros; se podía estar en dos bandas.
- Validación de todos los datos que llegan del cliente (nombres, colores, modelos de NPC, rangos, documentos, territorios) y escape de HTML en la NUI.

**Errores corregidos**
- Plantar no funcionaba: el servidor rechazaba las coordenadas porque llegan como `vector3`, no como tabla.
- `rolling_paper` se registraba dos veces y la función global `RollJoint` estaba duplicada (una pisaba a la otra).
- Las plantas muertas por falta de agua volvían a aparecer en los clientes.
- Segundo pedido o crafteo sobrescribía el anterior y se perdían materiales.
- Consultas con la columna `rank` sin comillas (palabra reservada en MySQL 8).
- La lista de miembros nunca respondía si el framework no era QBCore/ESX.
- El garaje de empresa borraba cualquier vehículo, no solo la furgoneta.
- NPC repartidor/Cocinero: bucles sin límite si el NPC se atascaba.
- Varias funciones globales pasan a ser locales; el texto de ayuda de distintos bucles ya no se pisa.

**Otros**
- Nuevo comprobador de versiones común (`server/version_check.lua`).
- `Config.Debug = false` por defecto.
- README reescrito.

### 1.0.0
- Versión inicial: bandas, cultivo, procesado y Grow Shop (QBCore/ESX parcial).

---

## Soporte y créditos

Autor: **JGR** · GitHub: [jgr-ry](https://github.com/jgr-ry)

Abre una *issue* en [jgr-ry/JGR_IlegalSystem](https://github.com/jgr-ry/JGR_IlegalSystem) para dudas o errores.
