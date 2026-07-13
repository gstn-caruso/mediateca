require "test_helper"

# The worker is the app's answer to being in a window with no address bar and no
# reload button: when the server is not there, it is the worker that says so, in
# the app's own voice, instead of the browser's error page.
class ServingTheServiceWorkerTest < ActionDispatch::IntegrationTest
  setup do
    @was = Rails.configuration.x.build
  end

  teardown do
    Rails.configuration.x.build = @was
  end

  # A worker may only speak for the pages under the path it was served from. From
  # anywhere but the root — /assets, say — it would control nothing at all.
  test "the worker is served from the root, so it can speak for every page" do
    assert_equal "/service-worker.js", pwa_service_worker_path
  end

  # A worker served as HTML is not run: the browser refuses the registration on
  # the MIME type alone, and the app quietly stays a tab forever.
  test "the worker is served as JavaScript" do
    get pwa_service_worker_path

    assert_response :success
    assert_equal "text/javascript", response.media_type
  end

  # The worker caches by build, so landing on a new one throws the last one's
  # cache away instead of serving it a page it no longer knows how to draw.
  #
  # The success is asserted before the body, and that is not a formality: Rails'
  # error page quotes the template it died rendering, build string and all, so
  # this test once passed against a 422.
  test "the worker is stamped with the build it belongs to" do
    Rails.configuration.x.build = "v1.2.3-deadbeef"

    get pwa_service_worker_path

    assert_response :success
    assert_match "v1.2.3-deadbeef", response.body
  end

  # The page it falls back to is the one page that has to render with the network
  # gone. Anything it had to go and fetch — a stylesheet, a script, a font — would
  # be exactly the thing it cannot have.
  test "the page it falls back to needs nothing but itself" do
    get "/offline.html"

    assert_response :success
    assert_select "link[rel=stylesheet]", count: 0
    assert_select "script[src]", count: 0
    assert_select "img[src]", count: 0
  end
end
