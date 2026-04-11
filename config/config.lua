Config = Config or {}

-- Framework Settings
Config.Framework = "qbcore" -- "qbcore", "esx", or "standalone"

-- General Settings
Config.Locale = "es" -- Language
Config.Debug = true  -- Enable debug commands (/testnpc, /tpnpc) and console prints

--- Inventario de almacén de banda: "ox_inventory" (recomendado) o "qb-inventory"
Config.GangInventory = "ox_inventory"
--- Máximo de vehículos guardados por banda (garaje)
Config.GangGarageMaxVehicles = 8
--- Garaje en mundo: "ox_lib" = menú contextual (recomendado, evita NUI fantasma) | "nui" = panel HTML
Config.GangGarageMenuMode = "ox_lib"

-- Gang System Configuration
Config.GangSystem = {
    CreatorModels = {
        "g_m_y_famca_01",
        "g_m_y_ballaorig_01",
        "g_m_y_mexgoon_01",
        "g_m_m_chigoon_01",
        "a_m_m_salton_01",
        "csb_reporter",
        "s_m_m_highsec_01",
    },
    MaxRoles = 10,
    BasePermissions = {
        "full_access",
        "stash",
        "manage_members",
        "gang_points",
        "quick_menu",
        "npc_control",
        "radio",
        "garage",
        "safe"
    },
    Specializations = {
        "weed",
        "cocaine",
        "meth",
        "weapons"
    }
}

-- Grow Shop Module Configuration (Phase 3 User Request)
Config.GrowShop = {
    Enabled = true,

    -- Boss Menu / Shop Location
    Location = vector3(-1218.1184, -1483.7954, 5.1716), -- Default coords, can be changed
    
    -- Map Blip configuration
    Blip = {
        Enabled = true,
        Sprite = 140, -- 140 is the Weed leaf blip
        Color = 52, -- 52 is green
        Scale = 0.8,
        Name = "Piti Shop"
    },

    -- Authorized Ranks for managing the Grow Shop (can buy wholesale & craft)
    JobName = "growshop",
    ManagementRanks = {
        "jefe", 
        "encargado"
    },

    -- Company Garage (Phase 3.5)
    Garage = {
        Location = vector3(-1206.5729, -1480.5638, 4.3780),
        Heading = 305.2023,
        Vehicle = "pony2",
        Colors = { primary = 52, secondary = 145 } -- Green and Purple
    },

    -- Logistics Drop-Offs (Phase 3.5)
    DeliveryPoints = {
        vector3(146.51, -3211.53, 5.85), -- Elysian Island Dock
        vector3(894.88, -3130.6, 5.9),   -- Scrapyard
        vector3(-467.58, -2803.95, 6.0)  -- Airport Warehouse
    },

    -- Storage Stash
    Stash = {
        Enabled = true,
        Location = vector3(-1214.9413, -1485.9397, 4.3739), -- Default coords for stash
        Name = "growshop_stash",
        Label = "Almacén Grow Shop",
        Weight = 4000000,
        Slots = 50
    },

    -- Wholesale Shop Items (Available for management to purchase to society stock)
    Wholesale = {
        -- Semillas
        { item = "seed_weed_standard", price = 50, label = "Semilla Standard" },
        { item = "seed_weed_cbd", price = 80, label = "Semilla CBD" },
        { item = "seed_weed_amnesia", price = 120, label = "Semilla Amnesia" },
        { item = "seed_weed_kush", price = 150, label = "Semilla Kush" },

        -- Suministros Cultivo
        { item = "grow_fertilizer", price = 25, label = "Fertilizante Básico" },
        { item = "grow_watercan", price = 15, label = "Regadera" },
        { item = "grow_pot", price = 40, label = "Maceta de Cultivo" },
        { item = "grow_uv_light", price = 200, label = "Foco UV Lámpara" },
        
        -- Herramientas
        { item = "trimming_scissors", price = 35, label = "Tijeras de Podar" },
        { item = "empty_baggies", price = 5, label = "Bolsitas Vacías" },
        { item = "digital_scale", price = 150, label = "Báscula de Precisión" },
    },

    -- NPC "El Cocinero" Crafting Recipes
    Crafting = {
        ["joint_weed"] = {
            label = "Porro Standard",
            required = {
                { item = "bud_standard", amount = 1 },
                { item = "rolling_paper", amount = 1 }
            },
            amount = 3
        },
        ["joint_cbd"] = {
            label = "Porro CBD",
            required = {
                { item = "bud_cbd", amount = 1 },
                { item = "rolling_paper", amount = 1 }
            },
            amount = 3
        },
        ["joint_kush"] = {
            label = "Porro Kush",
            required = {
                { item = "bud_kush", amount = 1 },
                { item = "rolling_paper", amount = 1 }
            },
            amount = 3
        },
        ["blunt_amnesia"] = {
            label = "Blunt Amnesia",
            required = {
                { item = "bud_amnesia", amount = 1 },
                { item = "rolling_paper", amount = 2 }
            },
            amount = 2
        },
        ["weed_cookie"] = {
            label = "Galleta de Marihuana",
            required = {
                { item = "bud_standard", amount = 2 },
            },
            amount = 4
        },
        ["weed_brownie"] = {
            label = "Brownie Espacial",
            required = {
                { item = "package_gelato", amount = 1 },
            },
            amount = 5
        },
        ["thc_gummies"] = {
            label = "Gominolas THC",
            required = {
                { item = "package_gorilla", amount = 1 },
            },
            amount = 5
        }
    }
}

