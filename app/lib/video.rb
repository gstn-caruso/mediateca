module Video
  # The errors live in Ffprobe, which is the one that knows them. They are
  # re-exported here so whoever works with video doesn't need to know where
  # they come from.
  Unreadable = Ffprobe::Unreadable
  NotInstalled = Ffprobe::NotInstalled
end
