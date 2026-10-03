-- Item list. weight is in grams.
--   stack = false  -> every item takes its own slot (good for items with metadata)
--   close = true   -> using the item closes the inventory
--   icon           -> Font Awesome icon shown when web/images/<name>.png doesn't exist
--   rarity         -> common | uncommon | rare | legendary (slot highlight, see InvConfig.Rarity)
InvItems = {
    -- kept in sync with the player's cash account when InvConfig.CashItem is on
    cash = { label = 'Cash', rarity = 'legendary', weight = 0, stack = true, icon = 'fa-solid fa-money-bill-wave', description = 'Cold hard cash.' },

    water = { label = 'Water', rarity = 'common', weight = 500, stack = true, close = true, icon = 'fa-solid fa-bottle-water', description = 'Fresh bottled water.' },
    sandwich = { label = 'Sandwich', rarity = 'common', weight = 300, stack = true, close = true, icon = 'fa-solid fa-burger', description = 'Fills you up.' },
    bread = { label = 'Bread', rarity = 'common', weight = 250, stack = true, close = true, icon = 'fa-solid fa-bread-slice', description = 'A loaf of bread.' },
    coffee = { label = 'Coffee', rarity = 'common', weight = 300, stack = true, close = true, icon = 'fa-solid fa-mug-hot', description = 'Wakes you up.' },
    bandage = { label = 'Bandage', rarity = 'uncommon', weight = 100, stack = true, close = true, icon = 'fa-solid fa-bandage', description = 'Heals a little health.' },
    medikit = { label = 'Medikit', rarity = 'rare', weight = 1000, stack = true, close = true, icon = 'fa-solid fa-kit-medical', description = 'Heals you fully.' },
    armor = { label = 'Body Armor', rarity = 'legendary', weight = 3000, stack = true, close = true, icon = 'fa-solid fa-shield-halved', description = 'Bulletproof vest.' },
    repairkit = { label = 'Repair Kit', rarity = 'rare', weight = 2500, stack = true, close = true, icon = 'fa-solid fa-screwdriver-wrench', description = 'Fixes a vehicle engine.' },
    lockpick = { label = 'Lockpick', rarity = 'uncommon', weight = 150, stack = true, close = true, icon = 'fa-solid fa-key', description = 'For doors that are not yours.' },
    phone = { label = 'Phone', rarity = 'uncommon', weight = 200, stack = false, icon = 'fa-solid fa-mobile-screen', description = 'Your smartphone.' },
    radio = { label = 'Radio', rarity = 'uncommon', weight = 500, stack = false, icon = 'fa-solid fa-walkie-talkie', description = 'Talk on radio channels.' },
    id_card = { label = 'ID Card', rarity = 'uncommon', weight = 10, stack = false, icon = 'fa-solid fa-id-card', description = 'Citizen identification.' },
    backpack = { label = 'Backpack', rarity = 'rare', weight = 1000, stack = false, icon = 'fa-solid fa-suitcase', description = 'Carry more things.' },
    copper = { label = 'Copper', rarity = 'common', weight = 200, stack = true, icon = 'fa-solid fa-cubes', description = 'Scrap metal.' },
    pistol_ammo = { label = 'Pistol Ammo', rarity = 'uncommon', weight = 200, stack = true, icon = 'fa-solid fa-grip-lines-vertical', description = 'Box of pistol rounds.' },
}
