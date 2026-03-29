local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local AvatarEditorService = game:GetService("AvatarEditorService")
local UserInputService = game:GetService("UserInputService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local ImageCatalog = require(Shared.ImageCatalog)
local MonetizationConfig = require(Shared.MonetizationConfig)
local Theme = require(Shared.Theme)

local MenuScreen = require(script.Parent.components.MenuScreen)
local PuzzleBoard = require(script.Parent.components.PuzzleBoard)
local CompleteScreen = require(script.Parent.components.CompleteScreen)
local NewItemNotification = require(script.Parent.components.NewItemNotification)
local RoomLobbyScreen = require(script.Parent.components.RoomLobbyScreen)
local DailyRewardModal = require(script.Parent.components.DailyRewardModal)
local SpinWheelModal = require(script.Parent.components.SpinWheelModal)
local LikeFavoriteModal = require(script.Parent.components.LikeFavoriteModal)
local DevToolPanel = require(script.Parent.components.DevToolPanel)
local RoomCodeEntryScreen = require(script.Parent.components.RoomCodeEntryScreen)
local StarterPackButton = require(script.Parent.components.StarterPackButton)
local StarterPackModal = require(script.Parent.components.StarterPackModal)
local ResumePromptModal = require(script.Parent.components.ResumePromptModal)

-- SeatingService loaded optionally
local SeatingService = nil
pcall(function()
	SeatingService = require(script.Parent.Parent.services.SeatingService)
end)


type GameState = "walking" | "menu" | "playing" | "complete" | "admiring" | "room_lobby" | "room_playing" | "room_complete" | "room_code_entry"

local function App(props)
	local playerGui = props.playerGui
	local gameState, setGameState = React.useState("walking" :: GameState)
	local rows, setRows = React.useState(3)
	local cols, setCols = React.useState(3)
	local imageAssetId, setImageAssetId = React.useState("")
	local imageId, setImageId = React.useState("")
	local difficultyId, setDifficultyId = React.useState("6x6")
	local completionTime, setCompletionTime = React.useState(0)
	local rewardData, setRewardData = React.useState(nil :: any)

	-- Refs to avoid stale closures in XPAwarded listener
	local imageIdRef = React.useRef(imageId)
	local difficultyIdRef = React.useRef(difficultyId)
	local completionTimeRef = React.useRef(completionTime)
	local rowsRef = React.useRef(rows)
	local colsRef = React.useRef(cols)
	imageIdRef.current = imageId
	difficultyIdRef.current = difficultyId
	completionTimeRef.current = completionTime
	rowsRef.current = rows
	colsRef.current = cols

	-- Saved puzzles state
	local savedPuzzles, setSavedPuzzles = React.useState({} :: { any })
	local savedPuzzlesRef = React.useRef(savedPuzzles)
	savedPuzzlesRef.current = savedPuzzles
	local resumeState, setResumeState = React.useState(nil :: any)
	local showResumePrompt, setShowResumePrompt = React.useState(false)
	local didResumeFromPromptRef = React.useRef(false)

	-- Multiplayer room state
	local roomInfo, setRoomInfo = React.useState(nil :: any)
	local roomPuzzleDef, setRoomPuzzleDef = React.useState(nil :: any)
	local roomInitialPieces, setRoomInitialPieces = React.useState(nil :: any)
	local roomConfig, setRoomConfig = React.useState(nil :: any)
	-- Admire mode tracking for multiplayer
	local admireIsMultiplayer, setAdmireIsMultiplayer = React.useState(false)

	-- Room code entry error state
	local roomJoinError, setRoomJoinError = React.useState(nil :: string?)

	-- Loading state for initial data fetch
	local isDataLoading, setIsDataLoading = React.useState(true)

	-- Daily reward state
	local showDailyReward, setShowDailyReward = React.useState(false)
	local showLikeFavoriteModal, setShowLikeFavoriteModal = React.useState(false)
	local favoriteChecking, setFavoriteChecking = React.useState(false)
	local favoriteError, setFavoriteError = React.useState(nil :: string?)
	local dailyRewardStatus, setDailyRewardStatus = React.useState(nil :: any)
	local dailyRewardClaimResult, setDailyRewardClaimResult = React.useState(nil :: any)

	-- Daily puzzle state
	local dailyPuzzle, setDailyPuzzle = React.useState(nil :: any)
	local dailyPuzzleCompleted, setDailyPuzzleCompleted = React.useState(false)

	-- Spin wheel state
	local spinWheelCanFree, setSpinWheelCanFree = React.useState(false)
	local spinWheelSecsUntilFree, setSpinWheelSecsUntilFree = React.useState(0)
	local spinWheelPaidRestricted, setSpinWheelPaidRestricted = React.useState(false)

	-- Starter pack state
	local starterPackSecsLeft, setStarterPackSecsLeft = React.useState(0)
	local starterPackPurchased, setStarterPackPurchased = React.useState(true) -- hidden until data loads
	local showStarterPackModal, setShowStarterPackModal = React.useState(false)

	-- Dev tool panel state (admin only)
	local isAdmin = Players.LocalPlayer.UserId == 3401001
	local showDevToolPanel, setShowDevToolPanel = React.useState(false)

	-- NPC overlay state (only one open at a time)
	local activeOverlay, setActiveOverlay = React.useState(nil :: string?)
	local overlayRef = React.useRef(nil :: Frame?)
	local blurRef = React.useRef(nil :: BlurEffect?)

	-- New item purchase notification state
	local newItemNotification, setNewItemNotification = React.useState(nil :: any)
	local function onDismissNotification()
		setNewItemNotification(nil)
	end

	local function closeOverlay()
		-- Tween out blur + FOV
		local blur = blurRef.current
		if blur then
			local blurOut = TweenService:Create(blur, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = 0,
			})
			blurOut:Play()
			blurOut.Completed:Once(function()
				if blurRef.current == blur then
					blur:Destroy()
					blurRef.current = nil
				end
			end)
		end
		local camera = workspace.CurrentCamera
		TweenService:Create(camera, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			FieldOfView = 70,
		}):Play()

		local frame = overlayRef.current
		if frame then
			local tweenOut = TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, 0, 0.5, 30),
				GroupTransparency = 1,
			})
			tweenOut:Play()
			tweenOut.Completed:Once(function()
				setActiveOverlay(nil)
			end)
		else
			setActiveOverlay(nil)
		end
	end

	local function openOverlay(name: string)
		-- If same overlay is already open, close it (toggle)
		if activeOverlay == name then
			closeOverlay()
			return
		end

		-- Close current overlay with slide-out, then open new one
		local frame = overlayRef.current
		if activeOverlay and frame then
			local tweenOut = TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, 0, 0.5, 30),
				GroupTransparency = 1,
			})
			tweenOut:Play()
			tweenOut.Completed:Once(function()
				setActiveOverlay(name)
			end)
		else
			setActiveOverlay(name)
		end
	end

	-- Compat shorthands for NPC proximity triggers
	local npcShopOpen = activeOverlay == "shop"
	local npcRobuxShopOpen = activeOverlay == "robux"
	local npcLeaderboardOpen = activeOverlay == "leaderboard"
	local npcStatsOpen = activeOverlay == "stats"

	-- Tween-in on overlay mount + blur/FOV effect
	React.useEffect(function()
		if activeOverlay == nil then return end
		local frame = overlayRef.current
		if not frame then return end

		frame.Position = UDim2.new(0.5, 0, 0.5, 30)
		frame.GroupTransparency = 1

		local tweenIn = TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.5, 0.5),
			GroupTransparency = 0,
		})
		tweenIn:Play()

		-- Blur effect
		local blur = blurRef.current
		if not blur then
			blur = Instance.new("BlurEffect")
			blur.Size = 0
			blur.Parent = Lighting
			blurRef.current = blur
		end
		local blurIn = TweenService:Create(blur, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = 24,
		})
		blurIn:Play()

		-- FOV zoom
		local camera = workspace.CurrentCamera
		local fovIn = TweenService:Create(camera, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			FieldOfView = 60,
		})
		fovIn:Play()

		return function()
			tweenIn:Cancel()
			blurIn:Cancel()
			fovIn:Cancel()
		end
	end, { activeOverlay })

	-- Toggle mobile touch controls based on game state
	-- Skip initial mount to avoid racing PlayerModule's TouchGui creation;
	-- only toggle when gameState actually changes after first render.
	local touchMounted = React.useRef(false)
	React.useEffect(function()
		if not UserInputService.TouchEnabled then return end
		if not touchMounted.current then
			touchMounted.current = true
			return
		end
		if gameState ~= "walking" then
			GuiService.TouchControlsEnabled = false
		else
			task.defer(function()
				GuiService.TouchControlsEnabled = true
			end)
		end
	end, { gameState })

	-- Seating state
	local seatingInfo, setSeatingInfo = React.useState(nil :: any)
	local hasEverSat, setHasEverSat = React.useState(false)

	-- Player data state (populated by remotes in Phase 2)
	local playerData, setPlayerData = React.useState(nil :: {
		cash: number,
		unlockedImages: { [string]: boolean },
		personalBests: { [string]: number },
		titleName: string?,
		equippedBoardSkin: string?,
		equippedConfettiStyle: string?,
		equippedSnapEffect: string?,
		hasExpertPass: boolean?,
		hintsRemaining: number?,
		hasClaimedFavoriteReward: boolean?,
		cashBoostsRemaining: number?,
		ownedBoardSkins: { [string]: boolean }?,
		ownedConfettiStyles: { [string]: boolean }?,
		ownedSnapEffects: { [string]: boolean }?,
		totalPuzzlesCompleted: number?,
		totalPlayTime: number?,
		totalPiecesPlaced: number?,
		puzzlesCompletedByDifficulty: { [string]: number }?,
	}?)

	-- Try to fetch initial player data via GetPlayerData remote
	React.useEffect(function()
		task.spawn(function()
			local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
			if not remotes then
				setIsDataLoading(false)
				return
			end
			local getPlayerData = remotes:FindFirstChild("GetPlayerData")
			if not getPlayerData or not getPlayerData:IsA("RemoteFunction") then
				setIsDataLoading(false)
				return
			end

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

			-- Fetch daily reward status
			local getDailyStatus = remotes:FindFirstChild("GetDailyRewardStatus")
			if getDailyStatus and getDailyStatus:IsA("RemoteFunction") then
				local ok3, status = pcall(function() return getDailyStatus:InvokeServer() end)
				if ok3 and status then
					setDailyRewardStatus(status)
					if status.canClaim then
						setShowDailyReward(true)
					end
				end
			end

			-- Fetch daily puzzle
			local getDailyPuzzleRemote = remotes:FindFirstChild("GetDailyPuzzle")
			if getDailyPuzzleRemote and getDailyPuzzleRemote:IsA("RemoteFunction") then
				local ok4, result = pcall(function() return getDailyPuzzleRemote:InvokeServer() end)
				if ok4 and result then
					setDailyPuzzle(result.puzzle)
					setDailyPuzzleCompleted(result.completed == true)
				end
			end

			-- Fetch spin wheel status
			local getSpinStatus = remotes:FindFirstChild("GetSpinWheelStatus")
			if getSpinStatus and getSpinStatus:IsA("RemoteFunction") then
				local ok5, spinStatus = pcall(function() return getSpinStatus:InvokeServer() end)
				if ok5 and spinStatus then
					setSpinWheelCanFree(spinStatus.canFreeSpin == true)
					setSpinWheelSecsUntilFree(spinStatus.secondsUntilFreeSpin or 0)
					setSpinWheelPaidRestricted(spinStatus.paidSpinsRestricted == true)
				end
			end

			-- Init starter pack timer from player data
			if data then
				setStarterPackPurchased(data.starterPack_purchased == true)
				if not data.starterPack_purchased then
					local remaining = math.max(0, (data.starterPack_expiryTime or 0) - os.time())
					setStarterPackSecsLeft(remaining)
				end
			end

			setIsDataLoading(false)
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
			-- Update local player data (use refs to get current values, not stale closure)
			if data then
				local curImageId = imageIdRef.current
				local curDifficultyId = difficultyIdRef.current
				local curCompletionTime = if data.completionTime and data.completionTime > 0 then data.completionTime else completionTimeRef.current
				local curRows = rowsRef.current
				local curCols = colsRef.current

				setPlayerData(function(prev)
					if not prev then return prev end
					local updated = table.clone(prev)
					if data.cashGained then
						updated.cash = (updated.cash or 0) + data.cashGained
					end
					if data.imageUnlocked then
						updated.unlockedImages = table.clone(updated.unlockedImages)
						updated.unlockedImages[data.imageUnlocked] = true
					end
					if data.isPersonalBest and curCompletionTime > 0 then
						local bestKey = curImageId .. "_" .. curDifficultyId
						updated.personalBests = table.clone(updated.personalBests)
						updated.personalBests[bestKey] = curCompletionTime
					end
					updated.totalPuzzlesCompleted = (updated.totalPuzzlesCompleted or 0) + 1
					updated.totalPlayTime = (updated.totalPlayTime or 0) + curCompletionTime
					updated.totalPiecesPlaced = (updated.totalPiecesPlaced or 0) + (curRows * curCols)
					if not updated.puzzlesCompletedByDifficulty then
						updated.puzzlesCompletedByDifficulty = {}
					else
						updated.puzzlesCompletedByDifficulty = table.clone(updated.puzzlesCompletedByDifficulty)
					end
					updated.puzzlesCompletedByDifficulty[curDifficultyId] = (updated.puzzlesCompletedByDifficulty[curDifficultyId] or 0) + 1
					if data.boostUsed then
						updated.cashBoostsRemaining = math.max(0, (updated.cashBoostsRemaining or 0) - 1)
					end
					return updated
				end)

				if data.cashPurchased then
					setNewItemNotification({
						category = "cash_purchase",
						name = data.cashProductName or ("+" .. tostring(data.cashGained) .. " Cash"),
						description = "Added to your balance!",
						previewColor = Theme.Colors.cashGreen,
					})
				end
			end
		end)

		return function()
			conn:Disconnect()
		end
	end, {} :: { any })

	-- Listen for Robux image unlock confirmation from server
	React.useEffect(function()
		local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
		if not remotes then return end
		local unlockEvent = remotes:FindFirstChild("ImageUnlockedRobux")
		if not unlockEvent or not unlockEvent:IsA("RemoteEvent") then return end

		local conn = unlockEvent.OnClientEvent:Connect(function(data)
			if data and data.imageId then
				setPlayerData(function(prev)
					if not prev then return prev end
					local updated = table.clone(prev)
					updated.unlockedImages = table.clone(updated.unlockedImages or {})
					updated.unlockedImages[data.imageId] = true
					return updated
				end)
			end
		end)

		return function()
			conn:Disconnect()
		end
	end, {} :: { any })

	-- Starter pack countdown timer
	React.useEffect(function()
		local running = true
		task.spawn(function()
			while running do
				task.wait(1)
				if not running then break end
				setStarterPackSecsLeft(function(prev)
					if prev <= 0 then return 0 end
					return prev - 1
				end)
			end
		end)
		return function()
			running = false
		end
	end, { starterPackPurchased } :: { any })

	-- Listen for StarterPackPurchased event from server
	React.useEffect(function()
		local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
		if not remotes then return end
		local starterEvent = remotes:FindFirstChild("StarterPackPurchased")
		if not starterEvent or not starterEvent:IsA("RemoteEvent") then return end

		local conn = starterEvent.OnClientEvent:Connect(function()
			setStarterPackPurchased(true)
			setStarterPackSecsLeft(0)
			setShowStarterPackModal(false)
			-- Refresh player data
			task.spawn(function()
				local getPlayerData = remotes:FindFirstChild("GetPlayerData")
				if getPlayerData and getPlayerData:IsA("RemoteFunction") then
					local ok, data = pcall(function() return getPlayerData:InvokeServer() end)
					if ok and data then
						setPlayerData(data)
					end
				end
			end)
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
				setHasEverSat(true)
				if SeatingService then
					SeatingService.SetSeated(data)
					SeatingService.TransitionCameraToTable(data.tableId)
				end

				-- Check for saved puzzles to show resume prompt (both single and multi tables)
				local saves = savedPuzzlesRef.current
				if saves and #saves > 0 then
					setShowResumePrompt(true)
				end

				if data.tableType == "single" then
					setGameState("menu")
				elseif string.find(data.tableType, "^multi") then
					if data.roomInProgress then
						-- Room is playing; show code entry screen instead of joining
						setRoomJoinError(nil)
						setGameState("room_code_entry")
					else
						-- Fetch room info via GetTableInfo
						task.spawn(function()
							local getTableInfo = remotes:FindFirstChild("GetTableInfo")
							if getTableInfo and getTableInfo:IsA("RemoteFunction") then
								local ok, result = pcall(function() return getTableInfo:InvokeServer(data.tableId) end)
								if ok and result and result.roomInfo then
									setRoomInfo(result.roomInfo)
									setRoomConfig(result.roomInfo.config)
									-- Don't overwrite gameState if player already chose to resume a saved puzzle
									if not didResumeFromPromptRef.current then
										setGameState("room_lobby")
									end
								end
							end
						end)
					end
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
				setShowResumePrompt(false)
				didResumeFromPromptRef.current = false
	
	
	
	
				setGameState("walking")
			end))
		end

		return function()
			for _, conn in connections do
				conn:Disconnect()
			end
		end
	end, {} :: { any })

	-- Listen for NPC ProximityPrompt triggers
	React.useEffect(function()
		local conn = ProximityPromptService.PromptTriggered:Connect(function(prompt)
			local rootPart = prompt.Parent
			if not rootPart then return end
			local model = rootPart.Parent
			if not model then return end
			local npcTypeValue = model:FindFirstChild("NPCType")
			if not npcTypeValue or not npcTypeValue:IsA("StringValue") then return end

			local npcType = npcTypeValue.Value
			if npcType == "shop" then
				openOverlay("shop")
			elseif npcType == "leaderboard" then
				openOverlay("leaderboard")
			elseif npcType == "stats" then
				openOverlay("stats")
			end
		end)

		return function()
			conn:Disconnect()
		end
	end, {} :: { any })

	-- Close NPC overlays when leaving walking state
	React.useEffect(function()
		if gameState ~= "walking" then
			setActiveOverlay(nil)
		end
	end, { gameState })

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

		-- Notify server of puzzle start for server-side timing
		task.spawn(function()
			local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
			if not remotes then return end
			local puzzleStartedEvent = remotes:FindFirstChild("PuzzleStarted")
			if puzzleStartedEvent and puzzleStartedEvent:IsA("RemoteEvent") then
				puzzleStartedEvent:FireServer({
					imageId = selectedImageId,
					difficultyId = selectedDifficultyId,
				})
			end
		end)
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

			-- Also fire DailyPuzzleCompleted if this matches the daily puzzle
			if dailyPuzzle and imageId == dailyPuzzle.imageId and difficultyId == dailyPuzzle.difficultyId then
				local dailyEvent = remotes:FindFirstChild("DailyPuzzleCompleted")
				if dailyEvent and dailyEvent:IsA("RemoteEvent") then
					dailyEvent:FireServer({
						imageId = imageId,
						difficultyId = difficultyId,
						completionTime = elapsedSeconds,
					})
					setDailyPuzzleCompleted(true)
				end
			end
		end)
	end

	local function savePuzzleData(saveData: any)
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
	end

	local function onBackToMenu(saveData: any)
		savePuzzleData(saveData)
		setResumeState(nil)
		setGameState("menu")
	end

	local function onSaveContinue(saveData: any)
		savePuzzleData(saveData)
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

		-- Notify server of puzzle resume with prior elapsed time
		task.spawn(function()
			local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
			if not remotes then return end
			local puzzleStartedEvent = remotes:FindFirstChild("PuzzleStarted")
			if puzzleStartedEvent and puzzleStartedEvent:IsA("RemoteEvent") then
				puzzleStartedEvent:FireServer({
					imageId = save.imageId,
					difficultyId = save.difficultyId,
					resumedElapsed = save.elapsedSeconds,
				})
			end
		end)
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

	-- Resume prompt handlers
	local function onResumeFromPrompt(slotIndex: number)
		setShowResumePrompt(false)
		local save = savedPuzzles[slotIndex]
		if not save then return end

		-- Check if we're at a multiplayer table
		local isMultiTable = seatingInfo and string.find(seatingInfo.tableType, "^multi")
		if isMultiTable then
			didResumeFromPromptRef.current = true
			-- Resume as multiplayer: call ResumeRoom to configure + start room with saved state
			task.spawn(function()
				local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
				if not remotes then return end
				local resumeRemote = remotes:FindFirstChild("ResumeRoom")
				if resumeRemote and resumeRemote:IsA("RemoteFunction") then
					local ok, result = pcall(function() return resumeRemote:InvokeServer(save) end)
					if ok and result and result.error then
						warn("[App] ResumeRoom error:", result.error)
					end
				end
			end)
		else
			onResume(slotIndex)
		end
	end

	local function onStartFresh()
		setShowResumePrompt(false)
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
					setRoomJoinError(result.error)
					return
				end
				setRoomJoinError(nil)
				setRoomInfo(result.roomInfo)

				-- Late join: skip lobby, go straight to playing
				if result.lateJoin then
					local config = result.lateJoin.config
					setRows(config.rows)
					setCols(config.cols)
					setImageAssetId(config.imageAssetId)
					setImageId(config.imageId)
					setDifficultyId(config.difficultyId)
					setRoomPuzzleDef(result.lateJoin.puzzleDef)
					setRoomInitialPieces(result.lateJoin.pieces)
					setRoomConfig(config)
					setCompletionTime(0)
					setRewardData(nil)
					setGameState("room_playing")
				else
					setRoomConfig(result.roomInfo and result.roomInfo.config)
					setGameState("room_lobby")
				end
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
		-- Force stand up from the seat — this triggers server-side handleUnsit
		-- which fires PlayerUnseated, cleaning up seatingInfo and going to "walking"
		local humanoid = Players.LocalPlayer and Players.LocalPlayer.Character
			and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Sit = false
		end
		-- Fallback: if not seated or humanoid not found, go to walking directly
		if not seatingInfo then
			setGameState("walking")
		end
		-- Otherwise, PlayerUnseated event will handle the state transition
	end

	-- Multiplayer save callbacks (save & exit leaves room, save & continue just saves)
	local function onMpBackToMenu(saveData: any)
		savePuzzleData(saveData)
		onLeaveRoom()
	end

	local function onMpSaveContinue(saveData: any)
		savePuzzleData(saveData)
	end

	-- Stand up from table without leaving a room (for code entry screen)
	local function onLeaveTable()
		setRoomJoinError(nil)
		local humanoid = Players.LocalPlayer and Players.LocalPlayer.Character
			and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Sit = false
		end
		if not seatingInfo then
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
			elseif category == "snap_effects" then
				updated.equippedSnapEffect = itemId
			end
			return updated
		end)

		-- Persist to server
		task.spawn(function()
			local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
			if not remotes then return end
			local equipRemote = remotes:FindFirstChild("EquipItem")
			if equipRemote and equipRemote:IsA("RemoteFunction") then
				pcall(function() equipRemote:InvokeServer(itemId, category) end)
			end
		end)
	end

	-- Show loading indicator while initial data is being fetched
	if isDataLoading then
		safeChildren["DataLoading"] = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -30),
			Size = UDim2.new(0, 300, 0, 40),
			BackgroundColor3 = Theme.Colors.bgMedium,
			BackgroundTransparency = Theme.Transparency.hudButton,
			Text = "Loading player data...",
			TextColor3 = Theme.Colors.textSecondary,
			TextSize = Theme.TextSize.button,
			Font = Theme.Font.medium,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = Theme.Radius.md }),
		})
	end

	local spinWheelElement = nil
	local starterPackElement = nil
	if gameState == "walking" then
		-- Only show hint for players who haven't sat at a table yet
		if not hasEverSat and not (playerData and (playerData.totalPuzzlesCompleted or 0) > 0) then
			safeChildren["WalkingHint"] = React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 0.95),
				Size = UDim2.fromScale(0.35, 0.06),
				BackgroundColor3 = Theme.Colors.bgMedium,
				BackgroundTransparency = Theme.Transparency.hudButton,
				Text = "Walk to a table and sit down to start a puzzle!",
				TextColor3 = Theme.Colors.textPrimary,
				TextSize = Theme.TextSize.large,
				Font = Theme.Font.medium,
				TextWrapped = true,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 12) }),
				Padding = React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, 16),
					PaddingRight = UDim.new(0, 16),
				}),
			})
		end

		-- Cash display (bottom-left)
		if playerData then
			safeChildren["CashDisplay"] = React.createElement("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0.02, 0, 0.96, 0),
				Size = UDim2.new(0.22, 0, 0.07, 0),
				BackgroundColor3 = Theme.Colors.bgHud,
				BackgroundTransparency = Theme.Transparency.subtle,
				ZIndex = 10,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = Theme.Radius.md }),
				Stroke = React.createElement("UIStroke", {
					Thickness = 1.5,
					Color = Theme.Colors.border,
				}),
				SizeConstraint = React.createElement("UISizeConstraint", {
					MinSize = Vector2.new(140, 40),
					MaxSize = Vector2.new(300, 60),
				}),
				CashLabel = React.createElement("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = "$" .. (playerData.cash or 0),
					TextColor3 = Theme.Colors.cashGreen,
					TextScaled = true,
					Font = Theme.Font.bold,
					ZIndex = 11,
				}, {
					Padding = React.createElement("UIPadding", {
						PaddingLeft = UDim.new(0.08, 0),
						PaddingRight = UDim.new(0.08, 0),
					}),
					TextStroke = React.createElement("UIStroke", {
						Thickness = 1.5,
						Color = Theme.Colors.black,
					}),
				}),
			})
		end

		-- Persistent HUD buttons (left side, vertically centered)
		safeChildren["HUDButtons"] = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.fromScale(0.105, 0.7),
			BackgroundTransparency = 1,
			ZIndex = 10,
		}, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0.01, 0),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
			}),
			CashShopBtn = React.createElement("Frame", {
				LayoutOrder = 1,
				Size = UDim2.fromScale(1, 0.23),
				BackgroundTransparency = 1,
				ZIndex = 10,
			}, {
				Icon = React.createElement("ImageButton", {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0),
					Size = UDim2.fromScale(0.85, 0.72),
					BackgroundTransparency = 1,
					Image = "rbxassetid://135280767376471",
					ScaleType = Enum.ScaleType.Fit,
					ZIndex = 10,
					[React.Event.Activated] = function()
						openOverlay("shop")
					end,
					[React.Event.MouseEnter] = function(rbx)
						TweenService:Create(rbx, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = 5 }):Play()
					end,
					[React.Event.MouseLeave] = function(rbx)
						TweenService:Create(rbx, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
					end,
				}, {
					Aspect = React.createElement("UIAspectRatioConstraint", {
						AspectRatio = 1,
					}),
				}),
				Label = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.72),
					Size = UDim2.fromScale(1.1, 0.3),
					BackgroundTransparency = 1,
					ZIndex = 11,
					Text = "Shop",
					TextColor3 = Theme.Colors.textPrimary,
					TextScaled = true,
					Font = Theme.Font.heading,
				}, {
					LabelStroke = React.createElement("UIStroke", {
						Thickness = 2,
						Color = Theme.Colors.black,
					}),
				}),
			}),
			RobuxShopBtn = React.createElement("Frame", {
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0.23),
				BackgroundTransparency = 1,
				ZIndex = 10,
			}, {
				Icon = React.createElement("ImageButton", {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0),
					Size = UDim2.fromScale(0.85, 0.72),
					BackgroundTransparency = 1,
					Image = "rbxassetid://136485331602074",
					ScaleType = Enum.ScaleType.Fit,
					ZIndex = 10,
					[React.Event.Activated] = function()
						openOverlay("robux")
					end,
					[React.Event.MouseEnter] = function(rbx)
						TweenService:Create(rbx, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = 5 }):Play()
					end,
					[React.Event.MouseLeave] = function(rbx)
						TweenService:Create(rbx, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
					end,
				}, {
					Aspect = React.createElement("UIAspectRatioConstraint", {
						AspectRatio = 1,
					}),
				}),
				Label = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.72),
					Size = UDim2.fromScale(1.1, 0.3),
					BackgroundTransparency = 1,
					ZIndex = 11,
					Text = "R$ Shop",
					TextColor3 = Theme.Colors.textPrimary,
					TextScaled = true,
					Font = Theme.Font.heading,
				}, {
					LabelStroke = React.createElement("UIStroke", {
						Thickness = 2,
						Color = Theme.Colors.black,
					}),
				}),
			}),
			LeaderBtn = React.createElement("Frame", {
				LayoutOrder = 3,
				Size = UDim2.fromScale(1, 0.23),
				BackgroundTransparency = 1,
				ZIndex = 10,
			}, {
				Icon = React.createElement("ImageButton", {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0),
					Size = UDim2.fromScale(0.85, 0.72),
					BackgroundTransparency = 1,
					Image = "rbxassetid://87104752122465",
					ScaleType = Enum.ScaleType.Fit,
					ZIndex = 10,
					[React.Event.Activated] = function()
						openOverlay("leaderboard")
					end,
					[React.Event.MouseEnter] = function(rbx)
						TweenService:Create(rbx, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = 5 }):Play()
					end,
					[React.Event.MouseLeave] = function(rbx)
						TweenService:Create(rbx, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
					end,
				}, {
					Aspect = React.createElement("UIAspectRatioConstraint", {
						AspectRatio = 1,
					}),
				}),
				Label = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.72),
					Size = UDim2.fromScale(1.1, 0.3),
					BackgroundTransparency = 1,
					ZIndex = 11,
					Text = "Leaderboard",
					TextColor3 = Theme.Colors.textPrimary,
					TextScaled = true,
					Font = Theme.Font.heading,
				}, {
					LabelStroke = React.createElement("UIStroke", {
						Thickness = 2,
						Color = Theme.Colors.black,
					}),
				}),
			}),
			StatsBtn = React.createElement("Frame", {
				LayoutOrder = 4,
				Size = UDim2.fromScale(1, 0.23),
				BackgroundTransparency = 1,
				ZIndex = 10,
			}, {
				Icon = React.createElement("ImageButton", {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0),
					Size = UDim2.fromScale(0.85, 0.72),
					BackgroundTransparency = 1,
					Image = "rbxassetid://80087999124116",
					ScaleType = Enum.ScaleType.Fit,
					ZIndex = 10,
					[React.Event.Activated] = function()
						openOverlay("stats")
					end,
					[React.Event.MouseEnter] = function(rbx)
						TweenService:Create(rbx, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = 5 }):Play()
					end,
					[React.Event.MouseLeave] = function(rbx)
						TweenService:Create(rbx, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
					end,
				}, {
					Aspect = React.createElement("UIAspectRatioConstraint", {
						AspectRatio = 1,
					}),
				}),
				Label = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.72),
					Size = UDim2.fromScale(1.1, 0.3),
					BackgroundTransparency = 1,
					ZIndex = 11,
					Text = "Stats",
					TextColor3 = Theme.Colors.textPrimary,
					TextScaled = true,
					Font = Theme.Font.heading,
				}, {
					LabelStroke = React.createElement("UIStroke", {
						Thickness = 2,
						Color = Theme.Colors.black,
					}),
				}),
			}),
		})

		-- Spin wheel button (top area, between center and right)
		spinWheelElement = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.7, 0, 0, 4),
			Size = UDim2.fromScale(0.105, 0.14),
			BackgroundTransparency = 1,
			ZIndex = 10,
		}, {
			Icon = React.createElement("ImageButton", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.fromScale(0.85, 0.72),
				BackgroundColor3 = Theme.Colors.gold,
				BackgroundTransparency = 1,
				Image = "",
				ZIndex = 10,
				[React.Event.Activated] = function()
					openOverlay("spin")
				end,
				[React.Event.MouseEnter] = function(rbx)
					TweenService:Create(rbx, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = 5 }):Play()
				end,
				[React.Event.MouseLeave] = function(rbx)
					TweenService:Create(rbx, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
				end,
			}, {
				Aspect = React.createElement("UIAspectRatioConstraint", {
					AspectRatio = 1,
				}),
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
				SpinIcon = React.createElement("ImageLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Image = "rbxassetid://124221102367378",
					ScaleType = Enum.ScaleType.Fit,
					ZIndex = 10,
				}),
				FreeDot = if spinWheelCanFree then React.createElement("Frame", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 6, 0, -6),
					Size = UDim2.fromOffset(18, 18),
					BackgroundColor3 = Theme.Colors.danger,
					ZIndex = 12,
				}, {
					DotCorner = React.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
				}) else nil,
			}),
			Label = React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.72),
				Size = UDim2.fromScale(1.1, 0.3),
				BackgroundTransparency = 1,
				ZIndex = 11,
				Text = "Spin",
				TextColor3 = Theme.Colors.textPrimary,
				TextScaled = true,
				Font = Theme.Font.heading,
			}, {
				LabelStroke = React.createElement("UIStroke", {
					Thickness = 2,
					Color = Theme.Colors.black,
				}),
			}),
		})

		-- Starter pack button (left of spin wheel)
		if not starterPackPurchased and starterPackSecsLeft > 0 then
			starterPackElement = React.createElement(StarterPackButton, {
				secondsLeft = starterPackSecsLeft,
				onActivated = function()
					setShowStarterPackModal(true)
				end,
			})
		end

		-- NPC overlay (animated wrapper)
		if activeOverlay then
			local overlayContent = nil

			if activeOverlay == "shop" then
				local ShopScreen = nil
				local ok = pcall(function()
					ShopScreen = require(script.Parent.components.ShopScreen)
				end)
				if ok and ShopScreen then
					overlayContent = React.createElement(ShopScreen, {
						onClose = closeOverlay,
						playerData = playerData,
						onEquip = onEquip,
						onItemPurchased = function(item)
							setNewItemNotification(item)
						end,
					})
				else
					setActiveOverlay(nil)
				end
			elseif activeOverlay == "robux" then
				local RobuxShopScreen = nil
				local ok = pcall(function()
					RobuxShopScreen = require(script.Parent.components.RobuxShopScreen)
				end)
				if ok and RobuxShopScreen then
					overlayContent = React.createElement(RobuxShopScreen, {
						onClose = closeOverlay,
						playerData = playerData,
					})
				else
					setActiveOverlay(nil)
				end
			elseif activeOverlay == "leaderboard" then
				local LeaderboardScreen = nil
				local ok = pcall(function()
					LeaderboardScreen = require(script.Parent.components.LeaderboardScreen)
				end)
				if ok and LeaderboardScreen then
					overlayContent = React.createElement(LeaderboardScreen, {
						onClose = closeOverlay,
					})
				else
					setActiveOverlay(nil)
				end
			elseif activeOverlay == "stats" then
				local StatsScreen = nil
				local ok = pcall(function()
					StatsScreen = require(script.Parent.components.StatsScreen)
				end)
				if ok and StatsScreen then
					overlayContent = React.createElement(StatsScreen, {
						onClose = closeOverlay,
						playerData = playerData,
					})
				else
					setActiveOverlay(nil)
				end
			elseif activeOverlay == "spin" then
				overlayContent = React.createElement(SpinWheelModal, {
					onClose = closeOverlay,
					canFreeSpin = spinWheelCanFree,
					secondsUntilFreeSpin = spinWheelSecsUntilFree,
					paidSpinsRestricted = spinWheelPaidRestricted,
					onSpinComplete = function(reward)
						setSpinWheelCanFree(false)
						-- Refresh player data after spin
						task.spawn(function()
							local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
							if not remotes then return end
							local getPlayerData = remotes:FindFirstChild("GetPlayerData")
							if getPlayerData and getPlayerData:IsA("RemoteFunction") then
								local ok2, data = pcall(function() return getPlayerData:InvokeServer() end)
								if ok2 and data then
									setPlayerData(data)
								end
							end
						end)
					end,
				})
			end

			if overlayContent then
				safeChildren["NpcOverlay"] = React.createElement("CanvasGroup", {
					ref = overlayRef,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					GroupTransparency = 0,
					ZIndex = 100,
				}, {
					Content = overlayContent,
				})
			end
		end
	end

	local function onUnlockImage(unlockImageId: string)
		task.spawn(function()
			local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
			if not remotes then return end
			local unlockRemote = remotes:FindFirstChild("UnlockImage")
			if not unlockRemote or not unlockRemote:IsA("RemoteFunction") then return end

			local ok, result = pcall(function() return unlockRemote:InvokeServer(unlockImageId) end)
			if ok and result and result.success then
				setPlayerData(function(prev)
					if not prev then return prev end
					local updated = table.clone(prev)
					updated.cash = result.newCash
					updated.unlockedImages = table.clone(updated.unlockedImages)
					updated.unlockedImages[unlockImageId] = true
					return updated
				end)
			end
		end)
	end

	local function onUnlockImageRobux(unlockImageId: string)
		task.spawn(function()
			-- Tell server which image we want to unlock before prompting purchase
			local remotes = ReplicatedStorage:WaitForChild("PuzzleRemotes")
			local setPending = remotes:WaitForChild("SetPendingUnlock") :: RemoteEvent
			setPending:FireServer(unlockImageId)

			local localPlayer = Players.LocalPlayer
			if localPlayer then
				local MarketplaceService = game:GetService("MarketplaceService")
				pcall(function()
					MarketplaceService:PromptProductPurchase(localPlayer, MonetizationConfig.DEV_PRODUCTS.UNLOCK_PUZZLE.id)
				end)
			end
		end)
	end

	local function onPromptExpertPass()
		task.spawn(function()
			local localPlayer = Players.LocalPlayer
			if localPlayer then
				local MarketplaceService = game:GetService("MarketplaceService")
				pcall(function()
					MarketplaceService:PromptGamePassPurchase(localPlayer, MonetizationConfig.GAME_PASSES.EXPERT.id)
				end)
			end
		end)
	end

	-- Daily reward claim handler
	local function onClaimDailyReward()
		task.spawn(function()
			local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
			if not remotes then return end
			local claimRemote = remotes:FindFirstChild("ClaimDailyReward")
			if not claimRemote or not claimRemote:IsA("RemoteFunction") then return end

			local ok, result = pcall(function() return claimRemote:InvokeServer() end)
			if ok and result then
				setDailyRewardClaimResult(result)
				if result.success and result.newCash then
					setPlayerData(function(prev)
						if not prev then return prev end
						local updated = table.clone(prev)
						updated.cash = result.newCash
						if result.bonusReward and result.bonusReward.type == "snap_effect" then
							updated.ownedSnapEffects = table.clone(updated.ownedSnapEffects or {})
							updated.ownedSnapEffects[result.bonusReward.id] = true
						end
						if result.bonusReward and result.bonusReward.type == "hints" then
							updated.hintsRemaining = (updated.hintsRemaining or 0) + result.bonusReward.count
						end
						return updated
					end)
				end
			end
		end)
	end

	-- Favorite reward: show custom modal
	local function onClaimFavoriteReward()
		setShowLikeFavoriteModal(true)
	end

	-- Favorite reward: confirm from modal → prompt favorite → verify → claim
	local function onConfirmLikeFavorite()
		setFavoriteChecking(true)
		setFavoriteError(nil)
		task.spawn(function()
			-- Prompt the native Roblox favorite dialog with correct args
			local promptOk, promptErr = pcall(function()
				AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
			end)
			if not promptOk then
				warn("[FavoriteReward] PromptSetFavorite failed:", promptErr)
				setFavoriteError("Something went wrong \u{2014} please try again.")
				setFavoriteChecking(false)
				return
			end

			-- Wait for the user to respond to the native prompt
			local result = AvatarEditorService.PromptSetFavoriteCompleted:Wait()

			if result ~= Enum.AvatarPromptResult.Success then
				setFavoriteError("You need to favorite the game to claim the free pack!")
				setFavoriteChecking(false)
				return
			end

			-- User favorited successfully — claim the reward from server
			local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
			if not remotes then
				setFavoriteError("Something went wrong \u{2014} please try again.")
				setFavoriteChecking(false)
				return
			end
			local claimRemote = remotes:FindFirstChild("ClaimFavoriteReward")
			if not claimRemote or not claimRemote:IsA("RemoteFunction") then
				setFavoriteError("Something went wrong \u{2014} please try again.")
				setFavoriteChecking(false)
				return
			end

			local ok, claimResult = pcall(function() return claimRemote:InvokeServer() end)
			if ok and claimResult and claimResult.success then
				setFavoriteChecking(false)
				setFavoriteError(nil)
				setShowLikeFavoriteModal(false)
				setPlayerData(function(prev)
					if not prev then return prev end
					local updated = table.clone(prev)
					updated.hasClaimedFavoriteReward = true
					local imgs = table.clone(updated.unlockedImages or {})
					for _, imgId in claimResult.unlockedIds do
						imgs[imgId] = true
					end
					updated.unlockedImages = imgs
					return updated
				end)
			else
				setFavoriteError("Something went wrong \u{2014} please try again.")
				setFavoriteChecking(false)
			end
		end)
	end

	-- Daily reward modal (auto-show on login when claimable, in walking state)
	if showDailyReward and gameState == "walking" then
		safeChildren["DailyRewardModal"] = React.createElement(DailyRewardModal, {
			onClose = function()
				setShowDailyReward(false)
			end,
			rewardStatus = dailyRewardStatus,
			onClaim = onClaimDailyReward,
			claimResult = dailyRewardClaimResult,
		})
	end

	-- Like & Favorite modal
	if showLikeFavoriteModal then
		safeChildren["LikeFavoriteModal"] = React.createElement(LikeFavoriteModal, {
			onConfirm = onConfirmLikeFavorite,
			onClose = function()
				setShowLikeFavoriteModal(false)
				setFavoriteChecking(false)
				setFavoriteError(nil)
			end,
			isChecking = favoriteChecking,
			errorMessage = favoriteError,
		})
	end

	-- Starter pack modal
	if showStarterPackModal and gameState == "walking" then
		safeChildren["StarterPackModal"] = React.createElement(StarterPackModal, {
			secondsLeft = starterPackSecsLeft,
			onClose = function()
				setShowStarterPackModal(false)
			end,
			onBuy = function()
				local MarketplaceService = game:GetService("MarketplaceService")
				local localPlayer = Players.LocalPlayer
				if localPlayer and MonetizationConfig.DEV_PRODUCTS.STARTER_PACK.id ~= 0 then
					pcall(function()
						MarketplaceService:PromptProductPurchase(localPlayer, MonetizationConfig.DEV_PRODUCTS.STARTER_PACK.id)
					end)
				end
			end,
		})
	end

	-- Dev tool panel (admin only)
	if isAdmin and (gameState == "walking" or gameState == "menu") then
		safeChildren["DevToolBtn"] = React.createElement("TextButton", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 8, 1, -8),
			Size = UDim2.new(0, 48, 0, 28),
			BackgroundColor3 = Theme.Colors.bgElevated,
			Text = "DEV",
			TextColor3 = Theme.Colors.headerGold,
			TextSize = 13,
			Font = Theme.Font.bold,
			ZIndex = 40,
			[React.Event.Activated] = function()
				setShowDevToolPanel(true)
			end,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Stroke = React.createElement("UIStroke", {
				Color = Theme.Colors.border,
				Thickness = 1.5,
			}),
		})
	end

	if isAdmin and showDevToolPanel then
		safeChildren["DevToolPanel"] = React.createElement(DevToolPanel, {
			onClose = function()
				setShowDevToolPanel(false)
			end,
		})
	end

	if gameState == "menu" then
		safeChildren["Menu"] = React.createElement(MenuScreen, {
			onStart = onStart,
			unlockedImages = if playerData then playerData.unlockedImages else nil,
			personalBests = if playerData then playerData.personalBests else nil,
			savedPuzzles = savedPuzzles,
			onResume = onResume,
			onDeleteSave = onDeleteSave,
			playerData = playerData,
			onEquip = onEquip,
			cash = if playerData then playerData.cash else nil,
			hasExpertPass = if playerData then playerData.hasExpertPass else nil,
			onUnlockImage = onUnlockImage,
			onUnlockImageRobux = onUnlockImageRobux,
			onPromptExpertPass = onPromptExpertPass,
			dailyPuzzle = dailyPuzzle,
			dailyPuzzleCompleted = dailyPuzzleCompleted,
			onClaimFavoriteReward = onClaimFavoriteReward,
			hasClaimedFavoriteReward = if playerData then playerData.hasClaimedFavoriteReward else false,
		})

		-- Resume prompt overlay
		if showResumePrompt and savedPuzzles and #savedPuzzles > 0 then
			safeChildren["ResumePrompt"] = React.createElement(ResumePromptModal, {
				savedPuzzles = savedPuzzles,
				onResume = onResumeFromPrompt,
				onNewPuzzle = onStartFresh,
			})
		end

		-- Leave Table button
		safeChildren["LeaveTableBtn"] = React.createElement("TextButton", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.new(0, 140, 0, 40),
			BackgroundColor3 = Theme.Colors.dangerDark,
			Text = "Leave Table",
			TextColor3 = Theme.Colors.textPrimary,
			TextSize = Theme.TextSize.body,
			Font = Theme.Font.bold,
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

	-- Room code entry screen (for in-progress tables)
	if gameState == "room_code_entry" then
		safeChildren["RoomCodeEntry"] = React.createElement(RoomCodeEntryScreen, {
			onJoinRoom = onJoinRoom,
			onLeaveTable = onLeaveTable,
			joinError = roomJoinError,
		})

		-- Resume prompt overlay for room code entry
		if showResumePrompt and savedPuzzles and #savedPuzzles > 0 then
			safeChildren["ResumePrompt"] = React.createElement(ResumePromptModal, {
				savedPuzzles = savedPuzzles,
				onResume = onResumeFromPrompt,
				onNewPuzzle = onStartFresh,
			})
		end
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
			personalBests = if playerData then playerData.personalBests else nil,
			cash = if playerData then playerData.cash else 0,
			onUnlockImage = onUnlockImage,
			onUnlockImageRobux = onUnlockImageRobux,
			hasExpertPass = if playerData then playerData.hasExpertPass else nil,
			onPromptExpertPass = onPromptExpertPass,
			savedPuzzles = savedPuzzles,
			onResumeSave = function(slotIndex: number)
				local save = savedPuzzles[slotIndex]
				if not save then return end
				task.spawn(function()
					local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
					if not remotes then return end
					local resumeRemote = remotes:FindFirstChild("ResumeRoom")
					if resumeRemote and resumeRemote:IsA("RemoteFunction") then
						local ok, result = pcall(function() return resumeRemote:InvokeServer(save) end)
						if ok and result and result.error then
							warn("[App] ResumeRoom error:", result.error)
						end
					end
				end)
			end,
			onDeleteSave = onDeleteSave,
		})

		-- Resume prompt overlay for multiplayer lobby
		if showResumePrompt and savedPuzzles and #savedPuzzles > 0 then
			safeChildren["ResumePrompt"] = React.createElement(ResumePromptModal, {
				savedPuzzles = savedPuzzles,
				onResume = onResumeFromPrompt,
				onNewPuzzle = onStartFresh,
			})
		end
	end

	-- Room code badge overlay (visible during lobby and playing)
	if gameState == "room_playing" and roomInfo and roomInfo.roomId then
		safeChildren["RoomCodeBadge"] = React.createElement("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 8),
			Size = UDim2.fromOffset(200, 56),
			BackgroundColor3 = Theme.Colors.bgElevated,
			ZIndex = 120,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Stroke = React.createElement("UIStroke", {
				Thickness = 1.5,
				Color = Theme.Colors.border,
			}),
			Label = React.createElement("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "Code: " .. roomInfo.roomId,
				TextColor3 = Theme.Colors.accentCyan,
				TextScaled = true,
				Font = Theme.Font.bold,
				ZIndex = 121,
			}, {
				Padding = React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
					PaddingTop = UDim.new(0, 6),
					PaddingBottom = UDim.new(0, 6),
				}),
			}),
		})
	end

	-- Board ScreenGui: full screen for piece dragging (rendered below safe UI)
	-- Spin wheel ScreenGui: ignores top bar so it sits at the very top
	local spinGui = nil
	if spinWheelElement or starterPackElement then
		spinGui = React.createElement("ScreenGui", {
			Name = "PuzzleAppSpin",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ScreenInsets = Enum.ScreenInsets.None,
			DisplayOrder = 2,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		}, {
			SpinWheelBtn = spinWheelElement,
			StarterPackBtn = starterPackElement,
		})
	end

	local boardGui = nil
	local isMultiplayerBoard = gameState == "room_playing" or gameState == "room_complete"
		or (gameState == "admiring" and admireIsMultiplayer)
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
				onBackToMenu = if isMultiplayerBoard then onMpBackToMenu else onBackToMenu,
				onSaveContinue = if isMultiplayerBoard then onMpSaveContinue else onSaveContinue,
				savedState = if isMultiplayerBoard then nil else resumeState,
				equippedBoardSkin = if playerData then playerData.equippedBoardSkin else nil,
				equippedSnapEffect = if playerData then playerData.equippedSnapEffect else nil,
				ownedSnapEffects = if playerData then playerData.ownedSnapEffects else nil,
				onEquip = onEquip,
				playerData = playerData,
				hintsRemaining = if playerData then playerData.hintsRemaining else 0,
				onHintUsed = onHintUsed,
				cashBoostsRemaining = if playerData then playerData.cashBoostsRemaining else 0,
				isMultiplayer = isMultiplayerBoard,
				roomPlayers = if isMultiplayerBoard and roomInfo then roomInfo.players else nil,
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
				onLeave = if gameState == "room_complete" then onLeaveRoom else nil,
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
				Size = UDim2.new(0, 240, 0, if admireIsMultiplayer then 168 else 110),
				BackgroundTransparency = 1,
			}, {
				Layout = React.createElement("UIListLayout", {
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 10),
				}),
				BackButton = React.createElement("TextButton", {
					LayoutOrder = 1,
					Size = UDim2.new(0, 220, 0, 48),
					BackgroundColor3 = Theme.Colors.bgMuted,
					Text = if admireIsMultiplayer then "Back to Lobby" else "Back to Menu",
					TextColor3 = Theme.Colors.textPrimary,
					TextSize = Theme.TextSize.large,
					Font = Theme.Font.bold,
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
				LeaveTableButton = if admireIsMultiplayer then React.createElement("TextButton", {
					LayoutOrder = 2,
					Size = UDim2.new(0, 220, 0, 48),
					BackgroundColor3 = Theme.Colors.danger,
					Text = "Leave Table",
					TextColor3 = Theme.Colors.textPrimary,
					TextSize = Theme.TextSize.large,
					Font = Theme.Font.bold,
					[React.Event.Activated] = function()
						onLeaveRoom()
					end,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
					Stroke = React.createElement("UIStroke", {
						Color = Theme.Colors.dangerDark,
						Thickness = 2,
					}),
				}) else nil,
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
			Active = false,
		}, safeChildren),
	})

	-- New item notification ScreenGui (DisplayOrder=3 so it's always on top)
	local notificationGui = nil
	if newItemNotification ~= nil then
		notificationGui = React.createElement("ScreenGui", {
			Name = "PuzzleAppNotification",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ScreenInsets = Enum.ScreenInsets.None,
			DisplayOrder = 3,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		}, {
			Notification = React.createElement(NewItemNotification, {
				item = newItemNotification,
				equippedConfettiStyle = if playerData then playerData.equippedConfettiStyle else nil,
				onDismiss = onDismissNotification,
			}),
		})
	end

	-- Portal each ScreenGui into playerGui so React doesn't manage playerGui
	-- directly (which would destroy Roblox's TouchGui, Freecam, etc.)
	return React.createElement(React.Fragment, nil, {
		SafeGui = ReactRoblox.createPortal(safeGui, playerGui, "SafeGui"),
		SpinGui = spinGui and ReactRoblox.createPortal(spinGui, playerGui, "SpinGui") or nil,
		BoardGui = boardGui and ReactRoblox.createPortal(boardGui, playerGui, "BoardGui") or nil,
		CompleteGui = completeGui and ReactRoblox.createPortal(completeGui, playerGui, "CompleteGui") or nil,
		AdmireGui = admireGui and ReactRoblox.createPortal(admireGui, playerGui, "AdmireGui") or nil,
		NotificationGui = notificationGui and ReactRoblox.createPortal(notificationGui, playerGui, "NotificationGui") or nil,
	})
end

return App
