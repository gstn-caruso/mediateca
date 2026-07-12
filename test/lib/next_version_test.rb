require "test_helper"

class NextVersionTest < ActiveSupport::TestCase
  test "a feature earns a minor, and the patch count starts over" do
    assert_equal "v1.3.0", bump("v1.2.7", "feat: the rail offers the rest of the artist")
  end

  test "everything that is not a feature is a patch" do
    [ "fix: the click that was lost", "refactor: move the version", "chore: bump a gem",
      "docs: say what the disk says", "test: wait for the results" ].each do |commit|
      assert_equal "v1.2.8", bump("v1.2.7", commit), "#{commit.split(":").first} did not earn a patch"
    end
  end

  # The bang and the trailer are the two ways a conventional commit says it broke
  # something, and both of them cost a major.
  test "a breaking change costs a major, and the rest starts over" do
    assert_equal "v2.0.0", bump("v1.2.7", "feat!: the queue is a playlist now")
    assert_equal "v2.0.0", bump("v1.2.7", "refactor(player)!: rip out the old queue")
    assert_equal "v2.0.0", bump("v1.2.7", "fix: something\n\nBREAKING CHANGE: the URLs moved")
  end

  # A squash merge signs the subject with the pull request it came from.
  test "the pull request number github tacks on does not confuse it" do
    assert_equal "v1.3.0", bump("v1.2.7", "feat: refresh every open tab on deploy (#9)")
  end

  test "a scope does not change what the type means" do
    assert_equal "v1.3.0", bump("v1.2.7", "feat(queue): suggestions")
    assert_equal "v1.2.8", bump("v1.2.7", "fix(player): the held press")
  end

  # Nothing that lands on main should be able to stop a deploy over its wording.
  test "a commit that says nothing about its type is a patch, not an error" do
    assert_equal "v1.2.8", bump("v1.2.7", "arreglo el reloj")
  end

  # There is no version yet: the first one is not a bump of anything.
  test "with no tag behind it, the first version is 1.0.0" do
    [ nil, "", "  " ].each do |nothing|
      assert_equal "v1.0.0", bump(nothing, "feat: the very first thing")
    end
  end

  private

  def bump(previous, commit)
    NextVersion.new(previous:, commit:).to_s
  end
end
