# Which tag this build was cut from.
#
# The tag lives in git, and a running app has no git to ask: the image is a
# tarball of the source, not a clone. So on the way in, the Dockerfile takes the
# tag as a build argument and Kamal hands it whatever the deploy was cut from,
# baked into the environment the container runs with.
#
# A development machine has the clone right there, so it asks git itself. A
# checkout with no tags — or an image built outside a release — has no version,
# and the app says nothing rather than inventing one.
tag = ENV["MEDIATECA_VERSION"]

if tag.blank? && Rails.env.development?
  begin
    tag = `git describe --tags --abbrev=0 2>/dev/null`
  rescue StandardError
    tag = nil # no git on this machine, which is not worth a word about
  end
end

Rails.application.config.x.version_name = tag

# Which build is answering: the commit Kamal put here, which is a different thing
# from the version. The version is a tag, and a tag can sit still across a deploy
# — a re-run, a rollback — where the commit cannot. A tab compares this, not the
# version, to know whether the app underneath it has been replaced.
Rails.application.config.x.build =
  ENV["KAMAL_VERSION"].presence || Rails.application.config.x.version_name.presence || "dev"
