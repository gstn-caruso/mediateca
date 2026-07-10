require "application_system_test_case"

class PickingAProfileTest < ApplicationSystemTestCase
  test "the picker asks who is listening, and takes you at your word" do
    Profile.create!(name: "Gastón")
    Profile.create!(name: "Ana")

    visit root_path

    assert_text "Who's listening?"
    click_on "Ana"

    assert_text "Your Library"
    assert_selector "nav", text: "Ana"
  end

  test "somebody new is added from the picker, then listens" do
    visit profiles_path

    fill_in "Name", with: "Beto"
    click_on "Add profile"
    click_on "Beto"

    assert_selector "nav", text: "Beto"
  end

  test "a name nobody can read is refused" do
    visit profiles_path

    click_on "Add profile"

    assert_text "Name can't be blank"
  end
end
