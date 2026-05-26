--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packet = require(ReplicatedStorage.Assets.Modules.Shared.Util.MainModule)

-- We define the type directly in the function signature to force the dropdown hints
type PacketObject = {
	Fire: (
		self: any, 
		Character: Model, 
		Params: {
			Skill: string?, 
			Key: string?, 
			Function: string
		}, 
		Data: any
	) -> (),
	FireClient: (
		self: any,
		Player : Player,
		Character: Model, 
		Params: {
			Skill: string?, 
			Key: string ?, 
			Function: string
		}, 
		Data: any
	) -> (),
	OnServerEvent: any,
	OnClientEvent: any
}

local Packets = {
	EquipEvent = Packet("EquipEvent", Packet.String, Packet.String, Packet.Any),
	CooldownSync = Packet("CooldownSync", Packet.Any, Packet.Any, Packet.Any),

	-- Cast to the specific PacketObject type
	ServerRemote = Packet("ServerRemote", Packet.Instance, Packet.Any, Packet.Any) :: PacketObject,
	ReplicateRemote = Packet("ReplicateRemote", Packet.Instance, Packet.Any, Packet.Any) :: PacketObject,

	RagdollRemote = Packet("RagdollRemote", Packet.Instance, Packet.Any)
}

return Packets
