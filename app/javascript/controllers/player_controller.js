import { Controller } from "@hotwired/stimulus"

const OFF = "off"
const ALL = "all"
const ONE = "one"

// Where the queue is written down so it can outlive a full reload. Named by the
// origin, so two apps on one host don't read each other's music.
const REMEMBERED = "mediateca:player"

// How often, at most, the passing of a song is written down. Anything that
// actually changes is written at once; this is only the clock ticking.
const REMEMBER_EVERY = 5000

// What it takes for a song to count as listened to: half of it, or four minutes
// of it, whichever comes first. Putting a song on is not listening to it, and
// the history used to think it was — a song skipped after three seconds counted
// as much as one sat through. This is Last.fm's rule, and it holds whether or
// not anybody's Last.fm is connected, because it is simply what listening means.
const ENOUGH = 4 * 60

// Whether the queue rail was left open, remembered the way the library rail's
// state is. The class the CSS reads to know it is.
const QUEUE = "mediateca:queue"
const OPEN = "is-open"

// The same, for the lyrics rail — and, beside it, whether the words are to
// follow the song at all. Following is the point of a timed .lrc, so it is on
// unless a listener has said otherwise.
const LYRICS = "mediateca:lyrics"
const FOLLOW = "mediateca:lyrics-follow"

// And the same again for the picture. What is drawn on it is no business of this
// controller — the visualizer draws itself. This owns the rail, as it owns the
// other two, and all it says is when the rail opens.
const VISUALIZER = "mediateca:visualizer"

// Drives the single <audio> element in the layout.
//
// Turbo Drive swaps the body on every navigation, so this controller is torn
// down and rebuilt constantly. The audio element is not: it lives inside
// #player, which is data-turbo-permanent. So the queue rides on the audio
// element rather than on the controller, and playback survives navigation.
export default class extends Controller {
  // Whether this listener has a Last.fm. Without one there is nobody to tell what
  // is on, and telling the server anyway would be a request per song that ends in
  // a shrug.
  static values = { profile: String, scrobbles: Boolean }

  static targets = [
    "audio", "title", "titleText", "idle", "subtitle", "subtitleText", "cover", "tail", "broken",
    "playIcon", "pauseIcon", "progress", "elapsed", "duration",
    "shuffle", "repeat", "repeatOne", "next", "queue", "queueEmpty", "queueToggle", "panel",
    "repeatBadge", "repeatBadgeText", "backdrop", "row", "suggestions",
    "lyrics", "lyricsPanel", "lyricsToggle", "syncToggle",
    "visualizerPanel", "visualizerToggle"
  ]

  // Whether the words are to follow the song. A plain controller field, not
  // state on the <audio>: the rail that holds the button is permanent, but this
  // is read back on every visit, and one read of localStorage per navigation is
  // nothing — one per `timeupdate`, four times a second forever, would not be.
  connect() {
    this.following = this.remembers(FOLLOW) !== "off"
  }

  // Turbo builds the new body before it moves #player, the permanent element,
  // into it — so on navigation the controller connects to a body with no player
  // yet. Waiting to be told the audio arrived beats asking whether it has.
  audioTargetConnected() {
    this.restore()
    this.refreshIcons()
    this.tick()
    this.render()
    this.makeGoodTheHeldPress()
  }

  // The same gap seen from the other side: the rows of the new body can be
  // pressed before the player is carried into it, and everything a press needs —
  // the queue, the order, the audio itself — is in there. Asking early throws and
  // the song is lost, so an early press is held rather than answered.
  held(press) {
    if (this.hasAudioTarget) return false

    this.heldPress = press
    return true
  }

  makeGoodTheHeldPress() {
    const press = this.heldPress
    this.heldPress = null
    press?.()
  }

  // The queue rail is permanent, so it stays open across a visit — but the bar
  // that holds the button is rebuilt, and came back saying "closed" while the
  // rail was still standing there. The panel is the one that knows.
  //
  // The button is in the new body and the rail is carried into it afterwards, so
  // on a visit this fires before there is a rail to ask. Asking anyway throws,
  // and a throw here takes the rest of the connection with it — including the
  // audio's, which is what marks the row that's playing.
  queueToggleTargetConnected() {
    this.syncQueueToggles()
  }

  // And once the rail itself lands, whichever buttons are on the page are told.
  // The rail is permanent, so it only lands on a full load — which is exactly
  // when the choice has to be read back off storage.
  panelTargetConnected() {
    if (this.remembers(QUEUE) === "open") this.panelTarget.classList.add(OPEN)

    this.syncQueueToggles()
  }

  syncQueueToggles() {
    if (!this.hasPanelTarget) return

    const open = String(this.panelTarget.classList.contains(OPEN))
    this.queueToggleTargets.forEach((toggle) => toggle.setAttribute("aria-expanded", open))
  }

  // The lyrics rail keeps the same two-sided arrangement, and for the same
  // reasons: the button that opens it is rebuilt on every visit, the rail itself
  // is permanent and only lands on a full load — which is where the choice to
  // have left it open is read back off storage.
  // A visit builds a new bar, and the microphone in it comes back alive — it is a
  // fresh button, and the markup cannot know what is playing. It is told.
  lyricsToggleTargetConnected() {
    this.syncLyricsToggles()
    this.renderLyricsToggle()
  }

  lyricsPanelTargetConnected() {
    if (this.remembers(LYRICS) === "open") this.lyricsPanelTarget.classList.add(OPEN)

    this.syncLyricsToggles()
    this.showLyrics()
  }

  syncLyricsToggles() {
    if (!this.hasLyricsPanelTarget) return

    const open = String(this.lyricsPanelTarget.classList.contains(OPEN))
    this.lyricsToggleTargets.forEach((toggle) => toggle.setAttribute("aria-expanded", open))
    this.syncToggleTarget.setAttribute("aria-pressed", String(this.following))
  }

