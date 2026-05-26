# UniFramework                    

A prediction-based remote dispatch framework for Roblox. The client acts immediately — playing animations, showing effects, responding to input — while the server receives the action, validates it, and replicates the authoritative result back. This keeps gameplay feeling responsive while still giving the server full control over what actually counts.

For example: a player throws a punch. The client plays the animation instantly. The server receives the request, checks if the punch is valid (cooldown, range, etc.), and only then replicates the hit effect to other clients. The client never waits on the server for things the player should feel immediately.

UniFramework handles the plumbing for this pattern — a single shared remote infrastructure that routes calls to the right module and function on either side, with zero per-feature wiring.

```
[Client] Tool activated → C_Punch.Start(char)
    │  plays local animation immediately (prediction)
    └─► ServerRemote:Fire(char, { Module = "Punch", Function = "Activate" })
              │
         [UniHandler] → finds S_Punch → S_Punch.Activate(Character, data, player)
              │  server validates the action
              └─► ReplicateRemote:Fire(char, { Module = "Punch", Function = "Effects" }, { Type = "Highlight" })
                        │
                   [UniReplicator] → finds C_Punch → C_Punch.Effects(args)
                        └─► renders confirmed effect on all clients
```

---

## Architecture

| Module | Type | Location | Role |
|---|---|---|---|
| `UniHandler` | Script | ServerScriptService | Listens on `ServerRemote`, dispatches to `S_` modules |
| `UniReplicator` | LocalScript | StarterPlayerScripts | Listens on `ReplicateRemote`, dispatches to `C_` modules |
| `Packets` | Shared ModuleScript | ReplicatedStorage/Remotes | Wraps and exposes the two remotes |
| `Configuration` | Shared ModuleScript | ReplicatedStorage/Assets/Modules | Declares where modules and utilities live |

---

## Setup

### 1. Folder Structure

The framework doesn't enforce a rigid structure — as long as your paths are registered in `Configuration`, the framework will find your modules. Below is the **reference setup** that works out of the box, matching the example project:

```
ReplicatedStorage/
├── Assets/
│   └── Modules/
│       ├── Configuration            ← shared config module
│       ├── Shared/
│       │   └── Util/                ← utility modules (accessible by both sides)
│       ├── Server/
│       │   └── Util/                ← server-only utility modules
│       └── Client/
│           └── Util/                ← client-only utility modules
├── ClientSkills/
│   └── Base/
│       └── Punch/
│           └── C_Punch              ← client skill module
├── Data/
└── Remotes/
    └── Packets                      ← shared Packets module

ServerScriptService/
├── CharacterClass/
├── ServerLogic/
│   └── Script
├── ServerSkills/
│   └── Punch/
│       └── S_Punch                  ← server skill module
└── SkillHandler/
    └── UniHandler                   ← server dispatcher

StarterPlayer/
└── StarterPlayerScripts/
    └── Controllers/
        ├── MovementController
        └── UniReplicator            ← client dispatcher (LocalScript)
```

> **This is just one working example.** The only hard requirements are that `UniHandler` runs as a server Script and `UniReplicator` runs as a LocalScript. Everything else — folder names, nesting depth, how you group skills — is up to you, as long as the paths are listed in `Configuration`.

Skill modules can be flat or nested inside their container; the recursive search handles both:

```
-- Flat
ServerSkills/
├── S_Punch
└── S_Kick

-- Nested by skill name (as in the reference setup)
ServerSkills/
├── Punch/
│   └── S_Punch
└── Kick/
    └── S_Kick
```

### 2. Naming Convention

| Module type | Prefix | Example |
|---|---|---|
| Server-side skill logic | `S_` | `S_Punch` |
| Client-side skill logic | `C_` | `C_Punch` |
| Shared utilities | *(none)* | `Highlight` |

Modules are discovered by recursively scanning the registered paths. No manual registration needed.

### 3. Configuration

`Configuration` holds the search path tables. The reference setup populates them like this:

- **`ServerModulePaths`** → `ServerScriptService/ServerSkills`
- **`ClientModulePaths`** → `ReplicatedStorage/ClientSkills`
- **`UtilityPaths`** → `ReplicatedStorage/Assets/Modules/Shared/Util` + the side-specific `Util` folder

To point the framework at different or additional folders, just insert more paths:

