# Security Policy

## Mediateca has no authentication, by design

Mediateca is built for a single, trusted home LAN. Its "profiles" are
Netflix-style — pick a picture, no password — because the trust model is
*the network*, not the login: anyone who can reach the app can act as any
profile. There is no session security, no per-user access control, and no
attempt to distinguish one person on the LAN from another.

**This is a documented design decision, not a vulnerability.** Do not report
"there's no login" or "any profile can be selected by anyone" as a security
issue — that's how the app is meant to work.

The consequence of that design is important, so it's worth saying plainly:
**do not expose Mediateca to the public internet as-is.** It is meant to run
behind your home network's own perimeter (or a VPN into it), not on an
open port facing the world. If you deploy it publicly, that's on you, and
outside anything this project can promise.

## What *is* worth reporting

Given the above, the boundary this project does claim to defend is the
filesystem: the app reads music from disk and serves it back, and it should
never be possible to make it read or serve anything outside the configured
media root. Worth a private report:

- **Path traversal** past `MEDIA_ROOT` — any request, filename, or crafted
  path that gets the server to read, serve, or expose a file outside the
  configured media directory (`..` sequences, absolute paths, symlinks that
  point outside the root, sibling-directory prefix confusion, etc).
- **SQL injection**, particularly in search or any query built from user
  input.
- **XSS** or other injection that runs attacker-controlled content in
  another user's browser.
- Any other way to make a request "escape the sandbox" the app claims to
  provide — i.e. do something the trust model above doesn't already grant
  by default.

## Reporting

Please report suspected vulnerabilities **privately**, not as a public
issue: use GitHub's **Security → Report a vulnerability** (Security
Advisories) on this repository. That opens a private conversation with the
maintainer before anything is disclosed publicly.

## Supported versions

There is one supported version: the latest release, which tracks `main`.
Every merge to `main` is deployed, so fixes land as soon as they're merged —
there's no older branch receiving separate security patches.
