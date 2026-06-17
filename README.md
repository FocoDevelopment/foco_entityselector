# Entity Inspector (lime_entityselector)

A lightweight **Entity Inspector tool for FiveM** by **Lime Studios** that lets admins scan, highlight, inspect, and act on entities in-game with a single mouse interaction. The NUI is built with **Svelte**.

---

## 🔐 Permissions

Grant the following ACE permission:

```
add_ace group.admin lime_entityselector.use allow
```

Only players with this permission can open the inspector or run any action.

---

## 🎮 Controls

| Action | Key |
|--------|-----|
| Scan entity | Hold **Middle Mouse Button (MMB)** |
| Open inspector | Release **MMB** |
| Close panel | **ESC** |

---

## ✨ Features

- 🔍 Raycast-based entity detection
- 📦 3D bounding box + floating label (lime accent)
- 📊 Detailed inspection panel (Svelte NUI)
- 🔄 Live data updates while the panel is open
- 📏 **Distance** readout from the player
- 🚗 Vehicle stats (body, engine, fuel tank)
- 🧍 Ped stats (armour, player check)
- 🌐 Network info (networked state, Net ID, owner)
- 📋 One-click copy for model name, hash, and coordinates
- 🚀 **Teleport** to the inspected entity
- ❄️ **Freeze / unfreeze** (server-authoritative for networked entities)
- 🗑️ **Delete** entity (server-authoritative; refuses to delete player peds)
- 🔔 In-panel toast feedback for every action

---

## 🆕 New in 2.3.1

- **Fixed the phantom "unknown @ 1075m" panel:** the map raycast flag (1) was returning bogus entity handles for raw world geometry — they passed `DoesEntityExist` but sat at coords 0,0,0 (≈1km from the player). Removed the map flag (real props are objects/flag 16 anyway) and added a sanity backstop that rejects any hit at the world origin or beyond the 50m cast range.
- **All-lime UI:** the panel accent no longer changes color by entity type or freeze state — the left border, icon chip, kicker, glow, network tag, and active Freeze button are always lime green. (Entity type is still shown by the header icon; the XYZ axis letters and damage-colored health values stay as semantic indicators.)

## 🆕 New in 2.3.0

- **Detection fixed for all props:** the raycast flags were wrong (the old value only hit peds). Now the ray hits map + vehicles + peds + objects + vegetation, so large static map props (e.g. the MRPD table) and big objects register reliably instead of half of them being missed.
- **Guaranteed highlight (hybrid):** FiveM's native outline shader silently fails on many large/static props (no `drawunlit` pass — cfx issue #874). The inspector now **always** draws a tight wireframe box (works on every entity) and layers the native silhouette on top when the model supports it. So everything gets highlighted, with the nicer silhouette where possible.
- **No more "unknown" popup:** hits on terrain/buildings (non-entities) return handle 0 and are filtered out. The panel only opens when the crosshair is on a real entity with a valid model.
- **Lower spikes:** the entity name is resolved once per target instead of every frame (was calling `GetEntityArchetypeName` + `string.format` per frame), model dimensions are cached, the raycast is throttled to ~16/sec, and the box uses batched 3D `DrawLine`.

## 🆕 New in 2.2.0

- **Real silhouette outline:** the prop is now highlighted with FiveM's native `SetEntityDrawOutline` (shader variant 1 — the crisp 2px solid outline), which traces the model's actual mesh edges instead of drawing a wireframe box. This is the glowing-silhouette look. Peds are intentionally **not** outlined (the native can crash on skinned meshes) and show the floating label only.
- **No more false popups:** releasing MMB now does a fresh raycast at that exact instant. If the crosshair isn't on a prop, nothing opens — the panel can no longer appear from a stale hover.
- **Lower resmon:** the per-frame wireframe (≈20 screen projections + line draws every frame) is gone. The native outline is GPU-side and free on the script side, and the raycast is throttled to ~13/sec. Effective use-time cost drops sharply from the previous ~0.37ms spike.

## 🆕 New in 2.1.0

- **Performance:** the scan/draw/ESC loops no longer run while idle. A 0ms draw thread spins up only while MMB is held and exits on release; the live-refresh and ESC threads run only while the panel is open and self-terminate when it closes. Idle cost is effectively ~0.00ms in resmon.
- **Tighter outline:** the bounding box is now drawn as crisp screen-space lines hugging the model's real dimensions, with bright bracketed corners (Electron-AC style) instead of a loose thick box. Model dimensions are cached per model hash.
- **Draggable + resizable window:** grab the header to move the panel anywhere; drag any edge or corner to resize it like a desktop window (min 300×360, clamped on-screen). The body scrolls when the window is shorter than its content; actions stay pinned to the bottom. Position and size persist for the session.

## 🆕 New in 2.0.0

- Rewrote the NUI in **Svelte 5** (runes + `mount`), matching the `lime_notify` build setup, compiled to a single JS + CSS bundle.
- Restyled the panel to the **Lime Studios house style** shared with `lime_notify`: tinted per-type colors, icon chips, uppercase tracked labels, left-accent border, and the shared `cubic-bezier(0.22,1,0.36,1)` motion.
- Per-entity-type theming: vehicles are blue, peds gold, objects green, frozen entities blue — driving the left accent, header chip, and glow.
- Rebranded from `motion_*` / Motion Scripts to `lime_*` / Lime Studios.
- Added **Teleport**, **Freeze**, and **Delete** actions, gated by ACE on the server.
- Added a **distance** field and toast notifications.
- Folded the version checker into the **centralized Lime Studios** checker with INI-style `[global]` broadcast support.

---

## 📁 Installation

1. Place the resource in your `resources` folder.
2. **Build the UI** (one time, or after editing `html/src`):
   ```
   cd html
   npm install
   npm run build
   ```
   This produces `html/dist/` which is what the resource serves. The repo ships a pre-built `dist/`, so you can skip this step unless you change the UI.
3. Add to your `server.cfg`:
   ```
   ensure lime_entityselector
   ```
4. Add the ACE permission:
   ```
   add_ace group.admin lime_entityselector.use allow
   ```

---

## ⚙️ Requirements

- FiveM server (FXServer)
- NUI support enabled
- An admin setup using ACE permissions
- Node.js 18+ (only to rebuild the UI)

---

## 🛠️ Developer Notes

- Safe `pcall` usage throughout to survive entities going invalid mid-frame.
- Optimised scan loop (20 ticks/sec).
- Freeze/Delete send the entity **Net ID** to the server so the server acts on the
  entity it owns rather than trusting a client handle.
- Player peds are protected from deletion on both the client and server.

### Suppressing update checks

Either set a convar in `server.cfg`:
```
setr lime_entityselector_suppressUpdates true
```
or add `suppress_updates 'true'` to `fxmanifest.lua`.

---

## 📌 Resource Info

- Resource name: `lime_entityselector`
- Client: `client/main.lua`
- Server: `server/main.lua`
- UI source: `html/src/` (Svelte) → built to `html/dist/`
- Permission: `lime_entityselector.use`

---

Built by Lime Studios 🟢
