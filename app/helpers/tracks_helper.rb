module TracksHelper
  UNKNOWN_DURATION = "–:––".freeze

  # Everything the player needs to start a song and keep the record playing
  # after it. Four different lists of songs — a record, a playlist, the hearts, a
  # search — each handed it the same eight things, written out eight times over.
  # The player reads them straight off the row, so they are spelled here, once.
  #
  # `index` is the song's place in the list it belongs to, which is the queue the
  # player deals when you press it: clicking track 5 of a record queues the
  # record, from track 5.
  def playable(track, index)
    {
      player_track: "",
      player_target: "row",
      action: "player#play",
      player_index_param: index,
      track_id: track.id,
      src: stream_url(track),
      title: track.title,
      subtitle: track.artist_name,
      cover: cover_url(track.album),
      album: album_path(track.album),
      album_title: track.album.title
    }
  end

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
