require "application_system_test_case"

# The report. Not "you played 127,231 songs" — every service says that. The one
# fact only a library can hand you is the other one: how much of what you love it
# hasn't got.
class TheReportTest < ApplicationSystemTestCase
  ALBUM_DIR = "Almafuerte/1995 - Mundo guanaco".freeze

  setup do
    @gaston = listening_as
    artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(
      directory: File.join(Rails.configuration.x.media_root, ALBUM_DIR), title: "Mundo Guanaco", year: 1995,
      album_type: "album", disc_total: 1, artist:, cover_path: media("cover.jpg")
    )
    @song = Track.create!(title: "Desencuentro", track_no: 1, disc_no: 1, duration: 137.0,
                          path: media("01 - Desencuentro.flac"), album: @album)

    36.times { |at| @gaston.played(@song, at: (at + 1).hours.ago) }
    36.times { |at| @gaston.heard_elsewhere(track: @song, at: 3.years.ago + at.days, from: "lastfm") }

    { "Pappo" => 240, "Fito Páez" => 190, "La Renga" => 155, "Bunbury" => 120,
      "Spinetta" => 96, "Los Redondos" => 71, "Cerati" => 48, "Miranda" => 30 }.each do |who, times|
      heard(who, times:)
    end
  end

  test "the report leads with what this disk hasn't got" do
    visit report_path

    assert_selector "h1", text: /aren't on this disk/
    assert_text "Your years"
    assert_text "Your hours"
    assert_text "Who you listen to"
    assert_text "What isn't here yet"
    take_screenshot

    scroll_to(find("h2", text: "Your years")); take_screenshot
    scroll_to(find("h2", text: "Who you listen to")); take_screenshot
    scroll_to(find("h2", text: "What isn't here yet")); take_screenshot
  end

  test "the three lists it is owed can be made" do
    visit report_path
    scroll_to(find("h2", text: "Three lists you're owed"))
    take_screenshot

    click_button "Make them"

    assert_text "Made"
    in_the_library("Playlists") do
      assert_link "Not on the disk"
      assert_link "On repeat"
    end
  end

  private

  def heard(who, times:)
    times.times do |at|
      gap = @gaston.misses(artist: who, title: "Song #{at % 12}")
      @gaston.heard_elsewhere(absence: gap, at: (at + 1).hours.ago - (at % 5).years, from: "lastfm")
    end
  end

  def media(name)
    File.join(Rails.configuration.x.media_root, ALBUM_DIR, name)
  end
end
