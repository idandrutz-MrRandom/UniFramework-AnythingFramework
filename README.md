# UniFramework

A lightweight, convention-based remote dispatch framework for Roblox — built around a unified packet system that routes client and server actions through named modules with zero boilerplate.

---

## Overview

UniFramework eliminates the need to manually wire up RemoteEvents per feature. Instead, you define **server modules** (`S_`) and **client modules** (`C_`) following a naming convention, and the framework automatically discovers, requires, and dispatches calls to the correct function — all through a single shared remote infrastructure.

```
Client calls Packet:Fire(char, { Module = "Punch", Function = "Activate" })
         └─► UniHandler receives it on the server
               └─► finds S_Punch, calls S_Punch.Activate(Character, data, player)
                     └─► server fires ReplicateRemote
                           └─► UniReplicator receives it on the client
                                 └─► finds C_Punch, calls C_Punch.Effects(args)
```

---

## Architecture

| Module | Type | Location | Role |
|---|---|---|---|
| `UniHandler` | Server Script | ServerScriptService | Listens for `ServerRemote`, dispatches to `S_` modules |
| `UniReplicator` | Local Script | StarterPlayerScripts (or similar) | Listens for `ReplicateRemote`, dispatches to `C_` modules |
| `Packets` | Shared ModuleScript | ReplicatedStorage/Remotes | Defines and wraps the two remotes |
| `Configuration` | Shared ModuleScript | ReplicatedStorage/Assets/Modules | Declares where modules and utilities live |

---

## Setup

### 1. Folder Structure

Ensure the following paths exist in your game:

```
ReplicatedStorage/
├── Assets/
│   └── Modules/
│       ├── Configuration    ← shared config module
│       ├── Shared/
│       │   └── Util/        ← utility modules (both sides)
│       ├── Server/
│       │   └── Util/        ← server-only utilities
│       └── Client/
│           └── Util/        ← client-only utilities
├── Remotes/
│   └── Packets              ← shared Packets module
└── ClientSkills/            ← C_ modules go here

ServerScriptService/
└── ServerSkills/            ← S_ modules go here
```

### 2. Naming Convention

The framework resolves modules by name with a required prefix:

| Module Type | Prefix | Example |
|---|---|---|
| Server-side logic | `S_` | `S_Punch` |
| Client-side logic | `C_` | `C_Punch` |
| Utilities (both sides) | *(none)* | `Highlight` |

> Modules are discovered by recursively searching the configured paths. You don't need to register them manually.

### 3. Configuration

`Configuration` declares the search paths. By default:

- **`ServerModulePaths`** → `ServerScriptService/ServerSkills`
- **`ClientModulePaths`** → `ReplicatedStorage/ClientSkills`
- **`UtilityPaths`** → `ReplicatedStorage/Assets/Modules/Shared/Util` + side-specific util folder

To add more containers, edit `Configuration`:

```lua
-- Add a new folder of server modules
table.insert(Configuration.ServerModulePaths, ServerScriptService:WaitForChild("MyNewSkills"))
```

---

## Packet API

All communication goes through `Packets`, which exposes two remotes:

```lua
local Packets = require(ReplicatedStorage.Remotes.Packets)

-- Client → Server
Packets.ServerRemote:Fire(Character, Params, Data?)

-- Server → All clients (broadcast)
Packets.ReplicateRemote:Fire(Character, Params, Data?)

-- Server → Specific client
Packets.ReplicateRemote:FireClient(Player, Character, Params, Data?)
```

### `Params` type

```lua
type Params = {
    Module: string?,   -- name of an S_ or C_ module (without the prefix)
    Utility: string?,  -- name of a utility module (no prefix)
    Function: string,  -- the function to call on the resolved module
}
```

One of `Module` or `Utility` must be provided. `Module` takes priority.

### `Character` type

`Character` is a `Model` — typically the player's character model. It is always passed as the first argument.

---

## Writing Modules

### Server Module (`S_`)

Place in `ServerScriptService/ServerSkills/`. Name must start with `S_`.

