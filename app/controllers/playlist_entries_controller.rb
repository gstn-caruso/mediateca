class PlaylistEntriesController < ApplicationController
  before_action :set_playlist

  def create
    track = Track.find(params[:track_id])
    @playlist.add(track)

    redirect_back_or_to album_path(track.album)
  end

  # Up is -1, down is +1. Anything else is not a move.
  def update
    @playlist.move(entry, by: params[:by].to_i.clamp(-1, 1))

    redirect_to @playlist
  end

  def destroy
    entry.destroy!

    redirect_to @playlist
  end

  private

  def set_playlist
    @playlist = Current.profile.playlists.find(params[:playlist_id])
  end

  def entry
    @playlist.entries.find(params[:id])
  end
end
