local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

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
}

local function PuzzlePiece(props: PuzzlePieceProps)
	local imageRef = React.useRef(nil :: ImageLabel?)
	local outlineRef = React.useRef(nil :: ImageLabel?)
	local drag = useDrag({
		id = props.pieceId,
		initialPosition = props.position,
		enabled = not props.isLocked,
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

	-- Report drag movement
	React.useEffect(function()
		if drag.isDragging and props.onDragMove then
			props.onDragMove(props.pieceId, drag.position.X, drag.position.Y)
		end
	end, { drag.isDragging, drag.position } :: { any })

	-- Determine outline appearance
	local outlineColor, outlineTransparency
	if props.isLocked then
		outlineColor = Color3.fromRGB(20, 20, 30)
		outlineTransparency = 1
	elseif props.isHovered and not drag.isDragging then
		outlineColor = Color3.fromRGB(120, 180, 255)
		outlineTransparency = 0
	else
		outlineColor = Color3.fromRGB(20, 20, 30)
		outlineTransparency = 0.3
	end

	return React.createElement("ImageLabel", {
		ref = imageRef,
		Position = UDim2.fromOffset(drag.position.X, drag.position.Y),
		Size = UDim2.fromOffset(props.pieceWidth, props.pieceHeight),
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
	})
end

return PuzzlePiece
