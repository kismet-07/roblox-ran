--!strict

-- Client-side locomotion for the Ran Online skinned character.
--
-- Roblox's KeyframeSequenceProvider registration APIs are Studio/Solo-only
-- for this use case, so they cannot be used by a normal Play test/live game.
-- Until Walk/Run are published as Roblox animation assets, this script uses
-- Bone.Transform for a local procedural gait. Bone.Transform is the runtime
-- animation offset for skinned bones.

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

-- The Roblox default Animate script expects a standard R6/R15 body hierarchy.
-- This character is a single skinned MeshPart, so the default script must not
-- compete with the procedural controller.
local animate = character:FindFirstChild("Animate")
if animate and animate:IsA("LocalScript") then
	animate.Enabled = false
end

local BONE_NAMES = {
	"mixamorig:Hips",
	"mixamorig:Spine",
	"mixamorig:Spine1",
	"mixamorig:Spine2",
	"mixamorig:Neck",
	"mixamorig:Head",
	"mixamorig:LeftUpLeg",
	"mixamorig:LeftLeg",
	"mixamorig:LeftFoot",
	"mixamorig:LeftToeBase",
	"mixamorig:RightUpLeg",
	"mixamorig:RightLeg",
	"mixamorig:RightFoot",
	"mixamorig:RightToeBase",
	"mixamorig:LeftArm",
	"mixamorig:LeftForeArm",
	"mixamorig:LeftHand",
	"mixamorig:RightArm",
	"mixamorig:RightForeArm",
	"mixamorig:RightHand",
}

type BoneInfo = {
	bone: Bone,
	sideAxis: Vector3,
	upAxis: Vector3,
}

local bones: {[string]: BoneInfo} = {}

local function toLocalAxis(bone: Bone, worldAxis: Vector3): Vector3
	local axis = bone.WorldCFrame:VectorToObjectSpace(worldAxis)
	if axis.Magnitude < 0.001 then
		return Vector3.xAxis
	end
	return axis.Unit
end

-- Convert the character's actual world axes into every bone's local space.
-- This avoids assuming an arbitrary Mixamo local X/Y/Z convention.
for _, name in BONE_NAMES do
	local object = mesh:FindFirstChild(name, true)
	if object and object:IsA("Bone") then
		local bone = object :: Bone
		bones[name] = {
			bone = bone,
			sideAxis = toLocalAxis(bone, root.CFrame.RightVector),
			upAxis = toLocalAxis(bone, root.CFrame.UpVector),
		}
	else
		warn("[RanLocomotion] Missing bone: " .. name)
	end
end

local function rot(name: string, axisName: "sideAxis" | "upAxis", angle: number): CFrame
	local info = bones[name]
	if not info then
		return CFrame.identity
	end
	return CFrame.fromAxisAngle(info[axisName], angle)
end

local function setTransform(name: string, transform: CFrame)
	local info = bones[name]
	if info then
		info.bone.Transform = transform
	end
end

local function resetTransforms()
	for _, info in bones do
		info.bone.Transform = CFrame.identity
	end
end

local phase = 0
local lastMoving = false
local lastMode = "Idle"

local WALK_SPEED = 16
local RUN_THRESHOLD = 20

local function horizontalSpeed(): number
	local velocity = root.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
end

