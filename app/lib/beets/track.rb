module Beets
  # A track as beets knows it. `duration` is in seconds; `path` is absolute.
  Track = Data.define(:beets_id, :title, :track_no, :disc_no, :duration, :path)
end
