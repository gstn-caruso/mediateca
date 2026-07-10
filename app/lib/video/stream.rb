module Video
  # One stream inside a media file, as ffprobe describes it.
  Stream = Data.define(:index, :codec, :channels, :language, :title)
end
