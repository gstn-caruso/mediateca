class CreateScrobbles < ActiveRecord::Migration[8.1]
  def change
    create_table :scrobbles do |t|
      # The listener, not their scrobbler: revoking a Last.fm must not throw away
      # the songs waiting to go to it. They wait for whenever it is reconnected.
      t.references :profile, null: false, foreign_key: true
      t.references :track, null: false, foreign_key: true

      # When the music started, which is the only timestamp Last.fm will take.
      t.datetime :played_at, null: false

      t.datetime :sent_at

      # What Last.fm did with it once it had it. Nought means it took it; three
      # means "that is too far in the past", which it says inside a perfectly
      # successful response, and which is what quietly eats a backfill.
      t.integer :ignored_as

      t.timestamps
    end

    # What is still waiting, oldest first — Last.fm asks that they be sent in the
    # order they were heard.
    add_index :scrobbles, [ :profile_id, :sent_at, :played_at ]

    # One listen, one scrobble. A double-click on the player, or two tabs both
    # reporting the same song, is not two listens.
    add_index :scrobbles, [ :profile_id, :track_id, :played_at ], unique: true
  end
end
