--!strict

-- Runtime locomotion for the Ran Online 52-bone skinned character.
-- The gait is authored as real KeyframeSequence/Pose data at runtime and
-- registered with Roblox's temporary animation provider. Roblox then handles
-- pose interpolation instead of manually changing Bone.Transform every frame.

local Players = game:GetService("Players")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

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
local animator = humanoid:WaitForChild("Animator") :: Animator

local animate = character:FindFirstChild("Animate")
if animate and animate:IsA("LocalScript") then
	animate.Enabled = false
end

local BONE_NAMES = {
	"mixamorig:Hips", "mixamorig:Spine", "mixamorig:Spine1", "mixamorig:Spine2",
	"mixamorig:Neck", "mixamorig:Head",
	"mixamorig:LeftUpLeg", "mixamorig:LeftLeg", "mixamorig:LeftFoot", "mixamorig:LeftToeBase",
	"mixamorig:RightUpLeg", "mixamorig:RightLeg", "mixamorig:RightFoot", "mixamorig:RightToeBase",
	"mixamorig:LeftArm", "mixamorig:LeftForeArm", "mixamorig:LeftHand",
	"mixamorig:RightArm", "mixamorig:RightForeArm", "mixamorig:RightHand",
}

type BoneInfo = {
	bone: Bone,
	bendAxis: Vector3,
	forwardAxis: Vector3,
}

local bones: {[string]: BoneInfo} = {}

local function firstBoneChild(bone: Bone): Bone?
	for _, child in bone:GetChildren() do
		if child:IsA("Bone") then
			return child
		end
	end
	return nil
end

-- Derive each joint's bend axis from the actual imported skeleton. This avoids
-- assuming a Mixamo bone uses a particular local Euler axis.
local function bendAxisWorld(bone: Bone): Vector3
	local child = firstBoneChild(bone)
	local parent = bone.Parent

	if child and parent and parent:IsA("Bone") then
		local incoming = bone.WorldPosition - parent.WorldPosition
		local outgoing = child.WorldPosition - bone.WorldPosition
		if incoming.Magnitude > 0.001 and outgoing.Magnitude > 0.001 then
			local axis = incoming.Unit:Cross(outgoing.Unit)
			if axis.Magnitude > 0.001 then
				axis = axis.Unit
				if axis:Dot(root.CFrame.RightVector) < 0 then
					axis = -axis
				end
				return axis
			end
		end
	end

	return root.CFrame.RightVector
end

local function localAxis(bone: Bone, worldAxis: Vector3): Vector3
	local axis = bone.WorldCFrame:VectorToObjectSpace(worldAxis)
	return axis.Magnitude > 0.001 and axis.Unit or Vector3.xAxis
end

for _, name in BONE_NAMES do
	local object = mesh:FindFirstChild(name, true)
	if object and object:IsA("Bone") then
		local bone = object :: Bone
		bones[name] = {
			bone = bone,
			bendAxis = localAxis(bone, bendAxisWorld(bone)),
			forwardAxis = localAxis(bone, root.CFrame.LookVector),
		}
	else
		warn("[RanLocomotion] Missing bone: " .. name)
	end
end

if not bones["mixamorig:Hips"] then
	warn("[RanLocomotion] Hips bone not found; locomotion disabled")
	return
end

local function rotation(name: string, angle: number): CFrame
	local state = bones[name]
	return state and CFrame.fromAxisAngle(state.bendAxis, angle) or CFrame.identity
end

local function yaw(name: string, angle: number): CFrame
	local state = bones[name]
	return state and CFrame.fromAxisAngle(state.forwardAxis, angle) or CFrame.identity
end

local function addPoseTree(parentBone: Instance, parentPose: Pose, transforms: {[string]: CFrame})
	for _, child in parentBone:GetChildren() do
		if child:IsA("Bone") then
			local pose = Instance.new("Pose")
			pose.Name = child.Name
			pose.CFrame = transforms[child.Name] or CFrame.identity
			pose.EasingStyle = Enum.PoseEasingStyle.CubicV2
			pose.EasingDirection = Enum.PoseEasingDirection.InOut
			parentPose:AddSubPose(pose)
			addPoseTree(child, pose, transforms)
		end
	end
end

local function makeKeyframe(time: number, transforms: {[string]: CFrame}): Keyframe
	local keyframe = Instance.new("Keyframe")
	keyframe.Time = time

	local hips = mesh:FindFirstChild("mixamorig:Hips", true)
	assert(hips and hips:IsA("Bone"), "Hips bone disappeared")

	local rootPose = Instance.new("Pose")
	rootPose.Name = hips.Name
	rootPose.CFrame = transforms[hips.Name] or CFrame.identity
	rootPose.EasingStyle = Enum.PoseEasingStyle.CubicV2
	rootPose.EasingDirection = Enum.PoseEasingDirection.InOut
	keyframe:AddPose(rootPose)
	addPoseTree(hips, rootPose, transforms)
	return keyframe
end

