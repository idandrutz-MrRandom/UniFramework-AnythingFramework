--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")

local Packets           = require(ReplicatedStorage.Remotes.Packets)


local Packet            = Packets.ReplicateRemote



local module: { [any]: any } = {}
local SavedTasks: { [any]: any} = {}

module.Activate = function(args: Packets.Args, player: Player?): string?
	local char = args.Character
	if not char then return "Fail" end
	
	-- if you want to do a validation check make an if statement and if it fails then return "Fail" , this will tell the system to find the Correction Function inside the Client module and run it
	-- here is a commented example:
	--if char:FindFirstChild("Humanoid").Health < 100 then return "Fail" end -- this exits this function and calls correction
	
	if not player then
		Packet:FireCloseClients({ Module = "Template", Function = "Start", Character = char })
	end
	--
	
	local Tasks =  task.spawn(function()
		-- here you can call diffrent actions if you want to have an action list, preferably from the server module just to keep it clean. for example:
		module.Action1(args)
		task.wait(2)
		module.Cleanup(args)
	end)
	SavedTasks[char] = Tasks :: thread-- if you want to cancel the actions from the server, you can delete the thread.
	
	return nil
end

module.Action1 = function(args : Packets.Args)
	print("Action1")
	
	-- here we can call effects from the {Module = "Template",Function = "Effects",Character = args.Character},{Type = "Action1"}
	Packet:FireCloseClients({Module = "Template",Function = "Effects",Character = args.Character},{Type = "Action1"})
end



module.Cleanup = function(args: Packets.Args)
	print("Cleaned up!")
	-- here we can set states for the action, for example in the punch skill we set the state action to false here, because the skill finished.
end

return module