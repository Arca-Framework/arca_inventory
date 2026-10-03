InvConfig = {
    OpenKey = 'I',            -- default key, players can rebind in GTA settings
    HotbarSlots = 5,            -- slots 1-5 of the player inventory are used with keys 1-5

    -- true = weight limits + slots, false = slots only (weights below are then ignored)
    UseWeight = true,

    -- weights are in grams
    Player = { slots = 30, weight = 30000 },
    Drop = { slots = 30, weight = 200000, range = 2.5 },
    Glovebox = { slots = 5, weight = 10000 },
    Trunk = {
        range = 2.0,            -- how close to the back of the vehicle you must be
        default = { slots = 30, weight = 60000 },
        -- per vehicle class (GetVehicleClass)
        classes = {
            [0] = { slots = 20, weight = 40000 },   -- compacts
            [8] = { slots = 5, weight = 10000 },    -- motorcycles
            [13] = { slots = 0, weight = 0 },       -- cycles (no trunk)
            [12] = { slots = 50, weight = 120000 }, -- vans
            [20] = { slots = 60, weight = 200000 }, -- commercial
        },
    },

    GiveRange = 3.0,

    -- Cash is an item in your inventory, kept equal to your arca_core cash balance.
    -- Dropping, giving or storing it moves the money; AddMoney/RemoveMoney from arca_core.
    CashItem = true,

    -- Shops: drag an item from the shop into your inventory to buy it (amount box = quantity)
    ShopPayment = { 'cash', 'bank' },   -- accounts players can pay with at the cart (one button each)
    Shops = {
        {
            id = '247', label = '24/7 Supermarket',
            ped = 'mp_m_shopkeep_01',
            blip = { sprite = 52, color = 2 },
            locations = {
                vector4(24.47, -1346.62, 29.50, 271.66),
                vector4(-3039.54, 584.38, 7.91, 17.27),
                vector4(1728.07, 6415.63, 35.04, 242.95),
                vector4(1959.82, 3740.48, 32.34, 301.57),
                vector4(549.13, 2670.85, 42.16, 99.39),
                vector4(2677.47, 3279.76, 55.24, 335.08),
                vector4(2556.66, 380.84, 108.62, 356.67),
                vector4(372.66, 326.98, 103.57, 253.73),
                vector4(-47.37, -1758.61, 29.42, 53.10),
            },
            items = {
                { name = 'water', price = 5 },
                { name = 'sandwich', price = 8 },
                { name = 'bread', price = 4 },
                { name = 'coffee', price = 6 },
                { name = 'bandage', price = 50 },
                { name = 'phone', price = 500 },
                { name = 'radio', price = 250 },
            },
        },
        {
            id = 'hardware', label = 'Hardware Store',
            ped = 's_m_m_lathandy_01',
            blip = { sprite = 402, color = 47 },
            locations = {
                vector4(45.68, -1749.04, 29.61, 53.13),
                vector4(2747.71, 3472.85, 55.67, 255.08),
            },
            items = {
                { name = 'repairkit', price = 250 },
                { name = 'lockpick', price = 150, stock = 20 },   -- limited stock (resets on restart)
                { name = 'backpack', price = 400 },
            },
            -- groups = { mechanic = 0 },   -- optional: only these jobs/gangs (min grade)
        },
        {
            -- weapons with licence = '...' (shared/items.lua) need that licence to buy.
            -- register = true writes every weapon sold here to the registry under the buyer's name.
            id = 'ammunation', label = 'Ammu-Nation',
            ped = 's_m_y_ammucity_01',
            blip = { sprite = 110, color = 1 },
            register = true,
            locations = {
                vector4(22.09, -1105.36, 29.80, 157.0),
                vector4(810.25, -2159.04, 29.62, 0.0),
                vector4(1692.39, 3760.98, 34.71, 228.0),
                vector4(-330.24, 6083.88, 31.45, 225.0),
                vector4(252.63, -50.0, 69.94, 70.0),
                vector4(-1118.59, 2699.93, 18.55, 222.0),
                vector4(841.92, -1035.32, 28.19, 0.0),
                vector4(-3173.31, 1088.85, 20.84, 245.0),
                vector4(-662.40, -933.53, 21.83, 176.57),
            },
            items = {
                { name = 'weapon_knife', price = 150 },
                { name = 'weapon_bat', price = 100 },
                { name = 'weapon_flashlight', price = 80 },
                { name = 'weapon_pistol', price = 2500 },
                { name = 'weapon_pumpshotgun', price = 6000, stock = 10 },
                { name = 'pistol_ammo', price = 3 },
                { name = 'shotgun_ammo', price = 6 },
                { name = 'weapon_flare', price = 50 },
                { name = 'weapon_flashlight_attachment', price = 400 },
                { name = 'weapon_repairkit', price = 750 },
            },
        },
        {
            -- job-only shop: groups limits who can open it, ignoreLicence skips licence checks
            id = 'police_armory', label = 'Police Armory',
            ped = 's_m_y_cop_01',
            groups = { police = 0 },
            ignoreLicence = true,
            register = true,
            locations = {
                vector4(482.47, -995.13, 30.69, 90.0),
            },
            items = {
                { name = 'weapon_stungun', price = 0 },
                { name = 'weapon_flashlight', price = 0 },
                { name = 'weapon_combatpistol', price = 0 },
                { name = 'weapon_carbinerifle', price = 0 },
                { name = 'weapon_smokegrenade', price = 0 },
                { name = 'weapon_bzgas', price = 0 },
                { name = 'pistol_ammo', price = 0 },
                { name = 'rifle_ammo', price = 0 },
                { name = 'weapon_repairkit', price = 0 },
                { name = 'armor', price = 0 },
            },
        },
    },

    -- Dumpsters: third-eye a dumpster to search it. Found loot goes into the dumpster,
    -- which also works as temporary storage until the server restarts.
    Dumpsters = {
        models = { 'prop_dumpster_01a', 'prop_dumpster_02a', 'prop_dumpster_02b', 'prop_dumpster_3a', 'prop_dumpster_4a', 'prop_dumpster_4b' },
        slots = 10,
        weight = 50000,
        searchTime = 5000,      -- ms
        cooldown = 900,         -- seconds before the same dumpster can be searched again
        rolls = { 1, 3 },       -- how many loot rolls per search
        loot = {                -- chance is % per roll
            { name = 'copper', min = 1, max = 3, chance = 35 },
            { name = 'water', min = 1, max = 1, chance = 20 },
            { name = 'bread', min = 1, max = 1, chance = 20 },
            { name = 'bandage', min = 1, max = 2, chance = 10 },
            { name = 'lockpick', min = 1, max = 1, chance = 5 },
            { name = 'phone', min = 1, max = 1, chance = 2 },
        },
    },
    SaveInterval = 60,          -- seconds between saving changed inventories
}

