This version is optimized for GitHub Flavored Markdown. It uses clear headers,
clean tables, and properly fenced code blocks with lua syntax highlighting to
ensure everything displays correctly on GitHub.

# ⚔️ Modular Combat Framework

A high-performance, modular combat framework for Roblox, designed for **Luau `--!strict`**. This system automates networking through a **Replicator** and **SkillHandler** to keep your codebase clean and organized.

---

## 📂 1. Folder Structure & Naming
The framework automatically discovers modules based on their location and name prefixes.

| Type | Folder Location | Naming Convention |
| :--- | :--- | :--- |
| **Client Skill** | `ReplicatedStorage.ClientSkills` | `C_` + Name (e.g. `C_Punch`) |
| **Server Skill** | `ServerScriptService.ServerSkills` | `S_` + Name (e.g. `S_Punch`) |
| **Client Utility** | `ReplicatedStorage.Assets.Modules.Client` | Raw Name (e.g. `Highlight`) |
| **Shared Utility** | `ReplicatedStorage.Assets.Modules.Shared.Util` | Raw Name (e.g. `Ragdoll`) |

---

## 🛠️ 2. Setting Up a New Skill
Every skill consists of a Server logic module and a Client visual module.

### A. Server Module (`S_Punch`)
This handles hitboxes, damage, and server-side validation.

```lua
--!strict
type Character = Model
local Packets = require(game.ReplicatedStorage.Remotes.Packets)
local Packet = Packets.ReplicateRemote

local module = {}

function module.Activate(char: Character, extra: any)
    print("Server: Processing Logic")
    
    -- Replicate visual effects to all clients
    Packet:Fire(char, {Skill = "Punch", Function = "Effects"}, {Type = "Heavy"})
end

return module

B. Client Module (C_Punch)

This handles input initiation and global visual effects.

--!strict
type Character = Model
type EffectArgs = { Character: Character, [string]: any }

local Packets = require(game.ReplicatedStorage.Remotes.Packets)
local Packet = Packets.ServerRemote

local module = {}

-- Triggered by your Tool or Input script
function module.Start(char: Character)
    Packet:Fire(char, {Skill = "Punch", Function = "Activate"}, {})
end

-- Triggered by the Replicator (Server -> All Clients)
function module.Effects(args: any)
    local data = args :: EffectArgs -- Type cast for autocomplete
    print("Playing effect for: " .. data.Character.Name)
end

return module

🔧 3. Setting Up a Utility (Key)

Utilities are prefix-free modules used for generic, reusable effects (e.g.,
Highlights, Camera Shakes).

1.  Place the module in Assets.Modules.Client or Shared.Util.
2.  Call it using the Key parameter instead of Skill.

-- Fire a generic utility directly from the server
Packet:Fire(char, {Key = "Highlight", Function = "Create"}, {Color = Color3.new(1,0,0)})

🚀 4. Usage & API

Use Packet:Fire(Character, Params, ExtraData) to communicate between
environments.

Parameters

  - Character: The Model performing the action.
  - Params:
      - Skill: Name of the skill (looks for C_ or S_ modules).
      - Key: Name of a utility (looks for raw module names).
      - Function: The string name of the function to execute.
  - ExtraData: A table {} containing dynamic data (Damage, Type, Colors).

⚠️ 5. Critical Rules

[!IMPORTANT] Character Injection
You do not need to pass the character inside your ExtraData table. The Client
Replicator automatically injects the character as args["Character"].

[!TIP] Strict Casting
For full Luau autocomplete in your Effects functions, always cast the arguments
at the top:
local data = args :: EffectArgs

[!WARNING] Empty Tables
The networking library requires all arguments to be filled. If you have no extra
data to send, you must pass an empty table {} as the 3rd argument to prevent
crashes.

Skills vs. Keys

  - Use Skill for unique abilities (e.g. Punch, Kick).
  - Use Key for shared systems (e.g. VFX, CameraShake).

