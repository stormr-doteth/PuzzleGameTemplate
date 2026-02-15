local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

local useDrag = require(script.Parent.Parent.hooks.useDrag)

export type PuzzlePieceProps = {
	pieceId: number,
	editableImage: EditableImage,
	pieceWidth: number,
	pieceHeight: number,
	position: Vector2,
	zIndex: number,
	isLocked: boolean,
	onDragStart: ((id: number) -> ())?,
	onDragMove: ((id: number, x: number, y: number) -> ())?,
	onDragEnd: ((id: number, x: number, y: number) -> ())?,
}

local function PuzzlePiece(props: PuzzlePieceProps)
	local imageRef = React.useRef(nil :: ImageLabel?)

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
	})
end

return PuzzlePiece
