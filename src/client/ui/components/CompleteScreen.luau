local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

export type CompleteScreenProps = {
	onPlayAgain: () -> (),
	onAdmire: () -> (),
	completionTime: number?,
	rewardData: {
		xpGained: number?,
		cashGained: number?,
		newLevel: number?,
		unlockedImages: { string }?,
		isPersonalBest: boolean?,
		isSpeedBonus: boolean?,
	}?,
	isPersonalBest: boolean?,
	previousBest: number?,
	equippedConfettiStyle: string?,
}

local CONFETTI_COUNT = 50

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

local function formatTime(seconds: number): string
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%d:%02d", mins, secs)
end

local function ConfettiPiece(props: { delay: number, index: number, styleConfig: ConfettiStyleConfig? })
	local ref = React.useRef(nil :: Frame?)
	local styleConfig = props.styleConfig or CONFETTI_STYLES.default

	React.useEffect(function()
		local frame = ref.current
		if not frame then return end

		task.delay(props.delay, function()
			if not frame or not frame.Parent then return end

			local tweenInfo = TweenInfo.new(
				2 + math.random() * 2, -- duration 2-4s
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
	local startX = math.random() -- 0-1 scale across screen
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

local function CompleteScreen(props: CompleteScreenProps)
	-- Resolve confetti style
	local styleKey = props.equippedConfettiStyle or ""
	local styleConfig = CONFETTI_STYLES[styleKey] or CONFETTI_STYLES.default

	local confettiChildren: { [string]: any } = {}

	for i = 1, CONFETTI_COUNT do
		confettiChildren["Confetti_" .. i] = React.createElement(ConfettiPiece, {
			index = i,
			delay = math.random() * 1.5, -- stagger spawns over 1.5s
			styleConfig = styleConfig,
		})
	end

	-- Build card children
	local cardChildren: { [string]: any } = {}

	cardChildren["Layout"] = React.createElement("UIListLayout", {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	})

	cardChildren["Padding"] = React.createElement("UIPadding", {
		PaddingTop = UDim.new(0, 16),
		PaddingBottom = UDim.new(0, 16),
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
	})

	cardChildren["Corner"] = React.createElement("UICorner", { CornerRadius = UDim.new(0, 16) })

	cardChildren["Title"] = React.createElement("TextLabel", {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		Text = "Puzzle Complete!",
		TextColor3 = Color3.fromRGB(255, 220, 80),
		TextSize = 44,
		Font = Enum.Font.GothamBold,
		TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
		TextStrokeTransparency = 0.3,
	})

	-- Time display
	if props.completionTime and props.completionTime > 0 then
		local timeText = "Completed in " .. formatTime(props.completionTime)
		cardChildren["TimeLabel"] = React.createElement("TextLabel", {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
			Text = timeText,
			TextColor3 = Color3.fromRGB(220, 220, 230),
			TextSize = 22,
			Font = Enum.Font.GothamMedium,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.5,
		})
	end

	-- Personal best display
	if props.isPersonalBest then
		cardChildren["PersonalBest"] = React.createElement("TextLabel", {
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
			Text = "NEW BEST! " .. formatTime(props.completionTime or 0),
			TextColor3 = Color3.fromRGB(255, 215, 0),
			TextSize = 24,
			Font = Enum.Font.GothamBold,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.3,
		})
	elseif props.previousBest then
		cardChildren["BestComparison"] = React.createElement("TextLabel", {
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundTransparency = 1,
			Text = "Best: " .. formatTime(props.previousBest) .. " | This run: " .. formatTime(props.completionTime or 0),
			TextColor3 = Color3.fromRGB(180, 180, 200),
			TextSize = 18,
			Font = Enum.Font.Gotham,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.5,
		})
	end

	-- Reward display (Phase 2+)
	local rewardData = props.rewardData
	if rewardData then
		local rewardParts = {}
		if rewardData.xpGained and rewardData.xpGained > 0 then
			table.insert(rewardParts, "+" .. rewardData.xpGained .. " XP")
		end
		if rewardData.cashGained and rewardData.cashGained > 0 then
			table.insert(rewardParts, "+" .. rewardData.cashGained .. " Cash")
		end

		if #rewardParts > 0 then
			cardChildren["Rewards"] = React.createElement("TextLabel", {
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundTransparency = 1,
				Text = table.concat(rewardParts, "  "),
				TextColor3 = Color3.fromRGB(120, 255, 120),
				TextSize = 22,
				Font = Enum.Font.GothamBold,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				TextStrokeTransparency = 0.3,
			})
		end

		if rewardData.isSpeedBonus then
			cardChildren["SpeedBonus"] = React.createElement("TextLabel", {
				LayoutOrder = 5,
				Size = UDim2.new(1, 0, 0, 26),
				BackgroundTransparency = 1,
				Text = "SPEED BONUS!",
				TextColor3 = Color3.fromRGB(255, 180, 50),
				TextSize = 22,
				Font = Enum.Font.GothamBold,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				TextStrokeTransparency = 0.3,
			})
		end

		if rewardData.newLevel then
			cardChildren["LevelUp"] = React.createElement("TextLabel", {
				LayoutOrder = 6,
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundTransparency = 1,
				Text = "LEVEL UP! Level " .. rewardData.newLevel,
				TextColor3 = Color3.fromRGB(255, 220, 80),
				TextSize = 26,
				Font = Enum.Font.GothamBold,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				TextStrokeTransparency = 0.2,
			})
		end

		if rewardData.unlockedImages and #rewardData.unlockedImages > 0 then
			cardChildren["NewUnlocks"] = React.createElement("TextLabel", {
				LayoutOrder = 7,
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				Text = "New images unlocked!",
				TextColor3 = Color3.fromRGB(80, 200, 255),
				TextSize = 20,
				Font = Enum.Font.GothamBold,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				TextStrokeTransparency = 0.3,
			})
		end
	end

	cardChildren["AdmireButton"] = React.createElement("TextButton", {
		LayoutOrder = 10,
		Size = UDim2.new(0, 220, 0, 48),
		BackgroundColor3 = Color3.fromRGB(80, 200, 120),
		Text = "Admire Puzzle",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 22,
		Font = Enum.Font.GothamBold,
		[React.Event.Activated] = function()
			props.onAdmire()
		end,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
	})

	cardChildren["PlayAgainButton"] = React.createElement("TextButton", {
		LayoutOrder = 11,
		Size = UDim2.new(0, 220, 0, 48),
		BackgroundColor3 = Color3.fromRGB(80, 140, 230),
		Text = "PLAY AGAIN",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 22,
		Font = Enum.Font.GothamBold,
		[React.Event.Activated] = function()
			props.onPlayAgain()
		end,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
	})

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 100,
	}, {
		Confetti = React.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 100,
		}, confettiChildren),

		Backdrop = React.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			ZIndex = 105,
		}),

		Card = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 380, 0, 420),
			BackgroundColor3 = Color3.fromRGB(30, 30, 45),
			BorderSizePixel = 0,
			ZIndex = 110,
		}, cardChildren),
	})
end

return CompleteScreen