-- Item rarity: set rarity = 'common' | 'uncommon' | 'rare' | 'legendary' on items in shared/items.lua.
-- Each rarity gives the inventory slot its own highlight. Set Enabled = false to turn it off.
InvConfig.Rarity = {
    Enabled = true,
    Default = 'common',             -- used for items without a rarity
    Colors = {
        common = '#9aa3ad',
        uncommon = '#3ecf72',
        rare = '#4c8dff',
        legendary = '#ffb547',
    },
}

-- Weapons are items (see shared/items.lua). Ammo lives on the weapon; use an ammo item
-- (or press the reload key) to load ammo from your inventory into the equipped weapon.
InvConfig.Weapons = {
    ReloadKey = 'R',
    MaxAmmo = 250,          -- default ammo a weapon can hold (items can set maxAmmo)
    Wear = 0.05,            -- default durability lost per shot (items can set wear)
    DisableWeaponWheel = true,
    -- remove any weapon a player holds that didn't come from their inventory
    StripUnknownWeapons = true,

    -- Licences live in the player's metadata (metadata.licences[name] = true), like qb-core.
    -- Jobs below may grant / revoke them with /givelicence and /revokelicence (admins always can).
    Licences = {
        Types = { weapon = 'Weapon Licence', hunting = 'Hunting Licence' },
        Issuers = { police = 2 },               -- job = minimum grade
        CardItem = 'weapon_licence',            -- also hand them this item when granted (false = off)
    },

    -- Weapon registry: weapons bought from shops with register = true are saved with the
    -- buyer's name. Police can look a serial up with /checkserial <serial>.
    Registry = {
        Enabled = true,
        Lookup = { police = 0 },                -- jobs allowed to use /checkserial
    },

    -- Repair benches: third-eye (or [E]) the bench, pick a weapon, pay and it's back to 100%
    RepairBenches = {
        {
            label = 'Weapon Bench',
            coords = vector3(16.72, -1110.35, 29.80),   -- Ammu-Nation, Pillbox Hill
            price = 5,                  -- $ per durability point restored
            account = 'cash',
            duration = 6000,            -- ms
            -- groups = { police = 0 },
        },
    },
}
