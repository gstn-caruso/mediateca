# Covers and audio are addressed by row id, and row ids get handed to different
# records whenever the catalog is rebuilt. Both URLs carry a signature of the
# file they mean, so a cached response can never be revalidated into another
# album's cover or another song's audio.
#
# The signature is stable for a file that did not move, so a re-import does not
# throw away a warm cache.
module MediaHelper
  def cover_url(album)
    cover_album_path(album, v: MediaFile.signature(album.cover_path))
  end

  def stream_url(track)
    stream_track_path(track, v: MediaFile.signature(track.path))
  end

  def portrait_url(artist)
    portrait_artist_path(artist, v: MediaFile.signature(artist.portrait_path))
  end
end
