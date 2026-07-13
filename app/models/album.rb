class Album < ApplicationRecord
  include Coloured

  belongs_to :artist
  has_many :tracks, -> { ordered }, dependent: :destroy, inverse_of: :album
  has_many :likes, as: :likeable, dependent: :destroy

  validates :directory, presence: true, uniqueness: true
  validates :title, presence: true

  scope :ordered, -> { order(:year, :title) }

  # A record's colour is printed on its sleeve.
  def picture
    cover_path
  end

  # What the record is, as files, said once at its head instead of song by song —
  # which is the question somebody is actually asking when they open it: is this
  # the good copy?
  #
  # Only when the record agrees with itself. A folder half ripped from the CD and
  # half filled in off the internet is not one thing, and there is no honest badge
  # for it: it says nothing, and the rows go on telling the truth song by song.
  def quality
    spoken = tracks.map { |track| track.audio.quality }.uniq

    spoken.first if spoken.one?
  end

  # How records stand on a shelf: under whoever made them, oldest first. Ordered
  # by year alone — which is what one artist's records want — the whole library
  # comes out interleaved, every artist shuffled in among the others.
  scope :shelved, -> { joins(:artist).order("artists.name", :year, :title) }

  # A record is hidden by whoever made it. The library seen as records is the
  # same library seen as people, and an artist hidden in one turn of the rail
  # and standing there in the next would be hidden in neither.
  scope :visible_to, ->(profile) { where.not(artist_id: profile.hidden_artist_ids) }
end
