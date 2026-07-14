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

  # Nothing in this app filters what is behind it any more — a pane that re-blurs
  # the whole room, every frame, is the one thing a cheap phone cannot afford, and
  # StayingLightTest walks the room saying so. It cannot walk into a menu, though:
  # a menu that is shut is not on the page. So this is the same rule, standing at
  # the one door that test cannot open.
  test "the menu does not filter what is behind it either" do
    visit root_path

    open_the_menu_for "Almafuerte"

    assert_equal "none", menu_material,
      "the menu is re-blurring everything behind it, every frame, on a phone that cannot"
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
