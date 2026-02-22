local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)

local PuzzleGenerator = require(Shared.PuzzleGenerator)
local ImageService = require(script.Parent.Parent.Parent.services.ImageService)
local PieceMasker = require(script.Parent.Parent.Parent.services.PieceMasker)
local SoundService = require(script.Parent.Parent.Parent.services.SoundService)

local RoomTypes = require(Shared.RoomTypes)
local ShopItems = require(Shared.ShopItems)

local PuzzlePiece = require(script.Parent.PuzzlePiece)
local usePuzzleState = require(script.Parent.Parent.hooks.usePuzzleState)
local useMultiplayerPuzzle = require(script.Parent.Parent.hooks.useMultiplayerPuzzle)
local useTimer = require(script.Parent.Parent.hooks.useTimer)

export type PuzzleBoardProps = {
	imageAssetId: string,
	imageId: string,
	difficultyId: string,
	rows: number,
	cols: number,
	onComplete: (elapsedSeconds: number) -> (),
	onGiveUp: (() -> ())?,
	onBackToMenu: ((saveData: any) -> ())?,
	savedState: any?,
	equippedBoardSkin: string?,
	hintsRemaining: number?,
	onHintUsed: (() -> ())?,
	isMultiplayer: boolean?,
	roomPuzzleDef: any?,
	roomInitialPieces: any?,
}

local BOARD_MAX_SIZE = 600

local function formatTime(seconds: number): string
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%d:%02d", mins, secs)
end

local PLAYER_COLORS = {
	Color3.fromRGB(80, 180, 230),
	Color3.fromRGB(230, 140, 80),
	Color3.fromRGB(80, 230, 140),
	Color3.fromRGB(230, 80, 180),
}

