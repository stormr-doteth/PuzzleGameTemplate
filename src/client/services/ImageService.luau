local AssetService = game:GetService("AssetService")

local ImageService = {}

function ImageService.loadImage(imageAssetId: string): (EditableImage?, number?, number?)
	local ok, img = pcall(function()
		return AssetService:CreateEditableImageAsync(Content.fromUri(imageAssetId))
	end)
	if not ok or not img then return nil, nil, nil end
	return img, img.Size.X, img.Size.Y
end

return ImageService