local function applyGait(speed: number, dt: number)
	local running = speed >= RUN_THRESHOLD
	local normalized = math.clamp(speed / WALK_SPEED, 0.45, 1.35)

	local cyclesPerSecond = if running then 2.0 else 1.25
	phase = (phase + dt * cyclesPerSecond * math.pi * 2) % (math.pi * 2)

	local s = math.sin(phase)
	local s2 = math.sin(phase * 2)

	local stride = math.rad(if running then 30 else 22) * normalized
	local kneeMax = math.rad(if running then 38 else 26) * normalized
	local armSwing = math.rad(if running then 24 else 17) * normalized
	local elbowMax = math.rad(if running then 16 else 9)

	local leftLegSwing = s * stride
	local rightLegSwing = -s * stride

	local leftRecovery = math.max(0, -s)
	local rightRecovery = math.max(0, s)
	local leftKnee = leftRecovery * kneeMax
	local rightKnee = rightRecovery * kneeMax

	local leftArmSwing = -s * armSwing
	local rightArmSwing = s * armSwing

	local bob = math.abs(s2) * (if running then 0.035 else 0.022)
	local torsoLean = math.rad(if running then 5 else 2.5)
	local torsoTwist = s * math.rad(if running then 3.5 else 2)

	setTransform(
		"mixamorig:Hips",
		CFrame.new(0, bob, 0)
			* rot("mixamorig:Hips", "sideAxis", s * math.rad(if running then 2.5 else 1.5))
			* rot("mixamorig:Hips", "upAxis", torsoTwist * 0.5)
	)

	setTransform("mixamorig:LeftUpLeg", rot("mixamorig:LeftUpLeg", "sideAxis", leftLegSwing))
	setTransform("mixamorig:RightUpLeg", rot("mixamorig:RightUpLeg", "sideAxis", rightLegSwing))

	setTransform("mixamorig:LeftLeg", rot("mixamorig:LeftLeg", "sideAxis", leftKnee))
	setTransform("mixamorig:RightLeg", rot("mixamorig:RightLeg", "sideAxis", rightKnee))

	setTransform(
		"mixamorig:LeftFoot",
		rot("mixamorig:LeftFoot", "sideAxis", -leftLegSwing * 0.55 - leftKnee * 0.35)
	)
	setTransform(
		"mixamorig:RightFoot",
		rot("mixamorig:RightFoot", "sideAxis", -rightLegSwing * 0.55 - rightKnee * 0.35)
	)

	setTransform("mixamorig:LeftToeBase", rot("mixamorig:LeftToeBase", "sideAxis", leftKnee * 0.2))
	setTransform("mixamorig:RightToeBase", rot("mixamorig:RightToeBase", "sideAxis", rightKnee * 0.2))

	setTransform(
		"mixamorig:LeftArm",
		rot("mixamorig:LeftArm", "sideAxis", leftArmSwing)
			* rot("mixamorig:LeftArm", "upAxis", -torsoTwist * 0.25)
	)
	setTransform(
		"mixamorig:RightArm",
		rot("mixamorig:RightArm", "sideAxis", rightArmSwing)
			* rot("mixamorig:RightArm", "upAxis", torsoTwist * 0.25)
	)

	setTransform("mixamorig:LeftForeArm", rot("mixamorig:LeftForeArm", "sideAxis", rightRecovery * elbowMax))
	setTransform("mixamorig:RightForeArm", rot("mixamorig:RightForeArm", "sideAxis", leftRecovery * elbowMax))

	setTransform(
		"mixamorig:Spine",
		rot("mixamorig:Spine", "sideAxis", torsoLean)
			* rot("mixamorig:Spine", "upAxis", -torsoTwist)
	)
	setTransform(
		"mixamorig:Spine1",
		rot("mixamorig:Spine1", "sideAxis", torsoLean * 0.55)
			* rot("mixamorig:Spine1", "upAxis", torsoTwist * 0.55)
	)
	setTransform(
		"mixamorig:Spine2",
		rot("mixamorig:Spine2", "sideAxis", torsoLean * 0.25)
			* rot("mixamorig:Spine2", "upAxis", -torsoTwist * 0.25)
	)
	setTransform("mixamorig:Neck", rot("mixamorig:Neck", "sideAxis", -torsoLean * 0.25))
	setTransform("mixamorig:Head", rot("mixamorig:Head", "sideAxis", -torsoLean * 0.12))
end

RunService.PreRender:Connect(function(dt)
	if humanoid.Health <= 0 then
		if lastMoving then
			resetTransforms()
			lastMoving = false
		end
		return
	end

	local moving = humanoid.MoveDirection.Magnitude > 0.05
	local speed = horizontalSpeed()

	if not moving or speed < 0.5 then
		if lastMoving then
			resetTransforms()
			lastMoving = false
			lastMode = "Idle"
			print("[RanLocomotion] Idle")
		end
		return
	end

	if not lastMoving then
		phase = 0
		lastMoving = true
	end

	local mode = if speed >= RUN_THRESHOLD then "Swordsman_Run" else "Swordsman_Walk"
	if mode ~= lastMode then
		lastMode = mode
		print(string.format("[RanLocomotion] %s active | speed=%.2f", mode, speed))
	end

	applyGait(speed, dt)
end)

resetTransforms()

print(string.format(
	"[RanLocomotion] Procedural locomotion ready for %s | bones=%d | walk=%d | run=%d",
	player.Name,
	#BONE_NAMES,
	WALK_SPEED,
	RUN_THRESHOLD
))