-- ============================================================
-- DRUG GROWING SYSTEM (Phase 4)
-- ============================================================
Config.Growing = {
    WaterDecayPerMinute = 2,   -- % of water lost per minute
    DeathAtZeroWater = false,  -- true = plant dies at 0% water, false = growth paused

    -- Ground material hashes allowed for planting (illegal strains only)
    AllowedMaterials = {
        [0x4F747B87] = true, -- Grass
        [0xB34E900D] = true, -- Grass Short
        [0xE47A3E41] = true, -- Grass Long
        [0x8F9CD58F] = true, -- Dirt Track
        [0x8C31B7EA] = true, -- Mud Hard
        [0x61826E7A] = true, -- Mud Soft
        [0x42251DC0] = true, -- Mud Deep
        [0xA0EBF7E4] = true, -- Sand Loose
        [0xD63CCDDB] = true, -- Soil
        [0xCDEB5023] = true, -- Rock
        [0xF8902AC8] = true, -- Rock Mossy
        [0x2D9C1E0D] = true, -- Stone
        [0x22AD7B72] = true, -- Bushes
        [0xC98F5B61] = true, -- Twigs
        [0x8653C6CD] = true, -- Leaves
        [0x129ECA2A] = true, -- Mud Pothole
        [0xEFB2DF09] = true, -- Mud Underwater
        [0x1E6D775E] = true, -- Sand Compact
        [0x363CBCD5] = true, -- Sand Wet
        [0x7EDC5571] = true, -- Mountain Rock/Gravel
    },

    Seeds = {
        ["seed_weed_standard"] = {
            label = "Marihuana Standard",
            bud = "bud_standard",
            harvestMin = 2, harvestMax = 5,
            requiresPot = false,
            stages = {
                { time = 5,  prop = "prop_weed_02" },       -- Brote
                { time = 10, prop = "prop_weed_02" },       -- Crecimiento
                { time = 15, prop = "prop_weed_01" },       -- Vegetativo
                { time = 20, prop = "prop_weed_01" },       -- Floración
                { time = 0,  prop = "prop_weed_01" },       -- Cosecha (final)
            }
        },
        ["seed_weed_cbd"] = {
            label = "CBD Medicinal",
            bud = "bud_cbd",
            harvestMin = 3, harvestMax = 6,
            requiresPot = true,
            stages = {
                { time = 5,  prop = "prop_weed_tub_01" },
                { time = 10, prop = "prop_weed_tub_01" },
                { time = 15, prop = "prop_weed_tub_01b" },
                { time = 20, prop = "prop_weed_tub_01b" },
                { time = 0,  prop = "prop_weed_tub_01b" },
            }
        },
        ["seed_weed_kush"] = {
            label = "Purple Kush",
            bud = "bud_kush",
            harvestMin = 1, harvestMax = 4,
            requiresPot = false,
            stages = {
                { time = 8,  prop = "prop_weed_02" },
                { time = 15, prop = "prop_weed_02" },
                { time = 20, prop = "prop_weed_01" },
                { time = 25, prop = "prop_weed_01" },
                { time = 0,  prop = "prop_weed_01" },
            }
        },
        ["seed_weed_amnesia"] = {
            label = "Amnesia Haze",
            bud = "bud_amnesia",
            harvestMin = 1, harvestMax = 3,
            requiresPot = false,
            stages = {
                { time = 10, prop = "prop_weed_02" },
                { time = 20, prop = "prop_weed_02" },
                { time = 25, prop = "prop_weed_01" },
                { time = 30, prop = "prop_weed_01" },
                { time = 0,  prop = "prop_weed_01" },
            }
        },
    }
}

-- ============================================================
-- DRUG PROCESSING & JOINTS (Phase 5)
-- ============================================================
Config.Processing = {
    -- Coordenada para empaquetar cogollos en bolsitas (mesa/zona secreta)
    BaggieLocation = vec4(1096.1074, -309.0940, 59.3597, 161.3038),
    BaggieTargetDistance = 2.0, -- Distancia máxima para interactuar
    
    -- Mapeo para liar porros (usando papel_liar)
    Joints = {
        { bud = "bud_standard", paper = "rolling_paper", paper_amt = 1, result = "joint_weed", label = "Porro Standard" },
        { bud = "bud_cbd", paper = "rolling_paper", paper_amt = 1, result = "joint_cbd", label = "Porro CBD" },
        { bud = "bud_kush", paper = "rolling_paper", paper_amt = 1, result = "joint_kush", label = "Porro Kush" },
        { bud = "bud_amnesia", paper = "rolling_paper", paper_amt = 2, result = "blunt_amnesia", label = "Blunt Amnesia" },
    },
    
    -- Mapeo para procesar bolsitas (requiere empty_baggies y target zone)
    Baggies = {
        { bud = "bud_standard", bud_amt = 1, baggie = "empty_baggies", result = "bag_standard", label = "Bolsita de Marihuana" },
        { bud = "bud_cbd", bud_amt = 1, baggie = "empty_baggies", result = "bag_cbd", label = "Bolsita de CBD" },
        { bud = "bud_kush", bud_amt = 1, baggie = "empty_baggies", result = "bag_kush", label = "Bolsita de Kush" },
        { bud = "bud_amnesia", bud_amt = 1, baggie = "empty_baggies", result = "bag_amnesia", label = "Bolsita de Amnesia" },
    }
}
