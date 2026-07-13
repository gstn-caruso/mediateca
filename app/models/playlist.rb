class Playlist < ApplicationRecord
  belongs_to :profile
  has_many :entries, -> { ordered },
           class_name: "PlaylistEntry", dependent: :destroy, inverse_of: :playlist
  has_many :tracks, through: :entries

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, uniqueness: { scope: :profile_id }

  scope :ordered, -> { order(:name) }

  # What the list looks like to whoever is reading it: the songs of a hidden
  # artist are not drawn. They are not thrown away, though — hiding is not
  # deleting, and somebody who changes their mind wants the list they made back,
  # not a list with a hole in it. So the entry stays, and unhiding restores it.
  #
  # Sifted in Ruby, off the entries already in hand, so a list costs no more to
  # draw than it did.
  def entries_visible_to(profile)
    entries.reject { |entry| profile.hidden_artist_ids.include?(entry.track.album.artist_id) }
  end

  # A playlist is a list, not a set: the same song may appear twice.
  #
  # But two songs may not appear in the same place, and reading the last position
  # and then claiming the next one cannot promise that — two adds racing both read
  # the same last position and both claim the one after it. The index refuses the
  # second, and the second asks again; by then the answer has changed.
  def add(track)
    entries.create!(track:, position: after_the_last)
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  # An entry at either end has nowhere to go, and a list that silently wrapped
  # around would move a song the listener never asked to move.
  def move(entry, by:)
    ids = entries.pluck(:id)
    from = ids.index(entry.id)
    to = from + by

    return if to.negative? || to >= ids.size

    ids.insert(to, ids.delete_at(from))
    reorder(ids)
  end

  private

  def after_the_last
    (entries.maximum(:position) || 0) + 1
  end

  # Every entry is renumbered from its place in the new order, so the positions
  # stay 1..n with no gaps and no two the same — which is what the index demands
  # and what ▲ and ▼ rely on. Nobody outside asks for this: a move is the only
  # thing that reorders a playlist, and a move is where the new order comes from.
  #
  # Written to a scratch range first, because the positions are unique and a
  # straight shuffle would collide with the very row it is about to move.
  def reorder(entry_ids)
    transaction do
      entry_ids.each_with_index { |id, index| entries.where(id: id).update_all(position: -(index + 1)) }
      entry_ids.each_with_index { |id, index| entries.where(id: id).update_all(position: index + 1) }
    end
  end
end
