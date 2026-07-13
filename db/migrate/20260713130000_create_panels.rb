class CreatePanels < ActiveRecord::Migration[8.1]
  def change
    create_table :panels do |t|
      t.references :profile, null: false, foreign_key: true

      # Which of the four: the library, the picture, the words, the queue. A name
      # and not a reference — a panel is a thing in the layout, and the layout is
      # not in the database.
      t.string :name, null: false

      # In pixels, which is the unit the hand that dragged it was working in.
      t.integer :width, null: false

      t.timestamps
    end

    # One listener, one panel, one width. Dragged twice, the second drag replaces
    # the first rather than standing beside it — the database has the last word,
    # the way it does for a standing and for a heart.
    add_index :panels, [ :profile_id, :name ], unique: true
  end
end
