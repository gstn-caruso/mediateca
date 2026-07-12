class PlaylistsController < ApplicationController
  before_action :set_playlist, only: [ :show, :update, :destroy ]

  def show
  end

  def create
    playlist = Current.profile.playlists.new(playlist_params)

    return redirect_to playlist if playlist.save

    redirect_to root_path
  end

  def update
    @playlist.update(playlist_params)
    redirect_to @playlist
  end

  def destroy
    @playlist.destroy!
    redirect_to root_path
  end

  private

  # Found through the profile, so somebody else's playlist simply does not
  # exist. There is no password to check, and this is what stands in for one.
  #
  # Every row names the song and who sings it, which is a walk from the entry to
  # the track to its record to the artist — three questions a row, if they are
  # not fetched together.
  def set_playlist
    @playlist = Current.profile.playlists
                               .includes(entries: { track: { album: :artist } })
                               .find(params[:id])
  end

  def playlist_params
    params.expect(playlist: [ :name ])
  end
end
