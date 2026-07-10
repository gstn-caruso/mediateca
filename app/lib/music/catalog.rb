module Music
  # Builds the library the app actually has: the disk, told apart by beets when
  # beets is around. One place to assemble it, so the rake task, the job and the
  # console all import the same thing.
  module Catalog
    def self.library(root: Rails.configuration.x.music_root, beets_database: Rails.configuration.x.beets_database)
      Library.new(disk: FilesystemSource.new(root:), beets: beets_at(beets_database))
    end

    # beets is an optional guest. Without it the library is still the library.
    def self.beets_at(database)
      Beets::Library.new(database) if database.present? && File.exist?(database)
    end

    def self.import(**)
      Importer.new.import(library(**))
    end
  end
end
