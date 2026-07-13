# The disk decides first: a photograph you left beside the records beats
# anything a stranger's server thinks. Then Deezer, a music service that knows a
# band by the exact name on its records. Then Wikimedia, whose picture is
# Creative Commons and free to keep, but whose name search strays to homonyms.
# Then Spotify, only if it was handed credentials on purpose.
class FetchPortraitsJob < ApplicationJob
  queue_as :default

  def self.chain
    Music::FirstPortrait.new(Music::PortraitsOnDisk.new, Deezer::Portraits.new, Wikimedia::Portraits.new, Spotify::Portraits.new)
  end

  def perform
    Music::Portraits.new(source: self.class.chain).collect

    # An artist wears the colour of their photograph, and the scan read the
    # library's colours before any of these faces existed. Whoever brings a face
    # asks for it to be read.
    ReadColoursJob.perform_later
  end
end