local function PuzzleBoard(props: PuzzleBoardProps)
	local soloState, soloActions = usePuzzleState()
	local mpState, mpActions = useMultiplayerPuzzle(props.roomInitialPieces)
	local state = if props.isMultiplayer then mpState else soloState
	local actions = if props.isMultiplayer then mpActions else soloActions
	local timer = useTimer()
	local localHints, setLocalHints = React.useState(props.hintsRemaining or 0)
	local localUserId = game:GetService("Players").LocalPlayer and game:GetService("Players").LocalPlayer.UserId or 0

	-- Dynamic top inset to clear Roblox top bar in full-screen ScreenGui
	local topInset = React.useMemo(function()
		local insetStart, _ = GuiService:GetGuiInset()
		return math.max(insetStart.Y, 44) + 8
	end, {})
	local hoveredPieceIds, setHoveredPieceIds = React.useState({} :: { [number]: boolean })
	local showEdgesOnly, setShowEdgesOnly = React.useState(false)
	local pieceImages, setPieceImages = React.useState(nil :: { [number]: any }?)
	local puzzleDef, setPuzzleDef = React.useState(nil :: any)
	local isLoading, setIsLoading = React.useState(true)
	local boardSize, setBoardSize = React.useState(Vector2.new(800, 800))
	local cellSize, setCellSize = React.useState(Vector2.new(100, 100))
	local pixelScale, setPixelScale = React.useState(1)

	-- Ref to track group follower offsets during drag
	local groupDragOffsets = React.useRef({})

	-- Load image and generate/restore puzzle on mount
	React.useEffect(function()
		setIsLoading(true)
		timer.reset()

		task.spawn(function()
			local sourceImage, sourceWidth, sourceHeight = ImageService.loadImage(props.imageAssetId)
			if not sourceImage then
				warn("[PuzzleBoard] Failed to load image")
				setIsLoading(false)
				return
			end

			local puzzle
			if props.isMultiplayer and props.roomPuzzleDef then
				puzzle = props.roomPuzzleDef
			elseif props.savedState then
				-- Use saved puzzleDef instead of generating new
				puzzle = props.savedState.puzzleDef
			else
				puzzle = PuzzleGenerator.generatePuzzle(props.rows, props.cols)
			end
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

			if props.isMultiplayer then
				-- Multiplayer: pieces are initialized by the useMultiplayerPuzzle hook
				-- No scramble or restore needed
			elseif props.savedState then
				-- Restore piece positions and timer from saved state
				actions.restorePieces(props.savedState.pieces, props.savedState.groups)
				timer.restore(props.savedState.elapsedSeconds)
			else
				local pieceIds = {}
				for _, piece in puzzle.pieces do
					table.insert(pieceIds, piece.id)
				end

				local camera = workspace.CurrentCamera
				local viewportW = if camera then camera.ViewportSize.X else 1200
				local viewportH = if camera then camera.ViewportSize.Y else 800

				local bOffX = math.floor((viewportW - displayBoardW) / 2)
				local bOffY = math.floor((viewportH - displayBoardH) / 2)

				actions.scramblePieces(
					pieceIds,
					viewportW,
					viewportH,
					bOffX,
					bOffY,
					displayBoardW,
					displayBoardH
				)
			end

			sourceImage:Destroy()
			setIsLoading(false)
			timer.start()
		end)
	end, { props.imageAssetId, props.rows, props.cols } :: { any })

	-- Watch for completion
	React.useEffect(function()
		if state.isComplete then
			timer.stop()
			SoundService.playComplete()
			props.onComplete(timer.elapsedSeconds)
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

	-- Convert screen image position → virtual cell position (for sending to server)
	local function screenToVirtual(screenX: number, screenY: number, imgOffsetX: number, imgOffsetY: number)
		-- Add tab offset: image pos → cell pos
		local cellX = screenX + imgOffsetX
		local cellY = screenY + imgOffsetY
		-- Map board-relative screen position to virtual canvas
		local vw = RoomTypes.VIRTUAL_CANVAS_WIDTH
		local vh = RoomTypes.VIRTUAL_CANVAS_HEIGHT
		return (cellX - boardOffsetX) / boardSize.X * vw,
			(cellY - boardOffsetY) / boardSize.Y * vh
	end

	-- Convert virtual cell position → screen image position (for display)
	local function virtualToScreen(virtualX: number, virtualY: number, imgOffsetX: number, imgOffsetY: number)
		local vw = RoomTypes.VIRTUAL_CANVAS_WIDTH
		local vh = RoomTypes.VIRTUAL_CANVAS_HEIGHT
		local cellX = virtualX / vw * boardSize.X + boardOffsetX
		local cellY = virtualY / vh * boardSize.Y + boardOffsetY
		-- Subtract tab offset: cell pos → image pos
		return cellX - imgOffsetX, cellY - imgOffsetY
	end

	local function onPieceHoverStart(pieceId: number)
		setHoveredPieceIds(function(prev)
			local next = table.clone(prev)
			next[pieceId] = true
			return next
		end)
	end

	local function onPieceHoverEnd(pieceId: number)
		setHoveredPieceIds(function(prev)
			local next = table.clone(prev)
			next[pieceId] = nil
			return next
		end)
	end

	local function onDragStart(pieceId: number)
		actions.bringToFront(pieceId)
		SoundService.playPickup()
		if props.isMultiplayer and actions.claimPiece then
			actions.claimPiece(pieceId)
		end

		-- Compute group follower offsets for drag (in screen coords)
		local piece = state.pieces[pieceId]
		local groupId = piece and piece.groupId
		if groupId and state.groups and state.groups[groupId] then
			local offsets = {}
			if props.isMultiplayer and pieceImages then
				-- Multiplayer: piece positions are virtual coords, convert to screen for offsets
				local dragImg = pieceImages[pieceId]
				if dragImg then
					local dragSox = math.floor(dragImg.offsetX * pixelScale)
					local dragSoy = math.floor(dragImg.offsetY * pixelScale)
					local dragScreenX, dragScreenY = virtualToScreen(piece.x, piece.y, dragSox, dragSoy)
					for _, memberId in state.groups[groupId] do
						if memberId ~= pieceId then
							local memberPiece = state.pieces[memberId]
							local memberImg = pieceImages[memberId]
							if memberPiece and memberImg then
								local mSox = math.floor(memberImg.offsetX * pixelScale)
								local mSoy = math.floor(memberImg.offsetY * pixelScale)
								local mScreenX, mScreenY = virtualToScreen(memberPiece.x, memberPiece.y, mSox, mSoy)
								offsets[memberId] = {
									dx = mScreenX - dragScreenX,
									dy = mScreenY - dragScreenY,
								}
							end
						end
					end
				end
			else
				-- Solo: positions are already screen coords
				for _, memberId in state.groups[groupId] do
					if memberId ~= pieceId then
						local memberPiece = state.pieces[memberId]
						if memberPiece then
							offsets[memberId] = {
								dx = memberPiece.x - piece.x,
								dy = memberPiece.y - piece.y,
							}
						end
					end
				end
			end
			groupDragOffsets.current = offsets
		else
			groupDragOffsets.current = {}
		end
	end

	local function onDragMove(pieceId: number, x: number, y: number)
		if props.isMultiplayer and pieceImages then
			-- Multiplayer: move followers locally (server handles their network broadcast)
			for memberId, offset in groupDragOffsets.current do
				local memberImg = pieceImages[memberId]
				if memberImg and actions.movePieceLocal then
					local mSox = math.floor(memberImg.offsetX * pixelScale)
					local mSoy = math.floor(memberImg.offsetY * pixelScale)
					local mvx, mvy = screenToVirtual(x + offset.dx, y + offset.dy, mSox, mSoy)
					actions.movePieceLocal(memberId, mvx, mvy)
				end
			end
			-- Send dragged piece to server
			local imageData = pieceImages[pieceId]
			if imageData then
				local sox = math.floor(imageData.offsetX * pixelScale)
				local soy = math.floor(imageData.offsetY * pixelScale)
				local vx, vy = screenToVirtual(x, y, sox, soy)
				actions.movePiece(pieceId, vx, vy)
			end
		else
			-- Solo: move all followers via movePiece (screen coords)
			for memberId, offset in groupDragOffsets.current do
				actions.movePiece(memberId, x + offset.dx, y + offset.dy)
			end
		end
	end

	local function onDragEnd(pieceId: number, x: number, y: number)
		groupDragOffsets.current = {}

		-- Always persist drop position to state so it stays in sync
		-- (prevents snap-back via initialPosition effect and fixes save/restore)
		if not props.isMultiplayer then
			actions.movePiece(pieceId, x, y)
		end

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

		if props.isMultiplayer then
			local vx, vy = screenToVirtual(x, y, scaledOffsetX, scaledOffsetY)
			actions.trySnap(pieceId, vx, vy, 0, 0)
			-- Hook always returns false; server handles snap sound via events
		else
			local snapped = actions.trySnap(
				pieceId, x, y, correctX, correctY,
				puzzleDef, pieceImages, cellSize, pixelScale, boardOffsetX, boardOffsetY
			)
			if snapped then
				SoundService.playSnap()
			end
		end
	end

	-- Compute board colors from equipped skin
	local boardBgColor = Color3.fromRGB(25, 25, 35)
	local gridBgColor = Color3.fromRGB(40, 40, 50)
	if props.equippedBoardSkin and props.equippedBoardSkin ~= "" then
		local skin = ShopItems.getById(props.equippedBoardSkin)
		if skin and skin.previewColor then
			boardBgColor = skin.previewColor
			local h, s, v = boardBgColor:ToHSV()
			gridBgColor = Color3.fromHSV(h, s, math.min(v + 0.1, 1))
		end
	end

	local children: { [string]: any } = {}

	-- Timer display (top-center)
	if not isLoading then
		children["Timer"] = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 4),
			Size = UDim2.fromOffset(120, 40),
			BackgroundColor3 = Color3.fromRGB(30, 30, 40),
			BackgroundTransparency = 0.3,
			Text = formatTime(timer.elapsedSeconds),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 28,
			Font = Enum.Font.GothamBold,
			ZIndex = 50,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Padding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
		})
	end

	-- Back to Menu and Give Up buttons (top-left, shown when not loading)
	if not isLoading then
		children["BackButton"] = React.createElement("TextButton", {
			Position = UDim2.new(0, 20, 0, topInset),
			Size = UDim2.fromOffset(130, 36),
			BackgroundColor3 = Color3.fromRGB(50, 50, 70),
			Text = if props.isMultiplayer then "< Leave Room" else "< Back to Menu",
			TextColor3 = Color3.fromRGB(220, 220, 240),
			TextSize = 14,
			Font = Enum.Font.GothamMedium,
			ZIndex = 50,
			[React.Event.Activated] = function()
				if props.isMultiplayer then
					-- In multiplayer, just give up (no save)
					if props.onGiveUp then
						props.onGiveUp()
					end
				elseif props.onBackToMenu and puzzleDef then
					timer.stop()
					local savePieces = {}
					for id, p in state.pieces do
						table.insert(savePieces, {
							id = id, x = p.x, y = p.y,
							zIndex = p.zIndex, locked = p.locked,
						groupId = p.groupId,
						})
					end
					local saveGroups = {}
					for gid, memberIds in state.groups do
						table.insert(saveGroups, { id = gid, pieceIds = memberIds })
					end
					props.onBackToMenu({
						imageId = props.imageId,
						imageAssetId = props.imageAssetId,
						difficultyId = props.difficultyId,
						rows = props.rows,
						cols = props.cols,
						elapsedSeconds = timer.elapsedSeconds,
						savedAt = os.time(),
						puzzleDef = puzzleDef,
						pieces = savePieces,
						groups = saveGroups,
					})
				end
			end,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
		})

		children["GiveUpButton"] = React.createElement("TextButton", {
			Position = UDim2.new(0, 160, 0, topInset),
			Size = UDim2.fromOffset(80, 36),
			BackgroundColor3 = Color3.fromRGB(160, 50, 50),
			Text = "Give Up",
			TextColor3 = Color3.fromRGB(255, 220, 220),
			TextSize = 14,
			Font = Enum.Font.GothamMedium,
			ZIndex = 50,
			[React.Event.Activated] = function()
				if props.onGiveUp then
					props.onGiveUp()
				end
			end,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
		})

		children["EdgesOnlyButton"] = React.createElement("TextButton", {
			Position = UDim2.new(0, 250, 0, topInset),
			Size = UDim2.fromOffset(100, 36),
			BackgroundColor3 = if showEdgesOnly then Color3.fromRGB(50, 120, 80) else Color3.fromRGB(50, 50, 70),
			Text = if showEdgesOnly then "Show All" else "Edges Only",
			TextColor3 = Color3.fromRGB(220, 220, 240),
			TextSize = 14,
			Font = Enum.Font.GothamMedium,
			ZIndex = 50,
			[React.Event.Activated] = function()
				setShowEdgesOnly(function(prev) return not prev end)
			end,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
		})

		-- Hint button (disabled in multiplayer)
		if not props.isMultiplayer and localHints > 0 and puzzleDef and pieceImages then
			children["HintButton"] = React.createElement("TextButton", {
				Position = UDim2.new(0, 360, 0, topInset),
				Size = UDim2.fromOffset(110, 36),
				BackgroundColor3 = Color3.fromRGB(200, 160, 50),
				Text = "Hint (" .. localHints .. ")",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 14,
				Font = Enum.Font.GothamMedium,
				ZIndex = 50,
				[React.Event.Activated] = function()
					if localHints <= 0 or not puzzleDef or not pieceImages then return end

					-- Find a random unlocked piece
					local unlockedIds = {}
					for _, pieceDef in puzzleDef.pieces do
						local ps = state.pieces[pieceDef.id]
						if ps and not ps.locked then
							table.insert(unlockedIds, pieceDef.id)
						end
					end
					if #unlockedIds == 0 then return end

					local targetId = unlockedIds[math.random(1, #unlockedIds)]
					local targetDef = nil
					for _, p in puzzleDef.pieces do
						if p.id == targetId then
							targetDef = p
							break
						end
					end
					if not targetDef then return end

					-- Compute correct position
					local imageData = pieceImages[targetId]
					local scaledOffsetX = math.floor(imageData.offsetX * pixelScale)
					local scaledOffsetY = math.floor(imageData.offsetY * pixelScale)
					local correctX = boardOffsetX + (targetDef.col - 1) * cellSize.X - scaledOffsetX
					local correctY = boardOffsetY + (targetDef.row - 1) * cellSize.Y - scaledOffsetY

					actions.snapPiece(targetId, correctX, correctY)
					SoundService.playSnap()

					setLocalHints(function(prev) return math.max(0, prev - 1) end)
					if props.onHintUsed then
						props.onHintUsed()
					end

					-- Tell server
					task.spawn(function()
						local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
						if not remotes then return end
						local useHint = remotes:FindFirstChild("UseHint")
						if useHint and useHint:IsA("RemoteFunction") then
							pcall(function() useHint:InvokeServer() end)
						end
					end)
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
			})
		end
	end

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
			BackgroundColor3 = gridBgColor,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			ZIndex = 0,
		}, gridCells)

		-- Compute topmost hovered piece
		local topmostHoveredId = nil
		local topmostZ = -1
		for id in hoveredPieceIds do
			local ps = state.pieces[id]
			if ps and not ps.locked and ps.zIndex > topmostZ then
				topmostZ = ps.zIndex
				topmostHoveredId = id
			end
		end

		-- Render puzzle pieces
		if pieceImages and puzzleDef then
			for _, pieceDef in puzzleDef.pieces do
				local pieceId = pieceDef.id
				local pieceState = state.pieces[pieceId]
				local imageData = pieceImages[pieceId]

				if pieceState and imageData then
					-- Hide non-edge pieces when showEdgesOnly is active (locked pieces always stay visible)
					if showEdgesOnly and not pieceState.locked then
						local isEdge = pieceDef.edges.top == "flat"
							or pieceDef.edges.bottom == "flat"
							or pieceDef.edges.left == "flat"
							or pieceDef.edges.right == "flat"
						if not isEdge then
							continue
						end
					end
					local displayW = math.floor(imageData.width * pixelScale)
					local displayH = math.floor(imageData.height * pixelScale)

						-- Multiplayer claimed state
					local claimedByOther = false
					local claimerColor = nil
					if props.isMultiplayer and state.claimedPieces then
						local claimerId = state.claimedPieces[pieceId]
						if claimerId and claimerId ~= localUserId then
							claimedByOther = true
							claimerColor = PLAYER_COLORS[((claimerId % #PLAYER_COLORS)) + 1]
						end
					end

					-- In multiplayer, state stores virtual coords; convert to screen image position for display
					local displayX, displayY = pieceState.x, pieceState.y
					if props.isMultiplayer then
						local scaledOffX = math.floor(imageData.offsetX * pixelScale)
						local scaledOffY = math.floor(imageData.offsetY * pixelScale)
						displayX, displayY = virtualToScreen(pieceState.x, pieceState.y, scaledOffX, scaledOffY)
					end

					children["Piece_" .. pieceId] = React.createElement(PuzzlePiece, {
						pieceId = pieceId,
						editableImage = imageData.image,
						outlineImage = imageData.outlineImage,
						pieceWidth = displayW,
						pieceHeight = displayH,
						position = Vector2.new(displayX, displayY),
						zIndex = pieceState.zIndex,
						isLocked = pieceState.locked,
						isHovered = (pieceId == topmostHoveredId),
						onDragStart = onDragStart,
						onDragMove = onDragMove,
						onDragEnd = onDragEnd,
						onHoverStart = onPieceHoverStart,
						onHoverEnd = onPieceHoverEnd,
						claimedByOther = claimedByOther,
						claimerColor = claimerColor,
					})
				end
			end
		end
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = boardBgColor,
		BackgroundTransparency = 0,
	}, children)
end

return PuzzleBoard
