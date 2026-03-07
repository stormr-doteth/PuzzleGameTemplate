local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)

local Theme = require(Shared.Theme)
local DailyRewardsConfig = require(Shared.DailyRewardsConfig)

export type DailyRewardModalProps = {
	onClose: () -> (),
	rewardStatus: {
		streak: number,
		canClaim: boolean,
		nextDay: number?,
	}?,
	onClaim: () -> (),
	claimResult: {
		success: boolean,
		day: number?,
		cash: number?,
		bonusReward: any?,
	}?,
}

local function DailyRewardModal(props: DailyRewardModalProps)
	local status = props.rewardStatus
	local streak = if status then status.streak else 0
	local canClaim = if status then status.canClaim else false
	local nextDay = if status and status.nextDay then status.nextDay else streak + 1
	if nextDay > DailyRewardsConfig.STREAK_LENGTH then
		nextDay = 1
	end

	local claimed, setClaimed = React.useState(false)
	local claimResult = props.claimResult

	-- Auto-close after claim animation
	React.useEffect(function()
		if claimResult and claimResult.success then
			setClaimed(true)
			local thread = task.delay(2.5, function()
				props.onClose()
			end)
			return function()
				task.cancel(thread)
			end
		end
		return nil
	end, { claimResult })

	-- Build day circles
	local dayCircles: { [string]: any } = {}
	dayCircles["Layout"] = React.createElement("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	})

	for i = 1, DailyRewardsConfig.STREAK_LENGTH do
		local reward = DailyRewardsConfig.REWARDS[i]
		local isPast = i <= streak
		local isCurrent = i == nextDay and canClaim
		local isDay7 = i == 7

		local bgColor = Theme.Colors.bgElevated
		local borderColor = Theme.Colors.border
		local textColor = Theme.Colors.textMuted
		local circleSize = UDim2.fromOffset(52, 60)

		if isPast then
			bgColor = Theme.Colors.success
			borderColor = Theme.Colors.successLight
			textColor = Theme.Colors.textPrimary
		elseif isCurrent then
			bgColor = Theme.Colors.gold
			borderColor = Theme.Colors.warning
			textColor = Theme.Colors.bgDark
		end

		if isDay7 then
			circleSize = UDim2.fromOffset(64, 68)
		end

		local circleChildren: { [string]: any } = {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Stroke = React.createElement("UIStroke", {
				Thickness = if isCurrent then 2.5 else 1.5,
				Color = borderColor,
			}),
			DayLabel = React.createElement("TextLabel", {
				Position = UDim2.fromScale(0, 0.02),
				Size = UDim2.fromScale(1, 0.32),
				BackgroundTransparency = 1,
				Text = "Day " .. i,
				TextColor3 = textColor,
				TextSize = Theme.TextSize.tiny,
				Font = Theme.Font.bold,
				TextScaled = true,
			}),
			RewardLabel = React.createElement("TextLabel", {
				Position = UDim2.fromScale(0, 0.32),
				Size = UDim2.fromScale(1, 0.36),
				BackgroundTransparency = 1,
				Text = if reward then reward.label else "",
				TextColor3 = textColor,
				TextSize = Theme.TextSize.small,
				Font = Theme.Font.bold,
				TextScaled = true,
			}),
		}

		if isPast then
			circleChildren["Check"] = React.createElement("TextLabel", {
				Position = UDim2.fromScale(0, 0.62),
				Size = UDim2.fromScale(1, 0.34),
				BackgroundTransparency = 1,
				Text = "\u{2713}",
				TextColor3 = Theme.Colors.textPrimary,
				TextSize = Theme.TextSize.body,
				Font = Theme.Font.bold,
				TextScaled = true,
			})
		end

		if isDay7 then
			circleChildren["Star"] = React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 4, 0, -4),
				Size = UDim2.fromOffset(18, 18),
				BackgroundTransparency = 1,
				Text = "\u{2B50}",
				TextSize = 14,
				ZIndex = 5,
			})
		end

		dayCircles["Day" .. i] = React.createElement("Frame", {
			LayoutOrder = i,
			Size = circleSize,
			BackgroundColor3 = bgColor,
		}, circleChildren)
	end

	-- Build modal content
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

	modalChildren["Title"] = React.createElement("TextLabel", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		Text = "Daily Reward",
		TextColor3 = Theme.Colors.gold,
		TextSize = Theme.TextSize.heading,
		Font = Theme.Font.heading,
	}, {
		TextStroke = React.createElement("UIStroke", {
			Thickness = 2,
			Color = Theme.Colors.black,
		}),
	})

	modalChildren["Subtitle"] = React.createElement("TextLabel", {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = "Come back every day for bigger rewards!",
		TextColor3 = Theme.Colors.textSecondary,
		TextSize = Theme.TextSize.body,
		Font = Theme.Font.regular,
	})

	modalChildren["DayRow"] = React.createElement("Frame", {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 72),
		BackgroundTransparency = 1,
	}, dayCircles)

	-- Claim button or result
	if claimed and claimResult and claimResult.success then
		local resultText = "+$" .. (claimResult.cash or 0)
		if claimResult.bonusReward then
			if claimResult.bonusReward.type == "snap_effect" then
				resultText = resultText .. " + Snap Effect!"
			elseif claimResult.bonusReward.type == "hints" then
				resultText = resultText .. " + " .. claimResult.bonusReward.count .. " Hints!"
			end
		end

		modalChildren["Result"] = React.createElement("TextLabel", {
			LayoutOrder = 4,
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			Text = resultText,
			TextColor3 = Theme.Colors.cashGreen,
			TextSize = Theme.TextSize.large,
			Font = Theme.Font.bold,
		}, {
			TextStroke = React.createElement("UIStroke", {
				Thickness = 1.5,
				Color = Theme.Colors.black,
			}),
		})
	elseif canClaim then
		modalChildren["ClaimBtn"] = React.createElement("TextButton", {
			LayoutOrder = 4,
			Size = UDim2.new(0.6, 0, 0, 48),
			BackgroundColor3 = Theme.Colors.success,
			Text = "Claim!",
			TextColor3 = Theme.Colors.textPrimary,
			TextSize = Theme.TextSize.large,
			Font = Theme.Font.bold,
			[React.Event.Activated] = function()
				if not claimed then
					props.onClaim()
				end
			end,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
			Stroke = React.createElement("UIStroke", {
				Thickness = 2,
				Color = Theme.Colors.successLight,
			}),
		})
	else
		modalChildren["AlreadyClaimed"] = React.createElement("TextLabel", {
			LayoutOrder = 4,
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			Text = "Come back tomorrow!",
			TextColor3 = Theme.Colors.textMuted,
			TextSize = Theme.TextSize.body,
			Font = Theme.Font.medium,
		})
	end

	-- Close button
	modalChildren["CloseBtn"] = React.createElement("TextButton", {
		LayoutOrder = 5,
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
		ZIndex = Theme.ZIndex.modal,
	}, {
		-- Backdrop
		Backdrop = React.createElement("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Colors.black,
			BackgroundTransparency = Theme.Transparency.overlay,
			Text = "",
			ZIndex = Theme.ZIndex.modal,
			[React.Event.Activated] = props.onClose,
		}),
		-- Modal
		Modal = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(460, 320),
			BackgroundColor3 = Theme.Colors.bgDark,
			ZIndex = Theme.ZIndex.modal + 1,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = Theme.Radius.modal }),
			Stroke = React.createElement("UIStroke", {
				Thickness = 2,
				Color = Theme.Colors.border,
			}),
			Content = React.createElement("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = Theme.ZIndex.modal + 1,
			}, modalChildren),
		}),
	})
end

return DailyRewardModal
