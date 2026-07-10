namespace :music do
  desc "Importa la biblioteca de beets al catálogo (idempotente)"
  task import: :environment do
    database = Rails.configuration.x.beets_database
    abort "No encuentro la biblioteca de beets en #{database}" unless File.exist?(database)

    Music::Importer.new.import(Beets::Library.new(database))

    puts "#{Artist.count} artistas, #{Album.count} álbumes, #{Track.count} tracks"
  end
end
