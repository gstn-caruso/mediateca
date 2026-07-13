class Track < ApplicationRecord
  belongs_to :album
  has_many :playlist_entries, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :plays, dependent: :destroy

  validates :title, presence: true
  validates :path, presence: true, uniqueness: true

  # A song nobody numbered belongs at the end of the record, not ahead of its
  # first track — and SQLite sorts nulls first unless told otherwise. The path
  # breaks what ties are left, which is how the disk itself would break them.
  scope :ordered, -> { order(:disc_no, Arel.sql("track_no IS NULL"), :track_no, :path) }

  # A song is hidden by whoever made the record it sits on — not by the credit
  # line on the file, which names guests and duets and is not somebody you own
  # records by.
  scope :visible_to, ->(profile) { where.not(album_id: Album.where(artist_id: profile.hidden_artist_ids)) }

  # Who sings this one. Usually it is simply whoever made the record, and the
  # file says nothing the sleeve doesn't — but a guest, a duet or a compilation
  # says otherwise on the file itself, and the file is the one to believe.
  def artist_name
    artist.presence || album.artist.name
  end

  # The scan spread the file's encoding over columns because that is how a table
  # stores it, but they are one fact, and it is Music::Audio that knows how to
  # read it.
  def audio
    Music::Audio.new(codec:, bit_depth:, sample_rate:, bit_rate:, bit_rate_mode:)
  end

  # The words, which live beside the song rather than in this table: an .lrc the
  # scan never has to know about, that can be rewritten without a re-import, and
  # that any other player on the disk can read. The track only knows to go and
  # look where they would be.
  def lyrics
    Music::Lyrics.beside(path)
  end
end
