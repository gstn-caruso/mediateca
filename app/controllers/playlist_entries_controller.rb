class PlaylistEntriesController < ApplicationController
  before_action :set_playlist

  # Adding a song does not take you anywhere: you are on a record, adding a song
  # to a playlist, and you are still on the record afterwards. It used to be a
  # whole page fetched and redrawn, scrolled back to the top, with nothing said
  # about where the song had gone.
  def create
    track = Track.find(params[:track_id])
    @playlist.add(track)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          helpers.dom_id(track, :add),
          partial: "shared/add_to_playlist",
          locals: { track:, landed_in: @playlist.name }
        )
      end
      format.html { redirect_back_or_to album_path(track.album) }
    end
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
