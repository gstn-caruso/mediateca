# Contributing to Mediateca

Thanks for taking a look. Mediateca is a small, self-hosted music server built
for one deployment (a home NAS), but it's built carefully, and contributions
are welcome as long as they keep it that way.

## Getting set up

```sh
bin/setup   # installs dependencies, prepares the database
bin/dev     # runs the app, Tailwind watcher, and jobs
```

The app never touches a real music library while developing or testing.
Fixtures live under `test/fixtures/media` and `test/fixtures/audio` — a
handful of tiny, silent FLAC files, tagged the way real ones would be. You
don't need a NAS, a beets database, or actual songs to work on this.

## Running the tests

```sh
bin/rails test          # unit, integration, contract tests
bin/rails test:system   # system tests (headless Chrome)
bin/ci                  # everything CI runs, in one command
```

Run `bin/ci` before opening a PR. It runs the same checks GitHub Actions
runs on every push: tests, system tests, RuboCop, Brakeman, bundler-audit,
and an importmap audit. If `bin/ci` isn't green, the PR isn't ready.

One test is special: `test/contracts/ffprobe_contract_test.rb` runs the real
`ffprobe` binary to verify it still describes a FLAC's tags the way
`Music::Tags` assumes it does. It's skipped automatically if `ffprobe` isn't
installed — except when `REQUIRE_FFPROBE=1` is set, which is how CI runs it,
so that test can never go green without actually having run. If you're
touching anything under `Music::Tags` or the scanner, install `ffprobe`
(part of `ffmpeg`) and run with `REQUIRE_FFPROBE=1 bin/rails test` to be sure.

## Test-Driven Development is mandatory

Every behavior change enters through a failing test first. Not "for big
features" — every change: a bug fix starts with a test that reproduces the
bug, a new feature starts with a test that describes what it should do. This
isn't a style preference; PRs that add behavior without a preceding test
will be asked to add one.

The suite has unit, integration, contract, and system tests. Pick the layer
that actually exercises the thing you're changing — a controller behavior
doesn't need a system test, and a JS interaction usually does.

## Tidy First

If a change needs both a structural cleanup (rename, extract, move code
around, no behavior change) and a behavior change, do them as **separate
commits** — ideally the cleanup first, so the behavior change is easy to
read on its own. Don't mix "I renamed this" with "and also it now does X"
in the same diff.

## Commit messages: Conventional Commits, written as sentences

Every commit uses a Conventional Commits type — `feat:`, `fix:`, `chore:`,
`docs:`, `refactor:`, `test:` — no exceptions. Beyond the type, this repo
writes the rest of the message as a full, declarative sentence that says
what changed *and why*, not a terse label. Look at `git log` for the tone:

```
fix: a press that lands before the player does is held, not lost
feat: a deploy tells every open tab, and the tabs morph onto it without stopping the music
refactor: the version moves to the last corner of the app, the foot of the queue
```

Compare that to something like `fix: race condition in player init` — both
are technically fine, but the first tells you what actually happened.
Aim for the former.

Keep commits small, reversible, and independently verifiable.

## What makes a change likely to be accepted

This project values simplicity over generality. Concretely:

- **The simplest thing that works.** Don't add configuration, abstraction,
  or indirection for a use case that doesn't exist yet.
- **No code for hypothetical futures.** If Mediateca doesn't need it today,
  it doesn't go in today. YAGNI is the default, not the exception.
- **No premature abstraction.** Three similar lines are better than the
  wrong shared abstraction. Duplication is cheaper to fix later than a bad
  interface is to unwind.
- Changes that fit how the app already thinks (see
  [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)) are much easier to review than
  changes that introduce a new pattern alongside an existing one.

If you're unsure whether an idea fits, open an issue or a Discussion before
writing code — it's a much shorter conversation before the PR than after.

## Opening a PR

1. Fork and branch off `main`.
2. Make your change: test first, then code, structural and behavioral
   changes in separate commits.
3. Run `bin/ci` locally and make sure it's green.
4. Open the PR with a summary of what changed and why. Link any related
   issue.
5. CI runs the same checks on the PR. Every merge to `main` auto-deploys and
   cuts a release, so `main` has to stay releasable at all times — that's
   part of why the bar is "green CI," not "looks right."
