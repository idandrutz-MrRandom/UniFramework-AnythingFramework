--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packet = require(ReplicatedStorage.Assets.Modules.Shared.Util.MainModule)

export type Character = Model
export type Params = { Module: string?, Utility: string?, Function: string }
export type Args = { Context: Character, [any]: any }

type RawPacket = {
	Fire: (self: any, Context: Character, Params: Params, Data: any?) -> (),
	FireClient: (self: any, Player: Player, Context: Character, Params: Params, Data: any?) -> (),
	OnServerEvent: any,
	OnClientEvent: any
}

local function CreateRemote(Name: string): RawPacket
	local Raw = Packet(Name, Packet.Instance, Packet.Any, Packet.Any)
	local Wrapper = {}

	Wrapper.OnServerEvent = Raw.OnServerEvent
	Wrapper.OnClientEvent = Raw.OnClientEvent

	function Wrapper:Fire(Context: Character, Params: Params, Data: any?)
		Raw:Fire(Context, Params, Data or {})
	end

	function Wrapper:FireClient(Player: Player, Context: Character, Params: Params, Data: any?)
		Raw:FireClient(Player, Context, Params, Data or {})
	end

	return Wrapper :: any
end

return {
	ServerRemote = CreateRemote("ServerRemote"),
	ReplicateRemote = CreateRemote("ReplicateRemote"),
}