# A heart. It hangs off whatever was liked, which so far is a track or an album.
#
# That the same thing is not hearted twice is the database's rule to keep, not
# ours: a validation reads the table and then writes it, and two tabs can both
# read nothing and both write. Only the unique index is in a position to say no,
# and it always is — so it is the only one that says it. See Profile#like.
class Like < ApplicationRecord
  belongs_to :profile
  belongs_to :likeable, polymorphic: true
end
