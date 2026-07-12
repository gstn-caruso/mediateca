# What the next version is, once a change has landed on main.
#
# The commit says how far to move. A conventional commit is a promise about what
# changed, and the version is that promise written down where a listener can see
# it: a breaking change costs a major, a feature earns a minor, and everything
# else — a fix, a refactor, a tidy — is a patch. A commit that says nothing about
# its type is a patch too: no wording anybody chose in a hurry should be able to
# stop a deploy.
#
# Nothing here knows about Rails. It runs on the deployer, out of the checkout,
# before there is an app to boot — see script/next-version.
class NextVersion
  # The first release is not a bump of anything.
  FIRST = "v1.0.0".freeze

  NUMBERED = /\Av?(\d+)\.(\d+)\.(\d+)/
  # `feat!:` and `refactor(player)!:` say it in the subject; `BREAKING CHANGE:`
  # says it in the body. Both are how a conventional commit admits it broke.
  BREAKING = /\A\w+(\([^)]*\))?!:|^BREAKING[ -]CHANGE:/
  FEATURE = /\Afeat(\([^)]*\))?!?:/

  def initialize(previous:, commit:)
    @previous = previous.to_s.strip
    @commit = commit.to_s.strip
  end

  def to_s
    major, minor, patch = numbers
    return FIRST unless major

    return "v#{major + 1}.0.0" if breaking?
    return "v#{major}.#{minor + 1}.0" if feature?

    "v#{major}.#{minor}.#{patch + 1}"
  end

  private

  def numbers
    NUMBERED.match(@previous)&.captures&.map(&:to_i)
  end

  def breaking?
    @commit.match?(BREAKING)
  end

  def feature?
    @commit.match?(FEATURE)
  end
end
