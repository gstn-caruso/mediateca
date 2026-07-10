namespace :music do
  desc "Importa la biblioteca de música al catálogo (idempotente)"
  task import: :environment do
    root = Rails.configuration.x.music_root
    abort "No encuentro la música en #{root}" unless File.directory?(root)

    Music::Catalog.import

    puts "#{Artist.count} artistas, #{Album.count} álbumes, #{Track.count} tracks"
  end
end
