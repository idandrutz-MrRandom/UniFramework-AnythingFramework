--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Remotes.Packets)
local Players = game:GetService("Players")
local highlight = require(ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Util"):WaitForChild("Highlight") :: ModuleScript) :: any

local module = {}

module.Start = function(args: Packets.Args)

	-- args.Character may be nil for characterless calls -- make sure to guard against this
	local char = if typeof(args) == "table" then args.Character else (args :: any)

	if char and Players:GetPlayerFromCharacter(char) then
		Packets.ServerRemote:Fire({Module = "Punch",Function = "Activate",Character = char})
	end
	-- rest client logic is 
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