class Playlist < ApplicationRecord
  belongs_to :profile
  has_many :entries, -> { ordered },
           class_name: "PlaylistEntry", dependent: :destroy, inverse_of: :playlist
  has_many :tracks, through: :entries

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, uniqueness: { scope: :profile_id }

  scope :ordered, -> { order(:name) }

  # A playlist is a list, not a set.
  def add(track)
    entries.create!(track:, position: (entries.maximum(:position) || 0) + 1)
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

  # The ids arrive from a form, so they are whatever the browser chose to send.
  # Scoping the update to our own entries stops a stray id from reordering
  # somebody else's playlist.
  def reorder(entry_ids)
    transaction do
      entry_ids.each_with_index do |id, index|
        entries.where(id: id).update_all(position: index + 1)
      end
    end
  end
end
