class ArtistsController < ApplicationController
  # The library this page shows is the library in the rail beside it, and the
  # rail is already holding it — asked for a second time here, it was the same
  # question, answered twice on the one page that asks it twice.
  def index
    @recently_played = Current.profile.recently_played_albums

    # The records the house has gone and got, which are not on the disk yet and are
    # drawn as though they were: the gap in the shelf, filling itself, in front of you.
    @coming = OnTheWay.new(Current.profile).all

    # And why nothing is coming, when nothing is. "Nothing is being fetched" is not
    # a thing to say by saying nothing.
    @no_room = Disk.holding_the_music.then { it.why_not unless it.room? } if Qbittorrent.api.configured?
  end

  def show
    @artist = Artist.find(params[:id])
    @albums = @artist.albums.ordered
  end
end
