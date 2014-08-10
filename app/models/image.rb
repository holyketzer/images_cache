class Image < ActiveRecord::Base
  belongs_to :imageable, polymorphic: true

  mount_uploader :cloudinary, ImageUploader

  def url(version = :standard)
    if local
      local
    else
      cloudinary_url(version)
    end
  end
end
