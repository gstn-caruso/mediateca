module Video
  # The file is not something we can play — or not something at all.
  Unreadable = Class.new(StandardError)

  # ffmpeg is missing. Not the file's fault; ours.
  NotInstalled = Class.new(StandardError)
end
