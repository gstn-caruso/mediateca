require "test_helper"

class ChoosingAProfileTest < ActionDispatch::IntegrationTest
  setup { @gaston = Profile.create!(name: "Gastón") }

  test "the picker is the one page you can reach as nobody" do
    get profiles_path

    assert_response :success
  end

  test "the library sends you to the picker until somebody is listening" do
    get root_path

    assert_redirected_to profiles_path
  end

  test "choosing a profile lets you into the library" do
    choose @gaston

    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
  end

  test "the chosen profile outlives the request that chose it" do
    choose @gaston

    get root_path

    assert_response :success
  end

  test "somebody new can be added from the picker" do
    assert_difference -> { Profile.count }, +1 do
      post profiles_path, params: { profile: { name: "Ana" } }
    end

    assert_redirected_to profiles_path
  end

  test "a nameless profile is not added" do
    assert_no_difference -> { Profile.count } do
      post profiles_path, params: { profile: { name: "" } }
    end
  end

  test "leaving sends you back to the picker, and the library locks again" do
    choose @gaston

    delete session_path

    assert_redirected_to profiles_path
    get root_path
    assert_redirected_to profiles_path
  end

  # The cookie outlives the profile: a browser left open on the kitchen tablet
  # still names somebody who was deleted last week. Nobody listening is a
  # answer; a 404 in the middle of the library is not.
  test "a cookie naming a profile that no longer exists means nobody is listening" do
    choose @gaston
    @gaston.destroy!

    get root_path

    assert_redirected_to profiles_path
  end

  test "choosing a profile that does not exist lets nobody in" do
    post session_path, params: { profile_id: 0 }

    assert_redirected_to profiles_path
    get root_path
    assert_redirected_to profiles_path
  end

  private

  def choose(profile)
    post session_path, params: { profile_id: profile.id }
  end
end
