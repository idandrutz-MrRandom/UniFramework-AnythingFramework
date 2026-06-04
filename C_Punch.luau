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