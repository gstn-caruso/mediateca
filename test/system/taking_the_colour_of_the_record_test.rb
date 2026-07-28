require "application_system_test_case"

# Put a record on and the whole app takes its colour: the Play button, the
# playing row, the equalizer, the light in the corners of the room. So the colour
# it takes had better be the record's, and not one we made up on the way out.
class TakingTheColourOfTheRecordTest < ApplicationSystemTestCase
  ALBUM_DIR = "Elliott Smith/2000 - Figure 8".freeze

  # The sleeve is black, white and one red — like the real Figure 8. Black and
  # white sit the vote out (no saturation to speak of), so that red is the only
  # colour on the record that can become the accent.
  SLEEVE_RED = 350 # degrees: rgb(200, 16, 46)

  setup do
    listening_as
    artist = Artist.create!(name: "Elliott Smith")
    @album = Album.create!(
      directory: File.join(Rails.configuration.x.media_root, ALBUM_DIR), title: "Figure 8", year: 2000,
      album_type: "album", disc_total: 1, artist:, cover_path: media("cover.png")
    )
    Track.create!(title: "Son of Sam", track_no: 1, disc_no: 1, duration: 186.0,
                  path: media("01 - Son of Sam.flac"), album: @album)

    # The colour is read off the sleeve on the server, the way it is after every
    # scan of the library. Nothing in the browser opens the cover.
    Music::Colours.new.collect
  end

  # It used to come back at 14° — orange — because the hue was warmed toward
  # orange on its way to the accent, which made the app lie about the sleeve.
  test "a black, white and red record paints the app its own red" do
    play "Son of Sam"

    assert_operator hue_gap(accent_hue, SLEEVE_RED), :<=, 12,
      "the accent came back #{accent} (hue #{accent_hue.round}°): that is not the red on the sleeve"
    take_screenshot
  end

  # The whole point of deciding the colour on the server: the app knows what it
  # will wear before the cover has arrived, so nothing has to be re-painted once
  # the image lands, and a cover that never loads is not a record without a
  # colour.
  test "the app is already wearing the record's colour before its cover loads" do
    visit album_path(@album)
    page.execute_script("document.querySelectorAll('img').forEach((img) => img.src = '/nowhere.png')")

    find("button[data-player-track]", text: "Son of Sam").click

    assert_operator hue_gap(accent_hue, SLEEVE_RED), :<=, 12,
      "with no cover to look at, the app fell back to a colour that is not the record's"
  end

  private

  def play(title)
    visit album_path(@album)
    find("button[data-player-track]", text: title).click
    assert_selector "[data-player-target='title']", text: title
  end

  # The accent is written onto <html> itself, so it is painted the moment it is
  # there. Reading the inline property rather than the computed one keeps this
  # off the half-second transition, which would otherwise be caught mid-ease and
  # report a colour that is on the way to the answer rather than the answer.
  def accent
    @accent ||= begin
      deadline = Time.now + Capybara.default_max_wait_time
      painted = nil
      while painted.blank? && Time.now < deadline
        painted = page.evaluate_script("document.documentElement.style.getPropertyValue('--color-accent')")
        sleep 0.05 if painted.blank?
      end
      painted.presence or flunk "the record never painted its colour onto the app"
    end
  end

  def accent_hue
    r, g, b = accent.delete_prefix("#").scan(/../).map { |pair| pair.to_i(16) / 255.0 }
    high, low = [ r, g, b ].max, [ r, g, b ].min
    return 0 if high == low

    span = high - low
    degrees = case high
    when r then (g - b) / span + (g < b ? 6 : 0)
    when g then (b - r) / span + 2
    else (r - g) / span + 4
    end
    degrees * 60
  end

  # Hues live on a circle, where 350° and 2° are neighbours: the gap between two
  # of them is the shorter way round, never the long way through the greens.
  def hue_gap(one, other)
    ((one - other + 540) % 360 - 180).abs
  end

  def media(name)
    File.join(Rails.configuration.x.media_root, ALBUM_DIR, name)
  end
end
