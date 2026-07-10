require "test_helper"
require "tmpdir"

class MediaFileTest < ActiveSupport::TestCase
  test "a file inside the root can be served" do
    within_root do |root|
      flac = create(root, "Almafuerte/01 - Desencuentro.flac")

      assert MediaFile.new(flac, root:).exist?
    end
  end

  test "a file inside the root that is no longer on disk can't be served" do
    within_root do |root|
      refute MediaFile.new("#{root}/deleted.flac", root:).exist?
    end
  end

  # Paths come from the database, not from the request; but the database is
  # filled by a scanner that reads whatever is on disk. The root is the trust boundary.
  test "a path that escapes the root with .. is rejected" do
    within_root do |root|
      assert_raises(MediaFile::Forbidden) { MediaFile.new("#{root}/../../etc/passwd", root:) }
    end
  end

  test "an absolute path outside the root is rejected" do
    within_root do |root|
      assert_raises(MediaFile::Forbidden) { MediaFile.new("/etc/passwd", root:) }
    end
  end

  # A shared prefix isn't being inside: /mnt/data-secret isn't
  # inside /mnt/data.
  test "a sibling with the same prefix as the root is rejected" do
    within_root do |root|
      assert_raises(MediaFile::Forbidden) { MediaFile.new("#{root}-secret/stolen.flac", root:) }
    end
  end

  test "a symlink that points outside the root is rejected" do
    within_root do |root|
      secret = File.join(Dir.mktmpdir, "secret.txt")
      File.write(secret, "outside")
      link = File.join(root, "innocent.flac")
      File.symlink(secret, link)

      assert_raises(MediaFile::Forbidden) { MediaFile.new(link, root:) }
    end
  end

  private

  def within_root
    Dir.mktmpdir("media-root") { |root| yield root }
  end

  def create(root, relative)
    File.join(root, relative).tap do |path|
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "fake flac bytes")
    end
  end
end
