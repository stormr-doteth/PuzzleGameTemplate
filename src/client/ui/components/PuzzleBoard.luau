local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)

local PuzzleGenerator = require(Shared.PuzzleGenerator)
local ImageService = require(script.Parent.Parent.Parent.services.ImageService)
local PieceMasker = require(script.Parent.Parent.Parent.services.PieceMasker)
local SoundService = require(script.Parent.Parent.Parent.services.SoundService)

local MonetizationConfig = require(Shared.MonetizationConfig)
local Remotes = require(Shared.Remotes)
local RoomTypes = require(Shared.RoomTypes)
local ShopItems = require(Shared.ShopItems)
local Theme = require(Shared.Theme)

local PuzzlePiece = require(script.Parent.PuzzlePiece)
local SnapEffect = require(script.Parent.SnapEffect)
local usePuzzleState = require(script.Parent.Parent.hooks.usePuzzleState)
local useMultiplayerPuzzle = require(script.Parent.Parent.hooks.useMultiplayerPuzzle)
local useTimer = require(script.Parent.Parent.hooks.useTimer)
local useZoomPan = require(script.Parent.Parent.hooks.useZoomPan)

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
	equippedSnapEffect: string?,
	isMultiplayer: boolean?,
	roomPuzzleDef: any?,
	roomInitialPieces: any?,
}

local BOARD_MAX_SIZE_CAP = 600

local function getBoardMaxSize(topInsetValue: number): number
	local camera = workspace.CurrentCamera
	local viewportW = if camera then camera.ViewportSize.X else 1200
	local viewportH = if camera then camera.ViewportSize.Y else 800

	local usableH = viewportH - topInsetValue
	local maxFromW = viewportW * 0.6
	local maxFromH = usableH * 0.7

	return math.min(maxFromW, maxFromH, BOARD_MAX_SIZE_CAP)
end

local function formatTime(seconds: number): string
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%d:%02d", mins, secs)
end

local PLAYER_COLORS = {
	Theme.Colors.player1,
	Theme.Colors.player2,
	Theme.Colors.player3,
	Theme.Colors.player4,
}

