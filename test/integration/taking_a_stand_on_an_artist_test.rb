require "test_helper"

# Hiding somebody and highlighting them are the same gesture pointed two ways,
# and they are taken back the same way they were given.
class TakingAStandOnAnArtistTest < ActionDispatch::IntegrationTest
  setup do
    @gaston = listening_as
    @almafuerte = Artist.create!(name: "Almafuerte")
  end

  test "an artist can be hidden, and shown again" do
    post artist_standing_path(@almafuerte, standing: :hidden)
    assert @gaston.reload.hides?(@almafuerte)

    delete artist_standing_path(@almafuerte, standing: :hidden)
    refute @gaston.reload.hides?(@almafuerte)
  end

  test "an artist can be highlighted, and let go again" do
    post artist_standing_path(@almafuerte, standing: :highlighted)
    assert @gaston.reload.highlights?(@almafuerte)

    delete artist_standing_path(@almafuerte, standing: :highlighted)
    refute @gaston.reload.highlights?(@almafuerte)
  end

  # Hiding somebody changes the page in more places than the button pressed: they
  # leave the rail, they leave the shelf of records, they leave what you recently
  # played. So the answer is the page you were on, all of it — which Turbo reads
  # as a refresh, and refreshes here are morphs.
  test "taking a stand answers with the page you were standing on" do
    post artist_standing_path(@almafuerte, standing: :hidden),
         headers: { "HTTP_REFERER" => root_url }

    assert_redirected_to root_url
    assert_response :see_other
  end

  # There is no third standing, and no route to one.
  test "an artist cannot be stood on in a way that is not a standing" do
    post artist_standing_path(@almafuerte, standing: :adored)

    assert_response :bad_request
    assert_equal 0, @gaston.standings.count
  end

  # A standing is one listener's. Without a cookie there is nobody to hold it.
  test "nobody listening stands on nobody" do
    delete session_path

    post artist_standing_path(@almafuerte, standing: :hidden)

    assert_redirected_to profiles_path
    assert_equal 0, @gaston.standings.count
  end
end
