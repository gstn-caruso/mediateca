class CreateSpotifyAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :spotify_accounts do |t|
      t.references :profile, null: false, foreign_key: true, index: { unique: true }

      t.string :username, null: false

      # Encrypted, both of them, and long because ciphertext is. The access token
      # dies in an hour; the refresh token is the one that matters, and it is a key
      # to somebody's Spotify.
      t.text :access_token, null: false
      t.text :refresh_token, null: false
      t.datetime :expires_at, null: false

      # What became of an import, so the page can say it rather than showing a
      # spinner and the word "done".
      t.datetime :imported_at
      t.integer :imported_hearts, null: false, default: 0
      t.integer :imported_lists, null: false, default: 0
      t.integer :strangers, null: false, default: 0

      t.timestamps
    end
  end
end
