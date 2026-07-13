# One band being like another, as far as Last.fm is concerned — and only among the
# artists this house actually owns records by, because those are the only ones the
# rail could ever put on.
#
# It is the one thing a home library genuinely cannot work out for itself. The disk
# knows what you own and the history knows what you play, but neither of them knows
# that Hermética is what comes after Almafuerte.
class Kinship < ApplicationRecord
  belongs_to :artist
  belongs_to :kin, class_name: "Artist"

  validates :match, presence: true
end
