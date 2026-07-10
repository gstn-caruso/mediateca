namespace :music do
  desc "Imports the music library into the catalog (idempotent)"
  task import: :environment do
    root = Rails.configuration.x.music_root
    abort "Can't find the music in #{root}" unless File.directory?(root)

    Music::Catalog.import

    puts "#{Artist.count} artists, #{Album.count} albums, #{Track.count} tracks"
  end

  desc "Fetches a portrait for every artist that has none (idempotent)"
  task portraits: :environment do
    Music::Portraits.new(source: FetchPortraitsJob.chain).collect

    with = Artist.where.not(portrait_path: nil).count
    puts "#{with} of #{Artist.count} artists have a portrait"
  end
end
