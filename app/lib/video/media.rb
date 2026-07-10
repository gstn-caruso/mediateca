module Video
  # What a media file contains: its container, its video stream, its audio
  # streams. Immutable; Video::Probe builds it, Video::Playback reads it.
  Media = Data.define(:container, :video, :audios)
end
