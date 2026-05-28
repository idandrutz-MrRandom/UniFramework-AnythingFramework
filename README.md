# UniFramework

A prediction-based remote dispatch framework for Roblox. The client acts immediately — playing animations, showing effects, responding to input — while the server receives the action, validates it, and replicates the authoritative result back. This keeps gameplay feeling responsive while still giving the server full control over what actually counts.

The system can also start entirely from the server and replicate effects outward to clients, but it was specifically designed to shine with client-side prediction.

**Example:** a player throws a punch. The client plays the animation instantly. The server receives the request, checks if the punch is valid (cooldown, range, character state), and only then replicates the hit effect to other clients. The client never waits on the server for things the player should feel immediately.

UniFramework handles the plumbing for this pattern — a single shared remote infrastructure that routes calls to the right module and function on either side, with zero per-feature wiring. Adding a new skill means dropping two files in the right folders. No remotes to create, no handlers to register.

```
[Client] Tool activated → C_Punch.Start(char)
    │  plays local animation immediately (prediction)
    └─► ServerRemote:Fire({ Module="Punch", Function="Activate", Character=char })
              │
         [UniHandler] → validates ownership → finds S_Punch → S_Punch.Activate(args, player)
              │  server validates the action
              └─► ReplicateRemote:Fire({ Module="Punch", Function="Effects", Character=char }, { Type="Highlight" })
                        │
                   [UniReplicator] → finds C_Punch → C_Punch.Effects(args)
                        └─► renders confirmed effect on all clients
```

> **Server-first is supported too.** NPCs and server scripts can call `S_` modules directly — no remote needed. The module runs on the server and replicates to clients as normal.

---

## Table of Contents

