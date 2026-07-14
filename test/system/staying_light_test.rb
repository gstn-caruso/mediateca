require "application_system_test_case"

# This app has to run on the cheapest Android anybody still has in a pocket, and
# the two things a phone like that cannot afford are the two the app was built
# out of.
#
# A backdrop-filter is not painted once. Every frame, the browser copies out
# everything standing behind the pane, blurs it, and draws the pane over it — and
# there were six panes doing that at all times: the bar, the rail, the queue, the
# words, the picture, the pill. A blurred bitmap is the other one: a cover blown
# up and blurred by the GPU, twice over — once burning under the whole building,
# once behind the title of every page.
#
# On the machine this was designed on, all of it is free. On a phone with no GPU
# to speak of, it is the difference between an app and a slideshow. So the rule
# is a test rather than a line in a stylesheet, and it walks the room with
# everything in it open: nothing here filters what is behind it, and nothing asks
# the GPU to blur a picture.
class StayingLightTest < ApplicationSystemTestCase
  ALBUM_DIR = "Almafuerte/1995 - Mundo guanaco".freeze

  setup do
    listening_as
    artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(
      directory: File.join(Rails.configuration.x.media_root, ALBUM_DIR), title: "Mundo Guanaco", year: 1995,
      album_type: "album", disc_total: 1, artist:, cover_path: media("cover.jpg")
    )
    Track.create!(title: "Desencuentro", track_no: 1, disc_no: 1, duration: 30.0,
                  path: media("01 - Desencuentro.flac"), album: @album)
  end

  test "no pane in the app filters what is behind it" do
    the_whole_room

    assert_empty panes_filtering_their_backdrop,
      "these panes are re-blurring everything behind them, every frame, on a phone that cannot"
  end

  test "nothing asks the GPU to blur a picture" do
    the_whole_room

    assert_empty things_blurring_a_bitmap,
      "these are being blurred by the GPU: a cheap phone draws them once and stutters doing it"
  end

  private

  # Everything the app has, standing at once: a record open, its song playing, the
  # pill up, and both rails out.
  def the_whole_room
    visit album_path(@album)
    find("button[data-player-track]", text: "Desencuentro").click
    assert_selector "[data-player-target='title']", text: "Desencuentro"

    open_the "Lyrics"
    open_the "Playing Next"
    assert_selector "#queue-panel.is-open"
  end

  def panes_filtering_their_backdrop
    offenders("style.backdropFilter !== 'none'")
  end

  def things_blurring_a_bitmap
    offenders("style.filter !== 'none' && style.filter.includes('blur')")
  end

  # Named the way somebody reading a failure would want them named: what the
  # element is, not where it sits in a tree.
  def offenders(condition)
    page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll("*")).filter((element) => {
        const style = getComputedStyle(element)
        return #{condition}
      }).map((element) => {
        const name = element.tagName.toLowerCase()
        const id = element.id ? `#${element.id}` : ""
        const classes = (element.getAttribute("class") || "").trim().split(/\\s+/).filter(Boolean)
        return name + id + classes.map((one) => `.${one}`).join("")
      })
    JS
  end

  def media(name)
    File.join(Rails.configuration.x.media_root, ALBUM_DIR, name)
  end
end
