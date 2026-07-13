class CreateScrobblers < ActiveRecord::Migration[8.1]
  def change
    create_table :scrobblers do |t|
      # One listener, one Last.fm. Connecting again replaces what was there
      # rather than adding a second account nobody asked for.
      t.references :profile, null: false, foreign_key: true, index: { unique: true }

      t.string :username, null: false

      # Encrypted, and long because ciphertext is: this is a credential Last.fm
      # never expires.
      t.text :session_key, null: false

      t.timestamps
    end
  end
end
