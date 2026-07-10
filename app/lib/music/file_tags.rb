module Music
  # What one audio file says about itself: the tags a person typed, and the
  # `audio` the encoder left behind (nil when the file carries no audio stream).
  FileTags = Data.define(:title, :artist, :album_artist, :album, :year, :genre, :track_no, :disc_no, :duration, :audio)
end
