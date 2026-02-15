local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

local MenuScreen = require(script.Parent.components.MenuScreen)
local PuzzleBoard = require(script.Parent.components.PuzzleBoard)
local CompleteScreen = require(script.Parent.components.CompleteScreen)

-- Hardcoded test image asset (replace with your own uploaded image)
local DEFAULT_IMAGE_ASSET = "rbxassetid://129720055698342"

type GameState = "menu" | "playing" | "complete"

local function App()
	local gameState, setGameState = React.useState("menu" :: GameState)
	local rows, setRows = React.useState(3)
	local cols, setCols = React.useState(3)

	local function onStart(selectedRows: number, selectedCols: number)
		setRows(selectedRows)
		setCols(selectedCols)
		setGameState("playing")
	end

	local function onComplete()
		setGameState("complete")
	end

	local function onPlayAgain()
		setGameState("menu")
	end

	local children: { [string]: any } = {}

	if gameState == "menu" then
		children["Menu"] = React.createElement(MenuScreen, {
			onStart = onStart,
		})
	elseif gameState == "playing" or gameState == "complete" then
		children["Board"] = React.createElement(PuzzleBoard, {
			imageAssetId = DEFAULT_IMAGE_ASSET,
			rows = rows,
			cols = cols,
			onComplete = onComplete,
		})
		if gameState == "complete" then
			children["CompleteOverlay"] = React.createElement(CompleteScreen, {
				onPlayAgain = onPlayAgain,
			})
		end
	end

	return React.createElement("ScreenGui", {
		Name = "PuzzleApp",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, children)
end

return App
