require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
# require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Mediateca
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Where the media lives. The NAS path is bind-mounted into the container
    # under the same path, so a path stored by the scanner means the same thing
    # on the host and inside the container.
    config.x.media_root = ENV.fetch("MEDIA_ROOT", "/mnt/data/multimedia")

    # The beets library we import the music catalog from, mounted read-only.
    config.x.beets_database = ENV.fetch("BEETS_DATABASE", "/mnt/data/beets/musiclibrary.db")
  end
end
