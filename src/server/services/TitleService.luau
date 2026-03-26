local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TitleConfig = require(Shared.TitleConfig)
local Theme = require(Shared.Theme)
local MonetizationConfig = require(Shared.MonetizationConfig)

local ProfileService = nil

local TitleService = {}

-- Rainbow gradient color sequence for starter pack buyers
local RAINBOW_SEQUENCE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 180, 50)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 255, 80)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 120)),
	ColorSequenceKeypoint.new(0.67, Color3.fromRGB(80, 180, 255)),
	ColorSequenceKeypoint.new(0.83, Color3.fromRGB(180, 80, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 200)),
})

-- Track current title per player to skip redundant updates
local currentTitles: { [number]: string } = {}

-- Server-owned container for all overhead BillboardGuis (anti-exploit)
local overheadFolder: Folder = nil

-- Per-player billboard tracking for cleanup and updates
local playerBillboards: { [number]: { title: BillboardGui?, name: BillboardGui? } } = {}

-- Per-player cleanup connections
local playerConnections: { [number]: { RBXScriptConnection } } = {}

local VIP_GOLD = Color3.fromRGB(255, 215, 0)

local function hasVIP(player: Player): boolean
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, MonetizationConfig.GAME_PASSES.VIP.id)
	end)
	return ok and owns
end

-- Protect a TextLabel property from client modification
local function protectProperty(label: TextLabel, property: string, expectedValue: any): RBXScriptConnection
	return label:GetPropertyChangedSignal(property):Connect(function()
		if label[property] ~= expectedValue then
			label[property] = expectedValue
		end
	end)
end

local function cleanupPlayer(userId: number)
	local billboards = playerBillboards[userId]
	if billboards then
		if billboards.title then
			billboards.title:Destroy()
		end
		if billboards.name then
			billboards.name:Destroy()
		end
		playerBillboards[userId] = nil
	end

	local connections = playerConnections[userId]
	if connections then
		for _, conn in connections do
			conn:Disconnect()
		end
		playerConnections[userId] = nil
	end
end

local function createBillboard(head: BasePart, titleName: string, player: Player)
	local userId = player.UserId

	-- Clean up any existing billboards first (respawn case)
	cleanupPlayer(userId)

	local connections: { RBXScriptConnection } = {}

	-- Check if player has purchased starter pack for rainbow title
	local hasStarterPack = false
	if ProfileService then
		local profileData = ProfileService.GetData(player)
		if profileData then
			hasStarterPack = profileData.StarterPack_Purchased == true
		end
	end

	-- Title billboard (rank/title) — scale-based sizing to stay consistent with zoom
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TitleBillboard_" .. userId
	billboard.Adornee = head
	billboard.StudsOffset = Vector3.new(0, 2.8, 0)
	billboard.MaxDistance = 50
	billboard.AlwaysOnTop = false
	billboard.Size = UDim2.new(5, 0, 0.4, 0)
	billboard.Parent = overheadFolder

	local label = Instance.new("TextLabel")
	label.Name = "TitleLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = titleName
	label.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
	label.TextColor3 = if hasStarterPack then Color3.fromRGB(255, 255, 255) else Theme.Colors.headerGold
	label.TextScaled = true
	label.Parent = billboard

	-- Add rainbow gradient for starter pack owners
	if hasStarterPack then
		local gradient = Instance.new("UIGradient")
		gradient.Color = RAINBOW_SEQUENCE
		gradient.Parent = label
	end

	-- Protect title label properties from client modification
	local titleColor = if hasStarterPack then Color3.fromRGB(255, 255, 255) else Theme.Colors.headerGold
	table.insert(connections, protectProperty(label, "Text", titleName))
	table.insert(connections, protectProperty(label, "TextColor3", titleColor))

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Color3.fromRGB(0, 0, 0)
	titleStroke.Thickness = 3
	titleStroke.Transparency = 0
	titleStroke.Parent = label

	-- Name billboard (display name + VIP tag)
	local isVIP = hasVIP(player)
	local displayName = player.DisplayName
	local nameText = if isVIP then "[VIP] " .. displayName else displayName
	local nameColor = if isVIP then VIP_GOLD else Theme.Colors.textPrimary

	local nameBillboard = Instance.new("BillboardGui")
	nameBillboard.Name = "NameBillboard_" .. userId
	nameBillboard.Adornee = head
	nameBillboard.StudsOffset = Vector3.new(0, 2, 0)
	nameBillboard.MaxDistance = 50
	nameBillboard.AlwaysOnTop = false
	nameBillboard.Size = UDim2.new(5, 0, 0.4, 0)
	nameBillboard.Parent = overheadFolder

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.fromScale(1, 1)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = nameText
	nameLabel.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
	nameLabel.TextColor3 = nameColor
	nameLabel.TextScaled = true
	nameLabel.Parent = nameBillboard

	-- Protect name label properties from client modification
	table.insert(connections, protectProperty(nameLabel, "Text", nameText))
	table.insert(connections, protectProperty(nameLabel, "TextColor3", nameColor))

	local nameStroke = Instance.new("UIStroke")
	nameStroke.Color = Color3.fromRGB(0, 0, 0)
	nameStroke.Thickness = 3
	nameStroke.Transparency = 0
	nameStroke.Parent = nameLabel

	playerBillboards[userId] = { title = billboard, name = nameBillboard }
	playerConnections[userId] = connections

	return billboard
