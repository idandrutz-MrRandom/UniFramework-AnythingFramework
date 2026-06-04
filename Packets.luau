--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Packet = require(ReplicatedStorage.Assets.Modules.Shared.Util.MainModule)
local Config = require(ReplicatedStorage.Assets.Modules.Configuration)

export type Character = Model
export type Params = {
	Module: string?,
	Utility: string?,
	Function: string,
	Character: Character?,
}
export type Args = {
	Character: Character?,
	[any]: any
}
type RawPacket = {
	Fire: (self: any, Params: Params, Data: any?) -> (),
	FireCloseClients: (self: any, Params: Params, Data: any?) -> (),
	FireClient: (self: any, Player: Player, Params: Params, Data: any?) -> (),
	OnServerEvent: any,
	OnClientEvent: any,
}

local CLOSE_RANGE =  Config.RemoteDistance

local function GetOrigin(Character: Character?): Vector3?
	if not Character then return nil end
	local Root = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if Root then Root.Position else nil
end

local function CreateRemote(Name: string): RawPacket
	local Raw = Packet(Name, Packet.Any, Packet.Any)
	local Wrapper = {}
	Wrapper.OnServerEvent = Raw.OnServerEvent
	Wrapper.OnClientEvent = Raw.OnClientEvent

	function Wrapper:Fire(Params: Params, Data: any?)
		Raw:Fire(Params, Data or {})
	end

	function Wrapper:FireCloseClients(Params: Params, Data: any?)
		local Origin = GetOrigin(Params.Character)
		for _, Player in Players:GetPlayers() do
			if Origin then
				local PlayerChar = Player.Character
				local Root = PlayerChar and PlayerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not Root or (Root.Position - Origin).Magnitude > CLOSE_RANGE then
					continue
				end
			end

			Raw:FireClient(Player, Params, Data or {})
		end
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