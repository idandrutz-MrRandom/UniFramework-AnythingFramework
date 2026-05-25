This version follows a strict Text → Code → Text structure. Each explanation is
kept outside of the code blocks to ensure it is readable and professionally
formatted for a GitHub README.

⚔️ Modular Combat Framework

This framework is a high-performance, modular system designed for Luau
--!strict. It uses an automated Replicator and SkillHandler to handle all
networking with minimal setup.

1. Folder Structure & Naming

The framework automatically discovers your scripts based on their location and
specific name prefixes.

| Type               | Folder Location                                | Naming Convention            |
| :----------------- | :--------------------------------------------- | :--------------------------- |
| **Client Skill**   | `ReplicatedStorage.ClientSkills`               | `C_` + Name (e.g. `C_Punch`) |
| **Server Skill**   | `ServerScriptService.ServerSkills`             | `S_` + Name (e.g. `S_Punch`) |
| **Client Utility** | `ReplicatedStorage.Assets.Modules.Client`      | Raw Name (e.g. `Highlight`)  |
| **Shared Utility** | `ReplicatedStorage.Assets.Modules.Shared.Util` | Raw Name (e.g. `Ragdoll`)    |

2. How to Create a Skill

Every skill requires a paired Server and Client module. For a skill named
"Punch," you would create the following:

The Server Module (S_Punch)

This module lives in ServerSkills. It handles the game logic, such as hitboxes
and damage. When the logic is finished, it tells the clients to play visuals.

--!strict
type Character = Model
local Packets = require(game.ReplicatedStorage.Remotes.Packets)
local Packet = Packets.ReplicateRemote

local module = {}

function module.Activate(char: Character, extra: any)
    print("Server logic running...")
    
    -- Tell all clients to run the "Effects" function in the C_Punch module
    Packet:Fire(char, {Skill = "Punch", Function = "Effects"}, {Type = "Standard"})
end

return module

The Client Module (C_Punch)

This module lives in ClientSkills. It handles the player's input and the visual
effects for everyone in the game.

--!strict
type Character = Model
type EffectArgs = { Character: Character, [string]: any }

local Packets = require(game.ReplicatedStorage.Remotes.Packets)
local Packet = Packets.ServerRemote

local module = {}

-- Triggered by your Tool or Input script to start the attack
function module.Start(char: Character)
    Packet:Fire(char, {Skill = "Punch", Function = "Activate"}, {})
end

-- Triggered by the Replicator to play visuals
function module.Effects(args: any)
    local data = args :: EffectArgs -- Use type casting for autocomplete
    print("Playing visuals for: " .. data.Character.Name)
end

return module

3. How to Create a Utility (Key)

Utilities are prefix-free modules used for shared effects like Highlights or
Camera Shakes. They do not require a specific "Skill" script to run.

To use a utility, place your module in Assets.Modules.Client or Shared.Util and
call it from the server using the Key parameter.

-- Firing a shared utility directly from the server
Packet:Fire(char, {Key = "Highlight", Function = "Create"}, {Color = Color3.new(1,0,0)})

4. How to Fire the Framework

You trigger the system by firing a packet with the following signature:
Packet:Fire(Character, Params, ExtraData).

Character: The Model performing the action.
Params: A table containing:

  - Skill: The name of the skill (looks for C_ or S_ modules).
  - Key: The name of a utility (looks for raw module names).
  - Function: The specific function name to execute.

ExtraData: A table {} containing any dynamic data like damage values or effect
types.

5. Critical Rules for Developers

1. Character Injection
You do not need to manually pass the character inside your ExtraData table. The
Client Replicator automatically inserts the character into the arguments as
args["Character"].

2. Strict Casting
To get full Luau autocomplete and prevent errors in your Effects functions,
always cast the arguments at the top of the function:

local data = args :: EffectArgs

3. Placeholder Tables
The networking library is strict. If you have no extra data to send, you must
pass an empty table {} as the 3rd argument. Passing nil will cause the packet to
fail.

4. Skills vs. Keys

  - Use Skill: For logic unique to a specific ability (e.g., Punch, Kick).
  - Use Key: For shared systems used by multiple different skills (e.g., VFX,
    CameraShake, Ragdoll).
