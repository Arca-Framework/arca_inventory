local isOpen = false
local myInventory      -- latest payload of our own inventory (for HasItem / hotbar)
local drops = {}       -- ground drops to draw markers for
local openTrunk        -- vehicle whose trunk we opened

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function itemsForNui()
    local list = {}
    for name, d in pairs(InvItems) do
        local rarity = InvConfig.Rarity.Enabled and (d.rarity or InvConfig.Rarity.Default) or nil
        list[name] = { label = d.label, weight = d.weight, stack = d.stack, icon = d.icon, description = d.description, rarity = rarity, weapon = d.weapon ~= nil and not d.throwable, throwable = d.throwable, attachment = d.attachment ~= nil, chip = d.chip }
    end
    return list
end

local function closestPlayer(maxDist)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local best, bestDist = nil, maxDist
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local d = #(coords - GetEntityCoords(GetPlayerPed(pid)))
            if d < bestDist then best, bestDist = pid, d end
        end
    end
    return best and GetPlayerServerId(best)
end

---Vehicle whose trunk the player is standing at
local function trunkVehicle()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local best, bestDist
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if #(coords - GetEntityCoords(veh)) < 8.0 then
            local min, max = GetModelDimensions(GetEntityModel(veh))
            local rear = GetOffsetFromEntityInWorldCoords(veh, 0.0, min.y - 0.2, 0.0)
            local d = #(coords - rear)
            if d <= InvConfig.Trunk.range and (not bestDist or d < bestDist) then best, bestDist = veh, d end
        end
    end
    return best
end

---------------------------------------------------------------------
-- Open / close
---------------------------------------------------------------------
---------------------------------------------------------------------
-- Busy state: while busy the inventory won't open and hotbar keys do nothing
---------------------------------------------------------------------
local busyReasons = {} -- [reason] = true, set by SetBusy from any resource

---Why the player can't use the inventory right now, or nil if they can
local function busyReason()
    if next(busyReasons) then return 'busy' end
    if LocalPlayer.state.invBusy then return 'busy' end            -- server: Player(src).state.invBusy = true
    if exports.arca_core:ProgressActive() then return 'busy' end    -- any arca_core progress bar
    local ped = PlayerPedId()
    if IsEntityDead(ped) then return 'dead' end
    if IsPedRagdoll(ped) or IsPedFalling(ped) or IsPedGettingIntoAVehicle(ped) then return 'busy' end
    local meta = (exports.arca_core:GetPlayerData() or {}).metadata or {}
    if meta.isdead or meta.inlaststand then return 'dead' end
    if meta.ishandcuffed or LocalPlayer.state.isCuffed then return 'cuffed' end
end

local lastBusyNotify = 0
local function blockedByBusy()
    local reason = busyReason()
    if not reason then return false end
    if reason ~= 'dead' and GetGameTimer() - lastBusyNotify > 1500 then
        lastBusyNotify = GetGameTimer()
        exports.arca_core:Notify(reason == 'cuffed' and 'You can\'t reach your pockets' or 'You\'re busy right now', 'error')
    end
    return true
end

local closeInventory -- defined below

---Mark the player busy (or not) from any resource. Each reason is tracked on its own, so two
---scripts can be busy at once. Going busy closes an open inventory.
---@param state boolean
---@param reason? string defaults to the calling resource's name
exports('SetBusy', function(state, reason)
    reason = reason or GetInvokingResource() or 'unknown'
    busyReasons[reason] = state and true or nil
    if state and closeInventory then closeInventory() end
end)
exports('IsBusy', function() return busyReason() ~= nil end)

