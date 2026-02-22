local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SeatingService = {}

local camera = Workspace.CurrentCamera
local localPlayer = Players.LocalPlayer

local isSeated = false
local currentSeating: {
	tableId: string,
	tableType: string,
	seatIndex: number,
	roomId: string?,
}? = nil

local TWEEN_INFO = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

function SeatingService.TransitionCameraToTable(tableId: string)
	-- Find the table model
	local cafeFolder = Workspace:FindFirstChild("CafeTables")
	if not cafeFolder then return end

	local tableModel = cafeFolder:FindFirstChild(tableId)
	if not tableModel then return end

	-- Find the tabletop to look at
	local tabletop = tableModel:FindFirstChild("Tabletop")
	if not tabletop then return end

	local tablePos = tabletop.Position

	-- Camera looks down at the table from above and slightly offset
	local cameraPos = Vector3.new(tablePos.X, tablePos.Y + 12, tablePos.Z + 6)
	local lookAt = tablePos

	camera.CameraType = Enum.CameraType.Scriptable

	local targetCFrame = CFrame.lookAt(cameraPos, lookAt)
	local tween = TweenService:Create(camera, TWEEN_INFO, { CFrame = targetCFrame })
	tween:Play()
end

function SeatingService.RestoreCamera()
	camera.CameraType = Enum.CameraType.Custom

	-- Re-assign camera subject to the local player's humanoid
	local character = localPlayer.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

function SeatingService.SetSeated(seatingInfo: any)
	isSeated = true
	currentSeating = seatingInfo
end

function SeatingService.ClearSeated()
	isSeated = false
	currentSeating = nil
end

function SeatingService.IsSeated(): boolean
	return isSeated
end

function SeatingService.GetCurrentSeating(): any
	return currentSeating
end

function SeatingService.Init()
	-- Nothing required at init time, service is stateless until seated
	print("[SeatingService] Initialized")
end

return SeatingService
