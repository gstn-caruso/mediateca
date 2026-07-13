# Connecting a Last.fm is a journey out and back. The listener says yes on
# Last.fm's own page — this app never sees a Last.fm password — and returns
# holding a token, which is spent here for a session key that never expires.
class ScrobblersController < ApplicationController
  before_action :require_lastfm

  # Where the app owns up to what Last.fm actually did with the listening it was
  # handed. It is a page rather than a line in a menu because the interesting
  # answer is not "connected" — it is how much of a year Last.fm quietly refused
  # as too old, which nothing else in the app would ever have said out loud.
  def show
    return redirect_to root_path unless Current.profile.scrobbles?

    @scrobbler = Current.profile.scrobbler
    @scrobbles = Current.profile.scrobbles
  end

  def connect
    redirect_to Lastfm.api.authorize_url(returning_to: way_back), allow_other_host: true
  end

  # The way back is a GET, and a GET is a link: without the handshake, anybody
  # could send this listener a link carrying *their* token and quietly have the
  # house scrobble into a stranger's account. So a token is only spent if we are
  # the ones who sent them to Last.fm — and a handshake is good for one journey.
  def callback
    return refuse("That did not come back from Last.fm.") unless expected?(params[:handshake])

    said = Lastfm.api.session_for(params[:token])
    Current.profile.scrobbles_to(**said)

    redirect_to root_path, notice: "Scrobbling to Last.fm as #{said.fetch(:username)}."
  rescue Lastfm::Api::Unreachable, Lastfm::Api::Refused => e
    refuse("Last.fm would not connect: #{e.message}")
  end

  # Slow, and said so plainly. Last.fm hands a history over two hundred at a time
  # and suspends accounts that ask several times a second, so it is asked once a
  # second — and a long history is a long wait that nobody has to sit through.
  def import
    return redirect_to root_path unless Current.profile.scrobbles?

    ImportFromLastfmJob.perform_later(Current.profile)

    redirect_to scrobbler_path,
                notice: "Bringing your Last.fm home. It is asked for politely, one page a second, so a long history takes a while — you can close this."
  end

  def destroy
    Current.profile.stops_scrobbling

    redirect_to root_path, notice: "Last.fm disconnected. Nothing more will be scrobbled."
  end

  private

  # No API account, no Last.fm anywhere in the app.
  def require_lastfm
    redirect_to root_path unless Lastfm.api.configured?
  end

  # Told to Last.fm as where to send them back, so it comes home in their hands.
  def way_back
    session[:lastfm_handshake] = SecureRandom.urlsafe_base64

    callback_scrobbler_url(handshake: session[:lastfm_handshake])
  end

  # Spent on the way in, whether or not it turns out to be the right one: a
  # handshake is for one journey, and a wrong guess does not get a second try.
  def expected?(said)
    session.delete(:lastfm_handshake).then do |sent|
      sent.present? && said.present? && ActiveSupport::SecurityUtils.secure_compare(sent, said)
    end
  end

  def refuse(why)
    redirect_to root_path, alert: why
  end
end
