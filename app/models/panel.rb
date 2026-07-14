# How wide one listener keeps one panel.
#
# Having no row at all is the ordinary case: nobody has dragged anything, and
# every panel is the width it was born. A row exists only where a hand has been.
class Panel < ApplicationRecord
  belongs_to :profile

  # The four. There is no fifth, and there will not be one by asking: each of
  # these is a partial, a toggle and a rail of its own, and the layout is not a
  # thing the database gets to invent.
  NAMES = %w[ library visualizer lyrics queue ].freeze

  # The width every panel starts at — 18rem, which is what all four were nailed
  # to before a hand could move them.
  BORN = 288

  # Narrower than this a rail cannot say what it is for: the library rows carry a
  # face and two lines, and the segmented control above them has three icons to
  # fit. Wider than this and a panel has stopped being a rail beside the content
  # and started being the content.
  NARROWEST = 240
  WIDEST = 480

  # And the ends of the other rope. A share is a proportion and nothing else — 300
  # against 100 divides any room three to one — so where its ends fall hardly
  # matters. What matters is that a number off the network cannot be nothing, or
  # everything, or not a number at all.
  LEAST_SHARE = 1
  MOST_SHARE = 10_000

  validates :name, inclusion: { in: NAMES }
  validates :width, numericality: { in: NARROWEST..WIDEST, only_integer: true }
  validates :share, numericality: { in: LEAST_SHARE..MOST_SHARE }, allow_nil: true

  # The hand is held inside the room by the browser, but a request is not a hand.
  # Anybody on the LAN can send this app any number they like, and a panel 9,000
  # pixels wide is a layout with no content in it — so the ends are held here,
  # where the width is written down, and not only out there where it was dragged.
  def self.within_reach(width)
    width.clamp(NARROWEST, WIDEST)
  end

  def self.share_within_reach(share)
    share.clamp(LEAST_SHARE, MOST_SHARE)
  end

  def self.known?(name)
    NAMES.include?(name)
  end
end
