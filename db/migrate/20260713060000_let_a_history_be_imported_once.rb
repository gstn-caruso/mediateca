class LetAHistoryBeImportedOnce < ActiveRecord::Migration[8.1]
  def up
    # One listen, one row. Until now nothing said so, because nothing ever wrote a
    # play twice — the player says it once, when the song has been heard. An
    # import does not have that luxury: it can be run again, and Last.fm will hand
    # over the same hundred thousand scrobbles it handed over the last time.
    #
    # Anything already doubled is not a listen we can tell apart from itself, so
    # the older row is the one kept.
    execute <<~SQL
      DELETE FROM plays WHERE id NOT IN (
        SELECT MIN(id) FROM plays GROUP BY profile_id, track_id, played_at
      )
    SQL

    add_index :plays, [ :profile_id, :track_id, :played_at ], unique: true

    # What became of an import, so the Last.fm page can say it out loud rather
    # than showing a spinner and the word "done".
    add_column :scrobblers, :imported_at, :datetime
    add_column :scrobblers, :imported_plays, :integer, null: false, default: 0
    add_column :scrobblers, :imported_hearts, :integer, null: false, default: 0

    # Songs Last.fm knew and this house does not have. The number nobody wants to
    # publish, and the only one that says whether the import really worked.
    add_column :scrobblers, :strangers, :integer, null: false, default: 0
  end

  def down
    remove_index :plays, [ :profile_id, :track_id, :played_at ]
    remove_column :scrobblers, :imported_at, :imported_plays, :imported_hearts, :strangers
  end
end
