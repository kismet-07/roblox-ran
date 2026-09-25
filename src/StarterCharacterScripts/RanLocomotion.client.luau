--!strict

-- Procedural locomotion for the Ran Online 52-bone skinned character.
-- This intentionally does not depend on unpublished Animation assets.
-- The gait is built from the character's actual Mixamo-style rest skeleton.

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

-- The default Roblox R6 Animate script is incompatible with this custom
-- skinned character because it expects Torso/limb parts and Motor6Ds.
local animate = character:FindFirstChild("Animate")
if animate and animate:IsA("LocalScript") then
	animate.Enabled = false
end

type BoneState = {
	bone: Bone,
	right: Vector3,
	up: Vector3,
	forward: Vector3,
}

local bones: {[string]: BoneState} = {}

local function registerBone(name: string)
	local object = mesh:FindFirstChild(name, true)
	if not object or not object:IsA("Bone") then
		warn("[RanLocomotion] Missing bone: " .. name)
		return
	end

	local bone = object :: Bone
	local world = bone.WorldCFrame
	local right = world:VectorToObjectSpace(root.CFrame.RightVector)
	local up = world:VectorToObjectSpace(root.CFrame.UpVector)
	local forward = world:VectorToObjectSpace(root.CFrame.LookVector)

	if right.Magnitude < 0.001 or up.Magnitude < 0.001 or forward.Magnitude < 0.001 then
		warn("[RanLocomotion] Invalid rest axes: " .. name)
		return
	end

	bones[name] = {
		bone = bone,
		right = right.Unit,
		up = up.Unit,
		forward = forward.Unit,
	}
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

-- Anatomical rotation helper. Angles are relative to the character's actual
-- rest-pose axes, rather than assuming every imported bone shares one axis.
local function pose(name: string, pitch: number?, yaw: number?, roll: number?, translation: Vector3?)
	local state = bones[name]
	if not state then
		return
	end

	local p = pitch or 0
	local y = yaw or 0
	local r = roll or 0
	local t = translation or Vector3.zero

	local transform = CFrame.new(t)
		* CFrame.fromAxisAngle(state.right, p)
		* CFrame.fromAxisAngle(state.up, y)
		* CFrame.fromAxisAngle(state.forward, r)

	state.bone.Transform = transform
end

local function applyLocomotion(phase: number, amount: number, running: boolean)
	local s = math.sin(phase)
	local c = math.cos(phase)

	local stride = math.rad(if running then 38 else 30) * amount
	local kneeMax = math.rad(if running then 34 else 23) * amount
	local ankleMax = math.rad(if running then 19 else 13) * amount
	local toeMax = math.rad(if running then 10 else 7) * amount
	local armSwing = math.rad(if running then 34 else 27) * amount
	local elbowMax = math.rad(if running then 20 else 13) * amount

	-- Smooth swing/stance curves. Knee and toe bend only during the swing
	-- portion of each stride instead of snapping at the zero crossing.
	local leftSwing = math.max(0, -s)
	local rightSwing = math.max(0, s)
	local leftKnee = leftSwing * leftSwing
	local rightKnee = rightSwing * rightSwing

	-- Legs: opposing thigh swing, then progressively stronger knee/ankle/toe
	-- articulation. Foot rotation counteracts the thigh to keep the sole more
	-- naturally oriented toward the floor.
	pose("mixamorig:LeftUpLeg", s * stride, c * math.rad(1.5) * amount, 0)
	pose("mixamorig:RightUpLeg", -s * stride, -c * math.rad(1.5) * amount, 0)

	pose("mixamorig:LeftLeg", -leftKnee * kneeMax, 0, 0)
	pose("mixamorig:RightLeg", -rightKnee * kneeMax, 0, 0)

	pose("mixamorig:LeftFoot", -s * ankleMax + leftKnee * math.rad(7) * amount, 0, 0)
	pose("mixamorig:RightFoot", s * ankleMax + rightKnee * math.rad(7) * amount, 0, 0)
	pose("mixamorig:LeftToeBase", leftKnee * toeMax, 0, 0)
	pose("mixamorig:RightToeBase", rightKnee * toeMax, 0, 0)

	-- Arms counter-swing naturally against the legs. The elbow bends more
	-- during the rearward swing, especially when running.
	pose("mixamorig:LeftArm", -s * armSwing, 0, 0)
	pose("mixamorig:RightArm", s * armSwing, 0, 0)
	pose("mixamorig:LeftForeArm", -rightKnee * elbowMax, 0, 0)
	pose("mixamorig:RightForeArm", -leftKnee * elbowMax, 0, 0)

	-- Small but visible whole-body rhythm.
	local bob = math.abs(c) * (if running then 0.055 else 0.035) * amount
	local hipRoll = s * math.rad(if running then 5 else 3.5) * amount
	local hipYaw = c * math.rad(if running then 4 else 2.5) * amount
	local torsoTwist = -s * math.rad(if running then 5 else 3) * amount
	local lean = math.rad(if running then 7 else 3) * amount

	pose("mixamorig:Hips", 0, hipYaw, hipRoll, Vector3.new(0, bob, 0))
	pose("mixamorig:Spine", lean, torsoTwist, 0)
	pose("mixamorig:Spine1", lean * 0.65, -torsoTwist * 0.65, 0)
	pose("mixamorig:Spine2", lean * 0.4, torsoTwist * 0.4, 0)

	-- Head/neck stabilize against the torso motion.
	pose("mixamorig:Neck", -lean * 0.35, -torsoTwist * 0.3, 0)
	pose("mixamorig:Head", -lean * 0.2, torsoTwist * 0.2, 0)
end

local phase = 0
local moving = false
local currentAmount = 0

RunService.RenderStepped:Connect(function(dt)
	if humanoid.Health <= 0 then
		if moving then
			resetBones()
			moving = false
			currentAmount = 0
		end
		return
	end

	local inputMagnitude = humanoid.MoveDirection.Magnitude
	local horizontalVelocity = Vector3.new(
		root.AssemblyLinearVelocity.X,
		0,
		root.AssemblyLinearVelocity.Z
	).Magnitude

	if inputMagnitude < 0.05 or horizontalVelocity < 0.15 then
		if moving then
			resetBones()
			moving = false
			currentAmount = 0
		end
		return
	end

	moving = true

	local walkSpeed = math.max(humanoid.WalkSpeed, 1)
	local speedRatio = math.clamp(horizontalVelocity / walkSpeed, 0.35, 1.5)
	local running = horizontalVelocity >= walkSpeed * 0.85

	-- Blend amplitude instead of instantly changing the gait at the run
	-- threshold. This avoids a visible mechanical transition.
	local targetAmount = math.clamp(horizontalVelocity / walkSpeed, 0.72, 1.05)
	currentAmount += (targetAmount - currentAmount) * math.min(dt * 10, 1)

	local frequency = if running then 9.5 else 6.8
	phase += dt * frequency * speedRatio
	if phase >= math.pi * 2 then
		phase -= math.pi * 2
	end

	resetBones()
	applyLocomotion(phase, currentAmount, running)
end)

local count = 0
for _ in pairs(bones) do
	count += 1
end

print(string.format("[RanLocomotion] Improved gait active for %s | bones=%d", player.Name, count))
