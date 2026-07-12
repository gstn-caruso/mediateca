require "test_helper"

class BuildTest < ActiveSupport::TestCase
  # The whole point of naming the build by the commit. The version is a tag, and
  # the same tag can name two deploys in a row — a re-run, a rollback — where the
  # commit cannot. A tab that compared versions would sit through a deploy it
  # should have caught, still on the old build and none the wiser.
  test "the commit wins over the version, because a version can name two deploys" do
    assert_equal "00a2ce1", answering(deployed: "00a2ce1", cut_from: "v1.4.0")
  end

  test "a deployed build is named by the commit that was deployed" do
    assert_equal "00a2ce1", answering(deployed: "00a2ce1", cut_from: nil)
  end

  # The image CI boots to check that it comes up was never deployed: no Kamal put
  # it anywhere. All it knows about itself is the tag it was cut from.
  test "an image built outside a deploy has only the tag it was cut from" do
    assert_equal "v1.4.0", answering(deployed: nil, cut_from: "v1.4.0")
  end

  test "a development machine has neither, and says so plainly" do
    assert_equal "dev", answering(deployed: nil, cut_from: nil)
  end

  # An environment variable that is set to nothing has not told us anything.
  test "an empty answer is no answer at all" do
    assert_equal "dev", answering(deployed: "", cut_from: "   ")
  end

  # `git describe` hands back a newline on the end of the tag, and on a development
  # machine that tag is the name of the build. The name gets written into the page,
  # and then compared — character for character — against the same name fetched
  # back from /build later. A newline on one side of that comparison and nowhere
  # else is a page that refreshes itself every time its socket reconnects, forever,
  # over a deploy that never happened.
  test "the newline git leaves on the end is not part of the name" do
    assert_equal "v1.4.0", answering(deployed: nil, cut_from: "v1.4.0\n")
  end

  private
    def answering(deployed:, cut_from:)
      Build.new(deployed:, cut_from:).to_s
    end
end
