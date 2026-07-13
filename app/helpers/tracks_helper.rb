module TracksHelper
  UNKNOWN_DURATION = "–:––".freeze

  # A song, as the player writes one down: everything it needs to start it, to say
  # what is playing, and to wear the colour of the record it came off.
  #
  # It is written down twice, in two alphabets, and this is the one place that
  # knows both. A row carries it in HTML, where the DOM dasherizes a name on the
  # way in and camelCases it on the way out; the server hands it over in JSON,
  # which has to arrive already spelled the way the DOM would have spelled it, or
  # it is a queue of songs with no source and no title. Same words either way — so
  # a record put on from the rail is the same queue as one put on from its own
  # tracklist.
  def queueable(track)
    {
      track_id: track.id,
      src: stream_url(track),
      title: track.title,
      subtitle: track.artist_name,
      cover: cover_url(track.album),
      album: album_path(track.album),
      album_title: track.album.title,
      palette: track.album.palette.to_h.to_json
    }
  end

  # The JSON alphabet: what the DOM would have made of the same words.
  def queued(track)
    queueable(track).transform_keys { |word| word.to_s.camelize(:lower) }
  end

  # A song on a list you are looking at, which is a song you can press. `index` is
  # its place in that list — the queue the player deals when you press it, so
  # clicking track 5 of a record queues the record, from track 5.
  def playable(track, index)
    {
      player_track: "",
      player_target: "row",
      action: "player#play",
      player_index_param: index,
      **queueable(track)
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