end

-- Update the protected value for a label property and refresh the protection connection
local function updateProtectedText(userId: number, label: TextLabel, property: string, newValue: any)
	-- Disconnect old protection for this property
	local connections = playerConnections[userId]
	if not connections then return end

	-- Update the property directly (this will fire the signal but we replace protection after)
	label[property] = newValue

	-- Replace all connections with fresh ones (simpler than tracking individual ones)
	-- We'll rebuild connections when needed in UpdateTitle
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

	local userId = player.UserId
	local billboards = playerBillboards[userId]

	-- Check starter pack for rainbow
	local hasStarterPack = false
	if ProfileService then
		local profileData = ProfileService.GetData(player)
		if profileData then
			hasStarterPack = profileData.StarterPack_Purchased == true
		end
	end
	local titleColor = if hasStarterPack then Color3.fromRGB(255, 255, 255) else Theme.Colors.headerGold

	if billboards and billboards.title then
		local label = billboards.title:FindFirstChild("TitleLabel")
		if label then
			-- Disconnect old protections and set up new ones
			local oldConns = playerConnections[userId]
			if oldConns then
				for _, conn in oldConns do
					conn:Disconnect()
				end
			end

			label.Text = titleName
			label.TextColor3 = titleColor

			-- Add/remove rainbow gradient
			local existingGradient = label:FindFirstChildOfClass("UIGradient")
			if hasStarterPack and not existingGradient then
				local gradient = Instance.new("UIGradient")
				gradient.Color = RAINBOW_SEQUENCE
				gradient.Parent = label
			elseif not hasStarterPack and existingGradient then
				existingGradient:Destroy()
			end

			-- Rebuild all protections
			local connections: { RBXScriptConnection } = {}
			table.insert(connections, protectProperty(label, "Text", titleName))
			table.insert(connections, protectProperty(label, "TextColor3", titleColor))

			-- Re-protect name label too
			if billboards.name then
				local nameLabel = billboards.name:FindFirstChild("NameLabel")
				if nameLabel then
					table.insert(connections, protectProperty(nameLabel, "Text", nameLabel.Text))
					table.insert(connections, protectProperty(nameLabel, "TextColor3", nameLabel.TextColor3))
				end
			end

			playerConnections[userId] = connections
		end
	else
		createBillboard(head, titleName, player)
	end
end

-- Refresh name billboard text/color and rebuild protections
local function refreshNameBillboard(player: Player, nameText: string, nameColor: Color3)
	local userId = player.UserId
	local billboards = playerBillboards[userId]
	if not billboards or not billboards.name then return end

	local nameLabel = billboards.name:FindFirstChild("NameLabel")
	if not nameLabel then return end

	-- Disconnect old protections
	local oldConns = playerConnections[userId]
	if oldConns then
		for _, conn in oldConns do
			conn:Disconnect()
		end
	end

	nameLabel.Text = nameText
	nameLabel.TextColor3 = nameColor

	-- Rebuild all protections
	local connections: { RBXScriptConnection } = {}
	table.insert(connections, protectProperty(nameLabel, "Text", nameText))
	table.insert(connections, protectProperty(nameLabel, "TextColor3", nameColor))

	-- Re-protect title label too
	if billboards.title then
		local titleLabel = billboards.title:FindFirstChild("TitleLabel")
		if titleLabel then
			table.insert(connections, protectProperty(titleLabel, "Text", titleLabel.Text))
			table.insert(connections, protectProperty(titleLabel, "TextColor3", titleLabel.TextColor3))
		end
	end

	playerConnections[userId] = connections
end

-- Refresh title appearance (e.g., after starter pack purchase adds rainbow)
function TitleService.RefreshTitleAppearance(player: Player)
	local userId = player.UserId
	-- Force re-create by clearing current title cache
	currentTitles[userId] = nil

	local profileData = if ProfileService then ProfileService.GetData(player) else nil
	if profileData then
		TitleService.UpdateTitle(player, profileData.PuzzlesCompletedByDifficulty or {})
	end
end

function TitleService.Init(profileService)
	ProfileService = profileService

	-- Create server-owned container for overhead BillboardGuis
	overheadFolder = Instance.new("Folder")
	overheadFolder.Name = "OverheadGuis"
	overheadFolder.Parent = workspace

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
		-- Set VIP attribute (auto-replicates to all clients for chat tags)
		player:SetAttribute("IsVIP", hasVIP(player))

		if player.Character then
			onCharacterAdded(player)
		end
		player.CharacterAdded:Connect(function()
			-- Clean up old billboards from previous character
			cleanupPlayer(player.UserId)
			currentTitles[player.UserId] = nil
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

	-- Update VIP attribute and billboard if someone buys VIP mid-session
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
		if wasPurchased and gamePassId == MonetizationConfig.GAME_PASSES.VIP.id then
			player:SetAttribute("IsVIP", true)
			refreshNameBillboard(player, "[VIP] " .. player.DisplayName, VIP_GOLD)
		end
	end)

	-- Clean up on leave
	Players.PlayerRemoving:Connect(function(player)
		currentTitles[player.UserId] = nil
		cleanupPlayer(player.UserId)
	end)
end

return TitleService
