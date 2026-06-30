# Nit Music - Update History & Brain

This file keeps track of all the changes and updates made to this personal music app.

## Updates Log

**Date: June 30, 2026**
- **Identity Removal:** Removed all references to original developer ("Valeri Gokadze" / "gokadzev"), deleted `LICENSE`, `CONTRIBUTING.md`, `.github`, etc.
- **Update Checks Disabled:** Removed all GitHub-based update checks and announcements so the app never tries to update from the original repository.
- **Package Name Changed:** Renamed the android package identifier to `com.musify.app`.
- **App Renamed:** Changed the app's display name from "Musify" to "Nit Music" in `AndroidManifest.xml`, Dart code, and all `.arb` translation files.
- **New AI Logo:** Generated a new premium AI logo (neon purple and blue) and replaced the app's launcher icons and internal assets (`assets/logo.png`).
- **Signing Fixed:** Configured the `release` build to use the default `debug` keystore to ensure the APK installs flawlessly on Android 11+ without throwing "Invalid Package" errors.
- **Search Speed Optimization:** Added 2-second timeouts to slow API requests (Artists, Albums, Playlists) in `Future.wait` during search. This drastically improved search speed by not blocking the fast song results.
- **Autoplay enabled:** Confirmed autoplay/default settings based on user request.
- **APK Generation:** Created and placed the final `NitMusic.apk` in the root directory for easy access.
- **UI Clean-up:** Completely removed the 'Licenses' and 'Translate' options from the Settings page to ensure no old UI elements or external links to the original developer exist.
- **UI Modernization:** Redesigned the mini player into a floating glassmorphism pill, rounded the search bar, added a SliverAppBar with gradient to the home screen, and updated the main headings to 'Nit Music'.
- **Auto Updates setup:** Initialized Git and added GitHub action (.github/workflows/auto_release.yml) to automatically compile APK and push to Github Releases. Updated update_manager.dart to fetch OTA updates directly from GitHub API.
