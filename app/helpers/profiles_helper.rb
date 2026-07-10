module ProfilesHelper
  # Written out whole because Tailwind reads these strings at build time and
  # cannot see a class name that Ruby assembles.
  AVATAR_COLOURS = %w[
    bg-emerald-500 bg-sky-500 bg-rose-500 bg-amber-500 bg-violet-500 bg-teal-500
  ].freeze

  # The same name always draws the same tile, so you find your profile by its
  # colour before you have read the label.
  def avatar_colour(profile)
    AVATAR_COLOURS[profile.name.sum % AVATAR_COLOURS.size]
  end

  def avatar_initial(profile)
    profile.name.first.upcase
  end
end
