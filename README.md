# Mediateca

A self-hosted media server, meant to replace Jellyfin. It runs in Docker on the
NAS and reads the files under `/mnt/data/multimedia` without copying or
transcoding them.

It does **music**, and nothing else, with a Spotify-style interface and
Netflix-style profiles. There was a `Video::` tree in here once, waiting for a
feature nobody had started; it was a plan sitting in `app/`, and a plan is not
code. Git remembers it.

---

## How it's built

The disk decides what music exists; beets only says what it's called.

`Music::FilesystemSource` scans the music and reads each FLAC's tags with
ffprobe: all 1171 files, not the 934 beets knows about. `Beets::Library`
contributes what it knows. `Music::Library` combines them, and `Music::Importer`
mirrors the result into the catalog, idempotently: the directory identifies the
album and the path identifies the track.

The cover art is chosen by the disk, not beets: beets had picked the back cover
for all six Almafuerte albums.

**A song that moved is still the song.** A directory names an album and a path
names a track, which means renaming a file makes the scan meet the same song as a
stranger: the old row goes, and `dependent: :destroy` takes the playlists, the
hearts and the whole play history with it — at 4am, silently. So before anything
is discarded, `Music::Move` pairs what vanished with what arrived, each side
naming itself: a record by whose it is and what it is called, a song by where it
sits on the record and what it is called. It refuses to guess — a name two things
answer to names neither of them, and handing a playlist a song nobody put there
is worse than losing the entry.

**One unreadable file does not cost the scan.** ffprobe raises on a truncated
copy, and nothing caught it: `ScanMusicJob` died on the first bad file and every
night after did the same, so the library just stopped growing and nothing said
why. A file nothing can read is a file nothing can play; the scan steps over it
and carries on. A *missing binary* is not a bad file, though — that one still
raises, because swallowing it would skip every track and call the library empty.

**A song says who sings it.** Usually that is simply whoever made the record, and
`tracks.artist` is null — but a guest, a duet or a compilation says otherwise on
the file itself, and the file is the one to believe. It is a credit, not an
`artist_id`. beets, asked first, said this happens to exactly one track in the
934 it knows — but the disk, which knows all 1171 and is the one that decides,
says **36**: *"Luis Alberto Spinetta, Pedro Aznar y Charly García"* on a Charly
García record, *"Indio Solari y Los Fundamentalistas del Aire Acondicionado"*
across most of Indio's. Those are credit lines, not people you own records by,
and rows for them would fill the library rail with artists who have no albums.

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

The player lives outside the `<body>` that Turbo Drive replaces when you
navigate (`data-turbo-permanent`), and the playback queue is stored **in the
`<audio>` element**, not in the Stimulus controller — which Turbo destroys and
rebuilds on every page. That's why the music doesn't cut out when you switch
views. A full reload does throw the element away, so the queue is also written
to `localStorage`, tagged with whose it is: the next listener does not inherit
the last one's music. That write happens **when the queue changes**, and the
passing of the song at most every five seconds — it used to serialise the whole
queue on every `timeupdate`, four times a second, forever, synchronously, on the
main thread.

The OS is told what's playing (`MediaSession`), so the media keys, Control Center
and the lock screen drive it. Without that the app is a tab that makes noise.

**Nothing that isn't navigation navigates.** A heart, and a song added to a
playlist, answer with a Turbo Stream and change in place. They used to be full
page visits: the scroll jumped back to the top of the record, the page faded in
again, and the history took one more entry pointing at the URL you were already
on, once per heart — so Back walked you through your own hearting. A system test
counts `history.length` and fails if it grows.

The one page where swapping the heart isn't enough is the list of hearts itself:
a song unhearted is not a liked song, so the stream removes its row too. It says
so unconditionally — on every other page there is no such row and Turbo removes
nothing. And when that takes the last row, the page has to *become* the page it
now is: no buttons to play nothing with, and a line saying so. That is already
true in the DOM, so `:has` reads it off the list instead of asking the server to
re-render everything to discover it.

Whoever is listening picks themselves off a grid, the way Netflix asks. **There
is no password**: whoever holds the cookie is whoever it names. On a home LAN
that is the whole of signing in, and it is a trade made on purpose — anybody on
the network can be anybody. Playlists, hearts and the play history hang off
`Current.profile`, and a playlist is looked up *through* it, so somebody else's
simply does not exist. That lookup is what stands in for a password.

The cookie outlives the profile it names — a browser left open on the kitchen
tablet still remembers somebody deleted last week — so a name that no longer
exists means nobody is listening, and the picker comes back.

Search is a `LIKE` scan, not FTS5: a thousand tracks scan faster than the page
paints, and an index would be a second copy of the truth to keep in step with
the disk. `%` and `_` are wildcards there, so both are escaped — and the escape
character is *declared*, because SQLite reads a backslash as a backslash
otherwise, and the escaping quietly does nothing. It is capped at 50 per kind: a
search is for finding something, not for reading the library out, and nobody
scrolls the six hundredth song with an "a" in it — but the page would have
rendered all six hundred, and clicking one would have queued them.

**No page asks the database one question per row.** The sidebar is on every page
in the app, and it counted each artist's records one `COUNT` at a time; the album
page asked, per song, whether that song was hearted; the playlist page walked
entry → track → album → artist a row at a time. None of it announced itself — it
just got slower with every record added. `test/integration/asking_the_database_once_test.rb`
holds every page to the rule: render it, grow the library tenfold, render it
again, and the number of queries must not move. Counting queries exactly is
brittle; counting the *slope* is the thing we mean.

