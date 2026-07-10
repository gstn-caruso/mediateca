module Music
  module Source
    # A track as some source describes it. `duration` is in seconds; `path` is
    # absolute, and is the track's identity.
    Track = Data.define(:path, :title, :track_no, :disc_no, :duration)
  end
end
