module Music
  module Source
    # A track as some source describes it. `duration` is in seconds; `path` is
    # absolute, and is the track's identity. `audio` is the file's encoding
    # (Music::Audio), which only the disk can measure — nil when a source, like
    # beets, only knows the metadata.
    Track = Data.define(:path, :title, :track_no, :disc_no, :duration, :audio)
  end
end
