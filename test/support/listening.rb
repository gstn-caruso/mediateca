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
end
