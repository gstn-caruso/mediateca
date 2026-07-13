require "test_helper"

# Reading the colour off every sleeve in the library, once.
class Music::ColoursTest < ActiveSupport::TestCase
  include Sleeves

  setup { @artist = Artist.create!(name: "Elliott Smith") }

  test "a record is painted the colour of its sleeve" do
    figure_8 = record(cover: sleeve("#101010" => 0.5, "#f5f5f5" => 0.25, "#c8102e" => 0.25))

    Music::Colours.new.collect

    assert_in_delta 350.2, Colour.hex(figure_8.reload.accent).hue, 5
  end

  # A black and white record is not a bug. It has no colour to give, and the app
  # goes on wearing its own — so nothing is written down, and the sleeve is read
  # again next time in case somebody replaced the cover with a better scan.
  test "a record whose sleeve has no colour is left with none" do
    plain = record(cover: sleeve("#101010" => 0.5, "#f5f5f5" => 0.5))

    Music::Colours.new.collect

    assert_nil plain.reload.accent
  end

  # The sleeve is on the NAS and reading it is not free. A record that has been
  # looked at is not looked at again.
  test "a record already painted is not asked a second time" do
    painted = record(cover: sleeve("#c8102e" => 1.0), accent: "#0000ff")

    Music::Colours.new.collect

    assert_equal "#0000ff", painted.reload.accent
  end

  test "a record with no cover at all is simply passed over" do
    coverless = record(cover: nil)

    assert_nothing_raised { Music::Colours.new.collect }
    assert_nil coverless.reload.accent
  end

  private

  def record(cover:, accent: nil)
    Album.create!(directory: "/music/#{SecureRandom.hex(4)}", title: "Figure 8", year: 2000,
                  artist: @artist, cover_path: cover, accent:)
  end
end
