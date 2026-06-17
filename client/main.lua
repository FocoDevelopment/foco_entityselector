-- ============================================================
--  Entity Inspector | client/main.lua
--  ACE permission: lime_entityselector.use
--
--  Performance model:
--    * Idle: no per-frame work at all. Key handlers are event-driven.
--    * A dedicated 0ms draw thread spins up ONLY while MMB is held,
--      and exits the instant the key is released.
--    * Live-refresh + ESC threads run only while the panel is open
--      and self-terminate when it closes.
--  Result: ~0.00ms idle, work only happens on demand.
-- ============================================================

local RESOURCE    = GetCurrentResourceName()

local isAdmin     = false
local panelOpen   = false
local selectedEnt = nil

local scanning    = false   -- MMB currently held
local drawActive  = false   -- draw thread currently alive
local frozenState = false

-- Forward declarations so command handlers can see them.
local StartDrawThread, StartPanelThreads, openPanel, closePanelInternal
local clearOutline

-- -- Key binding -----------------------------------------------
-- RegisterKeyMapping is the only correct way to detect MMB in FiveM.

RegisterCommand('+lime_scan', function()
    if panelOpen or not isAdmin then return end
    scanning = true
    if not drawActive then StartDrawThread() end
end, false)

RegisterCommand('-lime_scan', function()
    scanning = false
    -- The draw thread sees scanning=false, opens the panel if it had a
    -- target, and exits on its own.
end, false)

RegisterKeyMapping('+lime_scan', 'Entity Inspector Scan', 'MOUSE_BUTTON', 'MOUSE_MIDDLE')

-- -- Helpers --------------------------------------------------

local function getTypeName(entity)
    local t = GetEntityType(entity)
    if t == 1 then return "Ped"
    elseif t == 2 then return "Vehicle"
    elseif t == 3 then return "Object"
    else return "Unknown" end
end

local function f2(n) return math.floor((n or 0) * 100) / 100 end
local function f1(n) return math.floor((n or 0) * 10)  / 10  end

-- -- Raycast ---------------------------------------------------
-- Flags is a bitmask of what the ray can hit:
--   1 = map  (raw world mesh — DO NOT use: returns phantom entity
--             handles at 0,0,0 that pass DoesEntityExist but aren't
--             real props; this caused the "unknown @ 1075m" panel)
--   2 = vehicles
--   4 + 8 = peds
--   16 = objects (this is where props live, incl. large map props)
--   256 = vegetation
-- We hit vehicles + peds + objects + vegetation. Real inspectable props
-- are objects; raw map geometry is intentionally excluded.
local RAY_FLAGS = 2 + 4 + 8 + 16 + 256

local function raycast()
    local ped  = PlayerPedId()
    local cam  = GetGameplayCamCoords()
    local rot  = GetGameplayCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local cosX = math.cos(rx)
    local fwd  = vector3(-math.sin(rz) * cosX, math.cos(rz) * cosX, math.sin(rx))
    local dest = cam + fwd * 50.0

    local ray = StartShapeTestRay(cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, RAY_FLAGS, ped, 4)
    local _, hit, _, _, entity = GetShapeTestResult(ray)
    if hit == 1 and entity and entity ~= 0 and entity ~= ped and DoesEntityExist(entity) then
        return entity
    end
    return nil
end

