# Covers and audio are addressed by row id, and row ids get handed to different
# records whenever the catalog is rebuilt. Both URLs carry a signature of the
# file they mean, so a cached response can never be revalidated into another
# album's cover or another song's audio.
#
# The signature is stable for a file that did not move, so a re-import does not
# throw away a warm cache.
#
# And a picture says how big it is going to be drawn, so the NAS can send that
# much of it and no more. The size travels in the URL beside the signature, which
# is what makes it a picture a cache can keep: two sizes of one sleeve are two
# pictures, and they do not answer for each other.
module MediaHelper
  def cover_url(album, size: nil)
    album_cover_path(album, v: MediaFile.signature(album.cover_path), size:)
  end

  def stream_url(track)
    track_stream_path(track, v: MediaFile.signature(track.path))
  end

  def portrait_url(artist, size: nil)
    artist_portrait_path(artist, v: MediaFile.signature(artist.portrait_path), size:)
  end
end
