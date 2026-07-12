require "application_system_test_case"

class BrowsingTheLibraryTest < ApplicationSystemTestCase
  ALBUM_DIR = "Almafuerte/1995 - Mundo guanaco".freeze

  setup do
    profile = listening_as
    profile.playlists.create!(name: "Road trip")
    @artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(
      directory: File.join(Rails.configuration.x.media_root, ALBUM_DIR), title: "Mundo Guanaco",
      year: 1995, disc_total: 1, artist: @artist, cover_path: media("cover.jpg")
    )
  end

  test "the rail turns from the artists to the records, and back" do
    visit root_path

    within "nav" do
      assert_selector "a[href='#{artist_path(@artist)}']"
      assert_no_selector "a[href='#{album_path(@album)}']"

      click_on "Albums"

      assert_selector "a[href='#{album_path(@album)}']"
      assert_no_selector "a[href='#{artist_path(@artist)}']"

      click_on "Artists"

      assert_selector "a[href='#{artist_path(@artist)}']"
    end
  end

  test "the lists and the hearts are a turn of their own" do
    visit root_path

    within "nav" do
      click_on "Playlists"

      assert_text "Road trip"
      assert_text "Liked Songs"
      assert_no_selector "a[href='#{artist_path(@artist)}']"
    end
  end

  # The rail is re-rendered on every visit, so the turn it was left on cannot
  # ride along in the DOM the way the music does — it is written down and read
  # back, the same way the rail remembers being folded shut.
  test "the rail comes back on the turn it was left on" do
    visit root_path
    within("nav") { click_on "Albums" }

    visit likes_path

    within("nav") { assert_selector "a[href='#{album_path(@album)}']" }
  end

  test "the page turns to the records too" do
    visit root_path

    within "main" do
      click_on "Albums"

      assert_selector "a[href='#{album_path(@album)}']"
      assert_no_selector "a[href='#{artist_path(@artist)}']"
    end
  end

  private

  def media(name)
    File.join(Rails.configuration.x.media_root, ALBUM_DIR, name)
  end
end
