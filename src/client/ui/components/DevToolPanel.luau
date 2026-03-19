local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)

local Theme = require(Shared.Theme)

export type DevToolPanelProps = {
	onClose: () -> (),
}

local function formatDuration(seconds: number): string
	local hours = math.floor(seconds / 3600)
	local mins = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60
	if hours > 0 then
		return string.format("%dh %dm %ds", hours, mins, secs)
	end
	return string.format("%dm %ds", mins, secs)
end

local function DevToolPanel(props: DevToolPanelProps)
	local confirmStep, setConfirmStep = React.useState(false)
	local status, setStatus = React.useState("" :: string)
	local isProcessing, setIsProcessing = React.useState(false)
	local sessionData, setSessionData = React.useState(nil :: { { name: string, userId: number, sessionSeconds: number } }?)
	local sessionStatus, setSessionStatus = React.useState("" :: string)

	local function onResetClick()
		if isProcessing then return end

		if not confirmStep then
			setConfirmStep(true)
			return
		end

		-- Second click: fire remote
		setIsProcessing(true)
		setStatus("Resetting...")

		task.spawn(function()
			local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
			if not remotes then
				setStatus("Error: remotes not found")
				setIsProcessing(false)
				return
			end
			local remote = remotes:FindFirstChild("AdminResetData")
			if not remote or not remote:IsA("RemoteFunction") then
				setStatus("Error: remote not found")
				setIsProcessing(false)
				return
			end

			local ok, result = pcall(function()
				return remote:InvokeServer()
			end)

			if ok and result and result.success then
				setStatus("Data reset! Rejoin to apply.")
			else
				local msg = if result and result.message then result.message else "Unknown error"
				setStatus("Failed: " .. msg)
				setIsProcessing(false)
			end
			setConfirmStep(false)
		end)
	end

	local function onSessionTimesClick()
		setSessionStatus("Loading...")
		setSessionData(nil)

		task.spawn(function()
			local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
			if not remotes then
				setSessionStatus("Error: remotes not found")
				return
			end
			local remote = remotes:FindFirstChild("AdminGetSessionTimes")
			if not remote or not remote:IsA("RemoteFunction") then
				setSessionStatus("Error: remote not found")
				return
			end

			local ok, result = pcall(function()
				return remote:InvokeServer()
			end)

			if ok and result and result.success then
				setSessionData(result.players)
				setSessionStatus("")
			else
				local msg = if result and result.message then result.message else "Unknown error"
				setSessionStatus("Failed: " .. msg)
			end
		end)
	end

	local resetBtnText = "Reset All My Data"
	if isProcessing then
		resetBtnText = "Resetting..."
	elseif confirmStep then
		resetBtnText = "Are you sure? Click again"
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		ZIndex = 50,
		[React.Event.InputBegan] = function(_rbx, input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				props.onClose()
			end
		end,
	}, {
		Panel = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 320, 0, 420),
			BackgroundColor3 = Theme.Colors.bgCard,
			ZIndex = 51,
			[React.Event.InputBegan] = function() end, -- block clicks from reaching backdrop
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 14) }),
			Stroke = React.createElement("UIStroke", {
				Color = Theme.Colors.border,
				Thickness = 2,
			}),
			Padding = React.createElement("UIPadding", {
				PaddingTop = UDim.new(0, 16),
				PaddingBottom = UDim.new(0, 16),
				PaddingLeft = UDim.new(0, 16),
				PaddingRight = UDim.new(0, 16),
			}),
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 12),
			}),
			Title = React.createElement("TextLabel", {
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 32),
				BackgroundTransparency = 1,
				Text = "Dev Tools",
				TextColor3 = Theme.Colors.headerGold,
				TextSize = Theme.TextSize.title,
				Font = Theme.Font.title,
				ZIndex = 52,
			}),
			ResetBtn = React.createElement("TextButton", {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundColor3 = if confirmStep then Theme.Colors.danger else Theme.Colors.dangerDark,
				Text = resetBtnText,
				TextColor3 = Theme.Colors.textPrimary,
				TextSize = Theme.TextSize.button,
				Font = Theme.Font.bold,
				AutoButtonColor = not isProcessing,
				ZIndex = 52,
				[React.Event.Activated] = onResetClick,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
				Stroke = React.createElement("UIStroke", {
					Color = Theme.Colors.border,
					Thickness = 2,
				}),
			}),
			StatusLabel = if status ~= "" then React.createElement("TextLabel", {
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				Text = status,
				TextColor3 = Theme.Colors.textSecondary,
				TextSize = Theme.TextSize.body,
				Font = Theme.Font.medium,
				ZIndex = 52,
			}) else nil,
			SessionDivider = React.createElement("Frame", {
				LayoutOrder = 5,
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = Theme.Colors.border,
				BorderSizePixel = 0,
				ZIndex = 52,
			}),
			SessionBtn = React.createElement("TextButton", {
				LayoutOrder = 6,
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundColor3 = Theme.Colors.accentBlue,
				Text = if sessionData then "Refresh Session Times" else "Session Times",
				TextColor3 = Theme.Colors.textPrimary,
				TextSize = Theme.TextSize.button,
				Font = Theme.Font.bold,
				ZIndex = 52,
				[React.Event.Activated] = onSessionTimesClick,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
				Stroke = React.createElement("UIStroke", {
					Color = Theme.Colors.border,
					Thickness = 2,
				}),
			}),
			SessionStatusLabel = if sessionStatus ~= "" then React.createElement("TextLabel", {
				LayoutOrder = 7,
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Text = sessionStatus,
				TextColor3 = Theme.Colors.textSecondary,
				TextSize = Theme.TextSize.body,
				Font = Theme.Font.medium,
				ZIndex = 52,
			}) else nil,
			SessionList = if sessionData then React.createElement("ScrollingFrame", {
				LayoutOrder = 8,
				Size = UDim2.new(1, 0, 0, 140),
				BackgroundColor3 = Theme.Colors.bgDark,
				BackgroundTransparency = 0.5,
				BorderSizePixel = 0,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Theme.Colors.textSecondary,
				CanvasSize = UDim2.new(0, 0, 0, #sessionData * 32),
				ZIndex = 52,
			}, (function()
				local children = {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
					ListLayout = React.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 2),
					}),
					ListPadding = React.createElement("UIPadding", {
						PaddingTop = UDim.new(0, 4),
						PaddingBottom = UDim.new(0, 4),
						PaddingLeft = UDim.new(0, 8),
						PaddingRight = UDim.new(0, 8),
					}),
				}
				for i, entry in sessionData do
					children["Player_" .. i] = React.createElement("Frame", {
						LayoutOrder = i,
						Size = UDim2.new(1, 0, 0, 28),
						BackgroundTransparency = 1,
						ZIndex = 53,
					}, {
						NameLabel = React.createElement("TextLabel", {
							Size = UDim2.new(0.6, 0, 1, 0),
							Position = UDim2.fromScale(0, 0),
							BackgroundTransparency = 1,
							Text = entry.name,
							TextColor3 = Theme.Colors.textPrimary,
							TextSize = Theme.TextSize.body,
							Font = Theme.Font.bold,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
							ZIndex = 53,
						}),
						TimeLabel = React.createElement("TextLabel", {
							Size = UDim2.new(0.4, 0, 1, 0),
							Position = UDim2.fromScale(0.6, 0),
							BackgroundTransparency = 1,
							Text = formatDuration(entry.sessionSeconds),
							TextColor3 = Theme.Colors.textSecondary,
							TextSize = Theme.TextSize.body,
							Font = Theme.Font.medium,
							TextXAlignment = Enum.TextXAlignment.Right,
							ZIndex = 53,
						}),
					})
				end
				return children
			end)()) else nil,
			CloseBtn = React.createElement("TextButton", {
				LayoutOrder = 10,
				Size = UDim2.new(0.5, 0, 0, 36),
				BackgroundColor3 = Theme.Colors.bgElevated,
				Text = "Close",
				TextColor3 = Theme.Colors.textPrimary,
				TextSize = Theme.TextSize.button,
				Font = Theme.Font.bold,
				ZIndex = 52,
				[React.Event.Activated] = props.onClose,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Stroke = React.createElement("UIStroke", {
					Color = Theme.Colors.border,
					Thickness = 1.5,
				}),
			}),
		}),
	})
end

return DevToolPanel
