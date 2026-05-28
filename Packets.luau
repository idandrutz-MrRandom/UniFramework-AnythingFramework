--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packet = require(ReplicatedStorage.Assets.Modules.Shared.Util.MainModule)

export type Character = Model

export type Params = {
	Module: string?,
	Utility: string?,
	Function: string,
	Character: Character?,  -- optional: only set when the call involves a character
}

export type Args = {
	Character: Character?,  -- optional: modules must handle nil
	[any]: any
}

type RawPacket = {
	Fire: (self: any, Params: Params, Data: any?) -> (),
	FireClient: (self: any, Player: Player, Params: Params, Data: any?) -> (),
	OnServerEvent: any,
	OnClientEvent: any,
}

local function CreateRemote(Name: string): RawPacket
	local Raw = Packet(Name, Packet.Any, Packet.Any)
	local Wrapper = {}

	Wrapper.OnServerEvent = Raw.OnServerEvent
	Wrapper.OnClientEvent = Raw.OnClientEvent

	function Wrapper:Fire(Params: Params, Data: any?)
		Raw:Fire(Params, Data or {})
	end

	function Wrapper:FireClient(Player: Player, Params: Params, Data: any?)
		Raw:FireClient(Player, Params, Data or {})
	end

	return Wrapper :: any
end

return {
	ServerRemote = CreateRemote("ServerRemote"),
	ReplicateRemote = CreateRemote("ReplicateRemote"),
}