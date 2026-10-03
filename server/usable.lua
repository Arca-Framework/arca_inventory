-- Default usable items. Other resources register their own with
-- exports.arca_core:CreateUseableItem(name, function(source, item) ... end)

local function useWithProgress(src, item, progress, onDone)
    -- plays the animation / progress bar on the client and waits for it
    local done = Arca.Callback.Await('arca_inventory:useProgress', src, progress.duration + 5000, progress)
    if not done then return end
    if InvInternal.removeItem(InvInternal.resolve(src), item.name, 1, item.slot) then
        onDone()
    end
end

local function addStatus(src, key, amount)
    local player = exports.arca_core:GetPlayer(src)
    if not player then return end
    local value = math.min(100, (player.PlayerData.metadata[key] or 0) + amount)
    player.SetMetaData(key, value)
end

local food = {
    water = { thirst = 35, label = 'Drinking water', anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' }, prop = { model = 'prop_ld_flow_bottle', bone = 18905, pos = vec3(0.12, 0.008, 0.03), rot = vec3(240.0, -60.0, 0.0) } },
    coffee = { thirst = 20, stress = -10, label = 'Drinking coffee', anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' }, prop = { model = 'p_amb_coffeecup_01', bone = 28422, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0) } },
    sandwich = { hunger = 35, label = 'Eating sandwich', anim = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger' }, prop = { model = 'prop_sandwich_01', bone = 18905, pos = vec3(0.13, 0.05, 0.02), rot = vec3(-50.0, 16.0, 60.0) } },
    bread = { hunger = 25, label = 'Eating bread', anim = { dict = 'mp_player_inteat@burger', clip = 'mp_player_int_eat_burger' } },
}

for name, f in pairs(food) do
    exports.arca_core:CreateUseableItem(name, function(src, item)
        useWithProgress(src, item, { label = f.label, duration = 5000, anim = f.anim, prop = f.prop, disable = { combat = true } }, function()
            if f.hunger then addStatus(src, 'hunger', f.hunger) end
            if f.thirst then addStatus(src, 'thirst', f.thirst) end
            if f.stress then addStatus(src, 'stress', f.stress) end
        end)
    end)
end

exports.arca_core:CreateUseableItem('bandage', function(src, item)
    useWithProgress(src, item, { label = 'Applying bandage', duration = 4000, anim = { dict = 'missheistdockssetup1clipboard@idle_a', clip = 'idle_a' }, disable = { move = true, combat = true } }, function()
        TriggerClientEvent('arca_inventory:client:heal', src, 25)
    end)
end)

exports.arca_core:CreateUseableItem('medikit', function(src, item)
    useWithProgress(src, item, { label = 'Using medikit', duration = 8000, anim = { dict = 'missheistdockssetup1clipboard@idle_a', clip = 'idle_a' }, disable = { move = true, combat = true } }, function()
        TriggerClientEvent('arca_inventory:client:heal', src, 100)
    end)
end)

exports.arca_core:CreateUseableItem('armor', function(src, item)
    useWithProgress(src, item, { label = 'Putting on armor', duration = 5000, anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' }, disable = { move = true, combat = true } }, function()
        SetPedArmour(GetPlayerPed(tostring(src)), 100)
        local player = exports.arca_core:GetPlayer(src)
        if player then player.SetMetaData('armor', 100) end
    end)
end)

exports.arca_core:CreateUseableItem('repairkit', function(src, item)
    local ok = Arca.Callback.Await('arca_inventory:nearVehicle', src)
    if not ok then return TriggerClientEvent('arca_core:notify', src, 'No vehicle nearby', 'error') end
    useWithProgress(src, item, { label = 'Repairing engine', duration = 10000, anim = { dict = 'mini@repair', clip = 'fixing_a_player' }, disable = { move = true, car = true, combat = true } }, function()
        TriggerClientEvent('arca_inventory:client:repairVehicle', src)
    end)
end)
