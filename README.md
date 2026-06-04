# UniFramework
V 2.0
> The documentation was mostly written by AI since im not usually free. Dm idan4k for any questions or documentation fixes!
## If you want to get a deeper understanding, i recommend you to use the Given rbxl place to check it out and play around with it.
A prediction-based remote dispatch framework for Roblox. The client acts immediately — animations, effects, movement — while the server validates and replicates the authoritative result. If the server rejects the action, a `Correction` is automatically sent back so the client can undo whatever it jumped ahead with.

The same pattern works for anything: a dash blocked by a stun, a building placement that collides, a shop purchase that fails a currency check, a spell that gets interrupted. UniFramework doesn't care what the action is — it just routes calls to the right module and function on the right side.

**Adding a new feature = two files in the right folders. No remotes to create, no handlers to register.**

```
[Client] Tool activated → C_Punch.Start(char)
    │  plays animation immediately (prediction)
    └─► ServerRemote:Fire({ Module="Punch", Function="Activate", Character=char })
              │
         [UniHandler] → ownership check → S_Punch.Activate(args, player)
              │
              ├─ [Fail] returns truthy → Correction fired back to client
              │
              └─ [Pass] FireCloseClients(Effects) → ... → FireCloseClients(Finish)
                              └─► [UniReplicator] → C_Punch.Effects / C_Punch.Finish
```

> **Server-first works too.** NPCs and server scripts call `S_` modules directly — no remote needed.

---

