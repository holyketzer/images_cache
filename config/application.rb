require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ImagesCache
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Sidekiq checking for new jobs interval
    Sidekiq.configure_server do |config|
      config.poll_interval = 5
    end

    config.cloudinary_redis_cache_key = 'image_cache'
    config.cloudinary_redis_is_cached_key = 'image_has_cache'
    config.cloudinary_cache_path = '/images/cache'
    config.cloudinary_max_cache_size = 500
  end
end
