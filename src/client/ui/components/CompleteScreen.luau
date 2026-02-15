local CaptureService = game:GetService("CaptureService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages.React)

export type CompleteScreenProps = {
	onPlayAgain: () -> (),
}

local CONFETTI_COUNT = 50
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(80, 200, 255),
	Color3.fromRGB(255, 220, 80),
	Color3.fromRGB(120, 255, 120),
	Color3.fromRGB(220, 120, 255),
	Color3.fromRGB(255, 160, 60),
}

local function ConfettiPiece(props: { delay: number, index: number })
	local ref = React.useRef(nil :: Frame?)

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
	local color = CONFETTI_COLORS[math.random(1, #CONFETTI_COLORS)]
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
		ZIndex = 10,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 2) }),
	})
end

local function CompleteScreen(props: CompleteScreenProps)
	local overlayRef = React.useRef(nil :: Frame?)
	local confettiChildren: { [string]: any } = {}

	for i = 1, CONFETTI_COUNT do
		confettiChildren["Confetti_" .. i] = React.createElement(ConfettiPiece, {
			index = i,
			delay = math.random() * 1.5, -- stagger spawns over 1.5s
		})
	end

	return React.createElement("Frame", {
		ref = overlayRef,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 100,
	}, {
		-- Confetti container (full screen, no interaction)
		Confetti = React.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 100,
		}, confettiChildren),

		-- Bottom panel with text and button
		BottomPanel = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -30),
			Size = UDim2.new(1, 0, 0, 180),
			BackgroundTransparency = 1,
			ZIndex = 101,
		}, {
			Layout = React.createElement("UIListLayout", {
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 12),
			}),

			Title = React.createElement("TextLabel", {
				LayoutOrder = 1,
				Size = UDim2.new(0, 400, 0, 56),
				BackgroundTransparency = 1,
				Text = "Puzzle Complete!",
				TextColor3 = Color3.fromRGB(255, 220, 80),
				TextSize = 48,
				Font = Enum.Font.GothamBold,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				TextStrokeTransparency = 0.3,
			}),

			Subtitle = React.createElement("TextLabel", {
				LayoutOrder = 2,
				Size = UDim2.new(0, 400, 0, 30),
				BackgroundTransparency = 1,
				Text = "Great job putting it all together!",
				TextColor3 = Color3.fromRGB(220, 220, 230),
				TextSize = 20,
				Font = Enum.Font.Gotham,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				TextStrokeTransparency = 0.5,
			}),

			ScreenshotButton = React.createElement("TextButton", {
				LayoutOrder = 3,
				Size = UDim2.new(0, 220, 0, 50),
				BackgroundColor3 = Color3.fromRGB(80, 200, 120),
				Text = "Save Screenshot",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 24,
				Font = Enum.Font.GothamBold,
				ZIndex = 101,
				[React.Event.Activated] = function()
					-- Hide the completion overlay and Roblox chrome so the screenshot shows just the puzzle
					local overlay = overlayRef.current
					if overlay then
						overlay.Visible = false
					end
					StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)

					-- Wait a frame for UI to fully hide before capturing
					task.wait()

					CaptureService:CaptureScreenshot(function(contentId)
						-- Restore UI
						if overlay then
							overlay.Visible = true
						end
						StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)

						CaptureService:PromptSaveCapturesToGallery({ contentId }, function() end)
					end)
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
			}),

			PlayAgainButton = React.createElement("TextButton", {
				LayoutOrder = 4,
				Size = UDim2.new(0, 220, 0, 50),
				BackgroundColor3 = Color3.fromRGB(80, 140, 230),
				Text = "Play Again",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 24,
				Font = Enum.Font.GothamBold,
				ZIndex = 101,
				[React.Event.Activated] = function()
					props.onPlayAgain()
				end,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
			}),
		}),
	})
end

return CompleteScreen
