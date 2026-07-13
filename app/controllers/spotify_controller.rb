# Connecting a Spotify, so what a listener kept there can be brought home: the
# songs they hearted, the records they saved, the lists they made.
#
# Not their history. Spotify has no endpoint for one — the most it will ever tell
# you is the last fifty songs you played — so nothing here pretends otherwise, and
# the history comes from Last.fm.
#
# The journey is PKCE: a secret is invented here, its hash is what Spotify is
# shown on the way out, and the secret itself is what proves on the way back that
# this is the same app that left. Nothing that has to be kept, which is exactly
# right for something running on a NAS.
class SpotifyController < ApplicationController
  before_action :require_spotify

  # Spotify allows a loopback address as a way back and refuses the *word*
  # `localhost` — it is explicit about the distinction, and will not even let you
  # register one. Which means that in development this app has to be reached at
  # 127.0.0.1, and there is nothing it can do about that.
  #
  # What it must not do is paper over it. Quietly sending 127.0.0.1 as the way back
  # while the listener stands on localhost splits the journey across two origins,
  # and a browser keeps a separate cookie jar for each — so they come home to a
  # session that never heard of them, and are told the handshake failed. Which is
  # true, and is the least useful true thing the app could have said.
  NOT_LOCALHOST = "Spotify will not send anybody back to `localhost` — only to the address it stands for. " \
                  "Open Mediateca at http://127.0.0.1:3000 and connect from there.".freeze

  def show
    return redirect_to root_path unless Current.profile.spotify?

    @account = Current.profile.spotify_account
  end

  def connect
    return refuse(NOT_LOCALHOST) if on_localhost?

    session[:spotify_verifier] = SecureRandom.urlsafe_base64(64)
    session[:spotify_handshake] = SecureRandom.urlsafe_base64

    redirect_to Spotify.api.authorize_url(
      returning_to: callback_spotify_url,
      verifier: session[:spotify_verifier],
      state: session[:spotify_handshake]
    ), allow_other_host: true
  end

  # Spotify hands the state back untouched, which is what makes it a handshake:
  # without it, a link carrying somebody else's code would connect this listener to
  # a stranger's Spotify.
  def callback
    verifier = session.delete(:spotify_verifier)
    return refuse("That did not come back from Spotify.") unless expected?(params[:state]) && verifier

    Current.profile.connects_spotify(**tokens(params[:code], verifier))

    redirect_to spotify_path, notice: "Spotify connected."
  rescue Spotify::Api::Unreachable, Spotify::Api::Refused => e
    refuse("Spotify would not connect: #{e.message}")
  end

  def import
    return redirect_to root_path unless Current.profile.spotify?

    ImportFromSpotifyJob.perform_later(Current.profile)

    redirect_to spotify_path, notice: "Bringing your Spotify home — the hearts and the lists. You can close this."
  end

  def destroy
    Current.profile.forgets_spotify

    redirect_to root_path, notice: "Spotify disconnected."
  end

  private

  def tokens(code, verifier)
    given = Spotify.api.tokens_for(code:, verifier:, returning_to: callback_spotify_url)

    Spotify.api.me(token: given.fetch(:access_token)).merge(given)
  end

  def on_localhost?
    request.host == "localhost"
  end

  def require_spotify
    redirect_to root_path unless Spotify.api.signed_in?
  end

  def expected?(said)
    session.delete(:spotify_handshake).then do |sent|
      sent.present? && said.present? && ActiveSupport::SecurityUtils.secure_compare(sent, said)
    end
  end

  def refuse(why)
    redirect_to root_path, alert: why
  end
end
