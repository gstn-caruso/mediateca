require "test_helper"

class BrowsingMusicTest < ActionDispatch::IntegrationTest
  ALBUM_DIR = "Almafuerte/1995 - Mundo guanaco".freeze

  setup do
    @artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(
      beets_id: 1, title: "Mundo Guanaco", year: 1995, genre: "", album_type: "album",
      disc_total: 1, artist: @artist, cover_path: media("cover.jpg")
    )
    @track = Track.create!(
      beets_id: 1, title: "Desencuentro", track_no: 2, disc_no: 1, duration: 136.9,
      path: media("01 - Desencuentro.flac"), album: @album
    )
  end

  test "la portada lista los artistas" do
    get root_path

    assert_response :success
    assert_match "Almafuerte", response.body
  end

  test "un artista muestra sus álbumes" do
    get artist_path(@artist)

    assert_response :success
    assert_match "Mundo Guanaco", response.body
  end

  test "un álbum muestra sus tracks" do
    Track.create!(beets_id: 2, title: "Dijo El Droguero", track_no: 1, disc_no: 1, path: media("otro.flac"), album: @album)

    get album_path(@album)

    assert_response :success
    assert_operator response.body.index("Dijo El Droguero"), :<, response.body.index("Desencuentro"),
      "los tracks tienen que salir en orden de reproducción, no de creación"
  end

  test "la carátula de un álbum se sirve como imagen" do
    get cover_album_path(@album)

    assert_response :success
    assert_equal "image/jpeg", response.media_type
  end

  # 3 de los 75 álbumes del NAS apuntan a carátulas que ya no están en disco.
  test "una carátula que ya no está en disco da 404" do
    @album.update!(cover_path: media("no-existe.jpg"))

    get cover_album_path(@album)

    assert_response :not_found
  end

  test "un álbum sin carátula da 404" do
    @album.update!(cover_path: nil)

    get cover_album_path(@album)

    assert_response :not_found
  end

  test "un track se sirve como audio" do
    get stream_track_path(@track)

    assert_response :success
    assert_equal "audio/flac", response.media_type
  end

  # Sin Range no hay seek: arrastrar la barra del reproductor se vuelve
  # imposible y el browser tiene que bajar el FLAC entero para empezar.
  # (Rack 3 normaliza los headers a minúscula.)
  test "un track responde a un Range request con contenido parcial" do
    get stream_track_path(@track), headers: { "Range" => "bytes=0-9" }

    assert_response :partial_content
    assert_equal "bytes 0-9/50", response.headers["content-range"]
    assert_equal 10, response.body.bytesize
  end

  test "un track anuncia que acepta rangos, así el reproductor ofrece seek" do
    get stream_track_path(@track)

    assert_response :success
    assert_equal "bytes", response.headers["accept-ranges"]
  end

  test "un track cuyo archivo ya no está en disco da 404" do
    @track.update!(path: media("borrado.flac"))

    get stream_track_path(@track)

    assert_response :not_found
  end

  test "un track cuyo path se escapa de la raíz de medios da 403" do
    @track.update_column(:path, "/etc/passwd")

    get stream_track_path(@track)

    assert_response :forbidden
  end

  private

  def media(name)
    File.join(Rails.configuration.x.media_root, ALBUM_DIR, name)
  end
end
