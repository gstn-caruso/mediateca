class LikesController < ApplicationController
  # A like hangs off a track or an album, and the route says which by the id it
  # carries. Nothing else can be liked, because nothing else has a like route.
  LIKEABLE = { track_id: Track, album_id: Album }.freeze

  def index
    @tracks = Current.profile.liked_tracks
  end

  def create
    Current.profile.like(likeable)
    swap_the_heart
  end

  def destroy
    Current.profile.unlike(likeable)
    swap_the_heart
  end

  private

  # The heart is swapped where it stands, and nothing else moves. Somebody
  # pressing a heart is telling you about a song, not asking to be taken
  # somewhere — and it used to take them somewhere: a whole page, re-fetched and
  # re-drawn, scrolled back to the top of the record, with one more entry in the
  # history for every heart they gave.
  #
  # The redirect stays for a browser running no JavaScript, which is the only one
  # that will ever ask for it.
  def swap_the_heart
    respond_to do |format|
      format.turbo_stream { render turbo_stream: [ the_heart, the_row_it_is_no_longer ].compact }
      format.html { redirect_back_or_to likes_path }
    end
  end

  def the_heart
    turbo_stream.replace(
      helpers.dom_id(likeable, :heart),
      partial: "shared/heart",
      locals: { thing: likeable, size: params[:size] }
    )
  end

  # A song unhearted is not a liked song, so its row in Liked Songs goes. Said
  # unconditionally: on any other page there is no such row, and Turbo removes
  # nothing. It is true everywhere — the page it is true *about* is the one that
  # has the row.
  def the_row_it_is_no_longer
    turbo_stream.remove(helpers.dom_id(likeable, :liked)) unless Current.profile.likes?(likeable)
  end

  def likeable
    @likeable ||= begin
      param, model = LIKEABLE.find { |name, _| params[name] }

      model.find(params[param])
    end
  end
end
