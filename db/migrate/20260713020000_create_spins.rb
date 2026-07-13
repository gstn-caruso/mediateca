class CreateSpins < ActiveRecord::Migration[8.1]
  def change
    create_table :spins do |t|
      t.references :profile, null: false, foreign_key: true
      t.references :album, null: false, foreign_key: true

      # The play that closed the circle. The next turn is counted from here, so
      # that going back to the first song after a record has finished starts a
      # new turn rather than finishing the same one twice.
      t.references :play, null: false, foreign_key: true, index: { unique: true }

      t.timestamps
    end

    add_index :spins, [ :profile_id, :album_id ]
  end
end
