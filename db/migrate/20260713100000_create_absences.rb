class CreateAbsences < ActiveRecord::Migration[8.1]
  def change
    create_table :absences do |t|
      t.references :profile, null: false, foreign_key: true

      # Names, not references. That is the whole point of them: there is nothing
      # in this library for them to refer to.
      t.string :artist, null: false
      t.string :title, null: false

      t.timestamps
    end

    # One gap, however many times it turns up: hearted on Spotify and sitting in
    # three playlists is one song you do not own.
    add_index :absences, [ :profile_id, :artist, :title ], unique: true
    add_index :absences, [ :profile_id, :artist ]

    # A line in a playlist used to be a song. Now it is a song *or* the name of one
    # — a list brought home from Spotify holds both, and the ones you do not own
    # are drawn grey rather than quietly dropped, so the list stays the list.
    change_column_null :playlist_entries, :track_id, true
    add_reference :playlist_entries, :absence, null: true, foreign_key: true
  end
end
