# The disk decides first: a photograph you left beside the records beats
# anything a stranger's server thinks. Then Wikimedia, which cannot hold an
# album sleeve. Then Spotify, only if it was handed credentials on purpose.
class FetchPortraitsJob < ApplicationJob
  queue_as :default

  def self.chain
    Music::FirstPortrait.new(Music::PortraitsOnDisk.new, Wikimedia::Portraits.new, Spotify::Portraits.new)
  end

  def perform
    Music::Portraits.new(source: self.class.chain).collect
  end
end