-- -- Highlight: hybrid box + native outline -------------------
-- The native SetEntityDrawOutline gives a clean silhouette BUT silently
-- fails on many large/static map props (trees, tubes, big world objects
-- with no drawunlit shader pass — see cfx issue #874). So we ALWAYS draw
-- a tight wireframe box (works on every entity) and additionally turn on
-- the native silhouette when the model supports it.
--
-- Perf: box corners are computed only when the target changes (cached),
-- not every frame. Lines use 3D DrawLine which the engine batches on the
-- GPU. Peds are never passed to the native (it can crash on skinned
-- meshes) but still get the box.

local OUTLINE_R, OUTLINE_G, OUTLINE_B = 132, 225, 60
local outlinedEnt = nil

-- Cached box geometry + label for the current target.
local boxEnt = nil
local boxModel = nil
local boxMin, boxMax = nil, nil
local boxName = "unknown"

local function isNativeSafe(entity)
    local t = GetEntityType(entity)
    return t == 2 or t == 3  -- vehicles + objects only
end

local function setNativeOutline(entity)
    if outlinedEnt == entity then return end
    clearOutline()
    if entity and DoesEntityExist(entity) and isNativeSafe(entity) then
        pcall(function()
            SetEntityDrawOutlineShader(1)
            SetEntityDrawOutlineColor(OUTLINE_R, OUTLINE_G, OUTLINE_B, 255)
            SetEntityDrawOutline(entity, true)
        end)
        outlinedEnt = entity
    end
end

clearOutline = function()
    if outlinedEnt and DoesEntityExist(outlinedEnt) then
        pcall(SetEntityDrawOutline, outlinedEnt, false)
    end
    outlinedEnt = nil
end

-- Refresh cached model dimensions + name when the target changes.
local function cacheBox(entity)
    if boxEnt == entity then return end
    boxEnt = entity
    boxModel = GetEntityModel(entity)
    if boxModel and boxModel ~= 0 then
        boxMin, boxMax = GetModelDimensions(boxModel)
    else
        boxMin, boxMax = nil, nil
    end
    -- Resolve display name once (was previously recomputed every frame).
    boxName = "unknown"
    pcall(function()
        local n = GetEntityArchetypeName(entity)
        if type(n) == "string" and n ~= "" then
            boxName = n
        elseif boxModel and boxModel ~= 0 then
            boxName = string.format("0x%08X", boxModel)
        end
    end)
end

-- Draw the wireframe box (guaranteed-visible fallback). Cheap: 12 edges
-- via 3D DrawLine, corners recomputed from the live matrix each frame so
-- it tracks moving entities, but min/max are cached.
local function drawBox(entity)
    if not (boxMin and boxMax) then return end
    local ok = pcall(function()
        local mn, mx = boxMin, boxMax
        local fwd, right, up, pos = GetEntityMatrix(entity)

        local function c(lx, ly, lz)
            return
                pos.x + right.x*lx + fwd.x*ly + up.x*lz,
                pos.y + right.y*lx + fwd.y*ly + up.y*lz,
                pos.z + right.z*lx + fwd.z*ly + up.z*lz
        end

        local x1,y1,z1 = c(mn.x, mn.y, mn.z)
        local x2,y2,z2 = c(mx.x, mn.y, mn.z)
        local x3,y3,z3 = c(mx.x, mx.y, mn.z)
        local x4,y4,z4 = c(mn.x, mx.y, mn.z)
        local x5,y5,z5 = c(mn.x, mn.y, mx.z)
        local x6,y6,z6 = c(mx.x, mn.y, mx.z)
        local x7,y7,z7 = c(mx.x, mx.y, mx.z)
        local x8,y8,z8 = c(mn.x, mx.y, mx.z)

        local R,G,B,A = OUTLINE_R, OUTLINE_G, OUTLINE_B, 200
        -- bottom
        DrawLine(x1,y1,z1, x2,y2,z2, R,G,B,A)
        DrawLine(x2,y2,z2, x3,y3,z3, R,G,B,A)
        DrawLine(x3,y3,z3, x4,y4,z4, R,G,B,A)
        DrawLine(x4,y4,z4, x1,y1,z1, R,G,B,A)
        -- top
        DrawLine(x5,y5,z5, x6,y6,z6, R,G,B,A)
        DrawLine(x6,y6,z6, x7,y7,z7, R,G,B,A)
        DrawLine(x7,y7,z7, x8,y8,z8, R,G,B,A)
        DrawLine(x8,y8,z8, x5,y5,z5, R,G,B,A)
        -- verticals
        DrawLine(x1,y1,z1, x5,y5,z5, R,G,B,A)
        DrawLine(x2,y2,z2, x6,y6,z6, R,G,B,A)
        DrawLine(x3,y3,z3, x7,y7,z7, R,G,B,A)
        DrawLine(x4,y4,z4, x8,y8,z8, R,G,B,A)
    end)
    if not ok then end
end

-- -- Floating label --------------------------------------------

local function project(p)
    local on, sx, sy = World3dToScreen2d(p.x, p.y, p.z)
    if on and on ~= 0 and sx == sx and sy == sy then
        return sx, sy
    end
    return nil
end

local function drawLabel(entity)
    local pos = GetEntityCoords(entity, false)
    local sx, sy = project(vector3(pos.x, pos.y, pos.z + 1.0))
    if not sx then return end

    local cam  = GetGameplayCamCoords()
    local dist = #(pos - cam)
    if dist < 0.01 then return end
    local scale = math.min(0.45, math.max(0.22, (1.0 / dist) * 2.2))

    pcall(function()
        SetTextScale(scale, scale)
        SetTextFont(4)
        SetTextColour(132, 225, 60, 230)
        SetTextOutline()
        SetTextCentre(true)
        BeginTextCommandDisplayText("STRING")
        AddTextComponentSubstringPlayerName(boxName)
        EndTextCommandDisplayText(sx, sy)
    end)
end

-- -- Collect data ----------------------------------------------

local function collectData(entity)
    if not DoesEntityExist(entity) then return nil end

    local pos     = GetEntityCoords(entity, true)
    local entType = getTypeName(entity)

    local model = "unknown"
    pcall(function()
        local n = GetEntityArchetypeName(entity)
        if n and n ~= "" then model = n
        else model = string.format("0x%08X", GetEntityModel(entity)) end
    end)

    local health, maxHp, heading = 0, 200, 0.0
    pcall(function()
        health  = GetEntityHealth(entity)
        maxHp   = GetEntityMaxHealth(entity)
        heading = GetEntityHeading(entity)
    end)

    local isNet = false
    local netIdNum = nil
    local netIdStr, ownerStr = nil, "N/A"
    pcall(function()
        isNet = NetworkGetEntityIsNetworked(entity)
        if isNet then
            local ok, nid = pcall(NetworkGetNetworkIdFromEntity, entity)
            if ok and nid and nid > 0 then
                netIdNum = nid
                netIdStr = tostring(nid)
            end
            local ok2, oid = pcall(NetworkGetEntityOwner, entity)
            if ok2 and oid and oid >= 0 then
                ownerStr = GetPlayerName(oid) or ("Player " .. tostring(oid))
            end
        end
    end)

    local modelHash = " "
    pcall(function() modelHash = tostring(GetEntityModel(entity)) end)

    local dist = 0.0
    pcall(function()
        local pc = GetEntityCoords(PlayerPedId(), true)
        dist = f1(#(pos - pc))
    end)

    local d = {
        modelName  = model,
        entityType = entType,
        handle     = entity,
        netId      = netIdStr,
        netIdNum   = netIdNum,
        modelHash  = modelHash,
        health     = health,
        maxHealth  = maxHp,
        heading    = f1(heading),
        distance   = dist,
        pos        = { x = f2(pos.x), y = f2(pos.y), z = f2(pos.z) },
        networked  = isNet,
        owner      = ownerStr,
        frozen     = frozenState,
        extras     = {},
    }

    if entType == "Vehicle" then
        pcall(function()
            d.extras = {
                body   = math.floor(GetVehicleBodyHealth(entity)),
                engine = math.floor(GetVehicleEngineHealth(entity)),
                tank   = math.floor(GetVehiclePetrolTankHealth(entity)),
            }
        end)
    elseif entType == "Ped" then
        pcall(function()
            d.extras = {
                armour   = GetPedArmour(entity),
                isPlayer = IsPedAPlayer(entity),
            }
        end)
    end

    return d
end

-- -- Panel open / close ---------------------------------------

openPanel = function(ent)
    panelOpen   = true
    selectedEnt = ent
    frozenState = (IsEntityPositionFrozen and IsEntityPositionFrozen(ent)) or false
    SetNuiFocus(true, true)
    local d = collectData(ent)
    if d then SendNUIMessage({ type = 'open', data = d }) end
    StartPanelThreads()
end

closePanelInternal = function()
    panelOpen   = false
    selectedEnt = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'close', data = {} })
