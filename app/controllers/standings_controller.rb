# Hiding an artist and highlighting one are the same gesture pointed two ways,
# so they are the same resource: one standing, taken or given back.
class StandingsController < ApplicationController
  # The two standings there are, and how the profile is told about each. A
  # request naming anything else is naming nothing — the whitelist is what says
  # so, and it is the only reason a parameter is allowed to choose a message.
  TAKEN   = { "hidden" => :hide,   "highlighted" => :highlight }.freeze
  DROPPED = { "hidden" => :unhide, "highlighted" => :unhighlight }.freeze

  def create
    stand(TAKEN)
  end

  def destroy
    stand(DROPPED)
  end

  private

  def stand(standings)
    told = standings[params[:standing]]

    return head :bad_request unless told

    Current.profile.public_send(told, artist)
    become_the_page_it_now_is
  end

  # Hiding somebody changes the page in more places than the button that was
  # pressed: they leave the rail, they leave the shelf of records, they leave what
  # you recently played, and the lists they were in grow shorter. Swapping one
  # button would leave a page still holding all of them — so the answer is the
  # page again, not a piece of it.
  #
  # Back to the page you were on, which Turbo sees for what it is: a visit to the
  # URL you are already at is a *refresh*, and this app refreshes by morphing. So
  # the library rearranges itself in place, the scroll stays where it was, the
  # history takes no entry for an opinion, and the morph steps around the
  # permanent <audio> — the music does not so much as stutter.
  #
  # A turbo_stream.refresh looks like the shorter way to say this and is not: it
  # carries the request id, and Turbo pointedly ignores a refresh a tab asked for
  # itself. It is for telling the *other* tabs.
  def become_the_page_it_now_is
    redirect_back_or_to artist_path(artist), status: :see_other
  end

  def artist
    @artist ||= Artist.find(params[:artist_id])
  end
end