  // The picture's rail, arranged the same way and for the same reasons.
  visualizerToggleTargetConnected() {
    this.syncVisualizerToggles()
  }

  visualizerPanelTargetConnected() {
    if (this.remembers(VISUALIZER) === "open") this.visualizerPanelTarget.classList.add(OPEN)

    this.syncVisualizerToggles()
    this.tellTheVisualizer()
  }

  syncVisualizerToggles() {
    if (!this.hasVisualizerPanelTarget) return

    const open = String(this.visualizerPanelTarget.classList.contains(OPEN))
    this.visualizerToggleTargets.forEach((toggle) => toggle.setAttribute("aria-expanded", open))
  }

  remembers(key) {
    try {
      return localStorage.getItem(key)
    } catch {
      return null
    }
  }

  // A tracklist arrives whenever you navigate, and the row that is playing may
  // be in it. Marking each row as it appears is not subject to that ordering.
  rowTargetConnected(row) {
    this.mark(row)
  }

  // A click on a track queues the whole tracklist it belongs to, so the album
  // keeps playing on its own — and keeps playing while you browse elsewhere.
  play({ params: { index } }) {
    if (this.held(() => this.play({ params: { index } }))) return

    this.queueUp(this.rowTargets.map((row) => ({ ...row.dataset })), index)
  }

  // Pressing play on a record you are not looking at: a row in the rail, an
  // artist's own header. There is no tracklist on the page to queue from, so the
  // button carries the address where the songs can be had, and the player goes and
  // asks for them. The answer is spelled exactly as a row is, so from here on it
  // is the same queue.
  async putOn({ params: { queue, shuffled } }) {
    if (this.held(() => this.putOn({ params: { queue, shuffled } }))) return

    const answer = await fetch(queue, { headers: { Accept: "application/json" } })
    if (!answer.ok) return

    const { tracks } = await answer.json()
    if (!tracks.length) return

    this.shuffled = Boolean(shuffled)
    this.queueUp(tracks, this.shuffled ? Math.floor(Math.random() * tracks.length) : 0)
  }

  // Take this list, start on this one, and deal the rest — in order, or shuffled
  // around the one that is starting.
  queueUp(tracks, index) {
    this.queue = tracks
    this.order = this.shuffled ? this.shuffleAround(index) : tracks.map((_, at) => at)
    this.cursor = this.order.indexOf(index)
    this.start()
  }

  // The big shuffle button on a record turns shuffle on and then plays it, the
  // way pressing shuffle in Spotify is a way of pressing play.
  //
  // Which song it starts with is part of the shuffle. It used to take the index
  // the button carried — always 0 — so every shuffle of a record began with
  // track one, dealt the rest at random, and called that shuffling.
  playShuffled() {
    if (this.held(() => this.playShuffled())) return

    this.shuffled = true
    this.play({ params: { index: Math.floor(Math.random() * this.rowTargets.length) } })
  }

  // Jumping from the queue panel: the track is already queued, only the cursor
  // moves.
  jump({ params: { at } }) {
    this.cursor = at
    this.start()
  }

  toggle() {
    if (!this.audioTarget.src) return

    this.audioTarget.paused ? this.audioTarget.play().catch(() => {}) : this.audioTarget.pause()
  }

  // Space is play/pause everywhere there is music, and it was the one key that
  // did nothing here. Not while you are typing in the search box — and not while
  // a song row has the focus, because every row is a button, and Space on a
  // focused button is how a keyboard presses it.
  hotkey(event) {
    if (event.key !== " " || event.metaKey || event.ctrlKey || event.altKey) return

    const { target } = event
    if (target.isContentEditable || [ "INPUT", "TEXTAREA", "SELECT", "BUTTON" ].includes(target.tagName)) return

    event.preventDefault()
    this.toggle()
  }

  next() {
    if (this.cursor + 1 < this.order.length) this.cursor += 1
    else if (this.repeating === ALL) this.cursor = 0
    else return

    this.start()
  }

  // The first press restarts the track; only a second one goes back. Every
  // music player does this, and it is the only reason `previous` is not `next`
  // with a minus sign.
  //
  // Starting the song over is starting it over: what was heard of the last pass
  // is abandoned, and sitting through this one is a listen of its own.
  previous() {
    if (this.audioTarget.currentTime > 3) {
      this.listenAfresh()
      this.audioTarget.currentTime = 0
      return
    }
    if (this.cursor <= 0) return

    this.cursor -= 1
    this.start()
  }

  // A track that ended on its own obeys repeat-one; a listener pressing next
  // means next.
  //
  // Repeat-one takes the song back to the top itself rather than going through
  // start(), so it has to say that a fresh listen has begun — otherwise a song
  // on loop all afternoon would be a single play.
  advance() {
    if (this.repeating === ONE) {
      this.listenAfresh()
      this.audioTarget.currentTime = 0
      this.audioTarget.play()
      return
    }

    this.next()
  }

  // Whatever is playing keeps playing; the order of what comes after changes
  // under it. So the queue index has to be read before the order is redealt.
  toggleShuffle() {
    const playing = this.order[this.cursor]

    this.shuffled = !this.shuffled

    if (playing !== undefined) {
      this.order = this.shuffled ? this.shuffleAround(playing) : this.queue.map((_, at) => at)
      this.cursor = this.order.indexOf(playing)
    }

    this.render()
  }

  cycleRepeat() {
    this.repeating = { [OFF]: ALL, [ALL]: ONE, [ONE]: OFF }[this.repeating]
    this.render()
  }

  // Open or shut; the CSS decides what open looks like — beside the content on a
  // desktop, over it on a phone. The choice is written down, the way the library
  // rail's is, so a refresh doesn't shut a queue you left open.
  toggleQueue() {
    const open = this.panelTarget.classList.toggle(OPEN)

    try {
      localStorage.setItem(QUEUE, open ? "open" : "shut")
    } catch { /* a private window just forgets which way it was left */ }

    this.syncQueueToggles()
  }

