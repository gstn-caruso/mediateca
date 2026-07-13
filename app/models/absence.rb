# A song this listener listens to, somewhere else, and does not own a copy of.
#
# Mediateca is a library of the records you have, and it could say nothing at all
# about the ones you have not: a Spotify import counted them, reported a number,
# and threw the names away. So the app knew about a thousand songs somebody loves
# and mentioned none of them.
#
# An absence is a name and nothing more, because there is nothing here for it to
# refer to. It cannot be played, it has no sleeve, and it is drawn grey. It is the
# shape of the gap between what you listen to and what is on the disk — which is,
# for a library of records you own, a useful thing to be able to see.
class Absence < ApplicationRecord
  belongs_to :profile

  validates :artist, presence: true
  validates :title, presence: true

  # Somebody the house owns nothing by, and how many of their songs are wanted.
  # Not an Artist: an Artist is somebody whose records are on the disk, and the
  # whole of the point here is that these are not.
  Stranger = Data.define(:name, :songs)

  # An artist is only missing while the house owns nothing at all by them. A song
  # of theirs you have not got is a song that is short, not a person: the shelf
  # already has them, and it would be a strange library that listed Elliott Smith
  # under both what it has and what it wants.
  scope :by_strangers, lambda {
    where.not(artist: Artist.select(:name))
  }
end
