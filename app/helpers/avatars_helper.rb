# A tile for anything that has a name and may have no picture: a listener, an
# artist nobody photographed.
module AvatarsHelper
  # Written out whole because Tailwind reads these strings at build time and
  # cannot see a class name that Ruby assembles.
  AVATAR_COLOURS = %w[
    bg-emerald-500 bg-sky-500 bg-rose-500 bg-amber-500 bg-violet-500 bg-teal-500
  ].freeze

  # The same name always draws the same tile, so you find what you are looking
  # for by its colour before you have read the label.
  def avatar_colour(named)
    AVATAR_COLOURS[named.name.sum % AVATAR_COLOURS.size]
  end

  def avatar_initial(named)
    named.name.first.upcase
  end
end