  // Open or shut, remembered, exactly as the queue is.
  toggleLyrics() {
    this.leaveLyrics(!this.lyricsOpen)
  }

  // And the picture, the same again — except that a rail with a WebGL context
  // behind it costs something to draw, so the one thing this has to do that the
  // others don't is say so. Drawing sixty frames a second at a rail nobody has
  // open is the whole cost of the feature for none of the point of it.
  toggleVisualizer() {
    const open = this.visualizerPanelTarget.classList.toggle(OPEN)

    try {
      localStorage.setItem(VISUALIZER, open ? "open" : "shut")
    } catch { /* a private window just forgets which way it was left */ }

    this.syncVisualizerToggles()
    this.tellTheVisualizer()
  }

  // The rail is opened from the bar, which is out here, and drawn from inside
  // itself. This is the only word that passes between them.
  tellTheVisualizer() {
    this.dispatch("visualizer")
  }

  // The rail left the way it is being left, and remembered that way.
  //
  // Opening it is what asks for the words — of a song already asked about, that
  // is the words already in hand, and the rail opens onto them at once. Shutting
  // it asks for nothing: there is nothing to show, and it is showLyrics that
  // shuts the rail in the first place.
  leaveLyrics(open) {
    this.lyricsPanelTarget.classList.toggle(OPEN, open)

    try {
      localStorage.setItem(LYRICS, open ? "open" : "shut")
    } catch { /* a private window just forgets which way it was left */ }

    this.syncLyricsToggles()
    if (open) this.showLyrics()
  }

  // Following on or off. Turning it off leaves the words standing exactly where
  // they are — so the line that was lit has to be put out, or it would sit there
  // pointing at a moment the song has long since passed. Turning it back on
  // catches up with wherever the song got to, rather than waiting for the next
  // line to come round.
  toggleSyncing() {
    this.following = !this.following

    try {
      localStorage.setItem(FOLLOW, this.following ? "on" : "off")
    } catch { /* a private window just forgets which way it was left */ }

    this.syncToggleTarget.setAttribute("aria-pressed", String(this.following))
    this.following ? this.followLyrics() : this.dimLyrics()
  }

  // Dragging the scrubber fires `input` the whole way across. Seeking on each
  // one asks the NAS for a fresh range of a 34MB FLAC dozens of times, and
  // `timeupdate` keeps writing the thumb back where the song is — so it fights
  // the pointer. The drag only paints; the seek happens once, on `change`, when
  // it is let go.
  scrubbing() {
    this.dragging = true
    this.elapsedTarget.textContent = this.clock(this.scrubbedTo())
    this.paint(this.progressTarget)
  }

  scrub() {
    this.dragging = false

    const to = this.scrubbedTo()
    if (Number.isFinite(to)) this.audioTarget.currentTime = to
  }

  scrubbedTo() {
    const { duration } = this.audioTarget

    return Number.isFinite(duration) ? (this.progressTarget.value / 1000) * duration : NaN
  }

  tick() {
    if (this.dragging) return

    const { currentTime, duration } = this.audioTarget

    this.elapsedTarget.textContent = this.clock(currentTime)
    this.durationTarget.textContent = Number.isFinite(duration) ? this.clock(duration) : "–:––"
    this.progressTarget.value = Number.isFinite(duration) && duration > 0 ? (currentTime / duration) * 1000 : 0
    this.paint(this.progressTarget)
    this.followLyrics()
    this.keepListening()
    this.savePosition()
  }

  // A file the server no longer has — a re-import that moved it, a NAS that went
  // away — used to leave the player sitting on a title that would never sound,
  // saying nothing, forever.
  //
  // It says so now, and it stops there. It does not skip on: an error is as
  // easily a NAS catching its breath as a file that is gone, and a player that
  // skips on error would tear through the whole record in a second over a blip.
  // Next is one press away, and the listener knows which it was.
  failed() {
    if (!this.audioTarget.src) return

    this.brokenTarget.hidden = false
    this.refreshIcons()
  }

  // How much of the song is behind us. The CSS draws the track from this, so the
  // fill reads the same in every engine instead of leaning on accent-color —
  // and the input itself can be a tall, invisible drag target over a hairline.
  paint(range) {
    range.style.setProperty("--filled", `${(range.value / range.max) * 100}%`)
  }

  // The bars of an equalizer say sound is coming out of this song. Paused, no
  // sound is coming out of anything, and bars that keep bouncing are lying — so
  // the whole document is told whether anything is playing, and the CSS holds
  // every equalizer on the page still until it is. <html> survives Turbo, so the
  // answer rides across navigation the way the music does.
  refreshIcons() {
    const playing = Boolean(this.audioTarget.src && !this.audioTarget.paused)

    this.playIconTarget.classList.toggle("hidden", playing)
    this.pauseIconTarget.classList.toggle("hidden", !playing)
    document.documentElement.dataset.playing = String(playing)
    this.save()
  }

  // --- State, which lives in the <audio> because the <audio> survives Turbo -

  get queue() { return this.audioTarget.queue ?? [] }
  set queue(tracks) { this.audioTarget.queue = tracks }

  get order() { return this.audioTarget.order ?? [] }
  set order(indexes) { this.audioTarget.order = indexes }

  get cursor() { return this.audioTarget.cursor ?? -1 }
  set cursor(at) { this.audioTarget.cursor = at }

  // The tally of what has actually been heard rides on the <audio> for the same
  // reason the queue does: Turbo throws this controller away on every visit, and
  // walking to another page in the middle of a song is not leaving the song.
  get listened() { return this.audioTarget.listened ?? 0 }
  set listened(seconds) { this.audioTarget.listened = seconds }

  // Where the music had got to when we last looked, so the next look knows how
  // much of it ran in between.
  get heardAt() { return this.audioTarget.heardAt ?? 0 }
  set heardAt(seconds) { this.audioTarget.heardAt = seconds }

