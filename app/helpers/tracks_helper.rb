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

  # Codecs that keep every sample: their fidelity is the depth and rate they were
  # captured at, not a bitrate a compressor settled on. The whole library is
  # FLAC, but the badge reads the same way for anything lossless.
  LOSSLESS = %w[flac alac wav wavpack ape].freeze

  # A short badge for how good a file is: "FLAC · 16/44.1" for a lossless file,
  # "MP3 · 320" for a compressed one. Nil for a row scanned before we recorded
  # its encoding, so the badge just doesn't show.
  def track_quality(track)
    return if track.codec.blank?

    [ track.codec.upcase, fidelity(track) ].compact.join(" · ")
  end

  # The long form, for a tooltip: every measure we have, spelled out.
  def track_quality_detail(track)
    return if track.codec.blank?

    [
      track.codec.upcase,
      ("#{track.bit_depth}-bit" if track.bit_depth),
      ("#{khz(track.sample_rate)} kHz" if track.sample_rate),
      ("#{kbps(track.bit_rate)} kbps" if track.bit_rate)
    ].compact.join(" · ")
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

  private

  # A lossless file's fidelity is its depth and rate; a lossy one's is the
  # bitrate it chose.
  def fidelity(track)
    if LOSSLESS.include?(track.codec.downcase)
      "#{track.bit_depth}/#{khz(track.sample_rate)}" if track.bit_depth && track.sample_rate
    elsif track.bit_rate
      kbps(track.bit_rate)
    end
  end

  # 44100 → "44.1", 48000 → "48", 96000 → "96".
  def khz(hertz)
    format("%g", hertz / 1000.0)
  end

  def kbps(bits_per_second)
    (bits_per_second / 1000.0).round
  end
end
