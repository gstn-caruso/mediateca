require "application_system_test_case"

# The chrome takes what it needs and the content gets the rest, so how much room
# a page actually has is not a function of the window: open the library rail on a
# tablet and the column left for the record is a fraction of the screen. Anything
# sized off the viewport is sized off the wrong number.
class FittingTheColumnTest < ApplicationSystemTestCase
  TABLET = [ 834, 1112 ].freeze

  ALBUM_DIR = "Indio Solari/2010 - El perfume de la tempestad".freeze

  # Long enough that it cannot fit on one line in a narrow column — which is
  # fine. Being cut in half is not.
  LONG_TITLE = "El perfume de la tempestad".freeze

  setup do
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
                                    width: TABLET.first, height: TABLET.last,
                                    deviceScaleFactor: 1, mobile: false)
    listening_as
    artist = Artist.create!(name: "Indio Solari")
    @album = Album.create!(
      directory: File.join(Rails.configuration.x.media_root, ALBUM_DIR),
      title: LONG_TITLE, year: 2010, disc_total: 1, artist:, cover_path: media("cover.jpg")
    )
    Track.create!(title: "Todos a los botes", track_no: 1, disc_no: 1, duration: 286.0,
                  path: media("01 - Todos a los botes.flac"), album: @album)
  end

  teardown do
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  # The record's name is the one thing the page is about. It may wrap onto as many
  # lines as it likes; what it may not do is run past its column and lose its own
  # ending, which is what a viewport-sized headline does the moment the rail is
  # open beside it.
  test "an album's title is never cut off" do
    visit album_path(@album)
    assert_selector "h1", text: LONG_TITLE

    overflow = page.evaluate_script(<<~JS)
      (() => {
        const h1 = document.querySelector('h1');
        return { scroll: h1.scrollWidth, client: h1.clientWidth };
      })()
    JS

    assert_operator overflow["scroll"], :<=, overflow["client"] + 1,
                    "the title needs #{overflow['scroll']}px and has #{overflow['client']}px: it is cut off"
  end

  def media(name)
    File.join(Rails.configuration.x.media_root, ALBUM_DIR, name)
  end
end
