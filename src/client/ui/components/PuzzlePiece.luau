local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.Theme)

local useDrag = require(script.Parent.Parent.hooks.useDrag)

export type PuzzlePieceProps = {
	pieceId: number,
	editableImage: EditableImage,
	outlineImage: EditableImage,
	pieceWidth: number,
	pieceHeight: number,
	position: Vector2,
	zIndex: number,
	isLocked: boolean,
	isHovered: boolean,
	onDragStart: ((id: number) -> ())?,
	onDragMove: ((id: number, x: number, y: number) -> ())?,
	onDragEnd: ((id: number, x: number, y: number) -> ())?,
	onHoverStart: ((id: number) -> ())?,
	onHoverEnd: ((id: number) -> ())?,
	registerFrameRef: ((pieceId: number, frame: ImageLabel?) -> ())?,
	claimedByOther: boolean?,
	claimerColor: Color3?,
	isHintHighlighted: boolean?,
	screenToWorld: ((screenX: number, screenY: number) -> (number, number))?,
	worldToScreen: ((worldX: number, worldY: number) -> (number, number))?,
	zoom: number?,
	panX: number?,
	panY: number?,
}

local function HintGlow()
	local frameRef = React.useRef(nil :: Frame?)

	React.useEffect(function()
		local frame = frameRef.current
		if not frame then return end

		local pulseInfo = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

		local frameTween = TweenService:Create(frame, pulseInfo, {
			BackgroundTransparency = 0.6,
		})
		frameTween:Play()

		local stroke = frame:FindFirstChildOfClass("UIStroke")
		local strokeTween = nil
		if stroke then
			strokeTween = TweenService:Create(stroke, pulseInfo, {
				Transparency = 0.5,
			})
			strokeTween:Play()
		end

		return function()
			frameTween:Cancel()
			if strokeTween then
				strokeTween:Cancel()
			end
		end
	end, {})

	return React.createElement("Frame", {
		ref = frameRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.gold,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
		Stroke = React.createElement("UIStroke", {
			Color = Theme.Colors.gold,
			Thickness = 3,
			Transparency = 0,
		}),
	})
end

local function PuzzlePiece(props: PuzzlePieceProps)
	local imageRef = React.useRef(nil :: ImageLabel?)
	local outlineRef = React.useRef(nil :: ImageLabel?)
	local drag = useDrag({
		id = props.pieceId,
		initialPosition = props.position,
		enabled = not props.isLocked and not props.claimedByOther,
		screenToWorld = props.screenToWorld,
		worldToScreen = props.worldToScreen,
		frameRef = imageRef,
		onDragStart = function()
			if props.onDragStart then
				props.onDragStart(props.pieceId)
			end
		end,
		onDrop = function(finalPos: Vector2)
			if props.onDragEnd then
				props.onDragEnd(props.pieceId, finalPos.X, finalPos.Y)
			end
		end,
		onMove = function(pos: Vector2)
			if props.onDragMove then
				props.onDragMove(props.pieceId, pos.X, pos.Y)
			end
		end,
	})

	-- Set EditableImage on the ImageLabel imperatively (React-Roblox doesn't support Content type)
	React.useEffect(function()
		local imageLabel = imageRef.current
		if imageLabel and props.editableImage then
			imageLabel.ImageContent = Content.fromObject(props.editableImage)
		end
	end, { imageRef.current, props.editableImage } :: { any })

	-- Set outline EditableImage imperatively
	React.useEffect(function()
		local outlineLabel = outlineRef.current
		if outlineLabel and props.outlineImage then
			outlineLabel.ImageContent = Content.fromObject(props.outlineImage)
		end
	end, { outlineRef.current, props.outlineImage } :: { any })

	-- Sync position from parent when locked (snapped)
	React.useEffect(function()
		if props.isLocked then
			drag.setPosition(props.position)
		end
	end, { props.isLocked, props.position } :: { any })

	-- Register frame ref with parent for direct manipulation of group followers
	React.useEffect(function()
		if imageRef.current and props.registerFrameRef then
			props.registerFrameRef(props.pieceId, imageRef.current)
		end
		return function()
			if props.registerFrameRef then
				props.registerFrameRef(props.pieceId, nil)
			end
		end
	end, { imageRef.current } :: { any })

	-- Determine outline appearance
	local outlineColor, outlineTransparency
	if props.isLocked then
		outlineColor = Theme.Colors.bgHud
		outlineTransparency = 1
	elseif props.isHovered and not drag.isDragging then
		outlineColor = Theme.Colors.accentBlue
		outlineTransparency = 0
	else
		outlineColor = Theme.Colors.bgHud
		outlineTransparency = 0.3
	end

	local currentPos = if drag.isDragging then drag.positionRef.current else drag.position
	local sx, sy = currentPos.X, currentPos.Y
	if props.worldToScreen then
		sx, sy = props.worldToScreen(currentPos.X, currentPos.Y)
	end
	local zoomedW = props.pieceWidth * (props.zoom or 1)
	local zoomedH = props.pieceHeight * (props.zoom or 1)

	return React.createElement("ImageLabel", {
		ref = imageRef,
		Position = UDim2.fromOffset(sx, sy),
		Size = UDim2.fromOffset(zoomedW, zoomedH),
		BackgroundTransparency = 1,
		ImageTransparency = if props.isLocked then 0 else (if drag.isDragging then 0.05 else 0),
		ZIndex = if drag.isDragging then 9999 else props.zIndex,
		Active = not props.isLocked,
		ScaleType = Enum.ScaleType.Stretch,
		[React.Event.InputBegan] = drag.onInputBegan,
		[React.Event.MouseEnter] = function()
			if not props.isLocked and props.onHoverStart then
				props.onHoverStart(props.pieceId)
			end
		end,
		[React.Event.MouseLeave] = function()
			if props.onHoverEnd then
				props.onHoverEnd(props.pieceId)
			end
		end,
	}, {
		Outline = React.createElement("ImageLabel", {
			ref = outlineRef,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Stretch,
			ImageColor3 = outlineColor,
			ImageTransparency = outlineTransparency,
			ZIndex = 1,
		}),
		ClaimedTint = if props.claimedByOther
			then React.createElement("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = props.claimerColor or Color3.fromRGB(255, 100, 100),
				BackgroundTransparency = 0.7,
				BorderSizePixel = 0,
				ZIndex = 2,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
			})
			else nil,
		HintHighlight = if props.isHintHighlighted then React.createElement(HintGlow) else nil,
	})
end

return React.memo(PuzzlePiece)
