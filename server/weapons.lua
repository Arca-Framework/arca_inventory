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
    if d.throwable then
        TriggerClientEvent('arca_inventory:client:forceClose', src)
        return TriggerClientEvent('arca_inventory:client:useWeapon', src, slot, item, {
            weapon = d.weapon, throwable = true,
        })
    end
    if d.repair then
        return TriggerClientEvent('arca_inventory:client:useRepairKit', src, slot)
    end
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

---------------------------------------------------------------------
-- Throwables: each throw the client reports removes one item from the stack
---------------------------------------------------------------------
RegisterNetEvent('arca_inventory:weapon:thrown', function(slot, thrown)
    local src = source
    local inv = I.playerInv(src)
    slot = tonumber(slot)
    local item = inv and slot and inv.items[slot]
    if not item or not def(item.name).throwable then return end
    thrown = math.floor(tonumber(thrown) or 0)
    if thrown < 1 then return end
    I.removeItem(inv, item.name, math.min(thrown, item.count), slot)
end)

local function reply(src, msg, kind)
    if src == 0 then return print(msg) end
    TriggerClientEvent('arca_core:notify', src, msg, kind)
end

local function isAdmin(src)
    return src == 0 or exports.arca_core:HasPermission(src, 'admin')
end

function PlayerName(src)
    local player = type(src) == 'table' and src or exports.arca_core:GetPlayer(src)
    local info = player and player.PlayerData.charinfo
    return info and ('%s %s'):format(info.firstname, info.lastname) or 'Unknown'
end

---------------------------------------------------------------------
-- Licences (player metadata, qb-core style: metadata.licences[name] = true)
---------------------------------------------------------------------
local LicCfg = InvConfig.Weapons.Licences

function LicenceLabel(name)
    return LicCfg.Types[name] or (name .. ' licence')
end

function HasLicence(src, name)
    local player = exports.arca_core:GetPlayer(src)
    local licences = player and player.PlayerData.metadata.licences
    return type(licences) == 'table' and licences[name] == true
end

local function setLicence(target, name, value)
    local player = exports.arca_core:GetPlayer(target)
    if not player then return false end
    local licences = player.PlayerData.metadata.licences
    if type(licences) ~= 'table' then licences = {} end
    licences[name] = value and true or nil
    player.SetMetaData('licences', licences)
    return true
end

exports('HasLicence', HasLicence)
exports('SetLicence', setLicence)

