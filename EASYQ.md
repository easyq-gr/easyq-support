# EasyQ Support

**EasyQ Support** is the remote help client of [EasyQ](https://www.easyq.gr), print shop management software. It is
[RustDesk](https://github.com/rustdesk/rustdesk) with a small set of changes, built from this repository. A customer
starts it from EasyQ when they ask EasyQ support for help; nothing is installed and nothing runs after it is closed.

## What is different from RustDesk

All changes are in [`easyq/apply.ps1`](easyq/apply.ps1), applied to `libs/hbb_common/src/config.rs` during the build:

| Change | Why |
|---|---|
| App name `EasyQ Support` | Its own settings folder: a RustDesk the user already has keeps its settings and does not affect this client |
| ID / relay server `remote.easyq.gr` and its public key | EasyQ's own server instead of RustDesk's public servers |
| `approve-mode = click` | Every connection needs the user's "Accept"; there is no password to ask for |
| No installation, no settings page, no account, no address book | Only a one-time, user-started session |
| No API server (`register-device = N`) | The client never calls RustDesk's admin server |
| No update check, no LAN discovery | Nothing besides the session itself |

Everything else is RustDesk, unchanged.

## How it is built

- Branch `easyq-1.5.3` = RustDesk tag `1.5.3` + `easyq/` + `.github/workflows/easyq-build.yml` + this file. One branch
  per RustDesk version, named `easyq-<version>`; the default branch is the one EasyQ ships today.
- `.github/workflows/easyq-build.yml` (run by hand) builds Windows x64 with RustDesk's own build steps and the
  change above, and uploads the unsigned files as an artifact. It is generated from RustDesk's `flutter-build.yml` of
  the same version, never edited by hand.
- The files are then signed by EasyQ with its own code signing certificate and published.
- A new RustDesk version: a new `easyq-<version>` branch from the new tag, the same `easyq/` folder, the workflow
  generated again.

## License

RustDesk is licensed under the [GNU AGPL-3.0](LICENCE). So is this fork: the source of every EasyQ Support binary is
the `easyq-<version>` branch of this repository for that version. This is not an official RustDesk build and is not supported by
the RustDesk team; please report problems to EasyQ, not to RustDesk.
