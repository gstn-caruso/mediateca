class AddPortraitCreditToArtists < ActiveRecord::Migration[8.1]
  def change
    # CC BY-SA asks for the photographer's name. A picture we cannot credit is a
    # picture we should not show.
    add_column :artists, :portrait_credit, :string
  end
end
