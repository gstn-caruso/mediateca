# What a listener kept on Spotify, brought home: the hearts and the lists. Off the
# request, because a library of ten thousand hearted songs is two hundred pages and
# nobody should watch a spinner through them.
class ImportFromSpotifyJob < ApplicationJob
  queue_as :default

  # Only what trying again could fix. A refusal is not: Spotify said no, and it
  # will say no five more times.
  retry_on Spotify::Api::Unreachable, Spotify::Api::Busy, wait: :polynomially_longer, attempts: 5

  def perform(profile)
    return unless profile.spotify?

    Spotify::Import.new(profile).bring_it_all_home
  end
end
