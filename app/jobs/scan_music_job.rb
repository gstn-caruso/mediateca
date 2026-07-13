class ScanMusicJob < ApplicationJob
  queue_as :default

  def perform
    Music::Catalog.import

    Rails.logger.info "Music: #{Artist.count} artists, #{Album.count} albums, #{Track.count} tracks"

    # New music brings new artists, and nobody photographed them onto the NAS.
    FetchPortraitsJob.perform_later
    # And new sleeves, which is where the app gets the colour it wears.
    ReadColoursJob.perform_later
  end
end
