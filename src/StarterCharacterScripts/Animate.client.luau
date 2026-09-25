--!strict

-- Ran Online-style character locomotion.
-- This intentionally replaces Roblox's default R6 Animate script.
-- The imported character is a custom Mixamo-style skinned mesh, so the
-- default R6 animation controller cannot drive it.
--
-- V1 uses procedural bone transforms so locomotion does not depend on
-- unpublished Roblox Animation asset IDs. Once authored animations are
-- published, this controller can be replaced by an Animator/AnimationTrack
-- implementation without changing the movement system.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local root = character:WaitForChild("HumanoidRootPart") :: BasePart

humanoid.AutoRotate = true

local mesh = character:FindFirstChild("tripo_node_d2795b5d")
if not mesh or not mesh:IsA("MeshPart") then
	warn("[RanAnimation] Custom mesh was not found; locomotion animation disabled")
	return
end

local function getBone(name: string): Bone?
	local bone = mesh:FindFirstChild(name, true)
	if bone and bone:IsA("Bone") then
		return bone
	end
	return nil
end

local bones = {
	hips = getBone("mixamorig:Hips"),
	spine = getBone("mixamorig:Spine"),
	spine1 = getBone("mixamorig:Spine1"),
	spine2 = getBone("mixamorig:Spine2"),
	neck = getBone("mixamorig:Neck"),
	head = getBone("mixamorig:Head"),
	leftUpperLeg = getBone("mixamorig:LeftUpLeg"),
	leftLowerLeg = getBone("mixamorig:LeftLeg"),
	leftFoot = getBone("mixamorig:LeftFoot"),
	leftToe = getBone("mixamorig:LeftToeBase"),
	rightUpperLeg = getBone("mixamorig:RightUpLeg"),
	rightLowerLeg = getBone("mixamorig:RightLeg"),
	rightFoot = getBone("mixamorig:RightFoot"),
	rightToe = getBone("mixamorig:RightToeBase"),
	leftUpperArm = getBone("mixamorig:LeftArm"),
	leftForeArm = getBone("mixamorig:LeftForeArm"),
	rightUpperArm = getBone("mixamorig:RightArm"),
	rightForeArm = getBone("mixamorig:RightForeArm"),
}

local base: {[Bone]: CFrame} = {}
for _, bone in pairs(bones) do
	if bone then
		base[bone] = bone.Transform
	end
end

local function apply(bone: Bone?, transform: CFrame)
	if bone then
		bone.Transform = base[bone] * transform
	end
end

local function resetBones()
	for bone, transform in pairs(base) do
		bone.Transform = transform
	end
end

local function smoothStep(current: number, target: number, dt: number, response: number): number
	local alpha = 1 - math.exp(-response * dt)
	return current + (target - current) * alpha
end

local phase = 0
local strength = 0
local targetStrength = 0
local speedScale = 0
local targetSpeedScale = 0
local lastState = "Idle"

RunService.RenderStepped:Connect(function(dt)
	if humanoid.Health <= 0 then
		resetBones()
		return
	end

	local velocity = root.AssemblyLinearVelocity
	local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local speed = horizontalVelocity.Magnitude
	local moving = humanoid.MoveDirection.Magnitude > 0.05 and speed > 0.15

	if not moving then
		targetStrength = 0
		targetSpeedScale = 0
	else
		-- Walk below 10 studs/s, run at normal/default character speed.
		if speed < 10 then
			lastState = "Walk"
			targetSpeedScale = 1.0
		else
			lastState = "Run"
			targetSpeedScale = 1.55
		end
		targetStrength = math.clamp(speed / math.max(humanoid.WalkSpeed, 0.01), 0, 1)
	end

	strength = smoothStep(strength, targetStrength, dt, 10)
	speedScale = smoothStep(speedScale, targetSpeedScale, dt, 10)

	if strength < 0.01 then
		phase = 0
		resetBones()
		return
	end

	phase += dt * 7.0 * speedScale
	local swing = math.sin(phase)
	local opposite = math.sin(phase + math.pi)
	local bob = math.abs(math.sin(phase * 2))
	local blend = strength

	-- Legs: alternating forward/back movement.
	apply(bones.leftUpperLeg, CFrame.Angles(opposite * math.rad(24) * blend, 0, 0))
	apply(bones.rightUpperLeg, CFrame.Angles(swing * math.rad(24) * blend, 0, 0))

	-- Slight knee bend keeps the gait from looking rigid.
	apply(bones.leftLowerLeg, CFrame.Angles(math.max(0, swing) * math.rad(18) * blend, 0, 0))
	apply(bones.rightLowerLeg, CFrame.Angles(math.max(0, opposite) * math.rad(18) * blend, 0, 0))

	-- Feet follow the leg cycle.
	apply(bones.leftFoot, CFrame.Angles(-opposite * math.rad(10) * blend, 0, 0))
	apply(bones.rightFoot, CFrame.Angles(-swing * math.rad(10) * blend, 0, 0))
	apply(bones.leftToe, CFrame.Angles(opposite * math.rad(5) * blend, 0, 0))
	apply(bones.rightToe, CFrame.Angles(swing * math.rad(5) * blend, 0, 0))

	-- Arms counter-swing against the legs.
	apply(bones.leftUpperArm, CFrame.Angles(swing * math.rad(20) * blend, 0, 0))
	apply(bones.rightUpperArm, CFrame.Angles(opposite * math.rad(20) * blend, 0, 0))
	apply(bones.leftForeArm, CFrame.Angles(math.max(0, -swing) * math.rad(8) * blend, 0, 0))
	apply(bones.rightForeArm, CFrame.Angles(math.max(0, -opposite) * math.rad(8) * blend, 0, 0))

	-- Small body motion prevents the upper body from looking frozen.
	apply(bones.hips, CFrame.Angles(0, swing * math.rad(2.5) * blend, 0) * CFrame.new(0, bob * 0.025 * blend, 0))
	apply(bones.spine, CFrame.Angles(math.sin(phase * 2) * math.rad(2) * blend, 0, 0))
	apply(bones.spine1, CFrame.Angles(math.sin(phase * 2) * math.rad(1.5) * blend, 0, 0))
	apply(bones.spine2, CFrame.Angles(math.sin(phase * 2) * math.rad(1) * blend, 0, 0))
	apply(bones.neck, CFrame.Angles(math.sin(phase * 2) * math.rad(0.75) * blend, 0, 0))
	apply(bones.head, CFrame.Angles(math.sin(phase * 2 + math.pi) * math.rad(0.5) * blend, 0, 0))
end)

print("[RanAnimation] Custom locomotion controller active for", player.Name)
