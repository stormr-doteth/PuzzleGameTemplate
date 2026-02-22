local CaptureService = game:GetService("CaptureService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)

local MenuScreen = require(script.Parent.components.MenuScreen)
local PuzzleBoard = require(script.Parent.components.PuzzleBoard)
local CompleteScreen = require(script.Parent.components.CompleteScreen)
local RoomLobbyScreen = require(script.Parent.components.RoomLobbyScreen)

-- SeatingService loaded optionally
local SeatingService = nil
pcall(function()
	SeatingService = require(script.Parent.Parent.services.SeatingService)
end)

-- XPBar loaded optionally (created in Phase 2)
local XPBar = nil
pcall(function()
	XPBar = require(script.Parent.components.XPBar)
end)

type GameState = "walking" | "menu" | "playing" | "complete" | "admiring" | "room_lobby" | "room_playing" | "room_complete"

local function App()
	local gameState, setGameState = React.useState("walking" :: GameState)
	local rows, setRows = React.useState(3)
	local cols, setCols = React.useState(3)
	local imageAssetId, setImageAssetId = React.useState("")
	local imageId, setImageId = React.useState("")
	local difficultyId, setDifficultyId = React.useState("6x6")
	local completionTime, setCompletionTime = React.useState(0)
	local rewardData, setRewardData = React.useState(nil :: any)

	-- Saved puzzles state
	local savedPuzzles, setSavedPuzzles = React.useState({} :: { any })
	local resumeState, setResumeState = React.useState(nil :: any)

	-- Multiplayer room state
	local roomInfo, setRoomInfo = React.useState(nil :: any)
	local roomPuzzleDef, setRoomPuzzleDef = React.useState(nil :: any)
	local roomInitialPieces, setRoomInitialPieces = React.useState(nil :: any)
	local roomConfig, setRoomConfig = React.useState(nil :: any)

	-- Admire mode tracking for multiplayer
	local admireIsMultiplayer, setAdmireIsMultiplayer = React.useState(false)

	-- Seating state
	local seatingInfo, setSeatingInfo = React.useState(nil :: any)

	-- Player data state (populated by remotes in Phase 2)
	local playerData, setPlayerData = React.useState(nil :: {
		level: number,
		xp: number,
		cash: number,
		unlockedImages: { [string]: boolean },
		personalBests: { [string]: number },
		equippedBoardSkin: string?,
		equippedConfettiStyle: string?,
		equippedBadge: string?,
		hintsRemaining: number?,
		ownedBoardSkins: { [string]: boolean }?,
		ownedConfettiStyles: { [string]: boolean }?,
		ownedBadges: { [string]: boolean }?,
		totalPuzzlesCompleted: number?,
		totalPlayTime: number?,
		totalPiecesPlaced: number?,
		puzzlesCompletedByDifficulty: { [string]: number }?,
	}?)

	-- Try to fetch initial player data via GetPlayerData remote
	React.useEffect(function()
		task.spawn(function()
			local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
			if not remotes then return end
			local getPlayerData = remotes:FindFirstChild("GetPlayerData")
			if not getPlayerData or not getPlayerData:IsA("RemoteFunction") then return end

			local ok, data = pcall(function()
				return getPlayerData:InvokeServer()
			end)
			if ok and data then
				setPlayerData(data)
			end

			-- Load saved puzzles
			local loadSaved = remotes:FindFirstChild("LoadSavedPuzzles")
			if loadSaved and loadSaved:IsA("RemoteFunction") then
				local ok2, saves = pcall(function() return loadSaved:InvokeServer() end)
				if ok2 and saves then
					setSavedPuzzles(saves)
				end
			end
		end)
	end, {})

	-- Listen for XP awards from server
	React.useEffect(function()
		local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
		if not remotes then return end
		local xpAwarded = remotes:FindFirstChild("XPAwarded")
		if not xpAwarded or not xpAwarded:IsA("RemoteEvent") then return end

		local conn = xpAwarded.OnClientEvent:Connect(function(data)
			setRewardData(data)
			-- Update local player data
			if data then
				setPlayerData(function(prev)
					if not prev then return prev end
					local updated = table.clone(prev)
					if data.newLevel then
						updated.level = data.newLevel
					end
					if data.xpGained then
						updated.xp = (updated.xp or 0) + data.xpGained
					end
					if data.cashGained then
						updated.cash = (updated.cash or 0) + data.cashGained
					end
					if data.unlockedImages then
						for _, imgId in data.unlockedImages do
							updated.unlockedImages[imgId] = true
						end
					end
					if data.isPersonalBest and completionTime > 0 then
						local bestKey = imageId .. "_" .. difficultyId
						updated.personalBests[bestKey] = completionTime
					end
					updated.totalPuzzlesCompleted = (updated.totalPuzzlesCompleted or 0) + 1
					updated.totalPlayTime = (updated.totalPlayTime or 0) + completionTime
					updated.totalPiecesPlaced = (updated.totalPiecesPlaced or 0) + (rows * cols)
					if not updated.puzzlesCompletedByDifficulty then
						updated.puzzlesCompletedByDifficulty = {}
					else
						updated.puzzlesCompletedByDifficulty = table.clone(updated.puzzlesCompletedByDifficulty)
					end
					updated.puzzlesCompletedByDifficulty[difficultyId] = (updated.puzzlesCompletedByDifficulty[difficultyId] or 0) + 1
					return updated
				end)
			end
		end)

		return function()
			conn:Disconnect()
		end
	end, {} :: { any })

	-- Listen for seating events from server
	React.useEffect(function()
		local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
		if not remotes then return end

		local connections: { RBXScriptConnection } = {}

		local playerSeated = remotes:FindFirstChild("PlayerSeated")
		if playerSeated and playerSeated:IsA("RemoteEvent") then
			table.insert(connections, playerSeated.OnClientEvent:Connect(function(data)
				setSeatingInfo(data)
				if SeatingService then
					SeatingService.SetSeated(data)
					SeatingService.TransitionCameraToTable(data.tableId)
				end

				if data.tableType == "single" then
					setGameState("menu")
				elseif data.tableType == "multi" then
					-- Fetch room info via GetTableInfo
					task.spawn(function()
						local getTableInfo = remotes:FindFirstChild("GetTableInfo")
						if getTableInfo and getTableInfo:IsA("RemoteFunction") then
							local ok, result = pcall(function() return getTableInfo:InvokeServer(data.tableId) end)
							if ok and result and result.roomInfo then
								setRoomInfo(result.roomInfo)
								setRoomConfig(result.roomInfo.config)
								setGameState("room_lobby")
							end
						end
					end)
				end
			end))
		end

		local playerUnseated = remotes:FindFirstChild("PlayerUnseated")
		if playerUnseated and playerUnseated:IsA("RemoteEvent") then
			table.insert(connections, playerUnseated.OnClientEvent:Connect(function()
				setSeatingInfo(nil)
				if SeatingService then
					SeatingService.ClearSeated()
					SeatingService.RestoreCamera()
				end

				-- Clean up room state if in multiplayer
				setRoomInfo(nil)
				setRoomPuzzleDef(nil)
				setRoomInitialPieces(nil)
				setRoomConfig(nil)
				setGameState("walking")
			end))
		end

		return function()
			for _, conn in connections do
				conn:Disconnect()
			end
		end
	end, {} :: { any })

	local function onStart(selectedRows: number, selectedCols: number, selectedImageAssetId: string, selectedImageId: string, selectedDifficultyId: string)
		setRows(selectedRows)
		setCols(selectedCols)
		setImageAssetId(selectedImageAssetId)
		setImageId(selectedImageId)
		setDifficultyId(selectedDifficultyId)
		setCompletionTime(0)
		setRewardData(nil)
		setResumeState(nil)
		setGameState("playing")
	end

	local function onComplete(elapsedSeconds: number)
		setCompletionTime(elapsedSeconds)
		setGameState("complete")

		-- Fire PuzzleCompleted to server
		task.spawn(function()
			local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
			if not remotes then return end
			local puzzleCompleted = remotes:FindFirstChild("PuzzleCompleted")
			if not puzzleCompleted or not puzzleCompleted:IsA("RemoteEvent") then return end

			puzzleCompleted:FireServer({
				imageId = imageId,
				difficultyId = difficultyId,
				completionTime = elapsedSeconds,
			})
		end)
	end

	local function onBackToMenu(saveData: any)
		task.spawn(function()
			local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
			if not remotes then return end
			local savePuzzle = remotes:FindFirstChild("SavePuzzle")
			if savePuzzle and savePuzzle:IsA("RemoteFunction") then
				pcall(function() savePuzzle:InvokeServer(saveData) end)
			end
			-- Refresh saved puzzles list
			local loadSaved = remotes:FindFirstChild("LoadSavedPuzzles")
			if loadSaved and loadSaved:IsA("RemoteFunction") then
				local ok, saves = pcall(function() return loadSaved:InvokeServer() end)
				if ok and saves then setSavedPuzzles(saves) end
			end
		end)
		setResumeState(nil)
		setGameState("menu")
	end

	local function onGiveUp()
		setResumeState(nil)
		if seatingInfo then
			setGameState("menu")
		else
			setGameState("walking")
		end
	end

	local function onResume(slotIndex: number)
		local save = savedPuzzles[slotIndex]
		if not save then return end
		setRows(save.rows)
		setCols(save.cols)
		setImageAssetId(save.imageAssetId)
		setImageId(save.imageId)
		setDifficultyId(save.difficultyId)
		setCompletionTime(0)
		setRewardData(nil)
		setResumeState(save)
		setGameState("playing")
	end

	local function onDeleteSave(slotIndex: number)
		task.spawn(function()
			local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
			if not remotes then return end
			local deleteSaved = remotes:FindFirstChild("DeleteSavedPuzzle")
			if deleteSaved and deleteSaved:IsA("RemoteFunction") then
				pcall(function() deleteSaved:InvokeServer(slotIndex) end)
			end
			-- Refresh list
			local loadSaved = remotes:FindFirstChild("LoadSavedPuzzles")
			if loadSaved and loadSaved:IsA("RemoteFunction") then
				local ok, saves = pcall(function() return loadSaved:InvokeServer() end)
				if ok and saves then setSavedPuzzles(saves) end
			end
		end)
	end

	-- === Multiplayer handlers ===
	local function onCreateRoom()
		task.spawn(function()
			local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
			if not remotes then return end
			local createRoom = remotes:FindFirstChild("CreateRoom")
			if not createRoom or not createRoom:IsA("RemoteFunction") then return end

			local ok, result = pcall(function() return createRoom:InvokeServer() end)
			if ok and result then
				if result.error then
					warn("[App] CreateRoom error:", result.error)
					return
				end
				setRoomInfo(result.roomInfo)
				setRoomConfig(result.roomInfo and result.roomInfo.config)
				setGameState("room_lobby")
			end
		end)
	end

	local function onJoinRoom(roomCode: string)
		task.spawn(function()
			local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
			if not remotes then return end
			local joinRemote = remotes:FindFirstChild("JoinRoom")
			if not joinRemote or not joinRemote:IsA("RemoteFunction") then return end

			local ok, result = pcall(function() return joinRemote:InvokeServer(roomCode) end)
			if ok and result then
				if result.error then
					warn("[App] JoinRoom error:", result.error)
					return
				end
				setRoomInfo(result.roomInfo)
				setRoomConfig(result.roomInfo and result.roomInfo.config)
				setGameState("room_lobby")
			end
		end)
	end

	local function onLeaveRoom()
		task.spawn(function()
			local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
			if not remotes then return end
			local leaveRemote = remotes:FindFirstChild("LeaveRoom")
			if leaveRemote and leaveRemote:IsA("RemoteFunction") then
				pcall(function() leaveRemote:InvokeServer() end)
			end
		end)
		setRoomInfo(nil)
		setRoomPuzzleDef(nil)
		setRoomInitialPieces(nil)
		setRoomConfig(nil)
		if seatingInfo then
			setGameState("menu")
		else
			setGameState("walking")
		end
	end

	local function onConfigureRoom(config: any)
		task.spawn(function()
			local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
			if not remotes then return end
			local configRemote = remotes:FindFirstChild("ConfigureRoom")
			if configRemote and configRemote:IsA("RemoteFunction") then
				pcall(function() configRemote:InvokeServer(config) end)
			end
		end)
	end

	local function onStartRoom()
		task.spawn(function()
			local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
			if not remotes then return end
			local startRemote = remotes:FindFirstChild("StartRoom")
			if startRemote and startRemote:IsA("RemoteFunction") then
				local ok, result = pcall(function() return startRemote:InvokeServer() end)
				if ok and result and result.error then
					warn("[App] StartRoom error:", result.error)
				end
			end
		end)
	end

	-- Listen for multiplayer room events
	React.useEffect(function()
		local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
		if not remotes then return end

		local connections: { RBXScriptConnection } = {}

		-- RoomPlayerJoined
		local playerJoined = remotes:FindFirstChild("RoomPlayerJoined")
		if playerJoined and playerJoined:IsA("RemoteEvent") then
			table.insert(connections, playerJoined.OnClientEvent:Connect(function(data)
				setRoomInfo(function(prev)
					if not prev then return prev end
					local updated = table.clone(prev)
					updated.players = table.clone(updated.players)
					table.insert(updated.players, data.player)
					return updated
				end)
			end))
		end

		-- RoomPlayerLeft
		local playerLeft = remotes:FindFirstChild("RoomPlayerLeft")
		if playerLeft and playerLeft:IsA("RemoteEvent") then
			table.insert(connections, playerLeft.OnClientEvent:Connect(function(data)
				setRoomInfo(function(prev)
					if not prev then return prev end
					local updated = table.clone(prev)
					updated.players = {}
					for _, p in prev.players do
						if p.userId ~= data.userId then
							local playerCopy = table.clone(p)
							if data.newHostUserId and p.userId == data.newHostUserId then
								playerCopy.isHost = true
								updated.hostUserId = data.newHostUserId
							end
							table.insert(updated.players, playerCopy)
						end
					end
					return updated
				end)
			end))
		end

		-- RoomConfigUpdated
		local configUpdated = remotes:FindFirstChild("RoomConfigUpdated")
		if configUpdated and configUpdated:IsA("RemoteEvent") then
			table.insert(connections, configUpdated.OnClientEvent:Connect(function(data)
				setRoomConfig(data.config)
				setRoomInfo(function(prev)
					if not prev then return prev end
					local updated = table.clone(prev)
					updated.config = data.config
					return updated
				end)
			end))
		end

		-- RoomPuzzleStarted
		local puzzleStarted = remotes:FindFirstChild("RoomPuzzleStarted")
		if puzzleStarted and puzzleStarted:IsA("RemoteEvent") then
			table.insert(connections, puzzleStarted.OnClientEvent:Connect(function(data)
				local config = data.config
				setRows(config.rows)
				setCols(config.cols)
				setImageAssetId(config.imageAssetId)
				setImageId(config.imageId)
				setDifficultyId(config.difficultyId)
				setRoomPuzzleDef(data.puzzleDef)
				setRoomInitialPieces(data.pieces)
				setRoomConfig(config)
				setCompletionTime(0)
				setRewardData(nil)
				setGameState("room_playing")
			end))
		end

		-- RoomCompleted
		local roomCompleted = remotes:FindFirstChild("RoomCompleted")
		if roomCompleted and roomCompleted:IsA("RemoteEvent") then
			table.insert(connections, roomCompleted.OnClientEvent:Connect(function()
				setGameState("room_complete")
			end))
		end

		-- RoomReturnedToLobby
		local roomReturnedToLobby = remotes:FindFirstChild("RoomReturnedToLobby")
		if roomReturnedToLobby and roomReturnedToLobby:IsA("RemoteEvent") then
			table.insert(connections, roomReturnedToLobby.OnClientEvent:Connect(function(data)
				setRoomPuzzleDef(nil)
				setRoomInitialPieces(nil)
				setRewardData(nil)
				setCompletionTime(0)
				if data.config then
					setRoomConfig(data.config)
				else
					setRoomConfig(nil)
				end
				setRoomInfo(function(prev)
					if not prev then return prev end
					local updated = table.clone(prev)
					updated.state = "lobby"
					updated.config = data.config
					return updated
				end)
				setGameState("room_lobby")
			end))
		end

		-- RoomDestroyed
		local roomDestroyed = remotes:FindFirstChild("RoomDestroyed")
		if roomDestroyed and roomDestroyed:IsA("RemoteEvent") then
			table.insert(connections, roomDestroyed.OnClientEvent:Connect(function()
				setRoomInfo(nil)
				setRoomPuzzleDef(nil)
				setRoomInitialPieces(nil)
				setRoomConfig(nil)
				-- Stay at menu if seated, otherwise walk
				setSeatingInfo(function(prev)
					if prev then
						setGameState("menu")
					else
						setGameState("walking")
					end
					return prev
				end)
			end))
		end

		return function()
			for _, conn in connections do
				conn:Disconnect()
			end
		end
	end, {} :: { any })

	local function onPlayAgain()
		-- Clean up room state if coming from multiplayer
		if roomInfo then
			task.spawn(function()
				local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
				if not remotes then return end
				local leaveRemote = remotes:FindFirstChild("LeaveRoom")
				if leaveRemote and leaveRemote:IsA("RemoteFunction") then
					pcall(function() leaveRemote:InvokeServer() end)
				end
			end)
			setRoomInfo(nil)
			setRoomPuzzleDef(nil)
			setRoomInitialPieces(nil)
			setRoomConfig(nil)
		end
		-- Stay at the table (menu) if seated, otherwise go to walking
		if seatingInfo then
			setGameState("menu")
		else
			setGameState("walking")
		end
		setRewardData(nil)
	end

	local function onRoomPlayAgain()
		task.spawn(function()
			local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
			if not remotes then return end
			local restartRemote = remotes:FindFirstChild("RestartRoom")
			if restartRemote and restartRemote:IsA("RemoteFunction") then
				local ok, result = pcall(function() return restartRemote:InvokeServer(true) end)
				if ok and result and result.error then
					warn("[App] RestartRoom error:", result.error)
				end
			end
		end)
	end

	local function onRoomChooseNewPuzzle()
		task.spawn(function()
			local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
			if not remotes then return end
			local restartRemote = remotes:FindFirstChild("RestartRoom")
			if restartRemote and restartRemote:IsA("RemoteFunction") then
				local ok, result = pcall(function() return restartRemote:InvokeServer(false) end)
				if ok and result and result.error then
					warn("[App] RestartRoom error:", result.error)
				end
			end
		end)
	end

	local function onAdmire()
		setAdmireIsMultiplayer(gameState == "room_complete")
		setGameState("admiring")
	end

	-- Build safe area children (menu, XP bar)
	local safeChildren: { [string]: any } = {}

	if XPBar and playerData then
		safeChildren["XPBar"] = React.createElement(XPBar, {
			level = playerData.level,
			xp = playerData.xp,
			cash = playerData.cash,
		})
	end

	local function onHintUsed()
		setPlayerData(function(prev)
			if not prev then return prev end
			local updated = table.clone(prev)
			updated.hintsRemaining = math.max(0, (updated.hintsRemaining or 0) - 1)
			return updated
		end)
	end

	local function onEquip(itemId: string, category: string)
		setPlayerData(function(prev)
			if not prev then return prev end
			local updated = table.clone(prev)
			if category == "board_skins" then
				updated.equippedBoardSkin = itemId
			elseif category == "confetti_styles" then
				updated.equippedConfettiStyle = itemId
			elseif category == "badges" then
				updated.equippedBadge = itemId
			end
			return updated
		end)
	end

	if gameState == "walking" then
		safeChildren["WalkingHint"] = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -30),
			Size = UDim2.new(0, 500, 0, 50),
			BackgroundColor3 = Color3.fromRGB(30, 30, 40),
			BackgroundTransparency = 0.3,
			Text = "Walk to a table and sit down to start a puzzle!",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 20,
			Font = Enum.Font.GothamMedium,
			TextWrapped = true,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 12) }),
			Padding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 16),
				PaddingRight = UDim.new(0, 16),
			}),
		})
	end

	if gameState == "menu" then
		safeChildren["Menu"] = React.createElement(MenuScreen, {
			onStart = onStart,
			unlockedImages = if playerData then playerData.unlockedImages else nil,
			playerLevel = if playerData then playerData.level else nil,
			personalBests = if playerData then playerData.personalBests else nil,
			savedPuzzles = savedPuzzles,
			onResume = onResume,
			onDeleteSave = onDeleteSave,
			playerData = playerData,
			onEquip = onEquip,
		})

		-- Leave Table button
		safeChildren["LeaveTableBtn"] = React.createElement("TextButton", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 20, 1, -20),
			Size = UDim2.new(0, 140, 0, 40),
			BackgroundColor3 = Color3.fromRGB(140, 60, 60),
			Text = "Leave Table",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 16,
			Font = Enum.Font.GothamBold,
			[React.Event.Activated] = function()
				local localPlayer = Players.LocalPlayer
				if localPlayer and localPlayer.Character then
					local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid.Sit = false
					end
				end
			end,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
		})
	end

	-- Room lobby screen
	if gameState == "room_lobby" then
		local localPlayer = game:GetService("Players").LocalPlayer
		local localUserId = localPlayer and localPlayer.UserId or 0
		local isHost = roomInfo and roomInfo.hostUserId == localUserId

		safeChildren["RoomLobby"] = React.createElement(RoomLobbyScreen, {
			roomInfo = roomInfo,
			isHost = isHost,
			onLeave = onLeaveRoom,
			onConfigure = onConfigureRoom,
			onStart = onStartRoom,
			unlockedImages = if playerData then playerData.unlockedImages else nil,
			playerLevel = if playerData then playerData.level else nil,
		})
	end

	-- Board ScreenGui: full screen for piece dragging (rendered below safe UI)
	local boardGui = nil
	local isMultiplayerBoard = gameState == "room_playing" or gameState == "room_complete"
	if gameState == "playing" or gameState == "complete" or gameState == "admiring" or isMultiplayerBoard then
		boardGui = React.createElement("ScreenGui", {
			Name = "PuzzleAppBoard",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ScreenInsets = Enum.ScreenInsets.None,
			DisplayOrder = 0,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		}, {
			Board = React.createElement(PuzzleBoard, {
				imageAssetId = imageAssetId,
				imageId = imageId,
				difficultyId = difficultyId,
				rows = rows,
				cols = cols,
				onComplete = if isMultiplayerBoard then function()
					-- In multiplayer, completion is handled by RoomCompleted event
				end else onComplete,
				onGiveUp = if isMultiplayerBoard then onLeaveRoom else onGiveUp,
				onBackToMenu = if isMultiplayerBoard then nil else onBackToMenu,
				savedState = if isMultiplayerBoard then nil else resumeState,
				equippedBoardSkin = if playerData then playerData.equippedBoardSkin else nil,
				hintsRemaining = if playerData then playerData.hintsRemaining else 0,
				onHintUsed = onHintUsed,
				isMultiplayer = isMultiplayerBoard,
				roomPuzzleDef = roomPuzzleDef,
				roomInitialPieces = roomInitialPieces,
			}),
		})
	end

	-- Complete ScreenGui: full screen so confetti ignores top bar
	local completeGui = nil
	if gameState == "complete" or gameState == "room_complete" then
		completeGui = React.createElement("ScreenGui", {
			Name = "PuzzleAppComplete",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ScreenInsets = Enum.ScreenInsets.None,
			DisplayOrder = 2,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		}, {
			Complete = React.createElement(CompleteScreen, {
				onPlayAgain = if gameState == "room_complete" then onRoomPlayAgain else onPlayAgain,
				onAdmire = onAdmire,
				completionTime = completionTime,
				rewardData = rewardData,
				isPersonalBest = if rewardData then rewardData.isPersonalBest else false,
				previousBest = if rewardData then rewardData.previousBest else nil,
				equippedConfettiStyle = if playerData then playerData.equippedConfettiStyle else nil,
				isMultiplayer = gameState == "room_complete",
				isHost = gameState == "room_complete" and roomInfo ~= nil and roomInfo.hostUserId == (Players.LocalPlayer and Players.LocalPlayer.UserId or 0),
				onChooseNewPuzzle = onRoomChooseNewPuzzle,
			}),
		})
	end

	-- Admire overlay ScreenGui: screenshot + back buttons over the completed puzzle
	local admireGui = nil
	if gameState == "admiring" then
		admireGui = React.createElement("ScreenGui", {
			Name = "PuzzleAppAdmire",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ScreenInsets = Enum.ScreenInsets.None,
			DisplayOrder = 2,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		}, {
			Buttons = React.createElement("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -20),
				Size = UDim2.new(0, 240, 0, 110),
				BackgroundTransparency = 1,
			}, {
				Layout = React.createElement("UIListLayout", {
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 10),
				}),
				ScreenshotButton = React.createElement("TextButton", {
					LayoutOrder = 1,
					Size = UDim2.new(0, 220, 0, 48),
					BackgroundColor3 = Color3.fromRGB(80, 200, 120),
					Text = "Save Screenshot",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 22,
					Font = Enum.Font.GothamBold,
					[React.Event.Activated] = function(rbx)
						-- Hide all UI for a clean screenshot
						local screenGui = rbx:FindFirstAncestorOfClass("ScreenGui")
						if screenGui then
							screenGui.Enabled = false
						end
						StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)

						task.wait()

						CaptureService:CaptureScreenshot(function(contentId)
							if screenGui then
								screenGui.Enabled = true
							end
							StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
							CaptureService:PromptSaveCapturesToGallery({ contentId }, function() end)
						end)
					end,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
				}),
				BackButton = React.createElement("TextButton", {
					LayoutOrder = 2,
					Size = UDim2.new(0, 220, 0, 48),
					BackgroundColor3 = Color3.fromRGB(100, 100, 120),
					Text = if admireIsMultiplayer then "Back to Lobby" else "Back to Menu",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 22,
					Font = Enum.Font.GothamBold,
					[React.Event.Activated] = function()
						if admireIsMultiplayer then
							onRoomPlayAgain()
						else
							onPlayAgain()
						end
					end,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
				}),
			}),
		})
	end

	-- Safe ScreenGui: avoids top bar + device notches
	local safeGui = React.createElement("ScreenGui", {
		Name = "PuzzleAppSafe",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		DisplayOrder = 1,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, {
		Content = React.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, safeChildren),
	})

	return React.createElement(React.Fragment, nil, {
		SafeGui = safeGui,
		BoardGui = boardGui,
		CompleteGui = completeGui,
		AdmireGui = admireGui,
	})
end

return App