-- the server set the statebag: close if it's open
AddStateBagChangeHandler('invBusy', ('player:%s'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
    if value and closeInventory then closeInventory() end
end)

local function openInventory(ctx)
    if isOpen or not exports.arca_core:IsLoggedIn() or IsPauseMenuActive() then return end
    if blockedByBusy() then return end
    local ped = PlayerPedId()

    ctx = ctx or {}
    if not (ctx.stash or ctx.shop or ctx.dumpster or ctx.player) then
        if IsPedInAnyVehicle(ped, false) then
            ctx.glovebox = true
        else
            -- a specific vehicle (from arca_target), otherwise whichever trunk we're standing at
            local veh = ctx.vehicle or trunkVehicle()
            ctx.vehicle = nil
            if veh and GetVehicleDoorLockStatus(veh) < 2 and NetworkGetEntityIsNetworked(veh) then
                ctx.trunk = NetworkGetNetworkIdFromEntity(veh)
                ctx.class = GetVehicleClass(veh)
                openTrunk = veh
                SetVehicleDoorOpen(veh, 5, false, false)
            end
        end
    end

    local data = Arca.Callback.Await('arca_inventory:open', ctx)
    if not data then
        if openTrunk and DoesEntityExist(openTrunk) then SetVehicleDoorShut(openTrunk, 5, false) end
        openTrunk = nil
        print('^1[arca_inventory] server returned no inventory - check the server console for errors^7')
        return exports.arca_core:Notify('Inventory failed to load', 'error')
    end
    isOpen = true
    SendNUIMessage({ action = 'open', data = { player = data.player, others = data.others, items = itemsForNui(), payment = InvConfig.ShopPayment, rarity = InvConfig.Rarity, useWeight = InvConfig.UseWeight } })
    SetNuiFocus(true, true)
end

function closeInventory()
    if not isOpen then return end
    isOpen = false
    SendNUIMessage({ action = 'close' })
    SetNuiFocus(false, false)
    TriggerServerEvent('arca_inventory:close')
    if openTrunk and DoesEntityExist(openTrunk) then SetVehicleDoorShut(openTrunk, 5, false) end
    openTrunk = nil
end

-- not while another UI has focus (e.g. typing an 'i' on the phone)
RegisterCommand('inventory', function() if not IsNuiFocused() then openInventory() end end, false)
RegisterKeyMapping('inventory', 'Open inventory', 'keyboard', InvConfig.OpenKey)

-- hotbar: keys 1-5 use the first slots of your inventory
for i = 1, InvConfig.HotbarSlots do
    RegisterCommand('hotbar' .. i, function()
        if isOpen or not exports.arca_core:IsLoggedIn() or IsNuiFocused() then return end
        if blockedByBusy() then return end
        if myInventory then
            SendNUIMessage({ action = 'hotbar', data = { inventory = myInventory, slot = i } })
        end
        TriggerServerEvent('arca_inventory:use', i)
    end, false)
    RegisterKeyMapping('hotbar' .. i, ('Use hotbar slot %d'):format(i), 'keyboard', tostring(i))
end

exports('OpenStash', function(id) openInventory({ stash = id }) end)
exports('OpenTrunk', function(vehicle) openInventory({ vehicle = vehicle }) end)

---------------------------------------------------------------------
-- arca_target: look at the back of a vehicle -> "Open trunk"
---------------------------------------------------------------------
local function rearOf(veh)
    local min = GetModelDimensions(GetEntityModel(veh))
    return GetOffsetFromEntityInWorldCoords(veh, 0.0, min.y - 0.2, 0.0)
end

local function hasTrunk(veh)
    local size = InvConfig.Trunk.classes[GetVehicleClass(veh)] or InvConfig.Trunk.default
    return size.slots > 0
end

-- arca_target can report 'started' before its exports exist (resources start alphabetically),
-- so keep trying for a while instead of checking once
local function whenTargetReady(fn)
    CreateThread(function()
        for _ = 1, 60 do
            if GetResourceState('arca_target') == 'started' and pcall(fn) then return end
            Wait(500)
        end
    end)
end

local function registerTarget()
    exports.arca_target:addGlobalVehicle({
        {
            name = 'arca_inventory:trunk',
            label = 'Open trunk',
            icon = 'fa-solid fa-car-rear',
            distance = 3.0,
            canInteract = function(veh, _, coords)
                if isOpen or IsPedInAnyVehicle(PlayerPedId(), false) then return false end
                if GetVehicleDoorLockStatus(veh) >= 2 or not hasTrunk(veh) then return false end
                -- only when aiming at the back of the vehicle and standing near it
                local rear = rearOf(veh)
                return #(coords - rear) < 1.8 and #(GetEntityCoords(PlayerPedId()) - rear) < InvConfig.Trunk.range + 1.0
            end,
            onSelect = function(data)
                openInventory({ vehicle = data.entity })
            end,
        },
    })
end

-- arca_target may start after us, or restart (which clears its options), so register whenever it starts
whenTargetReady(registerTarget)
AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'arca_target' then registerTarget() end
end)
exports('CloseInventory', closeInventory)

---------------------------------------------------------------------
-- Server events
---------------------------------------------------------------------
RegisterNetEvent('arca_inventory:client:update', function(data)
    -- we only ever receive our own player inventory
    if data.type == 'player' then myInventory = data end
    if isOpen then SendNUIMessage({ action = 'update', data = data }) end
end)

RegisterNetEvent('arca_inventory:client:forceClose', closeInventory)

-- arca_admin: open someone else's inventory next to ours
RegisterNetEvent('arca_inventory:client:openPlayer', function(target)
    openInventory({ player = target })
end)

