local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)

local Theme = require(Shared.Theme)

export type DevToolPanelProps = {
	onClose: () -> (),
}

local DURATION_OPTIONS = {
	{ label = "1 Hour", minutes = 60 },
	{ label = "24 Hours", minutes = 1440 },
	{ label = "7 Days", minutes = 10080 },
	{ label = "Permanent", minutes = 0 },
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

local function formatBanTimeRemaining(bannedAt: number, durationMinutes: number): string
	if durationMinutes == 0 then
		return "Permanent"
	end
	local expiresAt = bannedAt + (durationMinutes * 60)
	local remaining = expiresAt - os.time()
	if remaining <= 0 then
		return "Expired"
	end
	local days = math.floor(remaining / 86400)
	local hours = math.floor((remaining % 86400) / 3600)
	local mins = math.floor((remaining % 3600) / 60)
	if days > 0 then
		return string.format("%dd %dh remaining", days, hours)
	end
	return string.format("%dh %dm remaining", hours, mins)
end

local function invokeRemote(name: string, ...): (boolean, any)
	local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
	if not remotes then
		return false, "Remotes not found"
	end
	local remote = remotes:FindFirstChild(name)
	if not remote or not remote:IsA("RemoteFunction") then
		return false, "Remote not found"
	end
	local ok, result = pcall(function(...)
		return remote:InvokeServer(...)
	end, ...)
	if not ok then
		return false, "Network error"
	end
	return true, result
end

local function DevToolPanel(props: DevToolPanelProps)
	local confirmStep, setConfirmStep = React.useState(false)
	local status, setStatus = React.useState("" :: string)
	local isProcessing, setIsProcessing = React.useState(false)
	local sessionData, setSessionData = React.useState(nil :: { { name: string, userId: number, sessionSeconds: number } }?)
	local sessionStatus, setSessionStatus = React.useState("" :: string)

	-- Ban state
	local banTargetUserId, setBanTargetUserId = React.useState(nil :: number?)
	local banReason, setBanReason = React.useState("" :: string)
	local banDurationIndex, setBanDurationIndex = React.useState(1)
	local banStatus, setBanStatus = React.useState("" :: string)
	local showBanList, setShowBanList = React.useState(false)
	local banList, setBanList = React.useState(nil :: { { userId: number, reason: string, bannedAt: number, duration: number, bannedBy: string } }?)
	local banListStatus, setBanListStatus = React.useState("" :: string)

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
			local ok, result = invokeRemote("AdminResetData")

			if ok and result and result.success then
				setStatus("Data reset! Rejoin to apply.")
			else
				local msg = if result and type(result) == "table" and result.message then result.message else "Unknown error"
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
			local ok, result = invokeRemote("AdminGetSessionTimes")

			if ok and result and result.success then
				setSessionData(result.players)
				setSessionStatus("")
			else
				local msg = if result and type(result) == "table" and result.message then result.message else "Unknown error"
				setSessionStatus("Failed: " .. msg)
			end
		end)
	end

	local function onBanConfirm()
		if not banTargetUserId then return end
		local reason = if banReason == "" then "No reason given" else banReason
		local durationMinutes = DURATION_OPTIONS[banDurationIndex].minutes

		setBanStatus("Banning...")

		task.spawn(function()
			local ok, result = invokeRemote("AdminBanPlayer", banTargetUserId, reason, durationMinutes)

			if ok and result and result.success then
				setBanStatus("Banned!")
				setBanTargetUserId(nil)
				setBanReason("")
				setBanDurationIndex(1)
				-- Refresh session list
				onSessionTimesClick()
				task.wait(2)
				setBanStatus("")
			else
				local msg = if result and type(result) == "table" and result.message then result.message else "Unknown error"
				setBanStatus("Failed: " .. msg)
			end
		end)
	end

	local function onUnban(userId: number)
		setBanListStatus("Unbanning...")

		task.spawn(function()
			local ok, result = invokeRemote("AdminUnbanPlayer", userId)

			if ok and result and result.success then
				-- Refresh ban list
				local ok2, result2 = invokeRemote("AdminGetBanList")
				if ok2 and result2 and result2.success then
					setBanList(result2.bans)
				end
				setBanListStatus("Unbanned!")
				task.wait(2)
				setBanListStatus("")
			else
				local msg = if result and type(result) == "table" and result.message then result.message else "Unknown error"
				setBanListStatus("Failed: " .. msg)
			end
		end)
	end

	local function onBanListClick()
		setShowBanList(not showBanList)
		if not showBanList then
			setBanListStatus("Loading...")
			setBanList(nil)

			task.spawn(function()
				local ok, result = invokeRemote("AdminGetBanList")

				if ok and result and result.success then
					setBanList(result.bans)
					setBanListStatus(if #result.bans == 0 then "No banned players" else "")
				else
					local msg = if result and type(result) == "table" and result.message then result.message else "Unknown error"
					setBanListStatus("Failed: " .. msg)
				end
			end)
		end
	end

	local resetBtnText = "Reset All My Data"
	if isProcessing then
		resetBtnText = "Resetting..."
	elseif confirmStep then
		resetBtnText = "Are you sure? Click again"
	end

	-- Build session list children with ban buttons
	local function buildSessionList()
		if not sessionData then return nil end

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
			local isTarget = banTargetUserId == entry.userId

			children["Player_" .. i] = React.createElement("Frame", {
				LayoutOrder = i * 2 - 1,
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundTransparency = 1,
				ZIndex = 53,
			}, {
				NameLabel = React.createElement("TextLabel", {
					Size = UDim2.new(0.4, 0, 1, 0),
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
					Size = UDim2.new(0.3, 0, 1, 0),
					Position = UDim2.fromScale(0.4, 0),
					BackgroundTransparency = 1,
					Text = formatDuration(entry.sessionSeconds),
					TextColor3 = Theme.Colors.textSecondary,
					TextSize = Theme.TextSize.body,
					Font = Theme.Font.medium,
					TextXAlignment = Enum.TextXAlignment.Right,
					ZIndex = 53,
				}),
				BanBtn = React.createElement("TextButton", {
					Size = UDim2.new(0.25, 0, 0, 22),
					Position = UDim2.new(0.75, 0, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundColor3 = if isTarget then Theme.Colors.danger else Theme.Colors.dangerDark,
					Text = if isTarget then "Cancel" else "Ban",
					TextColor3 = Theme.Colors.textPrimary,
					TextSize = 11,
					Font = Theme.Font.bold,
					ZIndex = 54,
					[React.Event.Activated] = function()
						if isTarget then
							setBanTargetUserId(nil)
							setBanReason("")
							setBanDurationIndex(1)
						else
							setBanTargetUserId(entry.userId)
							setBanReason("")
							setBanDurationIndex(1)
						end
					end,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
				}),
			})

			-- Show ban controls inline below the selected player
			if isTarget then
				children["BanControls_" .. i] = React.createElement("Frame", {
					LayoutOrder = i * 2,
					Size = UDim2.new(1, 0, 0, 80),
					BackgroundColor3 = Theme.Colors.bgElevated,
					ZIndex = 53,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
					Padding = React.createElement("UIPadding", {
						PaddingTop = UDim.new(0, 6),
						PaddingBottom = UDim.new(0, 6),
						PaddingLeft = UDim.new(0, 8),
						PaddingRight = UDim.new(0, 8),
					}),
					Layout = React.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
					}),
					ReasonInput = React.createElement("TextBox", {
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, 24),
						BackgroundColor3 = Theme.Colors.bgDark,
						Text = banReason,
						PlaceholderText = "Ban reason...",
						PlaceholderColor3 = Theme.Colors.textSecondary,
						TextColor3 = Theme.Colors.textPrimary,
						TextSize = 12,
						Font = Theme.Font.medium,
						ClearTextOnFocus = false,
						ZIndex = 54,
						[React.Change.Text] = function(rbx)
							setBanReason(rbx.Text)
						end,
					}, {
						Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
						Padding = React.createElement("UIPadding", {
							PaddingLeft = UDim.new(0, 6),
							PaddingRight = UDim.new(0, 6),
						}),
					}),
					BottomRow = React.createElement("Frame", {
						LayoutOrder = 2,
						Size = UDim2.new(1, 0, 0, 28),
						BackgroundTransparency = 1,
						ZIndex = 54,
					}, {
						DurationBtn = React.createElement("TextButton", {
							Size = UDim2.new(0.55, 0, 1, 0),
							Position = UDim2.fromScale(0, 0),
							BackgroundColor3 = Theme.Colors.bgCard,
							Text = DURATION_OPTIONS[banDurationIndex].label,
							TextColor3 = Theme.Colors.textPrimary,
							TextSize = 11,
							Font = Theme.Font.bold,
							ZIndex = 55,
							[React.Event.Activated] = function()
								setBanDurationIndex((banDurationIndex % #DURATION_OPTIONS) + 1)
							end,
						}, {
							Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
							Stroke = React.createElement("UIStroke", {
								Color = Theme.Colors.border,
								Thickness = 1,
							}),
						}),
						ConfirmBtn = React.createElement("TextButton", {
							Size = UDim2.new(0.4, 0, 1, 0),
							Position = UDim2.fromScale(0.6, 0),
							BackgroundColor3 = Theme.Colors.danger,
							Text = "Confirm Ban",
							TextColor3 = Theme.Colors.textPrimary,
							TextSize = 11,
							Font = Theme.Font.bold,
							ZIndex = 55,
							[React.Event.Activated] = onBanConfirm,
						}, {
							Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
						}),
					}),
				})
			end
		end

		-- Calculate canvas height
		local rowCount = #sessionData
		local extraRows = 0
		if banTargetUserId then
			for _, entry in sessionData do
				if entry.userId == banTargetUserId then
					extraRows = 1
					break
				end
			end
		end
		local canvasHeight = (rowCount * 30) + (extraRows * 84)

		return React.createElement("ScrollingFrame", {
			LayoutOrder = 8,
			Size = UDim2.new(1, 0, 0, 140),
			BackgroundColor3 = Theme.Colors.bgDark,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Theme.Colors.textSecondary,
			CanvasSize = UDim2.new(0, 0, 0, canvasHeight),
			ZIndex = 52,
		}, children)
	end

	-- Build ban list
	local function buildBanList()
		if not showBanList then return nil end

		local listChildren = {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
			ListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),
			ListPadding = React.createElement("UIPadding", {
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
		}

		if banList then
			for i, ban in banList do
				listChildren["Ban_" .. i] = React.createElement("Frame", {
					LayoutOrder = i,
					Size = UDim2.new(1, 0, 0, 48),
					BackgroundColor3 = Theme.Colors.bgElevated,
					ZIndex = 53,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
					Padding = React.createElement("UIPadding", {
						PaddingLeft = UDim.new(0, 8),
						PaddingRight = UDim.new(0, 8),
					}),
					TopRow = React.createElement("TextLabel", {
						Size = UDim2.new(0.7, 0, 0, 24),
						Position = UDim2.fromOffset(0, 2),
						BackgroundTransparency = 1,
						Text = "ID: " .. tostring(ban.userId),
						TextColor3 = Theme.Colors.textPrimary,
						TextSize = 12,
						Font = Theme.Font.bold,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 54,
					}),
					TimeLabel = React.createElement("TextLabel", {
						Size = UDim2.new(0.7, 0, 0, 20),
						Position = UDim2.fromOffset(0, 24),
						BackgroundTransparency = 1,
						Text = ban.reason .. " \u{2022} " .. formatBanTimeRemaining(ban.bannedAt, ban.duration),
						TextColor3 = Theme.Colors.textSecondary,
						TextSize = 10,
						Font = Theme.Font.medium,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTruncate = Enum.TextTruncate.AtEnd,
						ZIndex = 54,
					}),
					UnbanBtn = React.createElement("TextButton", {
						Size = UDim2.new(0, 52, 0, 24),
						Position = UDim2.new(1, 0, 0.5, 0),
						AnchorPoint = Vector2.new(1, 0.5),
						BackgroundColor3 = Theme.Colors.success,
						Text = "Unban",
						TextColor3 = Theme.Colors.textPrimary,
						TextSize = 11,
						Font = Theme.Font.bold,
						ZIndex = 55,
						[React.Event.Activated] = function()
							onUnban(ban.userId)
						end,
					}, {
						Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 6) }),
					}),
				})
			end
		end

		local entryCount = if banList then #banList else 0
		local canvasHeight = math.max(30, entryCount * 52)

		return React.createElement("ScrollingFrame", {
			LayoutOrder = 12,
			Size = UDim2.new(1, 0, 0, 120),
			BackgroundColor3 = Theme.Colors.bgDark,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Theme.Colors.textSecondary,
			CanvasSize = UDim2.new(0, 0, 0, canvasHeight),
			ZIndex = 52,
		}, listChildren)
	end

	-- Calculate panel height dynamically
	local panelHeight = 420
	if banStatus ~= "" then panelHeight = panelHeight + 24 end
	if showBanList then panelHeight = panelHeight + 170 end

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
			Size = UDim2.new(0, 340, 0, panelHeight),
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
			SessionList = buildSessionList(),
			BanStatusLabel = if banStatus ~= "" then React.createElement("TextLabel", {
				LayoutOrder = 9,
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Text = banStatus,
				TextColor3 = Theme.Colors.gold,
				TextSize = Theme.TextSize.body,
				Font = Theme.Font.bold,
				ZIndex = 52,
			}) else nil,
			BanDivider = React.createElement("Frame", {
				LayoutOrder = 10,
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = Theme.Colors.border,
				BorderSizePixel = 0,
				ZIndex = 52,
			}),
			BanListBtn = React.createElement("TextButton", {
				LayoutOrder = 11,
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundColor3 = if showBanList then Theme.Colors.danger else Theme.Colors.dangerDark,
				Text = if showBanList then "Hide Banned Players" else "Banned Players",
				TextColor3 = Theme.Colors.textPrimary,
				TextSize = Theme.TextSize.button,
				Font = Theme.Font.bold,
				ZIndex = 52,
				[React.Event.Activated] = onBanListClick,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
				Stroke = React.createElement("UIStroke", {
					Color = Theme.Colors.border,
					Thickness = 2,
				}),
			}),
			BanListStatusLabel = if banListStatus ~= "" and showBanList then React.createElement("TextLabel", {
				LayoutOrder = 12,
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Text = banListStatus,
				TextColor3 = Theme.Colors.textSecondary,
				TextSize = Theme.TextSize.body,
				Font = Theme.Font.medium,
				ZIndex = 52,
			}) else nil,
			BanList = buildBanList(),
			CloseBtn = React.createElement("TextButton", {
				LayoutOrder = 20,
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
