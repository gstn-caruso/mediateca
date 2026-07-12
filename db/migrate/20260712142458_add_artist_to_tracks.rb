# Who sings this one, when it is not simply whoever made the record.
#
# The file has always said so — Music::Tags reads ARTIST off every one of them —
# and the scanner threw it away, so a guest, a duet or a compilation all came
# back wearing the album artist's name. A playlist is exactly where songs by
# different people meet, so it is exactly where that lie shows.
#
# A string, not an artist_id. beets, asked first, said this happens to exactly
# one track in the 934 it knows. The disk — which knows all 1171, and is the one
# that decides — says 36: "Luis Alberto Spinetta, Pedro Aznar y Charly García"
# on a Charly García record, "Indio Solari y Los Fundamentalistas del Aire
# Acondicionado" across most of Indio's. Those are credit lines, not people you
# own records by, and rows for them would fill the library rail with artists who
# have no albums. Null when the file says nothing the record doesn't already say,
# which is the other 1135.
class AddArtistToTracks < ActiveRecord::Migration[8.1]
  def change
    add_column :tracks, :artist, :string
  end
end
