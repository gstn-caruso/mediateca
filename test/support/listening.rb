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
  def listening_as(name = "Gastón")
    Profile.create!(name:).tap do
      visit profiles_path
      click_on name
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
