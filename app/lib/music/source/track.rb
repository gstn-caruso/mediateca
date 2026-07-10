module Music
  module Source
    # A track as some source describes it. `duration` is in seconds; `path` is
    # absolute.
    Track = Data.define(:beets_id, :title, :track_no, :disc_no, :duration, :path)
  end
end
