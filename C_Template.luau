--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local Packets           = require(ReplicatedStorage.Remotes.Packets)
local Assets            = ReplicatedStorage:WaitForChild("Assets")
local highlight         = require(Assets.Modules.Client.Util:WaitForChild("Highlight"))




local module: {[any]: any} = {}

local function getChar(args: Packets.Args)
	return if typeof(args) == "table" then args.Character else args
end

module.Start = function(args: Packets.Args) : any
	local char = getChar(args) -- CHECK THE CHARACTER
	if not char then return end

	



	
	if Players:GetPlayerFromCharacter(char) then
		-- before you fire to the server, make some extra checks to ensure that it would be valid, otherwise there will be desync and correction will have to kick in
		Packets.ServerRemote:Fire({ Module = "Template", Function = "Activate", Character = char }) -- IF ITS A PLAYER THEN ASK HIM TO REQUEST THE SERVER SIDE OF THE SKILL
	end
	--do client side effects such as animations and other stuff
	
	
	return nil
end


module.Correction = function(args: Packets.Args)
	local char = getChar(args)
	if not char then return end

	args.Type = "Correction" -- the type is set to showcase the correction color. because its acting from client there will be no overwrites with the Type meaning that you can change it.
	module.Finish(args)
	

end

module.Finish = function(args: Packets.Args)
	module.Effects(args)
end

-- Fixed Effects logic	to match the args structure
module.Effects = function(args: Packets.Args)
	local char = args.Character :: Packets.Character
	local effectType = args.Data and args.Data.Type or args.Type

	if effectType == "Action1" then
		highlight.Create({ Character = char, Color = Color3.fromRGB(255, 0, 0), Transparency = 0.5, FadeDuration = 0.5 })
	elseif effectType == "Finish" then
		highlight.Create({ Character = char, Color = Color3.fromRGB(0, 0, 127), Transparency = 0.5, FadeDuration = 0.5 })
	elseif effectType == "Correction" then
		highlight.Create({ Character = char, Color = Color3.fromRGB(0, 255, 0), Transparency = 0.5, FadeDuration = 0.5 })
	end
end



return module