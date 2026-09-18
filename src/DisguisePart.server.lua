--[[
	DisguisePart.server.lua

	Setup in Roblox Studio:
	1. Place this Script as a direct child of the Part that should trigger the disguise
	   (e.g. Workspace.DisguisePart.DisguisePart -- rename freely, the script only
	   cares that its parent is a BasePart).
	2. Put the Accessory you want players to receive as a direct child of that same
	   Part (drag it into the Part in the Explorer). The script clones it each time
	   someone touches the part, so the original stays in place and can be reused.

	Behavior on touch:
	- Removes all of the toucher's current Accessories.
	- Removes classic Shirt/Pants (their texture would otherwise still show through
	  the new body color, since clothing renders as an overlay independent of a
	  part's Color property).
	- Recolors every body part to RGB(126, 104, 63).
	- Makes the Head invisible.
	- Equips the disguise Accessory found under this Part, if any.
]]

local part = script.Parent
assert(part and part:IsA("BasePart"), "DisguisePart.server.lua must be parented to a BasePart")

local BODY_COLOR = Color3.fromRGB(126, 104, 63)

local debounce = {}

local function findAccessoryAmong(children)
	for _, child in ipairs(children) do
		if child:IsA("Accessory") then
			return child
		end
	end
	return nil
end

local function findDisguiseAccessory()
	-- Look directly under the part first, then fall back to the part's
	-- parent, in case the accessory was placed alongside the part (e.g.
	-- under a wrapping Model) rather than inside it.
	local found = findAccessoryAmong(part:GetChildren())
	if found then
		return found
	end

	if part.Parent then
		found = findAccessoryAmong(part.Parent:GetChildren())
		if found then
			return found
		end
	end

	return nil
end

local function findAttachmentByName(root, name)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("Attachment") and descendant.Name == name then
			return descendant
		end
	end
	return nil
end

local function findWaistAttachment(root)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("Attachment") and descendant.Name:find("Waist") then
			return descendant
		end
	end
	return nil
end

-- Welds the accessory's Handle directly to the matching attachment on the
-- character, instead of relying on Humanoid:AddAccessory(). That built-in
-- call requires the Handle's Attachment name to exactly match an attachment
-- already on the character rig (e.g. "WaistCenterAttachment") -- if it's
-- misnamed even slightly, AddAccessory silently parents the accessory
-- without welding it, leaving it invisible wherever it was cloned from
-- instead of on the player. This does the same positioning manually, with a
-- name-mismatch fallback, so a typo on the Handle's attachment can't break it.
local function equipAccessory(character, accessoryClone)
	local handle = accessoryClone:FindFirstChild("Handle")
	if not (handle and handle:IsA("BasePart")) then
		warn("[DisguisePart] '" .. accessoryClone.Name .. "' has no Handle part; cannot equip it.")
		return
	end

	local sourceAttachment = handle:FindFirstChildWhichIsA("Attachment")
	if not sourceAttachment then
		warn("[DisguisePart] '" .. accessoryClone.Name .. "'.Handle has no Attachment; cannot equip it.")
		return
	end

	local targetAttachment = findAttachmentByName(character, sourceAttachment.Name) or findWaistAttachment(character)
	if not targetAttachment then
		warn("[DisguisePart] No matching attachment found on the character for '" .. sourceAttachment.Name .. "'.")
		return
	end

	handle.CFrame = targetAttachment.WorldCFrame * sourceAttachment.CFrame:Inverse()

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = targetAttachment.Parent
	weld.Parent = handle

	accessoryClone.Parent = character
	print("[DisguisePart] Equipped '" .. accessoryClone.Name .. "' on '" .. character.Name .. "', welded to '" .. targetAttachment.Parent:GetFullName() .. "'.")
end

local function applyDisguise(character, humanoid)
	-- Remove all current accessories.
	for _, item in ipairs(character:GetChildren()) do
		if item:IsA("Accessory") then
			item:Destroy()
		end
	end

	-- Remove classic clothing so it doesn't render over the new body color.
	local shirt = character:FindFirstChildOfClass("Shirt")
	if shirt then
		shirt:Destroy()
	end

	local pants = character:FindFirstChildOfClass("Pants")
	if pants then
		pants:Destroy()
	end

	-- Recolor every body part.
	for _, item in ipairs(character:GetChildren()) do
		if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" then
			item.Color = BODY_COLOR
		end
	end

	-- Keep the legacy BodyColors object (used by some R6 rigs) in sync too.
	local bodyColors = character:FindFirstChildOfClass("BodyColors")
	if bodyColors then
		bodyColors.HeadColor3 = BODY_COLOR
		bodyColors.TorsoColor3 = BODY_COLOR
		bodyColors.LeftArmColor3 = BODY_COLOR
		bodyColors.RightArmColor3 = BODY_COLOR
		bodyColors.LeftLegColor3 = BODY_COLOR
		bodyColors.RightLegColor3 = BODY_COLOR
	end

	-- Make the head invisible.
	local head = character:FindFirstChild("Head")
	if head then
		head.Transparency = 1
		local face = head:FindFirstChild("face")
		if face and face:IsA("Decal") then
			face.Transparency = 1
		end
	end

	-- Equip the new disguise accessory, if one is set up under this part.
	local accessoryTemplate = findDisguiseAccessory()
	if accessoryTemplate then
		equipAccessory(character, accessoryTemplate:Clone())
	else
		warn("[DisguisePart] No Accessory found as a child of '" .. part:GetFullName() .. "' or its parent. Make sure chezburgerBody is placed directly under one of those.")
	end
end

part.Touched:Connect(function(otherPart)
	local character = otherPart:FindFirstAncestorOfClass("Model")
	if not character then
		return
	end

	local player = game.Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	if debounce[player] then
		return
	end
	debounce[player] = true

	applyDisguise(character, humanoid)

	task.wait(1)
	debounce[player] = nil
end)
