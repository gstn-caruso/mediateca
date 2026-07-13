module Music
  # The scans the queue knows about.
  #
  # A scan waiting to start will read the whole disk when it does, so it already
  # speaks for whatever landed since: asking for another would only read the same
  # tags twice. One that is already running speaks for nothing new — it may have
  # walked past the new directory before the file was there — so it does not
  # count as pending, and the music that arrives behind it gets a scan of its own.
  class Scans
    def request = ScanMusicJob.perform_later

    def pending?
      SolidQueue::ReadyExecution
        .joins(:job)
        .where(solid_queue_jobs: { class_name: ScanMusicJob.name })
        .exists?
    end
  end
end
