# Mediateca

A self-hosted media server, meant to replace Jellyfin. It runs in Docker on the
NAS and reads the files under `/mnt/data/multimedia` without copying or
transcoding them.

Right now it does **music**, with a Spotify-style interface and Netflix-style
profiles. Video comes later.

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
views.

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
otherwise, and the escaping quietly does nothing.

The play history is written by the player when a track starts, not by the stream
endpoint: `preload=metadata` asks for the file before anybody presses play, and
every seek asks for it again.

The sidebar is desktop-only, so on a phone the library, the hearts and the way
out of a profile live in the top bar instead. A system test at 390 px holds
every page to no sideways scroll.

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
databases built on the fly, and `MEDIA_ROOT` points at a couple of fake FLACs in
`test/fixtures/media`.

**And they don't need ffmpeg.** `Video::Playback` decides without opening
anything; `Video::Probe` and `Music::Tags` interpret ffprobe output recorded in
`test/fixtures/ffprobe`; `Video::Conversion` assembles the command and something
else runs it. Running a process is a separate responsibility, and it lives in
`Ffprobe`.

The only ones that do run it are those in `test/contracts/`, and they're the
only ones that can verify what nobody else can: that ffprobe still describes the
files the way it did when we recorded its output, and that ffmpeg understands the
arguments we build. If ffmpeg isn't there, they're skipped — except with
`REQUIRE_FFMPEG=1`, which is how CI runs them, so they never come up green
without having actually run.

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

- **Video.** Waiting there are 375 `.mkv`, 168 `.mp4` and 61 `.avi`. Many of the
  mkv are HEVC with multitrack FLAC 5.1 audio and ASS subtitles: they're not
  direct-play in any browser. The agreed plan is to remux with `ffmpeg -c copy`
  (change the container without recompressing the video), not to transcode.
- **A page for liked albums.** An album can be hearted, but only songs have a
  page listing them.
- **Drag-and-drop reordering.** A playlist moves a song one place at a time.
- **A PIN on a profile**, for when a home LAN stops being the whole story.
