class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :require_profile

  helper_method :library_artists

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
  def library_artists
    @library_artists ||= Artist.ordered
  end
end
