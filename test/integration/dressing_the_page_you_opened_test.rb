require "test_helper"

# The head of a page is the thing the page is about: its own picture blown up
# behind its own name, in its own colour.
#
# Which is a different question from the one the rest of the app answers. Down
# there, everything is painted in the record that is PLAYING — the floor it burns
# on, the Play button, the line you are hearing. Opening a record does not touch
# any of that: it dresses its own header and stops there. So the colour has to be
# written onto the header itself, and nowhere higher up.
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

  test "a record heads its page in its own colour, not the one the app is wearing" do
    Music::Colours.new.collect

    get album_path(@album)

    assert_includes header_style, "--color-accent: #{@album.reload.palette.accent}"
    assert_not_equal Palette::STANDING, @album.palette.accent,
      "the sleeve's red never made it out of the sleeve"
  end

  test "an artist is headed by their photograph, in the colour they were photographed in" do
    @artist.update!(portrait_path: photograph("#1e6ad4" => 1.0))
    Music::Colours.new.collect

    get artist_path(@artist)

    assert_select %(header .hero-wash img[src^="#{artist_portrait_path(@artist)}"])
    assert_includes header_style, "--color-accent: #{@artist.reload.palette.accent}"
  end

  # A record nobody scanned and an artist nobody photographed have no picture to
  # blow up and no colour of their own. Neither is given somebody else's.
  test "a page with no picture is headed by no picture" do
    @album.update!(cover_path: nil)

    get album_path(@album)

    assert_select "header .hero-wash", count: 0
    assert_includes header_style, "--color-accent: #{Palette.standing.accent}"
  end

  private

  def header_style
    css_select("main header").first["style"].to_s
  end
end
