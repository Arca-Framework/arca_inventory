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
    SaveInterval = 60,          -- seconds between saving changed inventories
}
