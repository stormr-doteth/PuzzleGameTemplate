local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)
local Theme = require(Shared.Theme)
local SnapEffect = require(script.Parent.SnapEffect)
local SoundService = require(script.Parent.Parent.Parent.services.SoundService)

export type StarterPackModalProps = {
	secondsLeft: number,
	onClose: () -> (),
	onBuy: () -> (),
}

local function formatMMSS(seconds: number): string
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	return string.format("%02d:%02d", m, s)
end

local RAINBOW_SEQUENCE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 180, 50)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 255, 80)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 120)),
	ColorSequenceKeypoint.new(0.67, Color3.fromRGB(80, 180, 255)),
	ColorSequenceKeypoint.new(0.83, Color3.fromRGB(180, 80, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 200)),
})

local CONTENTS = {
	{ icon = "\u{1FA99}", text = "500 Cash", color = Theme.Colors.cashGreen },
	{ icon = "\u{1F4A1}", text = "5 Hints", color = Theme.Colors.textPrimary },
	{ icon = "\u{26A1}", text = "2 Cash Boosts", color = Theme.Colors.textPrimary },
}

local function StarterPackModal(props: StarterPackModalProps)
	local isExpired = props.secondsLeft <= 0
	local modalRef = React.useRef(nil :: Frame?)

	-- Snap effect demo state (same pattern as ShopScreen)
	local demoEffect, setDemoEffect = React.useState(nil :: { effectId: string, key: string, x: number, y: number }?)
	local demoCounter = React.useRef(0)

	-- Build contents rows
	local contentRows: { [string]: any } = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		Padding = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16),
		}),
	}

	for i, item in CONTENTS do
		contentRows["Row_" .. i] = React.createElement("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundColor3 = Theme.Colors.bgElevated,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Stroke = React.createElement("UIStroke", {
				Thickness = 1.5,
				Color = Theme.Colors.border,
			}),
			Icon = React.createElement("TextLabel", {
				Position = UDim2.fromScale(0.04, 0),
				Size = UDim2.fromScale(0.12, 1),
				BackgroundTransparency = 1,
				Text = item.icon,
				TextScaled = true,
				Font = Theme.Font.regular,
				TextColor3 = Theme.Colors.textPrimary,
			}),
			Label = React.createElement("TextLabel", {
				Position = UDim2.fromScale(0.18, 0),
				Size = UDim2.fromScale(0.78, 1),
				BackgroundTransparency = 1,
				Text = item.text,
				TextColor3 = item.color,
				TextScaled = true,
				Font = Theme.Font.bold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, {
				LabelStroke = React.createElement("UIStroke", {
					Thickness = 1,
					Color = Theme.Colors.black,
				}),
			}),
		})
	end

	-- Snap effect row with test button (row 4)
	contentRows["Row_snap"] = React.createElement("Frame", {
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = Theme.Colors.bgElevated,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Stroke = React.createElement("UIStroke", {
			Thickness = 1.5,
			Color = Theme.Colors.border,
		}),
		Icon = React.createElement("TextLabel", {
			Position = UDim2.fromScale(0.04, 0),
			Size = UDim2.fromScale(0.12, 1),
			BackgroundTransparency = 1,
			Text = "\u{2B50}",
			TextScaled = true,
			Font = Theme.Font.regular,
			TextColor3 = Theme.Colors.textPrimary,
		}),
		Label = React.createElement("TextLabel", {
			Position = UDim2.fromScale(0.18, 0),
			Size = UDim2.fromScale(0.48, 1),
			BackgroundTransparency = 1,
			Text = "Starter Burst (EXCLUSIVE)",
			TextColor3 = Theme.Colors.gold,
			TextScaled = true,
			Font = Theme.Font.bold,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, {
			LabelStroke = React.createElement("UIStroke", {
				Thickness = 1,
				Color = Theme.Colors.black,
			}),
		}),
		TestBtn = React.createElement("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(0.96, 0.5),
			Size = UDim2.fromScale(0.22, 0.75),
			BackgroundColor3 = Theme.Colors.accentBlue,
			Text = "Test",
			TextColor3 = Theme.Colors.textPrimary,
			TextScaled = true,
			Font = Theme.Font.bold,
			ZIndex = 203,
			[React.Event.Activated] = function(_, inputObject)
				demoCounter.current += 1
				local key = "starter_demo_" .. tostring(demoCounter.current)

				local modal = modalRef.current
				local clickX = 0
				local clickY = 0
				if modal and inputObject then
					local screenPos = inputObject.Position
					local modalPos = modal.AbsolutePosition
					clickX = screenPos.X - modalPos.X
					clickY = screenPos.Y - modalPos.Y
				end

				setDemoEffect({ effectId = "snap_starter", key = key, x = clickX, y = clickY })
				SoundService.playSnap()
				task.delay(0.9, function()
					setDemoEffect(function(current)
						if current and current.key == key then
							return nil
						end
						return current
					end)
				end)
			end,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
			BtnStroke = React.createElement("UIStroke", {
				Thickness = 2,
				Color = Theme.Colors.border,
			}),
		}),
	})

	-- Rainbow name row (row 5)
	contentRows["Row_rainbow"] = React.createElement("Frame", {
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = Theme.Colors.bgElevated,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Stroke = React.createElement("UIStroke", {
			Thickness = 1.5,
			Color = Theme.Colors.border,
		}),
		Icon = React.createElement("TextLabel", {
			Position = UDim2.fromScale(0.04, 0),
			Size = UDim2.fromScale(0.12, 1),
			BackgroundTransparency = 1,
			Text = "\u{1F308}",
			TextScaled = true,
			Font = Theme.Font.regular,
			TextColor3 = Theme.Colors.textPrimary,
		}),
		Label = React.createElement("TextLabel", {
			Position = UDim2.fromScale(0.18, 0),
			Size = UDim2.fromScale(0.78, 1),
			BackgroundTransparency = 1,
			Text = "Rainbow Title",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			Font = Theme.Font.bold,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, {
			LabelStroke = React.createElement("UIStroke", {
				Thickness = 1,
				Color = Theme.Colors.black,
			}),
			RainbowGradient = React.createElement("UIGradient", {
				Color = RAINBOW_SEQUENCE,
			}),
		}),
	})

	-- Rainbow preview section (row 6)
	contentRows["Row_rainbowPreview"] = React.createElement("Frame", {
		LayoutOrder = 6,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = Theme.Colors.bgCard,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Stroke = React.createElement("UIStroke", {
			Thickness = 1.5,
			Color = Theme.Colors.border,
		}),
		PreviewLabel = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.9, 0.8),
			BackgroundTransparency = 1,
			Text = "Puzzle Beginner",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			Font = Theme.Font.heading,
		}, {
			PreviewStroke = React.createElement("UIStroke", {
				Thickness = 2,
				Color = Theme.Colors.black,
			}),
			PreviewGradient = React.createElement("UIGradient", {
				Color = RAINBOW_SEQUENCE,
			}),
		}),
	})

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.4,
		ZIndex = 200,
	}, {
		Modal = React.createElement("Frame", {
			ref = modalRef,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(460, 500),
			BackgroundColor3 = Theme.Colors.bgDark,
			ZIndex = 201,
			ClipsDescendants = true,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 14) }),
			Stroke = React.createElement("UIStroke", {
				Thickness = 2,
				Color = Theme.Colors.border,
			}),
			SizeConstraint = React.createElement("UISizeConstraint", {
				MaxSize = Vector2.new(460, 500),
			}),

			-- Title
			Title = React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.03),
				Size = UDim2.fromScale(0.7, 0.08),
				BackgroundTransparency = 1,
				Text = "STARTER PACK",
				TextColor3 = Theme.Colors.gold,
				TextScaled = true,
				Font = Theme.Font.heading,
				ZIndex = 202,
			}, {
				TitleStroke = React.createElement("UIStroke", {
					Thickness = 2,
					Color = Theme.Colors.black,
				}),
			}),

			-- Timer
			Timer = React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.12),
				Size = UDim2.fromScale(0.6, 0.06),
				BackgroundTransparency = 1,
				Text = if isExpired then "EXPIRED" else "Expires in " .. formatMMSS(props.secondsLeft),
				TextColor3 = Theme.Colors.danger,
				TextScaled = true,
				Font = Theme.Font.bold,
				ZIndex = 202,
			}, {
				TimerStroke = React.createElement("UIStroke", {
					Thickness = 1,
					Color = Theme.Colors.black,
				}),
			}),

			-- Contents list
			ContentsList = React.createElement("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.19),
				Size = UDim2.fromScale(0.9, 0.62),
				BackgroundTransparency = 1,
				ZIndex = 202,
			}, contentRows),

			-- Snap effect demo overlay
			DemoOverlay = if demoEffect ~= nil then React.createElement("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 210,
				ClipsDescendants = false,
			}, {
				[demoEffect.key] = React.createElement(SnapEffect, {
					positionX = demoEffect.x,
					positionY = demoEffect.y,
					effectId = demoEffect.effectId,
					effectKey = demoEffect.key,
				}),
			}) else nil,

			-- Buy button
			BuyButton = React.createElement("TextButton", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.84),
				Size = UDim2.fromScale(0.7, 0.09),
				BackgroundColor3 = if isExpired then Theme.Colors.bgMuted else Theme.Colors.success,
				Text = if isExpired then "EXPIRED" else "BUY \u{2014} 79 R$",
				TextColor3 = Theme.Colors.textPrimary,
				TextScaled = true,
				Font = Theme.Font.bold,
				AutoButtonColor = not isExpired,
				ZIndex = 202,
				[React.Event.Activated] = function()
					if not isExpired then
						props.onBuy()
					end
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
				BuyStroke = React.createElement("UIStroke", {
					Thickness = 2,
					Color = Theme.Colors.border,
				}),
			}),

			-- Close button
			CloseBtn = React.createElement("TextButton", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(0.97, 0.02),
				Size = UDim2.fromOffset(36, 36),
				BackgroundColor3 = Theme.Colors.closeRed,
				Text = "X",
				TextColor3 = Theme.Colors.textPrimary,
				TextScaled = true,
				Font = Theme.Font.bold,
				ZIndex = 203,
				[React.Event.Activated] = props.onClose,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
				CloseStroke = React.createElement("UIStroke", {
					Thickness = 2,
					Color = Theme.Colors.border,
				}),
			}),
		}),
	})
end

return StarterPackModal
