require "test_helper"

# Reading the colour off every picture in the library, once: the sleeve of a
# record, the photograph of an artist.
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

  # An artist's colour is their own, not one of their records'. It is read off
  # the picture of them, so a singer photographed against a red wall is red even
  # if every sleeve they ever made was blue.
  test "an artist is painted the colour of their photograph" do
    @artist.update!(portrait_path: photograph("#101010" => 0.6, "#1e6ad4" => 0.4))

    Music::Colours.new.collect

    assert_in_delta 214.0, Colour.hex(@artist.reload.accent).hue, 5
  end

  # Nobody has a picture of them: there is nothing to read, and an artist is not
  # given the colour of one of their sleeves to stand in for a face.
  test "an artist nobody photographed is left with no colour of their own" do
    assert_nothing_raised { Music::Colours.new.collect }
    assert_nil @artist.reload.accent
  end

  test "an artist already painted is not asked a second time" do
    @artist.update!(portrait_path: photograph("#1e6ad4" => 1.0), accent: "#c8102e")

    Music::Colours.new.collect

    assert_equal "#c8102e", @artist.reload.accent
  end

  private

  def record(cover:, accent: nil)
    Album.create!(directory: "/music/#{SecureRandom.hex(4)}", title: "Figure 8", year: 2000,
                  artist: @artist, cover_path: cover, accent:)
  end
end
