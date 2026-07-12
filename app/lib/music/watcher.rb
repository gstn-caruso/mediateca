module Music
  # Notices that the music on disk changed, and asks for a scan.
  #
  # Copying an album is not one event but dozens, and a scan reads every tag on
  # the NAS: a scan per file would be absurd. So a burst asks for one scan, and
  # asks again only once that one has left the queue — because a scan already
  # under way began before this file existed, and may have walked past its
  # directory already. One more, behind it, catches whatever it missed.
  class Watcher
    # Watches the music for as long as the process lives. Listen does its waiting
    # on a thread of its own, so this returns and the app goes on booting.
    def self.start(root: Rails.configuration.x.music_root, scans: Scans.new)
      new(scans:).tap do |watcher|
        # Listen says which files moved; the scan reads the disk anyway, so what
        # changed does not matter here — only that something did.
        Listen.to(root) { watcher.changed }.start
      end
    end

    def initialize(scans:)
      @scans = scans
    end

    def changed
      scans.request unless scans.pending?
    end

    private
      attr_reader :scans
  end
end
