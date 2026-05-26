--!strict
local Players = game:GetService("Players")
local Packets = require(game.ReplicatedStorage.Remotes.Packets)
local Packet = Packets.ReplicateRemote

local module = {}

module.Activate = function(Character: Packets.Character, data: any,player : Player)
	warn("Player is: ", player , "and players parent is: ", player.Parent)
	warn("Action Processed on:", Character.Name)
	print(typeof(Character))
	print(Character.Parent)
	-- Replicating without bonus data
	Packet:Fire(Character, {Module = "Punch", Function = "Effects"}, {Type = "Highlight"})
	local Player = Players:GetPlayerFromCharacter(Character)
	Packet:FireClient(Player,Character,{Module = "Punch", Function = "Effects"}, {Type = "Highlight"}) -- just test to showcase that it can work
end

return module