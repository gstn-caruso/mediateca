class CreateLikesAndPlays < ActiveRecord::Migration[8.1]
  def change
    create_table :likes do |t|
      t.references :profile, null: false, foreign_key: true
      t.references :likeable, polymorphic: true, null: false

      t.timestamps
    end

    # Liking twice is still liking once, and a race should not be able to say
    # otherwise.
    add_index :likes, [ :profile_id, :likeable_type, :likeable_id ],
              unique: true, name: "index_likes_on_profile_and_likeable"

    create_table :plays do |t|
      t.references :profile, null: false, foreign_key: true
      t.references :track, null: false, foreign_key: true

      t.timestamps
    end
  end
end
