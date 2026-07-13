require "test_helper"

# A record you put on and let run to the end is a different thing from a record
# you took one song off, and only one of them is what people mean when they say
# they have listened to a record a hundred times. So that is what gets counted:
# every song on it, heard, with nothing else put on in between.
#
# Shuffle still turns the record — you heard the whole thing, out of order. A
# song skipped does not, because a song skipped was never listened to at all.
class SpinTest < ActiveSupport::TestCase
  setup do
    @gaston = Profile.create!(name: "Gastón")
    artist = Artist.create!(name: "Almafuerte")
    @mundo = Album.create!(directory: "/music/mundo", title: "Mundo Guanaco", artist:)
    @pesos = Album.create!(directory: "/music/pesos", title: "Pesos Pesados", artist:)
    @one, @two, @three = 3.times.map { |at| track_of(@mundo, at + 1) }
    @other = track_of(@pesos, 1)
  end

  test "a record nobody put on has not been spun" do
    assert_equal 0, @gaston.spins_of(@mundo)
  end

  test "a record heard end to end has been spun once" do
    listen_to @one, @two, @three

    assert_equal 1, @gaston.spins_of(@mundo)
  end

  test "a record you are halfway through has not been spun" do
    listen_to @one, @two

    assert_equal 0, @gaston.spins_of(@mundo)
  end

  # You heard the whole record. That the songs arrived in a hat does not make it
  # less of the record.
  test "a record heard on shuffle has still been spun" do
    listen_to @three, @one, @two

    assert_equal 1, @gaston.spins_of(@mundo)
  end

  test "a record heard twice has been spun twice" do
    listen_to @one, @two, @three, @one, @two, @three

    assert_equal 2, @gaston.spins_of(@mundo)
  end

  # Putting a record on twice over is not putting it on three times: the turn it
  # already made is finished, and the songs after it are the start of the next.
  test "going back to the first song after a full turn does not turn it again" do
    listen_to @one, @two, @three, @one

    assert_equal 1, @gaston.spins_of(@mundo)
  end

  # A turn of the record is uninterrupted. Anything else put on in the middle
  # ends the run, and what is left of the record is the start of a new one.
  test "a record interrupted by another record was not spun" do
    listen_to @one, @two, @other, @three

    assert_equal 0, @gaston.spins_of(@mundo)
  end

  test "a record you came back to and finished is spun by the songs since" do
    listen_to @one, @two, @other, @one, @two, @three

    assert_equal 1, @gaston.spins_of(@mundo)
  end

  # A single is a record, and playing it is turning it.
  test "a record of one song is spun by that one song" do
    single = Album.create!(directory: "/music/single", title: "El Pibe Tigre", artist: @mundo.artist)

    listen_to track_of(single, 1)

    assert_equal 1, @gaston.spins_of(single)
  end

  test "what one profile spun, another did not" do
    listen_to @one, @two, @three

    assert_equal 0, Profile.create!(name: "Ana").spins_of(@mundo)
  end

  # A turn of the record is about the order the songs were *heard*, not the order
  # somebody got around to writing them down. Importing a decade of listening from
  # Last.fm writes down old plays today: they land with the newest row numbers in
  # the table and the oldest hours on the clock. A rule that read the row numbers
  # would think the record was interrupted by music you heard years afterwards.
  # A turn of the record is about the order the songs were *heard*, and an import
  # files a decade of listening today: old plays land with the newest row numbers
  # in the table and the oldest hours on the clock. Worse, they land out of order
  # among themselves — so nothing can be judged as it arrives, because the song
  # that interrupts a record may not be filed until after the record is.
  #
  # So after an import the turns are counted again, from the top, by the clock.
  # Here that changes the answer: filed, the record's three songs sit in a row and
  # the other record comes after them. Heard, the other record cut right through
  # the middle.
  test "a record cut through by another is not spun, however it was filed" do
    listen_to_out_of_order(@one => 4.hours.ago, @two => 3.hours.ago,
                           @three => 1.hour.ago, @other => 2.hours.ago)

    recount

    assert_equal 0, @gaston.spins_of(@mundo)
  end

  # And the other way. Filed, the other record lands in the middle of ours. Heard,
  # it came along after the whole thing had played through — so it is a turn, and
  # counting rows would have missed it.
  test "a record heard end to end is spun, however out of order it was filed" do
    listen_to_out_of_order(@one => 4.hours.ago, @other => 1.hour.ago,
                           @two => 3.hours.ago, @three => 2.hours.ago)

    recount

    assert_equal 1, @gaston.spins_of(@mundo)
  end

  test "counting again from the top agrees with counting as you go" do
    listen_to @one, @two, @three, @one, @two, @three, @other, @one

    assert_equal 2, @gaston.spins_of(@mundo)
    recount
    assert_equal 2, @gaston.spins_of(@mundo)
  end

  # The live rule has to survive an import too. These three songs were heard just
  # now, one after another, with nothing in between — but the import filed a play
  # from two years ago in the middle of them, and it has the highest row number in
  # the table. It interrupted nothing: it was heard in 2024.
  test "a record you are playing now is not interrupted by a decade filed this morning" do
    @gaston.played(@one, at: 3.minutes.ago)
    @gaston.played(@two, at: 2.minutes.ago)
    @gaston.played(@other, at: 2.years.ago)

    @gaston.played(@three, at: 1.minute.ago)

    assert_equal 1, @gaston.spins_of(@mundo)
  end

  private

  def listen_to(*tracks)
    tracks.each { @gaston.played(it) }
  end

  # Written down in one order, heard in another — which is what an import is.
  def listen_to_out_of_order(when_heard)
    when_heard.each { |track, at| @gaston.played(track, at:) }
  end

  def recount
    Spins.new(@gaston).recount
  end

  def track_of(album, number)
    Track.create!(title: "Song #{Track.count + 1}", path: "#{album.directory}/#{number}.flac",
                  track_no: number, album:)
  end
end
