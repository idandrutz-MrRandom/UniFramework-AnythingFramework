--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Remotes.Packets)
local module = {}
local Opened: {[any]: any} = {}

module.Open = function(args : Packets.Args,player: Player?) : any
	local char = args.Character
	if not char then return end
	
	if char:GetAttribute("Level") and player then
		if char:GetAttribute("Level") >= 10 then
			Packets.ReplicateRemote:FireClient(player,{Module = "Shop",Function = "OpenEffect",Character = char})
			
		else
			return "Fail"
		end

	else
		return "Fail"
		
	end
	return
end

module.Close = function(args : Packets.Args,player: Player?) : any
	local char = args.Character
	if not char then return end

	if char:GetAttribute("Level") and player then
		if char:GetAttribute("Level") >= 10 then
			warn("CLOSED!")
			return
			
		end
	end

	return
end

return module
