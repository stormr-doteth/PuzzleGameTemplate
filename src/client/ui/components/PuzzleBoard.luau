local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)

local PuzzleGenerator = require(Shared.PuzzleGenerator)
local ImageService = require(script.Parent.Parent.Parent.services.ImageService)
local PieceMasker = require(script.Parent.Parent.Parent.services.PieceMasker)
local SoundService = require(script.Parent.Parent.Parent.services.SoundService)

local PuzzlePiece = require(script.Parent.PuzzlePiece)
local usePuzzleState = require(script.Parent.Parent.hooks.usePuzzleState)

export type PuzzleBoardProps = {
	imageAssetId: string,
	rows: number,
	cols: number,
	onComplete: () -> (),
}

local BOARD_MAX_SIZE = 600

local function PuzzleBoard(props: PuzzleBoardProps)
	local state, actions = usePuzzleState()
	local pieceImages, setPieceImages = React.useState(nil :: { [number]: any }?)
	local puzzleDef, setPuzzleDef = React.useState(nil :: any)
	local isLoading, setIsLoading = React.useState(true)
	local boardSize, setBoardSize = React.useState(Vector2.new(800, 800))
	local cellSize, setCellSize = React.useState(Vector2.new(100, 100))
	local pixelScale, setPixelScale = React.useState(1)

	-- Load image and generate puzzle on mount
	React.useEffect(function()
		setIsLoading(true)

		task.spawn(function()
			local sourceImage, sourceWidth, sourceHeight = ImageService.loadImage(props.imageAssetId)
			if not sourceImage then
				warn("[PuzzleBoard] Failed to load image")
				setIsLoading(false)
				return
			end

			local puzzle = PuzzleGenerator.generatePuzzle(props.rows, props.cols)
			setPuzzleDef(puzzle)

			local images = PieceMasker.createPieceImages(
				sourceImage, sourceWidth, sourceHeight, puzzle
			)
			setPieceImages(images)

			-- Calculate display sizes
			local sourceCellW = math.floor(sourceWidth / props.cols)
			local sourceCellH = math.floor(sourceHeight / props.rows)

			local scale = math.min(
				BOARD_MAX_SIZE / sourceWidth,
				BOARD_MAX_SIZE / sourceHeight,
				1
			)
			setPixelScale(scale)

			local displayCellW = math.floor(sourceCellW * scale)
			local displayCellH = math.floor(sourceCellH * scale)
			local displayBoardW = displayCellW * props.cols
			local displayBoardH = displayCellH * props.rows

			setCellSize(Vector2.new(displayCellW, displayCellH))
			setBoardSize(Vector2.new(displayBoardW, displayBoardH))

			local pieceIds = {}
			for _, piece in puzzle.pieces do
				table.insert(pieceIds, piece.id)
			end

			local camera = workspace.CurrentCamera
			local viewportW = if camera then camera.ViewportSize.X else 1200
			local viewportH = if camera then camera.ViewportSize.Y else 800

			actions.scramblePieces(
				pieceIds,
				viewportW - displayCellW,
				viewportH - displayCellH,
				displayCellW,
				displayCellH
			)

			sourceImage:Destroy()
			setIsLoading(false)
		end)
	end, { props.imageAssetId, props.rows, props.cols } :: { any })

	-- Watch for completion
	React.useEffect(function()
		if state.isComplete then
			SoundService.playComplete()
			props.onComplete()
		end
	end, { state.isComplete })

	-- Board position (centered on screen)
	local boardOffsetX = React.useMemo(function()
		local camera = workspace.CurrentCamera
		local viewportW = if camera then camera.ViewportSize.X else 1200
		return math.floor((viewportW - boardSize.X) / 2)
	end, { boardSize } :: { any })

	local boardOffsetY = React.useMemo(function()
		local camera = workspace.CurrentCamera
		local viewportH = if camera then camera.ViewportSize.Y else 800
		return math.floor((viewportH - boardSize.Y) / 2)
	end, { boardSize } :: { any })

	local function onDragStart(pieceId: number)
		actions.bringToFront(pieceId)
		SoundService.playPickup()
	end

	local function onDragEnd(pieceId: number, x: number, y: number)
		if not puzzleDef or not pieceImages then
			return
		end

		local pieceDef = nil
		for _, p in puzzleDef.pieces do
			if p.id == pieceId then
				pieceDef = p
				break
			end
		end
		if not pieceDef then return end

		-- Correct screen position accounts for the piece's tab offset
		local imageData = pieceImages[pieceId]
		local scaledOffsetX = math.floor(imageData.offsetX * pixelScale)
		local scaledOffsetY = math.floor(imageData.offsetY * pixelScale)
		local correctX = boardOffsetX + (pieceDef.col - 1) * cellSize.X - scaledOffsetX
		local correctY = boardOffsetY + (pieceDef.row - 1) * cellSize.Y - scaledOffsetY

		local snapped = actions.trySnap(pieceId, x, y, correctX, correctY)
		if snapped then
			SoundService.playSnap()
		end
	end

	local children: { [string]: any } = {}

	if isLoading then
		children["Loading"] = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(300, 50),
			BackgroundTransparency = 1,
			Text = "Loading puzzle...",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 28,
			Font = Enum.Font.GothamMedium,
		})
	else
		-- Grid outline showing target positions
		local gridCells: { [string]: any } = {
			Border = React.createElement("UIStroke", {
				Color = Color3.fromRGB(80, 80, 100),
				Thickness = 2,
			}),
			Grid = React.createElement("UIGridLayout", {
				CellSize = UDim2.fromOffset(cellSize.X, cellSize.Y),
				CellPadding = UDim2.fromOffset(0, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		for i = 1, props.rows * props.cols do
			gridCells["Cell_" .. i] = React.createElement("Frame", {
				LayoutOrder = i,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, {
				Stroke = React.createElement("UIStroke", {
					Color = Color3.fromRGB(60, 60, 75),
					Thickness = 1,
					Transparency = 0.5,
				}),
			})
		end

		children["GridOutline"] = React.createElement("Frame", {
			Position = UDim2.fromOffset(boardOffsetX, boardOffsetY),
			Size = UDim2.fromOffset(boardSize.X, boardSize.Y),
			BackgroundColor3 = Color3.fromRGB(40, 40, 50),
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			ZIndex = 0,
		}, gridCells)

		-- Render puzzle pieces
		if pieceImages and puzzleDef then
			for _, pieceDef in puzzleDef.pieces do
				local pieceId = pieceDef.id
				local pieceState = state.pieces[pieceId]
				local imageData = pieceImages[pieceId]

				if pieceState and imageData then
					local displayW = math.floor(imageData.width * pixelScale)
					local displayH = math.floor(imageData.height * pixelScale)

					children["Piece_" .. pieceId] = React.createElement(PuzzlePiece, {
						pieceId = pieceId,
						editableImage = imageData.image,
						pieceWidth = displayW,
						pieceHeight = displayH,
						position = Vector2.new(pieceState.x, pieceState.y),
						zIndex = pieceState.zIndex,
						isLocked = pieceState.locked,
						onDragStart = onDragStart,
						onDragEnd = onDragEnd,
					})
				end
			end
		end
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(25, 25, 35),
		BackgroundTransparency = 0,
	}, children)
end

return PuzzleBoard
