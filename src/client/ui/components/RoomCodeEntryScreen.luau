local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.Theme)

export type RoomCodeEntryScreenProps = {
	onJoinRoom: (code: string) -> (),
	onLeaveTable: () -> (),
	joinError: string?,
}

local function RoomCodeEntryScreen(props: RoomCodeEntryScreenProps)
	local roomCode, setRoomCode = React.useState("")
	local localError, setLocalError = React.useState("")

	local function onJoin()
		local code = string.upper(string.gsub(roomCode, "%s", ""))
		if #code ~= 6 then
			setLocalError("Room code must be 6 characters")
			return
		end
		setLocalError("")
		props.onJoinRoom(code)
	end

	local displayError = if props.joinError and props.joinError ~= "" then props.joinError else localError

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.bgDark,
		ZIndex = 50,
	}, {
		Background = React.createElement("Frame", {
			Size = UDim2.fromScale(2, 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			BackgroundColor3 = Theme.Colors.bgDark,
			ZIndex = 0,
		}),
		Modal = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(380, 340),
			BackgroundColor3 = Theme.Colors.bgDeepest,
			ZIndex = 51,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 14) }),
			Stroke = React.createElement("UIStroke", {
				Thickness = 2,
				Color = Theme.Colors.border,
			}),
			Padding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 28),
				PaddingRight = UDim.new(0, 28),
				PaddingTop = UDim.new(0, 28),
				PaddingBottom = UDim.new(0, 28),
			}),
			Layout = React.createElement("UIListLayout", {
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 14),
			}),

			Title = React.createElement("TextLabel", {
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 36),
				BackgroundTransparency = 1,
				Text = "Puzzle In Progress",
				TextColor3 = Theme.Colors.headerGold,
				TextSize = Theme.TextSize.heading,
				Font = Theme.Font.heading,
			}),

			Subtitle = React.createElement("TextLabel", {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Text = "Enter room code to join",
				TextColor3 = Theme.Colors.textMuted,
				TextSize = Theme.TextSize.body,
				Font = Theme.Font.medium,
			}),

			CodeInput = React.createElement("TextBox", {
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 48),
				BackgroundColor3 = Theme.Colors.bgElevated,
				Text = roomCode,
				PlaceholderText = "Enter 6-digit code",
				PlaceholderColor3 = Theme.Colors.bgMuted,
				TextColor3 = Theme.Colors.textPrimary,
				TextSize = Theme.TextSize.large,
				Font = Theme.Font.bold,
				ClearTextOnFocus = false,
				[React.Change.Text] = function(rbx)
					local text = string.upper(string.gsub(rbx.Text, "%s", ""))
					if #text > 6 then
						text = string.sub(text, 1, 6)
					end
					setRoomCode(text)
					rbx.Text = text
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Padding = React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, 12),
					PaddingRight = UDim.new(0, 12),
				}),
			}),

			ErrorLabel = if displayError ~= ""
				then React.createElement("TextLabel", {
					LayoutOrder = 4,
					Size = UDim2.new(1, 0, 0, 18),
					BackgroundTransparency = 1,
					Text = displayError,
					TextColor3 = Theme.Colors.danger,
					TextSize = Theme.TextSize.small,
					Font = Theme.Font.regular,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
				else nil,

			JoinButton = React.createElement("TextButton", {
				LayoutOrder = 5,
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundColor3 = Theme.Colors.accentBlue,
				Text = "Join",
				TextColor3 = Theme.Colors.textPrimary,
				TextSize = Theme.TextSize.large,
				Font = Theme.Font.bold,
				[React.Event.Activated] = onJoin,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
				Stroke = React.createElement("UIStroke", {
					Thickness = 2,
					Color = Theme.Colors.border,
				}),
			}),

			LeaveButton = React.createElement("TextButton", {
				LayoutOrder = 6,
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundColor3 = Theme.Colors.dangerDark,
				Text = "Join Another Table",
				TextColor3 = Theme.Colors.textPrimary,
				TextSize = Theme.TextSize.body,
				Font = Theme.Font.bold,
				[React.Event.Activated] = function()
					props.onLeaveTable()
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Stroke = React.createElement("UIStroke", {
					Thickness = 2,
					Color = Theme.Colors.border,
				}),
			}),
		}),
	})
end

return RoomCodeEntryScreen
