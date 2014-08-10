class Image < ActiveRecord::Base
  REDIS_KEY = 'image_cache'
  CACHE_PATH = '/images/cache'

  belongs_to :imageable, polymorphic: true

  mount_uploader :cloudinary, ImageUploader

  def url(version = :standard)
    update_popularity
    if local
      local_url(version)
    else
      cache_locally
      cloudinary_url(version)
    end
  end

  private

  def local_url(version)
    File.join CACHE_PATH, "#{version}_#{self.local}"
  end

  def update_popularity
    redis = Redis.new
    redis.zincrby(REDIS_KEY, 1, id)
  end

  def cache_locally
    require 'open-uri'

    # Download all versions of image
    file_name = File.basename(URI.parse(cloudinary_url).path)
    cloudinary.versions.each_key do |version|
      url = cloudinary_url(version)
      file_path = File.join Rails.root, 'public', CACHE_PATH, "#{version}_#{file_name}"

      open(file_path, 'wb') do |file|
        file << open(url).read
      end
    end

    # Save in local only file name without version
    self.update!(local: file_name)
  end
end