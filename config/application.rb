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

    # The disk decides what music exists; beets only says what it is called.
    config.x.music_root = ENV.fetch("MUSIC_ROOT", "/mnt/data/multimedia/Música")
    config.x.beets_database = ENV.fetch("BEETS_DATABASE", "/mnt/data/beets/musiclibrary.db")

    # Nobody photographs an artist onto a NAS. The disk decides first, then
    # Wikimedia, then Spotify if it was given credentials. The answer is kept
    # under storage/, the only writable volume: the music is mounted read-only.
    config.x.musicbrainz_api = ENV.fetch("MUSICBRAINZ_API", "https://musicbrainz.org/ws/2")
    config.x.wikidata_api = ENV.fetch("WIKIDATA_API", "https://www.wikidata.org/w/api.php")
    config.x.commons_api = ENV.fetch("COMMONS_API", "https://commons.wikimedia.org/w/api.php")
    config.x.spotify_client_id = ENV["SPOTIFY_CLIENT_ID"]
    config.x.spotify_client_secret = ENV["SPOTIFY_CLIENT_SECRET"]
    config.x.portraits_root = ENV.fetch("PORTRAITS_ROOT", Rails.root.join("storage/portraits").to_s)

    # The scanner reads each file's tags with ffprobe, which ships in the image.
    config.x.ffprobe = ENV.fetch("FFPROBE", "ffprobe")

    # Last.fm, if somebody wants their listening to leave the house. Without
    # these there is no Last.fm in the app at all: no menu item, no scrobbles.
    # They come from an API account at last.fm/api/account/create.
    config.x.lastfm_api_key = ENV["LASTFM_API_KEY"]
    config.x.lastfm_api_secret = ENV["LASTFM_API_SECRET"]
  end
end
