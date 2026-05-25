To ensure the code displays correctly on GitHub, it must be wrapped in triple
backticks (```) followed by the language name (lua).

Here is the corrected, copy-paste-ready Markdown code for your README.md.

# ⚔️ Modular Combat Framework

A high-performance, modular combat system designed for **Luau `--!strict`**. This framework utilizes an automated **Replicator** and **SkillHandler** to bridge networking between Client and Server with minimal boilerplate.

---

## 📌 Table of Contents
* [Folder Structure & Naming](#1-folder-structure--naming)
* [Setting Up a New Skill](#2-setting-up-a-new-skill)
* [Setting Up a Utility (Key)](#3-setting-up-a-utility-key)
* [How to Call Skills](#4-how-to-call-skills)
* [Critical Rules](#5-critical-rules)

---

## 1. Folder Structure & Naming
The framework uses specific prefixes and locations to automate module discovery.

| Type | Folder Location | Naming Convention |
| :--- | :--- | :--- |
| **Client Skill** | `ReplicatedStorage.ClientSkills` | `C_` + Name (e.g., `C_Punch`) |
| **Server Skill** | `ServerScriptService.ServerSkills` | `S_` + Name (e.g., `S_Punch`) |
| **Client Utility** | `ReplicatedStorage.Assets.Modules.Client` | Raw Name (e.g., `Highlight`) |
| **Shared Utility** | `ReplicatedStorage.Assets.Modules.Shared.Util` | Raw Name (e.g., `Ragdoll`) |

---

## 2. Setting Up a New Skill
Skills require a paired Server and Client module to manage logic and visuals separately.

### A. The Server Module (`S_Punch`)
Handles game logic: hitboxes, damage, and server-side validation.

```lua
--!strict
type Character = Model
local Packets = require(game.ReplicatedStorage.Remotes.Packets)
local Packet = Packets.ReplicateRemote

local module = {}

function module.Activate(char: Character, extra: any)
    print("Server Logic Executing")
    
    -- Replicate to all clients to play visual effects
    Packet:Fire(char, {Skill = "Punch", Function = "Effects"}, {Type = "Standard"})
end

return module

B. The Client Module (C_Punch)

Handles user input initiation and global visual effects.

--!strict
type Character = Model
type EffectArgs = { Character: Character, [string]: any }

local Packets = require(game.ReplicatedStorage.Remotes.Packets)
local Packet = Packets.ServerRemote

local module = {}

-- Called by the Tool or Input controller
function module.Start(char: Character)
    -- Fire to Server logic
    Packet:Fire(char, {Skill = "Punch", Function = "Activate"}, {})
end

-- Called by the Replicator (Server -> Client)
function module.Effects(args: any)
    local data = args :: EffectArgs -- Cast for autocomplete
    print("Playing effect for: " .. data.Character.Name)
end

return module

3. Setting Up a Utility (Key)

Utilities are modules used for generic effects (Camera Shake, Highlights,
Ragdolls). They do not require prefixes.

1.  Place your module in Assets.Modules.Client or Shared.Util.
2.  Call it directly from the Server using the Key parameter:

-- Trigger a generic Highlight effect without a specific skill module
Packet:Fire(char, {Key = "Highlight", Function = "Create"}, {Color = Color3.new(1,0,0)})

4. How to Call Skills

Trigger the framework via ServerRemote (Client -> Server) or ReplicateRemote
(Server -> Client).

Function Signature

Packet:Fire(Character, Params, ExtraData)

1.  Character: The Model performing the action.
2.  Params:
      - Skill: The name of the skill (searches C_ or S_ modules).
      - Key: The name of a Utility (searches exact module names).
      - Function: The specific string name of the function to execute.
3.  ExtraData: A table {} containing dynamic info (Damage, Color, Type, etc.).

5. Critical Rules

[!IMPORTANT] 1. Character Injection
You do not need to manually pass the character inside your ExtraData table. The
Client Replicator automatically inserts it as args["Character"].

[!TIP] 2. Strict Casting
To enable full Luau autocomplete in your Effects functions, always cast the
arguments at the top:
local data = args :: EffectArgs

[!WARNING] 3. Placeholder Tables
The networking library is strict. If you have no extra data to send, you must
pass an empty table {} as the 3rd argument to prevent serialization errors.

4. Skills vs. Keys

  - Use Skill for unique abilities (Punch, Kick, Fireball).
  - Use Key for shared systems (Highlights, CameraShake, VFX).

