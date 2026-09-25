--!strict

-- Removes stale Studio-era character controllers that can survive a Rojo
-- session when the character was previously edited directly in Studio.
-- This keeps exactly one movement system: RanLocomotion.

local character = script.Parent

for _, child in character:GetChildren() do
	if child:IsA("AnimationController") then
		child:Destroy()
	elseif child:IsA("Script") or child:IsA("LocalScript") then
		if child ~= script then
			local name = child.Name
			if name == "Animate"
				or name == "RanAnimationController"
				or name == "Health"
				or name == "_TEMP_AnimTest" then
				child:Destroy()
			end
		end
	end
end

print("[RanCharacter] stale character controllers removed")
