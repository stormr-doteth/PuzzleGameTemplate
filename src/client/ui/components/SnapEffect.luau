local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

type EffectConfig = {
	particleCount: number,
	colors: { Color3 },
	size: number,
	duration: number,
	spread: number,
	cornerRadius: UDim,
	rotation: boolean,
	gravity: number,
	isRing: boolean?,
}

local EFFECT_CONFIGS: { [string]: EffectConfig } = {
	default = {
		particleCount = 12,
		colors = { Color3.fromRGB(255, 255, 255) },
		size = 12,
		duration = 0.55,
		spread = 55,
		cornerRadius = UDim.new(0, 1),
		rotation = false,
		gravity = 0,
	},
	snap_sparkle = {
		particleCount = 16,
		colors = {
			Color3.fromRGB(255, 215, 60),
			Color3.fromRGB(255, 235, 100),
			Color3.fromRGB(255, 200, 30),
		},
		size = 14,
		duration = 0.7,
		spread = 75,
		cornerRadius = UDim.new(0, 1),
		rotation = true,
		gravity = 0,
	},
	snap_ripple = {
		particleCount = 1,
		colors = { Color3.fromRGB(100, 180, 255) },
		size = 14,
		duration = 0.6,
		spread = 90,
		cornerRadius = UDim.new(1, 0),
		rotation = false,
		gravity = 0,
		isRing = true,
	},
	snap_hearts = {
		particleCount = 14,
		colors = {
			Color3.fromRGB(255, 100, 140),
			Color3.fromRGB(255, 80, 120),
			Color3.fromRGB(255, 130, 160),
			Color3.fromRGB(230, 60, 100),
		},
		size = 14,
		duration = 0.7,
		spread = 65,
		cornerRadius = UDim.new(1, 0),
		rotation = false,
		gravity = 20,
	},
}

local function SnapParticle(props: { config: EffectConfig, index: number, centerX: number, centerY: number })
	local ref = React.useRef(nil :: Frame?)
	local config = props.config

	React.useEffect(function()
		local frame = ref.current
		if not frame then return end

		local angle = (props.index / config.particleCount) * math.pi * 2 + (math.random() - 0.5) * 0.5
		local dist = config.spread * (0.7 + math.random() * 0.3)

		local endX = math.cos(angle) * dist
		local endY = math.sin(angle) * dist + config.gravity

		local tweenInfo = TweenInfo.new(
			config.duration,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		)

		local goalProps: { [string]: any } = {
			Position = UDim2.fromOffset(
				props.centerX + endX - config.size / 2,
				props.centerY + endY - config.size / 2
			),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(config.size * 0.5, config.size * 0.5),
		}

		if config.rotation then
			goalProps.Rotation = math.random(-180, 180)
		end

		local tween = TweenService:Create(frame, tweenInfo, goalProps)
		tween:Play()

		return function()
			tween:Cancel()
		end
	end, {})

	local color = config.colors[math.random(1, #config.colors)]
	local startRotation = if config.rotation then 45 else 0

	return React.createElement("Frame", {
		ref = ref,
		Size = UDim2.fromOffset(config.size, config.size),
		Position = UDim2.fromOffset(props.centerX - config.size / 2, props.centerY - config.size / 2),
		Rotation = startRotation,
		BackgroundColor3 = color,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = 90,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = config.cornerRadius }),
	})
end

local function SnapRing(props: { config: EffectConfig, centerX: number, centerY: number })
	local ref = React.useRef(nil :: Frame?)
	local config = props.config

	React.useEffect(function()
		local frame = ref.current
		if not frame then return end

		local tweenInfo = TweenInfo.new(
			config.duration,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		)

		local finalSize = config.spread * 2
		local tween = TweenService:Create(frame, tweenInfo, {
			Size = UDim2.fromOffset(finalSize, finalSize),
			Position = UDim2.fromOffset(props.centerX - finalSize / 2, props.centerY - finalSize / 2),
		})
		tween:Play()

		-- Fade stroke separately
		local fadeTween = nil
		local stroke = frame:FindFirstChildOfClass("UIStroke")
		if stroke then
			fadeTween = TweenService:Create(stroke, tweenInfo, {
				Transparency = 1,
			})
			fadeTween:Play()
		end

		return function()
			tween:Cancel()
			if fadeTween then
				fadeTween:Cancel()
			end
		end
	end, {})

	local color = config.colors[1]
	local startSize = config.size

	return React.createElement("Frame", {
		ref = ref,
		Size = UDim2.fromOffset(startSize, startSize),
		Position = UDim2.fromOffset(props.centerX - startSize / 2, props.centerY - startSize / 2),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 90,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Stroke = React.createElement("UIStroke", {
			Color = color,
			Thickness = 3.5,
			Transparency = 0,
		}),
	})
end

local function SnapFlash(props: { centerX: number, centerY: number })
	local ref = React.useRef(nil :: Frame?)

	React.useEffect(function()
		local frame = ref.current
		if not frame then return end

		local tweenInfo = TweenInfo.new(
			0.25,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		)

		local finalSize = 40
		local tween = TweenService:Create(frame, tweenInfo, {
			Size = UDim2.fromOffset(finalSize, finalSize),
			Position = UDim2.fromOffset(props.centerX - finalSize / 2, props.centerY - finalSize / 2),
			BackgroundTransparency = 1,
		})
		tween:Play()

		return function()
			tween:Cancel()
		end
	end, {})

	local startSize = 10
	return React.createElement("Frame", {
		ref = ref,
		Size = UDim2.fromOffset(startSize, startSize),
		Position = UDim2.fromOffset(props.centerX - startSize / 2, props.centerY - startSize / 2),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		ZIndex = 91,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
end

export type SnapEffectProps = {
	positionX: number,
	positionY: number,
	effectId: string?,
	effectKey: string,
}

local function SnapEffect(props: SnapEffectProps)
	local effectId = props.effectId or ""
	local config = EFFECT_CONFIGS[effectId] or EFFECT_CONFIGS.default

	local children: { [string]: any } = {}

	if config.isRing then
		children["Ring"] = React.createElement(SnapRing, {
			config = config,
			centerX = props.positionX,
			centerY = props.positionY,
		})
	else
		for i = 1, config.particleCount do
			children["Particle_" .. i] = React.createElement(SnapParticle, {
				config = config,
				index = i,
				centerX = props.positionX,
				centerY = props.positionY,
			})
		end
		children["Flash"] = React.createElement(SnapFlash, {
			centerX = props.positionX,
			centerY = props.positionY,
		})
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 90,
	}, children)
end

return SnapEffect
