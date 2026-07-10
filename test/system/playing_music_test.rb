require "application_system_test_case"

class PlayingMusicTest < ApplicationSystemTestCase
  ALBUM_DIR = "Almafuerte/1995 - Mundo guanaco".freeze

  setup do
    artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(
      directory: File.join(Rails.configuration.x.media_root, ALBUM_DIR), title: "Mundo Guanaco", year: 1995,
      genre: "heavy metal", album_type: "album", disc_total: 1, artist:, cover_path: media("cover.jpg")
    )
    {
      "Dijo El Droguero Al Drogador" => "02 - Dijo el droguero al drogador.flac",
      "Desencuentro" => "01 - Desencuentro.flac",
      "El Pibe Tigre" => "03 - El pibe tigre.flac"
    }.each_with_index do |(title, file), index|
      Track.create!(title:, track_no: index + 1, disc_no: 1, duration: 137.0 + index, path: media(file), album: @album)
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
    play "Desencuentro"

    click_link "Mediateca"

    assert_text "Tu biblioteca"
    assert_selector "[data-player-target='title']", text: "Desencuentro"
    assert page.evaluate_script("document.querySelector('audio').currentSrc.length > 0"),
      "el <audio> perdió su fuente al navegar"
  end

  test "el track que suena queda marcado en la lista" do
    play "Desencuentro"

    assert_selector "[data-player-track][aria-current='true']", text: "Desencuentro"
    assert_selector "[data-player-track][aria-current='true']", count: 1
  end

  # Hacer click en un track encola el álbum entero: lo que sigue tiene que
  # poder verse, no solo intuirse.
  test "la cola muestra lo que sigue" do
    play "Dijo El Droguero Al Drogador"

    click_button "Ver la cola"

    within "[data-player-target='queue']" do
      assert_text "Desencuentro"
      assert_text "El Pibe Tigre"
      # Lo que ya sonó no es lo que sigue.
      assert_no_text "Dijo El Droguero Al Drogador"
    end
    take_screenshot
  end

  test "desde la cola se salta a cualquier track" do
    play "Dijo El Droguero Al Drogador"
    click_button "Ver la cola"

    within("[data-player-target='queue']") { click_button "El Pibe Tigre" }

    assert_selector "[data-player-target='title']", text: "El Pibe Tigre"
  end

  test "el siguiente reproduce el track siguiente del álbum" do
    play "Dijo El Droguero Al Drogador"

    click_button "Siguiente"

    assert_selector "[data-player-target='title']", text: "Desencuentro"
  end

  # Con la cola dada vuelta, el último track no es el final de nada.
  test "con repetición, el último track vuelve al primero" do
    play "El Pibe Tigre"
    click_button "Repetir"

    click_button "Siguiente"

    assert_selector "[data-player-target='title']", text: "Dijo El Droguero Al Drogador"
  end

  test "sin repetición, el último track es el último" do
    play "El Pibe Tigre"

    click_button "Siguiente"

    assert_selector "[data-player-target='title']", text: "El Pibe Tigre"
  end

  test "con aleatorio, lo que sigue deja de ser el orden del disco" do
    play "Dijo El Droguero Al Drogador"

    click_button "Aleatorio"

    assert_selector "[data-player-target='shuffle'][aria-pressed='true']"
  end

  # Después de navegar por media biblioteca, volver a lo que suena.
  test "desde el player se vuelve al álbum que está sonando" do
    play "Desencuentro"
    click_link "Mediateca"
    assert_text "Tu biblioteca"

    click_link "Desencuentro"

    assert_text "Mundo Guanaco"
    assert_selector "[data-player-track][aria-current='true']", text: "Desencuentro"
  end

  private

  def play(title)
    visit album_path(@album)
    find("button[data-player-track]", text: title).click
    assert_selector "[data-player-target='title']", text: title
  end

  def media(name)
    File.join(Rails.configuration.x.media_root, ALBUM_DIR, name)
  end
end