local function licenceCommand(grant)
    local cmd = grant and 'givelicence' or 'revokelicence'
    return function(src, args)
        if not isAdmin(src) and not I.inGroups(src, LicCfg.Issuers) then
            return reply(src, 'You can\'t issue licences', 'error')
        end
        local target, name = tonumber(args[1]), args[2] and args[2]:lower()
        if not target or not name or not LicCfg.Types[name] then
            local types = {}
            for k in pairs(LicCfg.Types) do types[#types + 1] = k end
            return reply(src, ('Usage: /%s id type (%s)'):format(cmd, table.concat(types, ', ')), 'error')
        end
        if not setLicence(target, name, grant) then return reply(src, 'Player is not online', 'error') end

        local label = LicenceLabel(name)
        if grant and LicCfg.CardItem and name == 'weapon' then
            local inv = I.playerInv(target)
            if inv then I.addItem(inv, LicCfg.CardItem, 1, { holder = PlayerName(target) }) end
        end
        reply(src, ('%s %s %s ID %d'):format(grant and 'Gave' or 'Revoked', label, grant and 'to' or 'from', target), 'success')
        TriggerClientEvent('arca_core:notify', target, ('Your %s was %s'):format(label, grant and 'issued' or 'revoked'), grant and 'success' or 'error')
    end
end

exports.arca_core:AddCommand('givelicence', 'Issue a licence: /givelicence id type', nil, licenceCommand(true))
exports.arca_core:AddCommand('revokelicence', 'Revoke a licence: /revokelicence id type', nil, licenceCommand(false))

---------------------------------------------------------------------
-- Weapon registry
---------------------------------------------------------------------
local RegCfg = InvConfig.Weapons.Registry

---Metadata for a weapon that is about to be sold and registered to a player
function RegisteredWeaponMeta(_, player, d)
    local meta = { serial = serial() }
    if RegCfg.Enabled then meta.registered = PlayerName(player) end
    WeaponDefaults(d, meta)
    return meta
end

function RegisterWeapon(player, d, meta)
    if not RegCfg.Enabled then return end
    MySQL.insert('INSERT INTO arca_weapon_registry (serial, weapon, citizenid, owner) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE citizenid = VALUES(citizenid), owner = VALUES(owner)', {
        meta.serial, d.label, player.PlayerData.citizenid, meta.registered,
    })
end

local function lookup(serialNo)
    return MySQL.single.await('SELECT * FROM arca_weapon_registry WHERE serial = ?', { serialNo })
end
exports('GetWeaponRegistration', lookup)

exports.arca_core:AddCommand('checkserial', 'Look up a weapon serial: /checkserial serial', nil, function(src, args)
    if not isAdmin(src) and not I.inGroups(src, RegCfg.Lookup) then
        return reply(src, 'You don\'t have access to the weapon registry', 'error')
    end
    local serialNo = args[1] and args[1]:upper()
    if not serialNo then return reply(src, 'Usage: /checkserial serial', 'error') end
    local row = lookup(serialNo)
    if not row then return reply(src, ('%s is not registered'):format(serialNo), 'error') end
    reply(src, ('%s · %s registered to %s (%s)'):format(row.serial, row.weapon, row.owner, row.citizenid), 'inform')
end)

CreateThread(function()
    if not RegCfg.Enabled then return end
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `arca_weapon_registry` (
            `serial` VARCHAR(20) NOT NULL,
            `weapon` VARCHAR(60) NOT NULL,
            `citizenid` VARCHAR(50) NOT NULL,
            `owner` VARCHAR(100) NOT NULL,
            `registered_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`serial`),
            KEY `citizenid` (`citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
end)

---------------------------------------------------------------------
-- Repairs: repair kit item (equipped weapon) and repair benches (pay per point)
---------------------------------------------------------------------
local function repairable(d)
    return d and d.weapon and not d.throwable
end

RegisterNetEvent('arca_inventory:weapon:repairKit', function(weaponSlot, serialNo, kitSlot)
    local src = source
    local inv, item, d = weaponAt(src, weaponSlot, serialNo)
    if not inv or not repairable(d) then return end
    kitSlot = tonumber(kitSlot)
    local kit = kitSlot and inv.items[kitSlot]
    local kd = kit and def(kit.name)
    if not kd or not kd.repair then return end
    if (item.metadata.durability or 100) >= 100 then
        return reply(src, ('Your %s is already in perfect condition'):format(d.label), 'error')
    end
    if not I.removeItem(inv, kit.name, 1, kitSlot) then return end
    item.metadata.durability = math.min(100, (item.metadata.durability or 0) + kd.repair)
    I.changed(inv)
    reply(src, ('%s repaired to %d%%'):format(d.label, math.floor(item.metadata.durability)), 'success')
end)

local function benchAt(src, index)
    local bench = InvConfig.Weapons.RepairBenches[tonumber(index) or 0]
    if not bench then return nil end
    local c = GetEntityCoords(GetPlayerPed(tostring(src)))
    if #(c - bench.coords) > 3.0 or not I.inGroups(src, bench.groups) then return nil end
    return bench
end

local function benchCost(bench, item)
    return math.ceil((100 - (item.metadata.durability or 100)) * bench.price)
end

---Weapons in the player's inventory that the bench can repair
Arca.Callback.Register('arca_inventory:bench:list', function(src, index)
    local bench = benchAt(src, index)
    local inv = I.playerInv(src)
    if not bench or not inv then return nil end
    local list = {}
    for slot, item in pairs(inv.items) do
        local d = def(item.name)
        if repairable(d) and (item.metadata.durability or 100) < 100 then
            list[#list + 1] = {
                slot = slot, serial = item.metadata.serial, label = d.label, icon = d.icon,
                durability = math.floor(item.metadata.durability or 0), cost = benchCost(bench, item),
            }
        end
    end
    table.sort(list, function(a, b) return a.slot < b.slot end)
    return { list = list, account = bench.account or 'cash', duration = bench.duration or 5000 }
end)

Arca.Callback.Register('arca_inventory:bench:repair', function(src, index, slot, serialNo)
    local bench = benchAt(src, index)
    local inv, item, d = weaponAt(src, slot, serialNo)
    if not bench or not inv or not repairable(d) then return false end
    local cost = benchCost(bench, item)
    if cost <= 0 then return false end
    local player = exports.arca_core:GetPlayer(src)
    local account = bench.account or 'cash'
    if not player or (player.PlayerData.money[account] or 0) < cost or not player.RemoveMoney(account, cost, 'weapon repair') then
        reply(src, ('You need $%d (%s)'):format(cost, account), 'error')
        return false
    end
    item.metadata.durability = 100
    I.changed(inv)
    reply(src, ('Paid $%d · %s fully repaired'):format(cost, d.label), 'success')
    return true
end)
