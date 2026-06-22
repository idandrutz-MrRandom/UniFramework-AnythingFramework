# UniFramework

**A framework that allows BOTH server authority and validation and Client side prediction with correction!**

> **Get the latest files from the [Releases](../../releases) page** — grab the newest `Packets.lua`, `Configuration.lua`, and the DemoPlace `.rbxl` from there. The Packets module has been significantly optimized since the original version (string hashing, character compression, NPC id mapping, ping compensation) — always pull from Releases rather than copying old snippets out of this README.

## The Other parts of the system such as The Skills / utilities and The UniHandler / Replicator are up to date, grab them from the Current page and get the new packets and Configuration from the Releases!
MainModule in the ExamplePlace is the Packet Networking Library. Its in every demo and if you are planning on grabbing one for yourself, check out Packet networker.
---

## How it works

```
Tool / Trigger → C_Module.Start() → ServerRemote:Fire() → UniHandler (can do extra checks to validate if the call was right) → S_Module.Activate()
    → validates → ReplicateRemote → nearby clients
                ↓ (if "Fail" returned)
    UniHandler fires Correction packet → C_Module.Correction()
```

Two remotes drive everything:

| Remote | Direction | Purpose |
|---|---|---|
| `ServerRemote` | client → server | skill requests |
| `ReplicateRemote` | server → client(s) | effects, corrections |

Every packet carries a `Params` table:

```lua
type Params = {
    Module:    string?,     -- routes to C_/S_ prefixed modules
    Utility:   string?,     -- routes to plain utility modules
    Function:  string,      -- method name to call
    Character: Character?,  -- optional; validated server-side
    PingComp:  boolean?,    -- optional; request lag compensation for this call (see below)
}
```

And every received `Args` table now carries timing info automatically:

```lua
type Args = {
    Character:  Character?,
    ServerTime: number?,   -- internal; present only when PingComp was requested
    Lag:        number,    -- seconds of measured latency; 0 if PingComp wasn't requested
    [any]: any
}
```

---

## What changed in the optimized Packets module

The current `Packets.lua` (grab it from Releases) does everything the original version did, plus automatic bandwidth optimization with zero changes required to your skill code. You still write `Module`, `Function`, `Character` exactly the same way — the compression happens transparently inside `Pack`/`Unpack`.

| Optimization | What it does |
|---|---|
| **String hashing** | After the first time a given string (Module/Function/Data value) is sent to a recipient, only a small hash number is sent on every later call instead of the full string. |
| **Combined Module+Function key** | Module and Function are hashed together as one unit instead of two separate slots, since they always travel as a pair. |
| **Character compression** | `Character` is never sent as a raw Instance. `0` = the recipient's own character, a positive number = another player's `UserId`, a negative number = a small id assigned to an NPC. Two NPCs sharing the same `Name` never collide, since ids are assigned by object identity. |
| **NPC id teaching** | The very first time a given client sees a specific NPC, the server sends one slightly larger packet that teaches the client the exact id↔NPC mapping. Every call after that for the same NPC is back to a single small number. |
| **Optional slots** | `Utility` and `PingComp` only take up space on the wire when actually used — a normal `Module`/`Function`/`Character` call is the smallest possible shape. |
| **Data string compression** | String *values* inside your `Data` table (e.g. `{ Type = "Highlight" }`) go through the same hash cache as everything else. |
| **Ping compensation** | Set `PingComp = true` on a `Params` table to get `args.Lag` (seconds of measured latency) on the receiving end — useful for compensating animation/hitbox timing against network delay. Omit it and you pay nothing extra. |

### Turning optimizations on/off

All three are switches on `Configuration`, not on `Packets` itself — flip them from anywhere, takes effect immediately, no restart needed:

```lua
local Config = require(ReplicatedStorage.Assets.Modules.Configuration)

Config.HashingEnabled           = true -- string compression (Module/Function/Data values)
Config.CharacterHashingEnabled  = true -- character compression (0/UserId/NPC id)
Config.LagCompensationEnabled   = true -- ServerTime/Lag support for PingComp calls
```

These are useful for isolating a replication issue — if something behaves strangely, try flipping one off at a time to narrow down which compression path is involved.

