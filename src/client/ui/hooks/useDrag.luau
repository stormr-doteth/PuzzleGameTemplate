local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

-- Global drag lock: only one piece can be dragged at a time
local activeDragId: number? = nil

type UseDragOptions = {
	id: number,
	initialPosition: Vector2,
	onDragStart: (() -> ())?,
	onDrop: ((finalPosition: Vector2) -> ())?,
	enabled: boolean?,
}

type UseDragReturn = {
	position: Vector2,
	isDragging: boolean,
	onInputBegan: (rbx: GuiObject, input: InputObject) -> (),
	setPosition: (pos: Vector2) -> (),
}

local function useDrag(options: UseDragOptions): UseDragReturn
	local position, setPosition = React.useState(options.initialPosition)
	local isDragging, setIsDragging = React.useState(false)
	local dragOffset, setDragOffset = React.useState(Vector2.zero)
	local enabled = if options.enabled ~= nil then options.enabled else true

	-- Update position when initialPosition changes (for snapping)
	React.useEffect(function()
		setPosition(options.initialPosition)
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
				local mousePos = Vector2.new(input.Position.X, input.Position.Y)
				setPosition(mousePos - dragOffset)
			end
		end)

		releaseConn = UserInputService.InputEnded:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				activeDragId = nil
				setIsDragging(false)
				setPosition(function(currentPos)
					if options.onDrop then
						options.onDrop(currentPos)
					end
					return currentPos
				end)
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
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			activeDragId = options.id
			local mousePos = Vector2.new(input.Position.X, input.Position.Y)
			setDragOffset(mousePos - position)
			setIsDragging(true)
			if options.onDragStart then
				options.onDragStart()
			end
		end
	end

	return {
		position = position,
		isDragging = isDragging,
		onInputBegan = onInputBegan,
		setPosition = setPosition,
	}
end

return useDrag
