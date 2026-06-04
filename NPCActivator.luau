--!strict
task.wait(1)
local ServerScriptService = game:GetService("ServerScriptService")
local S_Punch = require(
	ServerScriptService:WaitForChild("ServerSkills")
		:FindFirstChild("Punch")
		:FindFirstChild("S_Punch")
) :: any

while true do
	task.wait(2)
	warn(script.Parent)
	S_Punch.Activate({ Character = script.Parent })
end