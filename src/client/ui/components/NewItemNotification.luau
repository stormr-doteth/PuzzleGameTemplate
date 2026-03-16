local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared.Theme)

-- Sound asset ID for purchase celebration (set to a valid rbxassetid to enable)
local PURCHASE_SOUND_ID: string? = nil

-- Confetti styles (duplicated from CompleteScreen)
local CONFETTI_COUNT = 30

type ConfettiStyleConfig = {
	colors: { Color3 },
	cornerRadius: UDim,
}

local CONFETTI_STYLES: { [string]: ConfettiStyleConfig } = {
	default = {
		colors = {
			Color3.fromRGB(255, 80, 80),
			Color3.fromRGB(80, 200, 255),
			Color3.fromRGB(255, 220, 80),
			Color3.fromRGB(120, 255, 120),
			Color3.fromRGB(220, 120, 255),
			Color3.fromRGB(255, 160, 60),
		},
		cornerRadius = UDim.new(0, 2),
	},
	confetti_hearts = {
		colors = {
			Color3.fromRGB(255, 80, 120),
			Color3.fromRGB(255, 100, 150),
			Color3.fromRGB(230, 50, 80),
			Color3.fromRGB(255, 150, 180),
			Color3.fromRGB(200, 30, 60),
		},
		cornerRadius = UDim.new(1, 0),
	},
	confetti_stars = {
		colors = {
			Color3.fromRGB(255, 215, 0),
			Color3.fromRGB(255, 235, 80),
			Color3.fromRGB(230, 190, 0),
			Color3.fromRGB(255, 200, 50),
			Color3.fromRGB(200, 170, 0),
		},
		cornerRadius = UDim.new(0, 0),
	},
	confetti_rainbow = {
		colors = {
			Color3.fromRGB(255, 0, 0),
			Color3.fromRGB(255, 127, 0),
			Color3.fromRGB(255, 255, 0),
			Color3.fromRGB(0, 255, 0),
			Color3.fromRGB(0, 0, 255),
			Color3.fromRGB(75, 0, 130),
			Color3.fromRGB(148, 0, 211),
		},
		cornerRadius = UDim.new(0, 2),
	},
	confetti_fire = {
		colors = {
			Color3.fromRGB(255, 60, 20),
			Color3.fromRGB(255, 120, 30),
			Color3.fromRGB(255, 180, 40),
			Color3.fromRGB(230, 40, 10),
			Color3.fromRGB(255, 200, 60),
		},
		cornerRadius = UDim.new(0, 2),
	},
}

local CATEGORY_LABELS = {
	board_skins = "Board Skin",
	confetti_styles = "Confetti Style",
	snap_effects = "Snap Effect",
	cash_purchase = "Cash Purchase",
}

local CATEGORY_COLORS = {
	board_skins = Theme.Colors.accentBlue,
	confetti_styles = Color3.fromRGB(200, 100, 220),
	snap_effects = Theme.Colors.orange,
	cash_purchase = Theme.Colors.cashGreen,
}

local function ConfettiPiece(props: { delay: number, index: number, styleConfig: ConfettiStyleConfig? })
	local ref = React.useRef(nil :: Frame?)
	local styleConfig = props.styleConfig or CONFETTI_STYLES.default

	React.useEffect(function()
		local frame = ref.current
		if not frame then return end

		task.delay(props.delay, function()
			if not frame or not frame.Parent then return end

			local tweenInfo = TweenInfo.new(
				2 + math.random() * 2,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			)

			local drift = (math.random() - 0.5) * 0.15
			local endX = frame.Position.X.Scale + drift
			local tween = TweenService:Create(frame, tweenInfo, {
				Position = UDim2.new(endX, 0, 1.1, 0),
				Rotation = frame.Rotation + (math.random(-360, 360)),
				BackgroundTransparency = 0.6,
			})
			tween:Play()
		end)
	end, {})

	local size = math.random(8, 16)
	local colors = styleConfig.colors
	local color = colors[math.random(1, #colors)]
	local startX = math.random()
	local startRotation = math.random(0, 360)

	return React.createElement("Frame", {
		ref = ref,
		Size = UDim2.fromOffset(size, size * (0.6 + math.random() * 0.8)),
		Position = UDim2.new(startX, 0, -0.05, 0),
		Rotation = startRotation,
		BackgroundColor3 = color,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = 100,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = styleConfig.cornerRadius }),
	})
end

export type NewItemNotificationProps = {
	item: any,
	equippedConfettiStyle: string?,
	onDismiss: () -> (),
}

