class CreateStandings < ActiveRecord::Migration[8.1]
  def change
    create_table :standings do |t|
      t.references :profile, null: false, foreign_key: true
      t.references :artist, null: false, foreign_key: true
      t.string :standing, null: false

      t.timestamps
    end

    # One listener has one opinion about one artist. Hidden and highlighted are
    # opposites, so the row is replaced rather than added to — and the index is
    # what makes that true even when two tabs press at once.
    add_index :standings, [ :profile_id, :artist_id ], unique: true
  end
end
