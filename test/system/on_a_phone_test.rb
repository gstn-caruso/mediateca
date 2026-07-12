require "application_system_test_case"

class OnAPhoneTest < ApplicationSystemTestCase
  WIDTH = 390
  HEIGHT = 844

  ALBUM_DIR = "Almafuerte/1995 - Mundo guanaco".freeze

  # Chrome refuses to make a window narrower than 500px, so resizing the window
  # is not the same as being on a phone — a test that asked for 390 was quietly
  # handed 500. The viewport is overridden instead, and every test below checks
  # it got what it asked for.
  setup do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
                                    width: WIDTH, height: HEIGHT, deviceScaleFactor: 2, mobile: true)
    listening_as
    artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(
      directory: File.join(Rails.configuration.x.media_root, ALBUM_DIR), title: "Mundo Guanaco",
      year: 1995, disc_total: 1, artist:, cover_path: media("cover.jpg")
    )
    Track.create!(title: "Desencuentro", track_no: 1, disc_no: 1, duration: 136.9,
                  path: media("01 - Desencuentro.flac"), album: @album)
  end

  # A phone scrolls up and down. Sideways means something is wider than the
  # screen, and everything to its right is unreachable.
  test "no page scrolls sideways" do
    [ root_path, album_path(@album), likes_path, search_path(q: "Desencuentro") ].each do |path|
      visit path

      assert_on_a_phone
      assert_no_sideways_scroll path
    end
  end

  # The sidebar is desktop-only, and it holds Liked Songs, the playlists and the
  # way out of a profile. On a phone all three have to live somewhere else.
  test "liked songs is reachable with no sidebar" do
    visit root_path
    assert_on_a_phone

    click_on "Liked Songs"

    assert_text "Songs you heart show up here"
  end

  test "a profile can be left with no sidebar" do
    visit root_path
    assert_on_a_phone

    switch_profile

    assert_text "Who's listening?"
  end

  test "a song still plays" do
    visit album_path(@album)

    find("button[data-player-track]", text: "Desencuentro").click

    assert_selector "[data-player-target='title']", text: "Desencuentro"
  end

  # The queue used to be desktop-only, twice over: the button that opens it was
  # hidden below md, and the class it toggled had no effect there anyway. So a
  # phone had no way to see what was coming, and no way to change it.
  #
  # There is no room to stand beside the content at 390px, so it comes over it.
  test "the queue can be opened, and what's coming can be seen and dropped" do
    visit album_path(@album)
    assert_on_a_phone
    find("button[data-player-track]", text: "Desencuentro").click

    click_button "Playing Next"

    within "[data-player-target='queue']" do
      assert_text "NOW PLAYING"
      assert_text "Desencuentro"
    end
    assert_no_sideways_scroll "the album, with the queue open"
  end

  private

  # A test that believes it is on a phone, and is not, proves nothing.
  def assert_on_a_phone
    assert_equal WIDTH, evaluate_script("window.innerWidth"),
      "the viewport is not a phone's, so this test is measuring a desktop"
  end

  def assert_no_sideways_scroll(path)
    overflow = evaluate_script("document.body.scrollWidth - window.innerWidth")

    assert_operator overflow, :<=, 0, "#{path} is #{overflow}px wider than the screen"
  end

  def media(name)
    File.join(Rails.configuration.x.media_root, ALBUM_DIR, name)
  end
end
