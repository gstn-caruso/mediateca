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

  # The name and the way out now live behind the avatar in the header.
  def open_profile_menu
    within("#topbar") { find("summary[aria-label='Profile']").click }
  end

  def switch_profile
    open_profile_menu
    within("#topbar") { click_on "Switch profile" }
  end
end
