--!strict

-- Keeps Roblox's standard third-person camera attached to the custom
-- character once the runtime bootstrap has supplied its Humanoid.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local function bindCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		warn("[RanCamera] Character Humanoid was not created within 10 seconds")
		return
	end

	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = humanoid
	end

	print("[RanCamera] Camera subject bound to " .. character.Name)
end

if player.Character then
	bindCharacter(player.Character)
end

player.CharacterAdded:Connect(bindCharacter)
