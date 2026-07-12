# A new build, and every tab in the house still looking at the old one.
#
# Saying so is the whole of it: Turbo answers a refresh by morphing the page onto
# the new build rather than reloading it, and a morph steps around anything
# marked permanent. The <audio> lives inside #player, which is permanent. So the
# deploy lands underneath the music without the music stopping to take delivery.
#
# The one exception is a build whose JavaScript or stylesheet changed: the page
# cannot run new code it has not loaded, so Turbo reloads in earnest instead of
# morphing, and the player picks the song back up off storage where it left it.
#
# Said by Kamal's post-deploy hook, once the new build is the one actually
# answering. Said at boot it would reach the tabs while the proxy still pointed
# at the old container, and they would refresh onto exactly what they had.
class Deploy
  STREAM = "builds".freeze

  def self.went_live
    Turbo::StreamsChannel.broadcast_refresh_to STREAM
  end
end