```lua
-- Point server modules to a different or additional folder
table.insert(Configuration.ServerModulePaths, ServerScriptService:WaitForChild("CombatSkills"))
table.insert(Configuration.ServerModulePaths, ServerScriptService:WaitForChild("MovementSkills"))

-- Add more client module locations
table.insert(Configuration.ClientModulePaths, ReplicatedStorage:WaitForChild("UISkills"))

-- Add more utility locations
table.insert(Configuration.UtilityPaths, ReplicatedStorage:WaitForChild("SharedHelpers"))
```

Sub-folders inside any registered path are searched automatically.

---

## Packet API

All cross-boundary communication goes through `Packets`, which wraps two `RemoteEvent`s:

```lua
local Packets = require(ReplicatedStorage.Remotes.Packets)

-- Client → Server
Packets.ServerRemote:Fire(Character, Params, Data?)

-- Server → All clients (broadcast)
Packets.ReplicateRemote:Fire(Character, Params, Data?)

-- Server → One specific client
Packets.ReplicateRemote:FireClient(Player, Character, Params, Data?)
```

### `Params`

```lua
type Params = {
    Module: string?,   -- name of an S_ or C_ module (without the prefix)
    Utility: string?,  -- name of a utility module (no prefix required)
    Function: string,  -- the function to call on the resolved module
}
```

Provide either `Module` or `Utility` — not both. `Module` takes priority if both are present.

### `Character`

`Character` is a `Model` — in practice, always the player's character. It travels as the first argument on every packet so that both sides always have unambiguous context for who the action belongs to.

### `Data`

An optional free-form table of extra information for the receiving function. Defaults to `{}` if omitted.

---

## Function Signatures

The signatures differ between server and client because the two sides have different needs.

### Server (`S_` modules) — called by `UniHandler`

```lua
module.SomeFunction = function(Character: Model, data: any, player: Player)
```

| Argument | Type | Description |
|---|---|---|
| `Character` | `Model` | The character model passed in the packet. Used to identify who triggered the action and to apply server-side effects. |
| `data` | `any` (usually a table) | The `extraData` table sent with the packet. Contains whatever the client included — cooldown tokens, input info, targeting data, etc. Defaults to `{}`. |
| `player` | `Player` | The `Player` instance who fired `ServerRemote`. Provided by `UniHandler` from the `OnServerEvent` callback — you don't pass this manually. Use it for ownership checks, `FireClient`, etc. |

`Character` comes before `data` because it represents the action's subject and is always present. `player` comes last because it's a derived value — `UniHandler` gets it from the event itself and appends it, so your client code never needs to include it.

### Client (`C_` modules) — called by `UniReplicator`

```lua
module.SomeFunction = function(args: { Character: Model, [any]: any })
```

| Argument | Type | Description |
|---|---|---|
| `args` | table | The `extraData` table sent from the server, with `Character` automatically injected into it by `UniReplicator`. All data arrives in one flat table. |
| `args.Character` | `Model` | Injected by `UniReplicator` from the packet's `Character` field. Always present. |

On the client there's only one argument because everything — the character and the payload — is merged into a single `args` table by `UniReplicator`. This keeps replicated function calls simple: one table in, everything you need is inside it.

> Note: `C_` functions with the pattern above are for **replicated** calls dispatched by `UniReplicator`. Functions you call directly from your own code (like `C_Punch.Start`) can take whatever arguments make sense for that call site — they're just normal Lua functions that happen to live in the module.

---

## Writing Modules

### Client Module (`C_`)

Place in `ReplicatedStorage/ClientSkills/` (or any registered `ClientModulePaths` folder). Name must start with `C_`.

A client module typically has two kinds of functions:

