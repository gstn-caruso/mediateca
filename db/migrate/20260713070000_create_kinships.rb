class CreateKinships < ActiveRecord::Migration[8.1]
  def change
    create_table :kinships do |t|
      t.references :artist, null: false, foreign_key: true
      t.references :kin, null: false, foreign_key: { to_table: :artists }

      # Last.fm scores a kinship between nought and one. It is what decides how
      # many times a band's songs go into the hat: a close cousin comes up often,
      # a distant one hardly ever.
      t.float :match, null: false

      t.timestamps
    end

    # One artist is kin to another once. Asking Last.fm again is refreshing what it
    # thinks, not collecting second opinions.
    add_index :kinships, [ :artist_id, :kin_id ], unique: true
  end
end
