class AddPlayedAtToPlays < ActiveRecord::Migration[8.1]
  def up
    add_column :plays, :played_at, :datetime

    # The rows already here were written the instant the track started, so for
    # them the two timestamps are the same thing. That stops being true from now
    # on: a play is written down halfway through the song, and Last.fm wants to
    # be told when the music began, not when we got around to saying so.
    execute "UPDATE plays SET played_at = created_at WHERE played_at IS NULL"

    change_column_null :plays, :played_at, false
    add_index :plays, [ :profile_id, :played_at ]
  end

  def down
    remove_index :plays, [ :profile_id, :played_at ]
    remove_column :plays, :played_at
  end
end
