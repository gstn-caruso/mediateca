class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :require_profile

  helper_method :library_artists, :library_albums, :playlists, :playlist_song_counts

  private

  # There is no password: whoever holds the cookie is whoever it names. On a
  # home LAN that is the whole of it, and it is a trade made on purpose.
  #
  # The cookie outlives the profile it names — a browser left open on the
  # kitchen tablet still remembers somebody deleted last week — so a name that
  # no longer exists means nobody is listening, not an exception.
  def require_profile
    Current.profile = Profile.find_by(id: cookies.signed[:profile_id])

    redirect_to profiles_path unless Current.profile
  end

  # The library sits in the sidebar of every page, the way a music app keeps it.
  # Lazily, so serving a FLAC never pays for a query nobody reads.
  #
  # The rail counts each artist's records and each playlist's songs, and asking
  # the database once per row would put that cost on every page in the app. So
  # they arrive together: a home library's worth of albums is one small query,
  # and counting them in Ruby costs nothing anybody can feel.
  def library_artists
    @library_artists ||= Artist.ordered.visible_to(Current.profile).includes(:albums).to_a
  end

  # The same library, seen as the records rather than as the people who made
  # them. Each row names its artist, so they come along rather than being asked
  # for one row at a time.
  def library_albums
    @library_albums ||= Album.shelved.visible_to(Current.profile).includes(:artist).to_a
  end

  # The listener's own playlists, in the sidebar of every page they see — and in
  # the menu behind every song's +, which asks whether there are any at all. A
  # remembered *query* would run that question again for every song on the page;
  # remembering the answer asks it once.
  def playlists
    @playlists ||= Current.profile.playlists.ordered.to_a
  end

  # How many songs each list holds — as this listener will see it, so a song by
  # somebody they have hidden is not counted, because it will not be drawn
  # either. A rail promising a number the list does not keep is worse than no
  # number at all.
  #
  # Counted in the database, all the lists at once. The entries themselves are
  # never loaded: the rail wants a number, and a number is what it asks for.
  def playlist_song_counts
    @playlist_song_counts ||= PlaylistEntry.joins(track: :album)
                                           .where(playlist: playlists)
                                           .where.not(albums: { artist_id: Current.profile.hidden_artist_ids })
                                           .group(:playlist_id)
                                           .count
  end
end
