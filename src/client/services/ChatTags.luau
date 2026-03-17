local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")

local ChatTags = {}

function ChatTags.Init()
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local props = Instance.new("TextChatMessageProperties")

		local source = message.TextSource
		if not source then
			return props
		end

		local player = Players:GetPlayerByUserId(source.UserId)
		if not player then
			return props
		end

		if player:GetAttribute("IsVIP") then
			local displayName = player.DisplayName
			props.PrefixText = '<font color="#FFD700">[VIP] ' .. displayName .. "</font>"
			props.Text = '<font color="#FFD700">' .. message.Text .. "</font>"
		end

		return props
	end

	TextChatService.OnBubbleAdded = function(message: TextChatMessage, adornee: Instance)
		local bubbleProps = Instance.new("BubbleChatMessageProperties")

		local source = message.TextSource
		if source then
			local player = Players:GetPlayerByUserId(source.UserId)
			if player and player:GetAttribute("IsVIP") then
				bubbleProps.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
				bubbleProps.TextColor3 = Color3.fromRGB(255, 215, 0)
			end
		end

		return bubbleProps
	end
end

return ChatTags
