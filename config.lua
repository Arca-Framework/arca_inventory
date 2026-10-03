InvConfig = {
    OpenKey = 'TAB',            -- default key, players can rebind in GTA settings
    HotbarSlots = 5,            -- slots 1-5 of the player inventory are used with keys 1-5

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

    -- Shops: drag an item from the shop into your inventory to buy it (amount box = quantity)
    ShopPayment = { 'cash', 'bank' },   -- accounts tried in order
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
