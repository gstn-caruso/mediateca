# Which build is answering.
#
# The commit Kamal deployed, which is a different thing from the version. The
# version is a tag, and a tag can sit still across a deploy — a re-run, a
# rollback — where the commit cannot. A tab compares this, and not the version,
# to know whether the app underneath it has been replaced; a name that repeated
# itself would leave it sitting on a build it believes it already has.
#
# Not every build was deployed, though. The image CI boots to see that it comes
# up knows only the tag it was cut from, and a development machine knows neither.
class Build
  UNDEPLOYED = "dev".freeze

  def initialize(deployed:, cut_from:)
    @deployed = name(deployed)
    @cut_from = name(cut_from)
  end

  def to_s
    @deployed || @cut_from || UNDEPLOYED
  end

  private
    # A variable set to nothing has named nothing.
    def name(said)
      said.presence
    end
end