  // When the music started, in the seconds Last.fm counts in.
  get startedAt() { return this.audioTarget.startedAt ?? 0 }
  set startedAt(unix) { this.audioTarget.startedAt = unix }

  // Said once. The tick that crosses the halfway mark is one of four a second.
  get counted() { return this.audioTarget.counted ?? false }
  set counted(yes) { this.audioTarget.counted = yes }

  get shuffled() { return this.audioTarget.shuffled ?? false }
  set shuffled(on) { this.audioTarget.shuffled = on }

  get repeating() { return this.audioTarget.repeating ?? OFF }
  set repeating(mode) { this.audioTarget.repeating = mode }

  get current() { return this.queue[this.order[this.cursor]] }

  // The words of what is playing, and whose they are. On the <audio> with the
  // rest of the state: the rail is permanent, so after a visit the lines are
  // still standing in it, and a controller that forgot whose they were would
  // fetch and repaint the very words already on the screen, on every navigation.
  get words() { return this.audioTarget.words ?? [] }
  set words(lines) { this.audioTarget.words = lines }

  get wordsFor() { return this.audioTarget.wordsFor }
  set wordsFor(trackId) { this.audioTarget.wordsFor = trackId }

  // Whether the song playing has any words at all — the fact the microphone in
  // the bar is showing. Undefined until the answer comes back.
  get sung() { return this.audioTarget.sung }
  set sung(has) { this.audioTarget.sung = has }

  // And whether they were timed, which is what the rail can follow. Remembered
  // beside them: the rail is opened long after the song was asked about, and the
  // answer has to still be there to paint.
  get synced() { return this.audioTarget.synced ?? false }
  set synced(is) { this.audioTarget.synced = is }

  // Whether next has anywhere to go: another track ahead, or repeat-all to wrap
  // back to the top. Mirrors what next() actually does.
  get hasNext() {
    if (this.cursor + 1 < this.order.length) return true

    return this.repeating === ALL && this.order.length > 0
  }

  // --- Private ---------------------------------------------------------------

  start() {
    const track = this.current
    if (!track) return

    this.brokenTarget.hidden = true
    this.audioTarget.src = track.src
    this.audioTarget.play().catch(() => {})
    this.listenAfresh()
    this.announce(track)
    this.announceToLastfm(track)
    this.render()
  }