RegisterNetEvent('arca_inventory:client:drops', function(list)
    drops = list
end)

RegisterNetEvent('arca_inventory:client:heal', function(amount)
    local ped = PlayerPedId()
    local max = GetEntityMaxHealth(ped)
    SetEntityHealth(ped, math.min(max, GetEntityHealth(ped) + math.floor((max - 100) * amount / 100)))
end)

RegisterNetEvent('arca_inventory:client:repairVehicle', function()
    local veh
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    for _, v in ipairs(GetGamePool('CVehicle')) do
        if #(coords - GetEntityCoords(v)) < 5.0 then veh = v break end
    end
    if not veh then return end
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleUndriveable(veh, false)
    exports.arca_core:Notify('Engine repaired', 'success')
end)

RegisterNetEvent('arca_inventory:client:giveAnim', function()
    local ped = PlayerPedId()
    RequestAnimDict('mp_common')
    local timeout = GetGameTimer() + 2000
    while not HasAnimDictLoaded('mp_common') and GetGameTimer() < timeout do Wait(0) end
    TaskPlayAnim(ped, 'mp_common', 'givetake1_a', 8.0, -8.0, 2000, 48, 0, false, false, false)
end)

Arca.Callback.Register('arca_inventory:useProgress', function(progress)
    return exports.arca_core:Progress(progress)
end)

Arca.Callback.Register('arca_inventory:nearVehicle', function()
    local coords = GetEntityCoords(PlayerPedId())
    for _, v in ipairs(GetGamePool('CVehicle')) do
        if #(coords - GetEntityCoords(v)) < 5.0 then return true end
    end
    return false
end)

---------------------------------------------------------------------
-- NUI
---------------------------------------------------------------------
RegisterNUICallback('move', function(data, cb)
    cb(1)
    TriggerServerEvent('arca_inventory:move', data)
end)

RegisterNUICallback('checkout', function(data, cb)
    local ok, err = Arca.Callback.Await('arca_inventory:checkout', data)
    cb({ ok = ok, error = err })
end)

-- phone chips (right-click a phone): handled by arca_phone
RegisterNUICallback('chipAction', function(data, cb)
    cb(1)
    TriggerServerEvent('arca_phone:server:chipAction', data.slot, data.action)
end)

RegisterNUICallback('detach', function(data, cb)
    cb(1)
    TriggerServerEvent('arca_inventory:weapon:detach', data.slot, data.attachment)
end)

RegisterNUICallback('use', function(data, cb)
    cb(1)
    -- e.g. still eating the last item: don't start another use
    if blockedByBusy() then return end
    TriggerServerEvent('arca_inventory:use', data.slot)
end)

RegisterNUICallback('give', function(data, cb)
    cb(1)
    local target = closestPlayer(InvConfig.GiveRange)
    if not target then return exports.arca_core:Notify('Nobody nearby', 'error') end
    TriggerServerEvent('arca_inventory:give', target, data.slot, data.count)
end)

RegisterNUICallback('close', function(_, cb)
    cb(1)
    closeInventory()
end)

---------------------------------------------------------------------
-- Ground drop markers
---------------------------------------------------------------------
CreateThread(function()
    while true do
        local sleep = 1000
        if #drops > 0 then
            local coords = GetEntityCoords(PlayerPedId())
            for _, drop in ipairs(drops) do
                local c = drop.coords
                if c and #(coords - vector3(c.x, c.y, c.z)) < 25.0 then
                    sleep = 0
                    DrawMarker(2, c.x, c.y, c.z - 0.6, 0, 0, 0, 0, 180.0, 0, 0.25, 0.25, 0.2, 0, 255, 106, 160, true, true, 2, false, nil, nil, false)
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('arca_core:client:onPlayerUnloaded', function()
    closeInventory()
    myInventory = nil
end)

---------------------------------------------------------------------
-- Client exports
---------------------------------------------------------------------
local function count(name)
    local total = 0
    for _, item in ipairs(myInventory and myInventory.items or {}) do
        if item.name == name then total = total + item.count end
    end
    return total
end

exports('HasItem', function(items, amount)
    amount = amount or 1
    if type(items) == 'string' then return count(items) >= amount end
    for k, v in pairs(items) do
        local name, need = type(k) == 'number' and v or k, type(k) == 'number' and amount or v
        if count(name) < need then return false end
    end
    return true
end)

exports('GetItemCount', count)
exports('GetPlayerItems', function() return myInventory and myInventory.items or {} end)

---------------------------------------------------------------------
-- Shops: blips, shopkeeper peds (spawned when close) and how to open them
---------------------------------------------------------------------
local hasTarget = function() return GetResourceState('arca_target') == 'started' end
local shopPeds = {} -- ["shopId:index"] = ped

local function openShop(shopId, index)
    openInventory({ shop = shopId, location = index })
end

CreateThread(function()
    for _, shop in ipairs(InvConfig.Shops or {}) do
        if shop.blip then
            for _, loc in ipairs(shop.locations) do
                local blip = AddBlipForCoord(loc.x, loc.y, loc.z)
                SetBlipSprite(blip, shop.blip.sprite or 52)
                SetBlipColour(blip, shop.blip.color or 2)
                SetBlipScale(blip, shop.blip.scale or 0.7)
                SetBlipAsShortRange(blip, true)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName(shop.label)
                EndTextCommandSetBlipName(blip)
            end
        end
    end
end)

local function spawnShopPed(shop, index, loc)
    local model = joaat(shop.ped or 'mp_m_shopkeep_01')
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(0) end
    if not HasModelLoaded(model) then return end

    local ped = CreatePed(4, model, loc.x, loc.y, loc.z - 1.0, loc.w, false, true)
    SetModelAsNoLongerNeeded(model)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)

    -- pcall: arca_target may not be ready yet; the ped respawns (and registers) when it starts
    if hasTarget() then
        pcall(function()
            exports.arca_target:addLocalEntity(ped, {
                { name = 'arca_inventory:shop', label = ('Open %s'):format(shop.label), icon = 'fa-solid fa-store', distance = 3.0,
                  onSelect = function() openShop(shop.id, index) end },
            })
        end)
    end
    return ped
