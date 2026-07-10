require "test_helper"

class TracksHelperTest < ActionView::TestCase
  test "una duración se muestra en minutos y segundos" do
    assert_equal "2:17", track_duration(136.9)
  end

  test "los segundos van con dos dígitos" do
    assert_equal "3:05", track_duration(185.0)
  end

  test "una duración de más de una hora sigue contándose en minutos" do
    assert_equal "74:30", track_duration(4470.0)
  end

  # beets deja length en NULL para algún archivo suelto.
  test "una duración desconocida se muestra como guiones" do
    assert_equal "–:––", track_duration(nil)
  end

  # La duración de un disco entero se lee distinto que la de un tema: nadie
  # dice que un álbum dura 111 minutos.
  test "un álbum de más de una hora se mide en horas y minutos" do
    assert_equal "1 h 51 min", album_length(6660)
  end

  test "un álbum de menos de una hora se mide en minutos" do
    assert_equal "40 min", album_length(2400)
  end

  test "un álbum de exactamente dos horas no muestra minutos de más" do
    assert_equal "2 h", album_length(7200)
  end

  test "un álbum sin duraciones conocidas no dice cuánto dura" do
    assert_nil album_length(0)
    assert_nil album_length(nil)
  end
end
