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

  # Who sings this one. Usually it is simply whoever made the record, and the
  # file says nothing the sleeve doesn't — but a guest, a duet or a compilation
  # says otherwise on the file itself, and the file is the one to believe.
  def artist_name
    artist.presence || album.artist.name
  end
end
