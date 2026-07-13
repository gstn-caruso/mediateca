require "test_helper"

# A library that fills its own disk stops being one.
class DiskTest < ActiveSupport::TestCase
  test "a disk with room has room" do
    assert_predicate Disk.new(Dir.tmpdir).used, :positive?
  end

  # Fail closed. A disk that will not answer is not a disk to start filling — and
  # "I could not tell" is not the same answer as "there is room".
  test "a disk that cannot be read is not a disk to fill" do
    disk = Disk.new("/there/is/nothing/here")

    assert_nil disk.used
    assert_not_predicate disk, :room?
    assert_match(/can't be read/i, disk.why_not)
  end

  test "past the line, there is no room" do
    assert_not_predicate Full.new, :room?
    assert_match(/76% full/, Full.new.why_not)
    assert_match(/#{Disk::FULL_ENOUGH}%/, Full.new.why_not)
  end

  class Full < Disk
    def initialize = super("/wherever")
    def used = 76
  end
end
