class ScanMusicJob < ApplicationJob
  queue_as :default

  def perform
    Music::Catalog.import

    Rails.logger.info "Music: #{Artist.count} artists, #{Album.count} albums, #{Track.count} tracks"
  end
end
