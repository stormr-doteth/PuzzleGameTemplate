local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

local TouchState = require(script.Parent.TouchState)

-- Global drag lock: only one piece can be dragged at a time
local activeDragId: number? = nil

type UseDragOptions = {
	id: number,
	initialPosition: Vector2,
	onDragStart: (() -> ())?,
	onDrop: ((finalPosition: Vector2) -> ())?,
	onMove: ((position: Vector2) -> ())?,
	enabled: boolean?,
	screenToWorld: ((screenX: number, screenY: number) -> (number, number))?,
	worldToScreen: ((worldX: number, worldY: number) -> (number, number))?,
	frameRef: { current: ImageLabel? }?,
}

type UseDragReturn = {
	position: Vector2,
	positionRef: { current: Vector2 },
	isDragging: boolean,
	onInputBegan: (rbx: GuiObject, input: InputObject) -> (),
	setPosition: (pos: Vector2) -> (),
}

local function useDrag(options: UseDragOptions): UseDragReturn
	local position, setPosition = React.useState(options.initialPosition)
	local isDragging, setIsDragging = React.useState(false)
	local isDraggingRef = React.useRef(false)
	local dragOffset, setDragOffset = React.useState(Vector2.zero)
	local enabled = if options.enabled ~= nil then options.enabled else true

	-- Ref to track position during direct-manipulation drag (bypasses React state)
	local positionRef = React.useRef(options.initialPosition)

	-- Store callback/transform refs so the InputChanged closure always sees current values
	local screenToWorldRef = React.useRef(options.screenToWorld)
	local worldToScreenRef = React.useRef(options.worldToScreen)
	local onMoveRef = React.useRef(options.onMove)
	local onDropRef = React.useRef(options.onDrop)
	local frameRefRef = React.useRef(options.frameRef)

	-- Update refs each render (cheap, no allocations)
	screenToWorldRef.current = options.screenToWorld
	worldToScreenRef.current = options.worldToScreen
	onMoveRef.current = options.onMove
	onDropRef.current = options.onDrop
	frameRefRef.current = options.frameRef
	if not isDraggingRef.current then
		positionRef.current = position
	end

	-- Update position when initialPosition changes (for snapping / group follower movement)
	React.useEffect(function()
		if not isDraggingRef.current then
			setPosition(options.initialPosition)
			positionRef.current = options.initialPosition
		end
	end, { options.initialPosition })

	React.useEffect(function()
		if not isDragging then
			return
		end

		local moveConn: RBXScriptConnection
		local releaseConn: RBXScriptConnection

		moveConn = UserInputService.InputChanged:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			then
				-- Cancel drag when multi-touching (two-finger pan/zoom)
				if input.UserInputType == Enum.UserInputType.Touch and TouchState.touchCount >= 2 then
					activeDragId = nil
					isDraggingRef.current = false
					TouchState.isDragging = false
					setIsDragging(false)
					local restorePos = positionRef.current
					setPosition(restorePos)
					if onDropRef.current then
						onDropRef.current(restorePos)
					end
					return
				end
				local mousePos = Vector2.new(input.Position.X, input.Position.Y)
				if screenToWorldRef.current then
					local wx, wy = screenToWorldRef.current(mousePos.X, mousePos.Y)
					mousePos = Vector2.new(wx, wy)
				end
				local newPos = mousePos - dragOffset
				positionRef.current = newPos

				-- Direct frame manipulation: bypass React state for smooth 60fps drag
				local fr = frameRefRef.current
				if fr and fr.current then
					if worldToScreenRef.current then
						local sx, sy = worldToScreenRef.current(newPos.X, newPos.Y)
						fr.current.Position = UDim2.fromOffset(sx, sy)
					else
						fr.current.Position = UDim2.fromOffset(newPos.X, newPos.Y)
					end
					-- Call direct move callback (for group follower movement)
					if onMoveRef.current then
						onMoveRef.current(newPos)
					end
				else
					-- Fallback: update React state (no frameRef provided)
					setPosition(newPos)
				end
			end
		end)

		releaseConn = UserInputService.InputEnded:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				activeDragId = nil
				isDraggingRef.current = false
				TouchState.isDragging = false
				setIsDragging(false)
				-- Sync React state with final position from ref
				local finalPos = positionRef.current
				setPosition(finalPos)
				if onDropRef.current then
					onDropRef.current(finalPos)
				end
			end
		end)

		return function()
			if moveConn then
				moveConn:Disconnect()
			end
			if releaseConn then
				releaseConn:Disconnect()
			end
		end
	end, { isDragging, dragOffset } :: { any })

	local function onInputBegan(_rbx: GuiObject, input: InputObject)
		if not enabled then
			return
		end
		-- Only allow drag if no other piece is being dragged
		if activeDragId ~= nil then
			return
		end
		-- Block new touch drags when multi-touching
		if input.UserInputType == Enum.UserInputType.Touch and TouchState.touchCount >= 2 then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			activeDragId = options.id
			isDraggingRef.current = true
			TouchState.isDragging = true
			local mousePos = Vector2.new(input.Position.X, input.Position.Y)
			if screenToWorldRef.current then
				local wx, wy = screenToWorldRef.current(mousePos.X, mousePos.Y)
				mousePos = Vector2.new(wx, wy)
			end
			local offset = mousePos - positionRef.current
			setDragOffset(offset)
			setIsDragging(true)
			if options.onDragStart then
				options.onDragStart()
			end
		end
	end

	return {
		position = position,
		positionRef = positionRef,
		isDragging = isDragging,
		onInputBegan = onInputBegan,
		setPosition = setPosition,
	}
end

return useDrag