- [Architecture](#architecture)
- [Setup](#setup)
  - [Folder Structure](#1-folder-structure)
  - [Naming Convention](#2-naming-convention)
  - [Configuration](#3-configuration)
- [Packet API](#packet-api)
- [Function Signatures](#function-signatures)
- [Writing Modules](#writing-modules)
  - [Client Module C\_](#client-module-c_)
  - [Server Module S\_](#server-module-s_)
  - [Utility Module](#utility-module)
  - [Characterless Calls](#characterless-calls)
- [How Dispatch Works Internally](#how-dispatch-works-internally)
- [Security — Anti-Spoof](#security--anti-spoof)
- [Module Caching](#module-caching)
- [NPC Activation](#npc-activation)
- [Notes & Limitations](#notes--limitations)
- [Credits](#credits)

---

## Architecture

| Module | Type | Location | Role |
|---|---|---|---|
| `UniHandler` | Script | ServerScriptService | Listens on `ServerRemote`, validates ownership, dispatches to `S_` modules |
| `UniReplicator` | LocalScript | StarterPlayerScripts | Listens on `ReplicateRemote`, dispatches to `C_` modules |
| `Packets` | Shared ModuleScript | ReplicatedStorage/Remotes | Wraps and exposes the two remotes with typed helpers |
| `Configuration` | Shared ModuleScript | ReplicatedStorage/Assets/Modules | Declares where skill modules and utilities live |

Two remotes. Two universal handlers. Any number of skills.

```
┌───────────────────────────────────────────────────────────────┐
│  CLIENT                                                       │
│                                                               │
│  Tool / UI / Input System                                     │
│        │  C_Punch.Start(char)   ← you call this directly      │
│        ▼                                                      │
│  C_Punch  ──── ServerRemote:Fire(params) ──────────────────►  │
│                                                               │
│  C_Punch  ◄── UniReplicator ◄── ReplicateRemote               │
│  .Effects()     (routes by         (from server)              │
│                  module name)                                 │
└───────────────────────────────────────────────────────────────┘
                        │ ServerRemote (Roblox Remote)
┌───────────────────────▼───────────────────────────────────────┐
│  SERVER                                                       │
│                                                               │
│  UniHandler                                                   │
│  (OnServerEvent)                                              │
│        │  ownership check → resolves "S_Punch"               │
│        ▼                                                      │
│  S_Punch.Activate(args, player)                               │
│        │  validates, then:                                    │
│        └── ReplicateRemote:Fire(params, data) ──────────────► │
│                                         (broadcasts to all    │
│                                          clients via          │
│                                          UniReplicator)       │
└───────────────────────────────────────────────────────────────┘
```

---

## Setup

### 1. Folder Structure

The framework doesn't enforce a rigid structure — as long as your paths are registered in `Configuration`, the handlers will find your modules. Below is the **reference layout** used in the example project:

```
ReplicatedStorage/
├── Assets/
│   └── Modules/
│       ├── Configuration            ← shared config module
│       ├── Shared/
│       │   └── Util/                ← utility modules (both sides)
│       ├── Server/
│       │   └── Util/                ← server-only utilities
│       └── Client/
│           └── Util/                ← client-only utilities
├── ClientSkills/
│   └── Base/
│       └── Punch/
│           └── C_Punch              ← client skill module
└── Remotes/
    └── Packets                      ← shared Packets module

ServerScriptService/
├── ServerSkills/
│   └── Punch/
│       └── S_Punch                  ← server skill module
└── UniHandler                       ← server dispatcher (Script)

StarterPlayer/
└── StarterPlayerScripts/
    └── UniReplicator                ← client dispatcher (LocalScript)
```

> **This is one working example.** The only hard requirements are that `UniHandler` runs as a server `Script` and `UniReplicator` runs as a `LocalScript`. Everything else — folder names, nesting depth, grouping — is up to you, as long as the paths are registered in `Configuration`.

Skill modules can be flat or nested inside their container; the recursive search in both handlers handles both patterns:

```
-- Flat (all at root of the container)
ServerSkills/
├── S_Punch
├── S_Kick
└── S_Dash

-- Nested by skill name (reference setup style)
ServerSkills/
├── Punch/
│   └── S_Punch
├── Kick/
│   └── S_Kick
└── Dash/
    └── S_Dash
```

Both layouts work. Mix them freely within the same container.

---

### 2. Naming Convention

| Module type | Prefix | Example |
|---|---|---|
| Server-side skill logic | `S_` | `S_Punch` |
| Client-side skill logic | `C_` | `C_Punch` |
| Shared utilities | *(none)* | `Highlight` |

Module names must be **unique** within their search scope. The handler takes the first match it finds when scanning descendants. If you have two modules named `S_Punch` in different subfolders under the same container, only one will ever be reached — avoid duplicate names.

---

### 3. Configuration

`Configuration` holds the path tables that tell both handlers where to look for modules. Populate them based on where you put your skill folders:

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type Config = {
    ServerModulePaths: { Instance },
    ClientModulePaths: { Instance },
    UtilityPaths: { Instance },
}

local Configuration: Config = {
    ServerModulePaths = {},
    ClientModulePaths = {},
    UtilityPaths = {},
}

-- Shared utilities — accessible by both sides
table.insert(Configuration.UtilityPaths, ReplicatedStorage.Assets.Modules.Shared.Util)

if RunService:IsServer() then
    local ServerScriptService = game:GetService("ServerScriptService")
    table.insert(Configuration.ServerModulePaths, ServerScriptService:WaitForChild("ServerSkills"))
    local serverUtil = ReplicatedStorage.Assets.Modules.Server:FindFirstChild("Util")
    if serverUtil then
        table.insert(Configuration.UtilityPaths, serverUtil)
    end
else
    table.insert(Configuration.ClientModulePaths, ReplicatedStorage:WaitForChild("ClientSkills"))
    local clientUtil = ReplicatedStorage.Assets.Modules.Client:FindFirstChild("Util")
    if clientUtil then
        table.insert(Configuration.UtilityPaths, clientUtil)
    end
end

return Configuration
```

To add more folders, insert them the same way:

```lua
-- More server skill containers
table.insert(Configuration.ServerModulePaths, ServerScriptService:WaitForChild("CombatSkills"))
table.insert(Configuration.ServerModulePaths, ServerScriptService:WaitForChild("MovementSkills"))

-- More client skill containers
table.insert(Configuration.ClientModulePaths, ReplicatedStorage:WaitForChild("UISkills"))

-- More shared utilities
table.insert(Configuration.UtilityPaths, ReplicatedStorage:WaitForChild("SharedHelpers"))
```

Sub-folders inside any registered path are searched automatically — you never need to register individual skill folders, only the root containers.

---

## Packet API

All cross-boundary communication goes through `Packets`, which wraps two `RemoteEvent`s:

```lua
local Packets = require(ReplicatedStorage.Remotes.Packets)

-- Client → Server
Packets.ServerRemote:Fire(Params, Data?)

-- Server → All clients (broadcast)
Packets.ReplicateRemote:Fire(Params, Data?)

-- Server → One specific client
Packets.ReplicateRemote:FireClient(Player, Params, Data?)
```

### Params

```lua
export type Params = {
    Module: string?,    -- name of an S_ or C_ module (without the prefix)
    Utility: string?,   -- name of a utility module (exact name, no prefix)
    Function: string,   -- the function to call on the resolved module
    Character: Model?,  -- optional: the character involved, if any
}
```

Provide either `Module` or `Utility`, not both. If both are present, `Module` takes priority.

`Character` is optional throughout the system. Calls that have no character context — opening a shop, triggering a global event, running UI logic — simply omit it. The handlers only inject `Character` into the call data when it is present.

### Data

An optional free-form table of extra information for the receiving function. Defaults to `{}` if omitted. You can put anything in here: combo counts, targeting info, item IDs, input state.

```lua
-- Example with extra data
Packets.ServerRemote:Fire({
    Module = "Punch",
    Function = "Activate",
    Character = char,
}, {
    ComboCount = 3,
    TargetId = hit.Parent.Name,
})
```

---

## Function Signatures

### Server (`S_` modules) — called by UniHandler

```lua
module.SomeFunction = function(args: Packets.Args, player: Player?)
```

| Argument | Type | Description |
|---|---|---|
| `args` | `Packets.Args` | Merged call data. Contains `args.Character` (if provided) plus everything from the `Data` payload. |
| `args.Character` | `Model?` | The character model from the packet. Always the sender's own character — `UniHandler` rejects anything else. May be `nil` for characterless calls. |
| `player` | `Player?` | The player who fired `ServerRemote`. `nil` when the call originates from the server itself (NPC, server script). Use for ownership checks, `FireClient`, anti-cheat. |

### Client (`C_` modules) — called by UniReplicator

```lua
module.SomeFunction = function(args: Packets.Args)
```

| Argument | Type | Description |
|---|---|---|
| `args` | `Packets.Args` | Merged call data. `UniReplicator` injects `args.Character` automatically from the packet. Everything from `Data` is also in this table. |
| `args.Character` | `Model?` | Injected by `UniReplicator`. May be `nil` if the server didn't include a character — guard before use. |

> `C_` functions with this signature are for **replicated** calls dispatched by `UniReplicator`. Functions you call directly from your own code (like `C_Punch.Start` from a tool) can take any arguments you like — they are regular Lua functions that happen to live in the module.

---

## Writing Modules

### Client Module (`C_`)

Place in `ReplicatedStorage/ClientSkills/` (or any folder registered under `ClientModulePaths`). The file name must start with `C_`.

A client module typically contains two kinds of functions:

- **Direct-call functions** — you call these yourself from tools, input handlers, UI scripts, etc. They run local prediction and fire the server.
- **Replicated functions** — `UniReplicator` calls these when the server broadcasts a confirmed result.

```lua
-- C_Punch.lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Remotes.Packets)
local Players = game:GetService("Players")
local highlight = require(
    ReplicatedStorage:WaitForChild("Assets")
        :WaitForChild("Modules")
        :WaitForChild("Client")
        :WaitForChild("Util")
        :WaitForChild("Highlight") :: ModuleScript
) :: any

local module = {}

-- Called directly by your own code (tool, input controller, etc.)
-- Also called by UniReplicator when an NPC activates this skill server-side.
-- The GetPlayerFromCharacter check handles both cases:
--   - Direct call from local player → passes, fires server
--   - Replicated NPC call → fails (NPC is not a player), stops here
module.Start = function(args: Packets.Args)
    local char = if typeof(args) == "table" then args.Character else (args :: any)
    if not char then return end

    -- play local animation here for instant feedback (prediction)
    -- e.g. animator:LoadAnimation(punchAnim):Play()

    if Players:GetPlayerFromCharacter(char) then
        -- char belongs to a player — fire the server to validate and replicate
        Packets.ServerRemote:Fire({
            Module = "Punch",
            Function = "Activate",
            Character = char,
        })
    end
    -- if char is an NPC, we stop here — no server call, no loop
end

-- Called by UniReplicator when the server confirms and replicates the effect.
-- args.Character is injected automatically.
module.Effects = function(args: Packets.Args)
    local char = args.Character
    if args.Type == "Highlight" and char then
        highlight.Create({
            Character = char,
            Color = Color3.fromRGB(255, 0, 0),
            Transparency = 0.5,
            FadeDuration = 1,
        })
    end
end

return module
```

**Calling `Start` from a Tool:**

```lua
--!strict
local Tool = script.Parent
local SkillMod = require(game.ReplicatedStorage.ClientSkills.Base.Punch.C_Punch) :: any

Tool.Activated:Connect(function()
    local Character = Tool.Parent :: any
    SkillMod.Start(Character)
end)
```

**Calling `Start` from a custom input controller:**

```lua
local UserInputService = game:GetService("UserInputService")
local C_Punch = require(ReplicatedStorage.ClientSkills.Base.Punch.C_Punch)
local player = game.Players.LocalPlayer

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.E then
        C_Punch.Start(player.Character)
    end
end)
```

You can call `C_` module functions from anywhere on the client — tools, input systems, UI buttons, proximity prompts. Pass either the character model directly or a table with a `Character` field; both are handled.

---

### Server Module (`S_`)

Place in `ServerScriptService/ServerSkills/` (or any folder registered under `ServerModulePaths`). The file name must start with `S_`.

This is where validation and authoritative logic lives. The client has already played its local prediction — your job here is to decide whether the action is legitimate, then replicate the confirmed result.

```lua
-- S_Punch.lua
--!strict
local Packets = require(game.ReplicatedStorage.Remotes.Packets)
local Packet = Packets.ReplicateRemote

local module = {}

module.Activate = function(args: Packets.Args, player: Player?)
    local char = args.Character

    -- Validate the action before doing anything.
    -- Return early (no replication) if invalid.
    -- if OnCooldown(player) then return end
    -- if not IsInRange(char) then return end

    if not player then
        -- NPC path: C_Punch.Start was never called on any client.
        -- Replicate it now so all clients run the local setup (animations etc.)
        -- C_Punch.Start will see an NPC character and stop before re-firing the server.
        Packet:Fire({
            Module = "Punch",
            Function = "Start",
            Character = char,
        })
    end

    -- Replicate confirmed effect to ALL clients
    Packet:Fire({
        Module = "Punch",
        Function = "Effects",
        Character = char,
    }, { Type = "Highlight" })
end

return module
```

**When to use `Fire` vs `FireClient`:**

| Method | Who receives it | Use case |
|---|---|---|
| `Packet:Fire(...)` | All connected clients | Hit effects, world state changes, animations others should see |
| `Packet:FireClient(player, ...)` | One specific client | Personal feedback, UI updates, correcting a misprediction |

---

### Utility Module

Place in any folder listed under `UtilityPaths`. No prefix. Utility modules are reachable from both sides.

```lua
-- Highlight.lua  (ReplicatedStorage/Assets/Modules/Shared/Util/Highlight)
local module = {}

module.Create = function(config: {
    Character: Model,
    Color: Color3,
    Transparency: number,
    FadeDuration: number,
})
    local h = Instance.new("Highlight")
    h.FillColor = config.Color
    h.FillTransparency = config.Transparency
    h.Parent = config.Character
    task.delay(config.FadeDuration, function()
        h:Destroy()
    end)
end

return module
```

To invoke a utility module through the remote system, use `Utility` instead of `Module` in your params:

```lua
Packets.ReplicateRemote:Fire({
    Utility = "Highlight",
    Function = "Create",
    Character = char,
}, {
    Color = Color3.fromRGB(255, 255, 0),
    Transparency = 0.3,
    FadeDuration = 2,
})
```

Or call it directly if you are already on the right side — no remote needed:

```lua
local highlight = require(ReplicatedStorage.Assets.Modules.Shared.Util.Highlight)
highlight.Create({ Character = char, Color = Color3.new(1,0,0), Transparency = 0.5, FadeDuration = 1 })
```

---

### Characterless Calls

`Character` is always optional. Any call that doesn't involve a specific character simply omits it.

**From the client — opening a shop:**

```lua
Packets.ServerRemote:Fire({
    Module = "Shop",
    Function = "Open",
}, {
    ItemId = 42,
})
```

**From the server — broadcasting a global world event:**

```lua
Packets.ReplicateRemote:Fire({
    Module = "World",
    Function = "OnNightfall",
}, {
    Phase = "night",
    Duration = 120,
})
```

**The receiving module handles nil gracefully:**

```lua
-- S_Shop.lua
module.Open = function(args: Packets.Args, player: Player?)
    local itemId = args.ItemId  -- args.Character is nil here — expected and fine
end
```

---

## How Dispatch Works Internally

### UniHandler (server)

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage:FindFirstChild("Assets")
local Config = require(Assets:FindFirstChild("Modules"):WaitForChild("Configuration"))
local Players = game:GetService("Players")
local Packets = require(ReplicatedStorage.Remotes.Packets)

local CachedModules: { [string]: any } = {}

local function SearchPaths(paths: { Instance }, name: string): ModuleScript?
    for _, path in ipairs(paths) do
        for _, descendant in ipairs(path:GetDescendants()) do
            if descendant:IsA("ModuleScript") and descendant.Name == name then
                return descendant
            end
        end
    end
    return nil
end

local function GetModule(name: string, isNamespace: boolean): any?
    if CachedModules[name] then return CachedModules[name] end
    local searchName = isNamespace and ("S_" .. name) or name
    local paths = isNamespace and Config.ServerModulePaths or Config.UtilityPaths
    local modScript = SearchPaths(paths, searchName)
    if modScript then
        local ok, result = pcall(require, modScript)
        if ok then
            CachedModules[name] = result
            return result
        end
    end
    return nil
end

Packets.ServerRemote.OnServerEvent:Connect(function(player: Player, params: any, data: any)
    local pms = params :: Packets.Params
    if not pms then return end

    local module = GetModule(pms.Module or pms.Utility or "", pms.Module ~= nil)
    if not module then return end

    local func = module[pms.Function]
    if typeof(func) ~= "function" then return end

    local callData: { [any]: any } = if typeof(data) == "table" then data else {}

    if pms.Character then
        -- Anti-spoof: only accept the character if it belongs to the sender.
        -- Rejects other players' characters, NPC models, and fabricated references.
        if Players:GetPlayerFromCharacter(pms.Character) == player then
            callData.Character = pms.Character
        else
            warn("UniHandler: character mismatch from", player.Name)
            return
        end
    end

    func(callData, player)
end :: any)

return {}
```

Step by step:

1. `OnServerEvent` fires — Roblox provides `player` automatically as the first arg
2. `params` is read as `Packets.Params` to get `Module`/`Utility` and `Function`
3. If `Module` is set → prepend `S_`, search `ServerModulePaths`; if `Utility` → search `UtilityPaths` as-is
4. Module is `require`d and cached by name
5. If `Character` is provided, ownership is validated — rejects anything that isn't the sender's own character
6. `module[Function](callData, player)` is called

### UniReplicator (client)

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage:FindFirstChild("Assets")
local Config = require(Assets:FindFirstChild("Modules"):WaitForChild("Configuration"))
local Packets = require(ReplicatedStorage.Remotes.Packets)

local CachedModules: { [string]: any } = {}

local function SearchPaths(paths: { Instance }, name: string): ModuleScript?
    for _, path in ipairs(paths) do
        for _, descendant in ipairs(path:GetDescendants()) do
            if descendant:IsA("ModuleScript") and descendant.Name == name then
                return descendant
            end
        end
    end
    return nil
end

local function GetModule(name: string, isNamespace: boolean): any?
    if CachedModules[name] then return CachedModules[name] end
    local searchName = isNamespace and ("C_" .. name) or name
    local paths = isNamespace and Config.ClientModulePaths or Config.UtilityPaths
    local modScript = SearchPaths(paths, searchName)
    if modScript then
        local ok, result = pcall(require, modScript)
        if ok then
            CachedModules[name] = result
            return result
        end
    end
    return nil
end

Packets.ReplicateRemote.OnClientEvent:Connect(function(params: any, data: any)
    local pms = params :: Packets.Params
    if not pms then return end

    local module = GetModule(pms.Module or pms.Utility or "", pms.Module ~= nil)
    if not module then return end

    local func = module[pms.Function]
    if typeof(func) ~= "function" then return end

    local callData: { [any]: any } = if typeof(data) == "table" then data else {}
    if pms.Character then
        callData.Character = pms.Character
    end

    func(callData)
end :: any)

return {}
```

Mirrors UniHandler exactly, with one difference: no ownership check is needed here because this remote only fires from the server — clients cannot call `OnClientEvent` on each other.

---

## Security — Anti-Spoof

`UniHandler` validates every incoming `ServerRemote` call before anything runs.

```lua
if Players:GetPlayerFromCharacter(pms.Character) == player then
    callData.Character = pms.Character
else
    warn("UniHandler: character mismatch from", player.Name)
    return
end
```

This single check covers all attack vectors:

| Client sends | `GetPlayerFromCharacter` result | Outcome |
|---|---|---|
| Their own character | Returns `player` — matches | ✅ Accepted |
| Another player's character | Returns a different `Player` | ❌ Rejected |
| An NPC model | Returns `nil` | ❌ Rejected |
| A destroyed / fake model | Returns `nil` | ❌ Rejected |
| No character (characterless call) | Check is skipped entirely | ✅ Accepted |

NPCs call `S_` modules directly on the server and never go through `OnServerEvent`, so they are unaffected by this check.

On the client side, `C_Punch.Start` has a matching guard:

```lua
if Players:GetPlayerFromCharacter(char) then
    Packets.ServerRemote:Fire({ ... })
end
```

This means:
- When `Start` is called directly from a tool with the local player's character → `GetPlayerFromCharacter` returns a Player → fires server
- When `Start` is replicated to all clients by `UniReplicator` after an NPC activation → `char` is the NPC model → `GetPlayerFromCharacter` returns `nil` → stops, no loop

The two checks work independently. Even if the client-side check is bypassed by an exploiter, the server-side check rejects it.

---

## Module Caching

Both handlers cache `require` results by module name after the first load. A module is required exactly once per session — every subsequent dispatch reuses the cached table.

```
First call  → SearchPaths → require → cache["Punch"] = module → call function
Second call → cache["Punch"] exists → call function directly
```

Module-level state (variables declared at the top of the module) persists across calls. If you need per-call state, keep it inside the function or in a dedicated state module.

---

## NPC Activation

NPCs and server scripts call `S_` modules directly — no remote involved. The module runs on the server and replicates to clients the same way it would for a player.

```lua
--!strict
task.wait(1)
local ServerScriptService = game:GetService("ServerScriptService")
local S_Punch = require(
    ServerScriptService:WaitForChild("ServerSkills")
        :FindFirstChild("Punch")
        :FindFirstChild("S_Punch")
) :: any

while true do
    task.wait(2)
    S_Punch.Activate({ Character = script.Parent })
end
```

### The NPC flow gap — and how to close it

When a **player** activates a skill:

```
C_Punch.Start (client) → ServerRemote → S_Punch.Activate (server) → ReplicateRemote → C_Punch.Effects (all clients)
```

When an **NPC** activates the same skill, `S_Punch.Activate` is called directly. `C_Punch.Start` was never called on any client — so animations and pre-effects are skipped. To fix this, `S_Punch` replicates `Start` to all clients when `player` is `nil`:

```lua
module.Activate = function(args: Packets.Args, player: Player?)
    if not player then
        -- NPC path: replicate Start so clients can play the attack animation
        Packet:Fire({
            Module = "Punch",
            Function = "Start",
            Character = args.Character,
        })
    end

    Packet:Fire({
        Module = "Punch",
        Function = "Effects",
        Character = args.Character,
    }, { Type = "Highlight" })
end
```

### Loop prevention

When `UniReplicator` calls `C_Punch.Start` on every client with the NPC's character, the `GetPlayerFromCharacter` check inside `Start` returns `nil` for the NPC model — so it stops before firing `ServerRemote`. No loop.

```lua
module.Start = function(args: Packets.Args)
    local char = if typeof(args) == "table" then args.Character else (args :: any)
    if not char then return end

    if Players:GetPlayerFromCharacter(char) then
        -- char is a player character — fire the server
        Packets.ServerRemote:Fire({
            Module = "Punch",
            Function = "Activate",
            Character = char,
        })
    end
    -- char is an NPC — stops here, no server call
end
```

| Origin | `GetPlayerFromCharacter(char)` | Server fired? |
|---|---|---|
| Player activates tool directly | Returns a `Player` | ✅ Yes |
| NPC action replicated via `UniReplicator` | Returns `nil` | ❌ No — loop blocked |

### Full NPC flow

```
[Server] NPC script → S_Punch.Activate({ Character = npc })
    │  player is nil → replicate Start to all clients
    ├─► ReplicateRemote:Fire({ Module="Punch", Function="Start", Character=npc })
    │         │
    │    [UniReplicator] → C_Punch.Start(args)
    │         │  GetPlayerFromCharacter(npc) = nil → stops, no server call ✅
    │
    └─► ReplicateRemote:Fire({ Module="Punch", Function="Effects", Character=npc })
              │
         [UniReplicator] → C_Punch.Effects → highlight on all clients
```

Compare with the player flow:

```
[Client] Tool activated → C_Punch.Start(playerChar)
    │  GetPlayerFromCharacter(playerChar) = Player → fires ServerRemote
              │
         [UniHandler] → ownership check passes → S_Punch.Activate(args, player)
              │  player is not nil → skip Start replication
              └─► ReplicateRemote:Fire({ Module="Punch", Function="Effects" })
                        │
                   [UniReplicator] → C_Punch.Effects on all clients
```

---

## Notes & Limitations

- **Module names must be unique** within their search scope. The handler takes the first match found when scanning descendants.
- **`Module` takes priority over `Utility`** if both keys are present in a single `Params` table.
- **Errors inside dispatched functions won't surface to the caller.** Use `warn` or `pcall` inside your functions for debugging.
- **`Data` defaults to `{}`** if not provided. Your functions always receive a table, never `nil`.
- **Character is always optional.** Guard with `if args.Character then` before using it in any module that might be called without one.
- Moduels that are required to being called characterless, have to do checks to make sure that the call isnt spoofed.
- **`UniHandler` rejects any character that doesn't belong to the sending player.** Clients can only pass their own character. NPCs call the server directly and bypass `OnServerEvent` entirely.
- ** This system still requires you to have exploit counter measures. make sure to make it ask the server for important stuff and never trust the client. because its prediction based, this system instantly does the client stuff and then requests the server side of the action, which MUST! have server check so people wont exploit it, and if they exploit the client part, it wont affect anyone drasticly.

**Planned:**
- Rollback system for misprediction correction (animations, state)
- Additional optimizations and QoL improvements

---

## Full Example Reference

Every file involved in the Punch skill, end to end.

<details>
<summary>Packets.lua</summary>

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packet = require(ReplicatedStorage.Assets.Modules.Shared.Util.MainModule)

export type Character = Model

export type Params = {
    Module: string?,
    Utility: string?,
    Function: string,
    Character: Character?,
}

export type Args = {
    Character: Character?,
    [any]: any
}

type RawPacket = {
    Fire: (self: any, Params: Params, Data: any?) -> (),
    FireClient: (self: any, Player: Player, Params: Params, Data: any?) -> (),
    OnServerEvent: any,
    OnClientEvent: any,
}

local function CreateRemote(Name: string): RawPacket
    local Raw = Packet(Name, Packet.Any, Packet.Any)
    local Wrapper = {}
    Wrapper.OnServerEvent = Raw.OnServerEvent
    Wrapper.OnClientEvent = Raw.OnClientEvent
    function Wrapper:Fire(Params: Params, Data: any?)
        Raw:Fire(Params, Data or {})
    end
    function Wrapper:FireClient(Player: Player, Params: Params, Data: any?)
        Raw:FireClient(Player, Params, Data or {})
    end
    return Wrapper :: any
end

return {
    ServerRemote    = CreateRemote("ServerRemote"),
    ReplicateRemote = CreateRemote("ReplicateRemote"),
}
```

</details>

<details>
<summary>Configuration.lua</summary>

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type Config = {
    ServerModulePaths: { Instance },
    ClientModulePaths: { Instance },
    UtilityPaths: { Instance },
}

local Configuration: Config = {
    ServerModulePaths = {},
    ClientModulePaths = {},
    UtilityPaths = {},
}

table.insert(Configuration.UtilityPaths, ReplicatedStorage.Assets.Modules.Shared.Util)

if RunService:IsServer() then
    local ServerScriptService = game:GetService("ServerScriptService")
    table.insert(Configuration.ServerModulePaths, ServerScriptService:WaitForChild("ServerSkills"))
    local serverUtil = ReplicatedStorage.Assets.Modules.Server:FindFirstChild("Util")
    if serverUtil then table.insert(Configuration.UtilityPaths, serverUtil) end
else
    table.insert(Configuration.ClientModulePaths, ReplicatedStorage:WaitForChild("ClientSkills"))
    local clientUtil = ReplicatedStorage.Assets.Modules.Client:FindFirstChild("Util")
    if clientUtil then table.insert(Configuration.UtilityPaths, clientUtil) end
end

return Configuration
```

</details>

<details>
<summary>UniHandler.lua (server Script)</summary>

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage:FindFirstChild("Assets")
local Config = require(Assets:FindFirstChild("Modules"):WaitForChild("Configuration"))
local Players = game:GetService("Players")
local Packets = require(ReplicatedStorage.Remotes.Packets)

local CachedModules: { [string]: any } = {}

local function SearchPaths(paths: { Instance }, name: string): ModuleScript?
    for _, path in ipairs(paths) do
        for _, descendant in ipairs(path:GetDescendants()) do
            if descendant:IsA("ModuleScript") and descendant.Name == name then
                return descendant
            end
        end
    end
    return nil
end

local function GetModule(name: string, isNamespace: boolean): any?
    if CachedModules[name] then return CachedModules[name] end
    local searchName = isNamespace and ("S_" .. name) or name
    local paths = isNamespace and Config.ServerModulePaths or Config.UtilityPaths
    local modScript = SearchPaths(paths, searchName)
    if modScript then
        local ok, result = pcall(require, modScript)
        if ok then
            CachedModules[name] = result
            return result
        end
    end
    return nil
end

Packets.ServerRemote.OnServerEvent:Connect(function(player: Player, params: any, data: any)
    local pms = params :: Packets.Params
    if not pms then return end

    local module = GetModule(pms.Module or pms.Utility or "", pms.Module ~= nil)
    if not module then return end

    local func = module[pms.Function]
    if typeof(func) ~= "function" then return end

    local callData: { [any]: any } = if typeof(data) == "table" then data else {}

    if pms.Character then
        if Players:GetPlayerFromCharacter(pms.Character) == player then
            callData.Character = pms.Character
        else
            warn("UniHandler: character mismatch from", player.Name)
            return
        end
    end

    func(callData, player)
end :: any)

return {}
```

</details>

<details>
<summary>UniReplicator.lua (LocalScript)</summary>

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage:FindFirstChild("Assets")
local Config = require(Assets:FindFirstChild("Modules"):WaitForChild("Configuration"))
local Packets = require(ReplicatedStorage.Remotes.Packets)

local CachedModules: { [string]: any } = {}

local function SearchPaths(paths: { Instance }, name: string): ModuleScript?
    for _, path in ipairs(paths) do
        for _, descendant in ipairs(path:GetDescendants()) do
            if descendant:IsA("ModuleScript") and descendant.Name == name then
                return descendant
            end
        end
    end
    return nil
end

local function GetModule(name: string, isNamespace: boolean): any?
    if CachedModules[name] then return CachedModules[name] end
    local searchName = isNamespace and ("C_" .. name) or name
    local paths = isNamespace and Config.ClientModulePaths or Config.UtilityPaths
    local modScript = SearchPaths(paths, searchName)
    if modScript then
        local ok, result = pcall(require, modScript)
        if ok then
            CachedModules[name] = result
            return result
        end
    end
    return nil
end

Packets.ReplicateRemote.OnClientEvent:Connect(function(params: any, data: any)
    local pms = params :: Packets.Params
    if not pms then return end

    local module = GetModule(pms.Module or pms.Utility or "", pms.Module ~= nil)
    if not module then return end

    local func = module[pms.Function]
    if typeof(func) ~= "function" then return end

    local callData: { [any]: any } = if typeof(data) == "table" then data else {}
    if pms.Character then
        callData.Character = pms.Character
    end

    func(callData)
end :: any)

return {}
```

</details>

<details>
<summary>C_Punch.lua</summary>

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Remotes.Packets)
local Players = game:GetService("Players")
local highlight = require(
    ReplicatedStorage:WaitForChild("Assets")
        :WaitForChild("Modules")
        :WaitForChild("Client")
        :WaitForChild("Util")
        :WaitForChild("Highlight") :: ModuleScript
) :: any

local module = {}

module.Start = function(args: Packets.Args)
    local char = if typeof(args) == "table" then args.Character else (args :: any)
    if not char then return end

    if Players:GetPlayerFromCharacter(char) then
        Packets.ServerRemote:Fire({
            Module = "Punch",
            Function = "Activate",
            Character = char,
        })
    end
end

module.Effects = function(args: Packets.Args)
    local char = args.Character
    if args.Type == "Highlight" and char then
        highlight.Create({
            Character = char,
            Color = Color3.fromRGB(255, 0, 0),
            Transparency = 0.5,
            FadeDuration = 1,
        })
    end
end

return module
```

</details>

<details>
<summary>S_Punch.lua</summary>

```lua
--!strict
local Packets = require(game.ReplicatedStorage.Remotes.Packets)
local Packet = Packets.ReplicateRemote

local module = {}

module.Activate = function(args: Packets.Args, player: Player?)
    local char = args.Character

    -- validate here: cooldown, range, etc.
    -- return early to silently reject without replicating

    if not player then
        -- NPC path: replicate Start to all clients
        Packet:Fire({
            Module = "Punch",
            Function = "Start",
            Character = char,
        })
    end

    Packet:Fire({
        Module = "Punch",
        Function = "Effects",
        Character = char,
    }, { Type = "Highlight" })
end

return module
```

</details>

<details>
<summary>Tool Activator (LocalScript inside Tool)</summary>

```lua
--!strict
local Tool = script.Parent
local SkillMod = require(game.ReplicatedStorage.ClientSkills.Base.Punch.C_Punch) :: any

Tool.Activated:Connect(function()
    local Character = Tool.Parent :: any
    SkillMod.Start(Character)
end)
```

</details>

<details>
<summary>NPC Activator (Script inside NPC model)</summary>

```lua
--!strict
task.wait(1)
local ServerScriptService = game:GetService("ServerScriptService")
local S_Punch = require(
    ServerScriptService:WaitForChild("ServerSkills")
        :FindFirstChild("Punch")
        :FindFirstChild("S_Punch")
) :: any

while true do
    task.wait(2)
    S_Punch.Activate({ Character = script.Parent })
end
```

</details>

---

## Credits

Built on top of [Packet](https://devforum.roblox.com/t/packet-networking-library/3573907) by suphi — a typed networking library required for the remote layer. Thanks suphi.
