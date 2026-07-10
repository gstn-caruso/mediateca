module ApplicationHelper
  # The two links above the library. Current page gets the white.
  def nav_link_class(current)
    base = "flex items-center gap-4 rounded-md px-3 py-2 text-sm font-semibold transition"
    current ? "#{base} text-white" : "#{base} text-neutral-400 hover:text-white"
  end
end
