# One full turn of a record: every song on it, heard, with nothing else put on in
# between.
#
# A record you let run to the end is a different thing from a record you took one
# song off, and only the first is what anybody means by having listened to a
# record. Shuffle still turns it — you heard the whole thing, out of order. A song
# skipped does not, because a song skipped is not a play at all.
class Spin < ApplicationRecord
  belongs_to :profile
  belongs_to :album

  # The play that closed the circle, and where the next turn starts counting.
  belongs_to :play
end
