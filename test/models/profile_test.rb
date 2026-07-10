require "test_helper"

class ProfileTest < ActiveSupport::TestCase
  test "a profile is someone with a name" do
    assert Profile.new(name: "Gastón").valid?
  end

  test "a nameless profile is nobody" do
    refute Profile.new(name: "").valid?
    refute Profile.new(name: "   ").valid?
  end

  # Without a password, the name is the only thing telling two listeners apart.
  test "two listeners cannot share a name" do
    Profile.create!(name: "Gastón")

    refute Profile.new(name: "Gastón").valid?
  end

  # A profile that moved in the grid would be a profile you click by mistake.
  test "profiles keep the order they were created in" do
    [ "Zoe", "Ana", "Beto" ].each { |name| Profile.create!(name:) }

    assert_equal [ "Zoe", "Ana", "Beto" ], Profile.ordered.map(&:name)
  end
end
