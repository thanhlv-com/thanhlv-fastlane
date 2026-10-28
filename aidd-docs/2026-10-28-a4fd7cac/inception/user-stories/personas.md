# User Personas

## Persona 1: Release Engineer (Alex)
- **Role**: DevOps & CI/CD Release Specialist.
- **Goals**: Automate end-to-end multi-platform desktop releases with zero manual file uploading; ensure release integrity without publishing corrupted or partial builds.
- **Pain Points**: Wasting 60+ minutes of GitHub Actions compute time on runs that fail at the end due to a duplicate tag; manually uploading DMG, EXE, and AppImage files across different repositories.
- **Needs**: An automated checkbox in GitHub Actions UI (`release: true`) that guarantees fail-fast validation, checks duplicate versions before building, and safely aggregates all desktop binaries into a formal GitHub Release.

## Persona 2: App Developer / Maintainer (Thanh)
- **Role**: Core application maintainer managing apps in `apps.json`.
- **Goals**: Separate application source code repos (e.g. `web-clone`) from dedicated public download repositories (e.g. `Web-Clone-app/download`) while keeping the build pipeline unified.
- **Pain Points**: Configuring custom release scripts for every new app or repository separation.
- **Needs**: Declarative configuration in `apps.json` where adding `"release_download": "..."` automatically routes all release assets to the designated download portal.

## Persona 3: Desktop App End-User (Sam)
- **Role**: Desktop application user on macOS, Windows, or Linux.
- **Goals**: Download verified, complete installation bundles (.dmg, .exe, .AppImage) directly from official GitHub releases.
- **Pain Points**: Missing installers for their specific OS when releases are uploaded incompletely.
- **Needs**: Every official release version contains all promised platform binaries built from the exact same commit.