```lua
-- S_Punch (ServerScriptService/ServerSkills/S_Punch)
--!strict
local Packets = require(game.ReplicatedStorage.Remotes.Packets)

local module = {}

module.Activate = function(Character: Packets.Character, data: any, player: Player)
    -- Character: the Model passed from the client
    -- data:      the extraData table from the client fire
    -- player:    the Player who fired the remote

    warn("Punch activated by:", Character.Name)

    -- Broadcast effect to all clients
    Packets.ReplicateRemote:Fire(Character, { Module = "Punch", Function = "Effects" }, {
        Type = "Highlight"
    })

    -- Or send only to the acting player
    Packets.ReplicateRemote:FireClient(player, Character, { Module = "Punch", Function = "Effects" }, {
        Type = "Highlight"
    })
end

return module
```

**Server function signature:**
```lua
function(Character: Model, data: any, player: Player)
```

---

### Client Module (`C_`)

Place in `ReplicatedStorage/ClientSkills/`. Name must start with `C_`.

```lua
-- C_Punch (ReplicatedStorage/ClientSkills/C_Punch)
--!strict
local Packets = require(game.ReplicatedStorage.Remotes.Packets)

local module = {}

-- Called locally to fire a server action
module.Start = function(char: Packets.Character)
    Packets.ServerRemote:Fire(char, { Module = "Punch", Function = "Activate" })
end

-- Called by UniReplicator when the server replicates an effect
-- args.Character is automatically injected by UniReplicator
module.Effects = function(args: Packets.Args)
    if args.Type == "Highlight" then
        -- apply visual effect on args.Character
    end
end

return module
```

**Client replicated function signature:**
```lua
function(args: { Character: Model, [any]: any })
```

> `Character` is automatically injected into the `args` table by `UniReplicator` — you don't need to pass it separately.

---

### Utility Module

Place in any path listed under `UtilityPaths`. No prefix required.

```lua
-- Highlight (ReplicatedStorage/Assets/Modules/Shared/Util/Highlight)
local module = {}

module.Create = function(config: { Character: Model, Color: Color3, Transparency: number, FadeDuration: number })
    -- apply highlight to config.Character
end

return module
```

Reference via `Utility` in params:

```lua
-- This would call Highlight.Create(...) on whichever side handles the packet
Packets.ReplicateRemote:Fire(char, { Utility = "Highlight", Function = "Create" }, { ... })
```

---

## Full Example: Punch Skill

### 1. Player activates the skill (client)

```lua
local Packets = require(ReplicatedStorage.Remotes.Packets)
local char = game.Players.LocalPlayer.Character

-- Fires ServerRemote → UniHandler → S_Punch.Activate
Packets.ServerRemote:Fire(char, { Module = "Punch", Function = "Activate" })
```

### 2. Server processes and replicates (`S_Punch`)

```lua
module.Activate = function(Character, data, player)
    -- game logic here ...

    -- Replicate visual effect to all clients
    Packets.ReplicateRemote:Fire(Character, { Module = "Punch", Function = "Effects" }, {
        Type = "Highlight"
    })
end
```

### 3. Client renders the effect (`C_Punch`)

```lua
-- UniReplicator calls this automatically, injecting args.Character
module.Effects = function(args)
    if args.Type == "Highlight" then
        highlight.Create({ Character = args.Character, Color = Color3.fromRGB(255, 0, 0), ... })
    end
end
```

---

## How Dispatch Works Internally

### UniHandler (server)

1. Listens on `Packets.ServerRemote.OnServerEvent`
2. Reads `params.Module` or `params.Utility` to get the module name
3. If `Module` → searches `ServerModulePaths` for `S_<name>`; if `Utility` → searches `UtilityPaths` for `<name>`
4. Requires the module (cached after first require)
5. Calls `module[params.Function](Character, extraData, player)` via `task.spawn`

### UniReplicator (client)

1. Listens on `Packets.ReplicateRemote.OnClientEvent`
2. Same lookup logic, but searches `ClientModulePaths` for `C_<name>`
3. Injects `Character` into the `extraData` table automatically
4. Calls `module[params.Function](extraData)` via `task.spawn`

---

## Module Caching

Both `UniHandler` and `UniReplicator` cache required modules by name after the first load. Modules are only `require`d once per session — subsequent dispatches to the same module reuse the cached result.

---

## Notes & Limitations

- Module names must be **unique** within their search paths. The first match is used.
- `params.Module` takes priority over `params.Utility` if both are somehow provided.
- Functions are called with `task.spawn`, so errors will not propagate to the caller — use `warn`/logging inside your module functions.
- `extraData` defaults to `{}` if not provided.
- The framework does **not** do server-side validation of `Character` ownership — add your own trust checks in `S_` modules if needed.