local function makeTransforms(phase: number, running: boolean): {[string]: CFrame}
	local s = math.sin(phase)
	local c = math.cos(phase)
	local stride = math.rad(if running then 34 else 27)
	local knee = math.rad(if running then 34 else 24)
	local ankle = math.rad(if running then 15 else 10)
	local toe = math.rad(if running then 8 else 5)
	local arm = math.rad(if running then 30 else 23)
	local elbow = math.rad(if running then 18 else 12)

	local leftSwing = math.max(0, -s)
	local rightSwing = math.max(0, s)
	local leftKnee = leftSwing * leftSwing
	local rightKnee = rightSwing * rightSwing

	local transforms: {[string]: CFrame} = {}

	transforms["mixamorig:LeftUpLeg"] = rotation("mixamorig:LeftUpLeg", s * stride) * yaw("mixamorig:LeftUpLeg", c * math.rad(2))
	transforms["mixamorig:RightUpLeg"] = rotation("mixamorig:RightUpLeg", -s * stride) * yaw("mixamorig:RightUpLeg", -c * math.rad(2))
	transforms["mixamorig:LeftLeg"] = rotation("mixamorig:LeftLeg", leftKnee * knee)
	transforms["mixamorig:RightLeg"] = rotation("mixamorig:RightLeg", rightKnee * knee)
	transforms["mixamorig:LeftFoot"] = rotation("mixamorig:LeftFoot", -s * ankle + leftKnee * math.rad(5))
	transforms["mixamorig:RightFoot"] = rotation("mixamorig:RightFoot", s * ankle + rightKnee * math.rad(5))
	transforms["mixamorig:LeftToeBase"] = rotation("mixamorig:LeftToeBase", leftKnee * toe)
	transforms["mixamorig:RightToeBase"] = rotation("mixamorig:RightToeBase", rightKnee * toe)

	transforms["mixamorig:LeftArm"] = rotation("mixamorig:LeftArm", -s * arm)
	transforms["mixamorig:RightArm"] = rotation("mixamorig:RightArm", s * arm)
	transforms["mixamorig:LeftForeArm"] = rotation("mixamorig:LeftForeArm", rightKnee * elbow)
	transforms["mixamorig:RightForeArm"] = rotation("mixamorig:RightForeArm", leftKnee * elbow)

	local lean = math.rad(if running then 6 else 3)
	local twist = s * math.rad(if running then 4 else 2.5)
	transforms["mixamorig:Hips"] = yaw("mixamorig:Hips", c * math.rad(3)) * rotation("mixamorig:Hips", s * math.rad(3))
	transforms["mixamorig:Spine"] = rotation("mixamorig:Spine", lean) * yaw("mixamorig:Spine", -twist)
	transforms["mixamorig:Spine1"] = rotation("mixamorig:Spine1", lean * 0.55) * yaw("mixamorig:Spine1", twist * 0.6)
	transforms["mixamorig:Spine2"] = rotation("mixamorig:Spine2", lean * 0.3) * yaw("mixamorig:Spine2", -twist * 0.35)
	transforms["mixamorig:Neck"] = rotation("mixamorig:Neck", -lean * 0.45) * yaw("mixamorig:Neck", twist * 0.25)
	transforms["mixamorig:Head"] = rotation("mixamorig:Head", -lean * 0.25) * yaw("mixamorig:Head", -twist * 0.15)

	return transforms
end

local function buildAnimation(name: string, running: boolean): (AnimationTrack, Animation)
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = name .. "_Runtime"
	sequence.Loop = true
	sequence.Priority = Enum.AnimationPriority.Movement

	local duration = if running then 0.72 else 0.95
	local frames = 8
	for i = 0, frames do
		local alpha = i / frames
		sequence:AddKeyframe(makeKeyframe(alpha * duration, makeTransforms(alpha * math.pi * 2, running)))
	end

	local ok, contentId = pcall(function()
		return KeyframeSequenceProvider:RegisterActiveKeyframeSequence(sequence)
	end)
	if not ok then
		sequence:Destroy()
		error("[RanLocomotion] Runtime animation registration failed: " .. tostring(contentId))
	end

	local animation = Instance.new("Animation")
	animation.Name = name .. "_Runtime"
	animation.AnimationId = contentId

	local track = animator:LoadAnimation(animation)
	track.Looped = true
	track.Priority = Enum.AnimationPriority.Movement

	sequence:Destroy()
	return track, animation
end

local okWalk, walkTrack, walkAnimation = pcall(function()
	return buildAnimation("Swordsman_Walk", false)
end)
if not okWalk then
	warn(tostring(walkTrack))
	return
end

local okRun, runTrack, runAnimation = pcall(function()
	return buildAnimation("Swordsman_Run", true)
end)
if not okRun then
	walkTrack:Destroy()
	walkAnimation:Destroy()
	warn(tostring(runTrack))
	return
end

local activeTrack: AnimationTrack? = nil

local function stopLocomotion()
	if activeTrack then
		activeTrack:Stop(0.15)
		activeTrack = nil
	end
end

local function switchTo(track: AnimationTrack, name: string, speed: number)
	if activeTrack == track then
		track:AdjustSpeed(speed)
		return
	end

	if activeTrack then
		activeTrack:Stop(0.12)
	end

	activeTrack = track
	track:Play(0.12, 1, speed)
	print(string.format("[RanLocomotion] %s active", name))
end

humanoid.Running:Connect(function(speed)
	if humanoid.Health <= 0 or speed < 0.5 then
		stopLocomotion()
		return
	end

	local running = speed >= humanoid.WalkSpeed * 0.85
	local ratio = math.clamp(speed / math.max(humanoid.WalkSpeed, 1), 0.55, 1.35)
	if running then
		switchTo(runTrack, "Swordsman_Run", ratio)
	else
		switchTo(walkTrack, "Swordsman_Walk", ratio)
	end
end)

humanoid.Died:Connect(stopLocomotion)

print(string.format("[RanLocomotion] Runtime animation tracks ready for %s | authoredBones=%d", player.Name, #BONE_NAMES))
