require "application_system_test_case"

# Putting a song on is not listening to it. The history used to think it was: it
# was written the instant a track started, so a song you skipped after three
# seconds counted exactly as much as one you sat through — in "Recently played",
# in the counts, and in what the app decides to offer you next.
#
# A song now counts once you have heard enough of it: half of it, or four
# minutes, whichever comes first. That is Last.fm's rule, and it is the same rule
# whether or not anybody's Last.fm is connected, because it is simply what
# listening means.
class WhatCountsAsListeningTest < ApplicationSystemTestCase
  ALBUM_DIR = "Almafuerte/1995 - Mundo guanaco".freeze

  # Two seconds long, so half of it is one second and a test can afford to sit
  # through it. The song after it is a real one, so skipping has somewhere to go
  # and lands on something that will not reach its own halfway mark while we look.
  setup do
    listening_as
    artist = Artist.create!(name: "Almafuerte")
    @album = Album.create!(
      directory: File.join(Rails.configuration.x.media_root, ALBUM_DIR), title: "Mundo Guanaco", year: 1995,
      album_type: "album", disc_total: 1, artist:, cover_path: media("cover.jpg")
    )
    @short = Track.create!(title: "Un Tema Corto", track_no: 1, disc_no: 1, duration: 2.0,
                           path: media("05 - Un tema corto.flac"), album: @album)
    Track.create!(title: "Desencuentro", track_no: 2, disc_no: 1, duration: 30.0,
                  path: media("01 - Desencuentro.flac"), album: @album)
  end

  test "a song you sat through is in your history" do
    play "Un Tema Corto"

    listened = eventually { Play.first }

    assert_equal @short, listened.track
  end

  # The player says nothing until the halfway mark, and then says it once. It is
  # asked four times a second, so "once" is the whole of the assertion — and the
  # asking does not outlive the song, so waiting for Desencuentro to come on is
  # waiting through every ask "Un Tema Corto" was ever going to get.
  test "sitting through a song once is one play, not one a second" do
    play "Un Tema Corto"

    eventually { Play.any? }
    assert_selector "[data-player-target='title']", text: "Desencuentro"

    assert_equal 1, Play.count
  end

  # A skip is a press, not a wait: the cursor moves and Desencuentro is on
  # screen before the click even returns. Checking for it first is checking
  # that the skip's own handler — the one thing that could still call
  # "Un Tema Corto" heard — has already run.
  test "a song you skipped is not in your history" do
    play "Un Tema Corto"
    click_on "Next"

    assert_selector "[data-player-target='title']", text: "Desencuentro"
    assert_empty Play.all
  end

  # The hole this rule exists to close. Position is not listening: dragging the
  # thumb to the end of a song takes an instant and leaves the song unheard, and
  # a player that watched the thumb would have counted it. So what is counted is
  # the time the music actually ran — a jump is a jump, and adds nothing.
  test "dragging the song to its end is not listening to it" do
    play "Un Tema Corto"
    scrub_to_the_end

    assert_no_plays
  end

  # The same hole, from the side it actually opens on. The player used to be told
  # about a jump by `seeking` and trusted that news to arrive before the tick that
  # would see the leap — but setting the position changes it at once, while
  # `seeking` is delivered from a queued task. A tick that lands in between asks
  # the song where it is and is told the end, having played none of the way there.
  #
  # So the player is asked in the losing order on purpose: the leap first, the
  # news second. What it has heard cannot depend on which of the two won.
  test "a jump is not listening even when the player hears of it late" do
    play "Un Tema Corto"
    scrub_to_the_end_before_the_seek_is_announced

    assert_no_plays
  end

  # The moment the music started, not the moment the news arrived — by then the
  # song is half over. It is what Last.fm is told, and what a history is ordered
  # by. Half of this song is a second, so the two timestamps must be a second
  # apart: anything less and the row was written when the music began, which is
  # the very thing that was wrong.
  test "the history remembers when the music started, not when it heard about it" do
    play "Un Tema Corto"

    listened = eventually { Play.first }

    assert_operator listened.created_at - listened.played_at, :>=, 0.9
  end

  private

  def play(title)
    visit album_path(@album)
    find("button[data-player-track]", text: title).click
    assert_selector "[data-player-target='title']", text: title
  end

  # Straight at the audio, because that is what a drag of the thumb comes down
  # to: the song is suddenly somewhere else, having played none of the way there.
  def scrub_to_the_end
    page.execute_script("document.querySelector('audio').currentTime = 1.9")
  end

  # The same jump, with the tick that sees it forced to arrive before the seek is
  # announced. Both happen in one turn of the browser's script, and a queued task
  # cannot cut in on that — so `seeking` is still waiting its turn when the player
  # is asked what it has heard. That is the order the browser is free to choose,
  # and the one the bug needed.
  def scrub_to_the_end_before_the_seek_is_announced
    page.execute_script(<<~JS)
      const audio = document.querySelector("audio")
      audio.currentTime = 1.9
      audio.dispatchEvent(new Event("timeupdate"))
    JS
  end

  # The music plays in the browser and the row is written by the server, so there
  # is nothing to wait on but the row itself. Generously: this waits on a second
  # of music actually playing, and the suite runs ten browsers at once, so that
  # second is not a second of anybody's wall clock.
  def eventually(within: 15)
    deadline = Time.current + within

    loop do
      found = yield
      return found if found
      flunk "waited #{within}s and it never happened" if Time.current > deadline

      sleep 0.1
    end
  end

  # Proving a negative: give it longer than the song and the threshold both, and
  # then look.
  #
  # Both scrubs land the song on Desencuentro too, once `ended` decides the seek
  # was really the end — but getting there needs the file to actually finish
  # decoding, and asking a Capybara finder to watch for it competes with that
  # decoding for the one thing this runner is short of. A wait, here, is not a
  # guess: the song and the threshold are both known quantities, and outliving
  # both is outliving the only window a wrong Play could come from.
  def assert_no_plays
    sleep 2.5

    assert_empty Play.all
  end

  def media(name)
    File.join(Rails.configuration.x.media_root, ALBUM_DIR, name)
  end
end
