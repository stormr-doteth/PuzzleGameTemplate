local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

export type RoomJoinDialogProps = {
	onCreateRoom: () -> (),
	onJoinRoom: (roomId: string) -> (),
	onCancel: () -> (),
}

local function RoomJoinDialog(props: RoomJoinDialogProps)
	local roomCode, setRoomCode = React.useState("")
	local errorText, setErrorText = React.useState("")

	local function onJoin()
		local code = string.upper(string.gsub(roomCode, "%s", ""))
		if #code ~= 6 then
			setErrorText("Room code must be 6 characters")
			return
		end
		setErrorText("")
		props.onJoinRoom(code)
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.4,
		ZIndex = 150,
	}, {
		Modal = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(360, 320),
			BackgroundColor3 = Color3.fromRGB(15, 15, 25),
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 12) }),
			Padding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 24),
				PaddingRight = UDim.new(0, 24),
				PaddingTop = UDim.new(0, 24),
				PaddingBottom = UDim.new(0, 24),
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
				Text = "Multiplayer",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 28,
				Font = Enum.Font.GothamBold,
			}),

			CreateButton = React.createElement("TextButton", {
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 48),
				BackgroundColor3 = Color3.fromRGB(50, 180, 80),
				Text = "Create Room",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 20,
				Font = Enum.Font.GothamBold,
				[React.Event.Activated] = function()
					props.onCreateRoom()
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
			}),

			Divider = React.createElement("Frame", {
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = Color3.fromRGB(60, 60, 80),
				BorderSizePixel = 0,
			}),

			JoinLabel = React.createElement("TextLabel", {
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
				Text = "Or join with a room code:",
				TextColor3 = Color3.fromRGB(180, 180, 200),
				TextSize = 14,
				Font = Enum.Font.GothamMedium,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			CodeInput = React.createElement("TextBox", {
				LayoutOrder = 5,
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundColor3 = Color3.fromRGB(40, 40, 55),
				Text = roomCode,
				PlaceholderText = "Enter 6-digit code",
				PlaceholderColor3 = Color3.fromRGB(100, 100, 120),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 22,
				Font = Enum.Font.GothamBold,
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

			ErrorLabel = if errorText ~= ""
				then React.createElement("TextLabel", {
					LayoutOrder = 6,
					Size = UDim2.new(1, 0, 0, 16),
					BackgroundTransparency = 1,
					Text = errorText,
					TextColor3 = Color3.fromRGB(255, 100, 100),
					TextSize = 13,
					Font = Enum.Font.Gotham,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
				else nil,

			ButtonRow = React.createElement("Frame", {
				LayoutOrder = 7,
				Size = UDim2.new(1, 0, 0, 40),
				BackgroundTransparency = 1,
			}, {
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 12),
				}),
				JoinButton = React.createElement("TextButton", {
					LayoutOrder = 1,
					Size = UDim2.fromOffset(140, 40),
					BackgroundColor3 = Color3.fromRGB(80, 140, 230),
					Text = "Join Room",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 16,
					Font = Enum.Font.GothamBold,
					[React.Event.Activated] = onJoin,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
				}),
				CancelButton = React.createElement("TextButton", {
					LayoutOrder = 2,
					Size = UDim2.fromOffset(100, 40),
					BackgroundColor3 = Color3.fromRGB(60, 60, 80),
					Text = "Cancel",
					TextColor3 = Color3.fromRGB(200, 200, 220),
					TextSize = 16,
					Font = Enum.Font.GothamMedium,
					[React.Event.Activated] = function()
						props.onCancel()
					end,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
				}),
			}),
		}),
	})
end

return RoomJoinDialog
