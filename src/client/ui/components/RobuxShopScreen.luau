local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)

local MonetizationConfig = require(Shared.MonetizationConfig)
local Theme = require(Shared.Theme)

export type RobuxShopScreenProps = {
	onClose: () -> (),
	playerData: any?,
}

-- Ordered lists for consistent rendering
local GAME_PASS_ORDER = { "VIP", "ALL_IMAGES", "EXPERT", "PUZZLE_ASSIST" }
local DEV_PRODUCT_ORDER = { "CASH_100", "CASH_500", "CASH_1500", "CASH_5000" }

local function RobuxShopScreen(props: RobuxShopScreenProps)
	local ownedGamePasses, setOwnedGamePasses = React.useState({} :: { [string]: boolean })

	-- Check which game passes are already owned
	React.useEffect(function()
		task.spawn(function()
			local localPlayer = Players.LocalPlayer
			if not localPlayer then return end
			local owned: { [string]: boolean } = {}
			for key, pass in MonetizationConfig.GAME_PASSES do
				if pass.id ~= 0 then
					local ok, ownsPass = pcall(function()
						return MarketplaceService:UserOwnsGamePassAsync(localPlayer.UserId, pass.id)
					end)
					if ok and ownsPass then
						owned[key] = true
					end
				end
			end
			setOwnedGamePasses(owned)
		end)
	end, {})

	local function promptGamePass(gamePassId: number)
		pcall(function()
			MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, gamePassId)
		end)
	end

	local function promptDevProduct(productId: number)
		pcall(function()
			MarketplaceService:PromptProductPurchase(Players.LocalPlayer, productId)
		end)
	end

	-- Helper to create a section header label
	local function createSectionHeader(text: string, color: Color3, layoutOrder: number)
		return React.createElement("TextLabel", {
			LayoutOrder = layoutOrder,
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = color,
			TextScaled = true,
			Font = Theme.Font.heading,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, {
			TextStroke = React.createElement("UIStroke", {
				Thickness = 1.5,
				Color = Theme.Colors.black,
			}),
		})
	end

	-- Build the scroll body as a vertical list: header, grid, header, grid
	local bodyChildren: { [string]: any } = {
		ListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0.02, 0),
			PaddingBottom = UDim.new(0.02, 0),
			PaddingLeft = UDim.new(0.02, 0),
			PaddingRight = UDim.new(0.02, 0),
		}),
	}

	local sectionOrder = 1

	-- Section header: Game Passes
	bodyChildren["SectionGamePasses"] = createSectionHeader("Game Passes", Theme.Colors.headerGold, sectionOrder)
	sectionOrder += 1

	-- Game Pass grid container
	local gamePassGridChildren: { [string]: any } = {
		GridLayout = React.createElement("UIGridLayout", {
			CellSize = UDim2.new(0.48, 0, 0, 140),
			CellPadding = UDim2.fromScale(0.02, 0.01),
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	local cardOrder = 1

	-- Game Pass cards
	for _, key in GAME_PASS_ORDER do
		local pass = MonetizationConfig.GAME_PASSES[key]
		if not pass then continue end

		local isOwned = ownedGamePasses[key] == true
		local iconColor = pass.iconColor or Theme.Colors.warning
		local iconText = pass.iconText or "R"

		local actionElement
		if isOwned then
			actionElement = React.createElement("Frame", {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.fromScale(0.95, 0.9),
				Size = UDim2.fromScale(0.4, 0.25),
				BackgroundColor3 = Theme.Colors.bgMuted,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Label = React.createElement("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = "Owned",
					TextColor3 = Theme.Colors.textPrimary,
					TextScaled = true,
					Font = Theme.Font.bold,
				}),
			})
		else
			actionElement = React.createElement("TextButton", {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.fromScale(0.95, 0.9),
				Size = UDim2.fromScale(0.4, 0.25),
				BackgroundColor3 = Theme.Colors.success,
				Text = "R$ " .. pass.robuxPrice,
				TextColor3 = Theme.Colors.textPrimary,
				TextScaled = true,
				Font = Theme.Font.bold,
				[React.Event.Activated] = function()
					promptGamePass(pass.id)
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Stroke = React.createElement("UIStroke", {
					Thickness = 2,
					Color = Theme.Colors.border,
				}),
			})
		end

		gamePassGridChildren["GP_" .. key] = React.createElement("Frame", {
			LayoutOrder = cardOrder,
			BackgroundColor3 = Theme.Colors.bgCard,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 12) }),
			Stroke = React.createElement("UIStroke", {
				Thickness = 2,
				Color = Theme.Colors.border,
			}),
			-- Icon circle
			Icon = React.createElement("Frame", {
				Position = UDim2.fromScale(0.05, 0.1),
				Size = UDim2.fromScale(0.3, 0.5),
				BackgroundColor3 = iconColor,
			}, {
				IconCorner = React.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
				AspectRatio = React.createElement("UIAspectRatioConstraint", {
					AspectRatio = 1,
				}),
				Emoji = React.createElement("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = iconText,
					TextScaled = true,
					Font = Theme.Font.heading,
					TextColor3 = Theme.Colors.textPrimary,
				}),
			}),
			-- Name
			Name = React.createElement("TextLabel", {
				Position = UDim2.fromScale(0.4, 0.08),
				Size = UDim2.fromScale(0.55, 0.2),
				BackgroundTransparency = 1,
				Text = pass.name,
				TextColor3 = Theme.Colors.textPrimary,
				TextScaled = true,
				Font = Theme.Font.bold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}, {
				NameStroke = React.createElement("UIStroke", {
					Thickness = 1,
					Color = Theme.Colors.black,
				}),
			}),
			-- Description
			Desc = React.createElement("TextLabel", {
				Position = UDim2.fromScale(0.4, 0.3),
				Size = UDim2.fromScale(0.55, 0.25),
				BackgroundTransparency = 1,
				Text = pass.description,
				TextColor3 = Theme.Colors.textMuted,
				TextScaled = true,
				Font = Theme.Font.regular,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
			}, {
			}),
			-- Buy button or Owned badge
			Action = actionElement,
		})
		cardOrder += 1
	end

	-- Calculate game pass grid height: rows * (140 + padding)
	local gpRows = math.ceil(#GAME_PASS_ORDER / 2)
	local gpGridHeight = gpRows * 148

	bodyChildren["GamePassGrid"] = React.createElement("Frame", {
		LayoutOrder = sectionOrder,
		Size = UDim2.new(1, 0, 0, gpGridHeight),
		BackgroundTransparency = 1,
	}, gamePassGridChildren)
	sectionOrder += 1

	-- Section header: Buy Coins
	bodyChildren["SectionCoins"] = createSectionHeader("Buy Coins", Theme.Colors.cashGreen, sectionOrder)
	sectionOrder += 1

	-- Coin grid container
	local coinGridChildren: { [string]: any } = {
		GridLayout = React.createElement("UIGridLayout", {
			CellSize = UDim2.new(0.48, 0, 0, 140),
			CellPadding = UDim2.fromScale(0.02, 0.01),
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	cardOrder = 1

	-- Dev Product (coin) cards
	for _, key in DEV_PRODUCT_ORDER do
		local product = MonetizationConfig.DEV_PRODUCTS[key]
		if not product then continue end

		local iconColor = product.iconColor or Theme.Colors.successLight
		local iconText = product.iconText or "$"

		coinGridChildren["DP_" .. key] = React.createElement("Frame", {
			LayoutOrder = cardOrder,
			BackgroundColor3 = Theme.Colors.bgCard,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 12) }),
			Stroke = React.createElement("UIStroke", {
				Thickness = 2,
				Color = Theme.Colors.border,
			}),
			-- Icon circle
			Icon = React.createElement("Frame", {
				Position = UDim2.fromScale(0.05, 0.1),
				Size = UDim2.fromScale(0.3, 0.5),
				BackgroundColor3 = iconColor,
			}, {
				IconCorner = React.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
				AspectRatio = React.createElement("UIAspectRatioConstraint", {
					AspectRatio = 1,
				}),
				Emoji = React.createElement("TextLabel", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = iconText,
					TextScaled = true,
					Font = Theme.Font.heading,
					TextColor3 = Theme.Colors.textPrimary,
				}),
			}),
			-- Name
			Name = React.createElement("TextLabel", {
				Position = UDim2.fromScale(0.4, 0.08),
				Size = UDim2.fromScale(0.55, 0.2),
				BackgroundTransparency = 1,
				Text = product.name,
				TextColor3 = Theme.Colors.textPrimary,
				TextScaled = true,
				Font = Theme.Font.bold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}, {
				NameStroke = React.createElement("UIStroke", {
					Thickness = 1,
					Color = Theme.Colors.black,
				}),
			}),
			-- Description
			Desc = React.createElement("TextLabel", {
				Position = UDim2.fromScale(0.4, 0.3),
				Size = UDim2.fromScale(0.55, 0.25),
				BackgroundTransparency = 1,
				Text = product.description,
				TextColor3 = Theme.Colors.textMuted,
				TextScaled = true,
				Font = Theme.Font.regular,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
			}, {
			}),
			-- Buy button
			BuyButton = React.createElement("TextButton", {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.fromScale(0.95, 0.9),
				Size = UDim2.fromScale(0.4, 0.25),
				BackgroundColor3 = Theme.Colors.success,
				Text = "R$ " .. product.robuxPrice,
				TextColor3 = Theme.Colors.textPrimary,
				TextScaled = true,
				Font = Theme.Font.bold,
				[React.Event.Activated] = function()
					promptDevProduct(product.id)
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Stroke = React.createElement("UIStroke", {
					Thickness = 2,
					Color = Theme.Colors.border,
				}),
			}),
		})
		cardOrder += 1
	end

	-- Calculate coin grid height: rows * (140 + padding)
	local coinRows = math.ceil(#DEV_PRODUCT_ORDER / 2)
	local coinGridHeight = coinRows * 148

	bodyChildren["CoinGrid"] = React.createElement("Frame", {
		LayoutOrder = sectionOrder,
		Size = UDim2.new(1, 0, 0, coinGridHeight),
		BackgroundTransparency = 1,
	}, coinGridChildren)

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 150,
	}, {
		Modal = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.85, 0.85),
			BackgroundColor3 = Theme.Colors.bgDark,
			ClipsDescendants = true,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 16) }),
			AspectRatio = React.createElement("UIAspectRatioConstraint", {
				AspectRatio = 0.85,
				DominantAxis = Enum.DominantAxis.Height,
			}),
			SizeConstraint = React.createElement("UISizeConstraint", {
				MaxSize = Vector2.new(720, math.huge),
			}),
			BorderStroke = React.createElement("UIStroke", {
				Thickness = 3,
				Color = Theme.Colors.border,
			}),

			-- Header
			Header = React.createElement("Frame", {
				Size = UDim2.new(1, 0, 0.08, 0),
				BackgroundColor3 = Theme.Colors.accentBlue,
			}, {
				HeaderCorner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 16) }),
				Title = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.5, 0.7),
					BackgroundTransparency = 1,
					Text = "Robux Shop",
					TextColor3 = Theme.Colors.textPrimary,
					TextScaled = true,
					Font = Theme.Font.heading,
				}, {
					TitleStroke = React.createElement("UIStroke", {
						Thickness = 2,
						Color = Theme.Colors.black,
					}),
				}),
				CloseButton = React.createElement("TextButton", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -8, 0.5, 0),
					Size = UDim2.fromScale(0.06, 0.8),
					BackgroundColor3 = Theme.Colors.closeRed,
					Text = "X",
					TextColor3 = Theme.Colors.textPrimary,
					TextScaled = true,
					Font = Theme.Font.bold,
					[React.Event.Activated] = function()
						props.onClose()
					end,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
					CloseStroke = React.createElement("UIStroke", {
						Thickness = 2,
						Color = Theme.Colors.border,
					}),
					AspectRatio = React.createElement("UIAspectRatioConstraint", {
						AspectRatio = 1,
					}),
				}),
			}),

			-- Scrollable card grid
			Body = React.createElement("ScrollingFrame", {
				Position = UDim2.fromScale(0, 0.08),
				Size = UDim2.fromScale(1, 0.92),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(0, 0, 0, 0),
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Theme.Colors.scrollbar,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, bodyChildren),
		}),
	})
end

return RobuxShopScreen