## Table of Contents
- [What you can build](#what-you-can-build)
- [Testing with the Punch example](#testing-with-the-punch-example)
- [Architecture](#architecture)
- [Setup](#setup)
- [Packet API](#packet-api)
- [Writing Modules](#writing-modules)
- [Prediction & Correction](#prediction--correction)
- [Proximity Replication](#proximity-replication)
- [Security — Anti-Spoof](#security--anti-spoof)
- [NPC Activation](#npc-activation)
- [How Dispatch Works Internally](#how-dispatch-works-internally)
- [Notes & Limitations](#notes--limitations)
- [Full Example Reference](#full-example-reference)
- [Credits](#credits)

---

## What you can build

UniFramework is a dispatch layer, not a combat framework. The Punch example is just a convenient demo — the same two-file structure works for:

**Combat & movement** — melee, projectiles, dashes, teleports, blocks and parries. Client predicts, server confirms or corrects.

**World interaction** — building placement (show ghost client-side, server validates collision), item pickup (client removes visually, server confirms it wasn't taken), doors and levers (animate locally, server checks state).

**UI systems** — shop purchases, ability unlocks, loadout changes. No character needed — just omit it from the params.

**Server-driven events** — boss attacks, environmental hazards, NPC skills. Server calls `S_` directly, replicates to nearby clients, no client request involved.

The pattern is always the same: **client acts immediately, server decides what actually happened, clients near the action see the authoritative result.** What the action is, and what "nearby" means, is up to you.

---

## Testing with the Punch example

The included files are a fully working test case. Drop them in and you can see prediction, replication, and correction all running live.

**What the test does:**

- `Tool_example` — equip the tool and click. `C_Punch.Start` fires the server. The server validates: character must exist, no `Action` attribute already set, Humanoid health must be ≥ 100. Pass → red highlight (`Effects`) on nearby clients, then blue highlight (`Finish`) after 10 seconds. Fail → `Correction` fires back to the requesting client only, which calls `Finish`, which calls `Effects` — producing a green highlight.
- `NPCActivator` — place inside an NPC model. It calls `S_Punch.Activate` directly every 2 seconds, bypassing the client entirely. The server replicates `Effects` and `Finish` to nearby clients.

**Reading the highlights:**

| Colour | Meaning |
|---|---|
| 🔴 Red | Server accepted — action started (`Type = "Highlight"`) |
| 🔵 Blue | Server confirmed completion (`Type = "Finish"`) |
| 🟢 Green | Server rejected — correction received (`Type = "Correction"`) |

The `Type` field is what drives the colour in `C_Punch.Effects`. On the correction path, `Correction` calls `Finish` which calls `Effects` — and you can optionally overwrite `args.Type` to `"Correction"` inside `Correction` to show the green highlight (see the commented line in `C_Punch`).

To force a rejection: set the `Action` attribute on your character in the Explorer before clicking, or have Humanoid health below 100.

---

## Architecture

| Module | Side | Role |
|---|---|---|
| `UniHandler` | Server Script | Receives `ServerRemote`, validates ownership, dispatches to `S_` modules, sends `Correction` on failure |
| `UniReplicator` | LocalScript | Receives `ReplicateRemote`, dispatches to `C_` modules |
| `Packets` | Shared ModuleScript | Wraps both remotes; exposes `Fire`, `FireCloseClients`, `FireClient` |
| `Configuration` | Shared ModuleScript | Tells the handlers where your modules live; sets `RemoteDistance` |

Two remotes. Two universal handlers. Any number of features.

---

## Setup

### Folder structure

The framework only requires that `UniHandler` is a server `Script` and `UniReplicator` is a `LocalScript`. Everything else — folder names, nesting — is up to you, as long as paths are registered in `Configuration`.

```
ReplicatedStorage/
├── Assets/Modules/
│   ├── Configuration
│   ├── Shared/Util/        ← utilities accessible by both sides
│   ├── Server/Util/        ← server-only utilities
│   └── Client/Util/        ← client-only utilities
├── ClientSkills/
│   └── Base/Punch/C_Punch
└── Remotes/Packets

ServerScriptService/
├── ServerSkills/Punch/S_Punch
└── UniHandler

StarterPlayer/StarterPlayerScripts/UniReplicator
```

Modules can be flat or nested — the recursive search handles both:

```
ServerSkills/S_Punch          -- flat
ServerSkills/Punch/S_Punch    -- nested
```

### Naming convention

| Prefix | Side | Example |
|---|---|---|
| `S_` | Server | `S_Punch` |
| `C_` | Client | `C_Punch` |
| *(none)* | Utility (both) | `Highlight` |

Names must be unique within their search scope — the handler takes the first match.

### Configuration

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type Config = {
	ServerModulePaths: { Instance },
	ClientModulePaths: { Instance },
	UtilityPaths: { Instance },
	RemoteDistance: number,
}

local Configuration: Config = {
	ServerModulePaths = {},
	ClientModulePaths = {},
	UtilityPaths = {},
	RemoteDistance = 650,
}

-- Shared utilities accessible by both sides
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

`RemoteDistance` controls the studs radius for `FireCloseClients`. Set it to match your game's render distance — default is `650`.

To add more folders, insert into the relevant list. Sub-folders are searched automatically — only register root containers:

```lua
table.insert(Configuration.ServerModulePaths, ServerScriptService:WaitForChild("CombatSkills"))
table.insert(Configuration.ClientModulePaths, ReplicatedStorage:WaitForChild("UISkills"))
table.insert(Configuration.UtilityPaths, ReplicatedStorage:WaitForChild("SharedHelpers"))
```

---

## Packet API

```lua
local Packets = require(ReplicatedStorage.Remotes.Packets)

Packets.ServerRemote:Fire(Params, Data?)                  -- Client → Server
Packets.ReplicateRemote:Fire(Params, Data?)               -- Server → all clients
Packets.ReplicateRemote:FireCloseClients(Params, Data?)   -- Server → nearby clients
Packets.ReplicateRemote:FireClient(Player, Params, Data?) -- Server → one client
```

**Params:**
```lua
export type Params = {
	Module: string?,    -- skill module name without prefix ("Punch" → finds S_Punch or C_Punch)
	Utility: string?,   -- utility module name, exact (no prefix added)
	Function: string,   -- function to call on the resolved module
	Character: Model?,  -- optional; omit for UI/global actions
}
```
If both `Module` and `Utility` are set, `Module` wins.

**Data:** any free-form table merged into `args` on the receiving end. Defaults to `{}` if omitted.

**Args** (what your module functions receive):
```lua
export type Args = {
	Character: Character?,
	[any]: any  -- everything from Data is also here
}
```

---

## Writing Modules

### Client module (`C_`)

Place in any folder under `ClientModulePaths`. File name must start with `C_`.

You can have any functions you want. The framework only calls the ones you name in `Params.Function`. In the Punch example there are four:

- **`Start`** — called directly from a tool or input handler. Does local prediction, then fires the server. Only fires the server if the character belongs to a real player (the `GetPlayerFromCharacter` check).
- **`Effects`** — called by `UniReplicator` when the server replicates an effect. The `args.Type` field determines what to show.
- **`Finish`** — called by `UniReplicator` when the server confirms completion. Calls `Effects` with the args it received.
- **`Correction`** — called automatically by `UniReplicator` when `UniHandler` rejects the action. Calls `Finish`, which calls `Effects`. You can overwrite `args.Type` to `"Correction"` here to drive a different visual (see the commented line in the source).

`Start → Effects + Finish` is just the shape this example takes. Your module can have whatever functions fit your feature.

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Remotes.Packets)
local Players = game:GetService("Players")
local highlight = require(ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Util"):WaitForChild("Highlight") :: ModuleScript) :: any

local module = {}

module.Start = function(args: Packets.Args) -- no checks here for testing purposes.
	local char = if typeof(args) == "table" then args.Character else (args :: any) 
	if  char and  Players:GetPlayerFromCharacter(char) then --here we check if its a player or not, if its not a player it means that its been called from the server side of the Skill / module, and not checking it here
		Packets.ServerRemote:Fire({ Module = "Punch", Function = "Activate", Character = char }) -- may cause an infinite loop of the events calling each other, so make sure when you start on client to check its a player
		-- and if not then dont send the event ( more stuff will be noted later on. )
	end

	-- client-side prediction goes here
end

module.Correction = function(args: Packets.Args)
	print("Client Correction")
	--args.Type = "Correction" -- overwrite the passed Type to "Correction" to showcase the Invalid callback. otherwise it would stay empty and wont showcase it.
	module.Finish(args)
end

module.Finish = function(args: Packets.Args)
	print("Client Finished Task.")
	module.Effects(args) -- here we receive the args, if it was Touched by Correction, the Type would be "Correction" meaning that the call wasnt valid and that it was cancelled,
	--otherwise it was called by server and it IS valid, and to showcase that you pass from the server the Type = "Finish"
end

module.Effects = function(args: Packets.Args)
	local char = args.Character

	if args.Type == "Highlight" then
		highlight.Create({ Character = char, Color = Color3.fromRGB(255, 0, 0), Transparency = 0.5, FadeDuration = 1 })
	elseif args.Type == "Finish" then
		highlight.Create({ Character = char, Color = Color3.fromRGB(0, 0, 127), Transparency = 0.5, FadeDuration = 1 })
	elseif args.Type == "Correction" then
		highlight.Create({ Character = char, Color = Color3.fromRGB(0, 255, 0), Transparency = 0.5, FadeDuration = 1 })
	end
end

return module
```

**Calling from a tool (`Tool_example`):**
```lua
--!strict
local Tool = script.Parent
local SkillMod = require(game.ReplicatedStorage.ClientSkills.Base.Punch.C_Punch) :: any

Tool.Activated:Connect(function()
	local Character = Tool.Parent :: any
	SkillMod.Start(Character)
end)
```

`Start` accepts either the character directly or a table with a `Character` field — both paths are handled by the `typeof(args)` check.

---

### Server module (`S_`)

Place in any folder under `ServerModulePaths`. File name must start with `S_`.

Three rules from the framework's perspective:
1. Functions receive `(args: Packets.Args, player: Player?)`
2. **Return any truthy value to reject** — `UniHandler` automatically sends `Correction` back to the client
3. Use `Fire`, `FireCloseClients`, or `FireClient` to push results to clients

Everything else — what you validate, how many replication steps, what state system you use — is your design.

```lua
--!strict
local Packets = require(game.ReplicatedStorage.Remotes.Packets)
local Packet = Packets.ReplicateRemote
local module = {}

module.Activate = function(args: Packets.Args, player: Player?): any
	local char = args.Character
	if not char then return "Fail" end
	if char:GetAttribute("Action") then return "Fail" end

	local hum = char:FindFirstChild("Humanoid") :: Humanoid?
	if not hum or hum.Health < 100 then return "Fail" end

	char:SetAttribute("Action", true)

	Packet:FireCloseClients({ Module = "Punch", Function = "Effects", Character = char }, { Type = "Highlight" })

	task.wait(10)

	Packet:FireCloseClients({ Module = "Punch", Function = "Finish", Character = char }, { Type = "Finish" })

	char:SetAttribute("Action", false)
	return
end

return module
```

Returning any truthy value (e.g. `"Fail"`) triggers an automatic `Correction` on the requesting client. Returning `nil` (or just `return`) means success — no correction sent.

**Replication methods:**

| Method | Reaches | Use when |
|---|---|---|
| `Fire` | All clients | Global events, world state |
| `FireCloseClients` | Clients within `RemoteDistance` studs of the character | Spatially local effects |
| `FireClient` | One client | Personal UI, corrections, private state |

---

### Utility module

Place in any folder under `UtilityPaths`. No prefix. Accessible from both sides.

Call directly when you're already on the right side, or route through the remote using `Utility` instead of `Module`:

```lua
Packets.ReplicateRemote:FireCloseClients({
	Utility = "Highlight",
	Function = "Create",
	Character = char,
}, { Color = Color3.fromRGB(255, 255, 0), Transparency = 0.3, FadeDuration = 2 })
```

---

### Characterless calls

`Character` is always optional — omit it for UI or global actions:

```lua
-- Client: open a shop
Packets.ServerRemote:Fire({ Module = "Shop", Function = "Open" }, { ItemId = 42 })

-- Server: broadcast a world event
Packets.ReplicateRemote:Fire({ Module = "World", Function = "OnNightfall" }, { Phase = "night" })
```

> **Note:** characterless calls skip the anti-spoof check, so validate carefully inside the module.

---

## Prediction & Correction

**How it flows:**
1. Client predicts immediately (animation, movement, UI)
2. Client fires `ServerRemote`
3. Server validates
4. **Pass** → server replicates result to clients; returns `nil`
5. **Fail** → server returns any truthy value → `UniHandler` automatically `FireClient`s `Correction` to the requesting player

No extra code needed in the server module — just return a truthy value to trigger correction.

In `C_Punch`, the correction path is: `Correction` → `Finish` → `Effects`. Uncommenting `args.Type = "Correction"` inside `Correction` makes `Effects` show the green highlight instead of nothing (since the server didn't pass a `Type` when sending the correction).

`Correction` only fires on the **requesting client**. Other players never ran the prediction so they never need one.

---

## Proximity Replication

`FireCloseClients` sends only to players whose `HumanoidRootPart` is within `RemoteDistance` studs of the action character. Without a character in `Params`, it falls back to all clients.

Tune the radius in `Configuration`:
```lua
RemoteDistance = 650,  -- default; match your game's render distance
```

---

## Security — Anti-Spoof

`UniHandler` validates every character before passing it to your module:

```lua
if Players:GetPlayerFromCharacter(pms.Character) == player then
	callData.Character = pms.Character -- right call from Player
else
	warn("Caller doesnt match the player...exploits?")
	return
end
```

| Client sends | Result |
|---|---|
| Own character | ✅ Accepted |
| Another player's character | ❌ Rejected |
| NPC model | ❌ Rejected |
| Destroyed/fake model | ❌ Rejected |
| No character | ✅ Skipped (characterless call) |

`C_Punch.Start` has a matching client-side guard — it won't fire the server if `GetPlayerFromCharacter` returns nil. Even if an exploiter bypasses the client guard, the server rejects it independently.

> **This system still requires server-side validation in your modules.** UniFramework handles routing and ownership — your `S_` module is responsible for game logic checks. Never trust the client for anything that matters.

---

## NPC Activation

NPCs call `S_` modules directly on the server — no remote, no client request:

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
	warn(script.Parent)
	S_Punch.Activate({ Character = script.Parent })
end
```

When called this way, `player` is `nil` in the server function. If your skill has client-side setup that needs to run (animations etc.), replicate `Start` when `player` is `nil`. `C_Punch.Start` will see the NPC character, fail `GetPlayerFromCharacter`, and stop before re-firing the server — no loop.

---

## How Dispatch Works Internally

### UniHandler (server)

1. `OnServerEvent` fires with `player` injected by Roblox
2. `Module` set → search `ServerModulePaths` for `S_<name>`; `Utility` set → search `UtilityPaths` as-is
3. Module is `require`d and cached by name
4. If `Character` provided → ownership validated; mismatch → silent reject
5. `local Function = func(callData, player)` — return value captured
6. `Function` truthy → `FireClient` a `Correction` to the player

### UniReplicator (client)

Same flow, but for `C_` modules and `ClientModulePaths`. No ownership check — `ReplicateRemote` only ever fires from the server.

Both handlers cache modules after the first `require`. Module-level variables persist across calls.

---

## Notes & Limitations

- Module names must be unique within their search scope
- `Module` takes priority over `Utility` if both are set in the same params
- `Data` defaults to `{}` — your functions always receive a table
- Errors inside dispatched functions don't surface to the caller — use `warn`/`pcall` inside your modules
- `FireCloseClients` without a character broadcasts to everyone
- Characterless calls skip the ownership check — validate them carefully inside the module

**Planned:** rollback system for misprediction correction, additional optimizations.

---

## Full Example Reference

<details>
<summary>Packets.lua</summary>

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Packet = require(ReplicatedStorage.Assets.Modules.Shared.Util.MainModule)
local Config = require(ReplicatedStorage.Assets.Modules.Configuration)

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
	FireCloseClients: (self: any, Params: Params, Data: any?) -> (),
	FireClient: (self: any, Player: Player, Params: Params, Data: any?) -> (),
	OnServerEvent: any,
	OnClientEvent: any,
}

local CLOSE_RANGE = Config.RemoteDistance

local function GetOrigin(Character: Character?): Vector3?
	if not Character then return nil end
	local Root = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if Root then Root.Position else nil
end

local function CreateRemote(Name: string): RawPacket
	local Raw = Packet(Name, Packet.Any, Packet.Any)
	local Wrapper = {}
	Wrapper.OnServerEvent = Raw.OnServerEvent
	Wrapper.OnClientEvent = Raw.OnClientEvent

	function Wrapper:Fire(Params: Params, Data: any?)
		Raw:Fire(Params, Data or {})
	end

	function Wrapper:FireCloseClients(Params: Params, Data: any?)
		local Origin = GetOrigin(Params.Character)
		for _, Player in Players:GetPlayers() do
			if Origin then
				local PlayerChar = Player.Character
				local Root = PlayerChar and PlayerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not Root or (Root.Position - Origin).Magnitude > CLOSE_RANGE then
					continue
				end
			end

			Raw:FireClient(Player, Params, Data or {})
		end
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
	RemoteDistance: number,
}

local Configuration: Config = {
	ServerModulePaths = {},
	ClientModulePaths = {},
	UtilityPaths = {},
	RemoteDistance = 650,
}

-- Shared utilities accessible by both sides
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

	local moduleName = pms.Module or pms.Utility or ""
	local isNamespace = pms.Module ~= nil
	local module = GetModule(moduleName, isNamespace)
	if not module then return end

	local func = module[pms.Function]
	if typeof(func) ~= "function" then return end

	local callData: { [any]: any } = if typeof(data) == "table" then data else {}

	-- Only inject character if one was provided in the params
	if pms.Character then
		if Players:GetPlayerFromCharacter(pms.Character) == player then
			callData.Character = pms.Character -- right call from Player
		else
			warn("Caller doesnt match the player...exploits?")
			return
		end

	end

	local Function = func(callData, player) :: any
	--warn(tostring(Function).." MODULE RETURN!")
	if Function then
		warn("[UniHandler]: Fail Validation: "..tostring(pms.Character).." | "..tostring(pms.Module))
		Packets.ReplicateRemote:FireClient(player,{Module = pms.Module,Function = "Correction",Character = pms.Character})

	end
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

	local moduleName = pms.Module or pms.Utility or ""
	local isNamespace = pms.Module ~= nil
	local module = GetModule(moduleName, isNamespace)
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
local highlight = require(ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Util"):WaitForChild("Highlight") :: ModuleScript) :: any

local module = {}

module.Start = function(args: Packets.Args)
	local char = if typeof(args) == "table" then args.Character else (args :: any)
	if not char or not Players:GetPlayerFromCharacter(char) then return end

	Packets.ServerRemote:Fire({ Module = "Punch", Function = "Activate", Character = char })
	-- client-side prediction goes here
end

module.Correction = function(args: Packets.Args)
	print("Client Correction")
	--args.Type = "Correction" -- overwrite the passed Type to "Correction" to showcase the Invalid callback. otherwise it would stay empty and wont showcase it.
	module.Finish(args)
end

module.Finish = function(args: Packets.Args)
	print("Client Finished Task.")
	module.Effects(args) -- here we receive the args, if it was Touched by Correction, the Type would be "Correction" meaning that the call wasnt valid and that it was cancelled,
	--otherwise it was called by server and it IS valid, and to showcase that you pass from the server the Type = "Finish"
end

module.Effects = function(args: Packets.Args)
	local char = args.Character

	if args.Type == "Highlight" then
		highlight.Create({ Character = char, Color = Color3.fromRGB(255, 0, 0), Transparency = 0.5, FadeDuration = 1 })
	elseif args.Type == "Finish" then
		highlight.Create({ Character = char, Color = Color3.fromRGB(0, 0, 127), Transparency = 0.5, FadeDuration = 1 })
	elseif args.Type == "Correction" then
		highlight.Create({ Character = char, Color = Color3.fromRGB(0, 255, 0), Transparency = 0.5, FadeDuration = 1 })
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

module.Activate = function(args: Packets.Args, player: Player?): any
	local char = args.Character
	if not char then return "Fail" end
	if char:GetAttribute("Action") then return "Fail" end

	local hum = char:FindFirstChild("Humanoid") :: Humanoid?
	if not hum or hum.Health < 100 then return "Fail" end

	char:SetAttribute("Action", true)

	Packet:FireCloseClients({ Module = "Punch", Function = "Effects", Character = char }, { Type = "Highlight" })

	task.wait(10)

	Packet:FireCloseClients({ Module = "Punch", Function = "Finish", Character = char }, { Type = "Finish" })

	char:SetAttribute("Action", false)
	return
end

return module
```
</details>

<details>
<summary>Tool_example.lua (LocalScript inside Tool)</summary>

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
<summary>NPCActivator.lua (Script inside NPC model)</summary>

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
	warn(script.Parent)
	S_Punch.Activate({ Character = script.Parent })
end
```
</details>

---

## Credits
Built on top of [Packet](https://devforum.roblox.com/t/packet-networking-library/3573907) by suphi — a typed networking library required for the remote layer. Thanks suphi.
