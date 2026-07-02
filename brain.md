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
- **UI Clean-up:** Completely removed the 'Licenses' and 'Translate' options from the Settings page to ensure no old UI elements or external links to the original developer exist.
- **UI Modernization:** Redesigned the mini player into a floating glassmorphism pill, rounded the search bar, added a SliverAppBar with gradient to the home screen, and updated the main headings to 'Nit Music'.
- **Auto Updates setup:** Initialized Git and added GitHub action (.github/workflows/auto_release.yml) to automatically compile APK and push to Github Releases. Updated update_manager.dart to fetch OTA updates directly from GitHub API.

**Date: July 2, 2026**
- **True Listening History:** Fixed the audio player queue logic in  udio_service.dart so that starting a new song/playlist accurately saves the currently playing song to history. Tapping the "Previous" button now perfectly restores the previously playing song.
- **Generic Grid & See All:** Implemented a new GenericGridPage and updated outer_service.dart so the "See all" buttons on the Home Page (for Top Mixes, Recommended) now properly route to a full grid view.
- **Premium Bottom Navigation:** Rebuilt the bottom navigation to feature a sliding pill indicator with FastOutSlowIn easing. The icons, labels, and page transitions are now 100% perfectly synchronized, replicating the feel of YouTube Music.
- **Settings UI & Navigation Fixes:** Overhauled the Settings section by replacing persistent sheets with showModalBottomSheet. This fixed the broken back-button/orphaned overlay issues. Slightly reduced and refined typography across all settings for a cleaner, modern look.
- **Splash Screen Polish:** Refined the initial launch splash screen animation to use a premium, snappy `elasticOut` curve, and ensured it accurately reads the `has_seen_splash` flag so it only shows up on the first app launch.
- **Search UI Refinement:** Restored the text labels to the `CustomBottomNavigationBar` after a previous mistake, and verified that the large purple "Search" text issue reported on older APK versions was indeed already removed from the codebase.
- **Home Page Dynamic Header:** Replaced the hamburger menu icon on the Home page top bar with the official `Nit Music` app logo icon. Additionally, updated the "Music" text color to dynamically extract and match the vibrant color of the currently playing song's artwork, synchronizing with the Now Playing background.
- **Update Logic Fixed:** Fixed a bug where the "Update Available" dialog kept appearing because of mismatched hardcoded versions. Also added a `checkAppUpdates` block to ensure the update dialog only appears once per session and only when genuinely required.
- **Trending Section Aspect Ratio:** Adjusted the "Trending Now" images from a 1:1 square to a 16:9 rectangle (220x124) so that YouTube thumbnails are no longer aggressively cropped from the top and bottom.
- **Bottom Navigation Sync & Layout:** Corrected the `CustomBottomNavigationBar` pill indicator synchronization issue where it failed to highlight Library and Settings due to an `AnimationController` upper bound constraint. Also fixed a `Stack` positioning bug where the indicator pill incorrectly overlapped text.
- **Now Playing Collapse Animation:** Fixed the jittering "Collapse Player" (down arrow) button during the transition between the full-screen player and the mini player. Achieved perfect synchronization by wrapping the button in a `Hero` widget with a custom `flightShuttleBuilder`, smoothly interpolating opacity and position along with the player background.
- **Optimized Live Search UI & Logic:** Completely overhauled the search experience to mimic YouTube Music's live search.
  - *UI Changes:* Converted the bulky `CustomBar` search suggestions into a compact `ListTile` with a faded matching query, search icon, and top-left arrow. Displayed both the suggestions and real-time Artist/Song results simultaneously in a `Column` without requiring the user to press Enter.
  - *API Optimizations (Dual-Debounce):* Implemented a `300ms` debounce for light text suggestions, and a heavier `700ms` dual-debounce explicitly for fetching live songs. Also enforced a minimum 2-character limit and request cancellation to protect the backend from spam/flooding during rapid typing.
