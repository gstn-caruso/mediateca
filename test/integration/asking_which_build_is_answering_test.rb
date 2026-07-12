require "test_helper"

class AskingWhichBuildIsAnsweringTest < ActionDispatch::IntegrationTest
  setup { @was = Rails.configuration.x.build }
  teardown { Rails.configuration.x.build = @was }

  test "the build answers with its own name" do
    Rails.configuration.x.build = "c1a7d86"

    get build_path

    assert_response :success
    assert_equal "c1a7d86", response.body
  end

  # A tab asks this on its way back from a deploy that cut its socket — and a
  # deploy takes the session with it if the container was replaced. Sending it to
  # the profile picker to ask which build is live would be a strange answer, and
  # would refresh nobody.
  test "a tab asks it without being anybody" do
    get build_path

    assert_response :success
  end

  # It is the deployed commit, which changes with every deploy — and not the
  # version, which is a tag and can name two deploys in a row.
  test "it is the commit that was deployed" do
    assert_equal ENV["KAMAL_VERSION"], Rails.configuration.x.build if ENV["KAMAL_VERSION"].present?
  end
end
