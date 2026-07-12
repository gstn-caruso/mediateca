# Two songs cannot occupy the same place in a list.
#
# Playlist#add read the last position and then claimed the next one, and a read
# followed by a write is not a promise: two adds racing — a double click, the
# phone and the tablet at once — both read the same last position and both claim
# the one after it. The list then has two songs in one place, their order between
# them decided by nothing, and pressing ▲ on either appears to do nothing at all.
#
# The database is the only one in a position to refuse that, so it does, and the
# loser simply asks again — by which time the answer has changed.
class AddUniquePositionToPlaylistEntries < ActiveRecord::Migration[8.1]
  def change
    remove_index :playlist_entries, [ :playlist_id, :position ]
    add_index :playlist_entries, [ :playlist_id, :position ], unique: true
  end
end
