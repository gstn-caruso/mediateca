# Who sings this one, when it is not simply whoever made the record.
#
# The file has always said so — Music::Tags reads ARTIST off every one of them —
# and the scanner threw it away, so a guest, a duet or a compilation all came
# back wearing the album artist's name. A playlist is exactly where songs by
# different people meet, so it is exactly where that lie shows.
#
# A string, not an artist_id: of the 934 tracks beets knows, one is credited to
# somebody other than its album's artist, and it reads "Luis Alberto Spinetta,
# Pedro Aznar y Charly García" — a credit line, not somebody you own records by.
# Rows for names like that would fill the library rail with artists who have no
# albums. Null when the file says nothing that the record doesn't already say,
# which is the other 933.
class AddArtistToTracks < ActiveRecord::Migration[8.1]
  def change
    add_column :tracks, :artist, :string
  end
end
