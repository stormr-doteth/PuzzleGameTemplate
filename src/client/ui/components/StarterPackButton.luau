local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local React = require(Packages.React)
local Theme = require(Shared.Theme)

export type StarterPackButtonProps = {
	secondsLeft: number,
	onActivated: () -> (),
}

local function formatMMSS(seconds: number): string
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	return string.format("%02d:%02d", m, s)
end

-- Sparkle particle that fades in, drifts, and fades out
local function Sparkle(props: { delay: number, x: number, y: number, size: number })
	local ref = React.useRef(nil :: Frame?)

	React.useEffect(function()
		local frame = ref.current
		if not frame then return end

		frame.BackgroundTransparency = 1

		local running = true
		task.delay(props.delay, function()
			if not running then return end
			if not frame or not frame.Parent then return end

			-- Fade in
			local fadeIn = TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 0,
				Size = UDim2.fromOffset(props.size, props.size),
			})
			fadeIn:Play()
			fadeIn.Completed:Wait()
			if not running or not frame.Parent then return end

			-- Fade out + drift
			local fadeOut = TweenService:Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 1,
				Position = UDim2.new(0, props.x + (math.random() - 0.5) * 20, 0, props.y - 10),
				Size = UDim2.fromOffset(2, 2),
			})
			fadeOut:Play()
		end)

		return function()
			running = false
		end
	end, {})

	return React.createElement("Frame", {
		ref = ref,
		Position = UDim2.fromOffset(props.x, props.y),
		Size = UDim2.fromOffset(props.size * 0.5, props.size * 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 200),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 13,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
end

local function StarterPackButton(props: StarterPackButtonProps)
	-- Generate looping sparkle particles
	local sparkleKey, setSparkleKey = React.useState(0)

	React.useEffect(function()
		local running = true
		task.spawn(function()
			while running do
				task.wait(1.5)
				if not running then break end
				setSparkleKey(function(prev)
					return prev + 1
				end)
			end
		end)
		return function()
			running = false
		end
	end, {})

	-- Build sparkle children keyed to sparkleKey so they remount each cycle
	local sparkles: { [string]: any } = {}
	local sparklePositions = {
		{ x = 8, y = 6, size = 8, delay = 0 },
		{ x = 70, y = 12, size = 6, delay = 0.2 },
		{ x = 15, y = 65, size = 7, delay = 0.4 },
		{ x = 65, y = 58, size = 8, delay = 0.6 },
		{ x = 40, y = 3, size = 5, delay = 0.1 },
		{ x = 5, y = 35, size = 6, delay = 0.8 },
		{ x = 72, y = 38, size = 5, delay = 0.3 },
	}
	for i, sp in sparklePositions do
		sparkles["Sparkle_" .. i .. "_" .. sparkleKey] = React.createElement(Sparkle, {
			delay = sp.delay,
			x = sp.x,
			y = sp.y,
			size = sp.size,
		})
	end

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(0.98, 0, 0.5, 0),
		Size = UDim2.fromScale(0.16, 0.28),
		BackgroundTransparency = 1,
		ZIndex = 10,
	}, {
		Icon = React.createElement("ImageButton", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromScale(0.9, 0.65),
			BackgroundTransparency = 1,
			Image = "rbxassetid://115824295269688",
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 10,
			[React.Event.Activated] = props.onActivated,
			[React.Event.MouseEnter] = function(rbx)
				TweenService:Create(rbx, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = 5 }):Play()
			end,
			[React.Event.MouseLeave] = function(rbx)
				TweenService:Create(rbx, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
			end,
		}, {
			Aspect = React.createElement("UIAspectRatioConstraint", {
				AspectRatio = 1,
			}),
			NotifDot = React.createElement("Frame", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 6, 0, -6),
				Size = UDim2.fromOffset(18, 18),
				BackgroundColor3 = Theme.Colors.danger,
				ZIndex = 12,
			}, {
				DotCorner = React.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
			-- Sparkle overlay
			Sparkles = React.createElement("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 13,
				ClipsDescendants = false,
			}, sparkles),
		}),
		-- "Starter Pack" label
		PackLabel = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.62),
			Size = UDim2.fromScale(1.1, 0.16),
			BackgroundTransparency = 1,
			ZIndex = 11,
			Text = "Starter Pack",
			TextColor3 = Theme.Colors.gold,
			TextScaled = true,
			Font = Theme.Font.heading,
		}, {
			LabelStroke = React.createElement("UIStroke", {
				Thickness = 2,
				Color = Theme.Colors.black,
			}),
		}),
		-- Timer countdown
		Timer = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.78),
			Size = UDim2.fromScale(0.8, 0.14),
			BackgroundTransparency = 1,
			ZIndex = 11,
			Text = formatMMSS(props.secondsLeft),
			TextColor3 = Theme.Colors.danger,
			TextScaled = true,
			Font = Theme.Font.heading,
		}, {
			TimerStroke = React.createElement("UIStroke", {
				Thickness = 2,
				Color = Theme.Colors.black,
			}),
		}),
	})
end

return StarterPackButton
