module PanelsHelper
  # The width of every panel, written on the room itself.
  #
  # It goes on <html> and not on the panels because <html> is the one element a
  # Turbo visit does not touch: the body is replaced, the head is merged, and the
  # room stands. A width kept on a panel would be a width the *next* page has to
  # be told again — and told by the server, which means a PATCH nobody waited for
  # racing the GET of whatever was clicked next. Losing that race would redraw the
  # rail at the width it no longer has.
  #
  # So the hand writes the width here, once, and every page drawn after it is
  # already wearing it. Each panel reads its own off the room by name.
  def panel_widths
    return "" unless Current.profile

    Panel::NAMES.map { "--#{it}: #{Current.profile.width_of(it)}px" }.join("; ")
  end
end
