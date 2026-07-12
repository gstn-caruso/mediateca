class AddBitRateModeToTracks < ActiveRecord::Migration[8.1]
  # Whether a compressed file held the bitrate it was given or let it follow the
  # music: "constant" or "variable", measured at scan time (Music::BitRateMode).
  #
  # Null wherever the question does not apply — every lossless file, which is the
  # whole library today — and wherever it was never asked: rows that predate this.
  def change
    add_column :tracks, :bit_rate_mode, :string
  end
end
