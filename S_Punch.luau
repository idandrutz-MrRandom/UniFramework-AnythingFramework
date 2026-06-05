--!strict
local Packets = require(game.ReplicatedStorage.Remotes.Packets)
local Packet = Packets.ReplicateRemote
local module = {}
module.Remotes = { Activate = true }

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