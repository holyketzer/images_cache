class Image < ActiveRecord::Base
  include Sidekiq::Worker
  include Sidetiq::Schedulable

  def redis
    @redis ||= Redis.new
  end

  recurrence { minutely(1) }

  REDIS_CACHE_KEY = 'image_cache'
  REDIS_IS_CACHED_KEY = 'image_has_cache'
  CACHE_PATH = '/images/cache'
  MAX_CACHE_SIZE = 5

  belongs_to :imageable, polymorphic: true

  mount_uploader :cloudinary, ImageUploader

  def url(version = :standard)
    update_popularity(id)
    if local
      mark_as_cached(id)
      local_url(version)
    else
      if popular? && !is_cached(id)
        self.delay.cache_locally
      end
      cloudinary_url(version)
    end
  end

  def popular?
    cache_size = redis.zcard(REDIS_CACHE_KEY)
    index = redis.zrank(REDIS_CACHE_KEY, id)
    index >= cache_size - MAX_CACHE_SIZE
  end

  # Sidetiq worker method
  def perform
    cleanup_cache
  end

  private

  def local_url(version)
    File.join CACHE_PATH, "#{version}_#{local}"
  end

  def update_popularity(id)
    redis.zincrby(REDIS_CACHE_KEY, 1, id)
  end

  def mark_as_cached(id)
    redis.sadd(REDIS_IS_CACHED_KEY, id)
  end

  def mark_as_uncached(id)
    redis.srem(REDIS_IS_CACHED_KEY, id)
  end

  def is_cached(id)
     redis.sismember(REDIS_IS_CACHED_KEY, id)
  end

  def build_file_path(file_name, version)
    File.join Rails.root, 'public', CACHE_PATH, "#{version}_#{file_name}"
  end

  def cache_locally
    require 'open-uri'

    # Download all versions of image
    file_name = File.basename(URI.parse(cloudinary_url).path)
    logger.info "Downloading file #{file_name} for image##{id}"

    cloudinary.versions.each_key do |version|
      url = cloudinary_url(version)
      file_path = build_file_path(file_name, version)

      open(file_path, 'wb') do |file|
        file << open(url).read
      end
    end

    # Save in local only file name without version
    self.update!(local: file_name)
    mark_as_cached(id)
  end

  def cleanup_cache
    logger.info 'Cache clean up'
    cache_size = redis.zcard(REDIS_CACHE_KEY)
    if cache_size > MAX_CACHE_SIZE
      under_popular_ids = redis.zrange(REDIS_CACHE_KEY, 0, cache_size - MAX_CACHE_SIZE - 1)
      under_popular_ids.each do |id|
        cleanup_cache_for_image(id)
      end
    else
      logger.info "Cache size=#{cache_size}. There is no cleanup needed"
    end
  end

  def cleanup_cache_for_image(image_id)
    image = Image.find(image_id)
    if is_cached(image_id)
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
      mark_as_uncached(image_id)
    end
  rescue ActiveRecord::RecordNotFound
    logger.info 'Image is not in DB more'
  end
end