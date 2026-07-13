require "test_helper"

module Spotify
  # What Spotify can give that Last.fm cannot: the songs you hearted there, the
  # records you saved, and the lists you made.
  #
  # And what it cannot give, which is the thing everybody assumes it can: a
  # history. There is no endpoint for one. The most Spotify will ever tell you is
  # the last fifty songs you played — so nothing here even asks.
  class ImportTest < ActiveSupport::TestCase
    setup do
      @gaston = Profile.create!(name: "Gastón")
      artist = Artist.create!(name: "Elliott Smith")
      @either = Album.create!(directory: "/music/either", title: "Either/Or", artist:)
      @bars = song("Between the Bars")
      @angeles = song("Angeles")
      @gaston.connects_spotify(username: "gaston", access_token: "at", refresh_token: "rt", expires_in: 3600)
    end

    test "a song hearted on Spotify is hearted here" do
      spotify.keeping(songs: [ { artist: "Elliott Smith", track: "Angeles" } ])

      bring_it_home

      assert @gaston.reload.likes?(@angeles)
      assert_equal 1, @gaston.spotify_account.imported_hearts
    end

    # Mediateca hearts sleeves as well as songs, which is the one place its idea of
    # a heart is bigger than either service's.
    test "a record saved on Spotify is hearted here" do
      spotify.keeping(records: [ { artist: "Elliott Smith", title: "Either/Or" } ])

      bring_it_home

      assert @gaston.reload.likes?(@either)
    end

    test "a list made on Spotify is a list here, in the order it was made" do
      spotify.keeping(lists: { "Domingo" => [ { artist: "Elliott Smith", track: "Angeles" },
                                              { artist: "Elliott Smith", track: "Between the Bars" } ] })

      bring_it_home

      list = @gaston.playlists.sole

      assert_equal "Domingo", list.name
      assert_equal [ @angeles, @bars ], list.tracks.to_a
      assert_equal 1, @gaston.spotify_account.imported_lists
    end

    # A list you kept somewhere else is the list you kept. Handing back only the
    # songs this house happens to own would be a shorter list that never said why —
    # so the songs that are not here come home as gaps: named, unplayable, and
    # drawn grey. The list stays the list.
    test "a list comes home whole, with the songs this house does not own as gaps" do
      spotify.keeping(lists: { "Domingo" => [ { artist: "Elliott Smith", track: "Angeles" },
                                              { artist: "Elliott Smith", track: "Say Yes" } ] })

      bring_it_home

      list = @gaston.playlists.sole

      assert_equal [ "Angeles", "Say Yes" ], list.entries.ordered.map(&:title)
      assert_equal [ true, false ], list.entries.ordered.map(&:playable?)
      assert_equal [ @angeles ], list.entries.playable.map(&:track)
    end

    test "a list of nothing this house owns is still the list, all of it missing" do
      spotify.keeping(lists: { "Nothing We Own" => [ { artist: "Some Band", track: "A Song" } ] })

      bring_it_home

      assert_equal [ "A Song" ], @gaston.playlists.sole.entries.map(&:title)
      assert_equal 1, @gaston.spotify_account.strangers
      assert_equal [ "Some Band" ], @gaston.absent_artists.map(&:name)
    end

    # One song you do not own is one gap, however many of your lists it turns up in.
    test "the same missing song in two lists is one gap" do
      spotify.keeping(lists: { "One" => [ { artist: "Pappo", track: "Desconfío" } ],
                               "Two" => [ { artist: "Pappo", track: "Desconfío" } ] })

      bring_it_home

      assert_equal 1, Absence.count
      assert_equal 1, @gaston.spotify_account.strangers
    end

    # Spotify refuses to hand over some lists, and it is entitled to: one made by
    # somebody else, one it has decided this app may not read. One refusal is not a
    # reason to throw away an import — the hearts already home stay home, the other
    # lists still come, and the one that was refused is counted and said out loud.
    test "a list Spotify will not hand over does not take the whole import down with it" do
      spotify.keeping(songs: [ { artist: "Elliott Smith", track: "Angeles" } ],
                      lists: { "Mine" => [ { artist: "Elliott Smith", track: "Between the Bars" } ] })
      spotify.refusing("Mine")

      assert_nothing_raised { bring_it_home }

      assert @gaston.reload.likes?(@angeles), "the hearts were already home and must stay home"
      assert_predicate @gaston.playlists, :empty?
      assert_equal 1, @gaston.spotify_account.refused_lists
    end

    # The guard that matters. A heart you gave on Spotify years ago is not a heart
    # you are giving now — and pushing it to Last.fm would say it was.
    test "nothing brought from Spotify is pushed on to Last.fm" do
      @gaston.scrobbles_to(username: "gaston", session_key: "k")
      Lastfm.api = FakeLastfm.new
      spotify.keeping(songs: [ { artist: "Elliott Smith", track: "Angeles" } ])

      bring_it_home

      assert_predicate Love.all, :empty?
    end

    test "importing again does not heart everything a second time" do
      spotify.keeping(songs: [ { artist: "Elliott Smith", track: "Angeles" } ])

      2.times { bring_it_home }

      assert_equal 1, @gaston.reload.likes.count
    end

    private

    def spotify
      @spotify ||= FakeSpotify.new.tap { Spotify.api = it }
    end

    def bring_it_home
      Import.new(@gaston).bring_it_all_home
      @gaston.reload
    end

    def song(title)
      Track.create!(title:, duration: 200.0, path: "/music/either/#{title}.flac", album: @either)
    end
  end
end
