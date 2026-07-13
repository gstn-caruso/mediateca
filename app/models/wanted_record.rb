# A record somebody in this house plays and nobody in it owns.
#
# It is the only ranking in music that has ever been honest, and a library is the
# only thing that could have kept it: not what is popular, not what somebody is
# paid to put in front of you — what *you* have worn out, on somebody else's
# machine, for years, and have never had a copy of.
#
# Last.fm has been keeping the tally the whole time. All this does is subtract the
# shelf from it, and what is left over is a shopping list in playcount order.
class WantedRecord < ApplicationRecord
  # A record you have played twice is a record you heard twice, not a record you
  # want. The line has to go somewhere and this is where: enough plays that the
  # absence of it is a real hole in a shelf.
  ENOUGH = 25

  # How many are chased at a time. The whole list is thousands of records long and
  # would be a hundred gigabytes if it ran off the leash — so it walks: a handful
  # per sweep, heaviest want first, and it will get there.
  A_FEW = 3

  scope :worth_it, -> { where(plays: ENOUGH..) }
  scope :unsought, -> { worth_it.where(sought_at: nil).order(plays: :desc) }
  scope :on_the_way, -> { where.not(torrent_hash: nil).where(found_at: nil) }
  scope :still_missing, -> { worth_it.where(found_at: nil).order(plays: :desc) }

  def on_the_way? = torrent_hash.present? && found_at.nil?
  def sought? = sought_at.present?

  def sought(hash: nil, name: nil, nothing_doing: nil)
    update!(sought_at: Time.current, torrent_hash: hash, torrent_name: name, nothing_doing:)
  end

  # What a search engine is given. The name of the record, whoever made it, and the
  # word that separates a real copy from a transcode wearing its name.
  def as_a_search
    "#{artist} #{title}"
  end

  # Everything on Last.fm that this listener plays and this house has not got,
  # heaviest first.
  #
  # The subtraction is done on names, bluntly, because that is all either side has:
  # Last.fm knows a record as two strings and so, near enough, does a disk.
  def self.refresh_from(profile)
    return unless profile.scrobbles?

    shelved = Album.joins(:artist).pluck("artists.name", :title).map { plainly(it) }.to_set

    Lastfm.api.top_albums(user: profile.scrobbler.username)
          .reject { shelved.include?(plainly([ it[:artist], it[:album] ])) }
          .select { it[:plays] >= ENOUGH }
          .each { keep(it) }
  end

  def self.keep(record)
    wanted = find_or_initialize_by(artist: record[:artist], title: record[:album])
    wanted.plays = record[:plays]
    wanted.save!
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  # Case is nothing, accents are nothing — the same blunt match everything else in
  # this app uses to tell somebody else's name for a thing from our own.
  def self.plainly(pair)
    pair.map { I18n.transliterate(it.to_s).downcase.gsub(/[^a-z0-9]+/, " ").strip }
  end
end
