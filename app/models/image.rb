class Image < ActiveRecord::Base
  include Sidekiq::Worker
  include Sidetiq::Schedulable

  recurrence { minutely(1) }

  REDIS_KEY = 'image_cache'
  CACHE_PATH = '/images/cache'
  CACHE_SIZE = 5

  belongs_to :imageable, polymorphic: true

  mount_uploader :cloudinary, ImageUploader

  def url(version = :standard)
    update_popularity
    if local
      local_url(version)
    else
      self.delay.cache_locally
      cloudinary_url(version)
    end
  end

  # Sidetiq worker method
  def perform
    cleanup_cache
  end

  private

  def local_url(version)
    File.join CACHE_PATH, "#{version}_#{self.local}"
  end

  def update_popularity
    redis = Redis.new
    redis.zincrby(REDIS_KEY, 1, id)
  end

  def build_file_path(file_name, version)
    File.join Rails.root, 'public', CACHE_PATH, "#{version}_#{file_name}"
  end

  def cache_locally
    require 'open-uri'

    # Download all versions of image
    file_name = File.basename(URI.parse(cloudinary_url).path)
    logger.info "Downloading file #{file_name} for image##{self.id}"

    cloudinary.versions.each_key do |version|
      url = cloudinary_url(version)
      file_path = build_file_path(file_name, version)

      open(file_path, 'wb') do |file|
        file << open(url).read
      end
    end

    # Save in local only file name without version
    self.update!(local: file_name)
  end

  def cleanup_cache
    logger.info 'Cache clean up'
    redis = Redis.new
    size = redis.zcard(REDIS_KEY)
    if size > CACHE_SIZE
      under_popular_ids = redis.zrange(REDIS_KEY, 0, size - CACHE_SIZE - 1)
      under_popular_ids.each do |id|
        cleanup_cache_for_image(id, redis)
      end
    else
      logger.info "Cache size=#{size}. There is no cleanup needed"
    end
  end

  def cleanup_cache_for_image(image_id, redis)
    image = Image.find(image_id)
    logger.info "Removing file #{image.local} of image##{image_id}"

    image.cloudinary.versions.each_key do |version|
      file_path = build_file_path(image.local, version)
      begin
        File.delete(file_path) if File.exists?(file_path)
      rescue => e
        logger.fatal e.inspect
      end
    end
    image.update!(local: nil)
  rescue ActiveRecord::RecordNotFound
    logger.info 'Image is not in DB more'
  ensure
    redis.zrem(REDIS_KEY, image_id)
  end
end