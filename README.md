# Modular Combat Framework

A high-performance, modular combat framework built for **Luau `--!strict`**.
The system uses an automated **Replicator** and **SkillHandler** to manage networking with minimal setup and clean scalability.

---

# Folder Structure & Naming

The framework automatically discovers modules based on their **folder location** and **naming convention**.

| Type               | Folder Location                                | Naming Convention       |
| ------------------ | ---------------------------------------------- | ----------------------- |
| **Client Skill**   | `ReplicatedStorage.ClientSkills`               | `C_` + Name → `C_Punch` |
| **Server Skill**   | `ServerScriptService.ServerSkills`             | `S_` + Name → `S_Punch` |
| **Client Utility** | `ReplicatedStorage.Assets.Modules.Client`      | Raw Name → `Highlight`  |
| **Shared Utility** | `ReplicatedStorage.Assets.Modules.Shared.Util` | Raw Name → `Ragdoll`    |

---

# Creating a Skill

Every skill requires:

* A **Server Module**
* A **Client Module**

For a skill named **Punch**, create:

* `S_Punch`
* `C_Punch`

---

## Server Module — `S_Punch`

Located in:

```txt
ServerScriptService.ServerSkills
```

Responsible for:

* Hitboxes
* Damage
* Validation
* Server-side combat logic

After the logic completes, the server replicates visuals to clients.

```lua
--!strict

type Character = Model

local Packets = require(game.ReplicatedStorage.Remotes.Packets)
local Packet = Packets.ReplicateRemote

local module = {}

function module.Activate(char: Character, extra: any)
    print("Server logic running...")

    -- Tell all clients to run the "Effects" function in C_Punch
    Packet:Fire(
        char,
        {
            Skill = "Punch",
            Function = "Effects"
        },
        {
            Type = "Standard"
        }
    )
end

return module
```

---

## Client Module — `C_Punch`

Located in:

```txt
ReplicatedStorage.ClientSkills
```

Responsible for:

* Player input
* Animations
* Camera effects
* Particles
* Client visuals

```lua
--!strict

type Character = Model

type EffectArgs = {
    Character: Character,
    [string]: any
}

local Packets = require(game.ReplicatedStorage.Remotes.Packets)
local Packet = Packets.ServerRemote

local module = {}

-- Triggered by input/tool scripts
function module.Start(char: Character)
    Packet:Fire(
        char,
        {
            Skill = "Punch",
            Function = "Activate"
        },
        {}
    )
end

-- Triggered by the Replicator
function module.Effects(args: any)
    local data = args :: EffectArgs

    print("Playing visuals for: " .. data.Character.Name)
end

return module
```

---

# Creating a Utility (Key)

Utilities are **prefix-free shared modules**.

They are used for reusable systems such as:

* Highlights
* Camera Shake
* VFX
* Ragdolls
* Sound Systems

Utilities do **not** require a matching Skill module.

---

## Example Utility Call

Place the module inside:

```txt
Assets.Modules.Client
```

or

```txt
Assets.Modules.Shared.Util
```

Then fire it directly from the server ( recommended use ):
( using from client will result in lag )
```lua
Packet:Fire(
    char,
    {
        Key = "Highlight",
        Function = "Create"
    },
    {
        Color = Color3.new(1, 0, 0)
    }
)
```

---

# Firing the Framework

All networking follows the same structure:

```lua
Packet:Fire(Character, Params, ExtraData)
```

---

## Parameter Breakdown

### `Character`

The `Model` performing the action.

---

### `Params`

Defines what module/function should run.

```lua
{
    Skill = "Punch",
    Function = "Activate"
}
```

or

```lua
{
    Key = "Highlight",
    Function = "Create"
}
```

---

### `ExtraData`

Dynamic runtime data.

```lua
{
    Damage = 15,
    Type = "Heavy"
}
```

If no extra data exists:

```lua
{}
```

---

# Developer Rules

---

## 1. Character Injection

You do **not** need to manually include the character inside `ExtraData`.

The Replicator automatically injects:

```lua
args.Character
```

Example:

```lua
function module.Effects(args)
    print(args.Character.Name)
end
```

---

## 2. Strict Casting

For proper Luau autocomplete and type safety, cast your arguments immediately.

```lua
local data = args :: EffectArgs
```

Recommended structure:

```lua
type EffectArgs = {
    Character: Character,
    [string]: any
}
```

---

## 3. Placeholder Tables

The networking layer is strict.

Always pass a table for `ExtraData`.

Correct:

```lua
Packet:Fire(char, params, {})
```

Incorrect:

```lua
Packet:Fire(char, params, nil)
```

Passing `nil` can cause replication failure.

---

## 4. Skills vs Keys

### Use `Skill`

For unique combat abilities:

* Punch
* Kick
* Dash
* Slam

```lua
{
    Skill = "Punch"
}
```

---

### Use `Key`

For reusable shared systems:

* CameraShake
* Highlight
* Ragdoll
* VFX

```lua
{
    Key = "Highlight"
}
```

---

# Summary

This framework provides:

* Modular architecture
* Automatic replication
* Strict Luau support
* Shared utility systems
* Minimal networking boilerplate
* Scalable combat scripting
* Code examples can be seen in studio
Designed for fast iteration while keeping code clean, reusable, and maintainable.
