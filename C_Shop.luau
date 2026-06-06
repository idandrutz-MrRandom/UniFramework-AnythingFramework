--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Remotes.Packets)
local Player = game.Players.LocalPlayer :: Player
local playerGui = Player:WaitForChild("PlayerGui")
local module = {}

module.Open = function(args: Packets.Args)
	print("OPENED!")




	local shopGui = playerGui:WaitForChild("ShopUi") :: ScreenGui
	shopGui.Enabled = true

	Packets.ServerRemote:Fire({
		Module = "Shop",
		Function = "Open",
		Character = args.Character
	})
end

module.Close = function(args: Packets.Args)
	local shopGui = playerGui:WaitForChild("ShopUi") :: ScreenGui
	shopGui.Enabled = false
	print("CLOSED!")
	Packets.ServerRemote:Fire({
		Module = "Shop",
		Function = "Close",
		Character = args.Character
	})
end

module.Correction = function(args: Packets.Args)
	module.Close(args)
	print("CORRECTION!")
end

return module