local function NewItemNotification(props: NewItemNotificationProps)
	local item = props.item
	local dismissed = React.useRef(false)
	local cardRef = React.useRef(nil :: Frame?)

	local function dismiss()
		if dismissed.current then return end
		dismissed.current = true

		local card = cardRef.current
		if card then
			local tweenOut = TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = UDim2.fromOffset(0, 0),
			})
			tweenOut:Play()
			tweenOut.Completed:Once(function()
				props.onDismiss()
			end)
		else
			props.onDismiss()
		end
	end

	-- Card pop-in animation + sound + auto-dismiss timer
	React.useEffect(function()
		local card = cardRef.current
		if card then
			card.Size = UDim2.fromOffset(0, 0)
			local tweenIn = TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, 360, 0, 320),
			})
			tweenIn:Play()
		end

		-- Play celebration sound if configured
		local sound: Sound? = nil
		if PURCHASE_SOUND_ID then
			sound = Instance.new("Sound")
			sound.SoundId = PURCHASE_SOUND_ID
			sound.Volume = 0.8
			sound.Parent = SoundService
			sound:Play()
			sound.Ended:Once(function()
				if sound then
					sound:Destroy()
				end
			end)
		end

		local timer = task.delay(3.5, function()
			dismiss()
		end)

		return function()
			task.cancel(timer)
			if sound then
				sound:Destroy()
				sound = nil
			end
		end
	end, {})

	-- Confetti
	local styleKey = props.equippedConfettiStyle or ""
	local styleConfig = CONFETTI_STYLES[styleKey] or CONFETTI_STYLES.default

	local confettiChildren: { [string]: any } = {}
	for i = 1, CONFETTI_COUNT do
		confettiChildren["Confetti_" .. i] = React.createElement(ConfettiPiece, {
			index = i,
			delay = math.random() * 0.8,
			styleConfig = styleConfig,
		})
	end

	-- Item info
	local categoryLabel = CATEGORY_LABELS[item.category] or "Item"
	local categoryColor = CATEGORY_COLORS[item.category] or Theme.Colors.accentBlue
	local swatchColor = item.previewColor or categoryColor

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		-- Confetti layer
		Confetti = React.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 100,
		}, confettiChildren),

		-- Dark overlay backdrop (tap to dismiss)
		Backdrop = React.createElement("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Colors.black,
			BackgroundTransparency = Theme.Transparency.overlay,
			BorderSizePixel = 0,
			Text = "",
			ZIndex = 105,
			[React.Event.Activated] = dismiss,
		}),

		-- Centered card
		Card = React.createElement("Frame", {
			ref = cardRef,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 360, 0, 320),
			BackgroundColor3 = Theme.Colors.bgCard,
			BorderSizePixel = 0,
			ZIndex = 110,
			ClipsDescendants = true,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = Theme.Radius.modal }),
			Stroke = React.createElement("UIStroke", {
				Thickness = 2,
				Color = Theme.Colors.border,
			}),
			Layout = React.createElement("UIListLayout", {
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}),

			-- Gold header bar
			Header = React.createElement("Frame", {
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 44),
				BackgroundColor3 = Theme.Colors.headerGold,
			}, {
				HeaderCorner = React.createElement("UICorner", { CornerRadius = Theme.Radius.modal }),
				Title = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.8, 0.7),
					BackgroundTransparency = 1,
					Text = if item.category == "cash_purchase" then "CASH RECEIVED!" else "NEW ITEM UNLOCKED!",
					TextColor3 = Theme.Colors.textPrimary,
					TextScaled = true,
					Font = Theme.Font.heading,
				}, {
					TitleStroke = React.createElement("UIStroke", {
						Thickness = 2,
						Color = Theme.Colors.black,
					}),
				}),
			}),

			-- Item preview swatch
			SwatchWrapper = React.createElement("Frame", {
				LayoutOrder = 2,
				Size = UDim2.new(0, 80, 0, 80),
				BackgroundColor3 = swatchColor,
				ClipsDescendants = true,
			}, {
				SwatchCorner = React.createElement("UICorner", { CornerRadius = Theme.Radius.md }),
				SwatchStroke = React.createElement("UIStroke", {
					Thickness = 1.5,
					Color = Theme.Colors.border,
				}),
				SwatchImage = if item.backgroundImage then React.createElement("ImageLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Image = item.backgroundImage,
					ScaleType = Enum.ScaleType.Crop,
				}) else nil,
				Letter = React.createElement("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = string.sub(item.name, 1, 1),
					TextColor3 = Theme.Colors.textPrimary,
					TextScaled = true,
					Font = Theme.Font.heading,
					ZIndex = 2,
				}, {
					LetterStroke = React.createElement("UIStroke", {
						Thickness = 1,
						Color = Theme.Colors.black,
					}),
				}),
			}),

			-- Category badge
			Badge = React.createElement("Frame", {
				LayoutOrder = 3,
				Size = UDim2.new(0, 120, 0, 24),
				BackgroundColor3 = categoryColor,
			}, {
				BadgeCorner = React.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
				BadgeLabel = React.createElement("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = categoryLabel,
					TextColor3 = Theme.Colors.textPrimary,
					TextScaled = true,
					Font = Theme.Font.bold,
				}, {
					Padding = React.createElement("UIPadding", {
						PaddingLeft = UDim.new(0, 12),
						PaddingRight = UDim.new(0, 12),
						PaddingTop = UDim.new(0, 2),
						PaddingBottom = UDim.new(0, 2),
					}),
				}),
			}),

			-- Item name
			ItemName = React.createElement("TextLabel", {
				LayoutOrder = 4,
				Size = UDim2.new(0.8, 0, 0, 32),
				BackgroundTransparency = 1,
				Text = item.name,
				TextColor3 = Theme.Colors.gold,
				TextScaled = true,
				Font = Theme.Font.heading,
			}, {
				NameStroke = React.createElement("UIStroke", {
					Thickness = 1.5,
					Color = Theme.Colors.black,
				}),
			}),

			-- Item description
			ItemDesc = React.createElement("TextLabel", {
				LayoutOrder = 5,
				Size = UDim2.new(0.8, 0, 0, 24),
				BackgroundTransparency = 1,
				Text = item.description or "",
				TextColor3 = Theme.Colors.textSecondary,
				TextScaled = true,
				Font = Theme.Font.regular,
				TextWrapped = true,
			}),

			-- Dismiss hint
			DismissHint = React.createElement("TextLabel", {
				LayoutOrder = 10,
				Size = UDim2.new(0.8, 0, 0, 20),
				BackgroundTransparency = 1,
				Text = "Tap anywhere to dismiss",
				TextColor3 = Theme.Colors.textMuted,
				TextScaled = true,
				Font = Theme.Font.regular,
			}),
		}),
	})
end

return NewItemNotification
