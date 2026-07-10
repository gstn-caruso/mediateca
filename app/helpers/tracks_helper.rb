module TracksHelper
  UNKNOWN_DURATION = "–:––".freeze

  # Track lengths read as minutes and seconds even past the hour, the way a
  # player shows them — a 74 minute live set is "74:30", not "1:14:30".
  def track_duration(seconds)
    return UNKNOWN_DURATION if seconds.blank?

    minutes, remainder = seconds.round.divmod(60)

    format("%d:%02d", minutes, remainder)
  end

  # A whole record reads differently from one song: nobody says an album lasts
  # 111 minutes.
  def album_length(seconds)
    return if seconds.blank? || seconds.zero?

    hours, minutes = (seconds / 60).round.divmod(60)

    return "#{minutes} min" if hours.zero?

    [ "#{hours} h", ("#{minutes} min" unless minutes.zero?) ].compact.join(" ")
  end
end