### Using ping compensation in a skill

```lua
-- C_YourSkill — request lag compensation when firing
Packets.ServerRemote:Fire({
    Module    = "YourSkill",
    Function  = "Activate",
    Character = char,
    PingComp  = true,
})
```

```lua
-- S_YourSkill — read the measured lag on the receiving end
module.Activate = function(args: Packets.Args, player: Player?): string?
    local char = args.Character
    if not char then return "Fail" end

    local lag = args.Lag -- 0 if PingComp wasn't set on the Fire call
    task.delay(someDelay - lag, function()
        -- compensate hitbox/animation timing against the player's latency
    end)

    return nil
end
```

---

## Table of Contents

- [What changed in the optimized Packets module](#what-changed-in-the-optimized-packets-module)
- [Configuration — registering module paths](#configuration)
- [Module naming convention](#module-naming-convention)
- [Adding a new skill — step by step](#adding-a-new-skill)
  - [Step 1 — C_YourSkill (client module)](#step-1--c_yourskill-client-module)
  - [Step 2 — S_YourSkill (server module)](#step-2--s_yourskill-server-module)
  - [Step 3 — Register folders in Configuration](#step-3--register-folders-in-configuration)
  - [Step 4 — Wire up a trigger](#step-4--wire-up-a-trigger)
- [Predictive vs Non-Predictive mode](#predictive-vs-non-predictive-mode)
- [Corrections](#corrections)
- [NPC support](#npc-support)
- [Initialization](#initialization)
- [Dependencies](#dependencies)
- [Credits & issues](#credits--issues)

---

## Configuration

Add folders to `Configuration` so the framework can discover your modules at runtime.

```lua
-- ServerModulePaths: folders containing S_ modules
table.insert(Configuration.ServerModulePaths,
    ServerScriptService:WaitForChild("ServerSkills"))

-- ClientModulePaths: folders containing C_ modules
table.insert(Configuration.ClientModulePaths,
    ReplicatedStorage:WaitForChild("ClientSkills"))

-- UtilityPaths: shared helpers accessible by both sides
table.insert(Configuration.UtilityPaths,
    ReplicatedStorage.Assets.Modules.Shared.Util)
```

> **Note:** Add both the server and client folder for every system (e.g. `ServerSkills` + `ClientSkills`, `ServerShopTest` + `ClientShopTest`).

`RemoteDistance` controls how far away clients receive `FireCloseClients` replication (default: `650` studs).

`HashingEnabled`, `CharacterHashingEnabled`, and `LagCompensationEnabled` control the optimizations described above — all default to `true`.

> Get the current `Configuration.lua` (with these fields already present) from **Releases**, then add your own folder paths on top of it. Don't hand-merge an old `Configuration.lua` with a new `Packets.lua` — grab both together.

---

## Module naming convention

The framework auto-prefixes module names when searching. You never write the prefix in your packet — just the base name.

| Side | File name | Packet field |
|---|---|---|
| Server | `S_Punch` | `Module = "Punch"` |
| Client | `C_Punch` | `Module = "Punch"` |
| Utility | `Cooldowns` | `Utility = "Cooldowns"` |

Utility modules keep their exact name and are found via `UtilityPaths`.

---

## Adding a new skill

### Step 1 — C_YourSkill (client module)

Place this in a folder registered under `ClientModulePaths` (e.g. `ReplicatedStorage/ClientSkills/YourSkill/C_YourSkill`).

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local Packets           = require(ReplicatedStorage.Remotes.Packets)

local module: {[any]: any} = {}

local function getChar(args: Packets.Args)
    return if typeof(args) == "table" then args.Character else args
end

module.Start = function(args: Packets.Args): any
    local char = getChar(args)
    if not char then return end

    if Players:GetPlayerFromCharacter(char) then
        -- optional: add pre-checks here to reduce correction chances
        Packets.ServerRemote:Fire({
            Module    = "YourSkill",
            Function  = "Activate",
            Character = char
        })
    end

    -- play client-side effects/animations here (predictive mode)
    -- leave empty to be non-predictive (wait for server to replicate)

    return nil
end

module.Correction = function(args: Packets.Args)
    local char = getChar(args)
    if not char then return end
    -- undo any predicted state here
    args.Type = "Correction"
    module.Finish(args)
end

module.Effects = function(args: Packets.Args)
    -- handle visual effects by args.Type
end

module.Finish = function(args: Packets.Args)
    module.Effects(args)
end

return module
```

---

### Step 2 — S_YourSkill (server module)

Place this in a folder registered under `ServerModulePaths` (e.g. `ServerScriptService/ServerSkills/YourSkill/S_YourSkill`).

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets           = require(ReplicatedStorage.Remotes.Packets)
local Packet            = Packets.ReplicateRemote

local module: { [any]: any } = {}
local SavedTasks: { [any]: any } = {}

module.Activate = function(args: Packets.Args, player: Player?): string?
    local char = args.Character
    if not char then return "Fail" end

    -- your validation logic:
    -- if someCheckFails then return "Fail" end

    -- replicate Start to nearby clients (NPC path)
    if not player then
        Packet:FireCloseClients({
            Module = "YourSkill", Function = "Start", Character = char
        })
    end

    -- fire effects after validation passes
    Packet:FireCloseClients({
        Module = "YourSkill", Function = "Effects", Character = char
    }, { Type = "Action1" })

    local Tasks = task.spawn(function()
        module.Action1(args)
        task.wait(2)
        module.Cleanup(args)
    end)
    SavedTasks[char] = Tasks -- store if you need to cancel later

    return nil -- nil = success, "Fail" = triggers Correction on client
end

module.Action1 = function(args: Packets.Args)
    Packet:FireCloseClients({
        Module = "YourSkill", Function = "Effects", Character = args.Character
    }, { Type = "Action1" })
end

module.Cleanup = function(args: Packets.Args)
    local char = args.Character
    if not char then return end
    -- reset states, apply cooldowns, etc.
end

return module
```

> **Return value matters:** returning `nil` = success. Returning `"Fail"` (or any truthy value) = UniHandler fires `Correction` at the requesting client.

---

### Step 3 — Register folders in Configuration

```lua
-- in Configuration.lua
if RunService:IsServer() then
    table.insert(Configuration.ServerModulePaths,
        ServerScriptService:WaitForChild("ServerSkills"))
else
    table.insert(Configuration.ClientModulePaths,
        ReplicatedStorage:WaitForChild("ClientSkills"))
end
```

You can add as many folders as you want — just `table.insert` each one.

---

### Step 4 — Wire up a trigger

**Tool example:**

```lua
--!strict
local Tool     = script.Parent
local SkillMod = require(game.ReplicatedStorage.ClientSkills.YourSkill.C_YourSkill) :: any

Tool.Activated:Connect(function()
    local Character = Tool.Parent :: any
    if not Character:GetAttribute("Action") then
        SkillMod.Start(Character)
    end
end)
```

**ProximityPrompt example:**

```lua
--!strict
local ProximityPrompt = script.Parent:WaitForChild("ProximityPrompt") :: ProximityPrompt
local Shop = require(game.ReplicatedStorage.ClientShopTest.C_Shop)
local Open = false

ProximityPrompt.Triggered:Connect(function(player)
    if Open == false then
        Shop.Open({ Character = player.Character })
        Open = true
    else
        Shop.Close({ Character = player.Character })
        Open = false
    end
end)
```

---
### Remember to always add checks to the UniHandler to ensure that the calls are right, so there wont be situations where a player fires a Skill that he doesn't have access too. (the bare minimum is to add additional checks)
## Why didn't I add it? Because this is universal, and it won't fit the criteria for everyone. Just add your own checks to ensure the client call is allowed.

## Predictive vs Non-Predictive mode

### Predictive mode (default)

Play animations and effects immediately in `C_Module.Start` before the server confirms. If the server rejects it, `Correction` rolls back.

**Best for:** combat skills, movement actions — anything where instant feedback matters.

```lua
-- C_YourSkill
module.Start = function(args: Packets.Args)
    local char = getChar(args)
    Packets.ServerRemote:Fire({ Module = "YourSkill", Function = "Activate", Character = char })

    animationManager:Play(char, someAnimation)   -- plays instantly
    highlight.Create({ Character = char, ... })  -- effect instantly
end

module.Correction = function(args: Packets.Args)
    -- server said no — stop the animation, reset state
    animationManager:Stop(char, someAnimation)
    module[char] = nil
end
```

---

### Non-predictive mode

Do nothing in `C_Module.Start` except fire to the server. The server validates and then fires `ReplicateRemote` to trigger effects on success. No rollback needed because nothing was predicted.

**Best for:** high-stakes actions (opening a shop, purchasing, interacting) where a frame of latency is acceptable.

```lua
-- C_YourSkill
module.Start = function(args: Packets.Args)
    local char = getChar(args)
    Packets.ServerRemote:Fire({ Module = "YourSkill", Function = "Activate", Character = char })
    -- nothing else — wait for server to replicate effects
end
```

```lua
-- S_YourSkill — fire effects only after validation passes
module.Activate = function(args: Packets.Args, player: Player?): string?
    if someCheckFails then return "Fail" end

    -- only reaches here if valid
    Packets.ReplicateRemote:FireCloseClients({
        Module = "YourSkill", Function = "Effects", Character = args.Character
    }, { Type = "Action1" })

    return nil
end
```

> The Shop demo uses this pattern — `C_Shop.Open` just fires to the server, the server checks the player's level, then fires `OpenEffect` back only if valid.

---

## Corrections

### What triggers a correction

When `S_Module.Activate` returns `"Fail"`, UniHandler automatically fires a `Correction` packet back to that player only:

```lua
-- UniHandler internals (you don't edit this)
local result = func(callData, player) :: any
if result then -- any truthy return = fail
    Packets.ReplicateRemote:FireClient(player, {
        Module    = pms.Module,
        Function  = "Correction",
        Character = pms.Character
    })
end
```

---

### How to handle a correction in your client module

Every client module that uses prediction needs a `Correction` function. UniReplicator calls it automatically when the server rejects the action.

```lua
-- C_YourSkill
module.Correction = function(args: Packets.Args)
    local char = getChar(args)
    if not char then return end

    -- 1. restore any state you changed in Start()
    local data = module[char]
    if data then
        data.Combo = data.PrevCombo  -- e.g. revert combo counter
    end

    -- 2. stop any animations you started
    if data and data.AnimsTrack then
        animationManager:Stop(char, data.AnimsTrack)
    end

    -- 3. play a correction visual so the player sees the rollback
    args.Type = "Correction"
    module.Finish(args)

    -- 4. clear stored state
    module[char] = nil
end
```

If your skill is non-predictive and stores no client state, `Correction` can be as simple as closing the UI:

```lua
-- C_Shop
module.Correction = function(args: Packets.Args)
    module.Close(args)
    print("CORRECTION!")
end
```

---

### Real example — Punch correction flow

```
C_Punch.Start → plays anim, fires server
    → S_Punch.Activate checks cooldown / Action state
        → returns "Fail" if invalid
            → C_Punch.Correction runs, reverts combo, stops anim
```

```lua
-- S_Punch.Activate — server-side checks
module.Activate = function(args: Packets.Args, player: Player?): string?
    local char = args.Character
    if not char then return "Fail" end
    if char:GetAttribute("Action") then return "Fail" end
    if CDManager:IsOnCooldown(char, "Punch") then return "Fail" end
    -- passed: continue with attack logic
    return nil
end
```

```lua
-- C_Punch.Correction — client rollback
module.Correction = function(args: Packets.Args)
    local char = getChar(args)
    local data = module[char]
    data.Combo = data.PrevCombo                      -- undo optimistic combo increment
    animationManager:Stop(char, data.AnimsTrack)     -- stop predicted animation
    args.Type = "Correction"
    module.Finish(args)                              -- flash green highlight
    module[char] = nil
end
```

---

## NPC support

Call the server module directly — no remote needed. Pass no player argument (or `nil`). The framework checks `if not player then` and fires `FireCloseClients` to replicate the visual to nearby players.

```lua
--!strict
local S_Punch = require(
    ServerScriptService:WaitForChild("ServerSkills")
        :FindFirstChild("Punch")
        :FindFirstChild("S_Punch")
) :: any

while true do
    task.wait(0.5)
    S_Punch.Activate({ Character = script.Parent }) -- no player arg
end
```

Inside your server module, always handle the `if not player then` branch:

```lua
-- S_YourSkill snippet
if not player then
    Packet:FireCloseClients({
        Module = "YourSkill", Function = "Start", Character = char
    })
end
```

The optimized `Packets.lua` handles NPC character compression automatically — the first time a given client observes a specific NPC, it learns that NPC's id; every replicated call after that for the same NPC costs a single small number instead of a full Instance reference. You don't need to do anything differently in your skill code for this to work.

---

## Initialization

Require these once from a server `Script` at game start:

```lua
require(game.ReplicatedStorage.Remotes.Packets)
require(game.ServerScriptService.SkillHandler.UniHandler)
require(game.ReplicatedStorage.Assets.Modules.Shared.Util.Cooldowns)
require(game.ReplicatedStorage.Assets.Modules.Shared.Util.AnimationManager)
require(game.ServerStorage.MuchachoHitbox)
```

`UniReplicator` runs on the client automatically — no manual require needed if it's placed as a `LocalScript` in the correct location.

---

## Dependencies

### Suphi's Packet library

UniFramework uses **Suphi's Packet** as its networking backbone. You need to grab the `MainModule` from the DevForum thread and place it where the `Packets` module can reach it:

> **[Packet — Networking Library by Suphi](https://devforum.roblox.com/t/packet-networking-library/3573907)**

**Setup:**

1. Get the `MainModule` from the thread above.
2. Place it at `ReplicatedStorage/Assets/Modules/Shared/Util/MainModule` (the path the `Packets` module requires it from), or anywhere — just make sure to link it to the `Packets` module.
3. The `Packets` module wraps it with the `ServerRemote` / `ReplicateRemote` layer, plus the hashing/compression/lag-compensation optimizations described above — no changes to `MainModule` needed.
4. Or get it from the DemoPlace `.rbxl` in **Releases** and follow the instructions included there.

```lua
-- Packets.lua (already set up for you)
local Packet = require(ReplicatedStorage.Assets.Modules.Shared.Util.MainModule)
```

Without the `MainModule` in place, `Packets` will error on require and nothing will work.

> **Grab the DemoPlace and the latest optimized `Packets.lua` / `Configuration.lua` together from the [Releases](../../releases) page.** Mixing an old `Packets.lua` with a new `Configuration.lua` (or vice versa) will break — `Packets.lua` expects `Config.HashingEnabled`, `Config.CharacterHashingEnabled`, and `Config.LagCompensationEnabled` to exist on whatever `Configuration` module it requires.

---

## Quick review

**Prediction** → client starts module, does unsecure client checks → plays animation → fires server → does secure checks, if fails then does correction.

**Server Authoritative** → client starts module → fires to server → does checks → plays animations.

Both work great — prediction is for speed and QoL, while authoritative is secure and reliable.
Also Dont forget To Require All the modules needed, Take concept from the ServerInit ( just concept )
Don't forget to configure the `Configuration` module to fit your needs, including the three optimization switches (`HashingEnabled`, `CharacterHashingEnabled`, `LagCompensationEnabled`).

---

--- 
# Types of Calls
| | |
|---|---|
|**Fire()** | Fires All clients if run on server or FireServer if from client |
|**FireCloseClients()** | Used To fire Clients In the Configured Range For optimization |
|**FireClient()** | Used To Fire a Specific Client |

## Credits & issues

| | |
|---|---|
| **Packet networking library** | [Suphi](https://devforum.roblox.com/t/packet-networking-library/3573907) |
| **UniFramework** | idan4k |
| **Tutorial for punch setup** | https://youtu.be/DIh3fUclDyg |
| **Tutorial for new skill setup** | (in works) |

Found a bug or have a question? Report issues to **idan4k**.

> Latest builds, the DemoPlace, and the current optimized `Packets.lua` + `Configuration.lua` are always in **[Releases](../../releases)** — this README documents the framework's concepts and usage patterns, but the actual Packets And Configuration should come from there.
