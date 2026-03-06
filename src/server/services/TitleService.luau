local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TitleConfig = require(Shared.TitleConfig)
local Theme = require(Shared.Theme)
local MonetizationConfig = require(Shared.MonetizationConfig)

local ProfileService = nil

local TitleService = {}

-- Track current title per player to skip redundant updates
local currentTitles: { [number]: string } = {}

local VIP_GOLD = Color3.fromRGB(255, 215, 0)

local function hasVIP(player: Player): boolean
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, MonetizationConfig.GAME_PASSES.VIP.id)
	end)
	return ok and owns
end

local function createBillboard(head: BasePart, titleName: string, player: Player)
	-- Title billboard (rank/title) — scale-based sizing to stay consistent with zoom
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TitleBillboard"
	billboard.StudsOffset = Vector3.new(0, 2.8, 0)
	billboard.MaxDistance = 50
	billboard.AlwaysOnTop = false
	billboard.Size = UDim2.new(5, 0, 0.4, 0)
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.Name = "TitleLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = titleName
	label.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
	label.TextColor3 = Theme.Colors.headerGold
	label.TextScaled = true
	label.Parent = billboard

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Color3.fromRGB(0, 0, 0)
	titleStroke.Thickness = 3
	titleStroke.Transparency = 0
	titleStroke.Parent = label

	-- Name billboard (display name + VIP tag)
	local isVIP = hasVIP(player)
	local displayName = player.DisplayName

	local nameBillboard = Instance.new("BillboardGui")
	nameBillboard.Name = "NameBillboard"
	nameBillboard.StudsOffset = Vector3.new(0, 2, 0)
	nameBillboard.MaxDistance = 50
	nameBillboard.AlwaysOnTop = false
	nameBillboard.Size = UDim2.new(5, 0, 0.4, 0)
	nameBillboard.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.fromScale(1, 1)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = if isVIP then "[VIP] " .. displayName else displayName
	nameLabel.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
	nameLabel.TextColor3 = if isVIP then VIP_GOLD else Theme.Colors.textPrimary
	nameLabel.TextScaled = true
	nameLabel.Parent = nameBillboard

	local nameStroke = Instance.new("UIStroke")
	nameStroke.Color = Color3.fromRGB(0, 0, 0)
	nameStroke.Thickness = 3
	nameStroke.Transparency = 0
	nameStroke.Parent = nameLabel

	return billboard
end

function TitleService.UpdateTitle(player: Player, puzzlesCompletedByDifficulty: { [string]: number })
	local titleName = TitleConfig.getTitleFromCompletions(puzzlesCompletedByDifficulty or {})

	-- Skip if title hasn't changed
	if currentTitles[player.UserId] == titleName then
		return
	end
	currentTitles[player.UserId] = titleName

	local character = player.Character
	if not character then return end

	local head = character:FindFirstChild("Head")
	if not head then return end

	-- Find or create billboard
	local billboard = head:FindFirstChild("TitleBillboard")
	if billboard then
		local label = billboard:FindFirstChild("TitleLabel")
		if label then
			label.Text = titleName
		end
	else
		createBillboard(head, titleName, player)
	end

	-- Refresh name billboard (in case DisplayName or VIP status changed)
	local nameBillboard = head:FindFirstChild("NameBillboard")
	if nameBillboard then
		local nameLabel = nameBillboard:FindFirstChild("NameLabel")
		if nameLabel then
			local isVIP = hasVIP(player)
			local displayName = player.DisplayName
			nameLabel.Text = if isVIP then "[VIP] " .. displayName else displayName
			nameLabel.TextColor3 = if isVIP then VIP_GOLD else Theme.Colors.textPrimary
		end
	end
end

function TitleService.Init(profileService)
	ProfileService = profileService

	local function onCharacterAdded(player: Player)
		-- Hide default Roblox nametag
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
		end

		local profileData = ProfileService.GetData(player)
		if profileData then
			TitleService.UpdateTitle(player, profileData.PuzzlesCompletedByDifficulty or {})
		end
	end

	local function onPlayerAdded(player: Player)
		if player.Character then
			onCharacterAdded(player)
		end
		player.CharacterAdded:Connect(function()
			-- Wait briefly for Head to load
			task.wait(0.5)
			onCharacterAdded(player)
		end)
	end

	-- Handle existing players (studio fast-reload)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)

	-- Clean up on leave
	Players.PlayerRemoving:Connect(function(player)
		currentTitles[player.UserId] = nil
	end)
end

return TitleService
