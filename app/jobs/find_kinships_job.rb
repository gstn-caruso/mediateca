# Asks Last.fm who each of this library's artists is like, and keeps the answers
# that land on a record the house owns.
#
# It runs after a scan, beside the portraits: both are the same kind of errand —
# something the disk cannot tell us, fetched once, kept, and never asked for again
# on the way to answering a request. The rail must not wait on Last.fm to say what
# comes next.
class FindKinshipsJob < ApplicationJob
  queue_as :default

  def perform
    return unless Lastfm.api.configured?

    Lastfm::Kin.new.find_them_all
  end
end
