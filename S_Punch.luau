--!strict
local Packets = require(game.ReplicatedStorage.Remotes.Packets)
local Packet = Packets.ReplicateRemote

local module = {}

module.Activate = function(args: Packets.Args, player: Player?)
	local char = args.Character  -- may be nil for characterless calls

	if not player then
		-- NPC path: replicate Start logic to all clients
		Packet:Fire({
			Module = "Punch",
			Function = "Start",
			Character = char,
		})
	end

	-- Always replicate effects (character optional — Effects handles nil gracefully)
	Packet:Fire({
		Module = "Punch",
		Function = "Effects",
		Character = char,
	}, { Type = "Highlight" })
end

return module