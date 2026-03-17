local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)

local Theme = require(Shared.Theme)
local SpinWheelConfig = require(Shared.SpinWheelConfig)
local MonetizationConfig = require(Shared.MonetizationConfig)

export type SpinWheelModalProps = {
	onClose: () -> (),
	canFreeSpin: boolean,
	secondsUntilFreeSpin: number?,
	onSpinComplete: ((reward: string) -> ())?,
	paidSpinsRestricted: boolean?,
}

local NUM_SEGMENTS = #SpinWheelConfig.SEGMENTS
local SPIN_WHEEL_PRODUCT_ID = MonetizationConfig.DEV_PRODUCTS.SPIN_WHEEL.id

-- Strip layout constants
local CELL_WIDTH = 100
local CELL_HEIGHT = 90
local CELL_GAP = 4
local CELL_STEP = CELL_WIDTH + CELL_GAP
local REPEATS = 10 -- repeat segments this many times for long strip
local TOTAL_CELLS = NUM_SEGMENTS * REPEATS
local WINDOW_WIDTH = CELL_STEP * 3 -- show ~3 cells at a time

-- Map config colorKey strings to Theme.Colors
local function getSegmentColor(colorKey: string): Color3
	return Theme.Colors[colorKey] or Theme.Colors.bgElevated
end

local function formatCountdown(seconds: number): string
	if seconds <= 0 then
		return "Ready!"
	end
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	if hours > 0 then
		return hours .. "h " .. minutes .. "m"
	elseif minutes > 0 then
		return minutes .. "m"
	else
		return "< 1m"
	end
end

