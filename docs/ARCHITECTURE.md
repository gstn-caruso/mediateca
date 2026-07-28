# How Mediateca is built

This is the long version — the decisions, and what they cost before they were
made. The short version is the [README](../README.md).

- [The disk decides what music exists](#the-disk-decides-what-music-exists)
- [Serving the bytes](#serving-the-bytes)
- [The player outlives the page](#the-player-outlives-the-page)
- [The player goes where it is put](#the-player-goes-where-it-is-put)
- [The panels are as wide as you keep them](#the-panels-are-as-wide-as-you-keep-them)
- [Nothing that isn't navigation navigates](#nothing-that-isnt-navigation-navigates)
- [An app, not a tab](#an-app-not-a-tab)
- [Who is listening](#who-is-listening)
- [What comes next, and who you would rather it didn't be](#what-comes-next-and-who-you-would-rather-it-didnt-be)
- [Search](#search)
- [No page asks the database one question per row](#no-page-asks-the-database-one-question-per-row)
- [The phone](#the-phone)
- [The tests](#the-tests)
- [CI](#ci)
- [Traps we already paid for](#traps-we-already-paid-for)

---

## The disk decides what music exists

beets only says what it's called.

`Music::FilesystemSource` scans the music and reads each FLAC's tags with
ffprobe: all 1171 files, not the 934 beets knows about. `Beets::Library`
contributes what it knows. `Music::Library` combines them, and `Music::Importer`
mirrors the result into the catalog, idempotently: the directory identifies the
album and the path identifies the track.

The cover art is chosen by the disk, not beets: beets had picked the back cover
for all six Almafuerte albums.

### A song that moved is still the song

A directory names an album and a path names a track, which means renaming a file
makes the scan meet the same song as a stranger: the old row goes, and
`dependent: :destroy` takes the playlists, the hearts and the whole play history
with it — at 4am, silently. So before anything is discarded, `Music::Move` pairs
what vanished with what arrived, each side naming itself: a record by whose it is
and what it is called, a song by where it sits on the record and what it is
called. It refuses to guess — a name two things answer to names neither of them,
and handing a playlist a song nobody put there is worse than losing the entry.

### One unreadable file does not cost the scan

ffprobe raises on a truncated copy, and nothing caught it: `ScanMusicJob` died on
the first bad file and every night after did the same, so the library just
stopped growing and nothing said why. A file nothing can read is a file nothing
can play; the scan steps over it and carries on. A *missing binary* is not a bad
file, though — that one still raises, because swallowing it would skip every
track and call the library empty.

### A song says who sings it

Usually that is simply whoever made the record, and `tracks.artist` is null — but
a guest, a duet or a compilation says otherwise on the file itself, and the file
is the one to believe. It is a credit, not an `artist_id`. beets, asked first,
said this happens to exactly one track in the 934 it knows — but the disk, which
knows all 1171 and is the one that decides, says **36**: *"Luis Alberto Spinetta,
Pedro Aznar y Charly García"* on a Charly García record, *"Indio Solari y Los
Fundamentalistas del Aire Acondicionado"* across most of Indio's. Those are
credit lines, not people you own records by, and rows for them would fill the
library rail with artists who have no albums.

## Serving the bytes

The bytes never pass through Ruby. In production Rails only names the file with
the `X-Sendfile` header and **Thruster** serves it, with `Range` support — that
is, the player can seek without downloading the whole FLAC. In development
there's nothing in front, so Rails serves with `Rack::Files`, which also
implements `Range`. The rule, written down in `ServesMedia`: *whoever serves the
file serves the range too.*

`MediaFile` is the trust boundary. The paths come out of the database, and it
rejects any that fall outside the media root: `..`, absolute paths, sibling
directories with the same prefix (`/mnt/data-secret` is not inside `/mnt/data`)
and symlinks that point outside.

Nothing gets transcoded. The FLACs are served raw and every modern browser plays
them natively.

### A picture arrives at the size it is going to be drawn

The music is never touched. The pictures are, and they had to be: the library
rail draws every artist and every record at forty-four pixels a side, and it was
sending the scan to do it — 133 sleeves on this NAS, 68 MB of them, 527 KB each.
A phone downloaded every byte, and then decoded a 1500×1500 JPEG into nine
megabytes of bitmap, once per row. Nothing on screen was any better for it.

So `Music::Thumbnail` draws a picture once at each size the app actually uses —
96 for a row and for the pill, 320 for a tile in a grid, 640 for the sleeve at
the top of a record's own page and for the lock screen of a phone, 64 for the
light behind a title — and keeps it under `storage/`, beside the portraits.
ffmpeg was already in the image and already decoding sleeves: the colour the app
wears is read off them.

The sizes are a **list**, not a number out of the URL: a URL that can ask for any
size is a URL that can ask the NAS to draw ten thousand of them. A picture ffmpeg
cannot read — a `cover.jpg` somebody's ripper wrote in 2006 — is handed over
whole, exactly as it was before. That row of 44px sleeves went from 68 MB to
about 300 KB.

## The player outlives the page

The player lives outside the `<body>` that Turbo Drive replaces when you navigate
(`data-turbo-permanent`), and the playback queue is stored **in the `<audio>`
element**, not in the Stimulus controller — which Turbo destroys and rebuilds on
every page. That's why the music doesn't cut out when you switch views. A full
reload does throw the element away, so the queue is also written to
`localStorage`, tagged with whose it is: the next listener does not inherit the
last one's music. That write happens **when the queue changes**, and the passing
of the song at most every five seconds — it used to serialise the whole queue on
every `timeupdate`, four times a second, forever, synchronously, on the main
thread.

The OS is told what's playing (`MediaSession`), so the media keys, Control Center
and the lock screen drive it. Without that the app is a tab that makes noise.

The play history is written by the player when a track starts, not by the stream
endpoint: `preload=metadata` asks for the file before anybody presses play, and
every seek asks for it again.

## The player goes where it is put

Being permanent also means it can be *moved*. `pill` picks the player up by
anything on it that is not a control — the transport is pressed and the scrubber
is dragged for a living, so neither is a handle — and puts it down wherever the
hand lets go, held inside the room, because a player dragged over the edge is
gone for good: there is no scrolling to it, and it is the only transport there
is.

Pushed into the floor, it stops being a pill and becomes the bar across the foot
of the room, the whole width of the row. What decides that is **the pointer, not
the player**: the pill already rests a touch above the bottom, so a player that
docked when its own foot reached the floor would dock on a nudge. The room holds
it back at the floor, the hand goes on pushing past where it can follow, and that
push is the ask — a window thrown at the edge of a screen.

And docked, it stops floating altogether: the room is a column, and the bar comes
down into the flow as its last row. The panels above are handed what is left, so
they end where the bar begins rather than running on underneath it. That is also
what takes the clearance back off the songs — the empty inch under the list and
the fade that dissolves them into it are both there for a pill floating over the
foot of it, and a bar in a row of its own floats over nothing.

Where it was left is written to `localStorage`, for the same reason the queue is:
the element rides through a Turbo visit on its own, but a cold load builds it
again out of HTML the server wrote knowing nothing about anybody's hand. And, as
with the queue, the controller is asked nothing — the element carries its own
state, in two classes and two custom properties, and the CSS does the placing.

## The panels are as wide as you keep them

All four were nailed to 18rem: the library, the picture, the words and the queue.
It is a fine width for a rail of artists and a poor one for a page of lyrics, and
nobody had ever been asked. Now each is taken by its edge and given the room it is
short of, and 18rem is only where a panel starts.

**The width belongs to the listener, and this is the one piece of the layout that
does.** Where the queue was left open, where the pill was put down, which turn of
the library you were on — a browser remembers all of those for itself, in
`localStorage`, because they are about the tab you are standing in front of. A
width is not. It is about the eyes reading it, and the same eyes come back on the
laptop and on the kitchen tablet and want the same room on both. So a `Panel` is a
row: one listener, one panel, one width, replaced rather than added to, exactly as
a standing is — and having no row at all is the ordinary case, because most people
never drag anything.

**The width is worn by `<html>`, not by the panels.** Turbo replaces the `<body>`
on every visit, and the library rail is the one panel that cannot be permanent: it
has to know which page you are standing on, so it is rebuilt each time. A width
kept on that element would be gone the moment you clicked an artist — and reading
it back off the server would put a `PATCH` nobody waited for in a race with the
`GET` of whatever was clicked next. Lose that race and the rail comes back at the
width it no longer has. So the hand writes the width on the room, which is the one
element a visit does not touch, and every page drawn afterwards is already wearing
it. Each panel says only which of the room's four numbers is its own; the CSS does
the sizing.

**The room holds them, and holds them back.** A hand can widen a rail until the
content is down to the least room a page can be read in, and not one pixel further
— a library with nothing left to be a library *of* is not a thing anybody meant to
drag. That has to go on being true afterwards, too: a window narrowed, or a second
rail opened beside the first, takes the same room a hand would have. So a panel
watches the content rather than waiting to be told, because a rail opening is not
the panel's business to know about and the content is. What it may take back is
what a hand added, and never what the app shipped: on a tablet with a rail open the
content is *already* under that floor and has been since long before any of this,
and a room allowed to take back whatever it liked would answer that by shrinking
rails nobody had ever touched.

**And the app holds the ends of the rope too, not only the browser.** A request is
not a hand. There is no password here, and anybody on the LAN can send this app any
number they like — so a width is held between its two ends where it is *written
down*, and not only out there where it was dragged.

The grips are 8px of nothing at a panel's edge, and where they can sit is decided
by what is already there. The library's goes out into the gap beside it: nothing
clips that rail, and its own right edge is where its scrollbar lives — a handle
laid over that would have quietly stolen the scrollbar. The other three are clipped
to their own rounded corners, so anything hanging outside them is simply cut off;
theirs sit just inside their near edge, which is the one strip of a rail with
nothing on it. On a phone there are none at all: a rail there does not stand beside
the content, it comes over the top and takes the screen, and there is no seam
between two things to take hold of.

## Nothing that isn't navigation navigates

A heart, and a song added to a playlist, answer with a Turbo Stream and change in
place. They used to be full page visits: the scroll jumped back to the top of the
record, the page faded in again, and the history took one more entry pointing at
the URL you were already on, once per heart — so Back walked you through your own
hearting. A system test counts `history.length` and fails if it grows.

The one page where swapping the heart isn't enough is the list of hearts itself:
a song unhearted is not a liked song, so the stream removes its row too. It says
so unconditionally — on every other page there is no such row and Turbo removes
nothing. And when that takes the last row, the page has to *become* the page it
now is: no buttons to play nothing with, and a line saying so. That is already
true in the DOM, so `:has` reads it off the list instead of asking the server to
re-render everything to discover it.

## An app, not a tab

Add it to the Dock and Mediateca is a window with its own icon and no address
bar. That much is a manifest and an icon, and it needs nothing else: it works
over the plain HTTP the app is deployed with by default.

The service worker is the half that needs a certificate — a browser hands one out
only to a page it considers secure — and what it does is deliberately small. It
answers **navigations**, and only the ones the network didn't, with a page that
says the server is gone. It does not cache the app, and it should not: the music
is on the far side of the network that just went away, and a library with no songs
in it is not worth pretending to. What it is really for is that a window with no
address bar and no reload button has no way to explain itself; left to the
browser's error page, a NAS that is rebooting looks like an app that broke.

Everything else it touches by leaving alone — the covers, the searches, and above
all the stream, which is asked for one byte range at a time. A worker that
answered a range request with a whole file, or with a cached one, would break
seeking in a way that is very hard to see and very easy to ship.

Where there is no certificate there is simply no worker: `navigator.serviceWorker`
is not there to ask, and the app is a tab that works. So the registration asks,
and doesn't insist.

## Who is listening

Whoever is listening picks themselves off a grid, the way Netflix asks. **There
is no password**: whoever holds the cookie is whoever it names. On a home LAN
that is the whole of signing in, and it is a trade made on purpose — anybody on
the network can be anybody. Playlists, hearts and the play history hang off
`Current.profile`, and a playlist is looked up *through* it, so somebody else's
simply does not exist. That lookup is what stands in for a password.

The cookie outlives the profile it names — a browser left open on the kitchen
tablet still remembers somebody deleted last week — so a name that no longer
exists means nobody is listening, and the picker comes back.

## What comes next, and who you would rather it didn't be

A home library has no recommender and needs none. The honest answer to "what
now" is more of whoever you are already listening to, and only once they run
out, anything else that is on the disk — and `Suggestions` says which of the two
it found, so the rail can offer the second for what it is rather than dressing
it up as the first.

What a listener has said about an artist bends both halves of that. A
**standing** is where one listener stands on one artist, and there are only two,
and they are opposites — so it is one row, replaced rather than added to, and
having no row at all is the ordinary case. Most artists are simply artists.

**Hidden** is not deleted. The disk decides what music exists, and a scan at 4am
would bring back anything this could delete; what it removes is not the music but
the *offering* of it. Everything the library does on its own stops doing it — the
rail, the shelf of records, the hearts, the playlists, the recently-played, and
the rail of what's next, which will not offer them even while they are playing,
because putting a record on by hand is not asking to be handed more of it. And
everything you ask for by name still answers: search finds them, their page still
loads, and that page is where the hiding is taken back. A playlist entry is left
undrawn rather than thrown away — somebody who changes their mind wants the list
they made back, not one with a hole in it.

**Highlighted** is the same gesture pointed the other way. A couple of the rail's
five slots are theirs whatever else is on, and they go to the songs of theirs the
listener actually goes back to: *featured songs* is not a list anybody keeps here
and does not need to be, because the play history has been writing it down all
along. A song nobody has played counts nothing and sorts last, which is also the
answer for an artist highlighted but never heard — any of them, then.

And when the artist runs out and the library is drawn from, a highlighted artist
is *heavier* in the draw rather than merely present in it: their songs go into
the hat threefold, the hat is shuffled, and each song is kept where it first
turns up. The draw happens in Ruby because a weighted draw is the one thing SQL
makes hard to say plainly — and because SQLite's `RANDOM()` is a signed 64-bit
integer, so multiplying one is not a weight, it is a bug that looks like one.
Only the ids are drawn; the five songs are fetched once they are known.

Pressing any of it answers with **the page you were standing on**, not a piece of
it: hiding somebody changes the page in more places than the button pressed, and
Turbo reads a visit to the URL you are already at as a refresh, which here is a
morph. The library rearranges itself in place, the scroll stays, the history
takes no entry for an opinion, and the morph steps around the permanent `<audio>`
— the music does not stutter. `turbo_stream.refresh` looks like the shorter way
to say that and is not: it carries the request id, and Turbo pointedly ignores a
refresh a tab asked for itself. It is for telling the *other* tabs.

## Search

Search is a `LIKE` scan, not FTS5: a thousand tracks scan faster than the page
paints, and an index would be a second copy of the truth to keep in step with the
disk. `%` and `_` are wildcards there, so both are escaped — and the escape
character is *declared*, because SQLite reads a backslash as a backslash
otherwise, and the escaping quietly does nothing. It is capped at 50 per kind: a
search is for finding something, not for reading the library out, and nobody
scrolls the six hundredth song with an "a" in it — but the page would have
rendered all six hundred, and clicking one would have queued them.

## No page asks the database one question per row

The sidebar is on every page in the app, and it counted each artist's records one
`COUNT` at a time; the album page asked, per song, whether that song was hearted;
the playlist page walked entry → track → album → artist a row at a time. None of
it announced itself — it just got slower with every record added.
`test/integration/asking_the_database_once_test.rb` holds every page to the rule:
render it, grow the library tenfold, render it again, and the number of queries
must not move. Counting queries exactly is brittle; counting the *slope* is the
thing we mean.

## The phone

The sidebar is desktop-only, so on a phone the library, the hearts and the way
out of a profile live in the top bar instead. The queue used to be desktop-only
too — twice over, since the button that opened it was hidden below `md` and the
class it toggled had no effect there anyway — so a phone had no queue at all. It
opens over the content now rather than beside it: 390px split in two is two
columns of nothing. A system test at 390px holds every page to no sideways
scroll.

### Nothing filters its backdrop, and nothing blurs a bitmap

The app was built out of Liquid Glass: six panes — the bar, the rail, the queue,
the words, the picture, the pill — each one blurring and saturating everything
standing behind it, over a cover blurred at 56px across the whole screen, with a
second blurred sleeve behind the title of every page.

A `backdrop-filter` is not painted once. Every frame, the browser copies out what
is behind the pane, blurs it, and draws the pane back over the top. On the machine
this was designed on, all of it is free; on a cheap Android it is the difference
between an app and a slideshow. So the panes are panels — one colour, one hairline
— and the room keeps the record's colour the way it always really had it: an
ambient gradient the server derives from the sleeve.

The picture behind a title is still there, and still blown up until it is only
light: 64 pixels the browser stretches across the header, five hundred bytes on
the wire instead of five hundred kilobytes.

**The blur moved; it did not go.** This first shipped claiming that a picture
stretched seventeen times *is* a blur — same arithmetic, done for free by the
scaler. It is not. Stretching interpolates, and an interpolated edge is still an
edge: the wash came back with the sleeve's lettering legible and the JPEG's own
8×8 grid — a whole eighth of a 64px picture — spread into soft squares a hand's
width across. So the edges are taken out where a blur is cheap, which is one
ffmpeg, once, on a picture already down to 64 pixels: `Music::Thumbnail::LIGHT`
is the one size that is not a picture, and it is drawn through `gblur`.

The light carries `-light` in its filename, and that is not decoration. A
thumbnail is only redrawn when the picture it came off changes, and a sleeve
sitting on a NAS does not change — a light answering to the name the sharp one
already had would never have been drawn at all, and every record anybody had
opened would have kept its pixelated wash for ever, on a fix that passed all of
its tests.

The rule is a test, not a note in the stylesheet: `StayingLightTest` walks the
room with everything in it open and fails if anything filters its backdrop or
asks the GPU to blur a picture. Reduce Transparency and Increase Contrast are
gone with the thing they existed to switch off — every pane is now what those
settings used to turn it into, for everybody.

## The tests

The tests **never touch a real music library**: `Beets::Library` runs against
SQLite databases built on the fly, and `MEDIA_ROOT` points at a few real FLACs in
`test/fixtures/media` — thirty seconds of silence each, which FLAC packs into
12KB. They used to be 50-byte stubs: enough to be *served*, so the `Range` test
meant something, but not enough to be *played*. Which meant no system test had
ever played a note — every one of them was watching a player that had silently
failed to load, and neither the end of a song nor the equalizer could be tested
at all.

**And they don't need ffprobe.** `Music::Tags` reads a description we wrote
ourselves (`FakeFfprobe`), so the whole suite runs with no binary and no file.
Running a process is a separate responsibility, and it lives in `Ffprobe`.

The one that *does* run it is `test/contracts/ffprobe_contract_test.rb`, and it
verifies the one thing nothing else can: that ffprobe still describes a FLAC the
way `Music::Tags` assumes it does. Those assumptions are not obvious — ffprobe
hands back `TITLE` and `album_artist` and `track` in whatever case the tagger
typed them, a `DATE` that may be a whole date, and a track number that may carry
its total. Change ffprobe and any of them could quietly stop being true; the scan
would keep running and the library would come back nameless. It is skipped when
ffprobe isn't installed — except under `REQUIRE_FFPROBE=1`, which is how CI runs
it, so it can never come up green without having actually run.

## CI

Six jobs in GitHub Actions, on every push and every PR:

| Job | What it does |
|---|---|
| Tests | `bin/rails test` |
| System tests | Headless Chrome, uploads screenshots on failure |
| Style | RuboCop (rubocop-rails-omakase) with cache |
| Security (Ruby) | Brakeman + bundler-audit |
| Security (JavaScript) | `importmap audit` |
| Docker image (amd64) | builds the image, brings it up and checks that `/up` answers |

That last job exists because a build that compiles but doesn't start proves
nothing, and a deploy is not the moment to find out.

Brakeman flags the `send_file` in `ServesMedia` because the path comes from a
model attribute. The category is right; the guard it can't see is `MediaFile`.
It's ignored with a note in `config/brakeman.ignore`.

A merge to `main` cuts the version the change earned — `lib/next_version.rb`
reads the conventional commit and decides the bump — and deploys it. The tag is
cut *before* the deploy, because the deploy bakes it into the image, but it is
pushed only after the deploy survives: a build that fails leaves no tag promising
something that was never alive.

## Traps we already paid for

**Port 5000 is useless on macOS.** The AirPlay receiver (ControlCenter) listens
on `*:5000` over both IPv4 and IPv6. Docker binds `127.0.0.1:5000`, but
`localhost` resolves to `::1` first, so the registry push ends up talking to
AirTunes, which answers `403 Forbidden` with a `Server: AirTunes/...` header.
Hence the `5555`.

**Kamal and a git in Spanish.** Kamal decides whether its build clone already
exists by matching git's error against `already exists and is not an empty
directory`. A localized git says something else, the regex doesn't match, and
instead of resetting the clone Kamal deletes it and clones it again on **every**
deploy, after printing an `Error preparing clone` that looks scary and means
nothing. That's why `bin/kamal` sets `LC_ALL=C`: the deploy drops from 79s to 9s.

**Rails answers 422 to a JavaScript GET.** A service worker is fetched by a
plain, non-XHR `GET`, and forgery protection reads a JavaScript response to one of
those as somebody else's `<script>` tag helping itself to your page:
`ActionController::InvalidCrossOriginRequest`, `422`, and the worker never
installs. Worse, the error page *quotes the template it died rendering* — so a
test that only looked for a string in the body passed against the 422. Hence
`skip_forgery_protection` in `PwaController`, and an `assert_response :success`
before every assertion about a body.

**TLS that ends at the proxy is TLS Rails cannot see.** kamal-proxy holds the
certificate and forwards plain HTTP inwards, so Rails goes on writing `http://`
URLs into an `https://` page — `stream_url` among them, which the browser then
refuses as mixed content. The music stops and nothing says why. `TLS_HOST` is what
tells Rails to assume the scheme it cannot see (`config.assume_ssl`).

**Rails 8.1 leaves the production SQLite paths commented out** in
`config/database.yml`. Without filling them in, the container dies on startup
with `No database file specified`.

**`/var` is a small partition on most NAS boxes** (6.4 GB on ours) and that is
where both Docker's `data-root` and containerd's go by default. With two images
and the build cache it fills up, and the app dies with `SQLite3::FullException:
database or disk is full`. Both have to move — moving only Docker's isn't enough,
because since Docker 23 the images live in containerd's content store. The
commands are in the [README](../README.md#preparing-the-server).
