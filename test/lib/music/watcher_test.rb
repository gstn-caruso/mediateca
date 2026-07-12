require "test_helper"

module Music
  class WatcherTest < ActiveSupport::TestCase
    # A scan that has been asked for but has not run yet. Standing in for the
    # queue lets these tests say what the watcher decides, without waiting on it.
    class FakeScans
      attr_reader :requested

      def initialize = @requested = 0

      def pending? = @pending

      def request
        @requested += 1
        @pending = true
      end

      # The queue picks the scan up: nothing is waiting any more.
      def starts = @pending = false
    end

    setup { @scans = FakeScans.new }

    test "music that never changes is never scanned" do
      Watcher.new(scans: @scans)

      assert_equal 0, @scans.requested
    end

    test "music that appears asks for a scan" do
      Watcher.new(scans: @scans).changed

      assert_equal 1, @scans.requested
    end

    # Copying an album is not one event: thirteen files land, and each one is a
    # reason to look again. One look is enough for all of them.
    test "a whole album landing at once asks for a single scan" do
      watcher = Watcher.new(scans: @scans)

      13.times { watcher.changed }

      assert_equal 1, @scans.requested
    end

    # The scan already under way began before this file existed, and may have
    # walked past its directory already. Whatever it misses, the next one catches.
    test "music that appears while a scan runs asks for another scan" do
      watcher = Watcher.new(scans: @scans)
      watcher.changed
      @scans.starts

      watcher.changed

      assert_equal 2, @scans.requested
    end
  end
end
