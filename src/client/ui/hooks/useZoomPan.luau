local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

local TouchState = require(script.Parent.TouchState)

local MIN_ZOOM = 0.5
local MAX_ZOOM = 4.0
local ZOOM_STEP = 0.15

export type ZoomPanState = {
	zoom: number,
	panX: number,
	panY: number,
}

export type ZoomPanActions = {
	worldToScreen: (worldX: number, worldY: number) -> (number, number),
	screenToWorld: (screenX: number, screenY: number) -> (number, number),
	zoomAtPoint: (screenX: number, screenY: number, delta: number) -> (),
	startPan: (screenX: number, screenY: number) -> (),
	updatePan: (screenX: number, screenY: number) -> (),
	endPan: () -> (),
	resetView: () -> (),
}

local function useZoomPan(): (ZoomPanState, ZoomPanActions)
	local zoom, setZoom = React.useState(1.0)
	local panX, setPanX = React.useState(0)
	local panY, setPanY = React.useState(0)

	local isPanning, setIsPanning = React.useState(false)
	local panStartScreen = React.useRef(Vector2.zero)
	local panStartPan = React.useRef(Vector2.zero)

	-- Refs for current values (used in input callbacks)
	local zoomRef = React.useRef(zoom)
	local panXRef = React.useRef(panX)
	local panYRef = React.useRef(panY)
	zoomRef.current = zoom
	panXRef.current = panX
	panYRef.current = panY

	local function worldToScreen(worldX: number, worldY: number): (number, number)
		return (worldX - panXRef.current) * zoomRef.current, (worldY - panYRef.current) * zoomRef.current
	end

	local function screenToWorld(screenX: number, screenY: number): (number, number)
		return screenX / zoomRef.current + panXRef.current, screenY / zoomRef.current + panYRef.current
	end

	local function zoomAtPoint(screenX: number, screenY: number, delta: number)
		local oldZoom = zoomRef.current
		local newZoom = math.clamp(oldZoom + delta, MIN_ZOOM, MAX_ZOOM)
		if newZoom == oldZoom then return end

		local worldX = screenX / oldZoom + panXRef.current
		local worldY = screenY / oldZoom + panYRef.current
		setPanX(worldX - screenX / newZoom)
		setPanY(worldY - screenY / newZoom)
		setZoom(newZoom)
	end

	local function startPan(screenX: number, screenY: number)
		panStartScreen.current = Vector2.new(screenX, screenY)
		panStartPan.current = Vector2.new(panXRef.current, panYRef.current)
		setIsPanning(true)
	end

	local function updatePan(screenX: number, screenY: number)
		local dx = screenX - panStartScreen.current.X
		local dy = screenY - panStartScreen.current.Y
		setPanX(panStartPan.current.X - dx / zoomRef.current)
		setPanY(panStartPan.current.Y - dy / zoomRef.current)
	end

	local function endPan()
		setIsPanning(false)
	end

	local function resetView()
		setZoom(1.0)
		setPanX(0)
		setPanY(0)
	end

	-- Input handling
	React.useEffect(function()
		local connections: { RBXScriptConnection } = {}

		-- Scroll wheel zoom
		table.insert(connections, UserInputService.InputChanged:Connect(function(input: InputObject, gameProcessed: boolean)
			if gameProcessed then return end
			if input.UserInputType == Enum.UserInputType.MouseWheel then
				local delta = input.Position.Z * ZOOM_STEP
				local mousePos = UserInputService:GetMouseLocation()
				zoomAtPoint(mousePos.X, mousePos.Y, delta)
			end
		end))

		-- Middle mouse pan
		table.insert(connections, UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
			if gameProcessed then return end
			if input.UserInputType == Enum.UserInputType.MouseButton3 then
				local mousePos = UserInputService:GetMouseLocation()
				startPan(mousePos.X, mousePos.Y)
			end

			-- Keyboard shortcuts
			if input.UserInputType == Enum.UserInputType.Keyboard then
				if input.KeyCode == Enum.KeyCode.Equals or input.KeyCode == Enum.KeyCode.Plus then
					local camera = workspace.CurrentCamera
					local cx = if camera then camera.ViewportSize.X / 2 else 600
					local cy = if camera then camera.ViewportSize.Y / 2 else 400
					zoomAtPoint(cx, cy, ZOOM_STEP)
				elseif input.KeyCode == Enum.KeyCode.Minus then
					local camera = workspace.CurrentCamera
					local cx = if camera then camera.ViewportSize.X / 2 else 600
					local cy = if camera then camera.ViewportSize.Y / 2 else 400
					zoomAtPoint(cx, cy, -ZOOM_STEP)
				elseif input.KeyCode == Enum.KeyCode.Zero then
					resetView()
				end
			end
		end))

		table.insert(connections, UserInputService.InputChanged:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				if isPanning then
					local mousePos = UserInputService:GetMouseLocation()
					updatePan(mousePos.X, mousePos.Y)
				end
			end
		end))

		table.insert(connections, UserInputService.InputEnded:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton3 then
				endPan()
			end
		end))

		-- Touch: two-finger pan and pinch-to-zoom
		-- Track by InputObject reference (same object fires across Started→Moved→Ended)
		local activeTouches: { { input: InputObject, pos: Vector2 } } = {}
		local singleTouchPanning = false
		local singleTouchLastPos = Vector2.zero

		table.insert(connections, UserInputService.TouchStarted:Connect(function(input: InputObject)
			table.insert(activeTouches, { input = input, pos = Vector2.new(input.Position.X, input.Position.Y) })
			TouchState.touchCount = #activeTouches

			if #activeTouches == 1 and not TouchState.isDragging then
				singleTouchPanning = true
				singleTouchLastPos = Vector2.new(input.Position.X, input.Position.Y)
			elseif #activeTouches >= 2 then
				singleTouchPanning = false
			end
		end))

		table.insert(connections, UserInputService.TouchMoved:Connect(function(input: InputObject)
			-- Find this touch by reference and get its previous position
			local touchIndex = nil
			local oldPos = nil
			for i, t in activeTouches do
				if t.input == input then
					touchIndex = i
					oldPos = t.pos
					break
				end
			end
			if not touchIndex or not oldPos then return end

			local newPos = Vector2.new(input.Position.X, input.Position.Y)

			-- Single-finger pan on empty space
			if #activeTouches == 1 and singleTouchPanning and not TouchState.isDragging then
				local delta = newPos - singleTouchLastPos
				setPanX(panXRef.current - delta.X / zoomRef.current)
				setPanY(panYRef.current - delta.Y / zoomRef.current)
				singleTouchLastPos = newPos
			end

			if #activeTouches >= 2 then
				-- Find the other touch
				local otherTouch = nil
				for i, t in activeTouches do
					if i ~= touchIndex then
						otherTouch = t
						break
					end
				end

				if otherTouch then
					local otherPos = otherTouch.pos

					-- Previous state
					local oldMid = (oldPos + otherPos) / 2
					local oldDist = (oldPos - otherPos).Magnitude

					-- New state
					local newMid = (newPos + otherPos) / 2
					local newDist = (newPos - otherPos).Magnitude

					-- Pan: apply midpoint delta
					local panDelta = newMid - oldMid
					setPanX(function(p) return p - panDelta.X / zoomRef.current end)
					setPanY(function(p) return p - panDelta.Y / zoomRef.current end)

					-- Pinch-to-zoom: apply distance ratio
					if oldDist > 10 and newDist > 10 then
						local ratio = newDist / oldDist
						local zoomDelta = (ratio - 1) * zoomRef.current * 0.5
						zoomAtPoint(newMid.X, newMid.Y, zoomDelta)
					end
				end
			end

			-- Update stored position
			activeTouches[touchIndex].pos = newPos
		end))

		table.insert(connections, UserInputService.TouchEnded:Connect(function(input: InputObject)
			for i, t in activeTouches do
				if t.input == input then
					table.remove(activeTouches, i)
					break
				end
			end
			TouchState.touchCount = #activeTouches

			if #activeTouches == 0 then
				singleTouchPanning = false
			end
		end))

		return function()
			for _, conn in connections do
				conn:Disconnect()
			end
		end
	end, { isPanning } :: { any })

	-- Reset on viewport resize
	React.useEffect(function()
		local camera = workspace.CurrentCamera
		if not camera then return end

		local prevSize = camera.ViewportSize
		local conn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			local newSize = camera.ViewportSize
			if math.abs(newSize.X - prevSize.X) > 1 or math.abs(newSize.Y - prevSize.Y) > 1 then
				resetView()
				prevSize = newSize
			end
		end)

		return function()
			conn:Disconnect()
		end
	end, {})

	local state: ZoomPanState = {
		zoom = zoom,
		panX = panX,
		panY = panY,
	}

	local actions: ZoomPanActions = {
		worldToScreen = worldToScreen,
		screenToWorld = screenToWorld,
		zoomAtPoint = zoomAtPoint,
		startPan = startPan,
		updatePan = updatePan,
		endPan = endPan,
		resetView = resetView,
	}

	return state, actions
end

return useZoomPan