- Functions **you call directly** (e.g. from a Tool's `Activated` event) to run local prediction and fire the server
- Functions **UniReplicator calls** to apply server-confirmed effects

```lua
-- C_Punch
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Remotes.Packets)
local highlight = require(...) -- your highlight utility

local module = {}

-- Called directly by your own code, e.g. from a Tool's Activated event.
-- char is the LocalPlayer's character, passed in by the caller.
-- Runs local prediction (animation, etc.) immediately, then notifies the server.
module.Start = function(char: Packets.Character)
    -- play animation locally for instant feedback (prediction)
    Packets.ServerRemote:Fire(char, { Module = "Punch", Function = "Activate" })
end

-- Called by UniReplicator when the server replicates a confirmed effect.
-- args.Character is injected automatically — no need to pass it from the server separately.
module.Effects = function(args: Packets.Args)
    if args.Type == "Highlight" then
        highlight.Create({
            Character = args.Character,
            Color = Color3.fromRGB(255, 0, 0),
            Transparency = 0.5,
            FadeDuration = 1,
        })
    end
end

return module
```

Calling `Start` from a Tool:

```lua
-- inside a Tool's LocalScript
local C_Punch = require(ReplicatedStorage.ClientSkills.Base.Punch.C_Punch)
local char = game.Players.LocalPlayer.Character

tool.Activated:Connect(function()
    C_Punch.Start(char)
end)
```
Again, you can still call the module from any local method possible; such as input systems tools and etc, as long as you properly require the client module from the starting input, you are good to go.
---

### Server Module (`S_`)

Place in `ServerScriptService/ServerSkills/` (or any registered `ServerModulePaths` folder). Name must start with `S_`.

The server module is where validation and authoritative logic lives. After the client has already played its local prediction, this runs and decides whether the action is legitimate — then replicates the confirmed result.

```lua
-- S_Punch
--!strict
local Players = game:GetService("Players")
local Packets = require(game.ReplicatedStorage.Remotes.Packets)

local module = {}

module.Activate = function(Character: Packets.Character, data: any, player: Player)
    -- validate: check cooldown, range, character state, etc.
    -- if invalid, simply return without replicating

    warn("Punch validated for:", Character.Name)

    -- Replicate confirmed effect to all clients
    Packets.ReplicateRemote:Fire(Character, { Module = "Punch", Function = "Effects" }, {
        Type = "Highlight"
    })

    -- Or replicate only to the acting player (e.g. for personal feedback)
    Packets.ReplicateRemote:FireClient(player, Character, { Module = "Punch", Function = "Effects" }, {
        Type = "Highlight"
    })
end

return module
```

---

### Utility Module

Place in any folder listed under `UtilityPaths`. No prefix. Utility modules are reachable from either side.

```lua
-- Highlight (ReplicatedStorage/Assets/Modules/Shared/Util/Highlight)
local module = {}

module.Create = function(config: { Character: Model, Color: Color3, Transparency: number, FadeDuration: number })
    -- apply highlight to config.Character
end

return module
```

Reference via `Utility` in params instead of `Module`:

```lua
Packets.ReplicateRemote:Fire(char, { Utility = "Highlight", Function = "Create" }, { ... })
```

---

## How Dispatch Works Internally

### UniHandler (server)

1. Listens on `Packets.ServerRemote.OnServerEvent`
2. Reads `params.Module` or `params.Utility` to resolve the module name
3. If `Module` → prepends `S_`, searches `ServerModulePaths`; if `Utility` → searches `UtilityPaths` as-is
4. `require`s the module (result is cached by name after first load)
5. Calls `module[params.Function](Character, extraData, player)` via `task.spawn`

### UniReplicator (client)

1. Listens on `Packets.ReplicateRemote.OnClientEvent`
2. Same lookup logic, but prepends `C_` and searches `ClientModulePaths`
3. Injects `Character` into the `extraData` table: `data["Character"] = Character`
4. Calls `module[params.Function](extraData)` via `task.spawn`

---

## Module Caching

Both `UniHandler` and `UniReplicator` cache `require` results by module name. A module is loaded exactly once per session — all subsequent dispatches to the same module reuse the cached table.

---

## Notes & Limitations

- Module names must be **unique** within their search paths. The framework uses the first match it finds.
- `params.Module` takes priority over `params.Utility` if both keys are present.
- Functions run inside `task.spawn`, so errors won't surface to the caller — use `warn` or a logging utility inside your functions - in works.
- `extraData` / `data` defaults to `{}` if not provided in the `Fire` call.
- The framework does **not** verify that the firing player owns the `Character` they pass. Add your own check in `S_` modules where it matters: `Players:GetPlayerFromCharacter(Character) == player`,Why? because this system can also work for npcs.
### Credits:
https://devforum.roblox.com/t/packet-networking-library/3573907?page=4 -- Thanks to suphi for Packets ( required for use )
