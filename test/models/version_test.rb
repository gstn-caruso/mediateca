require "test_helper"

class VersionTest < ActiveSupport::TestCase
  test "a build knows which tag it was cut from" do
    version = Version.new("v1.0.0")

    assert version.known?
    assert_equal "v1.0.0", version.to_s
  end

  # git hands back its answer with the newline it printed it with.
  test "the newline git prints is not part of the name" do
    assert_equal "v1.0.0", Version.new("v1.0.0\n").to_s
  end

  # A checkout with no tags yet, or an image built outside the release, has no
  # version — and says nothing rather than making one up.
  test "a build cut from no tag at all does not pretend to have one" do
    [ nil, "", "  ", "\n" ].each do |nothing|
      version = Version.new(nothing)

      assert_not version.known?, "#{nothing.inspect} passed itself off as a version"
      assert_empty version.to_s
    end
  end
end