local function PuzzleBoard(props: PuzzleBoardProps)
	local soloState, soloActions = usePuzzleState()
	local mpState, mpActions = useMultiplayerPuzzle(props.roomInitialPieces)
	local state = if props.isMultiplayer then mpState else soloState
	local actions = if props.isMultiplayer then mpActions else soloActions
	local timer = useTimer()
	local zoomState, zoomActions = useZoomPan()
	local loadError, setLoadError = React.useState(false)
	local localHints, setLocalHints = React.useState(props.hintsRemaining or 0)
	local localUserId = Players.LocalPlayer and Players.LocalPlayer.UserId or 0
	local snapEffects, setSnapEffects = React.useState({} :: { { positionX: number, positionY: number, key: string, effectId: string } })
	local snapEffectCounter = React.useRef(0)
	local showSavePrompt, setShowSavePrompt = React.useState(false)
	local hintHighlightId, setHintHighlightId = React.useState(nil :: number?)
	local showArtworkModal, setShowArtworkModal = React.useState(false)
	local ownsPuzzleAssist, setOwnsPuzzleAssist = React.useState(false)
	local showAssistOverlay, setShowAssistOverlay = React.useState(false)

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

	-- Refs for direct frame manipulation of group followers during drag
	local pieceFrameRefs = React.useRef({} :: { [number]: ImageLabel })
	local followerPositionsRef = React.useRef({} :: { [number]: { x: number, y: number } })

	-- Refs for current values (so useCallback closures always see latest state)
	local stateRef = React.useRef(state)
	local puzzleDefRef = React.useRef(puzzleDef)
	local pieceImagesRef = React.useRef(pieceImages)
	local pixelScaleRef = React.useRef(pixelScale)
	local cellSizeRef = React.useRef(cellSize)
	local boardSizeRef = React.useRef(boardSize)
	local zoomActionsRef = React.useRef(zoomActions)
	local zoomStateRef = React.useRef(zoomState)
	local actionsRef = React.useRef(actions)

	-- Update refs each render (cheap, no allocations)
	stateRef.current = state
	puzzleDefRef.current = puzzleDef
	pieceImagesRef.current = pieceImages
	pixelScaleRef.current = pixelScale
	cellSizeRef.current = cellSize
	boardSizeRef.current = boardSize
	zoomActionsRef.current = zoomActions
	zoomStateRef.current = zoomState
	actionsRef.current = actions

	-- Load image and generate/restore puzzle on mount
	React.useEffect(function()
		setIsLoading(true)
		timer.reset()

		task.spawn(function()
			local sourceImage, sourceWidth, sourceHeight = ImageService.loadImage(props.imageAssetId)
			if not sourceImage then
				warn("[PuzzleBoard] Failed to load image")
				setLoadError(true)
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

			local boardMaxSize = getBoardMaxSize(topInset)

			local scale = math.min(
				boardMaxSize / sourceWidth,
				boardMaxSize / sourceHeight,
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

				local piecePad = math.max(displayCellW, displayCellH) * 1.3
				actions.scramblePieces(
					pieceIds,
					viewportW,
					viewportH,
					bOffX,
					bOffY,
					displayBoardW,
					displayBoardH,
					piecePad,
					topInset
				)
			end

			sourceImage:Destroy()
			setIsLoading(false)
			timer.start()
		end)
	end, { props.imageAssetId, props.rows, props.cols } :: { any })

	-- Cleanup pieceImages on unmount to prevent memory leaks
	React.useEffect(function()
		return function()
			if pieceImages then
				for _, imgData in pieceImages do
					if imgData.image and typeof(imgData.image) == "Instance" then
						imgData.image:Destroy()
					end
					if imgData.outlineImage and typeof(imgData.outlineImage) == "Instance" then
						imgData.outlineImage:Destroy()
					end
				end
			end
		end
	end, { pieceImages } :: { any })

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

	-- Keep refs up to date for boardOffset (used in stable callbacks)
	local boardOffsetXRef = React.useRef(boardOffsetX)
	local boardOffsetYRef = React.useRef(boardOffsetY)
	boardOffsetXRef.current = boardOffsetX
	boardOffsetYRef.current = boardOffsetY

	-- Stable registerFrameRef callback for PuzzlePiece to register its frame
	local registerFrameRef = React.useCallback(function(pieceId: number, frame: ImageLabel?)
		if frame then
			pieceFrameRefs.current[pieceId] = frame
		else
			pieceFrameRefs.current[pieceId] = nil
		end
	end, {})

	-- Stable wrappers for zoom functions (useZoomPan creates new references every render,
	-- but the functions already use refs internally so delegating to .current is safe)
	local stableScreenToWorld = React.useCallback(function(screenX: number, screenY: number)
		return zoomActionsRef.current.screenToWorld(screenX, screenY)
	end, {})

	local stableWorldToScreen = React.useCallback(function(worldX: number, worldY: number)
		return zoomActionsRef.current.worldToScreen(worldX, worldY)
	end, {})

	-- Convert screen image position → virtual cell position (for sending to server)
	-- Uses refs so it works correctly inside stable useCallback closures
	local function screenToVirtual(screenX: number, screenY: number, imgOffsetX: number, imgOffsetY: number)
		local cellX = screenX + imgOffsetX
		local cellY = screenY + imgOffsetY
		local vw = RoomTypes.VIRTUAL_CANVAS_WIDTH
		local vh = RoomTypes.VIRTUAL_CANVAS_HEIGHT
		return (cellX - boardOffsetXRef.current) / boardSizeRef.current.X * vw,
			(cellY - boardOffsetYRef.current) / boardSizeRef.current.Y * vh
	end

	-- Convert virtual cell position → screen image position (for display)
	local function virtualToScreen(virtualX: number, virtualY: number, imgOffsetX: number, imgOffsetY: number)
		local vw = RoomTypes.VIRTUAL_CANVAS_WIDTH
		local vh = RoomTypes.VIRTUAL_CANVAS_HEIGHT
		local cellX = virtualX / vw * boardSizeRef.current.X + boardOffsetXRef.current
		local cellY = virtualY / vh * boardSizeRef.current.Y + boardOffsetYRef.current
		return cellX - imgOffsetX, cellY - imgOffsetY
	end

	local onPieceHoverStart = React.useCallback(function(pieceId: number)
		local pieceState = stateRef.current.pieces[pieceId]
		if pieceState and not pieceState.locked then
			SoundService.playHover()
		end
		setHoveredPieceIds(function(prev)
			local next = table.clone(prev)
			next[pieceId] = true
			return next
		end)
	end, {})

	local onPieceHoverEnd = React.useCallback(function(pieceId: number)
		setHoveredPieceIds(function(prev)
			local next = table.clone(prev)
			next[pieceId] = nil
			return next
		end)
	end, {})

	local onDragStart = React.useCallback(function(pieceId: number)
		actionsRef.current.bringToFront(pieceId)
		SoundService.playPickup()
		if props.isMultiplayer and actionsRef.current.claimPiece then
			actionsRef.current.claimPiece(pieceId)
		end

		-- Compute group follower offsets for drag (in screen coords)
		local curState = stateRef.current
		local curPieceImages = pieceImagesRef.current
		local curPixelScale = pixelScaleRef.current
		local piece = curState.pieces[pieceId]
		local groupId = piece and piece.groupId
		if groupId and curState.groups and curState.groups[groupId] then
			local offsets = {}
			if props.isMultiplayer and curPieceImages then
				-- Multiplayer: piece positions are virtual coords, convert to screen for offsets
				local dragImg = curPieceImages[pieceId]
				if dragImg then
					local dragSox = math.floor(dragImg.offsetX * curPixelScale)
					local dragSoy = math.floor(dragImg.offsetY * curPixelScale)
					local dragScreenX, dragScreenY = virtualToScreen(piece.x, piece.y, dragSox, dragSoy)
					for _, memberId in curState.groups[groupId] do
						if memberId ~= pieceId then
							local memberPiece = curState.pieces[memberId]
							local memberImg = curPieceImages[memberId]
							if memberPiece and memberImg then
								local mSox = math.floor(memberImg.offsetX * curPixelScale)
								local mSoy = math.floor(memberImg.offsetY * curPixelScale)
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
				for _, memberId in curState.groups[groupId] do
					if memberId ~= pieceId then
						local memberPiece = curState.pieces[memberId]
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
		followerPositionsRef.current = {}
	end, {})

	local onDragMove = React.useCallback(function(pieceId: number, x: number, y: number)
		local curPieceImages = pieceImagesRef.current
		local curPixelScale = pixelScaleRef.current
		if props.isMultiplayer and curPieceImages then
			-- Multiplayer: move followers directly via frame refs, send to server
			for memberId, offset in groupDragOffsets.current do
				local memberFrame = pieceFrameRefs.current[memberId]
				if memberFrame then
					local memberImg = curPieceImages[memberId]
					if memberImg then
						local mSox = math.floor(memberImg.offsetX * curPixelScale)
						local mSoy = math.floor(memberImg.offsetY * curPixelScale)
						local mvx, mvy = screenToVirtual(x + offset.dx, y + offset.dy, mSox, mSoy)
						-- Direct visual update: virtualToScreen gives world coords, apply zoom transform
						local worldX, worldY = virtualToScreen(mvx, mvy, mSox, mSoy)
						local sx, sy = worldX, worldY
						if zoomActionsRef.current.worldToScreen then
							sx, sy = zoomActionsRef.current.worldToScreen(worldX, worldY)
						end
						memberFrame.Position = UDim2.fromOffset(sx, sy)
						followerPositionsRef.current[memberId] = { x = mvx, y = mvy, isVirtual = true }
					end
				end
			end
			-- Send dragged piece to server
			local imageData = curPieceImages[pieceId]
			if imageData then
				local sox = math.floor(imageData.offsetX * curPixelScale)
				local soy = math.floor(imageData.offsetY * curPixelScale)
				local vx, vy = screenToVirtual(x, y, sox, soy)
				actionsRef.current.movePiece(pieceId, vx, vy)
			end
		else
			-- Solo: move all followers directly via frame refs (bypass React state)
			for memberId, offset in groupDragOffsets.current do
				local memberFrame = pieceFrameRefs.current[memberId]
				if memberFrame then
					local mx, my = x + offset.dx, y + offset.dy
					if zoomActionsRef.current.worldToScreen then
						local sx, sy = zoomActionsRef.current.worldToScreen(mx, my)
						memberFrame.Position = UDim2.fromOffset(sx, sy)
					else
						memberFrame.Position = UDim2.fromOffset(mx, my)
					end
					followerPositionsRef.current[memberId] = { x = mx, y = my }
				end
			end
		end
	end, {})

	local onDragEnd = React.useCallback(function(pieceId: number, x: number, y: number)
		-- Sync follower positions back to state (single batch after drag)
		for memberId, pos in followerPositionsRef.current do
			if pos.isVirtual then
				if actionsRef.current.movePieceLocal then
					actionsRef.current.movePieceLocal(memberId, pos.x, pos.y)
				end
			else
				actionsRef.current.movePiece(memberId, pos.x, pos.y)
			end
		end
		groupDragOffsets.current = {}
		followerPositionsRef.current = {}

		-- Always persist drop position to state so it stays in sync
		if not props.isMultiplayer then
			actionsRef.current.movePiece(pieceId, x, y)
		end

		local curPuzzleDef = puzzleDefRef.current
		local curPieceImages = pieceImagesRef.current
		local curPixelScale = pixelScaleRef.current
		local curCellSize = cellSizeRef.current
		local curBoardOffsetX = boardOffsetXRef.current
		local curBoardOffsetY = boardOffsetYRef.current

		if not curPuzzleDef or not curPieceImages then
			return
		end

		local pieceDef = nil
		for _, p in curPuzzleDef.pieces do
			if p.id == pieceId then
				pieceDef = p
				break
			end
		end
		if not pieceDef then return end

		-- Correct screen position accounts for the piece's tab offset
		local imageData = curPieceImages[pieceId]
		local scaledOffsetX = math.floor(imageData.offsetX * curPixelScale)
		local scaledOffsetY = math.floor(imageData.offsetY * curPixelScale)
		local correctX = curBoardOffsetX + (pieceDef.col - 1) * curCellSize.X - scaledOffsetX
		local correctY = curBoardOffsetY + (pieceDef.row - 1) * curCellSize.Y - scaledOffsetY

		if props.isMultiplayer then
			local vx, vy = screenToVirtual(x, y, scaledOffsetX, scaledOffsetY)
			actionsRef.current.trySnap(pieceId, vx, vy, 0, 0)

			-- Client-side snap prediction
			local MP_SNAP_THRESHOLD = 25
			local vw = RoomTypes.VIRTUAL_CANVAS_WIDTH
			local vh = RoomTypes.VIRTUAL_CANVAS_HEIGHT
			local cellVW = vw / props.cols
			local cellVH = vh / props.rows
			local correctVX = (pieceDef.col - 1) * cellVW
			local correctVY = (pieceDef.row - 1) * cellVH

			local gdx = vx - correctVX
			local gdy = vy - correctVY
			local gdist = math.sqrt(gdx * gdx + gdy * gdy)
			local willSnap = gdist <= MP_SNAP_THRESHOLD

			if not willSnap then
				local curState = stateRef.current
				for _, otherDef in curPuzzleDef.pieces do
					if otherDef.id == pieceId then continue end
					local otherState = curState.pieces[otherDef.id]
					if not otherState or otherState.locked then continue end
					local pieceState = curState.pieces[pieceId]
					if pieceState and pieceState.groupId and otherState.groupId == pieceState.groupId then continue end

					local rowDiff = math.abs(otherDef.row - pieceDef.row)
					local colDiff = math.abs(otherDef.col - pieceDef.col)
					if not (rowDiff + colDiff == 1) then continue end

					local expectedDx = (otherDef.col - pieceDef.col) * cellVW
					local expectedDy = (otherDef.row - pieceDef.row) * cellVH
					local actualDx = otherState.x - vx
					local actualDy = otherState.y - vy
					local snapDx = actualDx - expectedDx
					local snapDy = actualDy - expectedDy
					local snapDist = math.sqrt(snapDx * snapDx + snapDy * snapDy)

					if snapDist <= MP_SNAP_THRESHOLD then
						willSnap = true
						break
					end
				end
			end

			if willSnap then
				if actionsRef.current.markLocalSnap then
					actionsRef.current.markLocalSnap(pieceId)
				end
				SoundService.playSnap()
				local effectX = x + curCellSize.X / 2
				local effectY = y + curCellSize.Y / 2
				snapEffectCounter.current += 1
				local effectKey = "snap_" .. snapEffectCounter.current
				local effectId = props.equippedSnapEffect or ""
				setSnapEffects(function(prev)
					local updated = table.clone(prev)
					table.insert(updated, { positionX = effectX, positionY = effectY, key = effectKey, effectId = effectId })
					return updated
				end)
				task.delay(0.7, function()
					setSnapEffects(function(prev)
						local updated = {}
						for _, e in prev do
							if e.key ~= effectKey then
								table.insert(updated, e)
							end
						end
						return updated
					end)
				end)
			end
		else
			local snapped = actionsRef.current.trySnap(
				pieceId, x, y, correctX, correctY,
				curPuzzleDef, curPieceImages, curCellSize, curPixelScale, curBoardOffsetX, curBoardOffsetY,
				zoomStateRef.current.zoom
			)
			if snapped then
				SoundService.playSnap()
				local effectX = x + curCellSize.X / 2
				local effectY = y + curCellSize.Y / 2
				snapEffectCounter.current += 1
				local effectKey = "snap_" .. snapEffectCounter.current
				local effectId = props.equippedSnapEffect or ""
				setSnapEffects(function(prev)
					local updated = table.clone(prev)
					table.insert(updated, { positionX = effectX, positionY = effectY, key = effectKey, effectId = effectId })
					return updated
				end)
				task.delay(0.7, function()
					setSnapEffects(function(prev)
						local updated = {}
						for _, e in prev do
							if e.key ~= effectKey then
								table.insert(updated, e)
							end
						end
						return updated
					end)
				end)
			end
		end
	end, {})

	-- Helper: snap a random unlocked piece to its correct position and highlight it
	local function executeHint(): number?
		if not puzzleDef or not pieceImages then return nil end

		local unlockedIds = {}
		for _, pDef in puzzleDef.pieces do
			local ps = state.pieces[pDef.id]
			if ps and not ps.locked then
				table.insert(unlockedIds, pDef.id)
			end
		end
		if #unlockedIds == 0 then return nil end

		local targetId = unlockedIds[math.random(1, #unlockedIds)]
		local targetDef = nil
		for _, p in puzzleDef.pieces do
			if p.id == targetId then
				targetDef = p
				break
			end
		end
		if not targetDef then return nil end

		local imageData = pieceImages[targetId]
		local scaledOffsetX = math.floor(imageData.offsetX * pixelScale)
		local scaledOffsetY = math.floor(imageData.offsetY * pixelScale)
		local correctX = boardOffsetX + (targetDef.col - 1) * cellSize.X - scaledOffsetX
		local correctY = boardOffsetY + (targetDef.row - 1) * cellSize.Y - scaledOffsetY

		actions.snapPiece(targetId, correctX, correctY)
		SoundService.playSnap()

		-- Flash green highlight
		setHintHighlightId(targetId)
		task.delay(5.0, function()
			setHintHighlightId(function(current)
				if current == targetId then
					return nil
				end
				return current
			end)
		end)

		return targetId
	end

	-- Listen for Robux hint purchase confirmation from server
	React.useEffect(function()
		if props.isMultiplayer then return end

		local hintPurchasedEvent = Remotes.GetEvent("HintPurchased")
		local connection = hintPurchasedEvent.OnClientEvent:Connect(function(_data)
			executeHint()
		end)

		return function()
			connection:Disconnect()
		end
	end, { props.isMultiplayer, puzzleDef, pieceImages } :: { any })

	-- Check Puzzle Assist gamepass ownership
	React.useEffect(function()
		task.spawn(function()
			local localPlayer = Players.LocalPlayer
			if not localPlayer then return end
			local passConfig = MonetizationConfig.GAME_PASSES.PUZZLE_ASSIST
			if passConfig.id == 0 then return end
			local ok, ownsPass = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(localPlayer.UserId, passConfig.id)
			end)
			if ok and ownsPass then
				setOwnsPuzzleAssist(true)
			end
		end)
	end, {})

	-- Compute board colors from equipped skin
	local boardBgColor = Theme.Colors.bgDark
	local gridBgColor = Theme.Colors.bgElevated
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
			BackgroundColor3 = Theme.Colors.bgMedium,
			BackgroundTransparency = Theme.Transparency.hudButton,
			Text = formatTime(timer.elapsedSeconds),
			TextColor3 = Theme.Colors.textPrimary,
			TextSize = Theme.TextSize.heading,
			Font = Theme.Font.bold,
			ZIndex = 50,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Padding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
		})
	end

	-- Back to Menu and Give Up buttons (top-right, shown when not loading)
	if not isLoading then
		children["BackButton"] = React.createElement("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 4),
			Size = UDim2.fromOffset(130, 36),
			BackgroundColor3 = Theme.Colors.bgInput,
			Text = if props.isMultiplayer then "< Leave Room" else "< Back to Menu",
			TextColor3 = Theme.Colors.textSecondary,
			TextSize = Theme.TextSize.label,
			Font = Theme.Font.medium,
			ZIndex = 50,
			[React.Event.Activated] = function()
				if props.isMultiplayer then
					if props.onGiveUp then
						props.onGiveUp()
					end
				elseif puzzleDef then
					timer.stop()
					setShowSavePrompt(true)
				end
			end,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
		})

		children["GiveUpButton"] = React.createElement("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -146, 0, 4),
			Size = UDim2.fromOffset(80, 36),
			BackgroundColor3 = Theme.Colors.dangerDark,
			Text = "Give Up",
			TextColor3 = Color3.fromRGB(255, 220, 220),
			TextSize = Theme.TextSize.label,
			Font = Theme.Font.medium,
			ZIndex = 50,
			[React.Event.Activated] = function()
				if props.onGiveUp then
					props.onGiveUp()
				end
			end,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
		})

		-- Hint button (disabled in multiplayer)
		if not props.isMultiplayer and localHints > 0 and puzzleDef and pieceImages then
			children["HintButton"] = React.createElement("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(110, 36),
				BackgroundColor3 = Theme.Colors.orange,
				Text = "Hint (" .. localHints .. ")",
				TextColor3 = Theme.Colors.textPrimary,
				TextSize = Theme.TextSize.label,
				Font = Theme.Font.medium,
				ZIndex = 50,
				[React.Event.Activated] = function()
					if localHints <= 0 or not puzzleDef or not pieceImages then return end

					executeHint()

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

		-- Robux hint purchase button (disabled in multiplayer, always visible when puzzle is loaded)
		if not props.isMultiplayer and puzzleDef and pieceImages and not state.isComplete then
			local robuxOffsetY = if localHints > 0 then 24 else 0
			children["RobuxHintButton"] = React.createElement("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, robuxOffsetY),
				Size = UDim2.fromOffset(130, 36),
				BackgroundColor3 = Color3.fromRGB(0, 176, 111),
				Text = "\xF0\x9F\x92\x8E Hint (R$" .. MonetizationConfig.DEV_PRODUCTS.HINT_1.robuxPrice .. ")",
				TextColor3 = Theme.Colors.textPrimary,
				TextSize = Theme.TextSize.label,
				Font = Theme.Font.medium,
				ZIndex = 50,
				[React.Event.Activated] = function()
					local localPlayer = Players.LocalPlayer
					if localPlayer then
						MarketplaceService:PromptProductPurchase(localPlayer, MonetizationConfig.DEV_PRODUCTS.HINT_1.id)
					end
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
			})
		end

	end

	if loadError then
		children["ErrorMessage"] = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, -30),
			Size = UDim2.fromOffset(400, 50),
			BackgroundTransparency = 1,
			Text = "Failed to load puzzle image.",
			TextColor3 = Theme.Colors.danger,
			TextSize = Theme.TextSize.heading,
			Font = Theme.Font.bold,
		})
		children["ErrorBackButton"] = React.createElement("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 30),
			Size = UDim2.fromOffset(200, 44),
			BackgroundColor3 = Theme.Colors.scrollbar,
			Text = "Return to Menu",
			TextColor3 = Theme.Colors.textPrimary,
			TextSize = Theme.TextSize.button,
			Font = Theme.Font.medium,
			[React.Event.Activated] = function()
				if props.onGiveUp then
					props.onGiveUp()
				end
			end,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
		})
	elseif isLoading then
		children["Loading"] = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(300, 50),
			BackgroundTransparency = 1,
			Text = "Loading puzzle...",
			TextColor3 = Theme.Colors.textPrimary,
			TextSize = Theme.TextSize.heading,
			Font = Theme.Font.medium,
		})
	else
		-- Grid outline showing target positions
		local gridScreenX, gridScreenY = zoomActions.worldToScreen(boardOffsetX, boardOffsetY)
		local totalCells = props.rows * props.cols
		local gridCells: { [string]: any } = {
			Border = React.createElement("UIStroke", {
				Color = Theme.Colors.scrollbar,
				Thickness = 2,
			}),
		}
		-- Only render individual cell frames for small puzzles (≤100 cells)
		-- For larger puzzles (10x10+), skip per-cell frames to avoid reconciling hundreds of elements
		if totalCells <= 100 then
			gridCells["Grid"] = React.createElement("UIGridLayout", {
				CellSize = UDim2.fromOffset(cellSize.X * zoomState.zoom, cellSize.Y * zoomState.zoom),
				CellPadding = UDim2.fromOffset(0, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			})
			for i = 1, totalCells do
				gridCells["Cell_" .. i] = React.createElement("Frame", {
					LayoutOrder = i,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
				}, {
					Stroke = React.createElement("UIStroke", {
						Color = Theme.Colors.border,
						Thickness = 1,
						Transparency = 0.5,
					}),
				})
			end
		end

		children["GridOutline"] = React.createElement("Frame", {
			Position = UDim2.fromOffset(gridScreenX, gridScreenY),
			Size = UDim2.fromOffset(boardSize.X * zoomState.zoom, boardSize.Y * zoomState.zoom),
			BackgroundColor3 = gridBgColor,
			BackgroundTransparency = Theme.Transparency.disabled,
			BorderSizePixel = 0,
			ZIndex = 0,
		}, gridCells)

		-- Semi-transparent assist overlay (when Guide is active)
		if showAssistOverlay then
			children["AssistOverlay"] = React.createElement("ImageLabel", {
				Position = UDim2.fromOffset(gridScreenX, gridScreenY),
				Size = UDim2.fromOffset(boardSize.X * zoomState.zoom, boardSize.Y * zoomState.zoom),
				Image = props.imageAssetId,
				ScaleType = Enum.ScaleType.Fit,
				ImageTransparency = 0.75,
				BackgroundTransparency = 1,
				ZIndex = 1,
			})
		end

		-- Bottom controls (EdgesOnly, Shuffle, Zoom) pinned to bottom-center of screen
		local bottomControlChildren: { [string]: any } = {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			EdgesOnlyButton = React.createElement("TextButton", {
				LayoutOrder = 1,
				Size = UDim2.fromOffset(100, 36),
				BackgroundColor3 = if showEdgesOnly then Color3.fromRGB(50, 120, 80) else Theme.Colors.bgInput,
				Text = if showEdgesOnly then "Show All" else "Edges Only",
				TextColor3 = Theme.Colors.textSecondary,
				TextSize = Theme.TextSize.label,
				Font = Theme.Font.medium,
				ZIndex = 50,
				[React.Event.Activated] = function()
					setShowEdgesOnly(function(prev) return not prev end)
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
			}),
		}

		-- Shuffle button (solo only, hidden when complete)
		if not props.isMultiplayer and not state.isComplete then
			bottomControlChildren["ShuffleButton"] = React.createElement("TextButton", {
				LayoutOrder = 2,
				Size = UDim2.fromOffset(80, 36),
				BackgroundColor3 = Theme.Colors.bgInput,
				Text = "Shuffle",
				TextColor3 = Theme.Colors.textSecondary,
				TextSize = Theme.TextSize.label,
				Font = Theme.Font.medium,
				ZIndex = 50,
				[React.Event.Activated] = function()
					-- Collect unlocked piece IDs to shuffle
					local unlockedIds = {}
					for id, ps in state.pieces do
						if not ps.locked then
							table.insert(unlockedIds, id)
						end
					end
					if #unlockedIds == 0 then return end

					local camera = workspace.CurrentCamera
					local viewportW = if camera then camera.ViewportSize.X else 1200
					local viewportH = if camera then camera.ViewportSize.Y else 800

					local bOffX = math.floor((viewportW - boardSize.X) / 2)
					local bOffY = math.floor((viewportH - boardSize.Y) / 2)

					local piecePad = math.max(cellSize.X, cellSize.Y) * 1.3
					actions.scramblePieces(
						unlockedIds,
						viewportW,
						viewportH,
						bOffX,
						bOffY,
						boardSize.X,
						boardSize.Y,
						piecePad,
						topInset
					)
					SoundService.playPickup()
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
			})
		end

		-- Zoom controls
		bottomControlChildren["ZoomControls"] = React.createElement("Frame", {
			LayoutOrder = 3,
			Size = UDim2.fromOffset(140, 36),
			BackgroundTransparency = 1,
			ZIndex = 50,
		}, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),
			ZoomOut = React.createElement("TextButton", {
				LayoutOrder = 1,
				Size = UDim2.fromOffset(32, 36),
				BackgroundColor3 = Theme.Colors.bgInput,
				Text = "-",
				TextColor3 = Theme.Colors.textSecondary,
				TextSize = Theme.TextSize.large,
				Font = Theme.Font.bold,
				ZIndex = 50,
				[React.Event.Activated] = function()
					local camera = workspace.CurrentCamera
					local cx = if camera then camera.ViewportSize.X / 2 else 600
					local cy = if camera then camera.ViewportSize.Y / 2 else 400
					zoomActions.zoomAtPoint(cx, cy, -0.15)
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			ZoomLabel = React.createElement("TextLabel", {
				LayoutOrder = 2,
				Size = UDim2.fromOffset(48, 36),
				BackgroundColor3 = Theme.Colors.bgElevated,
				Text = math.floor(zoomState.zoom * 100 + 0.5) .. "%",
				TextColor3 = Theme.Colors.textSecondary,
				TextSize = Theme.TextSize.small,
				Font = Theme.Font.medium,
				ZIndex = 50,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			ZoomIn = React.createElement("TextButton", {
				LayoutOrder = 3,
				Size = UDim2.fromOffset(32, 36),
				BackgroundColor3 = Theme.Colors.bgInput,
				Text = "+",
				TextColor3 = Theme.Colors.textSecondary,
				TextSize = Theme.TextSize.large,
				Font = Theme.Font.bold,
				ZIndex = 50,
				[React.Event.Activated] = function()
					local camera = workspace.CurrentCamera
					local cx = if camera then camera.ViewportSize.X / 2 else 600
					local cy = if camera then camera.ViewportSize.Y / 2 else 400
					zoomActions.zoomAtPoint(cx, cy, 0.15)
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			ResetBtn = React.createElement("TextButton", {
				LayoutOrder = 4,
				Size = UDim2.fromOffset(20, 36),
				BackgroundColor3 = Theme.Colors.bgInput,
				Text = "0",
				TextColor3 = Theme.Colors.textMuted,
				TextSize = Theme.TextSize.tiny,
				Font = Theme.Font.medium,
				ZIndex = 50,
				[React.Event.Activated] = function()
					zoomActions.resetView()
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
		})

		-- View Artwork button (always visible)
		bottomControlChildren["ViewArtworkButton"] = React.createElement("TextButton", {
			LayoutOrder = 4,
			Size = UDim2.fromOffset(110, 36),
			BackgroundColor3 = Theme.Colors.bgInput,
			Text = "View Artwork",
			TextColor3 = Theme.Colors.textSecondary,
			TextSize = Theme.TextSize.label,
			Font = Theme.Font.medium,
			ZIndex = 50,
			[React.Event.Activated] = function()
				setShowArtworkModal(true)
			end,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
		})

		-- Guide toggle button (gamepass owners only)
		if ownsPuzzleAssist then
			bottomControlChildren["GuideToggleButton"] = React.createElement("TextButton", {
				LayoutOrder = 5,
				Size = UDim2.fromOffset(100, 36),
				BackgroundColor3 = if showAssistOverlay then Theme.Colors.accentCyan else Theme.Colors.bgInput,
				Text = if showAssistOverlay then "Guide ON" else "Guide OFF",
				TextColor3 = if showAssistOverlay then Theme.Colors.textPrimary else Theme.Colors.textSecondary,
				TextSize = Theme.TextSize.label,
				Font = Theme.Font.medium,
				ZIndex = 50,
				[React.Event.Activated] = function()
					setShowAssistOverlay(function(prev) return not prev end)
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
			})
		end

		children["BottomControls"] = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -12),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			ZIndex = 50,
		}, bottomControlChildren)

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

						-- Clamp to viewport so pieces stay on-screen on any device
						local camera = workspace.CurrentCamera
						if camera then
							local vpW = camera.ViewportSize.X
							local vpH = camera.ViewportSize.Y
							displayX = math.clamp(displayX, 0, vpW - displayW)
							displayY = math.clamp(displayY, 0, vpH - displayH)
						end
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
						isHintHighlighted = (pieceId == hintHighlightId),
						onDragStart = onDragStart,
						onDragMove = onDragMove,
						onDragEnd = onDragEnd,
						onHoverStart = onPieceHoverStart,
						onHoverEnd = onPieceHoverEnd,
						registerFrameRef = registerFrameRef,
						claimedByOther = claimedByOther,
						claimerColor = claimerColor,
						screenToWorld = stableScreenToWorld,
						worldToScreen = stableWorldToScreen,
						zoom = zoomState.zoom,
						panX = zoomState.panX,
						panY = zoomState.panY,
					})
				end
			end
		end
	end

	-- Render active snap effects (solo)
	for _, effect in snapEffects do
		children["SnapEffect_" .. effect.key] = React.createElement(SnapEffect, {
			positionX = effect.positionX,
			positionY = effect.positionY,
			effectId = effect.effectId,
			effectKey = effect.key,
		})
	end

	-- Render multiplayer snap effects (virtual coords → screen coords)
	if props.isMultiplayer and state.snapEvents then
		for _, event in state.snapEvents do
			-- Convert virtual coords to screen center position
			local vw = RoomTypes.VIRTUAL_CANVAS_WIDTH
			local vh = RoomTypes.VIRTUAL_CANVAS_HEIGHT
			local screenX = event.x / vw * boardSize.X + boardOffsetX
			local screenY = event.y / vh * boardSize.Y + boardOffsetY
			children["MPSnapEffect_" .. event.key] = React.createElement(SnapEffect, {
				positionX = screenX,
				positionY = screenY,
				effectId = event.effectId,
				effectKey = event.key,
			})
		end
	end

	-- Artwork modal overlay
	if showArtworkModal then
		children["ArtworkModalBackdrop"] = React.createElement("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Colors.black,
			BackgroundTransparency = Theme.Transparency.overlay,
			Text = "",
			ZIndex = Theme.ZIndex.modal,
			[React.Event.Activated] = function()
				setShowArtworkModal(false)
			end,
		})
		children["ArtworkModalCard"] = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.85, 0.85),
			BackgroundColor3 = Theme.Colors.bgCard,
			ZIndex = Theme.ZIndex.modal + 1,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = Theme.Radius.modal }),
			Stroke = React.createElement("UIStroke", {
				Thickness = 2,
				Color = Theme.Colors.border,
			}),
			Padding = React.createElement("UIPadding", {
				PaddingTop = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 12),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),
			ArtworkImage = React.createElement("ImageLabel", {
				Size = UDim2.fromScale(1, 1),
				Image = props.imageAssetId,
				ScaleType = Enum.ScaleType.Fit,
				BackgroundTransparency = 1,
				ZIndex = Theme.ZIndex.modal + 1,
			}),
			CloseButton = React.createElement("TextButton", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 4, 0, -4),
				Size = UDim2.fromOffset(32, 32),
				BackgroundColor3 = Theme.Colors.closeRed,
				Text = "X",
				TextColor3 = Theme.Colors.textPrimary,
				TextSize = Theme.TextSize.label,
				Font = Theme.Font.bold,
				ZIndex = Theme.ZIndex.modal + 2,
				[React.Event.Activated] = function()
					setShowArtworkModal(false)
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
			}),
		})
	end

	-- Save confirmation prompt overlay
	if showSavePrompt then
		children["SavePromptBackdrop"] = React.createElement("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Colors.black,
			BackgroundTransparency = Theme.Transparency.overlay,
			Text = "",
			ZIndex = 100,
			[React.Event.Activated] = function() end,
		})
		children["SavePromptCard"] = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(300, 160),
			BackgroundColor3 = Theme.Colors.bgCard,
			ZIndex = 101,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 12) }),
			PromptText = React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 20),
				Size = UDim2.new(1, -30, 0, 50),
				BackgroundTransparency = 1,
				Text = "Would you like to save\nyour progress?",
				TextColor3 = Theme.Colors.textSecondary,
				TextSize = Theme.TextSize.body,
				Font = Theme.Font.medium,
				TextWrapped = true,
				ZIndex = 101,
			}),
			SaveExitBtn = React.createElement("TextButton", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.3, 0, 0, 90),
				Size = UDim2.fromOffset(120, 40),
				BackgroundColor3 = Theme.Colors.success,
				Text = "Save & Exit",
				TextColor3 = Theme.Colors.textPrimary,
				TextSize = Theme.TextSize.body,
				Font = Theme.Font.medium,
				ZIndex = 101,
				[React.Event.Activated] = function()
					if props.onBackToMenu and puzzleDef then
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
			}),
			ExitNoSaveBtn = React.createElement("TextButton", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.7, 0, 0, 90),
				Size = UDim2.fromOffset(120, 40),
				BackgroundColor3 = Theme.Colors.dangerDark,
				Text = "Exit Without Saving",
				TextColor3 = Color3.fromRGB(255, 220, 220),
				TextSize = Theme.TextSize.small,
				Font = Theme.Font.medium,
				ZIndex = 101,
				[React.Event.Activated] = function()
					if props.onGiveUp then
						props.onGiveUp()
					end
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
			}),
		})
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = boardBgColor,
		BackgroundTransparency = 0,
	}, children)
end

return PuzzleBoard