end

local promptShown = false

CreateThread(function()
    while true do
        local coords = GetEntityCoords(PlayerPedId())
        local nearPrompt
        for _, shop in ipairs(InvConfig.Shops or {}) do
            for index, loc in ipairs(shop.locations) do
                local key = shop.id .. ':' .. index
                local dist = #(coords - vector3(loc.x, loc.y, loc.z))
                if dist < 40.0 and not shopPeds[key] then
                    shopPeds[key] = spawnShopPed(shop, index, loc)
                elseif dist >= 50.0 and shopPeds[key] then
                    DeleteEntity(shopPeds[key])
                    shopPeds[key] = nil
                end
                if dist < 2.5 and not hasTarget() then nearPrompt = { shop = shop, index = index } end
            end
        end

        -- without arca_target: walk up and press E
        if nearPrompt and not isOpen then
            exports.arca_core:ShowTextUI(('[E] %s'):format(nearPrompt.shop.label), { icon = 'fa-solid fa-store' })
            promptShown = true
            local untilTime = GetGameTimer() + 500
            while GetGameTimer() < untilTime do
                if IsControlJustPressed(0, 38) then
                    exports.arca_core:HideTextUI()
                    promptShown = false
                    openShop(nearPrompt.shop.id, nearPrompt.index)
                    break
                end
                Wait(0)
            end
        else
            -- only hide the prompt we showed, never another resource's text UI
            if promptShown then exports.arca_core:HideTextUI() promptShown = false end
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, ped in pairs(shopPeds) do DeleteEntity(ped) end
end)

---------------------------------------------------------------------
-- Dumpsters: third eye -> search (progress) -> dumpster opens with whatever was found
---------------------------------------------------------------------
local function searchDumpster(entity)
    local c = GetEntityCoords(entity)
    TaskTurnPedToFaceEntity(PlayerPedId(), entity, 800)
    Wait(800)
    local done = exports.arca_core:Progress({
        label = 'Searching dumpster',
        duration = InvConfig.Dumpsters.searchTime,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'amb@prop_human_bum_bin@base', clip = 'base', flag = 1 },
    })
    if done then openInventory({ dumpster = { x = c.x, y = c.y, z = c.z }, search = true }) end
end

local function registerDumpsters()
    exports.arca_target:addModel(InvConfig.Dumpsters.models, {
        { name = 'arca_inventory:dumpster', label = 'Search dumpster', icon = 'fa-solid fa-dumpster', distance = 2.0,
          canInteract = function() return not isOpen end,
          onSelect = function(data) searchDumpster(data.entity) end },
    })
end

whenTargetReady(registerDumpsters)
AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= 'arca_target' then return end
    registerDumpsters()
    -- arca_target forgets local-entity options when it restarts: respawn shopkeepers so they re-register
    for key, ped in pairs(shopPeds) do DeleteEntity(ped) shopPeds[key] = nil end
end)

-- radial menu entry
CreateThread(function()
    exports.arca_core:AddRadialItem({ id = 'arca_inventory', label = 'Inventory', icon = 'fa-solid fa-box-open', onSelect = function() openInventory() end })
end)
