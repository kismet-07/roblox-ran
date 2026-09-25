--!strict

-- Procedural locomotion for the Ran Online skinned character.
-- The source-controlled character does not contain published Walk/Run assets,
-- so locomotion is generated from the actual Mixamo bone rest pose.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local root = character:WaitForChild("HumanoidRootPart") :: BasePart
local meshObject = character:FindFirstChild("tripo_node_d2795b5d", true)

if not meshObject or not meshObject:IsA("MeshPart") then
	warn("[RanLocomotion] Character mesh not found; locomotion disabled")
	return
end

local mesh = meshObject :: MeshPart

-- Disable Roblox's legacy R6 animator if the engine injects it.
local animate = character:FindFirstChild("Animate")
if animate and animate:IsA("LocalScript") then
	animate.Enabled = false
end

type BoneState = { bone: Bone, axis: Vector3 }
local bones: {[string]: BoneState} = {}

local function registerBone(name: string)
	local object = mesh:FindFirstChild(name, true)
	if not object or not object:IsA("Bone") then
		warn("[RanLocomotion] Missing bone: " .. name)
		return
	end

	local bone = object :: Bone
	local axis = bone.WorldCFrame:VectorToObjectSpace(root.CFrame.RightVector)
	if axis.Magnitude > 0.001 then
		bones[name] = { bone = bone, axis = axis.Unit }
	end
end

for _, name in ipairs({
	"mixamorig:Hips", "mixamorig:Spine", "mixamorig:Spine1", "mixamorig:Spine2",
	"mixamorig:Neck", "mixamorig:Head",
	"mixamorig:LeftUpLeg", "mixamorig:LeftLeg", "mixamorig:LeftFoot", "mixamorig:LeftToeBase",
	"mixamorig:RightUpLeg", "mixamorig:RightLeg", "mixamorig:RightFoot", "mixamorig:RightToeBase",
	"mixamorig:LeftArm", "mixamorig:LeftForeArm", "mixamorig:LeftHand",
	"mixamorig:RightArm", "mixamorig:RightForeArm", "mixamorig:RightHand",
}) do
	registerBone(name)
end

if not bones["mixamorig:Hips"] then
	warn("[RanLocomotion] Hips bone not found; locomotion disabled")
	return
end

local function resetBones()
	for _, state in pairs(bones) do
		state.bone.Transform = CFrame.identity
	end
end

local function rotate(name: string, radians: number)
	local state = bones[name]
	if state then
		state.bone.Transform = CFrame.fromAxisAngle(state.axis, radians)
	end
end

local function applyPose(phase: number, intensity: number, running: boolean)
	local s = math.sin(phase)
	local c = math.cos(phase)

	local legSwing = (running and math.rad(34) or math.rad(25)) * intensity
	local knee = (running and math.rad(22) or math.rad(12)) * intensity
	local foot = (running and math.rad(16) or math.rad(11)) * intensity
	local armSwing = (running and math.rad(30) or math.rad(20)) * intensity
	local elbow = (running and math.rad(16) or math.rad(8)) * intensity

	-- Alternating legs.
	rotate("mixamorig:LeftUpLeg", s * legSwing)
	rotate("mixamorig:RightUpLeg", -s * legSwing)
	rotate("mixamorig:LeftLeg", math.max(0, -s) * knee)
	rotate("mixamorig:RightLeg", math.max(0, s) * knee)
	rotate("mixamorig:LeftFoot", -s * foot)
	rotate("mixamorig:RightFoot", s * foot)
	rotate("mixamorig:LeftToeBase", -s * math.rad(5) * intensity)
	rotate("mixamorig:RightToeBase", s * math.rad(5) * intensity)

	-- Arms counter-swing against the legs.
	rotate("mixamorig:LeftArm", -s * armSwing)
	rotate("mixamorig:RightArm", s * armSwing)
	rotate("mixamorig:LeftForeArm", math.max(0, s) * elbow)
	rotate("mixamorig:RightForeArm", math.max(0, -s) * elbow)

	-- Small body motion.
	local hip = (running and math.rad(5) or math.rad(3)) * intensity
	local spine = (running and math.rad(3) or math.rad(2)) * intensity
	rotate("mixamorig:Hips", c * hip)
	rotate("mixamorig:Spine", -c * spine)
	rotate("mixamorig:Spine1", c * spine * 0.65)
	rotate("mixamorig:Spine2", -c * spine * 0.4)
	rotate("mixamorig:Neck", -s * math.rad(2) * intensity)
	rotate("mixamorig:Head", s * math.rad(2) * intensity)
end

local phase = 0
local moving = false

RunService.RenderStepped:Connect(function(dt)
	if humanoid.Health <= 0 then
		if moving then resetBones(); moving = false end
		return
	end

	local inputMagnitude = humanoid.MoveDirection.Magnitude
	local velocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude

	if inputMagnitude < 0.05 or velocity < 0.15 then
		if moving then resetBones(); moving = false end
		return
	end

	moving = true
	local walkSpeed = math.max(humanoid.WalkSpeed, 1)
	local ratio = math.clamp(velocity / walkSpeed, 0.35, 1.5)
	local running = velocity >= walkSpeed * 0.8
	local frequency = if running then 9 else 6.5

	phase += dt * frequency * ratio
	if phase >= math.pi * 2 then phase -= math.pi * 2 end

	local intensity = math.clamp(velocity / walkSpeed, 0.65, 1)
	resetBones()
	applyPose(phase, intensity, running)
end)

local count = 0
for _ in pairs(bones) do count += 1 end
print(string.format("[RanLocomotion] Procedural locomotion active for %s | bones=%d", player.Name, count))
