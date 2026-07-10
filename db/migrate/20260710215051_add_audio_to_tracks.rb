class AddAudioToTracks < ActiveRecord::Migration[8.1]
  # How each file is encoded, read once at scan time so the player can show it
  # without re-probing. Null until the next scan fills it: old rows predate it.
  def change
    add_column :tracks, :codec, :string
    add_column :tracks, :bit_depth, :integer
    add_column :tracks, :sample_rate, :integer
    add_column :tracks, :bit_rate, :integer
  end
end
