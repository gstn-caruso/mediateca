require "application_system_test_case"

class PlayingMusicTest < ApplicationSystemTestCase
  ALBUM_DIR = "Almafuerte/1995 - Mundo guanaco".freeze

  setup do
    artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(
      beets_id: 1, title: "Mundo Guanaco", year: 1995, genre: "heavy metal",
      album_type: "album", disc_total: 1, artist:, cover_path: media("cover.jpg")
    )
    {
      "Dijo El Droguero Al Drogador" => "02 - Dijo el droguero al drogador.flac",
      "Desencuentro" => "01 - Desencuentro.flac",
      "El Pibe Tigre" => "03 - El pibe tigre.flac"
    }.each_with_index do |(title, file), index|
      Track.create!(
        beets_id: index + 1, title:, track_no: index + 1, disc_no: 1, duration: 137.0 + index,
        path: media(file), album: @album
      )
    end
  end

  test "la biblioteca muestra los artistas" do
    visit root_path

    assert_text "Tu biblioteca"
    assert_text "Almafuerte"
    take_screenshot
  end

  test "un álbum muestra sus tracks y se puede reproducir" do
    visit album_path(@album)

    assert_text "Mundo Guanaco"
    assert_text "Dijo El Droguero Al Drogador"
    assert_text "2:17"
    take_screenshot
  end

  # El player vive fuera del body que Turbo Drive reemplaza. Si la música se
  # cortara al navegar, esto lo detecta.
  test "la música sigue sonando al navegar a otra página" do
    visit album_path(@album)

    find("button[data-player-track]", text: "Desencuentro").click
    assert_selector "[data-player-target='title']", text: "Desencuentro"

    click_link "Mediateca"

    assert_text "Tu biblioteca"
    assert_selector "[data-player-target='title']", text: "Desencuentro"
    assert page.evaluate_script("document.querySelector('audio').currentSrc.length > 0"),
      "el <audio> perdió su fuente al navegar"
  end

  private

  def media(name)
    File.join(Rails.configuration.x.media_root, ALBUM_DIR, name)
  end
end
