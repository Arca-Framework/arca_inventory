-- Weapons as items: serial numbers, ammo stored on the weapon, durability and attachments.
-- The client equips/holsters; the server owns ammo, durability and attachments.

local I = InvInternal
local def = I.def

local function serial()
    local chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
    local s = ''
    for _ = 1, 3 do
        local n = math.random(#chars)
        s = s .. chars:sub(n, n)
    end
    return s .. math.random(100000, 999999)
end

---Fills in missing weapon metadata (called by addItem for every new weapon)
function WeaponDefaults(d, meta)
    if not meta.serial and not d.noSerial then meta.serial = serial() end
    if d.ammo and meta.ammo == nil then meta.ammo = 0 end
    if meta.durability == nil then meta.durability = 100 end
    if type(meta.components) ~= 'table' then meta.components = {} end
end

---The weapon in a player's slot, checked against the serial the client thinks it has
local function weaponAt(src, slot, serialNo)
    local inv = I.playerInv(src)
    local item = inv and inv.items[tonumber(slot)]
    if not item or not def(item.name).weapon then return nil end
    if serialNo and item.metadata.serial ~= serialNo then return nil end
    return inv, item, def(item.name)
end

---------------------------------------------------------------------
-- Using weapon / ammo / attachment items
---------------------------------------------------------------------
function WeaponUse(src, inv, slot, item, d)
    if d.weapon then
        if (item.metadata.durability or 100) <= 0 then
            return TriggerClientEvent('arca_core:notify', src, ('Your %s is broken'):format(d.label), 'error')
        end
        TriggerClientEvent('arca_inventory:client:forceClose', src)
        return TriggerClientEvent('arca_inventory:client:useWeapon', src, slot, item, {
            weapon = d.weapon, ammo = d.ammo, components = d.components,
        })
    end
    if d.ammoType then
        return TriggerClientEvent('arca_inventory:client:reload', src)
    end
    if d.attachment then
        return TriggerClientEvent('arca_inventory:client:useAttachment', src, slot, item.name)
    end
end

---------------------------------------------------------------------
-- Ammo / durability reported by the client while shooting
---------------------------------------------------------------------
RegisterNetEvent('arca_inventory:weapon:ammo', function(slot, serialNo, ammo)
    local src = source
    local inv, item, d = weaponAt(src, slot, serialNo)
    if not inv or not d.ammo then return end
    ammo = math.floor(tonumber(ammo) or 0)
    local current = item.metadata.ammo or 0
    -- the client may only ever lower ammo; loading goes through arca_inventory:weapon:reload
    if ammo >= current or ammo < 0 then return end

    local shots = current - ammo
    item.metadata.ammo = ammo
    local wear = d.wear or InvConfig.Weapons.Wear
    item.metadata.durability = math.max(0, math.floor(((item.metadata.durability or 100) - shots * wear) * 100) / 100)
    if item.metadata.durability <= 0 then
        TriggerClientEvent('arca_inventory:client:disarm', src)
        TriggerClientEvent('arca_core:notify', src, ('Your %s broke'):format(d.label), 'error')
    end
    I.changed(inv)
end)

---Loads ammo items from the inventory into the equipped weapon
Arca.Callback.Register('arca_inventory:weapon:reload', function(src, slot, serialNo)
    local inv, item, d = weaponAt(src, slot, serialNo)
    if not inv or not d.ammo then return nil end
    local max = d.maxAmmo or InvConfig.Weapons.MaxAmmo
    local current = item.metadata.ammo or 0
    local have = I.countItem(inv, d.ammo)
    local take = math.min(have, max - current)
    if take <= 0 then
        TriggerClientEvent('arca_core:notify', src, have == 0 and ('No %s'):format(def(d.ammo).label) or 'Weapon is full', 'error')
        return nil
    end
    I.removeItem(inv, d.ammo, take)
    item.metadata.ammo = current + take
    I.changed(inv)
    return item.metadata.ammo
end)

---------------------------------------------------------------------
-- Attachments
---------------------------------------------------------------------
RegisterNetEvent('arca_inventory:weapon:attach', function(weaponSlot, serialNo, attachSlot)
    local src = source
    local inv, item, d = weaponAt(src, weaponSlot, serialNo)
    if not inv then return end
    local att = inv.items[tonumber(attachSlot)]
    local ad = att and def(att.name)
    if not ad or not ad.attachment then return end

    local component = ad.attachment[d.weapon]
    if not component then
        return TriggerClientEvent('arca_core:notify', src, ('%s doesn\'t fit this weapon'):format(ad.label), 'error')
    end
    for _, existing in ipairs(item.metadata.components) do
        if existing == att.name then
            return TriggerClientEvent('arca_core:notify', src, 'Already attached', 'error')
        end
    end
    if not I.removeItem(inv, att.name, 1, tonumber(attachSlot)) then return end
    item.metadata.components[#item.metadata.components + 1] = att.name
    I.changed(inv)
    TriggerClientEvent('arca_core:notify', src, ('Attached %s'):format(ad.label), 'success')
end)

RegisterNetEvent('arca_inventory:weapon:detach', function(slot, attachmentName)
    local src = source
    local inv, item = weaponAt(src, slot)
    if not inv then return end
    local list = item.metadata.components or {}
    for i, name in ipairs(list) do
        if name == attachmentName then
            if not I.addItem(inv, name, 1) then
                return TriggerClientEvent('arca_core:notify', src, 'No room for the attachment', 'error')
            end
            table.remove(list, i)
            I.changed(inv)
            return TriggerClientEvent('arca_core:notify', src, ('Removed %s'):format(def(name).label), 'success')
        end
    end
end)
