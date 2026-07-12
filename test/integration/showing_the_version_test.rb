require "test_helper"

class ShowingTheVersionTest < ActionDispatch::IntegrationTest
  setup do
    listening_as
    @was = Rails.configuration.x.version_name
  end

  teardown do
    Rails.configuration.x.version_name = @was
  end

  # Which build you are looking at, at the foot of the rail that is on every
  # page — so the question "did my deploy land?" is answered by looking.
  test "the rail says which build this is" do
    Rails.configuration.x.version_name = "v1.2.3"

    get root_path

    assert_response :success
    assert_select "nav", text: /Mediateca v1\.2\.3/
  end

  # An untagged checkout has nothing true to say, so it says nothing: an empty
  # "Mediateca" with a blank after it would be worse than no line at all.
  test "a build with no tag says nothing at all" do
    Rails.configuration.x.version_name = nil

    get root_path

    assert_response :success
    assert_select "nav", text: /Mediateca/, count: 0
  end
end
