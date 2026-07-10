class LikesController < ApplicationController
  # A like hangs off a track or an album, and the route says which by the id it
  # carries. Nothing else can be liked, because nothing else has a like route.
  LIKEABLE = { track_id: Track, album_id: Album }.freeze

  def index
    @tracks = Current.profile.liked_tracks
  end

  def create
    Current.profile.like(likeable)
    redirect_back_or_to likes_path
  end

  def destroy
    Current.profile.unlike(likeable)
    redirect_back_or_to likes_path
  end

  private

  def likeable
    param, model = LIKEABLE.find { |name, _| params[name] }

    model.find(params[param])
  end
end
