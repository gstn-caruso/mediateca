require "application_system_test_case"

# Hiding somebody is done from the library, where you are looking at them, and
# taken back from their own page, which is the one place they still have.
class HidingAnArtistTest < ApplicationSystemTestCase
  setup do
    @gaston = listening_as
    @almafuerte = Artist.create!(name: "Almafuerte")
    Album.create!(directory: "/music/guanaco", title: "Mundo Guanaco", year: 1995, artist: @almafuerte)
  end

  test "an artist is hidden from the library, and shown again from their own page" do
    visit root_path

    open_the_menu_for "Almafuerte"
    click_on "Hide from the library"

    # The page becomes the page it now is: the face is gone from the wall and
    # gone from the rail, and nothing had to navigate for that to be true.
    assert_no_selector "a[href='#{artist_path(@almafuerte)}']"

    # They are not gone, only unlisted — and this is the way back to them.
    visit artist_path(@almafuerte)
    assert_text "Hidden from your library"

    open_the_menu_for "Almafuerte"
    click_on "Show in the library"

    assert_no_text "Hidden from your library"

    visit root_path
    assert_selector "a[href='#{artist_path(@almafuerte)}']"
  end

  test "an artist is highlighted, and says so" do
    visit artist_path(@almafuerte)

    open_the_menu_for "Almafuerte"
    click_on "Highlight in what's next"

    assert_text "they turn up in what's next more often"

    # A highlighted artist is still an artist: they stay in the library.
    visit root_path
    assert_selector "a[href='#{artist_path(@almafuerte)}']"
  end

  # Standing on an artist is not going anywhere, and the history should not
  # record it as though it were. Back, after hiding somebody, has to leave the
  # library — not walk you back through your own opinions.
  test "taking a stand does not grow the history" do
    visit root_path
    steps = page.evaluate_script("history.length")

    open_the_menu_for "Almafuerte"
    click_on "Hide from the library"
    assert_no_selector "a[href='#{artist_path(@almafuerte)}']"

    assert_equal steps, page.evaluate_script("history.length")
  end

  # This menu drops out of a card that is already a pane of glass, and glass
  # inside glass does not compose: the menu stops seeing the page and blurs the
  # pane it is sitting on, which was blurred and tinted already. It comes out
  # flat and muddy — which is why Apple says not to stack the material, and why
  # every other menu in the app is solid. This one had drifted.
  test "the menu is a menu, not another pane of glass" do
    visit root_path

    open_the_menu_for "Almafuerte"

    assert_equal "none", menu_material,
      "the menu is filtering its backdrop: it is glass stacked on glass"
  end

  private

  def open_the_menu_for(artist)
    find("summary[aria-label='What to do about #{artist}']").click
  end

  # What the browser ended up drawing, not which class we remembered to write.
  def menu_material
    page.evaluate_script("getComputedStyle(document.querySelector('details[open] > div')).backdropFilter")
  end
end
