-- Equipping weapon items, ammo / durability tracking, reloading and attachments.

local UNARMED = `WEAPON_UNARMED`
local equipped     -- { slot, serial, name, hash, ammoItem, components = { [name]=true } }
local lastAmmo     -- ammo last reported to the server
local inventory    -- our latest player inventory payload

local function itemInSlot(slot)
    for _, item in ipairs(inventory and inventory.items or {}) do
        if item.slot == slot then return item end
    end
end

local function itemBySerial(serial)
    for _, item in ipairs(inventory and inventory.items or {}) do
        if item.metadata and item.metadata.serial == serial and InvItems[item.name] and InvItems[item.name].weapon then
            return item
        end
    end
end

---------------------------------------------------------------------
-- Attachments
---------------------------------------------------------------------
local function applyComponents(ped, hash, weaponName, list)
    local wanted = {}
    for _, name in ipairs(list or {}) do
        local d = InvItems[name]
        local component = d and d.attachment and d.attachment[weaponName]
        if component then wanted[joaat(component)] = true end
    end
    -- remove components that were detached, add the new ones
    for _, d in pairs(InvItems) do
        local component = d.attachment and d.attachment[weaponName]
        if component then
            local h = joaat(component)
            local has = HasPedGotWeaponComponent(ped, hash, h)
            if wanted[h] and not has then
                GiveWeaponComponentToPed(ped, hash, h)
            elseif not wanted[h] and has then
                RemoveWeaponComponentFromPed(ped, hash, h)
            end
        end
    end
end

---------------------------------------------------------------------
-- Equip / holster
---------------------------------------------------------------------
local function reportAmmo(force)
    if not equipped or not (equipped.ammoItem or equipped.throwable) then return end
    local ammo = GetAmmoInPedWeapon(PlayerPedId(), equipped.hash)
    if force or ammo ~= lastAmmo then
        if lastAmmo and ammo < lastAmmo then
            if equipped.throwable then
                -- every throw uses up one item from the stack
                TriggerServerEvent('arca_inventory:weapon:thrown', equipped.slot, lastAmmo - ammo)
            else
                TriggerServerEvent('arca_inventory:weapon:ammo', equipped.slot, equipped.serial, ammo)
            end
        end
        lastAmmo = ammo
    end
end

local function holster(silent)
    if not equipped then return end
    local ped = PlayerPedId()
    if not silent then reportAmmo(true) end
    RemoveWeaponFromPed(ped, equipped.hash)
    SetCurrentPedWeapon(ped, UNARMED, true)
    equipped, lastAmmo = nil, nil
end

local function equip(slot, item, info)
    local ped = PlayerPedId()
    local hash = joaat(info.weapon)
    if equipped then holster() end

    GiveWeaponToPed(ped, hash, 0, false, true)
    -- throwables: the "ammo" is the number of items in the stack
    local ammo = info.throwable and item.count or (item.metadata.ammo or 0)
    if info.ammo or info.throwable then
        SetPedAmmo(ped, hash, ammo)
    end
    applyComponents(ped, hash, info.weapon, item.metadata.components)
    SetCurrentPedWeapon(ped, hash, true)

    equipped = {
        slot = slot, serial = item.metadata.serial, name = item.name, weapon = info.weapon,
        hash = hash, ammoItem = info.ammo, throwable = info.throwable,
    }
    lastAmmo = (info.ammo or info.throwable) and ammo or nil
end

RegisterNetEvent('arca_inventory:client:useWeapon', function(slot, item, info)
    if equipped and equipped.slot == slot and equipped.serial == item.metadata.serial then
        holster()
    else
        equip(slot, item, info)
    end
end)

RegisterNetEvent('arca_inventory:client:disarm', function()
    holster(true)
end)

exports('GetEquippedWeapon', function() return equipped end)
exports('Disarm', function() holster() end)

---------------------------------------------------------------------
-- Reloading: move ammo items from the inventory into the equipped weapon
---------------------------------------------------------------------
local reloading = false

local function reload()
    if not equipped or not equipped.ammoItem or reloading then return end
    reloading = true
    reportAmmo(true)
    local ammo = Arca.Callback.Await('arca_inventory:weapon:reload', equipped and equipped.slot, equipped and equipped.serial)
    if ammo and equipped then
        local ped = PlayerPedId()
        SetPedAmmo(ped, equipped.hash, ammo)
        lastAmmo = ammo
        MakePedReload(ped)
    end
    reloading = false
end

RegisterNetEvent('arca_inventory:client:reload', reload)
RegisterCommand('+arca_reload', reload, false)
RegisterCommand('-arca_reload', function() end, false)
RegisterKeyMapping('+arca_reload', 'Load ammo into weapon', 'keyboard', InvConfig.Weapons.ReloadKey)

RegisterNetEvent('arca_inventory:client:useAttachment', function(slot)
    if not equipped then
        return exports.arca_core:Notify('Equip the weapon first', 'error')
    end
    TriggerServerEvent('arca_inventory:weapon:attach', equipped.slot, equipped.serial, slot)
end)

