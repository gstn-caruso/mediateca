# The panel asks this for the words of whatever is playing, and gets them the
# way the karaoke needs them: every line with the moment it is sung, and whether
# the file was timed at all — a plain .lrc is still the words, it just cannot be
# followed.
#
# ServesMedia, because the words come off the same read-only disk as the music
# and are held to the same boundary: a path that resolves outside the media root
# is refused rather than read.
class LyricsController < ApplicationController
  include ServesMedia

  def show
    lyrics = Track.find(params[:track_id]).lyrics

    # Most of the record has no .lrc beside it. That is not an error, but the
    # panel has to be able to tell it from one.
    return head :not_found if lyrics.empty?

    render json: lyrics
  end
end
