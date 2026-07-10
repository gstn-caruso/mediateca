module TracksHelper
  UNKNOWN_DURATION = "–:––".freeze

  # Track lengths read as minutes and seconds even past the hour, the way a
  # player shows them — a 74 minute live set is "74:30", not "1:14:30".
  def track_duration(seconds)
    return UNKNOWN_DURATION if seconds.blank?

    minutes, remainder = seconds.round.divmod(60)

    format("%d:%02d", minutes, remainder)
  end
end
