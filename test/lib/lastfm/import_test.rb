require "test_helper"

module Lastfm
  # The years of listening that happened before this library existed. Last.fm has
  # been keeping them the whole time, and this is the direction that actually
  # works: it will hand over the lot, back to the day the account was opened.
  #
  # The thing to get right, and the thing an import gets wrong quietly, is what it
  # could *not* find. A hundred thousand scrobbles matched against a library of a
  # few thousand songs will miss most of themselves, and an import that found a
  # tenth of a history and reported "done" is worse than one that never ran.
  class ImportTest < ActiveSupport::TestCase
    setup do
      Lastfm.api = @lastfm = FakeLastfm.new(username: "ekvintroj")
      @gaston = Profile.create!(name: "Gastón")
      @artist = Artist.create!(name: "Elliott Smith")
      @either = Album.create!(directory: "/music/either", title: "Either/Or", artist: @artist)
      @bars = song(@either, "Between the Bars")
      @angeles = song(@either, "Angeles")
      @gaston.scrobbles_to(username: "ekvintroj", session_key: "s3ss10nk3y")
    end

    test "a history Last.fm kept becomes a history this library has" do
      @lastfm.keeping(history: [ scrobble("Between the Bars", at: 2.years.ago),
                                 scrobble("Angeles", at: 1.year.ago) ])

      bring_it_home

      assert_equal 2, @gaston.plays.count
      assert_equal 1, @gaston.times_played(@angeles)
      assert_in_delta 2.years.ago, @gaston.plays.order(:played_at).first.played_at, 1.second
    end

    # Last.fm pages a history, and it pages ours 200 at a time. An importer that
    # read the first page and stopped would look like it worked.
    test "the whole history comes home, not the first page of it" do
      @lastfm.keeping(history: 5.times.map { scrobble("Between the Bars", at: it.days.ago) })

      bring_it_home

      assert_equal 5, @gaston.times_played(@bars)
    end

    # The whole of a life, and not only the part of it this house owns a copy of.
    # An import that kept the songs it could match and dropped the rest would drop
    # most of a hundred thousand scrobbles — and a history of only what is on your
    # disk is a history of the wrong life. What is not here is a gap, and a gap is
    # a thing that can be listened to.
    test "a song Last.fm knows and this house does not have is still something you listened to" do
      @lastfm.keeping(history: [ scrobble("Between the Bars", at: 1.day.ago),
                                 { artist: "Some Band", track: "A Song We Do Not Own", at: 1.day.ago } ])

      bring_it_home

      assert_equal 2, @gaston.plays.count
      assert_equal [ "A Song We Do Not Own", "Between the Bars" ], @gaston.plays.map(&:title).sort
      assert_equal 1, @gaston.plays.of_ours.count
      assert_equal 1, @gaston.scrobbler.strangers
    end

    # And none of it is told back to Last.fm, which is where it came from.
    test "nothing Last.fm handed over is listening this app did" do
      @lastfm.keeping(history: [ scrobble("Between the Bars", at: 1.day.ago) ])

      bring_it_home

      assert_predicate @gaston.plays.heard_here, :empty?
    end

    # Case is nothing and accents are nothing: being right about "Café Tacvba"
    # matters more than being clever about anything else.
    test "a song is the same song in another case, and with its accents knocked off" do
      tacvba = Artist.create!(name: "Café Tacvba")
      re = Album.create!(directory: "/music/re", title: "Re", artist: tacvba)
      ingrata = song(re, "La Ingrata")

      @lastfm.keeping(history: [ { artist: "cafe tacuba", track: "la ingrata", at: 1.day.ago },
                                 { artist: "CAFÉ TACVBA", track: "La Ingrata", at: 2.days.ago } ])

      bring_it_home

      assert_equal 1, @gaston.times_played(ingrata), "'cafe tacuba' is a different band's spelling; only the accented one is ours"
      assert_equal 1, @gaston.scrobbler.strangers
      assert_equal 2, @gaston.plays.count, "and the other one is still something you listened to"
    end

    # A duet is scrobbled under whoever sang it, not under whoever owns the record.
    test "a song credited on the file to a guest is found under the guest" do
      guest = Track.create!(title: "A Duet", artist: "Elliott Smith & Somebody", duration: 200.0,
                            path: "/music/either/duet.flac", album: @either)

      @lastfm.keeping(history: [ { artist: "Elliott Smith & Somebody", track: "A Duet", at: 1.day.ago } ])

      bring_it_home

      assert_equal 1, @gaston.times_played(guest)
    end

    test "the hearts given over there are given here" do
      @lastfm.keeping(hearts: [ { artist: "Elliott Smith", track: "Angeles" } ])

      bring_it_home

      assert @gaston.reload.likes?(@angeles)
      assert_equal 1, @gaston.scrobbler.imported_hearts
    end

    # The whole point of the guard. These plays came *from* Last.fm — sending them
    # back would hand it a hundred thousand songs it told us about itself.
    test "nothing that came from Last.fm is sent back to Last.fm" do
      @lastfm.keeping(history: [ scrobble("Between the Bars", at: 2.years.ago) ],
                      hearts: [ { artist: "Elliott Smith", track: "Angeles" } ])

      bring_it_home

      assert_predicate Scrobble.all, :empty?
      assert_predicate Love.all, :empty?
    end

    # Last.fm will hand over the same hundred thousand scrobbles it handed over
    # last time. Running it twice is not listening to everything twice.
    test "importing again does not play everything a second time" do
      @lastfm.keeping(history: [ scrobble("Between the Bars", at: 2.years.ago) ])

      2.times { bring_it_home }

      assert_equal 1, @gaston.plays.count
    end

    # An import brings a decade of listening home, out of order and all at once —
    # so the turns of every record are counted again, from the top.
    test "a record you wore out a decade ago says so once its history is home" do
      @lastfm.keeping(history: [ scrobble("Between the Bars", at: 3.years.ago),
                                 scrobble("Angeles", at: 3.years.ago + 3.minutes) ])

      bring_it_home

      assert_equal 1, @gaston.spins_of(@either)
    end

    private

    def bring_it_home
      Import.new(@gaston, pause: 0).bring_it_all_home
      @gaston.reload
    end

    def scrobble(title, at:)
      { artist: "Elliott Smith", track: title, at: }
    end

    def song(album, title)
      Track.create!(title:, duration: 200.0, path: "#{album.directory}/#{title}.flac", album:)
    end
  end
end
