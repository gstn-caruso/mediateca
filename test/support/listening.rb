# There is no login. "Signed in" only ever means somebody was picked off the
# grid, so every test that browses the library has to pick somebody first.
module ListeningOverHttp
  def listening_as(name = "Gastón")
    Profile.create!(name:).tap do |profile|
      post session_path, params: { profile_id: profile.id }
    end
  end
end

module ListeningInABrowser
  # Picking a name is a navigation, and nothing was waiting for it to land. The
  # test moved on, the cookie was not yet set, and the next `visit` bounced back
  # to the picker — where there is no search box, no library and no player, so
  # whatever the test reached for was simply not there. It failed about once in
  # twenty, on the runner rather than here, and always somewhere that looked
  # unrelated to signing in.
  #
  # The top bar is the chrome only a listener sees. Waiting for it is waiting for
  # the session to be real.
  def listening_as(name = "Gastón")
    Profile.create!(name:).tap do
      visit profiles_path
      click_on name
      assert_selector "#topbar"
    end
  end

  # The rail shows one of its three turns at a time — the artists, the records,
  # the lists — so anything in the rail is first a turn of the rail.
  def in_the_library(turn)
    within("nav") do
      click_on turn
      yield
    end
  end

  # The name and the way out now live behind the avatar in the header.
  def open_profile_menu
    within("#topbar") { find("summary[aria-label='Profile']").click }
  end

  def switch_profile
    open_profile_menu
    within("#topbar") { click_on "Switch profile" }
  end

  # The panels are summoned from the top bar and taken by their edge, and more
  # than one test has to do both. They read as what a hand does to the room, not
  # as what a browser does to a selector, so they say so.
  def open_the(panel)
    within("#topbar") { find("button[aria-label='#{panel}']").click }
  end

  def width_of(selector)
    page.evaluate_script("document.querySelector('#{selector}').getBoundingClientRect().width")
  end

  # A drag is a press, a journey and a release — and the journey is told in two
  # legs rather than one leap, because a pointer that teleports is not a pointer
  # anybody's hand ever made.
  def widen(panel, by:)
    half = by / 2

    page.driver.browser.action
      .click_and_hold(find("#{panel} .grip", visible: :all).native)
      .move_by(half, 0)
      .move_by(by - half, 0)
      .release
      .perform
  end
end