The play history is written by the player when a track starts, not by the stream
endpoint: `preload=metadata` asks for the file before anybody presses play, and
every seek asks for it again.

The sidebar is desktop-only, so on a phone the library, the hearts and the way
out of a profile live in the top bar instead. The queue used to be desktop-only
too — twice over, since the button that opened it was hidden below `md` and the
class it toggled had no effect there anyway — so a phone had no queue at all. It
opens over the content now rather than beside it: 390px split in two is two
columns of nothing. A system test at 390 px holds every page to no sideways
scroll.

---

## Requirements

| | |
|---|---|
| Ruby | 4.0.5 (`.ruby-version`). Heads up: there is no stable Ruby 3.5 — that series was renamed to 4.0 |
| Rails | 8.1.3 |
| Database | SQLite (primary, cache, queue, cable) |
| Docker | only for deploying. Docker Desktop has to be **running**: Kamal brings up the local registry there |

---

## Development

```bash
bin/setup                # dependencies, database, assets
bin/dev                  # local server on :3000
bin/rails test           # unit, integration and contract tests
bin/rails test:system    # system tests, with headless Chrome
bin/ci                   # everything GitHub Actions runs
```

The tests **never touch the NAS**: `Beets::Library` runs against SQLite
databases built on the fly, and `MEDIA_ROOT` points at a few real FLACs in
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

To bring the app up with your real music, copy the beets database over:

```bash
scp nas:/mnt/data/beets/musiclibrary.db /tmp/
BEETS_DATABASE=/tmp/musiclibrary.db bin/rails music:import
```

The paths beets stores are absolute (`/mnt/data/multimedia/...`), so on the Mac
you'll see the catalog but the files won't exist. To actually play anything,
deploy.

---

## Setting up the NAS (one time only)

Kamal can install Docker on its own, but only if it logs in as root over SSH. On
this NAS root is denied, so we install it by hand:

```bash
ssh nas 'curl -fsSL https://get.docker.com | sudo sh'
ssh nas 'sudo usermod -aG docker gaston'   # so we don't need sudo
```

**`/var` is a small partition** (6.4 GB) and that's where both Docker's
`data-root` and containerd's go by default. With two images and the build cache
it fills up, and the app dies with `SQLite3::FullException: database or disk is
full`. `/srv` has 195 GB. You have to move **both** — moving only Docker's isn't
enough, because since Docker 23 the images live in containerd's content store:

```bash
ssh nas 'sudo systemctl stop docker.socket docker containerd

  sudo mkdir -p /srv/docker /srv/containerd
  sudo rsync -aHAX --remove-source-files /var/lib/docker/     /srv/docker/
  sudo rsync -aHAX --remove-source-files /var/lib/containerd/ /srv/containerd/
  sudo rm -rf /var/lib/docker /var/lib/containerd

  printf "{\n  \"data-root\": \"/srv/docker\"\n}\n" | sudo tee /etc/docker/daemon.json
  sudo sed -i "s|^disabled_plugins = \[\"cri\"\]|disabled_plugins = [\"cri\"]\n\nroot = \"/srv/containerd\"|" /etc/containerd/config.toml

  sudo systemctl start containerd docker'
```

**Free up `:80`.** kamal-proxy needs it, and that's where the nginx that proxied
to Jellyfin used to live. Jellyfin is still reachable directly on `:8096`:

```bash
ssh nas 'sudo systemctl disable --now nginx'
```

---

## Deploy

```bash
cp .kamal/secrets.example .kamal/secrets   # no secrets, just lookups
open -a Docker                             # the local registry runs here

bin/kamal setup      # the first time
bin/kamal deploy     # every time after
bin/kamal import     # scans the music and loads it into the catalog (~80s)
bin/kamal logs
bin/kamal console
```

The scan also runs on its own, every night before dawn: `ScanMusicJob` at 4am.

And there it is at `http://192.168.1.7/`.

There's no registry token and no private images floating around the internet:
the registry is local (`localhost:5555`), Kamal brings it up as a container on
your machine and opens a reverse SSH port-forward so the NAS pulls from its own
localhost. The image never leaves the LAN.

The image is built **on the NAS**, which is amd64. Cross-compiling from the Mac
(arm64) with QEMU works, but it's much slower.

The music is mounted read-only and **under the same path as on the host**, so a
path stored in the catalog means the same thing inside and outside the
container. The container runs as uid 1000, which on the NAS is `gaston`, the
owner of the files.

### Three traps we already paid for

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
nothing. That's why `bin/kamal` sets `LC_ALL=C`: the deploy drops from 79 s to
9 s.

**Rails 8.1 leaves the production SQLite paths commented out** in
`config/database.yml`. Without filling them in, the container dies on startup
with `No database file specified`.

---

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

---

## What's missing

- **A page for liked albums.** An album can be hearted, but only songs have a
  page listing them.
- **Dragging a song up a playlist.** The queue reorders by drag; a playlist still
  moves a song one place at a time, with ▲ and ▼. And the queue's drag is
  mouse-only — HTML5 drag-and-drop does not fire on touch, so on a phone the
  queue can be seen and dropped from, but not rearranged.
- **A PIN on a profile**, for when a home LAN stops being the whole story.
- **Video.** It was here, unreachable from any route or view, and it is gone —
  see the top. Waiting on the NAS are 375 `.mkv`, 168 `.mp4` and 61 `.avi`; many
  of the mkv are HEVC with multitrack FLAC 5.1 and ASS subtitles, so they are not
  direct-play in any browser. The plan, when it comes, is to remux with
  `ffmpeg -c copy` — change the container, don't recompress the video. It will be
  written against what is true then, not against what we guessed a month ago.
