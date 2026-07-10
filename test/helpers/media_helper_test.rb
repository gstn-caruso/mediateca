require "test_helper"

class MediaHelperTest < ActionView::TestCase
  # A URL keyed on a row id cannot tell two albums apart once a re-import hands
  # that id to a different album. The browser then answers a request for one
  # with the other, out of its cache, and Celia Cruz wears Piazzolla's face.
  test "two albums handed the same id do not share a cover URL" do
    piazzolla = Album.new(id: 11, cover_path: "/music/Astor Piazzolla/1976 - Suite/cover.jpg")
    celia     = Album.new(id: 11, cover_path: "/music/Celia Cruz/2015 - Eterna/cover.jpg")

    refute_equal cover_url(piazzolla), cover_url(celia),
      "a cache would answer a request for one album with the other's cover"
  end

  # The same file has to keep the same URL, or every re-import throws away a
  # warm cache for nothing.
  test "an album that did not move keeps its cover URL" do
    path = "/music/Celia Cruz/2015 - Eterna/cover.jpg"

    assert_equal cover_url(Album.new(id: 11, cover_path: path)),
                 cover_url(Album.new(id: 11, cover_path: path))
  end

  # The same bug, but it plays you the wrong song.
  test "two tracks handed the same id do not share a stream URL" do
    one = Track.new(id: 3, path: "/music/Almafuerte/01 - Desencuentro.flac")
    two = Track.new(id: 3, path: "/music/Hermética/01 - Soy de la esquina.flac")

    refute_equal stream_url(one), stream_url(two),
      "a cache would play one song where the other was asked for"
  end

  test "a track that did not move keeps its stream URL" do
    path = "/music/Almafuerte/01 - Desencuentro.flac"

    assert_equal stream_url(Track.new(id: 3, path:)), stream_url(Track.new(id: 3, path:))
  end

  # And the same for a face.
  test "two artists handed the same id do not share a portrait URL" do
    refute_equal portrait_url(Artist.new(id: 4, portrait_path: "/portraits/aaa.jpg")),
                 portrait_url(Artist.new(id: 4, portrait_path: "/portraits/bbb.jpg"))
  end

  test "an album with no cover on disk still has a URL to ask for it" do
    assert_match %r{/albums/11/cover}, cover_url(Album.new(id: 11, cover_path: nil))
  end
end
