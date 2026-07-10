# One track, once, by one listener. The history is the pile of these.
class Play < ApplicationRecord
  belongs_to :profile
  belongs_to :track
end
