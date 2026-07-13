require "test_helper"

# A page is dressed in the colour of whatever it is about: its own picture blown
# up behind its own name, and its own colour on everything printed over it — down
# to the button that puts it on, which is a button about this record and had no
# business being painted in another one.
#
# The page, and not a pixel further. The building around it — the rail, the bar,
# the pill, the cover burning on the floor — belongs to the record that is
# PLAYING and goes on belonging to it while you browse. So the colour is written
# onto the page itself, and nowhere higher up.
class DressingThePageYouOpenedTest < ActionDispatch::IntegrationTest
  include Sleeves

  # Figure 8: black, white and one red. Black and white have no colour to give, so
  # the red is the only thing on the sleeve that can dress the page.
  setup do
    listening_as
    @artist = Artist.create!(name: "Elliott Smith")
    @album = Album.create!(directory: "/music/figure-8", title: "Figure 8", year: 2000, artist: @artist,
                           cover_path: sleeve("#101010" => 0.5, "#f5f5f5" => 0.25, "#c8102e" => 0.25))
  end

  test "a record is headed by its own sleeve" do
    get album_path(@album)

    assert_select %(header .hero-wash img[src^="#{album_cover_path(@album)}"]), { count: 1 },
      "the sleeve is not standing behind the record it belongs to"
  end

  test "a record dresses its page in its own colour, not the one the app is wearing" do
    Music::Colours.new.collect

    get album_path(@album)

    assert_includes page_style, "--color-accent: #{@album.reload.palette.accent}"
    assert_not_equal Palette::STANDING, @album.palette.accent,
      "the sleeve's red never made it out of the sleeve"
  end

  # The one control that is unambiguously about this record and nothing else. It
  # was painted in whatever happened to be playing, which is the one record it is
  # certainly not about.
  test "the button that puts a record on is painted in that record" do
    Music::Colours.new.collect

    get album_path(@album)

    assert_select %(main[style*="--color-accent: #{@album.reload.palette.accent}"] button[aria-label=?]),
      "Play Figure 8"
  end

  test "an artist is headed by their photograph, in the colour they were photographed in" do
    @artist.update!(portrait_path: photograph("#1e6ad4" => 1.0))
    Music::Colours.new.collect

    get artist_path(@artist)

    assert_select %(header .hero-wash img[src^="#{artist_portrait_path(@artist)}"])
    assert_includes page_style, "--color-accent: #{@artist.reload.palette.accent}"
  end

  # A record nobody scanned and an artist nobody photographed have no picture to
  # blow up and no colour of their own. Neither is given somebody else's.
  test "a page with no picture is headed by no picture" do
    @album.update!(cover_path: nil)

    get album_path(@album)

    assert_select "header .hero-wash", count: 0
    assert_includes page_style, "--color-accent: #{Palette.standing.accent}"
  end

  private

  # On the page, not on <html>: what the player paints when you press something is
  # the whole building's business, and this is only the page's.
  def page_style
    css_select("main").first["style"].to_s
  end
end