---------------------------------------------------------------------
-- Keep the equipped weapon in sync with the inventory
---------------------------------------------------------------------
RegisterNetEvent('arca_inventory:client:update', function(data)
    if data.type ~= 'player' then return end
    inventory = data
    if not equipped then return end

    local item = equipped.serial and itemBySerial(equipped.serial) or itemInSlot(equipped.slot)
    if not item or item.name ~= equipped.name then
        -- moved out of the inventory (dropped, given, stored...)
        return holster(true)
    end
    equipped.slot = item.slot

    local ped = PlayerPedId()
    if equipped.throwable then
        -- stack grew (picked more up) or shrank (moved some away)
        if item.count ~= lastAmmo then
            SetPedAmmo(ped, equipped.hash, item.count)
            lastAmmo = item.count
        end
        return
    end
    applyComponents(ped, equipped.hash, equipped.weapon, item.metadata.components)
    if equipped.ammoItem and item.metadata.ammo and item.metadata.ammo > (lastAmmo or 0) then
        SetPedAmmo(ped, equipped.hash, item.metadata.ammo)
        lastAmmo = item.metadata.ammo
    end
end)

---------------------------------------------------------------------
-- Loops
---------------------------------------------------------------------
-- ammo reporting (throttled) + holster on death / weapon switch
CreateThread(function()
    while true do
        if equipped then
            local ped = PlayerPedId()
            if IsEntityDead(ped) then
                holster()
            elseif GetSelectedPedWeapon(ped) ~= equipped.hash and not IsPedInAnyVehicle(ped, false) then
                holster()
            else
                reportAmmo(false)
            end
            Wait(1000)
        else
            Wait(500)
        end
    end
end)

-- block the weapon wheel and weapons that didn't come from the inventory
CreateThread(function()
    local cfg = InvConfig.Weapons
    local nextStrip = 0
    SetPedDropsWeaponsWhenDead(PlayerPedId(), false)
    while true do
        local sleep = 500
        if LocalPlayer.state.isLoggedIn then
            if cfg.DisableWeaponWheel then
                sleep = 0
                DisableControlAction(0, 37, true)   -- weapon wheel
                HudWeaponWheelIgnoreSelection()
            end
            if cfg.StripUnknownWeapons and GetGameTimer() >= nextStrip then
                nextStrip = GetGameTimer() + 500
                local ped = PlayerPedId()
                local selected = GetSelectedPedWeapon(ped)
                if selected ~= UNARMED and (not equipped or selected ~= equipped.hash) and not IsPedInAnyVehicle(ped, false) then
                    RemoveAllPedWeapons(ped, true)
                    if equipped then holster(true) end
                end
            end
        end
        Wait(sleep)
    end
end)

---------------------------------------------------------------------
-- Repairs
---------------------------------------------------------------------
local repairing = false

-- repair kit: fixes the weapon in your hands
RegisterNetEvent('arca_inventory:client:useRepairKit', function(kitSlot)
    if repairing then return end
    if not equipped or equipped.throwable then
        return exports.arca_core:Notify('Hold the weapon you want to repair', 'error')
    end
    local slot, serial = equipped.slot, equipped.serial
    repairing = true
    holster()
    local done = exports.arca_core:Progress({
        label = 'Repairing weapon',
        duration = 5000,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 1 },
    })
    repairing = false
    if done then TriggerServerEvent('arca_inventory:weapon:repairKit', slot, serial, kitSlot) end
end)

-- repair benches: pick a damaged weapon, pay, wait, done
local function useBench(index)
    if repairing then return end
    local data = Arca.Callback.Await('arca_inventory:bench:list', index)
    if not data then return end
    if #data.list == 0 then
        return exports.arca_core:Notify('None of your weapons need repairs', 'inform')
    end

    local options = {}
    for _, w in ipairs(data.list) do
        options[#options + 1] = {
            title = w.label,
            description = ('Durability %d%% · $%d (%s)'):format(w.durability, w.cost, data.account),
            icon = w.icon or 'fa-solid fa-gun',
            onSelect = function()
                if equipped and equipped.slot == w.slot then holster() end
                repairing = true
                local done = exports.arca_core:Progress({
                    label = ('Repairing %s'):format(w.label),
                    duration = data.duration,
                    canCancel = true,
                    disable = { move = true, car = true, combat = true },
                    anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 1 },
                })
                repairing = false
                if done then Arca.Callback.Await('arca_inventory:bench:repair', index, w.slot, w.serial) end
            end,
        }
    end
    exports.arca_core:RegisterContext({ id = 'arca_inventory:bench', title = 'Weapon Bench', options = options })
    exports.arca_core:ShowContext('arca_inventory:bench')
end

local function registerBenches()
    for index, bench in ipairs(InvConfig.Weapons.RepairBenches or {}) do
        exports.arca_target:addSphereZone({
            name = 'arca_inventory:bench:' .. index,
            coords = bench.coords,
            radius = 1.2,
            options = {
                { name = 'arca_inventory:bench', label = bench.label or 'Repair weapons', icon = 'fa-solid fa-screwdriver-wrench', distance = 2.0,
                  onSelect = function() useBench(index) end },
            },
        })
    end
end

if GetResourceState('arca_target') == 'started' then registerBenches() end
AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'arca_target' then registerBenches() end
end)

-- without arca_target: walk up and press E
CreateThread(function()
    local shown = false
    while true do
        local sleep = 750
        if GetResourceState('arca_target') ~= 'started' then
            local coords = GetEntityCoords(PlayerPedId())
            local near
            for index, bench in ipairs(InvConfig.Weapons.RepairBenches or {}) do
                if #(coords - bench.coords) < 1.8 then near = index break end
            end
            if near then
                sleep = 0
                if not shown then
                    exports.arca_core:ShowTextUI('[E] Repair weapons', { icon = 'fa-solid fa-screwdriver-wrench' })
                    shown = true
                end
                if IsControlJustPressed(0, 38) then useBench(near) end
            elseif shown then
                exports.arca_core:HideTextUI()
                shown = false
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('arca_core:client:onPlayerUnloaded', function() holster(true) end)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then holster(true) end
end)
