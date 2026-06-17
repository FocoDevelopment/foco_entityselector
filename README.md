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
