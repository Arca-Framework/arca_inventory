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
    -- chip = true: the phone holds a phone chip (number, contacts, messages live on the chip, see arca_phone)
    phone = { label = 'Phone', rarity = 'uncommon', weight = 200, stack = false, chip = true, icon = 'fa-solid fa-mobile-screen', description = 'An iFruit smartphone. Right-click to see its chip.' },
    phone_chip = { label = 'Phone Chip', rarity = 'uncommon', weight = 5, stack = false, chipItem = true, icon = 'fa-solid fa-sim-card', description = 'Holds a phone number, contacts and messages.' },
    radio = { label = 'Radio', rarity = 'uncommon', weight = 500, stack = false, icon = 'fa-solid fa-walkie-talkie', description = 'Talk on radio channels.' },
    id_card = { label = 'ID Card', rarity = 'uncommon', weight = 10, stack = false, icon = 'fa-solid fa-id-card', description = 'Citizen identification.' },
    backpack = { label = 'Backpack', rarity = 'rare', weight = 1000, stack = false, icon = 'fa-solid fa-suitcase', description = 'Carry more things.' },
    copper = { label = 'Copper', rarity = 'common', weight = 200, stack = true, icon = 'fa-solid fa-cubes', description = 'Scrap metal.' },
    -- Ammo: ammoType marks it as ammo; weapons point to it with ammo = '<item>'
    pistol_ammo = { label = 'Pistol Ammo', rarity = 'uncommon', weight = 10, stack = true, ammoType = 'pistol', icon = 'fa-solid fa-grip-lines-vertical', description = 'Pistol rounds.' },
    smg_ammo = { label = 'SMG Ammo', rarity = 'uncommon', weight = 10, stack = true, ammoType = 'smg', icon = 'fa-solid fa-grip-lines-vertical', description = 'SMG rounds.' },
    rifle_ammo = { label = 'Rifle Ammo', rarity = 'rare', weight = 15, stack = true, ammoType = 'rifle', icon = 'fa-solid fa-grip-lines-vertical', description = 'Rifle rounds.' },
    shotgun_ammo = { label = 'Shotgun Shells', rarity = 'uncommon', weight = 20, stack = true, ammoType = 'shotgun', icon = 'fa-solid fa-grip-lines-vertical', description = 'Shotgun shells.' },

    -- Weapons: weapon = GTA weapon name, ammo = ammo item (none for melee), maxAmmo / wear optional
    --   licence = 'weapon' -> shops only sell it to players holding that licence
    weapon_pistol = { label = 'Pistol', rarity = 'uncommon', weight = 1000, weapon = 'WEAPON_PISTOL', ammo = 'pistol_ammo', icon = 'fa-solid fa-gun', licence = 'weapon', description = 'A standard 9mm pistol.' },
    weapon_combatpistol = { label = 'Combat Pistol', rarity = 'rare', weight = 1100, weapon = 'WEAPON_COMBATPISTOL', ammo = 'pistol_ammo', icon = 'fa-solid fa-gun', licence = 'weapon', description = 'Reliable sidearm.' },
    weapon_stungun = { label = 'Taser', rarity = 'uncommon', weight = 700, weapon = 'WEAPON_STUNGUN', icon = 'fa-solid fa-bolt', description = 'Non-lethal.', noSerial = true },
    weapon_smg = { label = 'SMG', rarity = 'rare', weight = 2500, weapon = 'WEAPON_SMG', ammo = 'smg_ammo', icon = 'fa-solid fa-gun', licence = 'weapon', description = 'Compact sub-machine gun.' },
    weapon_carbinerifle = { label = 'Carbine Rifle', rarity = 'legendary', weight = 3500, weapon = 'WEAPON_CARBINERIFLE', ammo = 'rifle_ammo', icon = 'fa-solid fa-gun', licence = 'weapon', description = 'Standard issue rifle.', wear = 0.03 },
    weapon_pumpshotgun = { label = 'Pump Shotgun', rarity = 'rare', weight = 3200, weapon = 'WEAPON_PUMPSHOTGUN', ammo = 'shotgun_ammo', maxAmmo = 60, icon = 'fa-solid fa-gun', licence = 'weapon', description = 'Close range stopping power.' },
    weapon_knife = { label = 'Knife', rarity = 'common', weight = 300, weapon = 'WEAPON_KNIFE', icon = 'fa-solid fa-utensils', description = 'Sharp.', noSerial = true },
    weapon_bat = { label = 'Baseball Bat', rarity = 'common', weight = 1000, weapon = 'WEAPON_BAT', icon = 'fa-solid fa-baseball-bat-ball', description = 'Home run.', noSerial = true },
    weapon_flashlight = { label = 'Flashlight', rarity = 'common', weight = 400, weapon = 'WEAPON_FLASHLIGHT', icon = 'fa-solid fa-lightbulb', description = 'Lights the way.', noSerial = true },

    -- Throwables: stack like normal items; equip and throw one at a time, each throw uses one item
    weapon_grenade = { label = 'Grenade', rarity = 'legendary', weight = 400, stack = true, throwable = true, weapon = 'WEAPON_GRENADE', icon = 'fa-solid fa-bomb', description = 'Pull the pin and throw.' },
    weapon_smokegrenade = { label = 'Smoke Grenade', rarity = 'rare', weight = 400, stack = true, throwable = true, weapon = 'WEAPON_SMOKEGRENADE', icon = 'fa-solid fa-smog', description = 'Covers an area in smoke.' },
    weapon_bzgas = { label = 'Tear Gas', rarity = 'rare', weight = 400, stack = true, throwable = true, weapon = 'WEAPON_BZGAS', icon = 'fa-solid fa-head-side-cough', description = 'Clears a room.' },
    weapon_molotov = { label = 'Molotov', rarity = 'rare', weight = 600, stack = true, throwable = true, weapon = 'WEAPON_MOLOTOV', icon = 'fa-solid fa-fire', description = 'A bottle of trouble.' },
    weapon_flare = { label = 'Flare', rarity = 'common', weight = 200, stack = true, throwable = true, weapon = 'WEAPON_FLARE', icon = 'fa-solid fa-fire-flame-simple', description = 'Lights up the night.' },

    -- Weapon repair: use one to repair the weapon you have equipped by `repair` durability points
    weapon_repairkit = { label = 'Weapon Repair Kit', rarity = 'rare', weight = 1500, stack = true, close = true, repair = 35, icon = 'fa-solid fa-toolbox', description = 'Cleans and fixes up the weapon in your hands.' },

    -- Licences are player metadata (see InvConfig.Weapons.Licences), the card is just for show
    weapon_licence = { label = 'Weapon Licence', rarity = 'rare', weight = 10, stack = false, icon = 'fa-solid fa-id-badge', description = 'Permit to carry firearms.' },

    -- Attachments: attachment = { [weapon] = component }
    suppressor = { label = 'Suppressor', rarity = 'rare', weight = 200, stack = true, icon = 'fa-solid fa-volume-xmark', description = 'Quiets your shots.', attachment = {
        WEAPON_PISTOL = 'COMPONENT_AT_PI_SUPP_02', WEAPON_COMBATPISTOL = 'COMPONENT_AT_PI_SUPP',
        WEAPON_SMG = 'COMPONENT_AT_PI_SUPP', WEAPON_CARBINERIFLE = 'COMPONENT_AT_AR_SUPP', WEAPON_PUMPSHOTGUN = 'COMPONENT_AT_SR_SUPP',
    } },
    weapon_flashlight_attachment = { label = 'Tactical Light', rarity = 'uncommon', weight = 150, stack = true, icon = 'fa-solid fa-lightbulb', description = 'Mounted flashlight.', attachment = {
        WEAPON_PISTOL = 'COMPONENT_AT_PI_FLSH', WEAPON_COMBATPISTOL = 'COMPONENT_AT_PI_FLSH',
        WEAPON_SMG = 'COMPONENT_AT_AR_FLSH', WEAPON_CARBINERIFLE = 'COMPONENT_AT_AR_FLSH', WEAPON_PUMPSHOTGUN = 'COMPONENT_AT_AR_FLSH',
    } },
    extended_clip = { label = 'Extended Clip', rarity = 'rare', weight = 250, stack = true, icon = 'fa-solid fa-layer-group', description = 'More rounds per magazine.', attachment = {
        WEAPON_PISTOL = 'COMPONENT_PISTOL_CLIP_02', WEAPON_COMBATPISTOL = 'COMPONENT_COMBATPISTOL_CLIP_02',
        WEAPON_SMG = 'COMPONENT_SMG_CLIP_02', WEAPON_CARBINERIFLE = 'COMPONENT_CARBINERIFLE_CLIP_02',
    } },
    scope = { label = 'Scope', rarity = 'rare', weight = 300, stack = true, icon = 'fa-solid fa-crosshairs', description = 'See further.', attachment = {
        WEAPON_SMG = 'COMPONENT_AT_SCOPE_MACRO_02', WEAPON_CARBINERIFLE = 'COMPONENT_AT_SCOPE_MEDIUM',
    } },
}
