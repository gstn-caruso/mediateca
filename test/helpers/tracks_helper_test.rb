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
end
