# Which build this is: the tag it was cut from.
#
# The tag lives in git, and a running app has no git to ask — the image is a
# tarball of the source, not a clone — so the tag is read at build time and
# baked into the environment the container runs with. Where the answer comes
# from is settled once, at boot, in config/initializers/version.rb.
#
# A checkout that was never tagged has no version, and the app says nothing
# rather than inventing one.
class Version
  def initialize(name)
    @name = name.to_s.strip
  end

  def known?
    @name.present?
  end

  def to_s
    @name
  end
end
