local CaptureService = game:GetService("CaptureService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)

local MenuScreen = require(script.Parent.components.MenuScreen)
local PuzzleBoard = require(script.Parent.components.PuzzleBoard)
local CompleteScreen = require(script.Parent.components.CompleteScreen)

-- XPBar loaded optionally (created in Phase 2)
local XPBar = nil
pcall(function()
	XPBar = require(script.Parent.components.XPBar)
end)

type GameState = "menu" | "playing" | "complete" | "admiring"

local function App()
	local gameState, setGameState = React.useState("menu" :: GameState)
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
		setGameState("menu")
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

	local function onPlayAgain()
		setGameState("menu")
		setRewardData(nil)
	end

	local function onAdmire()
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
	end

	-- Board ScreenGui: full screen for piece dragging (rendered below safe UI)
	local boardGui = nil
	if gameState == "playing" or gameState == "complete" or gameState == "admiring" then
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
				onComplete = onComplete,
				onGiveUp = onGiveUp,
				onBackToMenu = onBackToMenu,
				savedState = resumeState,
				equippedBoardSkin = if playerData then playerData.equippedBoardSkin else nil,
				hintsRemaining = if playerData then playerData.hintsRemaining else 0,
				onHintUsed = onHintUsed,
			}),
		})
	end

	-- Complete ScreenGui: full screen so confetti ignores top bar
	local completeGui = nil
	if gameState == "complete" then
		completeGui = React.createElement("ScreenGui", {
			Name = "PuzzleAppComplete",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ScreenInsets = Enum.ScreenInsets.None,
			DisplayOrder = 2,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		}, {
			Complete = React.createElement(CompleteScreen, {
				onPlayAgain = onPlayAgain,
				onAdmire = onAdmire,
				completionTime = completionTime,
				rewardData = rewardData,
				isPersonalBest = if rewardData then rewardData.isPersonalBest else false,
				previousBest = if rewardData then rewardData.previousBest else nil,
				equippedConfettiStyle = if playerData then playerData.equippedConfettiStyle else nil,
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
					Text = "Back to Menu",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 22,
					Font = Enum.Font.GothamBold,
					[React.Event.Activated] = function()
						onPlayAgain()
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
