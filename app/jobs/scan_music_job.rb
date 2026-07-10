class ScanMusicJob < ApplicationJob
  queue_as :default

  def perform
    Music::Catalog.import

    Rails.logger.info "Música: #{Artist.count} artistas, #{Album.count} álbumes, #{Track.count} tracks"
  end
end
