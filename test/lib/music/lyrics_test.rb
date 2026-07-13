require "test_helper"

class Music::LyricsTest < ActiveSupport::TestCase
  # An .lrc holds a time and a line, and the time is what makes it karaoke.
  test "a timed line knows when it is sung" do
    lyrics = Music::Lyrics.parse("[00:12.34]La primera")

    assert lyrics.synced?
    assert_equal [ [ 12.34, "La primera" ] ], lyrics.lines.map { [ it.at, it.text ] }
  end

  test "the lines come back in the order they are sung" do
    lyrics = Music::Lyrics.parse(<<~LRC)
      [00:30.00]La tercera
      [00:10.00]La primera
      [00:20.00]La segunda
    LRC

    assert_equal [ "La primera", "La segunda", "La tercera" ], lyrics.lines.map(&:text)
  end

  # A chorus is written once and sung twice: one line, both its times. Reading
  # only the first would leave the second time with nothing to show.
  test "a line sung twice is two lines" do
    lyrics = Music::Lyrics.parse("[00:15.00][01:20.00]El estribillo")

    assert_equal [ [ 15.0, "El estribillo" ], [ 80.0, "El estribillo" ] ], lyrics.lines.map { [ it.at, it.text ] }
  end

  # Minutes past the hour keep counting: a 70-minute live take is one song, and
  # [01:10:00] would be a lie about a track that is 70 minutes in.
  test "the minutes past sixty are still minutes" do
    assert_equal 4_205.0, Music::Lyrics.parse("[70:05.00]Un vivo largo").lines.sole.at
  end

  # LRCLIB writes hundredths; some writers write thousandths. Both are the time.
  test "a time written to the millisecond is read to the millisecond" do
    assert_equal 3.456, Music::Lyrics.parse("[00:03.456]Al milisegundo").lines.sole.at
  end

  # The header an .lrc carries — who wrote it, how long it runs — is about the
  # file, not about the song. Sung out loud it would be nonsense.
  test "the tags in the header are not sung" do
    lyrics = Music::Lyrics.parse(<<~LRC)
      [ar:Un artista]
      [ti:Una canción]
      [length:03:21]
      [00:05.00]La única línea
    LRC

    assert_equal [ "La única línea" ], lyrics.lines.map(&:text)
  end

  # The gap between verses is timed too, and it is where the karaoke has nothing
  # to say. Keeping it is how the panel knows to stop pointing at the last line.
  test "a timed silence is a line with nothing in it" do
    lyrics = Music::Lyrics.parse("[00:05.00]La primera\n[00:09.00]\n[00:14.00]La segunda")

    assert_equal [ "La primera", "", "La segunda" ], lyrics.lines.map(&:text)
  end

  # Not every song on the disk has a synced .lrc: some were only ever found as
  # plain text. They are still the words, and they still belong on the panel —
  # they just cannot be followed.
  test "words with no times are words all the same" do
    lyrics = Music::Lyrics.parse("La primera\nLa segunda")

    assert_not lyrics.synced?
    assert_not lyrics.empty?
    assert_equal [ "La primera", "La segunda" ], lyrics.lines.map(&:text)
    assert_nil lyrics.lines.first.at
  end

  test "a file with nothing in it is no lyrics at all" do
    assert Music::Lyrics.parse("").empty?
    assert Music::Lyrics.parse("   \n\n ").empty?
  end

  # A song nobody found the words to. The panel says so rather than standing
  # empty, so this has to be something, not nil.
  test "the words nobody found are empty, not missing" do
    assert Music::Lyrics.none.empty?
    assert_not Music::Lyrics.none.synced?
    assert_empty Music::Lyrics.none.lines
  end
end
