local Inventories = {} -- [id] = inventory
local Viewers = {}     -- [id] = { [src] = true }
local Access = {}      -- [src] = { [id] = true } secondary inventories a player has open
local PlayerInv = {}   -- [src] = inventory id
local Stashes = {}     -- [id] = { label, slots, weight, coords?, groups? }
local dropCount = 0

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function def(name) return InvItems[name] end

local function trim(s) return (tostring(s):gsub('^%s*(.-)%s*$', '%1')) end

local function sameMeta(a, b)
    return json.encode(a or {}) == json.encode(b or {})
end

---false when the weight is over the limit (always true when InvConfig.UseWeight is off)
local function fitsWeight(inv, weight)
    return not InvConfig.UseWeight or weight <= inv.maxWeight
end

local function usedSlots(inv)
    local n = 0
    for _ in pairs(inv.items) do n = n + 1 end
    return n
end

local function weightOf(inv)
    local total = 0
    for _, item in pairs(inv.items) do
        local d = def(item.name)
        total = total + (d and d.weight or 0) * item.count
    end
    return total
end

-- items are kept as [slot] = item internally, sent/saved as a plain list
local function toList(inv)
    local list = {}
    for slot, item in pairs(inv.items) do
        list[#list + 1] = { slot = slot, name = item.name, count = item.count, metadata = item.metadata }
    end
    return list
end

local function fromList(list, slots)
    local items = {}
    for _, item in ipairs(list or {}) do
        local slot = tonumber(item.slot)
        if slot and slot >= 1 and slot <= slots and def(item.name) and (item.count or 0) > 0 then
            items[slot] = { name = item.name, count = math.floor(item.count), metadata = item.metadata or {} }
        end
    end
    return items
end

local function payload(inv)
    return {
        id = inv.id, type = inv.type, label = inv.label,
        slots = inv.slots, maxWeight = inv.maxWeight, weight = weightOf(inv), used = usedSlots(inv),
        items = toList(inv),
    }
end

---------------------------------------------------------------------
-- Loading / saving
---------------------------------------------------------------------
local function create(id, invType, label, slots, maxWeight, items)
    local inv = { id = id, type = invType, label = label, slots = slots, maxWeight = maxWeight, items = items or {}, dirty = false }
    Inventories[id] = inv
    Viewers[id] = Viewers[id] or {}
    return inv
end

local function load(id, invType, label, slots, maxWeight)
    if Inventories[id] then return Inventories[id] end
    local raw = (invType ~= 'drop' and invType ~= 'dumpster') and MySQL.scalar.await('SELECT items FROM arca_inventories WHERE id = ?', { id })
    local list = raw and json.decode(raw) or {}
    return create(id, invType, label, slots, maxWeight, fromList(list, slots))
end

local function save(inv)
    -- drops, shops and dumpsters only live in memory
    if not inv.dirty or inv.type == 'drop' or inv.type == 'shop' or inv.type == 'dumpster' then return end
    inv.dirty = false
    MySQL.prepare('INSERT INTO arca_inventories (id, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = VALUES(items)', {
        inv.id, json.encode(toList(inv)),
    })
end

---------------------------------------------------------------------
-- Syncing
---------------------------------------------------------------------
local function sync(inv)
    local data = payload(inv)
    local other -- someone else's player inventory (admin view) is shown as a normal container
    for src in pairs(Viewers[inv.id] or {}) do
        if inv.type == 'player' and PlayerInv[src] ~= inv.id then
            if not other then
                other = {}
                for k, v in pairs(data) do other[k] = v end
                other.type = 'otherplayer'
            end
            TriggerClientEvent('arca_inventory:client:update', src, other)
        else
            TriggerClientEvent('arca_inventory:client:update', src, data)
        end
    end
end

local function syncDrops()
    local list = {}
    for id, inv in pairs(Inventories) do
        if inv.type == 'drop' then list[#list + 1] = { id = id, coords = inv.coords } end
    end
    TriggerClientEvent('arca_inventory:client:drops', -1, list)
end

local cashSync -- set further down once the item helpers exist

local function changed(inv)
    inv.dirty = true
    if inv.type == 'player' and cashSync then cashSync(inv) end
    if inv.type == 'drop' and next(inv.items) == nil then
        -- empty drops disappear
        for src in pairs(Viewers[inv.id] or {}) do
            if Access[src] then Access[src][inv.id] = nil end
        end
        sync(inv)
        Inventories[inv.id], Viewers[inv.id] = nil, nil
        return syncDrops()
    end
    sync(inv)
end

---------------------------------------------------------------------
-- Player inventories
---------------------------------------------------------------------
local function loadPlayer(src, citizenid)
    local id = 'player:' .. citizenid
    local inv = load(id, 'player', 'Inventory', InvConfig.Player.slots, InvConfig.Player.weight)
    inv.owner = src
    PlayerInv[src] = id
    Viewers[id][src] = true
    if CashFromAccount then CashFromAccount(src) end
    TriggerClientEvent('arca_inventory:client:update', src, payload(inv))
end

local function unloadPlayer(src)
    local id = PlayerInv[src]
    if not id then return end
    local inv = Inventories[id]
    if inv then
        save(inv)
        Inventories[id], Viewers[id] = nil, nil
    end
    PlayerInv[src], Access[src] = nil, nil
end

AddEventHandler('arca_core:server:playerLoaded', function(player)
    loadPlayer(player.PlayerData.source, player.PlayerData.citizenid)
end)

AddEventHandler('arca_core:server:playerUnloaded', unloadPlayer)
AddEventHandler('playerDropped', function() unloadPlayer(source) end)

---Resolves an export target (server id or inventory id) to an inventory
local function resolve(target)
    if type(target) == 'number' then return Inventories[PlayerInv[target]] end
    if Inventories[target] then return Inventories[target] end
    -- registered stashes load on demand, so scripts can fill one nobody has opened yet
    local stashId = type(target) == 'string' and target:match('^stash:(.+)$')
    local stash = stashId and Stashes[stashId]
    if stash then return load(target, 'stash', stash.label, stash.slots, stash.weight) end
end

---------------------------------------------------------------------
-- Core item operations
---------------------------------------------------------------------
local function canCarry(inv, name, count)
    local d = def(name)
    if not d then return false end
    return fitsWeight(inv, weightOf(inv) + d.weight * count)
end

local function freeSlot(inv)
    for slot = 1, inv.slots do
        if not inv.items[slot] then return slot end
    end
end

local function stackSlot(inv, name, metadata)
    for slot = 1, inv.slots do
        local item = inv.items[slot]
        if item and item.name == name and sameMeta(item.metadata, metadata) then return slot end
    end
end

local function addItem(inv, name, count, metadata, slot)
    local d = def(name)
    count = math.floor(tonumber(count) or 1)
    if not d or count < 1 or not canCarry(inv, name, count) then return false end
    metadata = metadata or {}

    if d.stack then
        local target = slot and inv.items[slot]
        if target and (target.name ~= name or not sameMeta(target.metadata, metadata)) then slot = nil end
        slot = slot or stackSlot(inv, name, metadata) or freeSlot(inv)
        if not slot then return false end
        local existing = inv.items[slot]
        if existing then
            existing.count = existing.count + count
        else
            inv.items[slot] = { name = name, count = count, metadata = metadata }
        end
    else
        -- unique items: one per slot
        local free = 0
        for s = 1, inv.slots do if not inv.items[s] then free = free + 1 end end
        if free < count then return false end
        for _ = 1, count do
            local s = (slot and not inv.items[slot]) and slot or freeSlot(inv)
            -- each copy gets its own metadata (weapons get their own serial)
            local meta = {}
            for k, v in pairs(metadata) do meta[k] = v end
            if d.weapon then WeaponDefaults(d, meta) end
            inv.items[s] = { name = name, count = 1, metadata = meta }
            slot = nil
        end
    end
    changed(inv)
    return true
end

local function countItem(inv, name)
    local total = 0
    for _, item in pairs(inv.items) do
        if item.name == name then total = total + item.count end
    end
    return total
end

local function removeItem(inv, name, count, slot)
    count = math.floor(tonumber(count) or 1)
    if count < 1 then return false end
    if slot then
        local item = inv.items[slot]
        if not item or item.name ~= name or item.count < count then return false end
        item.count = item.count - count
        if item.count <= 0 then inv.items[slot] = nil end
    else
        if countItem(inv, name) < count then return false end
        for s = 1, inv.slots do
            local item = inv.items[s]
            if item and item.name == name then
                local take = math.min(item.count, count)
                item.count = item.count - take
                count = count - take
                if item.count <= 0 then inv.items[s] = nil end
                if count <= 0 then break end
            end
        end
    end
    changed(inv)
    return true
end

---------------------------------------------------------------------
-- Cash as an item: the 'cash' item and arca_core's cash account are kept equal.
-- Moving/dropping/giving cash changes the account; AddMoney/RemoveMoney from any
-- script changes the item.
---------------------------------------------------------------------
local applying = {} -- [inventory id] = true while we change the item ourselves

local function setCashItem(inv, amount)
    local current = countItem(inv, 'cash')
    if amount == current then return end
    applying[inv.id] = true
    if amount > current then
        if not addItem(inv, 'cash', amount - current) then
            print(('^3[arca_inventory] no free slot for cash in %s^7'):format(inv.id))
        end
    else
        removeItem(inv, 'cash', current - amount)
    end
    applying[inv.id] = nil
    inv.cash = countItem(inv, 'cash')
end

if InvConfig.CashItem then
    cashSync = function(inv)
        if applying[inv.id] or not inv.owner then return end
        local cash = countItem(inv, 'cash')
        if cash == inv.cash then return end
        inv.cash = cash
        local player = exports.arca_core:GetPlayer(inv.owner)
        if player and player.PlayerData.money.cash ~= cash then
            player.SetMoney('cash', cash, 'inventory')
        end
    end

    ---Makes the item match the account (on login and after AddMoney/RemoveMoney)
    function CashFromAccount(src)
        local inv = Inventories[PlayerInv[src]]
        local player = exports.arca_core:GetPlayer(src)
        if inv and player then setCashItem(inv, math.floor(player.PlayerData.money.cash or 0)) end
    end

    AddEventHandler('arca_core:server:onMoneyChange', function(src, account, _, reason)
        if account ~= 'cash' or reason == 'inventory' then return end
        CashFromAccount(src)
    end)
end

---------------------------------------------------------------------
-- Opening inventories
---------------------------------------------------------------------
local function distance(src, coords)
    return #(GetEntityCoords(GetPlayerPed(tostring(src))) - vector3(coords.x, coords.y, coords.z))
end

local function grantAccess(src, inv)
    Access[src] = Access[src] or {}
    Access[src][inv.id] = true
    Viewers[inv.id][src] = true
end

local function closeAll(src)
    for id in pairs(Access[src] or {}) do
        if Viewers[id] then Viewers[id][src] = nil end
        local inv = Inventories[id]
        if inv and inv.type ~= 'drop' and next(Viewers[id]) == nil then
            save(inv)
        end
    end
    Access[src] = {}
end

local function trunkSize(class)
    return InvConfig.Trunk.classes[class] or InvConfig.Trunk.default
end

local function nearestDrop(src)
    local best, bestDist
    for _, inv in pairs(Inventories) do
        if inv.type == 'drop' then
            local d = distance(src, inv.coords)
            if d <= InvConfig.Drop.range and (not bestDist or d < bestDist) then best, bestDist = inv, d end
        end
    end
    return best
end

local function inGroups(src, groups)
    if not groups then return true end
    local player = exports.arca_core:GetPlayer(src)
    if not player then return false end
    local job, gang = player.PlayerData.job, player.PlayerData.gang
    if groups[job.name] and job.grade.level >= groups[job.name] then return true end
    if gang and groups[gang.name] and gang.grade.level >= groups[gang.name] then return true end
    return false
end

---------------------------------------------------------------------
-- Shops (in-memory inventories; dragging out of them = buying)
---------------------------------------------------------------------
local ShopsById = {}

local function buildShops()
    for _, shop in ipairs(InvConfig.Shops or {}) do
        ShopsById[shop.id] = shop
        local items = {}
        for i, entry in ipairs(shop.items) do
            if def(entry.name) then
                items[i] = {
                    name = entry.name,
                    count = entry.stock or 1,
                    metadata = { price = entry.price, unlimited = entry.stock == nil },
                }
            end
        end
        create('shop:' .. shop.id, 'shop', shop.label, #shop.items, 0, items)
    end
end

---------------------------------------------------------------------
-- Dumpsters (in-memory, keyed by position)
---------------------------------------------------------------------
local searched = {} -- [id] = os.time() of last search

local function dumpsterAt(c)
    local id = ('dumpster:%d:%d:%d'):format(math.floor(c.x), math.floor(c.y), math.floor(c.z))
    local cfg = InvConfig.Dumpsters
    local inv = Inventories[id] or create(id, 'dumpster', 'Dumpster', cfg.slots, cfg.weight)
    return inv
end

local function searchDumpster(src, inv)
    local cfg = InvConfig.Dumpsters
    local now = os.time()
    if searched[inv.id] and now - searched[inv.id] < cfg.cooldown then
        return TriggerClientEvent('arca_core:notify', src, 'Someone already went through this one', 'inform')
    end
    searched[inv.id] = now

    local found = 0
    for _ = 1, math.random(cfg.rolls[1], cfg.rolls[2]) do
        for _, loot in ipairs(cfg.loot) do
            if math.random(100) <= loot.chance then
                if addItem(inv, loot.name, math.random(loot.min, loot.max)) then found = found + 1 end
                break
            end
        end
    end
    TriggerClientEvent('arca_core:notify', src, found > 0 and 'You found something' or 'Nothing but trash', found > 0 and 'success' or 'inform')
end

Arca.Callback.Register('arca_inventory:open', function(src, ctx)
    local own = Inventories[PlayerInv[src]]
    if not own then
        -- loaded before this resource saw them log in: load on demand
        local player = exports.arca_core:GetPlayer(src)
        if not player then return nil end
        loadPlayer(src, player.PlayerData.citizenid)
        own = Inventories[PlayerInv[src]]
        if not own then return nil end
    end
    closeAll(src)
    ctx = type(ctx) == 'table' and ctx or {}

    local others = {}
    local ped = GetPlayerPed(tostring(src))

    if ctx.glovebox then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 then
            local plate = trim(GetVehicleNumberPlateText(veh))
            others[#others + 1] = load('glovebox:' .. plate, 'glovebox', 'Glovebox · ' .. plate, InvConfig.Glovebox.slots, InvConfig.Glovebox.weight)
        end
    elseif ctx.trunk then
        local veh = NetworkGetEntityFromNetworkId(tonumber(ctx.trunk) or 0)
        if veh ~= 0 and DoesEntityExist(veh) and distance(src, GetEntityCoords(veh)) < 6.0 then
            local plate = trim(GetVehicleNumberPlateText(veh))
            local size = trunkSize(tonumber(ctx.class) or -1)
            if size.slots > 0 then
                others[#others + 1] = load('trunk:' .. plate, 'trunk', 'Trunk · ' .. plate, size.slots, size.weight)
            end
        end
    elseif ctx.stash then
        local stash = Stashes[ctx.stash]
        if stash and (not stash.coords or distance(src, stash.coords) <= (stash.range or 3.0)) then
            local allowed = true
            if stash.groups then
                local player = exports.arca_core:GetPlayer(src)
                local job = player and player.PlayerData.job.name
                local gang = player and player.PlayerData.gang.name
                allowed = (job and stash.groups[job] ~= nil) or (gang and stash.groups[gang] ~= nil)
            end
            if allowed then
                others[#others + 1] = load('stash:' .. ctx.stash, 'stash', stash.label, stash.slots, stash.weight)
            end
        end
    elseif ctx.shop then
        local shop = ShopsById[ctx.shop]
        local loc = shop and shop.locations[tonumber(ctx.location) or 0]
        if loc and distance(src, loc) <= 4.0 and inGroups(src, shop.groups) then
            others[#others + 1] = Inventories['shop:' .. shop.id]
        end
    elseif ctx.player then
        -- admins looking into another player's pockets (arca_admin)
        local target = tonumber(ctx.player)
        local inv = target and target ~= src and Inventories[PlayerInv[target]]
        if inv and exports.arca_core:HasPermission(src, 'admin') then
            others[#others + 1] = inv
        end
    elseif ctx.dumpster then
        local c = ctx.dumpster
        if type(c) == 'table' and tonumber(c.x) and distance(src, c) <= 3.5 then
            local inv = dumpsterAt(c)
            if ctx.search then searchDumpster(src, inv) end
            others[#others + 1] = inv
        end
    end

    -- the ground (nearest drop, or an empty one created on first use) only when on foot
    -- and not already looking into a trunk / glovebox / stash
    local onFoot = GetVehiclePedIsIn(ped, false) == 0 and #others == 0
    local drop = onFoot and nearestDrop(src)
    if drop then others[#others + 1] = drop end

    local list = {}
    for _, inv in ipairs(others) do
        grantAccess(src, inv)
        local p = payload(inv)
        if inv.type == 'player' then
            p.type = 'otherplayer'
            p.label = ('%s · ID %s'):format(GetPlayerName(tostring(ctx.player)) or 'Player', ctx.player)
        end
        list[#list + 1] = p
    end
    if onFoot and not drop then
        list[#list + 1] = { id = 'newdrop', type = 'drop', label = 'Ground', slots = InvConfig.Drop.slots, maxWeight = InvConfig.Drop.weight, weight = 0, items = {} }
    end

    return { player = payload(own), others = list }
end)

RegisterNetEvent('arca_inventory:close', function()
    closeAll(source)
end)

---------------------------------------------------------------------
-- Moving items between slots / inventories
---------------------------------------------------------------------
local function canUse(src, id)
    return id == PlayerInv[src] or (Access[src] and Access[src][id])
end

local function createDrop(src)
    dropCount = dropCount + 1
    local coords = GetEntityCoords(GetPlayerPed(tostring(src)))
    local inv = create(('drop:%d'):format(dropCount), 'drop', 'Ground', InvConfig.Drop.slots, InvConfig.Drop.weight)
    inv.coords = coords
    grantAccess(src, inv)
    return inv
end

---Would all these items fit (weight + slots) without changing anything?
local function fits(inv, lines)
    local weight = weightOf(inv)
    local free = 0
    for s = 1, inv.slots do if not inv.items[s] then free = free + 1 end end

    local newStacks = {}
    for _, line in ipairs(lines) do
        local d = def(line.name)
        weight = weight + d.weight * line.count
        if d.stack then
            if not stackSlot(inv, line.name, {}) and not newStacks[line.name] then
                newStacks[line.name] = true
                free = free - 1
            end
        else
            free = free - line.count
        end
    end
    return fitsWeight(inv, weight) and free >= 0
end

---Buys everything in the cart in one go, paid from the chosen account
---@param data { shop: string, method: 'cash'|'bank', items: { slot: number, count: number }[] }
Arca.Callback.Register('arca_inventory:checkout', function(src, data)
    if type(data) ~= 'table' or type(data.items) ~= 'table' then return false, 'Invalid cart' end
    local shopInv = Inventories['shop:' .. tostring(data.shop)]
    local own = Inventories[PlayerInv[src]]
    if not shopInv or not own or not canUse(src, shopInv.id) then return false, 'You are not at this shop' end

    local method = data.method
    local allowed = false
    for _, account in ipairs(InvConfig.ShopPayment) do
        if account == method then allowed = true end
    end
    if not allowed then return false, 'That payment method is not accepted' end

    -- validate every line against the shop's real prices and stock
    local lines, total = {}, 0
    for _, req in ipairs(data.items) do
        local slot = tonumber(req.slot)
        local entry = slot and shopInv.items[slot]
        local count = math.floor(tonumber(req.count) or 0)
        if not entry or count < 1 then return false, 'Your cart is out of date' end
        if not entry.metadata.unlimited and count > entry.count then
            return false, ('Only %d %s left'):format(entry.count, def(entry.name).label)
        end
        lines[#lines + 1] = { slot = slot, name = entry.name, count = count, entry = entry }
        total = total + entry.metadata.price * count
    end
    if #lines == 0 then return false, 'Your cart is empty' end

    if not fits(own, lines) then return false, 'You can\'t carry all of that' end

    local player = exports.arca_core:GetPlayer(src)
    if not player then return false, 'Player not found' end

    local shop = ShopsById[tostring(data.shop)] or {}
    if not shop.ignoreLicence then
        for _, line in ipairs(lines) do
            local licence = def(line.name).licence
            if licence and not HasLicence(src, licence) then
                return false, ('You need a %s to buy a %s'):format(LicenceLabel(licence), def(line.name).label)
            end
        end
    end
    if (player.PlayerData.money[method] or 0) < total then
        return false, ('Not enough %s ($%d needed)'):format(method, total)
    end
    if not player.RemoveMoney(method, total, 'shop: ' .. shopInv.label) then
        return false, 'Payment failed'
    end

    local stockChanged = false
    for _, line in ipairs(lines) do
        local d = def(line.name)
        if shop.register and d.weapon and not d.throwable and not d.noSerial then
            for _ = 1, line.count do
                local meta = RegisteredWeaponMeta(src, player, d)
                if addItem(own, line.name, 1, meta) then RegisterWeapon(player, d, meta) end
            end
        else
            addItem(own, line.name, line.count)
        end
        if not line.entry.metadata.unlimited then
            line.entry.count = line.entry.count - line.count
            if line.entry.count <= 0 then shopInv.items[line.slot] = nil end
            stockChanged = true
        end
    end
    if stockChanged then changed(shopInv) end

    TriggerClientEvent('arca_core:notify', src, ('Paid $%d by %s'):format(total, method), 'success')
    return true
end)

RegisterNetEvent('arca_inventory:move', function(data)
    local src = source
    if type(data) ~= 'table' then return end
    local fromId, toId = data.from, data.to
    local fromSlot, toSlot = tonumber(data.fromSlot), tonumber(data.toSlot)
    if not fromSlot or not canUse(src, fromId) then return end

    local from = Inventories[fromId]
    local item = from and from.items[fromSlot]
    if not item then return end

    local to
    if toId == 'newdrop' then
        if GetVehiclePedIsIn(GetPlayerPed(tostring(src)), false) ~= 0 then return end
        to = createDrop(src)
        toSlot = nil
    else
        if not canUse(src, toId) then return end
        to = Inventories[toId]
    end
    if not to then return end

    -- shops are read-only: you can only take from them, which buys the item
    if to.type == 'shop' then return end
    -- items leave a shop through the cart (arca_inventory:checkout), never by dragging
    if from.type == 'shop' then return end

    local d = def(item.name)
    local count = math.floor(tonumber(data.count) or item.count)
    count = math.max(1, math.min(count, item.count))
    if not d.stack then count = 1 end

    if toSlot and (toSlot < 1 or toSlot > to.slots) then return end
    if not toSlot then
        toSlot = d.stack and stackSlot(to, item.name, item.metadata) or freeSlot(to)
        if not toSlot then return TriggerClientEvent('arca_core:notify', src, 'No free slot', 'error') end
    end
    if from == to and fromSlot == toSlot then return end

    local target = to.items[toSlot]

    if not target or (target.name == item.name and d.stack and sameMeta(target.metadata, item.metadata)) then
        -- move / merge
        if from ~= to and not fitsWeight(to, weightOf(to) + d.weight * count) then
            return TriggerClientEvent('arca_core:notify', src, 'Not enough space', 'error')
        end
        if target then
            target.count = target.count + count
        else
            to.items[toSlot] = { name = item.name, count = count, metadata = item.metadata }
        end
        item.count = item.count - count
        if item.count <= 0 then from.items[fromSlot] = nil end
    else
        -- swap (whole stacks only)
        if count ~= item.count then return end
        if from ~= to then
            local td = def(target.name)
            local toWeight = weightOf(to) - td.weight * target.count + d.weight * item.count
            local fromWeight = weightOf(from) - d.weight * item.count + td.weight * target.count
            if not fitsWeight(to, toWeight) or not fitsWeight(from, fromWeight) then
                return TriggerClientEvent('arca_core:notify', src, 'Not enough space', 'error')
            end
        end
        from.items[fromSlot], to.items[toSlot] = target, item
    end

    if from ~= to then changed(from) end
    changed(to)
    if to.type == 'drop' and to.coords then syncDrops() end
end)

---------------------------------------------------------------------
-- Use / give
---------------------------------------------------------------------
RegisterNetEvent('arca_inventory:use', function(slot)
    local src = source
    local inv = Inventories[PlayerInv[src]]
    local item = inv and inv.items[tonumber(slot)]
    if not item then return end
    local d0 = def(item.name)
    -- weapons, ammo and attachments are handled by server/weapons.lua
    if d0.weapon or d0.ammoType or d0.attachment or d0.repair then
        return WeaponUse(src, inv, tonumber(slot), item, d0)
    end
    local fn = exports.arca_core:CanUseItem(item.name)
    if not fn then
        return TriggerClientEvent('arca_core:notify', src, ('%s can\'t be used'):format(def(item.name).label), 'error')
    end
    local d = def(item.name)
    if d.close then TriggerClientEvent('arca_inventory:client:forceClose', src) end
    fn(src, { name = item.name, label = d.label, slot = tonumber(slot), count = item.count, amount = item.count, metadata = item.metadata, info = item.metadata })
end)

RegisterNetEvent('arca_inventory:give', function(target, slot, count)
    local src = source
    target = tonumber(target)
    local inv = Inventories[PlayerInv[src]]
    local other = target and Inventories[PlayerInv[target]]
    local item = inv and inv.items[tonumber(slot)]
    if not item or not other or target == src then return end

    local srcCoords = GetEntityCoords(GetPlayerPed(tostring(src)))
    if distance(target, srcCoords) > InvConfig.GiveRange then
        return TriggerClientEvent('arca_core:notify', src, 'Player is too far away', 'error')
    end

    count = math.max(1, math.min(math.floor(tonumber(count) or item.count), item.count))
    if not canCarry(other, item.name, count) then
        return TriggerClientEvent('arca_core:notify', src, 'They can\'t carry that', 'error')
    end
    local name, metadata = item.name, item.metadata
    if removeItem(inv, name, count, tonumber(slot)) and addItem(other, name, count, metadata) then
        local label = def(name).label
        TriggerClientEvent('arca_core:notify', src, ('You gave %dx %s'):format(count, label), 'success')
        TriggerClientEvent('arca_core:notify', target, ('You received %dx %s'):format(count, label), 'success')
        TriggerClientEvent('arca_inventory:client:giveAnim', src)
    end
end)

---------------------------------------------------------------------
-- Exports (qb-style signatures so the arca_core qb bridge can use them)
---------------------------------------------------------------------
local function formatItem(slot, item)
    if not item then return nil end
    local d = def(item.name) or {}
    return {
        name = item.name, label = d.label, slot = slot, count = item.count, amount = item.count,
        metadata = item.metadata, info = item.metadata, weight = d.weight, description = d.description,
    }
end

exports('AddItem', function(target, name, count, slot, metadata)
    local inv = resolve(target)
    return inv and addItem(inv, name, count, metadata, tonumber(slot)) or false
end)

exports('RemoveItem', function(target, name, count, slot)
    local inv = resolve(target)
    return inv and removeItem(inv, name, count, tonumber(slot)) or false
end)

exports('GetItemCount', function(target, name)
    local inv = resolve(target)
    return inv and countItem(inv, name) or 0
end)

exports('HasItem', function(target, items, amount)
    local inv = resolve(target)
    if not inv then return false end
    amount = amount or 1
    if type(items) == 'string' then return countItem(inv, items) >= amount end
    for k, v in pairs(items) do
        local name, need = type(k) == 'number' and v or k, type(k) == 'number' and amount or v
        if countItem(inv, name) < need then return false end
    end
    return true
end)

exports('CanCarryItem', function(target, name, count)
    local inv = resolve(target)
    return inv and canCarry(inv, name, count or 1) or false
end)

exports('GetItemByName', function(target, name)
    local inv = resolve(target)
    if not inv then return nil end
    for slot = 1, inv.slots do
        local item = inv.items[slot]
        if item and item.name == name then return formatItem(slot, item) end
    end
end)

exports('GetItemsByName', function(target, name)
    local inv = resolve(target)
    local list = {}
    if not inv then return list end
    for slot = 1, inv.slots do
        local item = inv.items[slot]
        if item and item.name == name then list[#list + 1] = formatItem(slot, item) end
    end
    return list
end)

exports('GetItemBySlot', function(target, slot)
    local inv = resolve(target)
    return inv and formatItem(tonumber(slot), inv.items[tonumber(slot)])
end)

exports('GetInventory', function(target)
    local inv = resolve(target)
    if not inv then return nil end
    local list = {}
    for slot, item in pairs(inv.items) do list[#list + 1] = formatItem(slot, item) end
    return list
end)

exports('ClearInventory', function(target)
    local inv = resolve(target)
    if not inv then return false end
    inv.items = {}
    changed(inv)
    return true
end)

exports('SetInventory', function(target, items)
    local inv = resolve(target)
    if not inv then return false end
    local list = {}
    for _, item in pairs(items or {}) do
        list[#list + 1] = { slot = item.slot, name = item.name, count = item.count or item.amount, metadata = item.metadata or item.info }
    end
    inv.items = fromList(list, inv.slots)
    changed(inv)
    return true
end)

---@param id string
---@param data { label: string, slots: number, weight: number, coords?: vector3, range?: number, groups?: table<string, number> }
exports('RegisterStash', function(id, data)
    Stashes[id] = data
end)

exports('GetItems', function() return InvItems end)

---Opens another player's inventory next to the admin's own (permission checked on open)
exports('OpenPlayerInventory', function(src, target)
    TriggerClientEvent('arca_inventory:client:openPlayer', src, target)
end)

---------------------------------------------------------------------
-- Startup / saving
---------------------------------------------------------------------
CreateThread(function()
    -- make sure the table exists even if sql/inventory.sql was never run
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `arca_inventories` (
            `id` VARCHAR(100) NOT NULL,
            `items` LONGTEXT NOT NULL,
            `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    buildShops()

    -- give qb-style resources the item list through the arca_core bridge
    local qbItems = {}
    for name, d in pairs(InvItems) do
        qbItems[name] = {
            name = name, label = d.label, weight = d.weight, type = 'item', image = name .. '.png',
            unique = not d.stack, useable = true, shouldClose = d.close or false, description = d.description,
        }
    end
    pcall(function() exports.arca_core:AddItems(qbItems) end)

    -- players already in game when the resource (re)starts
    for _, src in ipairs(exports.arca_core:GetPlayers()) do
        local player = exports.arca_core:GetPlayer(src)
        if player then loadPlayer(src, player.PlayerData.citizenid) end
    end
end)

CreateThread(function()
    while true do
        Wait(InvConfig.SaveInterval * 1000)
        for _, inv in pairs(Inventories) do save(inv) end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, inv in pairs(Inventories) do save(inv) end
end)

-- internal access for server/usable.lua
InvInternal = {
    resolve = resolve, removeItem = removeItem, addItem = addItem, countItem = countItem,
    canCarry = canCarry, changed = changed, def = def, inGroups = inGroups,
    playerInv = function(src) return Inventories[PlayerInv[src]] end,
}

---------------------------------------------------------------------
-- Admin commands
---------------------------------------------------------------------
exports.arca_core:AddCommand('giveitem', 'Give an item: /giveitem id|me item count', 'admin', function(src, args)
    local function reply(msg, kind)
        if src == 0 then return print(msg) end
        TriggerClientEvent('arca_core:notify', src, msg, kind)
    end

    local target = args[1] == 'me' and src or tonumber(args[1])
    local name = args[2] and args[2]:lower()
    local count = math.floor(tonumber(args[3]) or 1)

    if not target or target == 0 or not name then
        return reply('Usage: /giveitem id|me item count', 'error')
    end
    if not def(name) then return reply(('Item "%s" does not exist'):format(name), 'error') end
    if count < 1 then return reply('Count must be at least 1', 'error') end

    local inv = resolve(target)
    if not inv then return reply('Player is not online or not logged in', 'error') end
    if not addItem(inv, name, count) then
        return reply('They don\'t have enough space or weight for that', 'error')
    end

    local label = def(name).label
    reply(('Gave %dx %s to %s'):format(count, label, target == src and 'yourself' or ('ID ' .. target)), 'success')
    if target ~= src then
        TriggerClientEvent('arca_core:notify', target, ('You received %dx %s'):format(count, label), 'success')
    end
end)