end

-- -- DRAW THREAD (on-demand) ----------------------------------
-- Raycast is throttled (~every 60ms); the box is drawn every frame so it
-- tracks moving entities without flicker, but uses cached model dims and
-- batched 3D DrawLine. The native silhouette is toggled only when the
-- target changes. The panel opens only if a fresh raycast at release
-- confirms a real, inspectable entity under the crosshair.

local function isInspectable(entity)
    -- Must exist and resolve to a real model.
    if not (entity and entity ~= 0 and DoesEntityExist(entity)) then return false end
    local m = GetEntityModel(entity)
    if not m or m == 0 then return false end

    -- Backstop against phantom map handles: those report coords at the
    -- world origin (0,0,0) and end up ~1km from the player. A real ray hit
    -- is within the 50m cast range. Reject anything at origin or too far.
    local pos = GetEntityCoords(entity, false)
    if pos.x == 0.0 and pos.y == 0.0 and pos.z == 0.0 then return false end
    local pc = GetEntityCoords(PlayerPedId(), false)
    if #(pos - pc) > 60.0 then return false end

    return true
end

StartDrawThread = function()
    drawActive = true
    CreateThread(function()
        local hover = nil
        local nextCast = 0

        while scanning do
            local now = GetGameTimer()

            if now >= nextCast then
                nextCast = now + 60
                local hit = raycast()
                if isInspectable(hit) then
                    if hit ~= hover then
                        hover = hit
                        cacheBox(hover)
                        setNativeOutline(hover)
                    end
                else
                    if hover then
                        hover = nil
                        clearOutline()
                    end
                end
            end

            -- Entity may stream out mid-hold.
            if hover and not DoesEntityExist(hover) then
                hover = nil
                clearOutline()
            end

            -- Per-frame visuals (cheap, cached geometry).
            if hover then
                drawBox(hover)
                drawLabel(hover)
            end

            Wait(0)
        end

        clearOutline()

        -- Fresh confirmation raycast. Only inspectable hits open the panel,
        -- so empty space / non-entity geometry no longer shows "unknown".
        local confirmed = raycast()
        if isInspectable(confirmed) and not panelOpen then
            openPanel(confirmed)
        end

        drawActive = false
    end)
