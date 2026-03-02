local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TitleConfig = require(Shared.TitleConfig)
local Theme = require(Shared.Theme)

local ProfileService = nil

local TitleService = {}

-- Track current title per player to skip redundant updates
local currentTitles: { [number]: string } = {}

local function createBillboard(head: BasePart, titleName: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TitleBillboard"
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.MaxDistance = 50
	billboard.AlwaysOnTop = false
	billboard.Size = UDim2.new(0, 200, 0, 30)
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.Name = "TitleLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = titleName
	label.Font = Theme.Font.heading
	label.TextColor3 = Theme.Colors.headerGold
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextSize = 18
	label.Parent = billboard

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
		createBillboard(head, titleName)
	end
end

function TitleService.Init(profileService)
	ProfileService = profileService

	local function onCharacterAdded(player: Player)
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
