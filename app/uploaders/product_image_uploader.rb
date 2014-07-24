class ProductImageUploader < CloudinaryUploader
  version :mini do
    process resize_to_fill: [80, 80]
    process :convert => 'jpg'
  end

  version :standard do
    process resize_to_fill: [200, 200]
    process :convert => 'jpg'
    cloudinary_transformation :effect => "unsharp_mask:87"
  end
end
