module Music
  module Source
    # A track as some source describes it. `duration` is in seconds; `path` is
    # absolute, and is the track's identity. `artist` is whoever the file credits
    # the song to, which is usually the album's artist and occasionally a guest.
    # `audio` is the file's encoding (Music::Audio), which only the disk can
    # measure — nil when a source, like beets, only knows the metadata.
    Track = Data.define(:path, :title, :artist, :track_no, :disc_no, :duration, :audio)
  end
end
