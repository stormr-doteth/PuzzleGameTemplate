local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local REFRESH_INTERVAL = 60
local MAX_ENTRIES = 100

-- Board configurations
local BOARDS = {
	{
		modelName = "PhysicalLeaderboard",
		datastoreName = "Leaderboard_PiecesPlaced",
		headerText = "PIECES PLACED",
		profileKey = "TotalPiecesPlaced",
		formatValue = function(v) return tostring(v) end,
	},
	{
		modelName = "PlaytimeLeaderboard",
		datastoreName = "Leaderboard_Playtime",
		headerText = "PLAY TIME",
		profileKey = "TotalPlayTime",
		formatValue = function(v)
			local totalSeconds = math.floor(v)
			local days = math.floor(totalSeconds / 86400)
			local hours = math.floor((totalSeconds % 86400) / 3600)
			local minutes = math.floor((totalSeconds % 3600) / 60)
			if days > 0 then
				return string.format("%dd %dh %dm", days, hours, minutes)
			elseif hours > 0 then
				return string.format("%dh %dm", hours, minutes)
			else
				return string.format("%dm", minutes)
			end
		end,
	},
}

-- Runtime state per board
local boards: { any } = {}

local nameCache: { [number]: string } = {}

local PhysicalLeaderboardService = {}

local function getDisplayName(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end

	local displayName = "Player"
	pcall(function()
		local player = Players:GetPlayerByUserId(userId)
		if player then
			displayName = player.DisplayName
		else
			displayName = Players:GetNameFromUserIdAsync(userId)
		end
	end)

	nameCache[userId] = displayName
	return displayName
end

local function getRankColor(rank: number): Color3
	if rank == 1 then
		return Color3.fromRGB(255, 215, 0) -- Gold
	elseif rank == 2 then
		return Color3.fromRGB(192, 192, 192) -- Silver
	elseif rank == 3 then
		return Color3.fromRGB(205, 127, 50) -- Bronze
	else
		return Color3.fromRGB(255, 255, 255) -- White
	end
end

local function refreshBoard(board: any)
	if not board.scrollingFrame or not board.template then
		return
	end

	local success, pages = pcall(function()
		return board.store:GetSortedAsync(false, MAX_ENTRIES)
	end)

	if not success or not pages then
		warn("[PhysicalLeaderboardService] Failed to fetch leaderboard data for " .. board.config.modelName)
		return
	end

	-- Clear existing entries
	for _, child in board.scrollingFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local rank = 0
	local entries = pages:GetCurrentPage()
	for _, entry in entries do
		rank += 1
		local userId = tonumber(entry.key)
		if not userId then
			continue
		end

		local score = entry.value
		local displayName = getDisplayName(userId)
		local color = getRankColor(rank)

		local row = board.template:Clone()
		row.Name = "Entry_" .. rank
		row.LayoutOrder = rank
		row.Visible = true

		local placeLabel = row:FindFirstChild("PlaceLabel")
		if placeLabel then
			placeLabel.Text = tostring(rank)
			placeLabel.TextColor3 = color
		end

		local imageLabel = row:FindFirstChild("ImageLabel")
		if imageLabel then
			pcall(function()
				imageLabel.Image = Players:GetUserThumbnailAsync(
					userId,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size60x60
				)
			end)
		end

		local nameLabel = row:FindFirstChild("NameLabel")
		if nameLabel then
			nameLabel.Text = displayName
			nameLabel.TextColor3 = color
		end

		local winsLabel = row:FindFirstChild("WinsLabel")
		if winsLabel then
			winsLabel.Text = board.config.formatValue(score)
			winsLabel.TextColor3 = color
		end

		row.Parent = board.scrollingFrame
	end
end

local function setupBoard(config: any, leaderboardModel: Model): any?
	-- Find the part with the SurfaceGui
	local part = leaderboardModel:FindFirstChild("Leaderboard", true)
	if part then
		part = part:FindFirstChild("WeeklyWinsLeaderboard")
	end
	if not part then
		-- Fallback: search for any part with a SurfaceGui
		for _, desc in leaderboardModel:GetDescendants() do
			if desc:IsA("SurfaceGui") then
				part = desc.Parent
				break
			end
		end
	end

	if not part then
		warn("[PhysicalLeaderboardService] Could not find leaderboard part for " .. config.modelName)
		return nil
	end

	local surfaceGui = part:FindFirstChildWhichIsA("SurfaceGui")
	if not surfaceGui then
		warn("[PhysicalLeaderboardService] Could not find SurfaceGui for " .. config.modelName)
		return nil
	end

	-- Delete old script if present
	local oldScript = surfaceGui:FindFirstChild("WeeklyLeaderboardScriptClient")
	if oldScript then
		oldScript:Destroy()
	end

	local scrollingFrame = surfaceGui:FindFirstChildWhichIsA("ScrollingFrame")

	-- Find template from Folder inside the part, or from SurfaceGui children
	local template = nil
	local folder = part:FindFirstChildWhichIsA("Folder")
	if folder then
		template = folder:FindFirstChild("Template") or folder:FindFirstChild("EntryTemplate")
	end
	if not template then
		-- Search SurfaceGui descendants for a template
		for _, desc in surfaceGui:GetDescendants() do
			if desc:IsA("Frame") and (desc.Name == "EntryTemplate" or desc.Name == "Template") then
				template = desc
				break
			end
		end
	end

	if not template then
		warn("[PhysicalLeaderboardService] Could not find entry template for " .. config.modelName)
		return nil
	end

	-- Make sure template is not visible in the board
	template.Visible = false

	-- Update header text
	local headerFrame = surfaceGui:FindFirstChild("Frame")
	if headerFrame then
		local headerLabel = headerFrame:FindFirstChildWhichIsA("TextLabel")
		if headerLabel then
			headerLabel.Text = config.headerText
		end
	end

	return {
		config = config,
		store = DataStoreService:GetOrderedDataStore(config.datastoreName),
		surfaceGui = surfaceGui,
		scrollingFrame = scrollingFrame,
		template = template,
	}
end

function PhysicalLeaderboardService.submitScore(profileKey: string, userId: number, value: number)
	for _, board in boards do
		if board.config.profileKey == profileKey then
			local intValue = math.floor(value)
			if intValue > 0 then
				pcall(function()
					board.store:SetAsync(tostring(userId), intValue)
				end)
			end
		end
	end
end

function PhysicalLeaderboardService.submitAllScores(userId: number, profileData: any)
	for _, board in boards do
		local value = profileData[board.config.profileKey]
		if value and value > 0 then
			local intValue = math.floor(value)
			pcall(function()
				board.store:SetAsync(tostring(userId), intValue)
			end)
		end
	end
end

function PhysicalLeaderboardService.Init(leaderboardsFolder: Folder)
	for _, config in BOARDS do
		local model = leaderboardsFolder:FindFirstChild(config.modelName)
		if not model then
			warn("[PhysicalLeaderboardService] Model not found: " .. config.modelName)
			continue
		end

		local board = setupBoard(config, model)
		if board then
			table.insert(boards, board)

			-- Start refresh loop for this board
			task.spawn(function()
				while true do
					pcall(refreshBoard, board)
					task.wait(REFRESH_INTERVAL)
				end
			end)

			print("[PhysicalLeaderboardService] Initialized board: " .. config.modelName)
		end
	end
end

return PhysicalLeaderboardService
