class CreateProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :profiles do |t|
      t.string :name, null: false

      t.timestamps
    end

    # There is no password here. The name is the identity, so the database has
    # to hold it to one.
    add_index :profiles, :name, unique: true
  end
end
