--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Remotes.Packets)

local highlightInstance = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Util"):WaitForChild("Highlight") :: ModuleScript
local highlight = require(highlightInstance) :: any

local Player = game:GetService("Players").LocalPlayer

local Packet = Packets.ServerRemote
local module = {}

module.Start = function(char: Packets.Character)
	print("Character is " .. tostring(char))
	Packet:Fire(char, {Module = "Punch", Function = "Activate"})
end

module.Effects = function(args: Packets.Args)
	if args.Type == "Highlight" then
		highlight.Create({
			Character = args.Character :: Model,
			Color = Color3.fromRGB(255, 0, 0),
			Transparency = 0.5,
			FadeDuration = 1
		})
	end
end

return module