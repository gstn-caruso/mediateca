require "test_helper"

# The manifest is the whole difference between a tab and an app. It is what
# Safari reads when you say Add to Dock, and what Chrome reads before it offers
# to install — so what is written here is what ends up under the icon.
class InstallingTheAppTest < ActionDispatch::IntegrationTest
  test "the manifest is served as a manifest" do
    get pwa_manifest_path

    assert_response :success
    assert_equal "application/manifest+json", response.media_type
  end

  test "the manifest names the app" do
    get pwa_manifest_path

    assert_equal "Mediateca", manifest["name"]
    assert_equal "Mediateca", manifest["short_name"]
  end

  # A window of its own, opening on the library, and holding on to every link in
  # the app: outside the scope, a click would be handed back to the browser, and
  # the app you installed would open a tab to answer it.
  test "the manifest asks for a window of its own, over the whole app" do
    get pwa_manifest_path

    assert_equal "standalone", manifest["display"]
    assert_equal "/", manifest["start_url"]
    assert_equal "/", manifest["scope"]
  end

  # The app is black before it has drawn anything — so the window it opens into
  # is black too, rather than the white flash of a page that has not loaded yet.
  test "the manifest opens on the same black the app stands on" do
    get pwa_manifest_path

    assert_equal "#000000", manifest["background_color"]
    assert_equal "#000000", manifest["theme_color"]
  end

  # Chrome will not offer to install an app it cannot draw an icon for, and it
  # asks for these two sizes by name.
  test "the manifest offers the icons an installer asks for" do
    get pwa_manifest_path

    assert manifest["icons"].any? { |icon| icon["sizes"] == "192x192" && icon["type"] == "image/png" },
      "no 192px icon: Chrome will not offer to install"
    assert manifest["icons"].any? { |icon| icon["sizes"] == "512x512" && icon["type"] == "image/png" },
      "no 512px icon: Chrome will not offer to install"
  end

  # The Dock takes its icon from the manifest and nowhere else — an apple-touch-icon
  # is only a fallback, and a 512 blown up to 1024 is a blurry app. Apple asks for
  # one opaque, full-bleed, maskable square, and asks for it big.
  test "the manifest offers macOS the icon it draws the Dock from" do
    get pwa_manifest_path

    assert manifest["icons"].any? { |icon| icon["sizes"] == "1024x1024" && icon["purpose"] == "maskable" },
      "no 1024px maskable icon: the Dock has nothing sharp to draw, and cuts into whatever it is given"
  end

  test "every icon the manifest promises is really there" do
    get pwa_manifest_path

    manifest["icons"].each do |icon|
      get icon["src"]
      assert_response :success, "the manifest promises #{icon["src"]}, and it 404s"
    end
  end

  # A manifest nothing links to is a file nobody reads.
  test "the page points at the manifest" do
    listening_as

    get root_path

    assert_select "link[rel=manifest][href=?]", pwa_manifest_path
  end

  # Apple takes the name for the Dock from here, and reaches for this icon at
  # this exact path whether we link it or not.
  test "the page hands Apple the name and the icon it looks for" do
    listening_as

    get root_path

    assert_select "meta[name='apple-mobile-web-app-title'][content=?]", "Mediateca"
    assert_select "link[rel='apple-touch-icon'][href=?]", "/apple-touch-icon.png"
  end

  # An installed window's title bar takes its colour from here — the same black
  # the app stands on, so the chrome belongs to the app.
  test "the page declares the colour its window is tinted with" do
    listening_as

    get root_path

    assert_select "meta[name=theme-color][content=?]", "#000000"
  end

  private
    def manifest
      JSON.parse(response.body)
    end
end