  // Told at the first note, not at the halfway mark: what it is for is to put the
  // song on the listener's Last.fm page *while it is playing*. Nothing waits on
  // it and nothing retries it — a now-playing that arrived late would be a lie.
  announceToLastfm({ trackId }) {
    if (!this.scrobblesValue || !trackId) return

    fetch("/now_playing", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: JSON.stringify({ track_id: trackId })
    }).catch(() => {})
  }

  // A song begins unheard. The clock stamped here is the wall clock, because it
  // is when the music started that a history is ordered by and that Last.fm will
  // take — and by the time we have heard enough to say so, it is minutes late.
  listenAfresh() {
    this.listened = 0
    this.heardAt = 0
    this.sampledAt = Date.now()
    this.counted = false
    this.startedAt = Math.floor(Date.now() / 1000)
  }

  // Listening is the time the music ran, not where the thumb ended up. A thumb
  // can be dragged to the end of a song in an instant, having played none of it,
  // and a player that watched the thumb would call that a listen. So only the
  // ground the song covers under its own steam is counted.
  //
  // The clock is what tells the difference. A song cannot have run further than
  // time itself has, so what a tick credits is never more than the seconds that
  // actually passed since the one before it: music that ran asks for exactly what
  // the clock allows, and a leap asks for more and gets only what it is owed.
  //
  // That is the whole of the rule, and it needed to be — `seeking` announces a
  // jump from a queued task while the position changes at once, so a tick can and
  // does land in between. This used to trust that news to arrive first, and a
  // song dragged to its end in the wrong order counted as heard.
  keepListening() {
    const { currentTime, duration } = this.audioTarget
    const sampledAt = Date.now()
    const ran = currentTime - this.heardAt
    const passed = (sampledAt - this.sampledAt) / 1000

    if (ran > 0) this.listened += Math.min(ran, passed)
    this.heardAt = currentTime
    this.sampledAt = sampledAt

    if (this.counted || !Number.isFinite(duration)) return
    if (this.listened < Math.min(duration / 2, ENOUGH)) return

    this.counted = true
    this.remember(this.current)
  }

  // A seek covers no ground: the song is suddenly somewhere else, having played
  // none of the way there, so the mark moves to where the song now is and the
  // stretch it skipped is never counted as heard.
  //
  // This is not what makes that true — the clock in keepListening is, and it holds
  // whether this news comes early or late. What this catches is the one jump the
  // clock cannot: a thumb dragged while the song is paused. No tick runs to bound
  // that leap, and time passes anyway, so the clock would find it justified.
  jumped() {
    this.heardAt = this.audioTarget.currentTime
  }

  // What the machine itself shows about what is playing: the lock screen, the
  // Now Playing tile in Control Center, the media keys on the keyboard. Without
  // this the app is a tab that makes noise; with it, it is what the computer
  // thinks is playing music.
  announce(track) {
    if (!("mediaSession" in navigator)) return

    navigator.mediaSession.metadata = new MediaMetadata({
      title: track.title,
      artist: track.subtitle,
      album: track.albumTitle,
      artwork: [ { src: new URL(track.cover, location.href).href, sizes: "512x512" } ]
    })

    navigator.mediaSession.setActionHandler("play", () => this.audioTarget.play())
    navigator.mediaSession.setActionHandler("pause", () => this.audioTarget.pause())
    navigator.mediaSession.setActionHandler("nexttrack", this.hasNext ? () => this.next() : null)
    navigator.mediaSession.setActionHandler("previoustrack", () => this.previous())
  }

  // History is written once the song has been listened to, and it carries the
  // moment the music started — which by now is minutes ago, and which is the only
  // timestamp a history can be ordered by or a scrobble sent with.
  //
  // Nothing waits on this: a lost play is not worth a stutter, and a NAS that
  // blinked is not worth an error in the console.
  remember({ trackId }) {
    if (!trackId) return

    fetch("/plays", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: JSON.stringify({ track_id: trackId, started_at: this.startedAt })
    }).catch(() => {})
  }

  // Whatever is playing stays where it is; everything else gets dealt again.
  shuffleAround(index) {
    const rest = this.queue.map((_, at) => at).filter((at) => at !== index)

    for (let at = rest.length - 1; at > 0; at--) {
      const swap = Math.floor(Math.random() * (at + 1))
      ;[rest[at], rest[swap]] = [rest[swap], rest[at]]
    }

    return [index, ...rest]
  }

  render() {
    this.renderNowPlaying()
    this.renderControls()
    this.renderTail()
    this.renderQueue()
    this.renderSuggestions()
    this.renderRows()
    this.showLyrics()
    this.save()
  }

  // --- The words -------------------------------------------------------------
  //
  // Nothing here knows a word of any song. The words are an .lrc sitting on the
  // disk beside the file, written by whoever ripped it; the server reads that
  // file and hands the lines over with the moment each one is sung, and the rail
  // shows what it is given.
  //
  // Every song that plays is asked about, open rail or shut. They used to be
  // asked for only while the rail was open — a shut rail is a rail nobody is
  // reading, and the words would have been fetched to be shown to nobody. But
  // the microphone in the bar now shows whether there are any, and a shut rail
  // does not make it disappear: somebody is reading the answer either way. What
  // comes back is one .lrc, a couple of kilobytes, once per song.

  async showLyrics() {
    if (!this.hasLyricsTarget || !this.hasAudioTarget) return

    const track = this.current
    if (!track) return this.nothingToSing("Nothing playing")

    // The words do not change under a song, and render() runs on every press, so
    // a song is asked about once. What came back is simply shown again — which is
    // what opening the rail on a song already asked about does, with no second
    // trip to the disk.
    if (this.wordsFor === track.trackId) return this.renderLyrics()

    this.wordsFor = track.trackId
    this.words = []
    // Not known yet, and not knowing is not the same as knowing there are none:
    // the microphone gets the benefit of the doubt until the answer lands.
    this.sung = undefined
    this.sayLyrics("Looking for the words…")

    try {
      const answer = await fetch(`/tracks/${track.trackId}/lyrics`, { headers: { Accept: "application/json" } })

      // The song moved on while we were asking, and these are the last one's words.
      if (this.wordsFor !== track.trackId) return

      // 404 is the answer, not a failure: most of the record has no .lrc beside it.
      if (!answer.ok) return this.nothingToSing("No lyrics for this song")

      const { synced, lines } = await answer.json()
      if (this.wordsFor !== track.trackId) return

      this.words = lines
      this.synced = synced
      this.sung = true
      this.renderLyrics()
    } catch {
      // A NAS catching its breath is not a song without words, and saying it was
      // would be a lie the listener cannot tell from the truth. Nothing is settled,
      // so the microphone stays alive: pressing it goes and asks again.
      this.wordsFor = null
      this.sayLyrics("Couldn't reach the words")
    }
  }

  // There is nothing to sing, and it is settled: no song at all, or a song nobody
  // wrote the words for. The rail says which, and the microphone that opens the
  // rail goes dead — there is nothing left for it to open.
  nothingToSing(reason) {
    this.sung = false
    this.sayLyrics(reason)
    this.renderLyricsToggle()
  }

  // What is shown of the words: the lines, if the rail is open to take them — and
  // the microphone either way, because it is in the bar, and the bar is always up.
  renderLyrics() {
    this.renderLyricsToggle()

    if (this.lyricsOpen) this.paintLyrics()
  }

  // The microphone opens the words, so it goes dead when there are none to open.
  //
  // And a rail left standing open when such a song comes on has nothing left to
  // show, so it shuts itself. Only for a song with no words: an empty queue is
  // not one, and shutting the rail on it would throw away the choice to have left
  // it open — over nothing more than having pressed nothing yet.
  renderLyricsToggle() {
    if (!this.hasAudioTarget || !this.hasLyricsPanelTarget) return

    const nothing = !this.current || this.sung === false
    this.lyricsToggleTargets.forEach((toggle) => { toggle.disabled = nothing })

    if (this.current && this.sung === false && this.lyricsOpen) this.leaveLyrics(false)
  }

  paintLyrics() {
    this.lyricsPanelTarget.dataset.synced = String(this.synced)
    // A file nobody timed cannot be followed, so the button that would follow it
    // goes dead rather than lying about what it would do.
    this.syncToggleTarget.disabled = !this.synced

    this.lyricsTarget.replaceChildren(...this.words.map((line) => this.lyricLine(line)))
    this.lit = null
    this.followLyrics()
  }

  // A line of the song, and when it is sung. A timed .lrc marks the gaps between
  // the verses as lines with nothing in them — they are what tells the karaoke to
  // stop pointing at the last thing sung, and they show as the rest they are.
  lyricLine({ at, text }) {
    const line = document.createElement("p")
    line.className = "lyric"
    if (at !== null) line.dataset.at = at
    line.textContent = text || "♪"
    if (!text) line.classList.add("opacity-40")

    return line
  }

  // Which line the song is on now, lit, and carried to the middle of the rail.
  // In the gap between two verses nothing is lit at all: the words have run out
  // for a moment, and a karaoke that kept the last line lit through the silence
  // would be pointing at something nobody is singing.
  followLyrics() {
    if (!this.hasLyricsTarget || !this.lyricsOpen || !this.following) return

    const lines = this.lyricsTarget.children
    const now = this.lineAt(this.audioTarget.currentTime)

    if (now === this.lit) return
    this.lit = now

    for (const [ at, line ] of Array.from(lines).entries()) line.setAttribute("aria-current", String(at === now))

    lines[now]?.scrollIntoView({ block: "center", behavior: "smooth" })
  }

  // The last line whose moment has come — and nothing at all if that line is one
  // of the silences, or if the song has not reached the first word yet.
  lineAt(time) {
    let found = -1
    this.words.forEach((line, at) => { if (line.at !== null && line.at <= time) found = at })

    return found >= 0 && this.words[found].text ? found : -1
  }

  // Nothing is being followed, so nothing is lit — the words stand still and are
  // read at whatever pace the reader likes.
  dimLyrics() {
    if (!this.hasLyricsTarget) return

    this.lit = null
    for (const line of this.lyricsTarget.children) line.setAttribute("aria-current", "false")
  }

  // Why there is nothing to sing: no song, no .lrc, or a disk that did not answer.
  sayLyrics(reason) {
    this.words = []
    this.lit = null
    this.lyricsPanelTarget.dataset.synced = "false"
    this.syncToggleTarget.disabled = true

    const said = document.createElement("p")
    said.className = "py-6 text-center text-sm text-neutral-500"
    said.textContent = reason

    this.lyricsTarget.replaceChildren(said)
  }

  get lyricsOpen() {
    return this.hasLyricsPanelTarget && this.lyricsPanelTarget.classList.contains(OPEN)
  }

  // The queue rides on the <audio>, which a full reload throws away. So it is
  // also written to storage, tagged with whose it is: a reload rebuilds a bare
  // <audio> and we put the queue back onto it, but only for the same listener —
  // leaving a profile still takes the music. A source and time set here; the
  // browser may still refuse to resume unasked, and then it waits for a press.
  save() {
    this.wroteAt = performance.now()

    try {
      localStorage.setItem(REMEMBERED, JSON.stringify({
        profile: this.profileValue,
        queue: this.queue, order: this.order, cursor: this.cursor,
        shuffled: this.shuffled, repeating: this.repeating,
        src: this.audioTarget.src || "", time: this.audioTarget.currentTime || 0,
        paused: this.audioTarget.paused,
        listened: this.listened, heardAt: this.heardAt, startedAt: this.startedAt, counted: this.counted
      }))
    } catch { /* private windows and full disks just forget; the tab still plays */ }
  }

  // Where in the song we are changes four times a second, and writing to
  // localStorage is synchronous and lands on disk. Serialising the whole queue
  // that often, forever, is the only busy loop in the app — and nobody needs a
  // refresh to land on the exact second. Every change that matters (a track, a
  // press, the order) still writes at once, through render() and refreshIcons().
  savePosition() {
    if (this.wroteAt && performance.now() - this.wroteAt < REMEMBER_EVERY) return

    this.save()
  }

  // Only a brand-new <audio> is rebuilt: after a Turbo visit the element is the
  // same one, still carrying its queue, and must be left alone.
  restore() {
    if (this.audioTarget.queue !== undefined) return

    const saved = this.remembered()
    if (!saved || saved.profile !== this.profileValue || !saved.src) return

    this.queue = saved.queue
    this.order = saved.order
    this.cursor = saved.cursor
    this.shuffled = saved.shuffled
    this.repeating = saved.repeating

    // A reload in the middle of a song is not leaving the song, so what was
    // heard of it before the reload is still heard. Without this, refreshing the
    // page would quietly abandon a play the listener was most of the way through.
    this.listened = saved.listened ?? 0
    this.heardAt = saved.heardAt ?? 0
    this.startedAt = saved.startedAt || Math.floor(Date.now() / 1000)
    this.counted = saved.counted ?? false

    this.audioTarget.src = saved.src
    this.audioTarget.addEventListener("loadedmetadata", () => { this.audioTarget.currentTime = saved.time }, { once: true })
    if (!saved.paused) this.audioTarget.play().catch(() => {})
  }

  remembered() {
    try {
      return JSON.parse(localStorage.getItem(REMEMBERED))
    } catch {
      return null
    }
  }

  renderNowPlaying() {
    const track = this.current

    this.idleTarget.hidden = Boolean(track)
    this.titleTarget.hidden = !track
    if (!track) {
      this.subtitleTextTarget.textContent = ""
      this.clearBackdrop()
      this.clearAccent()
      return
    }

    this.titleTextTarget.textContent = track.title
    this.titleTarget.href = track.album
    this.subtitleTextTarget.textContent = track.subtitle

    this.coverTarget.src = track.cover
    this.coverTarget.classList.remove("hidden")

    this.marquee(this.titleTarget, this.titleTextTarget)
    this.marquee(this.subtitleTarget, this.subtitleTextTarget)

    this.setBackdrop(track.cover)
    this.wear(track.palette)
  }

  // A title or artist too long for its lane scrolls, pausing at each end, and
  // sits still when it fits. The distance is measured after layout, and drives
  // both how far it travels and how long it takes — long titles don't race.
  marquee(lane, text) {
    lane.classList.remove("is-scrolling")
    lane.style.removeProperty("--marquee-shift")
    lane.style.removeProperty("--marquee-duration")

    requestAnimationFrame(() => {
      const overflow = text.scrollWidth - lane.clientWidth
      if (overflow <= 2) return

      lane.style.setProperty("--marquee-shift", `-${overflow}px`)
      lane.style.setProperty("--marquee-duration", `${Math.max(6, overflow / 25)}s`)
      lane.classList.add("is-scrolling")
    })
  }

  // The cover of what's playing washes the whole floor. Two layers cross-fade:
  // paint the next cover on the layer that's hidden, then trade their opacities.
  setBackdrop(cover) {
    if (!this.hasBackdropTarget || !cover) return

    const shown = this.backdropTargets.find((layer) => layer.classList.contains("opacity-100"))
    if (shown?.dataset.cover === cover) return

    const next = this.backdropTargets.find((layer) => layer !== shown)
    next.style.backgroundImage = `url("${cover}")`
    next.dataset.cover = cover
    next.classList.replace("opacity-0", "opacity-100")
    shown?.classList.replace("opacity-100", "opacity-0")
  }

  // Nobody playing, no wash: both layers fade back to the bare backdrop.
  clearBackdrop() {
    if (!this.hasBackdropTarget) return

    this.backdropTargets.forEach((layer) => {
      layer.classList.replace("opacity-100", "opacity-0")
      delete layer.dataset.cover
    })
  }

  // --- The look, taken from the record ----------------------------------------
  //
  // The colour is not worked out here. Rails read the sleeve, picked the one
  // striking colour on it, and derived the whole look from that; what arrives on
  // the row is the finished thing — the custom properties, ready to set. This
  // controller does not know what a hue is, and does not need to.
  //
  // They go on <html>, which retints everything at once — the Play button, the
  // playing row, the equalizer, the wash in the corners of the room — and which
  // survives Turbo, so the colour rides across navigation.
  wear(palette) {
    if (!palette) return

    const root = document.documentElement.style
    for (const [property, value] of Object.entries(JSON.parse(palette))) {
      root.setProperty(property, value)
    }
  }

  // Back to the standing Apple-red theme defaults when nothing is playing.
  clearAccent() {
    const root = document.documentElement.style
    for (const name of [
      "--color-accent", "--color-accent-bright", "--color-on-accent", "--gel-glow", "--ambient-tint"
    ]) root.removeProperty(name)
  }

  // Shuffle and repeat moved off the mini-player; when their buttons aren't on
  // the page there is nothing to keep in sync.
  renderControls() {
    if (!this.hasShuffleTarget) return

    this.shuffleTarget.setAttribute("aria-pressed", String(this.shuffled))
    this.repeatTarget.setAttribute("aria-pressed", String(this.repeating !== OFF))
    this.repeatOneTarget.hidden = this.repeating !== ONE
  }

  // The end of the queue, said out loud: next has nowhere to go, so dim it, and
  // if a track is actually playing it out (not looping on one), name the end.
  renderTail() {
    this.nextTarget.disabled = !this.hasNext
    this.tailTarget.hidden = !(this.current && !this.hasNext && this.repeating !== ONE)
  }

  renderQueue() {
    const base = this.cursor + 1
    const upcoming = this.order.slice(base).map((at, offset) => this.queueRow(at, base + offset))

    const children = []
    if (this.current) children.push(this.queueSection("Now Playing"), this.nowPlayingRow(this.current))
    if (upcoming.length) children.push(this.queueSection("Next Up"), ...upcoming)
    this.queueTarget.replaceChildren(...children)

    const empty = upcoming.length === 0
    this.queueEmptyTarget.hidden = !empty
    // Repeat-all never runs out: the queue loops back rather than ending.
    this.queueEmptyTarget.textContent =
      empty && this.repeating === ALL && this.order.length > 0 ? "Repeats from the top." : "Nothing up next."

    this.repeatBadgeTarget.hidden = this.repeating === OFF
    this.repeatBadgeTextTarget.textContent = this.repeating === ONE ? "Repeat One" : "Repeat"
  }

  // "Nothing up next" was the end of it, and it needn't be: the rest of the
  // artist is still on the disk. So the rail asks the library what is left of
  // them and stands the answer where the queue ran out.
  renderSuggestions() {
    if (!this.hasSuggestionsTarget) return

    const track = this.current

    // Already offered for this song: leave them standing, minus whatever was
    // taken. Asking again on every render would flicker the rail and pester the
    // library for an answer that has not changed.
    if (track && this.offeredFor === track.trackId) return

    this.withdrawSuggestions()

    // Something is up next, so nothing needs suggesting — and on repeat-all the
    // queue never runs out at all.
    if (!track || this.hasNext) return

    this.offeredFor = track.trackId
    this.askWhatIsLeft(track)
  }

  async askWhatIsLeft(track) {
    const queued = this.queue.map((queued) => queued.trackId).join(",")

    try {
      const answer = await fetch(`/tracks/${track.trackId}/suggestions?queued=${queued}`,
        { headers: { Accept: "application/json" } })
      const { heading, tracks } = await answer.json()

      // The song moved on while we were asking, and these are last song's offers.
      if (this.offeredFor !== track.trackId) return

      this.offerSuggestions(heading, tracks)
    } catch {
      // A rail that cannot reach the library says what it always said: nothing
      // up next. Silence beats an error where the music should be.
    }
  }

  offerSuggestions(heading, tracks) {
    if (!tracks.length) return this.withdrawSuggestions()

    this.suggestionsTarget.replaceChildren(this.queueSection(heading), ...tracks.map((track) => this.suggestionRow(track)))
    this.suggestionsTarget.hidden = false
    this.queueEmptyTarget.hidden = true
  }

  withdrawSuggestions() {
    this.offeredFor = null
    this.suggestionsTarget.replaceChildren()
    this.suggestionsTarget.hidden = true
  }

  // An offer wears the same clothes as a queue row, only dimmer — it is not a
  // plan yet, and the rail should not read as though it were.
  suggestionRow(track) {
    const item = document.createElement("li")
    item.className = "opacity-50 transition hover:opacity-100"

    const take = document.createElement("button")
    take.type = "button"
    take.setAttribute("aria-label", `Queue ${track.title}`)
    take.className = "flex w-full min-w-0 items-center gap-2.5 rounded-lg p-1.5 text-left transition hover:bg-white/10"
    take.dataset.action = "player#enqueue"
    Object.assign(take.dataset, track)
    take.append(this.queueArt(track), this.queueText(track))

    item.append(take)
    return item
  }

  // Taking an offer is not playing it: it goes to the end of the queue and what
  // is playing keeps playing. And it stops being an offer, because it is a plan.
  enqueue(event) {
    const offer = event.currentTarget

    this.queue = [ ...this.queue, { ...offer.dataset } ]
    this.order = [ ...this.order, this.queue.length - 1 ]

    offer.closest("li").remove()
    // The last one taken leaves a heading over nothing.
    if (!this.suggestionsTarget.querySelector("button")) this.withdrawSuggestions()

    this.render()
  }

  // A quiet header inside the list to tell "Now Playing" from "Next Up".
  queueSection(label) {
    const li = document.createElement("li")
    li.className = "select-none px-1.5 pb-1 pt-3 text-[11px] font-semibold uppercase tracking-wider text-neutral-500 first:pt-1"
    li.textContent = label
    return li
  }

  // What's on now: art, title and artist, lit in accent behind an equalizer. It
  // doesn't move and can't be dropped — it isn't up next, it's playing.
  nowPlayingRow(track) {
    const item = document.createElement("li")
    item.className = "flex items-center gap-2.5 rounded-lg bg-white/5 p-1.5 ring-1 ring-inset ring-white/10"

    const meter = document.createElement("span")
    meter.className = "shrink-0 pr-0.5 text-accent"
    meter.setAttribute("aria-hidden", "true")
    meter.innerHTML = '<span class="eq"><i></i><i></i><i></i><i></i></span>'

    item.append(this.queueArt(track), this.queueText(track, "text-accent"), meter)
    return item
  }

  // A queue row: art, title and artist, click to jump to it. The whole row is a
  // drag handle for reordering; the × to drop it surfaces on hover. position is
  // its index into the play order, so drag and remove speak the same
  // coordinates.
  queueRow(at, position) {
    const track = this.queue[at]

    const item = document.createElement("li")
    item.className = "group flex items-center gap-1 rounded-lg pr-1 transition hover:bg-white/10"
    item.draggable = true
    item.dataset.pos = position
    item.dataset.action = "dragstart->player#dragStart dragover->player#dragOver drop->player#drop dragend->player#dragEnd"

    const jump = document.createElement("button")
    jump.type = "button"
    jump.setAttribute("aria-label", track.title)
    jump.className = "flex min-w-0 flex-1 cursor-grab items-center gap-2.5 rounded-lg p-1.5 text-left active:cursor-grabbing"
    jump.dataset.action = "player#jump"
    jump.dataset.playerAtParam = position
    jump.append(this.queueArt(track), this.queueText(track))

    const remove = document.createElement("button")
    remove.type = "button"
    remove.setAttribute("aria-label", `Remove ${track.title} from the queue`)
    remove.className = "shrink-0 rounded-full p-1.5 text-neutral-500 transition hover:bg-white/10 hover:text-white group-hover:text-neutral-300"
    remove.dataset.action = "player#removeFromQueue"
    remove.dataset.playerAtParam = position
    remove.innerHTML = '<svg class="size-3.5" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true"><path d="M4.28 3.22a.75.75 0 0 0-1.06 1.06L6.94 8l-3.72 3.72a.75.75 0 1 0 1.06 1.06L8 9.06l3.72 3.72a.75.75 0 1 0 1.06-1.06L9.06 8l3.72-3.72a.75.75 0 0 0-1.06-1.06L8 6.94 4.28 3.22Z"/></svg>'

    item.append(jump, remove)
    return item
  }

  // The small album thumbnail every queue row wears.
  queueArt(track) {
    const art = document.createElement("img")
    art.src = track.cover
    art.alt = ""
    art.className = "size-10 shrink-0 rounded object-cover shadow ring-1 ring-white/10"
    return art
  }

  // A title over a dimmer artist, each clipped to one line.
  queueText(track, titleColor = "text-neutral-100") {
    const text = document.createElement("span")
    text.className = "min-w-0 flex-1"

    const title = document.createElement("span")
    title.className = `block truncate text-sm font-medium ${titleColor}`
    title.textContent = track.title

    const artist = document.createElement("span")
    artist.className = "block truncate text-xs text-neutral-400"
    artist.textContent = track.subtitle

    text.append(title, artist)
    return text
  }

  // --- The queue, rearranged ---------------------------------------------------

  dragStart(event) {
    this.dragFrom = Number(event.currentTarget.dataset.pos)
    event.dataTransfer.effectAllowed = "move"
    event.currentTarget.classList.add("opacity-40")
  }

  // Something can only be dropped where dropping was allowed.
  dragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
  }

  drop(event) {
    event.preventDefault()
    this.moveInQueue(this.dragFrom, Number(event.currentTarget.dataset.pos))
  }

  dragEnd(event) {
    event.currentTarget.classList.remove("opacity-40")
  }

  // Only what hasn't played yet moves, so the cursor and everything behind it
  // stay put while the tail is redealt.
  moveInQueue(from, to) {
    if (Number.isNaN(from) || Number.isNaN(to) || from === to) return

    const base = this.cursor + 1
    const tail = this.order.slice(base)
    const [moved] = tail.splice(from - base, 1)
    tail.splice(to - base, 0, moved)

    this.order = [...this.order.slice(0, base), ...tail]
    this.render()
  }

  removeFromQueue({ params: { at } }) {
    const base = this.cursor + 1
    const tail = this.order.slice(base)
    tail.splice(at - base, 1)

    this.order = [...this.order.slice(0, base), ...tail]
    this.render()
  }

  // The album page can be any album, or none. Only the row that is playing gets
  // marked, and only if it is on screen.
  renderRows() {
    this.rowTargets.forEach((row) => this.mark(row))
  }

  mark(row) {
    const playing = this.hasAudioTarget && this.current?.src

    row.setAttribute("aria-current", String(Boolean(playing) && row.dataset.src === playing))
  }

  clock(seconds) {
    if (!Number.isFinite(seconds)) return "–:––"

    const minutes = Math.floor(seconds / 60)
    const rest = Math.floor(seconds % 60)

    return `${minutes}:${String(rest).padStart(2, "0")}`
  }
}
