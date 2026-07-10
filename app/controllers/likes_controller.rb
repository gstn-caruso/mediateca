class LikesController < ApplicationController
  # The type arrives from a form, so it names whatever the browser chose to
  # send. Two classes can be liked; asking for a third is not a 500.
  LIKEABLE = { "Track" => Track, "Album" => Album }.freeze

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
    model = LIKEABLE.fetch(params[:likeable_type]) { raise ActiveRecord::RecordNotFound }
    model.find(params[:likeable_id])
  end
end
