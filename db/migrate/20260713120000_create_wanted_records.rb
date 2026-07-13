class CreateWantedRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :wanted_records do |t|
      # Names, not references — there is nothing on this disk for them to refer to.
      # That is the entire point of them.
      t.string :artist, null: false
      t.string :title, null: false

      # How much this record has been played by somebody who does not own it. It is
      # what decides which one is fetched first, and it is a better ranking than any
      # shop has ever had: it is not what is popular, it is what *you* wear out.
      t.integer :plays, null: false, default: 0

      # The chase. Sought once and once only: a record nobody could find is not a
      # record to go looking for every half hour forever.
      t.datetime :sought_at
      t.string :torrent_hash
      t.string :torrent_name
      t.datetime :found_at

      # What happened, when nothing did. Said out loud rather than left as a silence.
      t.string :nothing_doing

      t.timestamps
    end

    # The house wants a record once, however many people in it are missing the same one.
    add_index :wanted_records, [ :artist, :title ], unique: true
    add_index :wanted_records, :torrent_hash, unique: true
  end
end
