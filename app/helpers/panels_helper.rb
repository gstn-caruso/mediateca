module PanelsHelper
  # Every panel's two numbers, written on the room itself.
  #
  # They go on <html> and not on the panels because <html> is the one element a
  # Turbo visit does not touch: the body is replaced, the head is merged, and the
  # room stands. A width kept on a panel would be a width the *next* page has to
  # be told again — and told by the server, which means a PATCH nobody waited for
  # racing the GET of whatever was clicked next. Losing that race would redraw the
  # rail at the width it no longer has.
  #
  # So the hand writes them here, once, and every page drawn after it is already
  # wearing them. Each panel reads its own off the room by name.
  #
  # Two numbers, because a panel is asked two questions. How wide it stands beside
  # the content, in pixels — and, with the content folded away and nothing left to
  # stand beside, how much of the empty room is its own. That second one is a
  # proportion and not a length, which is what lets it survive the trip from the
  # laptop to the kitchen tablet, where the whole room is 700 pixels wide.
  def panel_sizes
    return "" unless Current.profile

    Panel::NAMES.flat_map do
      [ "--#{it}: #{Current.profile.width_of(it)}px", "--#{it}-share: #{Current.profile.share_of(it)}" ]
    end.join("; ")
  end
end
