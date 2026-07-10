require "test_helper"
require "tmpdir"

module Music
  class PortraitsOnDiskTest < ActiveSupport::TestCase
    setup do
      @root = Dir.mktmpdir
      @artist = Artist.create!(name: "Luis Alberto Spinetta")
      Album.create!(directory: File.join(@root, "Luis Alberto Spinetta", "1973 - Artaud"),
                    title: "Artaud", artist: @artist)
      FileUtils.mkdir_p(File.join(@root, "Luis Alberto Spinetta"))
    end

    teardown { FileUtils.remove_entry(@root) }

    test "a photograph left beside the records is the one that wins" do
      write("artist.jpg", "spinetta")

      assert_equal "spinetta", PortraitsOnDisk.new.portrait_of(@artist).bytes
    end

    test "it answers to the other names people give these files" do
      write("folder.png", "spinetta")

      assert_equal "spinetta", PortraitsOnDisk.new.portrait_of(@artist).bytes
    end

    # Spinetta's folder holds spinetta.jpg, and nobody was going to rename it.
    test "one image loose in the folder is taken as the artist's" do
      write("spinetta.jpg", "spinetta")

      assert_equal "spinetta", PortraitsOnDisk.new.portrait_of(@artist).bytes
    end

    test "nothing on the disk is nothing to show" do
      assert_nil PortraitsOnDisk.new.portrait_of(@artist)
    end

    test "an artist with no albums has no folder to look in" do
      assert_nil PortraitsOnDisk.new.portrait_of(Artist.create!(name: "Nobody"))
    end

    private

    def write(name, bytes)
      File.binwrite(File.join(@root, "Luis Alberto Spinetta", name), bytes)
    end
  end
end