local function SpinWheelModal(props: SpinWheelModalProps)
	local spinning, setSpinning = React.useState(false)
	local resultText, setResultText = React.useState(nil :: string?)
	local canFreeSpin, setCanFreeSpin = React.useState(props.canFreeSpin)
	local stripRef = React.useRef(nil :: Frame?)
	local showOdds, setShowOdds = React.useState(false)

	-- Countdown timer state (server-provided seconds until UTC midnight)
	local countdownSeconds, setCountdownSeconds = React.useState(function()
		if props.canFreeSpin then
			return 0
		end
		return math.max(0, props.secondsUntilFreeSpin or 0)
	end)

	-- Tick countdown every second; re-query server when it reaches 0
	React.useEffect(function()
		if canFreeSpin then
			return
		end

		local running = true
		task.spawn(function()
			while running do
				task.wait(1)
				if not running then break end
				setCountdownSeconds(function(prev)
					local newVal = prev - 1
					if newVal <= 0 then
						-- Re-query server to verify free spin is actually available
						task.spawn(function()
							local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
							local statusRemote = remotes and remotes:FindFirstChild("GetSpinWheelStatus")
							if statusRemote and statusRemote:IsA("RemoteFunction") then
								local ok, status = pcall(function()
									return statusRemote:InvokeServer()
								end)
								if ok and status then
									if status.canFreeSpin then
										setCanFreeSpin(true)
									else
										-- Server says not yet — update countdown with fresh value
										setCountdownSeconds(math.max(1, status.secondsUntilFreeSpin or 60))
									end
								end
							end
						end)
						return 1 -- keep countdown alive until server responds
					end
					return newVal
				end)
			end
		end)

		return function()
			running = false
		end
	end, { canFreeSpin })

	-- Start strip at a neutral position (centered on a middle cell)
	local startCell = NUM_SEGMENTS * 3
	local initialX = -(startCell * CELL_STEP) + WINDOW_WIDTH / 2 - CELL_WIDTH / 2

	local function doSpin()
		if spinning then return end
		setSpinning(true)
		setResultText(nil)

		task.spawn(function()
			local remotes = ReplicatedStorage:FindFirstChild("PuzzleRemotes")
			if not remotes then
				setSpinning(false)
				return
			end

			local spinRemote = remotes:FindFirstChild("SpinWheel")
			if not spinRemote or not spinRemote:IsA("RemoteFunction") then
				setSpinning(false)
				return
			end

			local ok, result = pcall(function()
				return spinRemote:InvokeServer()
			end)

			if not ok or not result or not result.success then
				setSpinning(false)
				if result and result.message then
					setResultText({ isError = true, text = result.message })
				end
				return
			end

			local targetIndex = result.segmentIndex

			-- Pick a target cell in the later repeats so the strip scrolls a good distance
			local targetRepeat = 6 + math.random(0, 1)
			local targetCellIndex = targetRepeat * NUM_SEGMENTS + (targetIndex - 1)

			-- Add sub-cell jitter so it doesn't always land dead center
			local jitter = (math.random() - 0.5) * (CELL_WIDTH * 0.4)

			-- Calculate X position to center this cell under the pointer
			local targetX = -(targetCellIndex * CELL_STEP) + WINDOW_WIDTH / 2 - CELL_WIDTH / 2 + jitter

			local strip = stripRef.current
			if strip then
				-- Reset to start position instantly
				strip.Position = UDim2.new(0, initialX, 0, 0)

				local tween = TweenService:Create(strip, TweenInfo.new(4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
					Position = UDim2.new(0, targetX, 0, 0),
				})
				tween:Play()
				tween.Completed:Wait()
			else
				task.wait(0.5)
			end

			-- Update state
			setCanFreeSpin(false)
			-- Reset countdown — compute seconds until next UTC midnight
			local utcNow = os.date("!*t", os.time())
			local secsUntilMidnight = (24 - utcNow.hour - 1) * 3600 + (60 - utcNow.min - 1) * 60 + (60 - utcNow.sec)
			setCountdownSeconds(secsUntilMidnight)
			setResultText({ isError = false, text = result.reward })
			setSpinning(false)

			if props.onSpinComplete then
				props.onSpinComplete(result.reward)
			end
		end)
	end

	local function doPaidSpin()
		if spinning then return end
		setSpinning(true)
		setResultText(nil)

		task.spawn(function()
			local player = Players.LocalPlayer
			if not player then
				setSpinning(false)
				return
			end

			-- Prompt Robux purchase
			MarketplaceService:PromptProductPurchase(player, SPIN_WHEEL_PRODUCT_ID)

			-- Wait for purchase result
			local purchaseConnection
			local purchased = false

			purchaseConnection = MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, isPurchased)
				if userId == player.UserId and productId == SPIN_WHEEL_PRODUCT_ID then
					purchased = isPurchased
					if purchaseConnection then
						purchaseConnection:Disconnect()
						purchaseConnection = nil
					end
				end
			end)

			-- Wait for callback (with timeout)
			local waited = 0
			while purchaseConnection and waited < 120 do
				task.wait(0.1)
				waited = waited + 0.1
			end
			if purchaseConnection then
				purchaseConnection:Disconnect()
			end

			if not purchased then
				setSpinning(false)
				return
			end

			-- Small delay to ensure ProcessReceipt completes server-side
			task.wait(0.3)

			-- Now spin using the token
			doSpin()
		end)
	end

	-- === Build the scrolling strip of cells ===
	local stripChildren: { [string]: any } = {}
	stripChildren["Layout"] = React.createElement("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, CELL_GAP),
	})

	for cellIdx = 0, TOTAL_CELLS - 1 do
		local segIdx = (cellIdx % NUM_SEGMENTS) + 1
		local segment = SpinWheelConfig.SEGMENTS[segIdx]
		local color = getSegmentColor(segment.colorKey)

		stripChildren["Cell" .. cellIdx] = React.createElement("Frame", {
			LayoutOrder = cellIdx,
			Size = UDim2.fromOffset(CELL_WIDTH, CELL_HEIGHT),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Stroke = React.createElement("UIStroke", {
				Thickness = 1.5,
				Color = Theme.Colors.borderDark,
			}),
			Label = React.createElement("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = segment.label,
				TextColor3 = Theme.Colors.textPrimary,
				TextSize = Theme.TextSize.large,
				Font = Theme.Font.bold,
				TextScaled = true,
				ZIndex = 2,
			}, {
				Pad = React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0.1, 0),
					PaddingRight = UDim.new(0.1, 0),
					PaddingTop = UDim.new(0.15, 0),
					PaddingBottom = UDim.new(0.15, 0),
				}),
				TextStroke = React.createElement("UIStroke", {
					Thickness = 2,
					Color = Theme.Colors.black,
				}),
			}),
		})
	end

	-- Determine button text and availability
	local canSpin = not spinning
	local buttonText = "FREE SPIN!"
	local buttonColor = Theme.Colors.success
	local isPaidSpin = false
	local paidRestricted = props.paidSpinsRestricted == true

	if not canFreeSpin then
		if paidRestricted then
			buttonText = "Paid spins unavailable"
			buttonColor = Theme.Colors.bgElevated
			canSpin = false
		else
			buttonText = "Spin (R$25)"
			buttonColor = Theme.Colors.gold
			isPaidSpin = true
		end
	end

	if spinning then
		buttonText = "Spinning..."
		canSpin = false
		buttonColor = Theme.Colors.bgElevated
	end

	-- Modal content
	local modalChildren: { [string]: any } = {}
	modalChildren["Layout"] = React.createElement("UIListLayout", {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 12),
	})
	modalChildren["Padding"] = React.createElement("UIPadding", {
		PaddingTop = UDim.new(0, 16),
		PaddingBottom = UDim.new(0, 16),
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
	})

	-- Banner image
	modalChildren["BannerImage"] = React.createElement("ImageLabel", {
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 80),
		BackgroundTransparency = 1,
		Image = "rbxassetid://124221102367378",
		ScaleType = Enum.ScaleType.Fit,
	})

	-- Header row (title + info button)
	modalChildren["HeaderRow"] = React.createElement("Frame", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
	}, {
		Title = React.createElement("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "Spin the Wheel!",
			TextColor3 = Theme.Colors.gold,
			TextSize = Theme.TextSize.heading,
			Font = Theme.Font.heading,
		}, {
			TextStroke = React.createElement("UIStroke", {
				Thickness = 2,
				Color = Theme.Colors.black,
			}),
		}),
		InfoBtn = React.createElement("TextButton", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = Theme.Colors.bgElevated,
			Text = "i",
			TextColor3 = Theme.Colors.textSecondary,
			TextSize = Theme.TextSize.body,
			Font = Theme.Font.bold,
			ZIndex = 5,
			[React.Event.Activated] = function()
				setShowOdds(function(prev) return not prev end)
			end,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Stroke = React.createElement("UIStroke", {
				Thickness = 1.5,
				Color = Theme.Colors.border,
			}),
		}),
	})

	-- Odds panel (shown when info button toggled)
	if showOdds then
		local oddsRows: { [string]: any } = {}
		oddsRows["Layout"] = React.createElement("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 3),
		})
		oddsRows["Pad"] = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		})

		for i, seg in SpinWheelConfig.SEGMENTS do
			local pct = math.floor(seg.weight / SpinWheelConfig.TOTAL_WEIGHT * 100 + 0.5)
			local color = getSegmentColor(seg.colorKey)

			oddsRows["Row" .. i] = React.createElement("Frame", {
				LayoutOrder = i,
				Size = UDim2.new(1, 0, 0, 22),
				BackgroundTransparency = 1,
			}, {
				Dot = React.createElement("Frame", {
					Position = UDim2.fromOffset(0, 5),
					Size = UDim2.fromOffset(12, 12),
					BackgroundColor3 = color,
				}, {
					DotCorner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 3) }),
				}),
				Label = React.createElement("TextLabel", {
					Position = UDim2.fromOffset(18, 0),
					Size = UDim2.new(1, -60, 1, 0),
					BackgroundTransparency = 1,
					Text = seg.label,
					TextColor3 = Theme.Colors.textPrimary,
					TextSize = Theme.TextSize.small,
					Font = Theme.Font.medium,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Pct = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.new(0, 40, 1, 0),
					BackgroundTransparency = 1,
					Text = pct .. "%",
					TextColor3 = Theme.Colors.textMuted,
					TextSize = Theme.TextSize.small,
					Font = Theme.Font.medium,
					TextXAlignment = Enum.TextXAlignment.Right,
				}),
			})
		end

		modalChildren["OddsPanel"] = React.createElement("Frame", {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 210),
			BackgroundColor3 = Theme.Colors.bgCard,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Stroke = React.createElement("UIStroke", {
				Thickness = 1,
				Color = Theme.Colors.border,
			}),
			Content = React.createElement("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
			}, oddsRows),
		})
	end

	-- Spinner window (clips the strip, shows ~3 cells)
	modalChildren["SpinnerWindow"] = React.createElement("Frame", {
		LayoutOrder = 3,
		Size = UDim2.fromOffset(WINDOW_WIDTH, CELL_HEIGHT + 16),
		BackgroundColor3 = Theme.Colors.bgMedium,
		ClipsDescendants = true,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 12) }),
		Stroke = React.createElement("UIStroke", {
			Thickness = 2,
			Color = Theme.Colors.gold,
		}),

		-- The scrolling strip
		Strip = React.createElement("Frame", {
			ref = stripRef,
			Position = UDim2.fromOffset(initialX, 8),
			Size = UDim2.fromOffset(TOTAL_CELLS * CELL_STEP, CELL_HEIGHT),
			BackgroundTransparency = 1,
		}, stripChildren),

		-- Center pointer (top)
		PointerTop = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(20, 10),
			BackgroundColor3 = Theme.Colors.danger,
			ZIndex = 10,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
		}),

		-- Center pointer (bottom)
		PointerBottom = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromOffset(20, 10),
			BackgroundColor3 = Theme.Colors.danger,
			ZIndex = 10,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
		}),

		-- Center highlight lines
		HighlightLeft = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, -(CELL_WIDTH / 2 + 2), 0, 0),
			Size = UDim2.new(0, 2, 1, 0),
			BackgroundColor3 = Theme.Colors.danger,
			BackgroundTransparency = 0.3,
			ZIndex = 10,
		}),
		HighlightRight = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, CELL_WIDTH / 2 + 2, 0, 0),
			Size = UDim2.new(0, 2, 1, 0),
			BackgroundColor3 = Theme.Colors.danger,
			BackgroundTransparency = 0.3,
			ZIndex = 10,
		}),
	})

	-- Result text
	if resultText then
		local displayText = if resultText.isError then resultText.text else "You won: " .. resultText.text
		local displayColor = if resultText.isError then Theme.Colors.danger else Theme.Colors.cashGreen
		modalChildren["Result"] = React.createElement("TextLabel", {
			LayoutOrder = 4,
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			Text = displayText,
			TextColor3 = displayColor,
			TextSize = Theme.TextSize.large,
			Font = Theme.Font.bold,
		}, {
			TextStroke = React.createElement("UIStroke", {
				Thickness = 1.5,
				Color = Theme.Colors.black,
			}),
		})
	end

	-- Countdown timer (shown when free spin is not available)
	if not canFreeSpin and not spinning and countdownSeconds > 0 then
		modalChildren["Countdown"] = React.createElement("TextLabel", {
			LayoutOrder = 4.5,
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			Text = "Next free spin: " .. formatCountdown(countdownSeconds),
			TextColor3 = Theme.Colors.textMuted,
			TextSize = Theme.TextSize.body,
			Font = Theme.Font.medium,
		})
	end

	-- Region restriction notice
	if not canFreeSpin and paidRestricted and not spinning then
		modalChildren["RegionNotice"] = React.createElement("TextLabel", {
			LayoutOrder = 4.8,
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			Text = "Paid spins unavailable in your region",
			TextColor3 = Theme.Colors.textMuted,
			TextSize = Theme.TextSize.small,
			Font = Theme.Font.medium,
		})
	end

	-- Spin button
	modalChildren["SpinBtn"] = React.createElement("TextButton", {
		LayoutOrder = 5,
		Size = UDim2.new(0.7, 0, 0, 48),
		BackgroundColor3 = buttonColor,
		Text = buttonText,
		TextColor3 = Theme.Colors.textPrimary,
		TextSize = Theme.TextSize.button,
		Font = Theme.Font.bold,
		[React.Event.Activated] = function()
			if canSpin then
				if isPaidSpin then
					doPaidSpin()
				else
					doSpin()
				end
			end
		end,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
		Stroke = React.createElement("UIStroke", {
			Thickness = 2,
			Color = Theme.Colors.border,
		}),
	})

	-- Close button
	modalChildren["CloseBtn"] = React.createElement("TextButton", {
		LayoutOrder = 6,
		Size = UDim2.new(0.4, 0, 0, 32),
		BackgroundColor3 = Theme.Colors.bgElevated,
		Text = "Close",
		TextColor3 = Theme.Colors.textSecondary,
		TextSize = Theme.TextSize.body,
		Font = Theme.Font.medium,
		[React.Event.Activated] = props.onClose,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
	})

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Backdrop = React.createElement("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Colors.black,
			BackgroundTransparency = Theme.Transparency.overlay,
			Text = "",
			[React.Event.Activated] = function()
				if not spinning then
					props.onClose()
				end
			end,
		}),
		Modal = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(370, if showOdds then 580 else 360),
			BackgroundColor3 = Theme.Colors.bgDark,
			ZIndex = 2,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = Theme.Radius.modal }),
			Stroke = React.createElement("UIStroke", {
				Thickness = 2,
				Color = Theme.Colors.border,
			}),
			Content = React.createElement("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 2,
			}, modalChildren),
		}),
	})
end

return SpinWheelModal
