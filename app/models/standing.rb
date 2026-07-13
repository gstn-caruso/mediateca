# Where a listener stands on an artist: out of sight, or out in front.
#
# There are only two standings and they are opposites — an artist you never want
# offered is not one you want offered more — so a listener holds at most one row
# per artist, and having no row at all is the ordinary case. Most artists are
# simply artists.
class Standing < ApplicationRecord
  belongs_to :profile
  belongs_to :artist

  enum :standing, { hidden: "hidden", highlighted: "highlighted" }, validate: true
end
