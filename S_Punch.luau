--!strict
local Packets = require(game.ReplicatedStorage.Remotes.Packets)
local Packet = Packets.ReplicateRemote

local ACTION_DURATION = 10
local MIN_HEALTH = 100

local module = {}
module.Remotes = { Activate = true }

module.Activate = function(args: Packets.Args, player: Player?): any
	local char = args.Character
	if not char then return true end
	if char:GetAttribute("Action") then return true end

	local hum = char:FindFirstChildOfClass("Humanoid") :: Humanoid?
	if not hum or hum.Health < MIN_HEALTH then return true end

	-- No yield between the check above and this set, so the lock is race-free.
	-- Do not insert any awaiting call (DataStore, WaitForChild) here or two rapid
	-- activations could both pass the check before either one sets the attribute.
	char:SetAttribute("Action", true)

	-- Schedule the release before the first replication fire below. If a fire
	-- errors (destroyed character, serialization failure) the lock still clears
	-- in ACTION_DURATION instead of stranding the player unable to act.
	local actionChar: Model = char
	task.delay(ACTION_DURATION, function()
		actionChar:SetAttribute("Action", false)
		if actionChar.Parent then
			Packet:FireCloseClients({ Module = "Punch", Function = "Finish", Character = actionChar }, { Type = "Finish" })
		end
	end)

	Packet:FireCloseClients({ Module = "Punch", Function = "Effects", Character = char }, { Type = "Highlight" })
	return
end

return module
