class ScanMusicJob < ApplicationJob
  queue_as :default

  def perform
    Music::Catalog.import

    Rails.logger.info "Music: #{Artist.count} artists, #{Album.count} albums, #{Track.count} tracks"

    # New music brings new artists, and nobody photographed them onto the NAS.
    FetchPortraitsJob.perform_later

    # And new sleeves, which is where the app gets the colour it wears.
    ReadColoursJob.perform_later

    # Nor does the disk know who anybody is *like*. All three are the same kind of
    # errand: something a home library cannot work out for itself, fetched once and
    # kept — and never asked for on the way to answering a request.
    FindKinshipsJob.perform_later
  end
end
