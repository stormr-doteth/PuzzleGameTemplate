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
end

return ChatTags