end

-- -- PANEL THREADS (live refresh + ESC), on-demand ------------

StartPanelThreads = function()
    -- Live refresh @ 2/sec
    CreateThread(function()
        while panelOpen do
            if selectedEnt and DoesEntityExist(selectedEnt) then
                local d = collectData(selectedEnt)
                if d then SendNUIMessage({ type = 'update', data = d }) end
            elseif selectedEnt then
                closePanelInternal()
                break
            end
            Wait(500)
        end
    end)

    -- ESC to close — 0ms only while the panel is open.
    CreateThread(function()
        while panelOpen do
            if IsControlJustReleased(0, 200) then
                closePanelInternal()
                break
            end
            Wait(0)
        end
    end)
end

-- -- Resource lifecycle ----------------------------------------

AddEventHandler('onClientResourceStart', function(res)
    if res ~= RESOURCE then return end
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'close', data = {} })
    panelOpen   = false
    selectedEnt = nil
    scanning    = false
    drawActive  = false
    TriggerServerEvent('lime_entityselector:checkAdmin')
end)

AddEventHandler('onClientResourceStop', function(res)
    if res ~= RESOURCE then return end
    if clearOutline then clearOutline() end
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'close', data = {} })
end)

RegisterNetEvent('lime_entityselector:setAdmin', function(state)
    isAdmin = state
    print(isAdmin
        and "^2[EntitySelector] Admin access granted.^7"
        or  "^3[EntitySelector] No admin access.^7")
end)

-- -- Action toast --------------------------------------------

RegisterNetEvent('lime_entityselector:actionResult', function(action, ok, msg)
    SendNUIMessage({ type = 'toast', data = { action = action, ok = ok, msg = msg } })
end)

-- -- NUI Callbacks ---------------------------------------------

RegisterNUICallback('close', function(_, cb)
    closePanelInternal()
    cb('ok')
end)

RegisterNUICallback('teleport', function(_, cb)
    if selectedEnt and DoesEntityExist(selectedEnt) then
        local c = GetEntityCoords(selectedEnt, true)
        SetEntityCoords(PlayerPedId(), c.x + 1.5, c.y + 1.5, c.z, false, false, false, false)
        SendNUIMessage({ type = 'toast', data = { action = 'teleport', ok = true, msg = 'Teleported to entity' } })
    end
    cb('ok')
end)

RegisterNUICallback('freeze', function(_, cb)
    if not (selectedEnt and DoesEntityExist(selectedEnt)) then cb('ok'); return end
    frozenState = not frozenState

    if NetworkGetEntityIsNetworked(selectedEnt) then
        local ok, nid = pcall(NetworkGetNetworkIdFromEntity, selectedEnt)
        if ok and nid and nid > 0 then
            TriggerServerEvent('lime_entityselector:freezeEntity', nid, frozenState)
        end
    else
        FreezeEntityPosition(selectedEnt, frozenState)
        SendNUIMessage({ type = 'toast', data = {
            action = 'freeze', ok = true,
            msg = frozenState and 'Entity frozen' or 'Entity unfrozen'
        } })
    end

    SendNUIMessage({ type = 'freezeState', data = { frozen = frozenState } })
    cb('ok')
end)

RegisterNUICallback('delete', function(_, cb)
    if not (selectedEnt and DoesEntityExist(selectedEnt)) then cb('ok'); return end

    if GetEntityType(selectedEnt) == 1 and IsPedAPlayer(selectedEnt) then
        SendNUIMessage({ type = 'toast', data = { action = 'delete', ok = false, msg = 'Cannot delete a player ped' } })
        cb('ok'); return
    end

    if NetworkGetEntityIsNetworked(selectedEnt) then
        local ok, nid = pcall(NetworkGetNetworkIdFromEntity, selectedEnt)
        if ok and nid and nid > 0 then
            TriggerServerEvent('lime_entityselector:deleteEntity', nid)
        end
    else
        SetEntityAsMissionEntity(selectedEnt, true, true)
        DeleteEntity(selectedEnt)
        SendNUIMessage({ type = 'toast', data = { action = 'delete', ok = true, msg = 'Entity deleted' } })
    end

    closePanelInternal()
    cb('ok')
end)

print("^2[EntitySelector] Loaded   Hold MMB to highlight | Release to inspect | ACE: lime_entityselector.use^7")
