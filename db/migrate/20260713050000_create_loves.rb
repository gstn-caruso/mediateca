class CreateLoves < ActiveRecord::Migration[8.1]
  def change
    create_table :loves do |t|
      # The listener, not their scrobbler: revoking a Last.fm must not throw away
      # what was waiting to go to it.
      t.references :profile, null: false, foreign_key: true
      t.references :track, null: false, foreign_key: true

      # Which way the heart went. Last.fm has a call for each.
      t.boolean :loved, null: false

      t.datetime :sent_at

      t.timestamps
    end

    # One song, one intent. Hearting a song and unhearting it before the queue
    # drains is not two things to say — it is one thing, said last.
    add_index :loves, [ :profile_id, :track_id ], unique: true
    add_index :loves, [ :profile_id, :sent_at ]
  end
end
