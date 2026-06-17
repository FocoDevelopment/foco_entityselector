-- ============================================================
--  Entity Inspector | server/main.lua
--  Pure ACE permission check — works with any framework.
--  Grant access with:  add_ace identifier.license:XXXX lime_entityselector.use allow
--  Or via txAdmin:      add_ace group.admin lime_entityselector.use allow
-- ============================================================

local PERM = 'lime_entityselector.use'

local function isAllowed(src)
    return IsPlayerAceAllowed(tostring(src), PERM)
end

RegisterNetEvent('lime_entityselector:checkAdmin', function()
    local src = source
    TriggerClientEvent('lime_entityselector:setAdmin', src, isAllowed(src))
end)

-- ============================================================
--  Authoritative entity actions
--  The client sends a NETWORK id (not a local handle) so the
--  server can resolve and act on the entity it actually owns.
-- ============================================================

local function resolveNetEntity(netId)
    if type(netId) ~= 'number' or netId <= 0 then return nil end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent and ent ~= 0 and DoesEntityExist(ent) then return ent end
    return nil
end

-- Delete -----------------------------------------------------
RegisterNetEvent('lime_entityselector:deleteEntity', function(netId)
    local src = source
    if not isAllowed(src) then return end

    local ent = resolveNetEntity(netId)
    if not ent then
        TriggerClientEvent('lime_entityselector:actionResult', src, 'delete', false, 'Entity not found server-side')
        return
    end

    -- Never let an admin delete a live player ped through this tool.
    if GetEntityType(ent) == 1 and IsPedAPlayer(ent) then
        TriggerClientEvent('lime_entityselector:actionResult', src, 'delete', false, 'Refusing to delete a player ped')
        return
    end

    DeleteEntity(ent)
    TriggerClientEvent('lime_entityselector:actionResult', src, 'delete', true, 'Entity deleted')
end)

-- Freeze / unfreeze ------------------------------------------
RegisterNetEvent('lime_entityselector:freezeEntity', function(netId, state)
    local src = source
    if not isAllowed(src) then return end

    local ent = resolveNetEntity(netId)
    if not ent then
        TriggerClientEvent('lime_entityselector:actionResult', src, 'freeze', false, 'Entity not found server-side')
        return
    end

    FreezeEntityPosition(ent, state and true or false)
    TriggerClientEvent('lime_entityselector:actionResult', src, 'freeze', true,
        state and 'Entity frozen' or 'Entity unfrozen')
end)
